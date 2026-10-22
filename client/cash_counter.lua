--- Cash counter minigame: a counting machine any script can open with OpenCashCounter.
--- Visual only. It makes no server calls and decides nothing about money, so the
--- caller must do (and check) the real work on its own server once the count is done.

---@class CashCounterOptions
---@field amount number Whole amount to count, at least 1 (required)
---@field stackCount? integer Piles the amount is split into, 1-10 (default Config.CashCounter.StackCount)
---@field autoMoveToRight? boolean A counted pile moves to the right tray by itself (default Config.CashCounter.AutoMoveToRight)
---@field currency? string Symbol shown in front of the amounts (default "$")

local SCREEN = "cash-counter"

local MESSAGE = {
    open  = "t1ger_moneywash:cashCounter:open",
    close = "t1ger_moneywash:cashCounter:close",
}

local MAX_AMOUNT = 9007199254740991 -- Largest whole number the UI can show exactly

---@type promise|nil Resolved when the counter closes
local pending = nil

---@type string|nil Resource that called the export
local caller = nil

--- Reads a whole number option, clamped to a range.
---@param value any Nil uses the fallback
---@param fallback number
---@param minimum integer
---@param maximum integer
---@return integer|nil number Nil if the value is not a number
local function clampedInteger(value, fallback, minimum, maximum)
    if value == nil then value = fallback end
    if type(value) ~= "number" or value ~= value then return nil end

    return math.max(minimum, math.min(maximum, math.floor(value)))
end

--- Checks the options and builds the data the UI needs.
---@param options CashCounterOptions
---@return table|nil payload
---@return string|nil problem What was wrong, for the debug log
local function buildPayload(options)
    if type(options) ~= "table" then return nil, "options must be a table" end

    local amount = options.amount
    if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount > MAX_AMOUNT or amount % 1 ~= 0 then
        return nil, "amount must be a whole number of at least 1"
    end

    local config = Config.CashCounter or {}

    local stackCount = clampedInteger(options.stackCount, config.StackCount or 10, 1, 10)
    if not stackCount then return nil, "stackCount must be a number" end

    local autoMoveToRight = options.autoMoveToRight
    if autoMoveToRight == nil then autoMoveToRight = config.AutoMoveToRight == true end
    if type(autoMoveToRight) ~= "boolean" then return nil, "autoMoveToRight must be true or false" end

    local currency = options.currency
    if currency ~= nil and type(currency) ~= "string" then return nil, "currency must be text" end

    return {
        amount   = amount,
        currency = currency,
        settings = {
            stackCount      = stackCount,
            autoMoveToRight = autoMoveToRight,
        },
    }
end

--- Closes the counter and hands the result to the waiting caller.
--- Does nothing if the counter is not open, so every call resolves exactly once.
---@param ok boolean
---@param reason? string
local function closeCounter(ok, reason)
    if not pending or GetMoneywashUiScreen() ~= SCREEN then return end

    local waiting = pending
    pending, caller = nil, nil

    SendNUIMessage({ action = MESSAGE.close })
    CloseMoneywashUi(SCREEN)

    waiting:resolve({ ok = ok, reason = reason })
end

--- Opens the cash counter and waits until it is closed.
--- Only a visual: whatever the result, the caller still has to do the real work on its server.
---@param options CashCounterOptions
---@return boolean ok true when every pile was counted
---@return string? reason "cancelled" (player closed it), "interrupted" (died, cuffed or a resource stopped),
--- "busy" (another screen is open) or "invalid_input" (bad options)
function OpenCashCounter(options)
    local payload, problem = buildPayload(options)
    if not payload then
        DebugPrint("cash_counter", "invalid options:", problem)
        return false, "invalid_input"
    end

    if not BeginMoneywashUi(SCREEN) then return false, "busy" end

    local waiting = promise.new()
    pending, caller = waiting, GetInvokingResource()

    ShowMoneywashUi(SCREEN, MESSAGE.open, payload)

    CreateThread(function()
        while pending == waiting do
            Wait(250)

            local ped = PlayerPedId()
            if pending == waiting and (IsEntityDead(ped) or IsPedCuffed(ped)) then
                closeCounter(false, "interrupted")
            end
        end
    end)

    local result = Citizen.Await(waiting)

    return result.ok, result.reason
end
exports("OpenCashCounter", OpenCashCounter)

--- NUI: every pile is counted and the cash is put away.
---@param _ table Unused
---@param cb fun(response: { success: boolean })
RegisterNUICallback("t1ger_moneywash:cashCounter:finish", function(_, cb)
    cb({ success = true })
    closeCounter(true)
end)

--- NUI: the player closed the counter before finishing.
---@param _ table Unused
---@param cb fun(response: { success: boolean })
RegisterNUICallback("t1ger_moneywash:cashCounter:close", function(_, cb)
    cb({ success = true })
    closeCounter(false, "cancelled")
end)

--- Close the counter if the resource that opened it, or this one, stops.
AddEventHandler("onResourceStop", function(resource)
    if pending and (resource == caller or resource == GetCurrentResourceName()) then
        closeCounter(false, "interrupted")
    end
end)

-- TEMPORARY: /countcash [amount] [stackCount] [double]
RegisterCommand("countcash", function(_, args)
    if args[3] == "double" then
        CreateThread(function()
            Wait(500)
            local ok, reason = exports[GetCurrentResourceName()]:OpenCashCounter({ amount = 100 })
            print(("[countcash] second call: ok=%s reason=%s"):format(tostring(ok), tostring(reason)))
        end)
    end

    local ok, reason = exports[GetCurrentResourceName()]:OpenCashCounter({
        amount          = tonumber(args[1]) or 12500,
        stackCount      = tonumber(args[2]),
    })

    print(("[countcash] ok=%s reason=%s"):format(tostring(ok), tostring(reason)))
    _API.ShowNotification(("ok=%s reason=%s"):format(tostring(ok), tostring(reason)), ok and "success" or "error", {})
end, false)