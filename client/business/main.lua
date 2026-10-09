--- ============================================================================
--- Business Client Main
--- Handler NPC spawning, target registration and blip management per owned
--- business. Listens for server sync events to keep local state current.
--- ============================================================================

--- Local registry of spawned Handler NPCs and blips
--- keyed by business id
local HandlerNPCs = {} -- { [businessId] = pedHandle }
local HandlerBlips = {} -- { [businessId] = blipHandle }

--- Local copy of player's owned businesses synced from server
local OwnedBusinesses = {} -- { [businessId] = businessData }

--- -------------------------------------------------------------------------
--- NPC MANAGEMENT
--- -------------------------------------------------------------------------

--- Spawns a Handler NPC for a given business and registers targets
--- @param businessId number
--- @param businessData table
local function SpawnHandlerNPC(businessId, businessData)
    if HandlerNPCs[businessId] and DoesEntityExist(HandlerNPCs[businessId]) then return end

    local tier = nil
    for _, t in pairs(Config.Business.Tiers) do
        if t.type == businessData.type then tier = t break end
    end
    if not tier then return end

    local locations = require("shared/business_locations")
    local location = locations[businessData.type] and locations[businessData.type][businessData.locationId]
    if not location then return end

    -- Spawn NPC using shared helper
    local ped = SpawnStaticPed(tier.npc, location.coords, Config.Business.HandlerScenario)
    HandlerNPCs[businessId] = ped

    -- Create blip
    HandlerBlips[businessId] = CreateMapBlip(
        location.coords,
        Config.Business.HandlerBlipSprite or 375,
        Config.Business.HandlerBlipDisplay or 4,
        Config.Business.HandlerBlipScale or 0.7,
        Config.Business.HandlerBlipColor or 2,
        ("%s — %s"):format(tier.label, location.brand or tier.label)
    )

    -- Register owner target options
    while not _Target do Wait(100) end
    _API.Target.AddLocalEntity(ped, {
        {
            name        = ("t1ger_moneywash:handler:%d"):format(businessId),
            icon        = Config.Business.HandlerTargetIcon or "fa-solid fa-briefcase",
            label       = locale("target.handler_npc"),
            distance    = Config.Business.HandlerTargetDistance or 2.0,
            canInteract = CanInteractWithHandlerNPC,
            onSelect    = function()
                OpenHandlerMenu(businessId)
            end,
        },
        {
            name        = ("t1ger_moneywash:handler:deliverstock:%d"):format(businessId),
            icon        = Config.Business.StockMission.Icons.DeliverTarget,
            label       = locale("target.deliver_stock"),
            distance    = Config.Business.StockMission.PickupTargetDistance,
            canInteract = function()
                return IsCarryingStockBox(businessId)
            end,
            onSelect    = function()
                DeliverStock()
            end,
        },
    })

    if Config.Debug then
        print(("[MoneyWash] Handler NPC spawned for business %d (%s)"):format(businessId, businessData.type))
    end
end

--- Removes a Handler NPC and its blip for a given business
--- @param businessId number
local function DespawnHandlerNPC(businessId)
    if HandlerNPCs[businessId] then
        _API.Target.RemoveLocalEntity(HandlerNPCs[businessId], {
            names = {
                ("t1ger_moneywash:handler:%d"):format(businessId),
            }
        })
        DeletePed(HandlerNPCs[businessId])
        HandlerNPCs[businessId] = nil
    end

    RemoveMapBlip(HandlerBlips[businessId])
    HandlerBlips[businessId] = nil

    if Config.Debug then
        print(("[MoneyWash] Handler NPC despawned for business %d"):format(businessId))
    end
end

--- Spawns Handler NPCs for all owned businesses
local function SpawnAllHandlerNPCs()
    for businessId, businessData in pairs(OwnedBusinesses) do
        SpawnHandlerNPC(businessId, businessData)
    end
end

--- Despawns all Handler NPCs and clears local registry
local function DespawnAllHandlerNPCs()
    for businessId in pairs(HandlerNPCs) do
        DespawnHandlerNPC(businessId)
    end
end

--- -------------------------------------------------------------------------
--- SERVER SYNC EVENTS
--- -------------------------------------------------------------------------

--- Initial sync of all owned businesses on player load
RegisterNetEvent("t1ger_moneywash:client:syncBusinesses", function(businesses)
    DespawnAllHandlerNPCs()
    OwnedBusinesses = {}

    for _, business in ipairs(businesses) do
        OwnedBusinesses[business.id] = business
    end

    SpawnAllHandlerNPCs()

    if Config.Debug then
        print(("[MoneyWash] Synced %d owned businesses"):format(#businesses))
    end
end)

--- Business purchased - spawn its Handler NPC
RegisterNetEvent("t1ger_moneywash:client:businessPurchased", function(businessId, businessType, locationId)
    OwnedBusinesses[businessId] = {
        id         = businessId,
        type       = businessType,
        locationId = locationId,
    }
    SpawnHandlerNPC(businessId, OwnedBusinesses[businessId])
end)

--- Business transferred away - remove Handler NPC
RegisterNetEvent("t1ger_moneywash:client:businessTransferred", function(businessId)
    OwnedBusinesses[businessId] = nil
    DespawnHandlerNPC(businessId)
end)

--- Business received from transfer - spawn Handler NPC
RegisterNetEvent("t1ger_moneywash:client:businessReceived", function(businessId, businessType, locationId)
    OwnedBusinesses[businessId] = {
        id         = businessId,
        type       = businessType,
        locationId = locationId,
    }
    SpawnHandlerNPC(businessId, OwnedBusinesses[businessId])
end)

--- Business abandoned - remove Handler NPC
RegisterNetEvent("t1ger_moneywash:client:businessAbandoned", function(businessId)
    OwnedBusinesses[businessId] = nil
    DespawnHandlerNPC(businessId)
end)

--- Business permanently removed by admin - remove Handler NPC
RegisterNetEvent("t1ger_moneywash:client:businessRemoved", function(businessId)
    OwnedBusinesses[businessId] = nil
    DespawnHandlerNPC(businessId)
    _API.ShowNotification(locale("notification.business_removed"), "error", {})
end)

--- Money laundered into the Safe - notify player
RegisterNetEvent("t1ger_moneywash:client:moneyLaundered", function(amount, covered, exposed)
    _API.ShowNotification(string.format(locale("notification.money_laundered"), FormatMoney(amount), FormatMoney(covered), FormatMoney(exposed)), "success", {})
end)

--- Suspicion label changed - notify player if enabled
RegisterNetEvent("t1ger_moneywash:client:suspicionLabelChanged", function(newLabel)
    if Config.Suspicion.NotifyOnLabelChange then
        _API.ShowNotification(string.format(locale("notification.suspicion_changed"), newLabel.name), "inform", {})
    end
end)

--- -------------------------------------------------------------------------
--- EXPORTS
--- -------------------------------------------------------------------------

--- Returns the player's owned businesses (local cache)
exports("GetOwnedBusinesses", function()
    return OwnedBusinesses
end)