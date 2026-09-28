local opening = false
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

RegisterNUICallback("t1ger_moneywash:cashCounter:status", function(_, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" then
        cb({ success = false, reason = "ui_closed" }); return
    end
    cb(serverRequest("status"))
end)

RegisterNUICallback("t1ger_moneywash:cashCounter:close", function(_, cb)
    -- Closing the presentation does not cancel a server reservation.
    CloseMoneywashUi("cash-counter")
    cb({ success = true })
end)

-- Temporary cash-counter preview command.
local preview
local realServerRequest = serverRequest

serverRequest = function(name, ...)
    -- Normal gameplay always returns to real server callbacks.
    if name == "open" then
        preview = nil
    end

    if not preview then
        return realServerRequest(name, ...)
    end

    if name == "start" and not preview.batch then
        local amount = tonumber((...))

        if not amount or amount ~= amount or amount < 1
            or amount > preview.available or amount % 1 ~= 0 then
            return { success = false, reason = "invalid_amount" }
        end

        local cfg = Config.CashCounter
        local fraction = math.max(
            0,
            math.min(
                1,
                math.log(amount / 15000) / math.log(1000000 / 15000)
            )
        )
        local duration = math.floor(
            cfg.MinDurationMs
            + (cfg.MaxDurationMs - cfg.MinDurationMs) * fraction
        )
        preview.available = preview.available - amount
        preview.startedAt = GetGameTimer()
        preview.batch = {
            id = 1,
            amount = amount,
            durationMs = duration,
            remainingMs = duration,
            status = "counting"
        }
    end

    if preview.batch then
        local batch = preview.batch
        batch.remainingMs = math.max(
            0,
            batch.durationMs - (GetGameTimer() - preview.startedAt)
        )
        batch.status = batch.remainingMs == 0 and "complete" or "counting"
    end

    return {
        success = true,
        data = {
            available = preview.available,
            batch = preview.batch
        }
    }
end

RegisterCommand("testcashcounter", function(_, args)
    local amount = tonumber(args[1]) or 1000000

    if amount ~= amount or amount < 1 or amount > 1000000000 then
        print("Usage: /testcashcounter [amount between 1 and 1000000000]")
        return
    end

    if opening or not BeginMoneywashUi("cash-counter") then
        print("Close the current moneywash UI first.")
        return
    end

    preview = { available = math.floor(amount) }

    local messages = json.decode(
        LoadResourceFile(GetCurrentResourceName(), "locales/en.json") or "{}"
    )
    messages.cashCounter.injectTitle = "Cash counter preview"
    messages.cashCounter.injected = "{amount} counted. Test only."

    ShowMoneywashUi("cash-counter", "t1ger_moneywash:cashCounter:open", {
        businessId = 0,
        operation = "inject",
        available = preview.available,
        currency = Config.Currency or "$",
        locale = "en",
        messages = messages,
        titleKey = "cashCounter.injectTitle",
        successKey = "cashCounter.injected"
    })
end, false)
