-- Server-owned counting. Batches stay in memory during the counting period.
-- Business balances use the resource's existing persistence.
local Pending, ByBusiness, Sessions = {}, {}, {}
local nextBatchId = 0
local Resource = GetCurrentResourceName()

local function failure(reason)
    return { success = false, reason = reason }
end

local function locks(row)
    return {
        ("business:%d"):format(row.businessId),
        "owner:" .. row.identifier
    }
end

function HasPendingCashCounter(businessId)
    return ByBusiness[businessId] ~= nil
end

function IsCashCounterSaveBlocked(businessId)
    local row = ByBusiness[businessId]
    return row ~= nil and row.applied == true
end

local function duration(amount)
    local cfg = Config.CashCounter
    local fraction = math.max(
        0,
        math.min(1, math.log(amount / 15000) / math.log(1000000 / 15000))
    )

    return math.floor(
        cfg.MinDurationMs
        + (cfg.MaxDurationMs - cfg.MinDurationMs) * fraction
    )
end

local function publicBatch(row)
    if not row then return nil end

    return {
        id = row.id,
        amount = row.amount,
        durationMs = row.durationMs,
        remainingMs = row.state == "complete"
            and 0
            or math.max(0, row.deadline - GetGameTimer()),
        status = row.state == "complete"
            and "complete"
            or row.state == "review" and "review" or "counting"
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
    if not location or not IsPlayerNearCoords(
            src,
            location.coords,
            Config.CashCounter.InteractionDistance
        ) then
        return nil, "too_far"
    end

    return business
end

local function localization()
    local name = (Config.BusinessPortal or {}).Locale
        or GetConvar("ox:locale", "en")

    if type(name) ~= "string" or not name:match("^[%w_-]+$") then
        name = "en"
    end

    local raw = LoadResourceFile(Resource, "locales/" .. name .. ".json")
    if not raw then
        name = "en"
        raw = LoadResourceFile(Resource, "locales/en.json")
    end

    local ok, messages = pcall(json.decode, raw or "{}")
    return name, ok and messages or {}
end

local function onlineSource(identifier)
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == identifier then
            return player.source
        end
    end
end

lib.callback.register(
    "t1ger_moneywash:server:cashCounter:open",
    function(src, businessId, operation)
        if operation ~= "inject" then
            return failure("unsupported_operation")
        end

        businessId = tonumber(businessId)
        local business, reason = playerBusiness(src, businessId)
        if not business then return failure(reason) end

        local row = Pending[business.identifier]

        Sessions[src] = {
            identifier = business.identifier,
            businessId = businessId,
            batchId = row and row.id
        }

        local localeName, messages = localization()

        return {
            success = true,
            data = {
                businessId = businessId,
                operation = "inject",
                available = GetDirtyMoney(src),
                currency = Config.Currency,
                locale = localeName,
                messages = messages,
                titleKey = "cashCounter.injectTitle",
                successKey = "cashCounter.injected",
                batch = publicBatch(row)
            }
        }
    end
)

lib.callback.register(
    "t1ger_moneywash:server:cashCounter:start",
    function(src, amount)
        local session = Sessions[src]

        if not session
            or _API.Player.GetIdentifier(src) ~= session.identifier then
            return failure("invalid_player")
        end

        -- Repeated start requests return the same batch.
        if session.batchId then
            local row = session.result or Pending[session.identifier]

            if row and row.id == session.batchId then
                return {
                    success = true,
                    data = {
                        available = GetDirtyMoney(src),
                        batch = publicBatch(row)
                    }
                }
            end

            return failure("operation_in_progress")
        end

        if session.starting then
            return failure("operation_in_progress")
        end

        local business, reason = playerBusiness(src, session.businessId)
        if not business then return failure(reason) end

        if type(amount) ~= "number"
            or amount ~= amount
            or amount <= 0
            or amount > Config.CashCounter.MaxAmount
            or amount % 1 ~= 0 then
            return failure("invalid_amount")
        end

        if Pending[session.identifier] then
            return failure("operation_in_progress")
        end

        if not HasDirtyMoney(src, amount) then
            return failure("insufficient_dirty_cash")
        end

        local row = {
            identifier = session.identifier,
            businessId = business.id,
            amount = amount,
            durationMs = duration(amount),
            state = "counting"
        }

        if not AcquireCashCounterOwnershipLocks(locks(row)) then
            return failure("operation_in_progress")
        end

        session.starting = true
        Pending[row.identifier] = row
        ByBusiness[row.businessId] = row

        local balanceBefore = GetDirtyMoney(src)
        local removed, success = pcall(RemoveDirtyMoney, src, amount)

        if not removed or not success then
            -- If the bridge changed the balance but did not confirm success,
            -- hold this batch for manual review.
            if GetDirtyMoney(src) < balanceBefore then
                row.state = "review"
                row.deadline = GetGameTimer()

                nextBatchId = nextBatchId + 1
                row.id = nextBatchId
                session.batchId = row.id
                session.starting = false

                print(
                    "[MoneyWash] Cash counter debit uncertain; "
                    .. "check the player's balance before restarting the resource."
                )

                return failure("manual_review")
            end

            Pending[row.identifier] = nil
            ByBusiness[row.businessId] = nil
            ReleaseCashCounterOwnershipLocks(locks(row))
            session.starting = false

            return failure("request_failed")
        end

        nextBatchId = nextBatchId + 1
        row.id = nextBatchId
        row.deadline = GetGameTimer() + row.durationMs

        session.batchId = row.id
        session.starting = false

        return {
            success = true,
            data = {
                available = GetDirtyMoney(src),
                batch = publicBatch(row)
            }
        }
    end
)

lib.callback.register(
    "t1ger_moneywash:server:cashCounter:status",
    function(src)
        local session = Sessions[src]

        if not session
            or _API.Player.GetIdentifier(src) ~= session.identifier then
            return failure("invalid_player")
        end

        local row = session.result or Pending[session.identifier]

        return {
            success = true,
            data = {
                available = GetDirtyMoney(src),
                batch = publicBatch(row)
            }
        }
    end
)

local function finish(row)
    if row.working or row.state ~= "counting" then return end

    row.working = true

    -- Let an older business save finish before changing its cached values.
    while IsBusinessSaveInProgress(row.businessId) do
        Wait(20)
    end

    local business = GetBusiness(row.businessId)

    if not business or business.identifier ~= row.identifier then
        row.working = false
        print(
            ("[MoneyWash] Cash batch %d cannot settle: business owner changed.")
            :format(row.id)
        )
        return
    end

    if not row.applied then
        local fields, result = BuildCashInjection(business, row.amount)

        if not fields then
            row.working = false
            return
        end

        row.result = result
        row.applied = true
        UpdateBusinessFields(row.businessId, fields)
    end

    -- Retry a failed save without crediting the safe a second time.
    if not SaveBusiness(row.businessId, true) then
        row.working = false
        return
    end

    row.state = "complete"
    Pending[row.identifier] = nil
    ByBusiness[row.businessId] = nil

    ReleaseCashCounterOwnershipLocks(locks(row))

    for _, session in pairs(Sessions) do
        if session.identifier == row.identifier
            and session.batchId == row.id then
            session.result = row
        end
    end

    PublishCashInjection(
        onlineSource(row.identifier),
        row.identifier,
        row.businessId,
        row.result
    )

    row.working = false
end

CreateThread(function()
    while true do
        Wait(250)

        for _, row in pairs(Pending) do
            if row.state == "counting"
                and not row.working
                and GetGameTimer() >= row.deadline then
                local ok, err = pcall(finish, row)

                if not ok then
                    row.working = false
                    print( "[MoneyWash] Cash batch settlement retry: " .. tostring(err) )
                    Wait(1000)
                end
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    Sessions[source] = nil
end)
