--- Cash bags: withdrawing from the Safe creates a ledger row (moneywash_cashbags) and gives the
--- Config.Withdraw.Item item. The row decides everything, the item only carries its id.
--- A bag is deposited at an ATM, clears after Config.Deposit.ProcessingTime and is paid into
--- the depositor's bank. Money is never created from the item: a copy of a bag is worth nothing.

---@class CashBag
---@field id integer Ledger row id (internal, never shown)
---@field serial string Random number on the item, how the ledger finds the bag
---@field owner string Identifier of the player who withdrew it
---@field businessId integer
---@field label string Business name at withdrawal
---@field amount integer Gross amount taken from the Safe
---@field exposed integer Part of the amount that was exposed cash
---@field state "carried"|"processing"
---@field flagged boolean
---@field createdAt integer
---@field depositor? string Who deposited it (processing only)
---@field x? number ATM position (processing only)
---@field y? number
---@field z? number
---@field clearsAt? integer Unix time the deposit clears (processing only)
---@field written? boolean Withdraw: the Safe and the ledger row are written
---@field busy? boolean True while a database change to this bag is running
---@field paid? boolean True once the depositor got the money, so a failed delete can't pay twice

---@type table<integer, CashBag> Bags that are carried or processing, by id
local Bags = {}

local loaded = false

--- ATM model hashes (normalised to unsigned so client and server hashes compare equal)
local atmModels = {}
for _, name in ipairs(Config.Deposit.Models) do
    atmModels[joaat(name) & 0xFFFFFFFF] = true
end

---@param reason string
---@return { success: false, reason: string }
local function fail(reason)
    return { success = false, reason = reason }
end

---@param row table Database row
---@return CashBag
local function toBag(row)
    return {
        id         = row.id,
        serial     = row.serial,
        owner      = row.owner,
        businessId = row.business_id,
        label      = row.label,
        amount     = tonumber(row.amount) or 0,
        exposed    = tonumber(row.exposed) or 0,
        state      = row.state,
        flagged    = row.flagged == 1 or row.flagged == true,
        createdAt  = tonumber(row.created_at) or os.time(),
        depositor  = row.depositor,
        x          = tonumber(row.x),
        y          = tonumber(row.y),
        z          = tonumber(row.z),
        clearsAt   = tonumber(row.clears_at),
    }
end

--- True once the ledger is loaded. Nothing that touches bags works before that.
---@return boolean
function IsCashBagStoreReady()
    return loaded
end

---@param bag CashBag
---@return integer seconds
local function remainingSeconds(bag)
    return math.max(0, (bag.clearsAt or 0) - os.time())
end

--- Server-side distance check for ATM interactions. The target's own distance is a
--- config value; the extra margin only absorbs position lag.
---@param src integer
---@param x number
---@param y number
---@param z number
---@param distance number
---@return boolean
local function isNearATM(src, x, y, z, distance)
    return IsPlayerNearCoords(src, vector3(x, y, z), distance + 2.0)
end

---@param slots table[]|nil
---@param serial string
---@return table|nil entry
local function findBagSlot(slots, serial)
    for _, entry in ipairs(slots or {}) do
        if tostring(entry.metadata.serial) == serial then return entry end
    end
end

--- The item metadata of a bag. Only the serial is read back, the amount is for the player to see.
---@param bag CashBag
---@return table
local function bagMetadata(bag)
    return { serial = bag.serial, amount = Config.Currency .. bag.amount }
end

--- Finds a carried or processing bag by the serial on its item.
---@param serial any
---@return CashBag|nil
local function bagBySerial(serial)
    if serial == nil then return nil end
    serial = tostring(serial)

    for _, bag in pairs(Bags) do
        if bag.serial == serial then return bag end
    end
end

--- A random 8 digit serial that no active bag uses.
---@return string
local function newSerial()
    local serial
    repeat serial = tostring(math.random(10000000, 99999999)) until not bagBySerial(serial)
    return serial
end

--- -------------------------------------------------------------------------
--- WITHDRAW (called by cash_operation.lua)
--- -------------------------------------------------------------------------

--- Value of the business's bags that count towards the limit. Old bags stop counting
--- (a bag that was lost or thrown away would otherwise block the business forever).
---@param businessId integer
---@return integer total
local function outstandingTotal(businessId)
    local since = os.time() - (Config.Withdraw.OutstandingHours or 24) * 3600
    local total = 0

    for _, bag in pairs(Bags) do
        if bag.businessId == businessId and bag.createdAt >= since then
            total = total + bag.amount
        end
    end

    return total
end

--- How much more the business may put into bags right now. Nil when there is no limit.
---@param business table
---@return integer|nil allowance
function GetBagAllowance(business)
    if not Config.Withdraw.LimitOutstanding then return nil end

    local tier = GetTierByType(business.type)
    if not tier then return 0 end

    return math.max(0, tier.expectedRevenue - outstandingTotal(business.id))
end

--- Writes the reduced Safe and the new ledger row in ONE transaction, then reads the id back.
--- Returns false on failure, so the cash operation retries (the transaction only runs once).
---@param business table The business, already reduced in memory
---@param bag CashBag Without id
---@return boolean ok
function PersistCashBag(business, bag)
    bag.serial = bag.serial or newSerial() -- kept across retries

    if not bag.written then
        local ok, result = pcall(MySQL.transaction.await, {
            {
                query  = "UPDATE moneywash_businesses SET safe_covered = ?, safe_exposed = ? WHERE id = ? AND identifier = ?",
                values = { business.safeCovered, business.safeExposed, business.id, bag.owner },
            },
            {
                query  = "INSERT INTO moneywash_cashbags (owner, business_id, label, amount, exposed, serial, state, created_at) VALUES (?, ?, ?, ?, ?, ?, 'carried', ?)",
                values = { bag.owner, bag.businessId, bag.label, bag.amount, bag.exposed, bag.serial, bag.createdAt },
            },
        })

        if not ok or not result then
            print(("[MoneyWash] Cash bag write failed (will retry): %s"):format(tostring(result)))
            return false
        end

        bag.written = true
    end

    -- One operation per owner at a time, so their newest row is this bag.
    local ok, id = pcall(MySQL.scalar.await, "SELECT MAX(id) FROM moneywash_cashbags WHERE owner = ?", { bag.owner })
    if not ok or not id then
        print(("[MoneyWash] Cash bag id lookup failed (will retry): %s"):format(tostring(id)))
        return false
    end

    bag.id = id
    Bags[id] = bag

    return true
end

--- Gives the bag item and checks that it arrived (most inventories don't return a result).
---@param src integer
---@param bag CashBag
---@return boolean given
local function giveBagItem(src, bag)
    local item = Config.Withdraw.Item

    _API.Inventory.AddItem(src, item, 1, bagMetadata(bag))

    return findBagSlot(_API.Inventory.GetItemSlots(src, item), bag.serial) ~= nil
end

--- Takes a bag that could not be given back out of the world: the money returns to the
--- Safe and the ledger row is deleted, in one transaction.
---@param bag CashBag
---@return boolean undone
local function undoCashBag(bag)
    while IsBusinessSaveInProgress(bag.businessId) do Wait(20) end

    local business = GetBusiness(bag.businessId)
    local ok, result

    if business and business.identifier == bag.owner then
        local covered = business.safeCovered + (bag.amount - bag.exposed)
        local exposed = business.safeExposed + bag.exposed

        ok, result = pcall(MySQL.transaction.await, {
            {
                query  = "UPDATE moneywash_businesses SET safe_covered = ?, safe_exposed = ? WHERE id = ? AND identifier = ?",
                values = { covered, exposed, bag.businessId, bag.owner },
            },
            {
                query  = "DELETE FROM moneywash_cashbags WHERE id = ? AND state = 'carried'",
                values = { bag.id },
            },
        })

        if ok and result then
            UpdateBusinessFields(bag.businessId, { safeCovered = covered, safeExposed = exposed })
        end
    else
        -- The business is gone or changed owner: there is no Safe to return the money to.
        ok, result = pcall(MySQL.update.await, "DELETE FROM moneywash_cashbags WHERE id = ? AND state = 'carried'", { bag.id })
        result = ok and result ~= nil
    end

    if not ok or not result then
        print(("[MoneyWash] Cash bag %d could not be undone (%s): %s. The Safe was reduced but no bag exists; refund it by hand."):format(
            bag.id, bag.owner, tostring(result)))
        return false
    end

    Bags[bag.id] = nil

    return true
end

--- Runs after the withdraw is saved: gives the item to the owner. If that fails (offline,
--- no room), the withdraw is undone so the money is never lost.
---@param src integer|nil Owner source, nil if offline
---@param bag CashBag
function PublishCashBag(src, bag)
    if src then
        local ok, given = pcall(giveBagItem, src, bag)

        if ok and given then
            RunHook("OnCashBagCreated", bag.owner, bag.id, bag.businessId, bag.amount, bag.exposed)
            _API.SendNotification(src, string.format(locale("notification.cash_bag_received"), Config.Currency .. bag.amount), "success")
            return
        end

        _API.SendNotification(src, locale("error.cannot_carry_bag"), "error")
    end

    undoCashBag(bag)
end

--- -------------------------------------------------------------------------
--- PAYOUT
--- -------------------------------------------------------------------------

---@param src integer|nil
---@param identifier string
local function awardReputation(src, identifier)
    local reward = Config.Reputation.Rewards.bankDeposit
    if not (Config.Reputation.Enable and reward and reward.enable) then return end

    AwardReputationPoints(src, identifier, reward.points)
end

---@param bag CashBag
local function payBag(bag)
    if bag.busy or bag.state ~= "processing" then return end

    local tax = Config.Deposit.Tax or 0
    local net = math.floor(bag.amount * (100 - tax) / 100)

    bag.busy = true

    -- Pay first, delete second: a disconnect can't lose the money, and `paid`
    -- stops a failed delete from paying twice.
    if not bag.paid then
        local src = GetOnlineSourceByIdentifier(bag.depositor)
        if not src then bag.busy = false; return end -- offline: paid when they are back

        _API.Player.AddMoney(src, net, "bank")
        bag.paid = true
    end

    local ok, affected = pcall(MySQL.update.await, "DELETE FROM moneywash_cashbags WHERE id = ? AND state = 'processing'", { bag.id })

    bag.busy = false

    if not ok or affected == nil then
        print(("[MoneyWash] Cash bag %d paid but not deleted yet (retrying next tick)"):format(bag.id))
        return
    end

    Bags[bag.id] = nil

    local src = GetOnlineSourceByIdentifier(bag.depositor)

    -- Only the player who earned the money gets reputation for it, not whoever stole the bag
    if bag.depositor == bag.owner then awardReputation(src, bag.owner) end

    RunHook("OnCashBagDeposited", bag.depositor, bag.owner, bag.businessId, bag.amount, net, bag.id)

    if src then
        RefreshPortalViewer(src)
        _API.SendNotification(src, string.format(locale("notification.deposit_cleared"), Config.Currency .. net, Config.Currency .. (bag.amount - net)), "success")
    end
end

--- Called every minute by the master tick in server/main.lua.
function ProcessCashBags()
    local due = {}
    local now = os.time()

    for _, bag in pairs(Bags) do
        if bag.state == "processing" and bag.clearsAt and now >= bag.clearsAt then
            due[#due + 1] = bag
        end
    end

    for _, bag in ipairs(due) do
        payBag(bag)
    end
end

--- Startup: loads the ledger. A deposit that was still processing is lost: the bag is
--- already gone and nothing is paid (a restart must not help anyone dodge the police).
--- Call after LoadBusinesses().
function LoadCashBags()
    local rows = MySQL.query.await("SELECT * FROM moneywash_cashbags WHERE state IN ('carried', 'processing')") or {}
    local lost = {}

    for _, row in ipairs(rows) do
        local bag = toBag(row)

        if bag.state == "processing" then
            lost[#lost + 1] = bag
        else
            Bags[bag.id] = bag
        end
    end

    if #lost > 0 then
        MySQL.update.await("UPDATE moneywash_cashbags SET state = 'lost' WHERE state = 'processing'")

        for _, bag in ipairs(lost) do
            print(("[MoneyWash] Cash bag %d was lost in a restart: %s%d deposited by %s (owner %s)"):format(
                bag.id, Config.Currency, bag.amount, tostring(bag.depositor), bag.owner))
            RunHook("OnCashBagLost", bag.depositor, bag.owner, bag.businessId, bag.amount, bag.id)
        end
    end

    loaded = true

    if Config.Debug then
        print(("[MoneyWash] Loaded %d cash bag(s), %d lost"):format(#rows - #lost, #lost))
    end
end

--- -------------------------------------------------------------------------
--- DEPOSIT (ATM)
--- -------------------------------------------------------------------------

--- Why the player can't start a deposit right now, or nil.
---@param identifier string
---@return string|nil reason
local function depositBlocked(identifier)
    if not loaded then return "not_ready" end

    local minPolice = Config.Deposit.MinPolice or 0
    if minPolice > 0 and GetOnDutyPoliceCount() < minPolice then return "not_enough_police" end

    local active = 0
    for _, bag in pairs(Bags) do
        if bag.state == "processing" and bag.depositor == identifier then active = active + 1 end
    end

    if active >= (Config.Deposit.MaxActive or 1) then return "deposit_pending" end
end

--- The player's usable bags: the ones in their inventory that the ledger says are still carried.
---@param src integer
---@return { stack: table, bag: CashBag }[]|nil list
---@return string|nil reason
local function carriedBags(src)
    local slots, reason = _API.Inventory.GetItemSlots(src, Config.Withdraw.Item)
    if not slots then
        return nil, reason == "unsupported_inventory" and "inventory_unsupported" or "request_failed"
    end

    local list, seen = {}, {}

    for _, entry in ipairs(slots) do
        local bag = bagBySerial(entry.metadata.serial)

        if bag and bag.state == "carried" and not seen[bag.id] then
            seen[bag.id] = true
            list[#list + 1] = { stack = entry, bag = bag }
        end
    end

    -- core_inventory can't remove a specific stack, so with several bags it could take the wrong one
    if #list > 1 and _Inventory == "core_inventory" then return nil, "one_bag_at_a_time" end

    return list
end

--- Callback: the bags the player can deposit, for the choice menu. Early feedback only,
--- depositCashBag checks everything again.
lib.callback.register("t1ger_moneywash:server:getCashBags", function(src)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return fail("invalid_player") end

    local blocked = depositBlocked(identifier)
    if blocked then return fail(blocked) end

    local list, reason = carriedBags(src)
    if not list then return fail(reason) end
    if #list == 0 then return fail("empty_bag") end

    local data = {}
    for _, entry in ipairs(list) do
        data[#data + 1] = { id = entry.bag.id, amount = entry.bag.amount, label = entry.bag.label }
    end

    return { success = true, data = data }
end)

--- Rolls the flag: a stolen bag is always flagged, otherwise the chance is its exposed share.
---@param bag CashBag
---@param depositor string
---@return boolean flagged
---@return boolean stolen
local function rollFlag(bag, depositor)
    if bag.owner ~= depositor then return true, true end
    if bag.exposed <= 0 then return false, false end

    return math.random() < bag.exposed / bag.amount, false
end

--- Callback: deposits one bag at an ATM.
---@param src integer
---@param bagId integer
---@param coords { x: number, y: number, z: number } ATM position
---@param model integer ATM model hash
lib.callback.register("t1ger_moneywash:server:depositCashBag", function(src, bagId, coords, model)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return fail("invalid_player") end

    if type(coords) ~= "table" then return fail("invalid_atm") end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return fail("invalid_atm") end

    local hash = math.floor(tonumber(model) or 0) & 0xFFFFFFFF
    if not atmModels[hash] then return fail("invalid_atm") end

    -- The player's real position must be at the claimed ATM
    if not isNearATM(src, x, y, z, Config.Deposit.Target.distance) then return fail("atm_too_far") end

    local blocked = depositBlocked(identifier)
    if blocked then return fail(blocked) end

    bagId = tonumber(bagId)
    local bag = bagId and Bags[bagId]
    if not bag or bag.state ~= "carried" or bag.busy then return fail("empty_bag") end

    -- The bag must be in the player's inventory right now
    local list, reason = carriedBags(src)
    if not list then return fail(reason) end

    local stack
    for _, entry in ipairs(list) do
        if entry.bag.id == bag.id then stack = entry.stack; break end
    end
    if not stack then return fail("invalid_bag") end

    bag.busy = true

    -- Take the item first. Nothing yields between the check above and this removal.
    _API.Inventory.RemoveItem(src, Config.Withdraw.Item, 1, nil, stack.slot)

    local flagged, stolen = rollFlag(bag, identifier)
    local clearsAt = os.time() + Config.Deposit.ProcessingTime * 60

    local ok, affected = pcall(MySQL.update.await,
        "UPDATE moneywash_cashbags SET state = 'processing', depositor = ?, flagged = ?, x = ?, y = ?, z = ?, clears_at = ? " ..
        "WHERE id = ? AND state = 'carried'",
        { identifier, flagged and 1 or 0, x, y, z, clearsAt, bag.id })

    bag.busy = false

    if not ok or not affected or affected < 1 then
        -- Not saved: the player gets the bag back
        pcall(_API.Inventory.AddItem, src, Config.Withdraw.Item, 1, bagMetadata(bag))
        return fail("database_error")
    end

    bag.state, bag.depositor, bag.flagged = "processing", identifier, flagged
    bag.x, bag.y, bag.z, bag.clearsAt = x, y, z, clearsAt

    if flagged then
        SendPoliceNotification(stolen and "StolenDeposit" or "Deposit", vector3(x, y, z), { amount = bag.amount })
    end

    _API.SendNotification(src, string.format(locale("notification.deposit_submitted"), Config.Deposit.ProcessingTime), "success")

    return { success = true }
end)

--- -------------------------------------------------------------------------
--- POLICE
--- -------------------------------------------------------------------------

---@param src integer
---@return boolean
local function isDepositReviewer(src)
    local job = _API.Player.GetJob(src)
    if not job then return false end

    for _, name in ipairs(Config.Police.Jobs) do
        if job.name == name then
            return (job.grade or 0) >= Config.Police.ATM.MinGrade
        end
    end

    return false
end

---@param src integer
---@param bag CashBag
---@return boolean
local function officerNearBag(src, bag)
    if not bag.x or not bag.y or not bag.z then return false end

    return isNearATM(src, bag.x, bag.y, bag.z, Config.Police.ATM.Target.distance)
end

--- Callback: flagged deposits still processing at the ATM the officer is standing at.
lib.callback.register("t1ger_moneywash:server:getFlaggedDeposits", function(src)
    if not isDepositReviewer(src) then return {} end

    local list = {}

    for _, bag in pairs(Bags) do
        if bag.state == "processing" and bag.flagged and officerNearBag(src, bag) then
            list[#list + 1] = {
                ref              = bag.id,
                amount           = bag.amount,
                remainingSeconds = remainingSeconds(bag),
                name             = _API.GetCharacterNameByIdentifier(bag.depositor), -- name only, never the identifier
                business         = bag.label,
            }
        end
    end

    return list
end)

--- Callback: confiscation. The money vanishes.
lib.callback.register("t1ger_moneywash:server:confiscateDeposit", function(src, ref)
    if not isDepositReviewer(src) then return fail("invalid_job") end

    local bag = Bags[tonumber(ref)]
    if not bag then return fail("no_pending_deposit") end
    if bag.state ~= "processing" or not bag.flagged or bag.busy then return fail("not_flagged") end
    if not officerNearBag(src, bag) then return fail("atm_too_far") end

    bag.busy = true
    local ok, affected = pcall(MySQL.update.await, "DELETE FROM moneywash_cashbags WHERE id = ? AND state = 'processing'", { bag.id })
    bag.busy = false

    if not ok or not affected or affected < 1 then return fail("database_error") end

    Bags[bag.id] = nil

    RunHook("OnCashBagConfiscated", _API.Player.GetIdentifier(src), bag.depositor, bag.owner, bag.businessId, bag.amount, bag.id)

    local depositor = GetOnlineSourceByIdentifier(bag.depositor)
    if depositor then
        _API.SendNotification(depositor, locale("notification.deposit_confiscated"), "error")
    end

    return { success = true, amount = bag.amount }
end)