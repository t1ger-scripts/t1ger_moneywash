-- Timed cash-counter preview. No money moves until the player confirms.
local Pending, ByBusiness, Sessions = {}, {}, {}
local nextBatchId = 0
local Resource = GetCurrentResourceName()

local function cashCounterInteger(value, fallback, minimum, maximum)
    local number = tonumber(value)

    if not number or number ~= number
        or number == math.huge or number == -math.huge then
        number = fallback
    end

    return math.max(minimum, math.min(maximum, math.floor(number)))
end

local function GetCashCounterSettings()
    local config = Config.CashCounter or {}

    return {
        stackCount = cashCounterInteger(
            config.StackCount, 10, 1, 20
        ),
        stackDurationMs = cashCounterInteger(
            config.StackDurationMs, 800, 100, 60000
        ),
        autoMoveToRight = config.AutoMoveToRight == true,
    }
end

local function GetCashCounterBatchDuration(amount, settings)
    settings = settings or GetCashCounterSettings()

    local pileCount = math.min(settings.stackCount, amount)

    return pileCount * settings.stackDurationMs
end

local function failure(reason, data) return { success = false, reason = reason, data = data } end

local function locks(row) return { ("business:%d"):format(row.businessId), "owner:" .. row.identifier } end

function HasPendingCashCounter(businessId) return ByBusiness[businessId] ~= nil end

function IsCashCounterSaveBlocked(businessId)
    local row = ByBusiness[businessId]
    return row ~= nil and row.applied == true
end

local function publicBatch(row)
    if not row then return nil end

    local timeLeft = math.max(0, row.deadline - GetGameTimer())
    local status = row.state

    if status == "counting" and timeLeft == 0 then
        status = "ready"
    end

    return {
        id = row.id,
        amount = row.amount,
        durationMs = row.durationMs,
        remainingMs = status == "counting" and timeLeft or 0,
        status = status,
        settings = row.settings,
    }
end

local function playerBusiness(src, businessId)
    if not IsBusinessStoreReady() then return nil, "not_ready" end
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return nil, "invalid_player" end
    local business = GetBusiness(businessId)
    if not business then return nil, "not_found" end
    if business.identifier ~= identifier then return nil, "not_owner" end
    if business.isClosed then return nil, "business_closed" end
    local location = GetLocationConfig(business.type, business.locationId)
    if not location or not IsPlayerNearCoords(src, location.coords, Config.CashCounter.InteractionDistance) then
        return nil, "too_far"
    end
    return business
end

local function localization()
    local name = (Config.BusinessPortal or {}).Locale or GetConvar("ox:locale", "en")
    if type(name) ~= "string" or not name:match("^[%w_-]+$") then name = "en" end
    local raw = LoadResourceFile(Resource, "locales/" .. name .. ".json")
    if not raw then
        name = "en"; raw = LoadResourceFile(Resource, "locales/en.json")
    end
    local ok, messages = pcall(json.decode, raw or "{}")
    return name, ok and messages or {}
end

local function onlineSource(identifier)
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == identifier then return player.source end
    end
end

local function statusData(src, row)
    local available = 0
    local identifier = _API.Player.GetIdentifier(src)

    if identifier and (not row or identifier == row.identifier) then
        available = _API.Player.GetDirtyMoney(src)
    end

    return {
        available = available,
        batch = publicBatch(row),
    }
end

local function clearPreview(src, row)
    if row.state == "settling" or row.state == "review" or row.working then return false end
    if Pending[row.identifier] == row then Pending[row.identifier] = nil end
    local session = Sessions[src]
    if session and session.batchId == row.id then
        session.batchId = nil; session.result = nil
    end
    return true
end

lib.callback.register("t1ger_moneywash:server:cashCounter:open", function(src, businessId, operation, amount)
    if operation ~= "inject" then
        return failure("unsupported_operation")
    end

    businessId = tonumber(businessId)

    local business, reason = playerBusiness(src, businessId)
    if not business then
        return failure(reason)
    end

    if type(amount) ~= "number"
        or amount ~= amount
        or amount <= 0
        or amount > Config.CashCounter.MaxAmount
        or amount % 1 ~= 0 then
        return failure("invalid_amount")
    end

    local pending = Pending[business.identifier]

    if pending then
        return failure(
            pending.state == "review"
            and "manual_review"
            or "operation_in_progress"
        )
    end

    -- Initial feedback only. Confirmation checks again.
    if not _API.Player.HasDirtyMoney(src, amount) then
        return failure("insufficient_dirty_cash")
    end

    Sessions[src] = {
        identifier = business.identifier,
        businessId = businessId,
        amount = amount,
    }

    local localeName, messages = localization()

    return {
        success = true,
        data = {
            businessId = businessId,
            operation = "inject",
            amount = amount,
            available = _API.Player.GetDirtyMoney(src),
            currency = Config.Currency,
            locale = localeName,
            messages = messages,
            titleKey = "cashCounter.injectTitle",
            successKey = "cashCounter.injected",
            settings = GetCashCounterSettings(),
        },
    }
end)

lib.callback.register("t1ger_moneywash:server:cashCounter:start", function(src, amount)
    local session = Sessions[src]
    if not session or _API.Player.GetIdentifier(src) ~= session.identifier then return failure("invalid_player") end
    if session.batchId then
        local row = session.result or Pending[session.identifier]
        if row and row.id == session.batchId then
            return { success = true, data = statusData(src, row) }
        end
        return failure("operation_in_progress")
    end
    local business, reason = playerBusiness(src, session.businessId)
    if not business then return failure(reason) end
    if type(amount) ~= "number" or amount ~= amount or amount <= 0
        or amount > Config.CashCounter.MaxAmount or amount % 1 ~= 0 then
        return failure("invalid_amount")
    end
    if amount ~= session.amount then
        return failure("invalid_amount")
    end
    if Pending[session.identifier] then return failure("operation_in_progress") end
    -- Early balance check is for feedback; confirm always checks again.
    if not _API.Player.HasDirtyMoney(src, amount) then return failure("insufficient_dirty_cash") end
    nextBatchId = nextBatchId + 1
    local settings = GetCashCounterSettings()
    local duration = GetCashCounterBatchDuration(amount, settings)
    local row = {
        id = nextBatchId,
        identifier = session.identifier,
        businessId = business.id,
        amount = amount,
        durationMs = duration,
        deadline = GetGameTimer() + duration,
        state = "counting",
        settings = settings,
    }
    Pending[row.identifier], session.batchId = row, row.id
    return { success = true, data = statusData(src, row) }
end)

lib.callback.register("t1ger_moneywash:server:cashCounter:status", function(src)
    local session = Sessions[src]
    if not session or _API.Player.GetIdentifier(src) ~= session.identifier then return failure("invalid_player") end
    return { success = true, data = statusData(src, session.result or Pending[session.identifier]) }
end)

-- A settled batch remains locked if saving fails; retry without applying twice.
local function settle(row)
    if row.working or row.state ~= "settling" then return end
    row.working = true
    while IsBusinessSaveInProgress(row.businessId) do Wait(20) end
    local business = GetBusiness(row.businessId)
    if not business or business.identifier ~= row.identifier then
        row.working = false
        print(("[MoneyWash] Cash batch %d cannot settle: business owner changed."):format(row.id))
        return
    end
    if not row.applied then
        local fields, result = BuildCashInjection(business, row.amount)
        if not fields then
            row.working = false; return
        end
        row.result, row.applied = result, true
        UpdateBusinessFields(row.businessId, fields)
    end
    if not SaveBusiness(row.businessId, true) then
        row.nextRetry, row.working = GetGameTimer() + 1000, false
        return
    end
    row.state = "complete"
    Pending[row.identifier], ByBusiness[row.businessId] = nil, nil
    ReleaseCashCounterOwnershipLocks(locks(row))
    for _, session in pairs(Sessions) do
        if session.identifier == row.identifier and session.batchId == row.id then session.result = row end
    end
    PublishCashInjection(onlineSource(row.identifier), row.identifier, row.businessId, row.amount, row.result)
    row.working = false
end

local function resetFailedConfirm(src, row, reason)
    ByBusiness[row.businessId] = nil
    ReleaseCashCounterOwnershipLocks(locks(row))

    row.state = "counting"
    row.working = false

    clearPreview(src, row)

    return failure(reason, statusData(src))
end

lib.callback.register("t1ger_moneywash:server:cashCounter:confirm", function(src, batchId)
    local session = Sessions[src]
    if not session or _API.Player.GetIdentifier(src) ~= session.identifier then return failure("invalid_player") end
    local row = session.result or Pending[session.identifier]
    if not row or row.id ~= batchId or session.batchId ~= batchId then return failure("invalid_batch") end
    if row.state == "complete" or row.state == "settling" then
        return { success = true, data = statusData(src, row) }
    end
    if row.state ~= "counting" or GetGameTimer() < row.deadline then return failure("count_not_ready") end
    if row.working then return failure("operation_in_progress") end
    local business, reason = playerBusiness(src, row.businessId)
    if not business then
        clearPreview(src, row); return failure(reason, statusData(src))
    end
    if not AcquireCashCounterOwnershipLocks(locks(row)) then return failure("operation_in_progress") end
    ByBusiness[row.businessId], row.working = row, true
    -- A previous autosave may yield. Revalidate identity, ownership, distance and
    -- inventory after it completes and immediately before touching money.
    while IsBusinessSaveInProgress(row.businessId) do Wait(20) end
    business, reason = playerBusiness(src, row.businessId)
    if not business or _API.Player.GetIdentifier(src) ~= row.identifier then
        return resetFailedConfirm(src, row, reason or "invalid_player")
    end
    if not GetTierByType(business.type) then
        return resetFailedConfirm(src, row, "invalid_business_config")
    end

    if not _API.Player.HasDirtyMoney(src, row.amount) then
        return resetFailedConfirm(src, row, "insufficient_dirty_cash")
    end

    local before = _API.Player.GetDirtyMoney(src)
    local ok, removed = pcall(_API.Player.RemoveDirtyMoney, src, row.amount)
    if not ok or not removed then
        if _API.Player.GetDirtyMoney(src) < before then
            row.state, row.working = "review", false
            print(("[MoneyWash] Cash batch %d: debit uncertain; administrator review required."):format(row.id))
            return failure("manual_review", statusData(src, row))
        end
        return resetFailedConfirm(src, row, "request_failed")
    end
    row.state, row.working = "settling", false
    local saved, err = pcall(settle, row)
    if not saved then
        row.nextRetry, row.working = GetGameTimer() + 1000, false
        print("[MoneyWash] Cash batch settlement retry: " .. tostring(err))
    end
    return { success = true, data = statusData(src, row) }
end)

lib.callback.register("t1ger_moneywash:server:cashCounter:cancel", function(src)
    local session = Sessions[src]
    if not session or _API.Player.GetIdentifier(src) ~= session.identifier then return failure("invalid_player") end
    local row = Pending[session.identifier]
    if row and row.id == session.batchId then clearPreview(src, row) end
    Sessions[src] = nil
    return { success = true }
end)

CreateThread(function()
    while true do
        Wait(250)
        for _, row in pairs(Pending) do
            if row.state == "settling" and not row.working
                and GetGameTimer() >= (row.nextRetry or 0) then
                local ok, err = pcall(settle, row)
                if not ok then
                    row.working = false
                    print("[MoneyWash] Cash batch settlement retry: " .. tostring(err))
                    Wait(1000)
                end
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    local session = Sessions[src]
    if not session then return end
    local row = Pending[session.identifier]
    if row and row.id == session.batchId then clearPreview(src, row) end
    Sessions[src] = nil
end)
