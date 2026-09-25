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
            name        = ("t1ger_moneywash:handler:raid:%d"):format(businessId),
            icon        = Config.Police.RaidTargetIcon or "fa-solid fa-shield-halved",
            label       = locale("target.raid_business"),
            distance    = Config.Police.RaidTargetDistance or 2.0,
            canInteract = CanPoliceRaidBusiness,
            onSelect    = function()
                TriggerRaidAction(businessId)
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
                ("t1ger_moneywash:handler:raid:%d"):format(businessId),
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

--- Business permanently seized by police/admin - remove Handler NPC
RegisterNetEvent("t1ger_moneywash:client:businessSeized", function(businessId)
    OwnedBusinesses[businessId] = nil
    DespawnHandlerNPC(businessId)
    _API.ShowNotification(locale("notification.business_seized"), "error", {})
end)

--- Business raided - notify player
RegisterNetEvent("t1ger_moneywash:client:businessRaided", function(businessId, seizedAmount)
    _API.ShowNotification(string.format(locale("notification.business_raided"), FormatMoney(seizedAmount)), "error", {})
end)

--- Suspicion label changed - notify player if enabled
RegisterNetEvent("t1ger_moneywash:client:suspicionLabelChanged", function(newLabel)
    if Config.Suspicion.NotifyOnLabelChange then
        _API.ShowNotification(string.format(locale("notification.suspicion_changed"), newLabel.name), "inform", {})
    end
end)

--- Bank deposit cleared - notify player
RegisterNetEvent("t1ger_moneywash:client:depositCleared", function(amount)
    _API.ShowNotification(string.format(locale("notification.deposit_cleared"), FormatMoney(amount)), "success", {})
end)

--- Bank deposit confiscated by police
RegisterNetEvent("t1ger_moneywash:client:depositConfiscated", function(amount)
    _API.ShowNotification(string.format(locale("notification.deposit_confiscated"), FormatMoney(amount)), "error", {})
end)

--- Pending deposit synced on login (player had a deposit in progress)
RegisterNetEvent("t1ger_moneywash:client:pendingDepositSync", function(depositData)
    -- Store locally so missions.lua can reference it
    ActivePendingDeposit = depositData
    if Config.Debug then
        print(("[MoneyWash] Pending deposit synced: $%d clears at %d"):format(
            depositData.totalAmount, depositData.clearsAt))
    end
end)

--- -------------------------------------------------------------------------
--- RAID ACTION (police)
--- -------------------------------------------------------------------------

--- Initiates a raid on a business via police target interaction
--- @param businessId number
function TriggerRaidAction(businessId)
    local result = lib.callback.await("t1ger_moneywash:server:raidBusiness", false, businessId)
    if not result.success then
        _API.ShowNotification(locale("notification.raid_failed_" .. (result.reason or "unknown")), "error")
        return
    end
    _API.ShowNotification(locale("notification.raid_executed"), "success", {})
end

--- -------------------------------------------------------------------------
--- EXPORTS
--- -------------------------------------------------------------------------

--- Returns the player's owned businesses (local cache)
exports("GetOwnedBusinesses", function()
    return OwnedBusinesses
end)