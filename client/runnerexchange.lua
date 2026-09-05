runnerPed, runnerBlip = nil, nil
runnerExchangeActive = false

--- Returns a rough client-side estimate of the player's trust limit, for UI display only.
--- The server independently re-validates this - this is never trusted for the actual transaction.
--- @return number maxAmount
local function GetLocalTrustLimit()
    local fallback = Config.RunnerExchange.AmountLimits.max
    if not Config.Reputation or not Config.Reputation.Enable then return fallback end

    local points = GetPlayerReputationPoints()
    local limit = fallback
    local thresholds = {}

    for k in pairs(Config.RunnerExchange.TrustLimits) do
        table.insert(thresholds, k)
    end
    table.sort(thresholds)

    for _, threshold in ipairs(thresholds) do
        if points >= threshold then
            limit = Config.RunnerExchange.TrustLimits[threshold]
        else
            break
        end
    end

    return limit
end

--- Removes the runner ped, blip, and text UI, and resets local state.
function CleanupRunnerExchange()
    if runnerPed and DoesEntityExist(runnerPed) then
        _API.Target.RemoveLocalEntity(runnerPed, {names = {"t1ger_moneywash:runner:ped"}})
        SetPedAsNoLongerNeeded(runnerPed)
    end
    runnerPed = nil

    if runnerBlip and DoesBlipExist(runnerBlip) then
        RemoveBlip(runnerBlip)
    end
    runnerBlip = nil

    lib.hideTextUI()
    runnerExchangeActive = false
end

--- Opens the amount input dialog and requests a new Runner Exchange session from the server.
function OpenRunnerExchangeMenu()
    if runnerExchangeActive then
        _API.ShowNotification(locale("notification.runnerexchange_already_active"), "error")
        return
    end

    local maxAmount = GetLocalTrustLimit()

    local input = lib.inputDialog(locale("menu_title.runner_exchange"), {
        {
            type = "number",
            label = locale("input.runnerexchange_amount"),
            description = string.format(locale("input.runnerexchange_amount_desc"), Config.Currency, Config.RunnerExchange.AmountLimits.min, Config.Currency, maxAmount),
            required = true,
            min = Config.RunnerExchange.AmountLimits.min,
            max = maxAmount,
        }
    })

    if not input or not input[1] then return end

    RequestRunnerExchange(tonumber(input[1]))
end

--- Requests a Runner Exchange session from the server for the given amount.
--- @param amount number
function RequestRunnerExchange(amount)
    local response = lib.callback.await("t1ger_moneywash:server:requestRunnerExchange", false, amount)

    if not response.success then
        if response.reason == "cooldown" then
            _API.ShowNotification(string.format(locale("notification.runnerexchange_cooldown"), response.remaining), "error")
        elseif response.reason == "not_enough_police" then
            _API.ShowNotification(locale("notification.runnerexchange_not_enough_police"), "error")
        elseif response.reason == "invalid_amount" then
            _API.ShowNotification(string.format(locale("notification.runnerexchange_invalid_amount"), Config.Currency, response.min or 0, Config.Currency, response.max or 0), "error")
        elseif response.reason == "insufficient_cash" then
            _API.ShowNotification(locale("notification.runnerexchange_insufficient_cash"), "error")
        elseif response.reason == "already_active" then
            _API.ShowNotification(locale("notification.runnerexchange_already_active"), "error")
        else
            _API.ShowNotification(locale("notification.runnerexchange_failed"), "error")
        end
        return
    end

    SpawnRunnerPed(response.location, response.model, response.duration)
end

--- Spawns the runner ped at the server-assigned location and starts the countdown.
--- @param location vector4
--- @param model string
--- @param duration number
function SpawnRunnerPed(location, model, duration)
    runnerExchangeActive = true

    lib.requestModel(model)
    runnerPed = CreatePed(4, model, location.x, location.y, location.z - 1.0, location.w, false, true)

    SetEntityAsMissionEntity(runnerPed, true, true)
    SetBlockingOfNonTemporaryEvents(runnerPed, true)
    FreezeEntityPosition(runnerPed, true)
    TaskStartScenarioInPlace(runnerPed, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)

    runnerBlip = CreateMapBlip(location, 1, 4, 0.8, 1, locale("blip.runner_exchange"))
    SetNewWaypoint(location.x, location.y)

    while not _Target do Wait(100) end
    _API.Target.AddLocalEntity(runnerPed, {
        {
            name = "t1ger_moneywash:runner:ped",
            icon = "fa-solid fa-money-bill-transfer",
            label = locale("target.runner_handoff"),
            distance = 2.0,
            onSelect = function()
                AttemptHandoff()
            end
        }
    })

    -- Local countdown display only (cosmetic) - the server independently tracks and enforces the real expiry
    CreateThread(function()
        local remaining = duration
        while runnerExchangeActive and remaining > 0 do
            lib.showTextUI(string.format(locale("textui.runnerexchange_timer"), remaining), {position = "top-center"})
            Wait(1000)
            remaining = remaining - 1
        end
    end)
end

--- Attempts to hand off the cash to the runner. Plays a local progress bar for feel,
--- then asks the server to finalize - the server alone decides success vs hustle.
function AttemptHandoff()
    if not runnerExchangeActive then return end

    local success = ProgressBar({
        duration = 3000,
        label = locale("progress.runnerexchange_handoff"),
        useWhileDead = false,
        canCancel = true,
        disable = {move = true, car = true, combat = true},
        anim = {dict = "mp_common", clip = "givetake1_a"},
    })

    if not success then return end

    local result = lib.callback.await("t1ger_moneywash:server:finalizeRunnerExchange", false)

    if not result.success then
        if result.reason == "too_far" then
            _API.ShowNotification(locale("notification.runnerexchange_too_far"), "error")
            return -- session still active, player can move closer and retry
        elseif result.reason == "expired" then
            _API.ShowNotification(locale("notification.runnerexchange_expired"), "error")
        elseif result.reason == "insufficient_cash" then
            _API.ShowNotification(locale("notification.runnerexchange_insufficient_cash"), "error")
        else
            _API.ShowNotification(locale("notification.runnerexchange_failed"), "error")
        end
        CleanupRunnerExchange()
        return
    end

    if result.outcome == "hustle" then
        _API.ShowNotification(locale("notification.runnerexchange_hustle"), "error", {duration = 6000})
        TriggerRunnerHustle(result.weapon)
    elseif result.outcome == "success" then
        _API.ShowNotification(string.format(locale("notification.runnerexchange_success"), Config.Currency, result.cleanAmount), "success")
        CleanupRunnerExchange()
    end
end

--- Plays out the hustle: the runner arms up and attacks the player.
--- @param weapon string Weapon hash name chosen by the server
function TriggerRunnerHustle(weapon)
    if not runnerPed or not DoesEntityExist(runnerPed) then return end

    -- exchange has concluded server-side - clean up the countdown/blip but keep the ped for the fight
    if runnerBlip and DoesBlipExist(runnerBlip) then
        RemoveBlip(runnerBlip)
    end
    runnerBlip = nil
    lib.hideTextUI()
    runnerExchangeActive = false

    FreezeEntityPosition(runnerPed, false)
    SetEntityInvincible(runnerPed, false)
    ClearPedTasksImmediately(runnerPed)

    GiveWeaponToPed(runnerPed, GetHashKey(weapon), 999, false, true)
    SetCurrentPedWeapon(runnerPed, GetHashKey(weapon), true)
    SetPedCombatAttributes(runnerPed, 46, true)
    TaskCombatPed(runnerPed, PlayerPedId(), 0, 16)

    SetPedAsNoLongerNeeded(runnerPed)
    runnerPed = nil
end

--- Cancels an active Runner Exchange session (costs reputation per config).
RegisterCommand("cancelexchange", function()
    if not runnerExchangeActive then return end

    TriggerServerEvent("t1ger_moneywash:server:cancelRunnerExchange")
    CleanupRunnerExchange()
    _API.ShowNotification(locale("notification.runnerexchange_cancelled"), "inform")
end, false)

--- Server-forced cleanup if a session expires without the client ever calling finalize
--- (e.g. player walked away or alt-tabbed).
RegisterNetEvent("t1ger_moneywash:client:runnerExchangeExpired", function()
    if not runnerExchangeActive then return end
    _API.ShowNotification(locale("notification.runnerexchange_expired"), "error")
    CleanupRunnerExchange()
end)