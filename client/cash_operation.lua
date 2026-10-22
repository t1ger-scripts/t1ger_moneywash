--- Launder and withdraw flow: ask the server for the limit, ask for an amount,
--- run the cash counter, then the server does the real work.
--- The counter is only a visual: money moves in the last server call, and only there.

local CALLBACK = {
    limits = "t1ger_moneywash:server:cashOperation:limits",
    run    = "t1ger_moneywash:server:cashOperation:run",
}

local busy = false -- Blocks a second start while the dialog or a server call is open

--- Cash counter settings of an operation, from its config block.
---@param operation "launder"|"withdraw"
---@return { StackCount?: integer, AutoMoveToRight?: boolean }
local function counterSettings(operation)
    local config = operation == "launder" and Config.Laundering or Config.BankDeposit

    return config.CashCounter or {}
end

--- Limits, amount dialog, cash counter, then the server does the work.
--- The player is told by the server's own events (money laundered, deposit started).
---@param businessId integer
---@param operation "launder"|"withdraw"
local function perform(businessId, operation)
    local limits = ServerRequest(CALLBACK.limits, businessId, operation)
    if not limits.success then return NotifyError(limits.reason) end

    local amount = AskCashAmount(operation, limits.data) -- menu.lua, nil if closed
    if not amount then return end

    local settings = counterSettings(operation)

    local counted = OpenCashCounter({
        amount          = amount,
        stackCount      = settings.StackCount,
        autoMoveToRight = settings.AutoMoveToRight,
    })
    if not counted then return end -- Closed, died or busy: nothing happened, nothing to undo

    local result = ServerRequest(CALLBACK.run, businessId, operation, amount)
    if not result.success then NotifyError(result.reason) end
end

--- Starts a launder or a withdraw at a business.
---@param businessId integer
---@param operation "launder"|"withdraw"
function StartCashOperation(businessId, operation)
    if busy then return end

    busy = true
    local ok, err = pcall(perform, businessId, operation)
    busy = false

    if not ok then DebugPrint("cash_operation", "failed:", err) end
end