local opening = false

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

local function serverRequest(name, ...)
    local ok, response = pcall(lib.callback.await, "t1ger_moneywash:server:cashCounter:" .. name, false, ...)
    if not ok or type(response) ~= "table" then return { success = false, reason = "request_failed" } end
    return response
end
--- Reusable presentation entry point. Only server-registered operations are accepted.
--- 'inject' is connected now; future withdrawals can reuse the same screen.
function OpenCashCounter(businessId, operation)
    if opening or not BeginMoneywashUi("cash-counter") then return end
    opening = true
    local response = serverRequest("open", businessId, operation or "inject")
    opening = false
    if not response.success or not response.data then
        CloseMoneywashUi("cash-counter")
        local key = "cashCounter.errors." .. (response.reason or "request_failed")
        _API.ShowNotification(locale(key), "error", {})
        return
    end
    ShowMoneywashUi("cash-counter", "t1ger_moneywash:cashCounter:open", response.data)
end

exports("OpenCashCounter", OpenCashCounter)

RegisterNUICallback("t1ger_moneywash:cashCounter:start", function(data, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" or type(data) ~= "table" then
        cb({ success = false, reason = "ui_closed" }); return
    end
    cb(serverRequest("start", data.amount))
end)

RegisterNUICallback("t1ger_moneywash:cashCounter:confirm", function(data, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" or type(data) ~= "table" then
        cb({ success = false, reason = "ui_closed" })
        return
    end

    cb(serverRequest("confirm", data.batchId))
end)

RegisterNUICallback("t1ger_moneywash:cashCounter:reset", function(data, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" or type(data) ~= "table" then
        cb({ success = false, reason = "ui_closed" })
        return
    end

    cb(serverRequest("reset", data.batchId))
end)

RegisterNUICallback("t1ger_moneywash:cashCounter:status", function(_, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" then
        cb({ success = false, reason = "ui_closed" }); return
    end
    cb(serverRequest("status"))
end)

RegisterNUICallback("t1ger_moneywash:cashCounter:close", function(_, cb)
    serverRequest("cancel")
    CloseMoneywashUi("cash-counter")
    cb({ success = true })
end)

-- Local preview command. No server callback, inventory, or business safe is changed.
local testCounter
local realServerRequest = serverRequest

serverRequest = function(name, ...)
    if name == "open" then
        testCounter = nil
        return realServerRequest(name, ...)
    end

    if not testCounter then
        return realServerRequest(name, ...)
    end

    if name == "cancel" then
        testCounter = nil
        return { success = true }
    end

    local batch = testCounter.batch
    if batch and batch.status == "counting" then
        batch.remainingMs = math.max(0, testCounter.deadline - GetGameTimer())
        if batch.remainingMs == 0 then batch.status = "ready" end
    end

    local value = ...
    if name == "start" then
        local amount = value
        if type(amount) ~= "number" or amount % 1 ~= 0
            or amount < 1 or amount > testCounter.available
            or amount > Config.CashCounter.MaxAmount then
            return { success = false, reason = "invalid_amount" }
        end

        if not batch then
            local duration = GetCashCounterBatchDuration(amount, testCounter.settings)
            testCounter.nextId = testCounter.nextId + 1
            batch = {
                id = testCounter.nextId,
                amount = amount,
                durationMs = duration,
                remainingMs = duration,
                status = "counting",
                settings = testCounter.settings,
            }
            testCounter.batch = batch
            testCounter.deadline = GetGameTimer() + duration
        end

    elseif name == "confirm" then
        if not batch or batch.id ~= value then
            return { success = false, reason = "invalid_batch" }
        end
        if batch.status ~= "ready" then
            return { success = false, reason = "count_not_ready" }
        end

        testCounter.available = testCounter.available - batch.amount
        batch.status = "complete"
        batch.remainingMs = 0

    elseif name == "reset" then
        if not batch or batch.id ~= value then
            return { success = false, reason = "invalid_batch" }
        end
        testCounter.batch = nil
    end

    return {
        success = true,
        data = {
            available = testCounter.available,
            batch = testCounter.batch,
        },
    }
end

RegisterCommand("testcashcounter", function(_, args)
    local balance = args[1] and tonumber(args[1]) or 100000
    if not balance or balance % 1 ~= 0
        or balance < 1 or balance > Config.CashCounter.MaxAmount then
        print("[MoneyWash] Usage: /testcashcounter 100000")
        return
    end

    if not BeginMoneywashUi("cash-counter") then
        print("[MoneyWash] Close the current UI before testing the cash counter.")
        return
    end

    local raw = LoadResourceFile(GetCurrentResourceName(), "locales/en.json")
    local ok, messages = pcall(json.decode, raw or "{}")
    if not ok or type(messages) ~= "table" or type(messages.cashCounter) ~= "table" then
        CloseMoneywashUi("cash-counter")
        print("[MoneyWash] Could not load locales/en.json.")
        return
    end

    messages.cashCounter.injectTitle = "Inject cash (test)"
    messages.cashCounter.injected = "Test complete: {amount} counted. No cash was moved."
    messages.cashCounter.deposited = "TEST COMPLETE"

    testCounter = {
        available = balance,
        nextId = 0,
        settings = GetCashCounterSettings(),
    }

    ShowMoneywashUi("cash-counter", "t1ger_moneywash:cashCounter:open", {
        businessId = 0,
        operation = "inject",
        available = balance,
        currency = Config.Currency,
        locale = "en",
        messages = messages,
        titleKey = "cashCounter.injectTitle",
        successKey = "cashCounter.injected",
        settings = testCounter.settings,
    })
end, false)