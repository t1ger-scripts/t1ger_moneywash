--- Client core: handler NPCs, owner blips and server sync events.
--- Handler NPCs are local peds shown to every player near an owned business.
--- Map blips and the menu are owner-only.

---@type table<number, integer> Handler ped per business, only while the player is near
local HandlerNPCs = {}

---@type table<number, { data: table, coords: vector3, near: boolean }> Watched locations per business
local HandlerPoints = {}

---@type table<number, integer> Map blip per business, owner only
local HandlerBlips = {}

---@type table<number, table> The player's own businesses, synced from the server
local OwnedBusinesses = {}

---@param businessId number
---@return string
local function HandlerTargetName(businessId)
    return ("t1ger_moneywash:handler:%d"):format(businessId)
end

---@param businessId number
---@return string
local function DeliverTargetName(businessId)
    return ("t1ger_moneywash:handler:deliverstock:%d"):format(businessId)
end

---@param businessId number
---@return string
local function RaidTargetName(businessId)
    return ("t1ger_moneywash:handler:raid:%d"):format(businessId)
end

--- Spawns a handler NPC for a business and registers its target options.
---@param data { id: number, type: string, locationId: number }
local function SpawnHandlerNPC(data)
    local businessId = data.id
    if HandlerNPCs[businessId] and DoesEntityExist(HandlerNPCs[businessId]) then return end

    local tier = GetBusinessTier(data.type)
    local location = GetBusinessLocation(data)
    if not tier or not location then return end

    local ped = SpawnStaticPed(tier.npc, location.coords, Config.HandlerNPC.Scenario)
    HandlerNPCs[businessId] = ped

    while not _Target do Wait(100) end

    -- Despawned while we were waiting
    if HandlerNPCs[businessId] ~= ped then return end

    _API.Target.AddLocalEntity(ped, {
        {
            name        = HandlerTargetName(businessId),
            icon        = Config.HandlerNPC.Target.icon or "fa-solid fa-briefcase",
            label       = locale("target.handler_npc"),
            distance    = Config.HandlerNPC.Target.distance or 2.0,
            canInteract = function(entity)
                return OwnedBusinesses[businessId] ~= nil and CanInteractWithHandlerNPC(entity)
            end,
            onSelect    = function()
                OpenHandlerMenu(businessId)
            end,
        },
        {
            name        = DeliverTargetName(businessId),
            icon        = Config.Stock.Mission.Icons.DeliverTarget,
            label       = locale("target.deliver_stock"),
            distance    = Config.Stock.Mission.PickupTargetDistance,
            canInteract = function()
                return IsCarryingStockBox(businessId)
            end,
            onSelect    = function()
                DeliverStock()
            end,
        },
        {
            name        = RaidTargetName(businessId),
            icon        = Config.Police.Raid.Target.icon,
            label       = locale("target.raid_business"),
            distance    = Config.Police.Raid.Target.distance,
            canInteract = function(entity)
                if not Config.Police.Raid.Enable then return false end
                -- Owners can't raid themselves (Config.Debug allows it for testing)
                if OwnedBusinesses[businessId] and not Config.Debug then return false end
                if not IsPoliceJobWithGrade(Config.Police.Raid.MinGrade) then return false end
                return IsEntityValid(entity) and not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect    = function()
                StartRaid(businessId)
            end,
        },
    })

    if Config.Debug then
        print(("[MoneyWash] Handler NPC spawned for business %d (%s)"):format(businessId, data.type))
    end
end

--- Removes a handler NPC and its target options.
---@param businessId number
local function DespawnHandlerNPC(businessId)
    local ped = HandlerNPCs[businessId]
    if not ped then return end

    HandlerNPCs[businessId] = nil

    _API.Target.RemoveLocalEntity(ped, {
        names = { HandlerTargetName(businessId), DeliverTargetName(businessId), RaidTargetName(businessId) }
    })
    DeletePed(ped)

    if Config.Debug then
        print(("[MoneyWash] Handler NPC despawned for business %d"):format(businessId))
    end
end

--- Starts watching a location. Its NPC exists only while the player is nearby (see the watcher loop).
---@param data { id: number, type: string, locationId: number }
local function AddHandlerPoint(data)
    local location = GetBusinessLocation(data)
    if not location then return end

    HandlerPoints[data.id] = {
        data   = data,
        coords = vec3(location.coords.x, location.coords.y, location.coords.z),
        near   = false,
    }
end

--- Stops watching a location and removes its NPC.
---@param businessId number
local function RemoveHandlerPoint(businessId)
    local entry = HandlerPoints[businessId]
    if entry then
        entry.near = false
        HandlerPoints[businessId] = nil
    end
    DespawnHandlerNPC(businessId)
end

--- One loop for all locations, checked once a second.
--- A small margin on the way out stops the NPC flickering at the edge.
CreateThread(function()
    local margin = 5.0

    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local range = Config.HandlerNPC.SpawnDistance or 50.0

        for businessId, entry in pairs(HandlerPoints) do
            local distance = #(playerCoords - entry.coords)
            local isNear = distance <= (entry.near and (range + margin) or range)

            if isNear and not entry.near then
                entry.near = true
                CreateThread(function()
                    SpawnHandlerNPC(entry.data)
                    -- Player left while the ped was still spawning
                    if not entry.near then DespawnHandlerNPC(businessId) end
                end)
            elseif not isNear and entry.near then
                entry.near = false
                DespawnHandlerNPC(businessId)
            end
        end

        Wait(1000)
    end
end)

--- Adds blips for the player's businesses and removes blips for ones they no longer own.
local function RefreshHandlerBlips()
    for businessId, blip in pairs(HandlerBlips) do
        if not OwnedBusinesses[businessId] then
            RemoveMapBlip(blip)
            HandlerBlips[businessId] = nil
        end
    end

    for businessId, data in pairs(OwnedBusinesses) do
        if not HandlerBlips[businessId] then
            local tier = GetBusinessTier(data.type)
            local location = GetBusinessLocation(data)

            if tier and location then
                HandlerBlips[businessId] = CreateMapBlip(
                    location.coords,
                    Config.HandlerNPC.Blip.sprite or 375,
                    Config.HandlerNPC.Blip.display or 4,
                    Config.HandlerNPC.Blip.scale or 0.7,
                    Config.HandlerNPC.Blip.color or 2,
                    ("%s — %s"):format(tier.label, location.brand or tier.label)
                )
            end
        end
    end
end

--- The bridge fires this once the framework has loaded the player.
RegisterNetEvent("t1ger_moneywash:client:playerLoaded", function()
    TriggerServerEvent("t1ger_moneywash:server:playerLoaded")
    OnPlayerLoaded()
end)

--- Public list of every owned location (no owners). Drives NPC spawning for everyone.
---@param list { id: number, type: string, locationId: number }[]
RegisterNetEvent("t1ger_moneywash:client:syncLocations", function(list)
    local incoming = {}
    for _, data in ipairs(list) do incoming[data.id] = data end

    -- Remove locations that are gone or changed
    for businessId, entry in pairs(HandlerPoints) do
        local data = incoming[businessId]
        if not data or data.type ~= entry.data.type or data.locationId ~= entry.data.locationId then
            RemoveHandlerPoint(businessId)
        end
    end

    -- Add new ones
    for businessId, data in pairs(incoming) do
        if not HandlerPoints[businessId] then
            AddHandlerPoint(data)
        end
    end

    if Config.Debug then
        print(("[MoneyWash] Synced %d business locations (all owners)"):format(#list))
    end
end)

--- Initial sync of the player's own businesses on load.
---@param businesses table[]
RegisterNetEvent("t1ger_moneywash:client:syncBusinesses", function(businesses)
    OwnedBusinesses = {}

    for _, business in ipairs(businesses) do
        OwnedBusinesses[business.id] = business
    end

    RefreshHandlerBlips()

    if Config.Debug then
        local own = businesses[1]
        if own then
            print(("[MoneyWash] Your business: #%s (%s, location %s)"):format(own.id, own.type, own.locationId))
        else
            print("[MoneyWash] You do not own a business")
        end
    end
end)

--- The player bought a business.
RegisterNetEvent("t1ger_moneywash:client:businessPurchased", function(businessId, businessType, locationId)
    OwnedBusinesses[businessId] = { id = businessId, type = businessType, locationId = locationId }
    RefreshHandlerBlips()
end)

--- The player transferred a business away.
RegisterNetEvent("t1ger_moneywash:client:businessTransferred", function(businessId)
    OwnedBusinesses[businessId] = nil
    RefreshHandlerBlips()
end)

--- The player received a business from a transfer.
RegisterNetEvent("t1ger_moneywash:client:businessReceived", function(businessId, businessType, locationId)
    OwnedBusinesses[businessId] = { id = businessId, type = businessType, locationId = locationId }
    RefreshHandlerBlips()
end)

--- The player abandoned a business.
RegisterNetEvent("t1ger_moneywash:client:businessAbandoned", function(businessId)
    OwnedBusinesses[businessId] = nil
    RefreshHandlerBlips()
end)

--- An admin removed a business permanently.
RegisterNetEvent("t1ger_moneywash:client:businessRemoved", function(businessId)
    OwnedBusinesses[businessId] = nil
    RefreshHandlerBlips()
    _API.ShowNotification(locale("notification.business_removed"), "error", {})
end)

--- Money was laundered into the safe.
RegisterNetEvent("t1ger_moneywash:client:moneyLaundered", function(amount, covered, exposed)
    NotifyMoneyLaundered(amount, covered, exposed)
end)

--- The suspicion label changed (only sent when it went up).
RegisterNetEvent("t1ger_moneywash:client:suspicionLabelChanged", function(newLabel)
    NotifySuspicionChanged(newLabel)
end)

--- Police alert (suspicion pings and flagged deposits).
RegisterNetEvent("t1ger_moneywash:client:policeAlert", function(alertType, coords, data)
    ShowPoliceAlert(alertType, coords, data)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for businessId in pairs(HandlerPoints) do
        RemoveHandlerPoint(businessId)
    end

    for businessId, blip in pairs(HandlerBlips) do
        RemoveMapBlip(blip)
        HandlerBlips[businessId] = nil
    end
end)

--- Returns the player's owned businesses (local cache).
---@return table<number, table>
exports("GetOwnedBusinesses", function()
    return OwnedBusinesses
end)