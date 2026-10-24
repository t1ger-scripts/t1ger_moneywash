--- Cash operations: launder (dirty cash into the Safe) and withdraw (Safe into a cash bag).
--- The cash counter on the client is only a visual. The server decides everything:
--- "limits" gives the amount dialog its maximum, "run" checks again and moves the money.

---@class CashOperationRow An operation that has taken the money and is waiting to be saved
---@field id integer
---@field identifier string Owner identifier
---@field businessId integer
---@field operation "launder"|"withdraw"
---@field amount integer
---@field state "starting"|"settling"|"review"
---@field working? boolean True while taking the money or saving
---@field applied? boolean True once the change is applied to the business in memory (blocks autosave)
---@field persisted? boolean True once the operation's own data is saved, so a retry doesn't save it twice
---@field result? table Launder: label change info from calculateLaunder
---@field bag? table Withdraw: the new cash bag (see cash_bag.lua)
---@field nextRetry? integer GetGameTimer() value before which saving isn't retried

---@type table<string, CashOperationRow> Unfinished operations by owner identifier
local Pending = {}

---@type table<integer, CashOperationRow> The same operations by business id
local ByBusiness = {}

local nextId = 0

--- Builds a failed callback response.
---@param reason string Failure reason, see error.<reason> in the locales
---@return { success: false, reason: string }
local function failure(reason)
    return { success = false, reason = reason }
end

--- Lock keys that keep a business and its owner fixed while an operation is running.
---@param row CashOperationRow
---@return string[]
local function locks(row)
    return { ("business:%d"):format(row.businessId), "owner:" .. row.identifier }
end

--- True while an operation is running for the business (from taking the money until it is saved).
---@param businessId integer
---@return boolean
function HasPendingCashOperation(businessId)
    return ByBusiness[businessId] ~= nil
end

--- True once an operation changed the business in memory but has not saved yet, so autosave must not run.
---@param businessId integer
---@return boolean
function IsCashOperationSaveBlocked(businessId)
    local row = ByBusiness[businessId]
    return row ~= nil and row.applied == true
end

--- Checks that the player may use the handler: store ready, owns the business,
--- no raid, and is near the handler.
---@param src integer Player source
---@param businessId integer
---@return table? business
---@return string? reason not_ready, invalid_player, not_found, not_owner, raid_in_progress or too_far
local function playerBusiness(src, businessId)
    if not IsBusinessStoreReady() then return nil, "not_ready" end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return nil, "invalid_player" end

    local business = GetBusiness(businessId)
    if not business then return nil, "not_found" end
    if business.identifier ~= identifier then return nil, "not_owner" end
    if IsBusinessRaided(businessId) then return nil, "raid_in_progress" end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location or not IsPlayerNearCoords(src, location.coords, Config.HandlerNPC.Target.distance + 2.0) then
        return nil, "too_far"
    end

    return business
end

--- Splits a launder into covered (stock-backed, raid-safe) and exposed (raid-seizable) cash.
--- Step 1: expectedRevenue check (the overage is always exposed)
--- Step 2: stock check (the part of the rest that stock can't support is exposed)
---@param business table
---@param amount integer Gross amount being laundered
---@param tier table
---@return integer covered
---@return integer exposed
local function splitLaunderedCash(business, amount, tier)
    local remaining = math.max(0, tier.expectedRevenue - business.cycleLaundered)
    local withinRevenue = math.min(amount, remaining)
    local overRevenue = amount - withinRevenue

    local stockSupported = math.min(withinRevenue, business.stock * Config.Stock.LaunderDollarsPerUnit)

    return math.floor(stockSupported), math.floor(overRevenue + (withinRevenue - stockSupported))
end

--- What laundering `amount` does to the business: the new Safe, stock, suspicion and totals.
--- Pure calculation, nothing is changed here.
---@param business table
---@param amount integer
---@return table|nil fields Business fields to update, nil if the business has no tier
---@return table|nil result Covered/exposed split and the suspicion label before and after
local function calculateLaunder(business, amount)
    local tier = GetTierByType(business.type)
    if not tier then return nil end

    local covered, exposed = splitLaunderedCash(business, amount, tier)
    local suspicion = math.min(100, business.suspicion + CalculateSuspicionGain(business, amount, tier))

    return {
        stock          = math.max(0, business.stock - GetStockUnitsForAmount(amount)),
        safeCovered    = business.safeCovered + covered,
        safeExposed    = business.safeExposed + exposed,
        suspicion      = suspicion,
        totalLaundered = business.totalLaundered + amount,
        cycleLaundered = business.cycleLaundered + amount,
    }, {
        oldLabel = GetSuspicionLabel(business.suspicion),
        newLabel = GetSuspicionLabel(suspicion),
        covered  = covered,
        exposed  = exposed,
    }
end

--- Side effects of a launder. Runs only after the result is saved, never on a client event.
---@param src integer|nil Owner source, nil if offline
---@param identifier string
---@param businessId integer
---@param amount integer
---@param result table From calculateLaunder
local function publishLaunder(src, identifier, businessId, amount, result)
    local business = GetBusiness(businessId)
    if not business then return end

    RunHook("OnMoneyLaundered", identifier, businessId, business.type, amount, result.covered, result.exposed)

    if src then
        TriggerClientEvent("t1ger_moneywash:client:moneyLaundered", src, amount, result.covered, result.exposed)
    end

    if Config.Reputation.Enable and Config.Reputation.Rewards.launder.enable then
        AwardReputationPoints(src, identifier, Config.Reputation.Rewards.launder.points)
    end

    RollPoliceNotification(business)

    if src and Config.Suspicion.NotifyOnLabelChange and result.newLabel.threshold > result.oldLabel.threshold then
        TriggerClientEvent("t1ger_moneywash:client:suspicionLabelChanged", src, result.newLabel)
    end
end

--- Returns a reason if the owner can't withdraw `amount` from the Safe, otherwise nil.
---@param business table
---@param amount integer
---@return string|nil reason not_ready, insufficient_safe_cash or withdraw_limit
local function withdrawDenied(business, amount)
    if not IsCashBagStoreReady() then return "not_ready" end
    if business.safeCovered + business.safeExposed < amount then return "insufficient_safe_cash" end

    local allowance = GetBagAllowance(business)
    if allowance and amount > allowance then return "withdraw_limit" end
end

--- Returns a reason if the player can't receive a cash bag, otherwise nil.
---@param src integer
---@return string|nil reason inventory_unsupported, request_failed or cannot_carry_bag
local function bagInventoryProblem(src)
    local slots, reason = _API.Inventory.GetItemSlots(src, Config.Withdraw.Item)
    if not slots then
        return reason == "unsupported_inventory" and "inventory_unsupported" or "request_failed"
    end

    if not _API.Inventory.CanCarryItem(src, Config.Withdraw.Item, 1) then return "cannot_carry_bag" end
end

--- Removes `amount` from the Safe in memory (covered first, so the exposed cash stays
--- raidable) and returns the new cash bag. cash_bag.lua saves it (PersistCashBag).
---@param business table
---@param amount integer
---@return table bag
local function withdrawFromSafe(business, amount)
    local covered = math.min(amount, business.safeCovered)
    local exposed = amount - covered

    UpdateBusinessFields(business.id, {
        safeCovered = business.safeCovered - covered,
        safeExposed = business.safeExposed - exposed,
    })

    return {
        owner      = business.identifier,
        businessId = business.id,
        label      = GetBusinessLabel(business),
        amount     = amount,
        exposed    = exposed,
        state      = "carried",
        flagged    = false,
        createdAt  = os.time(),
    }
end

--- What differs between the operations. Everything else in this file is shared.
---@class CashOperation
---@field limits fun(src: integer, business: table): table|nil, string? Data for the amount dialog (max, ...), or nil and a reason
---@field take fun(src: integer, business: table, amount: integer, row: CashOperationRow): string? Takes the money. Nil on success, otherwise a reason ("review" if the debit can't be verified)
---@field persist fun(row: CashOperationRow, business: table): boolean Saves what is specific to the operation
---@field publish fun(src: integer|nil, row: CashOperationRow) Runs after everything is saved

---@type table<string, CashOperation>
local Operations = {}

Operations.launder = {
    limits = function(src, business)
        local dirty = math.floor(_API.Player.GetDirtyMoney(src) or 0)
        if dirty < 1 then return nil, "insufficient_dirty_cash" end

        return { max = math.min(dirty, Config.Laundering.MaxPerBatch) }
    end,

    take = function(src, business, amount, row)
        if amount > Config.Laundering.MaxPerBatch then return "invalid_amount" end
        if not _API.Player.HasDirtyMoney(src, amount) then return "insufficient_dirty_cash" end

        local before = _API.Player.GetDirtyMoney(src)
        local ok, removed = pcall(_API.Player.RemoveDirtyMoney, src, amount)

        if not ok or not removed then
            -- If the cash is gone anyway, don't retry: an administrator has to look at it.
            if _API.Player.GetDirtyMoney(src) < before then return "review" end
            return "request_failed"
        end
    end,

    persist = function(row, business)
        if not row.applied then
            local fields, result = calculateLaunder(business, row.amount)
            if not fields then return false end

            row.result, row.applied = result, true
            UpdateBusinessFields(row.businessId, fields)
        end

        return true -- The business itself is saved by settle
    end,

    publish = function(src, row)
        publishLaunder(src, row.identifier, row.businessId, row.amount, row.result)
    end,
}

Operations.withdraw = {
    limits = function(src, business)
        local denied = withdrawDenied(business, 1) or bagInventoryProblem(src)
        if denied then return nil, denied end

        local safe = business.safeCovered + business.safeExposed
        local allowance = GetBagAllowance(business)

        return {
            max     = allowance and math.min(safe, allowance) or safe,
            exposed = business.safeExposed,
            covered = business.safeCovered,
        }
    end,

    take = function(src, business, amount, row)
        -- Nothing yields between this check and the removal, so it can't race.
        local denied = withdrawDenied(business, amount) or bagInventoryProblem(src)
        if denied then return denied end

        row.bag = withdrawFromSafe(business, amount)
        row.applied = true -- Blocks autosave until the bag is written
    end,

    persist = function(row, business)
        -- The reduced Safe and the ledger row are written in one transaction.
        return PersistCashBag(business, row.bag)
    end,

    publish = function(src, row)
        PublishCashBag(src, row.bag)
    end,
}

--- Saves an operation that has taken the money, then finishes it. On failure it
--- is retried by the loop at the bottom, so the money is never lost to a failed save.
---@param row CashOperationRow
local function settle(row)
    if row.working or row.state ~= "settling" then return end
    row.working = true

    while IsBusinessSaveInProgress(row.businessId) do
        Wait(20)
    end

    local business = GetBusiness(row.businessId)
    if not business or business.identifier ~= row.identifier then
        row.nextRetry, row.working = GetGameTimer() + 5000, false
        print(("[MoneyWash] Cash operation %d cannot settle: business owner changed."):format(row.id))
        return
    end

    local operation = Operations[row.operation]

    if not row.persisted then
        if not operation.persist(row, business) then
            row.nextRetry, row.working = GetGameTimer() + 1000, false
            return
        end

        row.persisted = true
    end

    if not SaveBusiness(row.businessId, true) then
        row.nextRetry, row.working = GetGameTimer() + 1000, false
        return
    end

    Pending[row.identifier], ByBusiness[row.businessId] = nil, nil
    ReleaseCashOperationLocks(locks(row))

    operation.publish(GetOnlineSourceByIdentifier(row.identifier), row)
    row.working = false
end

--- Callback: the most the player can do right now, for the amount dialog. Early feedback
--- only, "run" checks everything again.
---@param src integer
---@param businessId integer
---@param operation "launder"|"withdraw"
---@return { success: boolean, reason?: string, data?: { max: integer, exposed?: integer, covered?: integer } }
lib.callback.register("t1ger_moneywash:server:cashOperation:limits", function(src, businessId, operation)
    local operationType = Operations[operation]
    if not operationType then return failure("unsupported_operation") end

    businessId = tonumber(businessId)
    if not businessId then return failure("not_found") end

    local business, reason = playerBusiness(src, businessId)
    if not business then return failure(reason) end

    local busy = Pending[business.identifier]
    if busy then return failure(busy.state == "review" and "manual_review" or "operation_in_progress") end

    local data, denied = operationType.limits(src, business)
    if not data then return failure(denied) end

    return { success = true, data = data }
end)

--- Callback: checks everything again, takes the money and saves it. Called by the client
--- after the cash counter, but nothing here trusts that it was ever shown.
---@param src integer
---@param businessId integer
---@param operation "launder"|"withdraw"
---@param amount integer
---@return { success: boolean, reason?: string }
lib.callback.register("t1ger_moneywash:server:cashOperation:run", function(src, businessId, operation, amount)
    local operationType = Operations[operation]
    if not operationType then return failure("unsupported_operation") end

    businessId = tonumber(businessId)
    if not businessId then return failure("not_found") end

    if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount % 1 ~= 0 then
        return failure("invalid_amount")
    end

    local business, reason = playerBusiness(src, businessId)
    if not business then return failure(reason) end

    local identifier = business.identifier

    local busy = Pending[identifier]
    if busy then return failure(busy.state == "review" and "manual_review" or "operation_in_progress") end

    nextId = nextId + 1
    ---@type CashOperationRow
    local row = {
        id         = nextId,
        identifier = identifier,
        businessId = businessId,
        operation  = operation,
        amount     = amount,
        state      = "starting",
        working    = true,
    }

    if not AcquireCashOperationLocks(locks(row)) then return failure("operation_in_progress") end
    Pending[identifier], ByBusiness[businessId] = row, row

    --- Gives everything back when nothing was taken.
    local function abort(why)
        Pending[identifier], ByBusiness[businessId] = nil, nil
        ReleaseCashOperationLocks(locks(row))

        return failure(why)
    end

    -- An autosave may be running. Check the player and the business again after it,
    -- right before touching any money.
    while IsBusinessSaveInProgress(businessId) do
        Wait(20)
    end

    business, reason = playerBusiness(src, businessId)
    if not business or _API.Player.GetIdentifier(src) ~= identifier then
        return abort(reason or "invalid_player")
    end

    if not GetTierByType(business.type) then return abort("invalid_business_config") end

    local denied = operationType.take(src, business, amount, row)

    if denied == "review" then
        -- The business stays locked until an administrator has checked it.
        row.state, row.working = "review", false
        print(("[MoneyWash] Cash operation %d: debit uncertain; administrator review required."):format(row.id))
        return failure("manual_review")
    end

    if denied then return abort(denied) end

    row.state, row.working = "settling", false

    local settled, err = pcall(settle, row)
    if not settled then
        row.nextRetry, row.working = GetGameTimer() + 1000, false
        print("[MoneyWash] Cash operation settlement retry: " .. tostring(err))
    end

    return { success = true }
end)

--- Retries saving operations that failed to save (honoring `nextRetry`).
--- Sleeps longer while nothing is pending.
CreateThread(function()
    while true do
        Wait(next(Pending) and 250 or 1000)

        for _, row in pairs(Pending) do
            if row.state == "settling" and not row.working
                and GetGameTimer() >= (row.nextRetry or 0) then
                local ok, err = pcall(settle, row)
                if not ok then
                    row.working = false
                    print("[MoneyWash] Cash operation settlement retry: " .. tostring(err))
                    Wait(1000)
                end
            end
        end
    end
end)