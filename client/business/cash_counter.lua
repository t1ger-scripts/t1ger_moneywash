local opening = false    -- true while the counter is opening or closing; blocks re-entry
local confirming = false -- true while a confirm request is in flight; blocks double confirms

---@class CashCounterResponse
---@field success boolean
---@field reason? string Error key, matches `cashCounter.errors.<reason>` in the locales
---@field data? table Payload returned by the server on success

--- Calls a `t1ger_moneywash:server:cashCounter:<name>` server callback.
--- Never throws: a failed call or a non-table reply becomes `request_failed`.
---@param name string Callback suffix: "open", "start", "status", "confirm" or "cancel"
---@param ... any Arguments forwarded to the server callback
---@return CashCounterResponse
local function serverRequest(name, ...)
    local ok, response = pcall(lib.callback.await, "t1ger_moneywash:server:cashCounter:" .. name, false, ...)
    if not ok or type(response) ~= "table" then
        return { success = false, reason = "request_failed" }
    end
    return response
end

--- Shows a cash counter error notification.
--- Falls back to the `request_failed` message when the reason has no locale entry.
---@param reason? string Error key, defaults to "request_failed"
local function ShowCashCounterError(reason)
    local key = "cashCounter.errors." .. (reason or "request_failed")
    local message = locale(key)

    if type(message) ~= "string" or message == key then
        message = locale("cashCounter.errors.request_failed")
    end

    _API.ShowNotification(message, "error", {})
end

--- Opens the cash counter UI after the server validates the request.
--- The client-side amount check is only for early feedback; the server re-checks everything.
---@param businessId number
---@param amount number Whole dirty cash amount, from 1 to Config.CashCounter.MaxAmount
---@param operation? string Cash operation, defaults to "inject"
---@return boolean opened False if the UI is busy, the amount is invalid, or the server refused
function OpenCashCounter(businessId, amount, operation)
    if opening or confirming then return false end

    amount = tonumber(amount)

    if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > Config.CashCounter.MaxAmount then
        ShowCashCounterError("invalid_amount")
        return false
    end

    if not BeginMoneywashUi("cash-counter") then
        return false
    end

    opening = true

    local response = serverRequest("open", businessId, operation or "inject", amount)

    if not response.success or not response.data then
        opening = false
        CloseMoneywashUi("cash-counter")
        ShowCashCounterError(response.reason)
        return false
    end

    ShowMoneywashUi("cash-counter", "t1ger_moneywash:cashCounter:open", response.data)

    opening = false
    return true
end
exports("OpenCashCounter", OpenCashCounter)

--- NUI: the player started counting a batch. Forwards the amount to the server.
---@param data { amount: number }
---@param cb fun(response: CashCounterResponse)
RegisterNUICallback("t1ger_moneywash:cashCounter:start", function(data, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" or type(data) ~= "table" then
        cb({ success = false, reason = "ui_closed" })
        return
    end
    cb(serverRequest("start", data.amount))
end)

--- NUI: the player confirmed a finished batch. The server takes the dirty cash and
--- settles it into the business. The UI closes whether or not the server accepts it.
---@param data { batchId: number }
---@param cb fun(response: CashCounterResponse)
RegisterNUICallback("t1ger_moneywash:cashCounter:confirm", function(data, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" or type(data) ~= "table" then
        cb({ success = false, reason = "ui_closed" })
        return
    end

    if confirming then
        cb({success = false, reason = "operation_in_progress"})
        return
    end

    confirming = true

    local response = serverRequest("confirm", data.batchId)

    SendNUIMessage({action = "t1ger_moneywash:cashCounter:close"})

    CloseMoneywashUi("cash-counter")

    cb(response)

    if not response.success then
        ShowCashCounterError(response.reason)
    end

    serverRequest("cancel")

    confirming = false
end)

--- NUI: the UI asks for the current dirty cash balance and batch state.
---@param _ table Unused
---@param cb fun(response: CashCounterResponse)
RegisterNUICallback("t1ger_moneywash:cashCounter:status", function(_, cb)
    if GetMoneywashUiScreen() ~= "cash-counter" then
        cb({ success = false, reason = "ui_closed" })
        return
    end
    cb(serverRequest("status"))
end)

--- NUI: the player closed the counter without confirming. Cancels the server preview.
--- `opening` stays true meanwhile so the counter can't be reopened mid-close.
---@param _ table Unused
---@param cb fun(response: { success: boolean })
RegisterNUICallback("t1ger_moneywash:cashCounter:close", function(_, cb)
    opening = true
    SendNUIMessage({action = "t1ger_moneywash:cashCounter:close",})
    CloseMoneywashUi("cash-counter")
    cb({ success = true })
    serverRequest("cancel")
    opening = false
end)