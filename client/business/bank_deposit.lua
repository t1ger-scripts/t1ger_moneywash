--- ============================================================================
--- Bank Deposit (client)
--- Handles the ATM targets (owner: submit / cancel, police: review flagged
--- deposits). The server owns all state; this file only mirrors it.
--- ============================================================================

---@type { businessId: number, amount: number, state: "enroute"|"processing" }|nil
local deposit = nil
local busy = false -- true while the ATM progress bar or a request is running

--- -------------------------------------------------------------------------
--- STATE FROM SERVER
--- -------------------------------------------------------------------------

---@param data table|nil Public deposit from the server (nil = no deposit)
---@param announce boolean Show the "head to an ATM" notification
local function applyDeposit(data, announce)
    deposit = data

    if data and data.state == "enroute" and announce then
        _API.ShowNotification(
            string.format(locale("notification.deposit_head_to_atm"), math.ceil(data.remainingSeconds / 60)),
            "inform", {})
    end
end

--- Cash counter finished: money left the Safe, the bag is now in hand
RegisterNetEvent("t1ger_moneywash:client:bankDepositStarted", function(data)
    applyDeposit(data, true)
end)

--- Login / resource start: restore any pending deposit
RegisterNetEvent("t1ger_moneywash:client:bankDepositSync", function(data)
    applyDeposit(data, false)
end)

--- Deposit finished in any way (paid, refunded, cancelled, confiscated)
RegisterNetEvent("t1ger_moneywash:client:bankDepositEnded", function()
    applyDeposit(nil, false)
end)

--- Resource restarted while the player is already in game: ask the server for the state
CreateThread(function()
    Wait(2500)
    local data = lib.callback.await("t1ger_moneywash:server:getBankDeposit", false)
    if data then applyDeposit(data, false) end
end)

--- -------------------------------------------------------------------------
--- ATM ACTIONS
--- -------------------------------------------------------------------------

---@param atm number ATM entity handle
local function submitDeposit(atm)
    if busy or not deposit or deposit.state ~= "enroute" then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end

    busy = true

    local coords = GetEntityCoords(atm)
    local model = GetEntityModel(atm)
    local cfg = Config.BankDeposit

    local completed = ProgressBar({
        duration     = cfg.SubmitDuration,
        label        = locale("progress.atm_deposit"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
        anim         = cfg.Animation,
    })

    if completed then
        local result = lib.callback.await("t1ger_moneywash:server:submitBankDeposit", false,
            { x = coords.x, y = coords.y, z = coords.z }, model)

        if result and result.success then
            deposit.state = "processing"
        else
            _API.ShowNotification(locale("notification.error_" .. ((result and result.reason) or "unknown")), "error", {})
        end
    end

    busy = false
end

local function cancelDeposit()
    if busy or not deposit or deposit.state ~= "enroute" then return end

    local confirmed = lib.alertDialog({
        header   = locale("menu.deposit.cancel_title"),
        content  = locale("menu.deposit.cancel_body"),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then return end

    busy = true
    local result = lib.callback.await("t1ger_moneywash:server:cancelBankDeposit", false)
    busy = false

    -- Success is handled by the bankDepositEnded event
    if not (result and result.success) then
        _API.ShowNotification(locale("notification.error_" .. ((result and result.reason) or "unknown")), "error", {})
    end
end

--- -------------------------------------------------------------------------
--- ATM TARGETS
--- -------------------------------------------------------------------------

CreateThread(function()
    while not _Target do Wait(100) end

    local cfg = Config.BankDeposit

    _API.Target.AddModel(cfg.Models, {
        {
            name        = "t1ger_moneywash:atm:deposit",
            icon        = cfg.TargetIcon,
            label       = locale("target.atm_deposit"),
            distance    = cfg.InteractDistance,
            canInteract = function()
                return not busy and deposit ~= nil and deposit.state == "enroute"
            end,
            onSelect    = submitDeposit,
        },
        {
            name        = "t1ger_moneywash:atm:cancel",
            icon        = cfg.TargetIcon,
            label       = locale("target.atm_cancel"),
            distance    = cfg.InteractDistance,
            canInteract = function()
                return not busy and deposit ~= nil and deposit.state == "enroute"
            end,
            onSelect    = cancelDeposit,
        },
        {
            name        = "t1ger_moneywash:atm:review",
            icon        = cfg.PoliceTargetIcon,
            label       = locale("target.atm_review"),
            distance    = cfg.InteractDistance,
            canInteract = function()
                return IsPoliceJobWithGrade(Config.Police.DepositReviewMinGrade)
            end,
            onSelect    = function()
                OpenPoliceATMMenu()
            end,
        },
    })
end)