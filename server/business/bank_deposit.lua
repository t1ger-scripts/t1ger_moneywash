--- ============================================================================
--- Bank Deposit
--- Safe -> cash counter ("withdraw") -> any ATM -> processing -> personal bank.
--- One pending deposit per player, persisted in moneywash_deposits.
--- ============================================================================

---@type table<string, table> Pending deposits by owner identifier
local Deposits = {}

--- ATM model hashes (normalised to unsigned so client and server hashes compare equal)
local atmModels = {}
for _, name in ipairs(Config.BankDeposit.Models) do
    atmModels[joaat(name) & 0xFFFFFFFF] = true
end

local function fail(reason)
    return { success = false, reason = reason }
end

local function onlineSource(identifier)
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == identifier then return player.source end
    end
end

local function toDeposit(row)
    return {
        identifier = row.identifier,
        businessId = row.business_id,
        amount     = row.amount,
        covered    = row.covered or 0,
        exposed    = row.exposed or 0,
        state      = row.state,
        flagged    = row.flagged == 1 or row.flagged == true,
        x          = tonumber(row.x),
        y          = tonumber(row.y),
        z          = tonumber(row.z),
        clearsAt   = tonumber(row.clears_at),
        createdAt  = tonumber(row.created_at) or os.time(),
    }
end

local function remainingSeconds(d)
    local deadline = d.state == "processing"
        and d.clearsAt
        or (d.createdAt + Config.BankDeposit.MissionTimeout * 60)
    return math.max(0, deadline - os.time())
end

--- Server-side distance check for ATM interactions. The target's own distance is
--- Config.BankDeposit.InteractDistance; the extra margin only absorbs position lag.
local function isNearATM(src, x, y, z)
    return IsPlayerNearCoords(src, vector3(x, y, z), Config.BankDeposit.InteractDistance + 2.0)
end

--- Client-safe view of a player's pending deposit (nil if none).
function GetBankDepositPublic(identifier)
    local d = Deposits[identifier]
    if not d then return nil end
    return {
        businessId       = d.businessId,
        amount           = d.amount,
        state            = d.state,
        remainingSeconds = remainingSeconds(d),
    }
end

function HasActiveDeposit(identifier)
    return Deposits[identifier] ~= nil
end

function HasBusinessDeposit(businessId)
    for _, d in pairs(Deposits) do
        if d.businessId == businessId then return true end
    end
    return false
end

--- -------------------------------------------------------------------------
--- CASH COUNTER INTEGRATION
--- -------------------------------------------------------------------------

--- Returns an error key if the owner can't start a deposit of `amount`, otherwise nil.
function CanStartBankDeposit(business, amount)
    if Deposits[business.identifier] then return "deposit_pending" end
    if (business.safeCovered + business.safeExposed) < amount then return "insufficient_safe_cash" end
    return nil
end

--- Removes `amount` from the Safe in memory (exposed first, then covered).
--- Returns the new deposit record. Persisted afterwards by PersistBankDepositStart.
function ApplyBankDepositWithdrawal(business, amount)
    local exposed = math.min(amount, business.safeExposed)
    local covered = amount - exposed

    UpdateBusinessFields(business.id, {
        safeExposed = business.safeExposed - exposed,
        safeCovered = business.safeCovered - covered,
    })

    return {
        identifier = business.identifier,
        businessId = business.id,
        amount     = amount,
        covered    = covered,
        exposed    = exposed,
        state      = "enroute",
        flagged    = false,
        createdAt  = os.time(),
    }
end

--- Writes the reduced Safe and the deposit row in ONE transaction.
--- Returns false on failure so the cash counter retries.
function PersistBankDepositStart(businessId, identifier, deposit)
    local business = GetBusiness(businessId)
    if not business or business.identifier ~= identifier then return false end

    local ok, result = pcall(MySQL.transaction.await, {
        {
            query  = "UPDATE moneywash_businesses SET safe_covered = ?, safe_exposed = ? WHERE id = ? AND identifier = ?",
            values = { business.safeCovered, business.safeExposed, businessId, identifier },
        },
        {
            query  = "INSERT INTO moneywash_deposits (identifier, business_id, amount, covered, exposed, state, flagged, created_at) VALUES (?, ?, ?, ?, ?, 'enroute', 0, ?)",
            values = { identifier, businessId, deposit.amount, deposit.covered, deposit.exposed, deposit.createdAt },
        },
    })

    if not ok or not result then
        print(("[MoneyWash] Bank deposit start failed (will retry): %s"):format(tostring(result)))
        return false
    end

    Deposits[identifier] = deposit
    return true
end

--- Runs after the deposit is durably saved.
function PublishBankDepositStarted(src, identifier, businessId, deposit)
    if src then
        TriggerClientEvent("t1ger_moneywash:client:bankDepositStarted", src, GetBankDepositPublic(identifier))
    end
end

--- -------------------------------------------------------------------------
--- REFUND (cancel, timeout, restart recovery)
--- -------------------------------------------------------------------------

--- Puts an enroute deposit back into the Safe and deletes the row (one transaction).
---@return boolean refunded
local function refundDeposit(d)
    if d.busy or d.state ~= "enroute" or Deposits[d.identifier] ~= d then return false end
    d.busy = true

    while IsBusinessSaveInProgress(d.businessId) do Wait(20) end

    local business = GetBusiness(d.businessId)
    local ok, result

    if business and business.identifier == d.identifier then
        local covered = business.safeCovered + d.covered
        local exposed = business.safeExposed + d.exposed

        ok, result = pcall(MySQL.transaction.await, {
            {
                query  = "UPDATE moneywash_businesses SET safe_covered = ?, safe_exposed = ? WHERE id = ? AND identifier = ?",
                values = { covered, exposed, d.businessId, d.identifier },
            },
            {
                query  = "DELETE FROM moneywash_deposits WHERE identifier = ? AND state = 'enroute'",
                values = { d.identifier },
            },
        })

        if ok and result then
            UpdateBusinessFields(d.businessId, { safeCovered = covered, safeExposed = exposed })
        end
    else
        -- Business no longer exists (removals are blocked while a deposit is pending,
        -- so this is a safety net only).
        ok, result = pcall(MySQL.update.await,
            "DELETE FROM moneywash_deposits WHERE identifier = ? AND state = 'enroute'", { d.identifier })
        result = ok and result ~= nil
    end

    d.busy = false

    if not ok or not result then
        print(("[MoneyWash] Bank deposit refund failed for %s: %s"):format(d.identifier, tostring(result)))
        return false
    end

    Deposits[d.identifier] = nil

    local src = onlineSource(d.identifier)
    if src then
        TriggerClientEvent("t1ger_moneywash:client:bankDepositEnded", src)
        _API.SendNotification(src,
            string.format(locale("notification.deposit_refunded"), Config.Currency .. d.amount), "inform")
    end

    return true
end

--- -------------------------------------------------------------------------
--- PAYOUT
--- -------------------------------------------------------------------------

local function awardReputation(src, identifier)
    local reward = Config.Reputation.Rewards.bankDeposit
    if not (Config.Reputation.Enable and reward and reward.enable) then return end

    if src and IsReputationReady(src) then
        AddReputationPoints(src, reward.points)
        SavePlayerReputation(src)
    else
        MySQL.update("UPDATE moneywash_reputation SET points = points + ? WHERE identifier = ?",
            { reward.points, identifier })
    end
end

local function payDeposit(d)
    if d.busy or d.state ~= "processing" then return end

    local tax = Config.BankDeposit.Tax or 0
    local net = math.floor(d.amount * (100 - tax) / 100)

    d.busy = true

    -- Pay first, delete second: a disconnect can't lose the money, and `paid`
    -- stops a failed delete from paying twice.
    if not d.paid then
        local src = onlineSource(d.identifier)
        if not src then d.busy = false; return end -- offline owner: paid after login
        _API.Player.AddMoney(src, net, "bank")
        d.paid = true
    end

    local ok, affected = pcall(MySQL.update.await,
        "DELETE FROM moneywash_deposits WHERE identifier = ? AND state = 'processing'", { d.identifier })

    d.busy = false

    if not ok or affected == nil then
        print(("[MoneyWash] Bank deposit delete failed for %s (retrying next tick)"):format(d.identifier))
        return
    end

    Deposits[d.identifier] = nil

    local src = onlineSource(d.identifier)
    awardReputation(src, d.identifier)
    OnBankDepositCompleted(d.identifier, d.businessId, d.amount, net)

    if src then
        TriggerClientEvent("t1ger_moneywash:client:bankDepositEnded", src)
        _API.SendNotification(src,
            string.format(locale("notification.deposit_cleared"), Config.Currency .. net, Config.Currency .. (d.amount - net)),
            "success")
    end
end

--- Called every minute by the master tick in server/main.lua.
function ProcessBankDeposits()
    local list = {}
    for _, d in pairs(Deposits) do list[#list + 1] = d end

    local now = os.time()
    local timeout = Config.BankDeposit.MissionTimeout * 60

    for _, d in ipairs(list) do
        if d.state == "enroute" and now >= d.createdAt + timeout then
            refundDeposit(d)
        elseif d.state == "processing" and d.clearsAt and now >= d.clearsAt then
            payDeposit(d)
        end
    end
end

--- Startup: load rows. Money that never reached an ATM returns to the Safe;
--- submitted deposits carry on from `clears_at`. Call after LoadBusinesses().
function LoadBankDeposits()
    local rows = MySQL.query.await("SELECT * FROM moneywash_deposits") or {}

    local enroute = {}
    for _, row in ipairs(rows) do
        local d = toDeposit(row)
        Deposits[d.identifier] = d
        if d.state == "enroute" then enroute[#enroute + 1] = d end
    end

    for _, d in ipairs(enroute) do refundDeposit(d) end

    if Config.Debug then
        print(("[MoneyWash] Loaded %d bank deposit(s), %d returned to Safe"):format(#rows, #enroute))
    end
end

--- -------------------------------------------------------------------------
--- OWNER CALLBACKS
--- -------------------------------------------------------------------------

lib.callback.register("t1ger_moneywash:server:getBankDeposit", function(src)
    local identifier = _API.Player.GetIdentifier(src)
    return identifier and GetBankDepositPublic(identifier) or nil
end)

lib.callback.register("t1ger_moneywash:server:cancelBankDeposit", function(src)
    local identifier = _API.Player.GetIdentifier(src)
    local d = identifier and Deposits[identifier]
    if not d or d.state ~= "enroute" then return fail("no_pending_deposit") end
    if not refundDeposit(d) then return fail("operation_in_progress") end
    return { success = true }
end)

lib.callback.register("t1ger_moneywash:server:submitBankDeposit", function(src, coords, model)
    local identifier = _API.Player.GetIdentifier(src)
    local d = identifier and Deposits[identifier]
    if not d or d.state ~= "enroute" or d.busy then return fail("no_pending_deposit") end

    if type(coords) ~= "table" then return fail("invalid_atm") end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return fail("invalid_atm") end

    local hash = math.floor(tonumber(model) or 0) & 0xFFFFFFFF
    if not atmModels[hash] then return fail("invalid_atm") end

    -- The player's real position must be at the claimed ATM
    if not isNearATM(src, x, y, z) then
        return fail("atm_too_far")
    end

    local business = GetBusiness(d.businessId)
    if not business then return fail("not_found") end

    -- Hidden flag roll against the suspicion label at this moment
    local label = GetSuspicionLabel(business.suspicion)
    local flagged = math.random(1, 100) <= (Config.BankDeposit.FlagChance[label.name] or 0)
    local clearsAt = os.time() + Config.BankDeposit.ProcessingTime * 60

    d.busy = true
    local ok, affected = pcall(MySQL.update.await,
        "UPDATE moneywash_deposits SET state = 'processing', flagged = ?, x = ?, y = ?, z = ?, clears_at = ? " ..
        "WHERE identifier = ? AND state = 'enroute'",
        { flagged and 1 or 0, x, y, z, clearsAt, identifier })
    d.busy = false

    if not ok or not affected or affected < 1 then return fail("database_error") end

    d.state, d.flagged = "processing", flagged
    d.x, d.y, d.z, d.clearsAt = x, y, z, clearsAt

    if flagged then
        SendDepositFlagNotification(identifier, d.amount, vector3(x, y, z))
    end

    _API.SendNotification(src,
        string.format(locale("notification.deposit_submitted"), Config.BankDeposit.ProcessingTime), "success")

    return { success = true, remainingSeconds = remainingSeconds(d) }
end)

--- -------------------------------------------------------------------------
--- POLICE CALLBACKS
--- -------------------------------------------------------------------------

local function isDepositReviewer(src)
    local job = _API.Player.GetJob(src)
    if not job then return false end
    for _, name in ipairs(Config.Police.Jobs) do
        if job.name == name then
            return (job.grade or 0) >= Config.Police.DepositReviewMinGrade
        end
    end
    return false
end

local function officerNearDeposit(src, d)
    if not d.x or not d.y or not d.z then return false end
    return isNearATM(src, d.x, d.y, d.z)
end

--- Flagged, still-processing deposits at the ATM the officer is standing at.
lib.callback.register("t1ger_moneywash:server:getFlaggedDeposits", function(src)
    if not isDepositReviewer(src) then return {} end

    local list = {}
    for _, d in pairs(Deposits) do
        if d.state == "processing" and d.flagged and officerNearDeposit(src, d) then
            list[#list + 1] = {
                ref              = d.businessId,
                amount           = d.amount,
                remainingSeconds = remainingSeconds(d),
            }
        end
    end
    return list
end)

--- Confiscation: the money vanishes.
lib.callback.register("t1ger_moneywash:server:confiscateDeposit", function(src, ref)
    if not isDepositReviewer(src) then return fail("invalid_job") end

    for _, d in pairs(Deposits) do
        if d.businessId == ref then
            if d.state ~= "processing" or not d.flagged or d.busy then return fail("not_flagged") end
            if not officerNearDeposit(src, d) then return fail("atm_too_far") end

            d.busy = true
            local ok, affected = pcall(MySQL.update.await,
                "DELETE FROM moneywash_deposits WHERE identifier = ? AND state = 'processing'", { d.identifier })
            d.busy = false

            if not ok or not affected or affected < 1 then return fail("database_error") end

            Deposits[d.identifier] = nil

            local owner = onlineSource(d.identifier)
            if owner then
                TriggerClientEvent("t1ger_moneywash:client:bankDepositEnded", owner)
                _API.SendNotification(owner, locale("notification.deposit_confiscated"), "error")
            end

            return { success = true, amount = d.amount }
        end
    end

    return fail("no_pending_deposit")
end)