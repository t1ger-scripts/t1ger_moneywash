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

---@type ContractDrop|nil The drop the player is heading to
local drop = nil

--- Removes the blip and the contact of the current drop.
local function clearDrop()
    local current = drop
    if not current then return end

    drop = nil

    if current.blip and DoesBlipExist(current.blip) then RemoveBlip(current.blip) end
    DeletePed(current.ped)
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
                    local ped = SpawnStaticPed(current.model, current.coords, current.scenario)
                    current.spawning = false

                    if drop == current then current.ped = ped else DeletePed(ped) end
                end)
            elseif not isNear and current.ped then
                DeletePed(current.ped)
                current.ped = nil
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
    if resource == GetCurrentResourceName() then clearDrop() end
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