--- Launder contracts (client): the payphone target, the shift and its drops.
--- The server owns the shift, this file only asks and shows.

local SERVER = "t1ger_moneywash:server:contracts:"

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

---@type ContractDrop|nil The drop the player is heading to
local drop = nil

local TARGET_NAME = "t1ger_moneywash:contact"

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

--- Marks the drop on the map with a route.
---@param coords vector4
---@return integer blip
local function createDropBlip(coords)
    local settings = cfg.Blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, settings.Sprite)
    SetBlipDisplay(blip, settings.Display)
    SetBlipScale(blip, settings.Scale)
    SetBlipColour(blip, settings.Color)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(settings.Label)
    EndTextCommandSetBlipName(blip)

    if settings.Route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, settings.RouteColor or settings.Color)
    end

    return blip
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

    SetTimeout(cfg.Contacts.LeaveTime * 1000, function()
        leavingPeds[ped] = nil
        DeletePed(ped)
    end)
end

--- Makes the deal with the contact. The server takes the cash when the progress bar starts and
--- pays when it ends, unless the contact has other plans.
---@param current ContractDrop
local function handOverCash(current)
    if current.busy then return end
    current.busy = true

    local started = ServerRequest(SERVER .. "beginHandover")
    if drop ~= current then return end

    if not started.success then
        current.busy = false

        if started.reason == "no_contract_shift" then
            onShift = false
            clearDrop()
        end

        -- "shift_over" is announced by the server's own shift ended message
        if started.reason ~= "shift_over" then NotifyError(started.reason) end

        return
    end

    local deal = cfg.Contacts.Handover
    local player, contact = PlayerPedId(), current.ped

    lib.requestAnimDict(deal.Dict)

    if contact then
        TaskTurnPedToFaceEntity(player, contact, 600)
        Wait(600)
        TaskPlayAnim(contact, deal.Dict, deal.Contact, 8.0, -8.0, started.duration, 49, 0, false, false, false)
    end

    local completed = ProgressBar({
        duration     = started.duration,
        label        = locale("progress.contract_handover"),
        useWhileDead = false,
        canCancel    = false,
        disable      = { move = true, car = true, combat = true },
        anim         = { dict = deal.Dict, clip = deal.Player, flag = 49 },
    })

    RemoveAnimDict(deal.Dict)
    if contact and DoesEntityExist(contact) then StopAnimTask(contact, deal.Dict, deal.Contact, -8.0) end

    -- Interrupted: the server gives the cash back when the deal times out
    if not completed then
        current.busy = false
        return
    end

    local response = ServerRequest(SERVER .. "completeHandover")
    if drop ~= current then return end

    if not response.success then
        current.busy = false
        return NotifyError(response.reason)
    end

    if contact and Config.PedReactions.Enable then PedSpeak(contact, Config.PedReactions.ContactThanks) end

    _API.ShowNotification(
        string.format(locale("notification.contract_handover"), FormatMoney(response.amount), FormatMoney(response.paid)),
        "success"
    )

    dismissContact(current)
    clearDrop()
end

--- Shows the contact to a player who is near: spawns it, turns the route off and greets once.
--- The margin on the way out stops the ped flickering at the edge. Runs until the drop is gone.
---@param current ContractDrop
local function watchDrop(current)
    local contacts = cfg.Contacts
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
                            icon        = contacts.TargetIcon,
                            label       = locale("target.contact_handover"),
                            distance    = contacts.TargetDistance,
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
    if not ConfirmEndShift(cfg.Cooldown) then return end

    local response = ServerRequest(SERVER .. "endShift")

    if not response.success then
        if response.reason == "no_contract_shift" then
            onShift = false
            clearDrop()
        end

        return NotifyError(response.reason)
    end

    onShift = false
    clearDrop()
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
    onShift = false
    clearDrop()

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
    for ped in pairs(leavingPeds) do DeletePed(ped) end
end)

if cfg.EndCommand then
    RegisterCommand(cfg.EndCommand, EndContractShift, false)
end

CreateThread(function()
    while not _Target do Wait(100) end

    _API.Target.AddModel(cfg.Models, {
        {
            name        = "t1ger_moneywash:payphone",
            icon        = cfg.Target.Icon,
            label       = locale("target.payphone"),
            distance    = cfg.Target.Distance,
            canInteract = function()
                return not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect    = function()
                OpenContractsMenu()
            end,
        },
    })
end)