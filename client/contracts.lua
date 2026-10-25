--- Launder contracts (client): the payphone target, the shift and its drops.
--- The server owns the shift, this file only asks and shows.

local SERVER = "t1ger_moneywash:server:contracts:"

-- Animations of the deal: both of them talk while the bar runs, then the money changes hands
local NEGOTIATE = { dict = "misscarsteal4@actor", clip = "actor_berating_loop" } -- Played by the player while the bar runs
local PICKUP = { dict = "random@domestic", clip = "pickup_low" }                 -- Played when taking the cash back
local HANDOFF = { dict = "mp_common", player = "givetake1_a", contact = "givetake1_b", time = 1800 }
local LEAVE_TIME = 8 -- Seconds the contact walks away before disappearing

local cfg = Config.Contracts

---@type boolean True while the player is on a shift
local onShift = false

---@class ContractDrop
---@field coords vector4
---@field model string
---@field scenario string
---@field blip? integer
---@field ped? integer Local contact ped, only while the player is near
---@field spawning? boolean
---@field busy? boolean A handover is running

---@class ContractBetrayal
---@field ped integer The contact that ran off with the cash
---@field amount integer Dirty cash it holds
---@field mode "flee"|"attack"
---@field endsAt integer GetGameTimer() value the cash is gone for good
---@field blip? integer
---@field prop? integer Cash dropped by the dead contact
---@field picking? boolean

---@type ContractDrop|nil The drop the player is heading to
local drop = nil

---@type ContractBetrayal|nil The contact the player has to put down
local betrayal = nil

local TARGET_NAME = "t1ger_moneywash:contact"
local CASH_TARGET_NAME = "t1ger_moneywash:cash"

---@type table<integer, boolean> Contacts walking away after a handover
local leavingPeds = {}

--- Takes the contact from the drop and removes its target option.
---@param current ContractDrop
---@return integer|nil ped
local function detachContact(current)
    local ped = current.ped
    if not ped then return nil end

    current.ped = nil
    _API.Target.RemoveLocalEntity(ped, { names = { TARGET_NAME }, labels = { locale("target.contact_handover") } })

    return ped
end

--- Removes the blip and the contact of the current drop.
local function clearDrop()
    local current = drop
    if not current then return end

    drop = nil

    if current.blip and DoesBlipExist(current.blip) then RemoveBlip(current.blip) end
    DeletePed(detachContact(current))
end

--- Applies the blip settings of Config.Contracts.Blip to a blip.
---@param blip integer
---@param settings table
local function styleBlip(blip, settings)
    SetBlipSprite(blip, settings.Sprite)
    SetBlipDisplay(blip, settings.Display)
    SetBlipScale(blip, settings.Scale)
    SetBlipColour(blip, settings.Color)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(settings.Label)
    EndTextCommandSetBlipName(blip)
end

--- Marks the drop on the map with a route.
---@param coords vector4
---@return integer blip
local function createDropBlip(coords)
    local settings = cfg.DropBlip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    styleBlip(blip, settings)

    if settings.Route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, settings.RouteColor or settings.Color)
    end

    return blip
end

--- Deletes a ped after a delay, or at once.
---@param ped integer
---@param seconds integer
local function removePedLater(ped, seconds)
    if seconds <= 0 then return DeletePed(ped) end

    leavingPeds[ped] = true

    SetTimeout(seconds * 1000, function()
        leavingPeds[ped] = nil
        DeletePed(ped)
    end)
end

--- Removes the contact that ran off, its blip and the cash it dropped.
---@param delay integer Seconds before the contact itself disappears
local function clearBetrayal(delay)
    local current = betrayal
    if not current then return end

    betrayal = nil

    if current.blip and DoesBlipExist(current.blip) then RemoveBlip(current.blip) end

    if current.prop and DoesEntityExist(current.prop) then
        _API.Target.RemoveLocalEntity(current.prop, { names = { CASH_TARGET_NAME }, labels = { locale("target.recover_cash") } })
        DeleteEntity(current.prop)
    end

    if DoesEntityExist(current.ped) then removePedLater(current.ped, delay) end
end

local function loseCash(tooSlow)
    _API.ShowNotification(locale(tooSlow and "notification.contract_cash_expired" or "notification.contract_cash_lost"), "error")
    clearBetrayal(0)
    ServerRequest(SERVER .. "forfeitCash")
end

--- Forgets everything of the shift on this client.
local function resetShift()
    onShift = false
    clearDrop()
    clearBetrayal(0)
end

--- Takes the cash back from the dead contact. The server gives the dirty cash back.
---@param current ContractBetrayal
local function recoverCash(current)
    if current.picking then return end
    current.picking = true

    -- Bend down for the cash, then the server gives it back
    lib.requestAnimDict(PICKUP.dict)
    TaskPlayAnim(PlayerPedId(), PICKUP.dict, PICKUP.clip, 2.0, 2.0, -1, 2, 0, false, false, false)
    Wait(800)
    RemoveAnimDict(PICKUP.dict)

    if betrayal ~= current then return end

    local response = ServerRequest(SERVER .. "recoverCash")
    if betrayal ~= current then return end

    if not response.success then
        current.picking = false
        return NotifyError(response.reason)
    end

    _API.ShowNotification(string.format(locale("notification.contract_cash_recovered"), FormatMoney(response.amount)), "success")
    clearBetrayal(5)
end

--- Drops the cash where the contact died, for the player to pick up.
---@param current ContractBetrayal
local function dropCash(current)
    local cash = cfg.Betrayal.Cash
    -- Wait for the body to stop sliding, so the stack doesn't end up under the legs
    local settled = GetGameTimer() + 3000

    while betrayal == current and DoesEntityExist(current.ped) and GetEntitySpeed(current.ped) > 0.2 and GetGameTimer() < settled do
        Wait(100)
    end

    if betrayal ~= current or not DoesEntityExist(current.ped) then return end

    -- Beside the body, on the side of the player, so the body never covers the target
    local body, player = GetEntityCoords(current.ped), GetEntityCoords(PlayerPedId())
    local dx, dy = player.x - body.x, player.y - body.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.1 then dx, dy, length = 1.0, 0.0, 1.0 end

    local coords = vec3(body.x + dx / length * 1.4, body.y + dy / length * 1.4, body.z)

    lib.requestModel(cash.Model)
    if betrayal ~= current then return end

    local prop = CreateObject(GetHashKey(cash.Model), coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(GetHashKey(cash.Model))
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)

    current.prop = prop

    _API.Target.AddLocalEntity(prop, {
        {
            name        = CASH_TARGET_NAME,
            icon        = cash.Target.Icon,
            label       = locale("target.recover_cash"),
            distance    = cash.Target.Distance,
            canInteract = function()
                return betrayal == current and not current.picking
            end,
            onSelect    = function()
                recoverCash(current)
            end,
        },
    })
end

--- Watches the contact that ran off: drops the cash when it dies, ends it when the time is up.
---@param current ContractBetrayal
local function watchBetrayal(current)
    CreateThread(function()
        while betrayal == current do
            if not DoesEntityExist(current.ped) then return loseCash() end

            if not current.prop and IsPedDeadOrDying(current.ped, true) then
                dropCash(current)
            elseif not current.prop then
                -- Keeps the contact on the run (or on the attack) if its task ended
                local player = PlayerPedId()

                if current.mode == "flee" and not IsPedFleeing(current.ped) then
                    TaskSmartFleePed(current.ped, player, 1000.0, -1, false, false)
                elseif current.mode == "attack" and not IsPedInCombat(current.ped, player) then
                    TaskCombatPed(current.ped, player, 0, 16)
                end
            end

            if betrayal == current and GetGameTimer() >= current.endsAt then
                -- A contact that was put down in time: the player was just too slow
                return loseCash(current.prop ~= nil or IsPedDeadOrDying(current.ped, true))
            end

            Wait(500)
        end
    end)
end

--- The contact keeps the cash: it flees or attacks, and the player has to put it down.
---@param current ContractDrop
---@param result { mode: "flee"|"attack", weapon: string, amount: integer, seconds: integer }
local function startBetrayal(current, result)
    local ped = detachContact(current)
    clearDrop()
    clearBetrayal(0)

    if not ped or not DoesEntityExist(ped) then return loseCash() end

    local settings = cfg.Betrayal
    local player = PlayerPedId()

    betrayal = { ped = ped, amount = result.amount, mode = result.mode, endsAt = GetGameTimer() + result.seconds * 1000 }

    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityInvincible(ped, false)
    SetEntityMaxHealth(ped, settings.Health)
    SetEntityHealth(ped, settings.Health)
    -- A dead contact drops nothing of its own: the stack is the only cash
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedMoney(ped, 0)

    if result.mode == "attack" then
        GiveWeaponToPed(ped, GetHashKey(result.weapon), 100, false, true)
        SetPedCombatAttributes(ped, 46, true)
        SetPedFleeAttributes(ped, 0, false)
        TaskCombatPed(ped, player, 0, 16)
    else
        TaskSmartFleePed(ped, player, 1000.0, -1, false, false)
    end

    SetPedKeepTask(ped, true)

    betrayal.blip = AddBlipForEntity(ped)
    styleBlip(betrayal.blip, settings.Blip)

    if Config.PedReactions.Enable then PedSpeak(ped, Config.PedReactions.ContactBetray) end

    _API.ShowNotification(locale(result.mode == "attack" and "notification.contract_betrayed_attack" or "notification.contract_betrayed_flee"), "error")
    watchBetrayal(betrayal)
end

--- Lets the contact walk away after a handover, and removes it a few seconds later.
---@param current ContractDrop
local function dismissContact(current)
    local ped = detachContact(current)
    if not ped then return end

    leavingPeds[ped] = true
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    TaskWanderStandard(ped, 10.0, 10)

    SetTimeout(LEAVE_TIME * 1000, function()
        leavingPeds[ped] = nil
        DeletePed(ped)
    end)
end

--- Makes the deal with the contact. The progress bar is the negotiation and can be cancelled.
--- When it ends the server decides: a clean deal plays the handoff, a betrayal skips it.
---@param current ContractDrop
local function handOverCash(current)
    if current.busy then return end
    current.busy = true

    local started = ServerRequest(SERVER .. "beginHandover")
    if drop ~= current then return end

    if not started.success then
        current.busy = false

        if started.reason == "no_contract_shift" then resetShift() end

        -- "shift_over" is announced by the server's own shift ended message
        if started.reason ~= "shift_over" then NotifyError(started.reason) end

        return
    end

    local player, contact = PlayerPedId(), current.ped

    lib.requestAnimDict(NEGOTIATE.dict)
    lib.requestAnimDict(HANDOFF.dict)

    -- Both of them talk with their hands while the bar runs
    if contact then
        TaskTurnPedToFaceEntity(player, contact, 600)
        Wait(600)
    end

    local completed = ProgressBar({
        duration     = started.duration,
        label        = locale("progress.contract_handover"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
        anim         = { dict = NEGOTIATE.dict, clip = NEGOTIATE.clip, flag = 49 },
    })

    RemoveAnimDict(NEGOTIATE.dict)

    -- Cancelled: nothing was taken, the player can start over
    if not completed then
        RemoveAnimDict(HANDOFF.dict)
        ServerRequest(SERVER .. "cancelHandover")

        if drop == current then current.busy = false end

        return
    end

    local response = ServerRequest(SERVER .. "completeHandover")

    if drop ~= current then return RemoveAnimDict(HANDOFF.dict) end

    if not response.success then
        RemoveAnimDict(HANDOFF.dict)
        current.busy = false

        -- "shift_over" is announced by the server's own shift ended message
        if response.reason ~= "shift_over" then NotifyError(response.reason) end

        return
    end

    -- The money changes hands whatever the outcome. The server settles the cash in the middle of the animation.
    contact = current.ped

    if contact and DoesEntityExist(contact) then
        TaskPlayAnim(contact, HANDOFF.dict, HANDOFF.contact, 8.0, -8.0, HANDOFF.time, 48, 0, false, false, false)
        if not response.betrayed and Config.PedReactions.Enable then PedSpeak(contact, Config.PedReactions.ContactThanks) end
    end

    TaskPlayAnim(PlayerPedId(), HANDOFF.dict, HANDOFF.player, 8.0, -8.0, HANDOFF.time, 48, 0, false, false, false)

    Wait(response.delay)

    if not response.betrayed then
        _API.ShowNotification(
            string.format(locale("notification.contract_handover"), FormatMoney(response.amount), FormatMoney(response.paid)),
            "success"
        )
    end

    Wait(math.max(HANDOFF.time - response.delay, 0))

    StopAnimTask(PlayerPedId(), HANDOFF.dict, HANDOFF.player, -8.0)
    RemoveAnimDict(HANDOFF.dict)

    if drop ~= current then return end

    -- The handoff is done: now the contact turns, or walks away
    if response.betrayed then return startBetrayal(current, response) end

    dismissContact(current)
    clearDrop()
end

--- Shows the contact to a player who is near: spawns it, turns the route off and greets once.
--- The margin on the way out stops the ped flickering at the edge. Runs until the drop is gone.
---@param current ContractDrop
local function watchDrop(current)
    local contacts = cfg.Contact
    local coords = vec3(current.coords.x, current.coords.y, current.coords.z)
    local greeted = false

    CreateThread(function()
        while drop == current do
            local distance = #(GetEntityCoords(PlayerPedId()) - coords)
            local isNear = distance <= (current.ped and contacts.SpawnDistance + 5.0 or contacts.SpawnDistance)

            if isNear and not current.ped and not current.spawning then
                current.spawning = true
                SetBlipRoute(current.blip, false)

                CreateThread(function()
                    while not _Target do Wait(100) end

                    local ped = SpawnStaticPed(current.model, current.coords, current.scenario)
                    current.spawning = false

                    if drop ~= current then return DeletePed(ped) end

                    current.ped = ped
                    _API.Target.AddLocalEntity(ped, {
                        {
                            name        = TARGET_NAME,
                            icon        = contacts.Target.Icon,
                            label       = locale("target.contact_handover"),
                            distance    = contacts.Target.Distance,
                            canInteract = function()
                                return drop == current and not current.busy
                            end,
                            onSelect    = function()
                                handOverCash(current)
                            end,
                        },
                    })
                end)
            elseif not isNear and current.ped then
                DeletePed(detachContact(current))
            end

            if current.ped and not greeted and distance <= contacts.GreetingDistance then
                greeted = true
                if Config.PedReactions.Enable then PedSpeak(current.ped, Config.PedReactions.ContactGreeting) end
            end

            Wait(1000)
        end
    end)
end

--- True while the player is on a shift.
---@return boolean
function IsContractShiftActive()
    return onShift
end

--- Asks the server to start a shift.
function StartContractShift()
    local response = ServerRequest(SERVER .. "startShift")

    if not response.success then
        if response.reason == "contract_cooldown" then
            return _API.ShowNotification(string.format(locale("notification.contract_cooldown"), response.remaining or 0), "error")
        end

        return NotifyError(response.reason)
    end

    onShift = true
    _API.ShowNotification(locale("notification.contract_started"), "success")
end

--- Ends the shift after a confirmation. Used by the payphone menu and the end command.
function EndContractShift()
    if not onShift then return NotifyError("no_contract_shift") end
    if not ConfirmEndShift(cfg.Shift.Cooldown) then return end

    local response = ServerRequest(SERVER .. "endShift")

    if not response.success then
        if response.reason == "no_contract_shift" then resetShift() end

        return NotifyError(response.reason)
    end

    resetShift()
    _API.ShowNotification(string.format(locale("notification.contract_ended"), response.cooldown or 0), "inform")
end

--- The server sent the player to a new drop.
RegisterNetEvent("t1ger_moneywash:client:contractDropAssigned", function(payload)
    if not onShift or type(payload) ~= "table" then return end

    clearDrop()
    drop = { coords = payload.coords, model = payload.model, scenario = payload.scenario }
    drop.blip = createDropBlip(payload.coords)
    watchDrop(drop)

    _API.ShowNotification(string.format(locale("notification.contract_drop"), math.ceil(payload.seconds / 60)), "inform")
end)

--- The server ended the shift without the player asking.
RegisterNetEvent("t1ger_moneywash:client:contractShiftEnded", function(reason)
    resetShift()

    local key = ({
        died          = "notification.contract_ended_died",
        missed        = "notification.contract_ended_missed",
        no_dirty_cash = "notification.contract_ended_no_cash",
    })[reason]

    if key then _API.ShowNotification(locale(key), "inform") end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    clearDrop()
    clearBetrayal(0)
    for ped in pairs(leavingPeds) do DeletePed(ped) end
end)

if cfg.EndCommand then
    RegisterCommand(cfg.EndCommand, EndContractShift, false)
end

CreateThread(function()
    while not _Target do Wait(100) end

    _API.Target.AddModel(cfg.Payphone.Models, {
        {
            name        = "t1ger_moneywash:payphone",
            icon        = cfg.Payphone.Target.Icon,
            label       = locale("target.payphone"),
            distance    = cfg.Payphone.Target.Distance,
            canInteract = function()
                return not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect    = function()
                OpenContractsMenu()
            end,
        },
    })
end)

-- TEMP: starts a shift without a payphone. Delete when done testing.
RegisterCommand("startshift", function()
    StartContractShift()
end, false)