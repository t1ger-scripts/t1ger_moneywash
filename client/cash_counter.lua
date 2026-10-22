--- Cash counter minigame: a counting machine any script can open with OpenCashCounter.
--- Visual only. It makes no server calls and decides nothing about money, so the
--- caller must do (and check) the real work on its own server once the count is done.

---@class CashCounterOptions
---@field amount number Whole amount to count, at least 1 (required)
---@field stackCount? integer Piles the amount is split into, 1-10 (default 10)
---@field autoMoveToRight? boolean A counted pile moves to the right tray by itself (default false)
---@field currency? string Symbol shown in front of the amounts (default "$")

local SCREEN = "cash-counter"

local MAX_AMOUNT = 9007199254740991 -- Largest whole number the UI can show exactly

---@type promise|nil Resolved when the counter closes
local pending = nil

---@type string|nil Resource that called the export
local caller = nil

--- Checks the options and builds the data the UI needs.
--- Options left out are not sent, so the UI applies its own defaults.
---@param options CashCounterOptions
---@return table|nil payload
---@return string|nil problem What was wrong, for the debug log
local function buildPayload(options)
    if type(options) ~= "table" then return nil, "options must be a table" end

    local amount = options.amount
    if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount > MAX_AMOUNT or amount % 1 ~= 0 then
        return nil, "amount must be a whole number of at least 1"
    end

    local stackCount = options.stackCount
    if stackCount ~= nil then
        if type(stackCount) ~= "number" or stackCount ~= stackCount then return nil, "stackCount must be a number" end
        stackCount = math.max(1, math.min(10, math.floor(stackCount)))
    end

    local autoMoveToRight = options.autoMoveToRight
    if autoMoveToRight ~= nil and type(autoMoveToRight) ~= "boolean" then
        return nil, "autoMoveToRight must be true or false"
    end

    local currency = options.currency
    if currency ~= nil and type(currency) ~= "string" then return nil, "currency must be text" end

    return {
        amount   = amount,
        currency = currency,
        settings = { stackCount = stackCount, autoMoveToRight = autoMoveToRight },
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

    SendNUIMessage({ action = "t1ger_moneywash:cashCounter:close" })
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

    ShowMoneywashUi(SCREEN, "t1ger_moneywash:cashCounter:open", payload)

    CreateThread(function()
        while pending == waiting do
            Wait(500)

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