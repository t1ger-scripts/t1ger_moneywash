-- ============================================================================
-- STOCK DELIVERY MISSION (client)
-- Every transition (pickup, load, unload, deliver, cancel) is a request to
-- the server - this file never decides deducted units or success itself.
-- Collision handling only ever sends a bare "check now" ping.
-- ============================================================================

local StockMissionActive = false
local ActiveMissionBusinessId = nil
local CarriedProp = nil
local GroundBoxProp = nil
local CurrentVehicleNetId = nil

--- @return boolean
function IsStockMissionActive()
    return StockMissionActive
end

--- @param vehicle number
--- @return number
local function GetVehicleNetId(vehicle)
    return NetworkGetNetworkIdFromEntity(vehicle)
end

--- Attaches the carried box prop to the player using the configured offset.
local function AttachCarriedProp()
    local cfg = Config.Business.StockMission.CarriedProp
    local playerPed = PlayerPedId()

    lib.requestModel(cfg.model)
    CarriedProp = CreateObject(joaat(cfg.model), GetEntityCoords(playerPed), true, false, false)

    AttachEntityToEntity(
        CarriedProp, playerPed, GetPedBoneIndex(playerPed, cfg.bone),
        cfg.pos.x, cfg.pos.y, cfg.pos.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(joaat(cfg.model))
end

local function RemoveCarriedProp()
    if CarriedProp and DoesEntityExist(CarriedProp) then
        DeleteEntity(CarriedProp)
    end
    CarriedProp = nil
end

--- Starts a stock order: requests the mission from the server, then walks
--- the player through pickup -> load/unload -> deliver.
--- @param businessId number
--- @param units number
function StartStockMission(businessId, units)
    if StockMissionActive then
        _API.ShowNotification(locale("notification.mission_already_active"), "error")
        return
    end

    local result = lib.callback.await("t1ger_moneywash:server:orderStock", false, businessId, units)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    StockMissionActive = true
    ActiveMissionBusinessId = businessId

    _API.ShowNotification(locale("notification.stock_order_placed"), "inform")

    local pickup = result.missionData.pickupLocation
    SetNewWaypoint(pickup.x, pickup.y)

    CreateThread(function()
        while StockMissionActive and not GroundBoxProp do
            Wait(500)

            if IsNearCoords(pickup, Config.Business.StockMission.PickupDistance) then
                GroundBoxProp = SpawnProp(GetStockBoxModel(), vector3(pickup.x, pickup.y, pickup.z), false, nil)
                lib.showTextUI(locale("textui.pickup_box"), { icon = "fa-solid fa-box" })

                _API.Target.AddLocalEntity(GroundBoxProp, {
                    {
                        name     = "moneywash:stock:pickup",
                        icon     = "fa-solid fa-hand",
                        label    = locale("target.pickup_box"),
                        distance = Config.Business.StockMission.BoxTargetDistance,
                        onSelect = function()
                            RequestStockPickup(businessId)
                        end,
                    },
                })
            end
        end
    end)
end

--- Requests pickup confirmation from the server, then plays the pickup
--- animation and switches the box to a carried prop.
--- @param businessId number
function RequestStockPickup(businessId)
    local result = lib.callback.await("t1ger_moneywash:server:pickupStockShipment", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    lib.hideTextUI()

    local anim = GetPickupAnimation()
    lib.requestAnimDict(anim.dict)
    local playerPed = PlayerPedId()

    TaskPlayAnim(playerPed, anim.dict, anim.clip, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)
    Wait(anim.duration)
    StopAnimTask(playerPed, anim.dict, anim.clip, 1.0)

    _API.Target.RemoveLocalEntity(GroundBoxProp, { names = { "moneywash:stock:pickup" } })
    DeleteProp(GroundBoxProp)
    GroundBoxProp = nil

    AttachCarriedProp()

    _API.ShowNotification(locale("notification.stock_picked_up"), "inform")
end

--- Registers the two stock vehicle target options exactly once, for the
--- lifetime of the resource. There's no per-mission add/remove - canInteract
--- alone decides whether either option is visible at any given moment,
--- based on live mission state.
local StockVehicleTargetsRegistered = false

function RegisterStockVehicleTargets()
    if StockVehicleTargetsRegistered then return end
    StockVehicleTargetsRegistered = true

    _API.Target.AddGlobalVehicle({
        {
            name        = "moneywash:stock:load",
            icon        = "fa-solid fa-truck-ramp-box",
            label       = locale("target.load_stock"),
            distance    = Config.Business.StockMission.BoxTargetDistance,
            canInteract = function()
                return StockMissionActive and CarriedProp ~= nil
            end,
            onSelect = function(entity)
                RequestStockLoad(ActiveMissionBusinessId, entity)
            end,
        },
        {
            name        = "moneywash:stock:unload",
            icon        = "fa-solid fa-hand",
            label       = locale("target.unload_stock"),
            distance    = Config.Business.StockMission.BoxTargetDistance,
            canInteract = function(entity)
                return StockMissionActive and CarriedProp == nil and CurrentVehicleNetId == GetVehicleNetId(entity)
            end,
            onSelect = function(entity)
                RequestStockUnload(ActiveMissionBusinessId)
            end,
        },
    })
end

CreateThread(function()
    while not _Target do Wait(100) end
    RegisterStockVehicleTargets()
end)

--- @param businessId number
--- @param vehicle number
function RequestStockLoad(businessId, vehicle)
    local netId = GetVehicleNetId(vehicle)

    local result = lib.callback.await("t1ger_moneywash:server:loadStockShipment", false, netId)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    RemoveCarriedProp()
    CurrentVehicleNetId = netId

    _API.ShowNotification(locale("notification.stock_loaded"), "inform")

    local businessLocations = require("shared/business_locations")
    local ownedBusinesses = exports["t1ger_moneywash"]:GetOwnedBusinesses()
    local business = ownedBusinesses[businessId]
    if business then
        local location = businessLocations[business.type] and businessLocations[business.type][business.locationId]
        if location then
            SetNewWaypoint(location.coords.x, location.coords.y)
        end
    end

    StartCollisionMonitor()
end

--- @param businessId number
function RequestStockUnload(businessId)
    local result = lib.callback.await("t1ger_moneywash:server:unloadStockShipment", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    CurrentVehicleNetId = nil
    AttachCarriedProp()

    _API.ShowNotification(locale("notification.stock_unloaded"), "inform")
end

--- Watches for collisions while the shipment is loaded in a vehicle and
--- pings the server to check. Only decides *when* it's worth asking - the
--- server alone decides whether anything actually happened and by how much.
function StartCollisionMonitor()
    CreateThread(function()
        local minSpeed = Config.Business.StockMission.CollisionDamage.MinImpactSpeed or 5.0

        local handler
        handler = AddEventHandler("gameEventTriggered", function(eventName, args)
            if not CurrentVehicleNetId then return end
            if eventName ~= "CEventNetworkEntityDamage" then return end

            local damagedVehicle = args[1]
            local entityHit = args[2]
            if entityHit == -1 then return end

            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle == 0 or damagedVehicle ~= vehicle then return end
            if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then return end
            if GetEntitySpeed(vehicle) < minSpeed then return end

            local netId = GetVehicleNetId(vehicle)
            local applied, deductedPercent, remainingUnits =
                lib.callback.await("t1ger_moneywash:server:reportStockCollision", false, netId)

            if applied then
                _API.ShowNotification(
                    string.format(locale("notification.stock_damaged"), deductedPercent, remainingUnits),
                    "error"
                )
            end
        end)

        while CurrentVehicleNetId do
            Wait(500)
        end

        RemoveEventHandler(handler)
    end)
end

--- Delivers the shipment. Requires the player to have unloaded it first
--- (carrying it, not still driving with it).
--- @param businessId number
function DeliverStock(businessId)
    if not StockMissionActive or CarriedProp == nil then return end

    local anim = GetDropoffAnimation()
    lib.requestAnimDict(anim.dict)
    local playerPed = PlayerPedId()

    TaskPlayAnim(playerPed, anim.dict, anim.clip, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)

    local completed = ProgressBar({
        duration     = anim.duration,
        label        = locale("progress.delivering_stock"),
        useWhileDead = false,
        canCancel    = false,
        disable      = { move = true, car = true, combat = true },
        anim         = { dict = anim.dict, clip = anim.clip, flag = anim.flag },
    })

    StopAnimTask(playerPed, anim.dict, anim.clip, 1.0)

    if not completed then return end

    local result = lib.callback.await("t1ger_moneywash:server:completeStockDelivery", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    RemoveCarriedProp()
    StockMissionActive = false
    ActiveMissionBusinessId = nil
    CurrentVehicleNetId = nil
    ClearWaypoint()

    _API.ShowNotification(locale("notification.stock_delivered"), "success")
end

--- Cancels the active mission voluntarily via command.
function CancelStockMission()
    if not StockMissionActive then return end

    local result = lib.callback.await("t1ger_moneywash:server:cancelStockMission", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    RemoveCarriedProp()
    if GroundBoxProp and DoesEntityExist(GroundBoxProp) then
        DeleteProp(GroundBoxProp)
    end
    
    GroundBoxProp = nil
    StockMissionActive = false
    ActiveMissionBusinessId = nil
    CurrentVehicleNetId = nil
    ClearWaypoint()
    lib.hideTextUI()

    _API.ShowNotification(locale("notification.stock_cancelled"), "inform")
end

RegisterCommand(Config.Business.StockMission.CancelCommand or "cancelstock", function()
    CancelStockMission()
end, false)