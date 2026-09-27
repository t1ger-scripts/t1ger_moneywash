-- ============================================================================
-- STOCK DELIVERY MISSION (client)
-- Single source of truth: `stockMission`. Every transition (pickup, load,
-- unload, deliver, cancel) is a request to the server - this file never
-- decides deducted units or success itself. Fully self-contained: no
-- dependency on client/functions.lua.
-- ============================================================================

--- @field active boolean
--- @field businessId number
--- @field units number
--- @field cost number
--- @field pickupLocation vector4
--- @field state string   "awaiting_pickup" | "carried" | "loaded"
--- @field prop number|nil
--- @field point table|nil    ox_lib point, active only during "awaiting_pickup"
--- @field blip number|nil
--- @field vehicleNetId number|nil
local stockMission = nil

-- -----------------------------------------------------------------------
-- LOCAL HELPERS
-- -----------------------------------------------------------------------

--- Spawns an object and settles it onto the ground/surface below it.
--- @param model string
--- @param coords vector3|vector4
--- @return number
local function SpawnGroundObject(model, coords)
    lib.requestModel(model)
    local obj = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z, true, true, true)
    PlaceObjectOnGroundOrObjectProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(GetHashKey(model))
    return obj
end

--- Safely deletes a prop spawned by this file.
--- @param propHandle number
local function DeleteStockProp(propHandle)
    if propHandle and DoesEntityExist(propHandle) then
        SetEntityAsMissionEntity(propHandle, false, true)
        DeleteEntity(propHandle)
    end
end

--- Creates a map blip.
--- @param coords vector3|vector4
--- @param sprite number
--- @param display number
--- @param scale number
--- @param color number
--- @param label string|nil
--- @return number
local function CreateStockBlip(coords, sprite, display, scale, color, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, display)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, false)

    if label then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(label)
        EndTextCommandSetBlipName(blip)
    end

    return blip
end

--- Removes a map blip.
--- @param blip number
local function RemoveStockBlip(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

--- Attaches the box to the player's hand using the configured offset.
local function AttachBoxToPlayer()
    local cfg = Config.Business.StockMission.PickupObject
    local playerPed = PlayerPedId()

    SetEntityVisible(stockMission.prop, true, false)
    AttachEntityToEntity(
        stockMission.prop, playerPed, GetPedBoneIndex(playerPed, cfg.bone),
        cfg.pos.x, cfg.pos.y, cfg.pos.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z,
        true, true, false, true, 1, true
    )
end

--- Hides the box and attaches it to the vehicle currently carrying it.
--- @param vehicle number
local function AttachBoxToVehicle(vehicle)
    SetEntityVisible(stockMission.prop, false, false)
    AttachEntityToEntity(
        stockMission.prop, vehicle, 0,
        0.0, -1.0, 0.0, 0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )
end

-- -----------------------------------------------------------------------
-- STATE QUERIES
-- -----------------------------------------------------------------------

--- @return boolean
function IsStockMissionActive()
    return stockMission ~= nil and stockMission.active
end

--- @return boolean
function IsCarryingStockBox()
    return stockMission ~= nil and stockMission.state == "carried"
end

-- -----------------------------------------------------------------------
-- CLEANUP
-- -----------------------------------------------------------------------

--- Tears down mission state, whatever stage it was at. The single thing
--- to call for both a successful delivery and a full cancel.
local function ResetStockMission()
    if stockMission then
        if stockMission.point then
            stockMission.point:remove()
        end

        if stockMission.blip then
            RemoveStockBlip(stockMission.blip)
        end

        if stockMission.prop and DoesEntityExist(stockMission.prop) then
            DeleteStockProp(stockMission.prop)
        end
    end

    stockMission = nil
end

-- -----------------------------------------------------------------------
-- PICKUP SITE (point, marker, box spawn)
-- -----------------------------------------------------------------------

--- Registers the pickup-site point: spawns the box once the player first
--- arrives, and draws the marker every frame while close enough.
local function SetupPickupPoint()
    local cfg = Config.Business.StockMission
    local pickup = stockMission.pickupLocation
    local coords = vector3(pickup.x, pickup.y, pickup.z)

    stockMission.point = lib.points.new({
        coords   = coords,
        distance = cfg.PickupDistance,
    })

    function stockMission.point:onEnter()
        if stockMission.prop then return end -- already spawned, re-entering after wandering off

        stockMission.prop = SpawnGroundObject(cfg.PickupObject.model, pickup)

        _API.Target.AddLocalEntity(stockMission.prop, {
            {
                name        = "moneywash:stock:pickup",
                icon        = cfg.Icons.PickupTarget,
                label       = locale("target.pickup_box"),
                distance    = cfg.PickupTargetDistance,
                canInteract = function()
                    return IsStockMissionActive() and stockMission.state == "awaiting_pickup"
                end,
                onSelect    = function()
                    RequestStockPickup()
                end,
            },
        })
    end

    function stockMission.point:nearby()
        if not stockMission.prop or stockMission.state ~= "awaiting_pickup" then return end
        if self.currentDistance >= cfg.PickupMarker.Distance then return end

        local m = cfg.PickupMarker
        local markerCoords = GetEntityCoords(stockMission.prop)

        DrawMarker(
            m.Type,
            markerCoords.x, markerCoords.y, markerCoords.z + m.ZOffset,
            0.0, 0.0, 0.0,
            m.Rotation.x, m.Rotation.y, m.Rotation.z,
            m.Scale.x, m.Scale.y, m.Scale.z,
            m.Color.r, m.Color.g, m.Color.b, m.Color.a,
            m.BobUpAndDown, m.FaceCamera, m.RotationOrder, m.Rotate,
            nil, nil, false
        )
    end
end

--- Confirms pickup with the server, then re-attaches the same ground box
--- entity to the player's hand rather than deleting and recreating it.
function RequestStockPickup()
    if not stockMission or not stockMission.prop then return end

    local result = lib.callback.await("t1ger_moneywash:server:pickupStockShipment", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    _API.Target.RemoveLocalEntity(stockMission.prop, { names = { "moneywash:stock:pickup" } })
    AttachBoxToPlayer()

    stockMission.state = "carried"

    if stockMission.point then
        stockMission.point:remove()
        stockMission.point = nil
    end

    if stockMission.blip then
        RemoveStockBlip(stockMission.blip)
        stockMission.blip = nil
    end

    _API.ShowNotification(locale("notification.stock_picked_up"), "inform")
end

-- -----------------------------------------------------------------------
-- VEHICLE LOAD / UNLOAD
-- -----------------------------------------------------------------------

--- Registered once for the resource's lifetime - canInteract alone decides
--- visibility based on live mission state, since there's no per-instance
--- remove function for global vehicle targets.
local function RegisterVehicleTargets()
    local cfg = Config.Business.StockMission

    _API.Target.AddGlobalVehicle({
        {
            name        = "moneywash:stock:load",
            icon        = cfg.Icons.LoadTarget,
            label       = locale("target.load_stock"),
            distance    = cfg.PickupTargetDistance,
            canInteract = function()
                return IsCarryingStockBox()
            end,
            onSelect = function(vehicle)
                RequestStockLoad(vehicle)
            end,
        },
        {
            name        = "moneywash:stock:unload",
            icon        = cfg.Icons.UnloadTarget,
            label       = locale("target.unload_stock"),
            distance    = cfg.PickupTargetDistance,
            canInteract = function(vehicle)
                return stockMission ~= nil and stockMission.state == "loaded"
                    and stockMission.vehicleNetId == NetworkGetNetworkIdFromEntity(vehicle)
            end,
            onSelect = function()
                RequestStockUnload()
            end,
        },
    })
end

--- @param vehicle number
function RequestStockLoad(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    print("netId: ", netId)
    local result = lib.callback.await("t1ger_moneywash:server:loadStockShipment", false, netId)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    AttachBoxToVehicle(vehicle)
    stockMission.state = "loaded"
    stockMission.vehicleNetId = netId

    _API.ShowNotification(locale("notification.stock_loaded"), "inform")
end

function RequestStockUnload()
    local result = lib.callback.await("t1ger_moneywash:server:unloadStockShipment", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    AttachBoxToPlayer()
    stockMission.state = "carried"
    stockMission.vehicleNetId = nil

    _API.ShowNotification(locale("notification.stock_unloaded"), "inform")
end

-- -----------------------------------------------------------------------
-- COLLISION REPORTING
-- -----------------------------------------------------------------------

--- Registered once, gated by live mission state. Only ever sends a bare
--- "check now" ping plus the vehicle it believes it's in (cross-check
--- only) - the server independently resolves the real vehicle and rolls
--- the penalty itself.
AddEventHandler("gameEventTriggered", function(eventName, args)
    if eventName ~= "CEventNetworkEntityDamage" then return end
    if not stockMission or stockMission.state ~= "loaded" then return end

    local damagedVehicle = args[1]
    local entityHit = args[2]
    if entityHit == -1 then return end

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle == 0 or damagedVehicle ~= vehicle then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= playerPed then return end

    local minSpeed = Config.Business.StockMission.CollisionDamage.MinImpactSpeed
    if GetEntitySpeed(vehicle) < minSpeed then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local applied, deductedPercent, remainingUnits =
        lib.callback.await("t1ger_moneywash:server:reportStockCollision", false, netId)

    if applied then
        _API.ShowNotification(
            string.format(locale("notification.stock_damaged"), deductedPercent, remainingUnits),
            "error"
        )
    end
end)

-- -----------------------------------------------------------------------
-- ORDER / DELIVERY / CANCEL
-- -----------------------------------------------------------------------

--- Builds mission state from an already-confirmed order (the server call
--- itself happens in menu.lua, alongside every other confirm-then-act
--- flow in this resource) and sets up the pickup site.
--- @param businessId number
--- @param missionData table  { units, cost, pickupLocation }
function StartStockMission(businessId, missionData)
    if IsStockMissionActive() then
        _API.ShowNotification(locale("notification.mission_already_active"), "error")
        return
    end

    local blipCfg = Config.Business.StockMission.PickupBlip

    stockMission = {
        active         = true,
        businessId     = businessId,
        units          = missionData.units,
        cost           = missionData.cost,
        pickupLocation = missionData.pickupLocation,
        state          = "awaiting_pickup",
        prop           = nil,
        point          = nil,
        blip           = nil,
        vehicleNetId   = nil,
    }

    _API.ShowNotification(locale("notification.stock_order_placed"), "inform")

    stockMission.blip = CreateStockBlip(
        stockMission.pickupLocation, blipCfg.Sprite, blipCfg.Display, blipCfg.Scale, blipCfg.Color, blipCfg.Label
    )

    if blipCfg.Route then
        SetBlipRoute(stockMission.blip, true)
        SetBlipRouteColour(stockMission.blip, blipCfg.RouteColor)
    end

    SetupPickupPoint()
end

--- Delivers the shipment. Requires the box to already be carried, not
--- still sitting loaded in a vehicle.
function DeliverStock()
    if not stockMission or stockMission.state ~= "carried" then return end

    local result = lib.callback.await("t1ger_moneywash:server:completeStockDelivery", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    ResetStockMission()
    _API.ShowNotification(locale("notification.stock_delivered"), "success")
end

--- Cancels the active mission voluntarily via command.
function CancelStockMission()
    if not IsStockMissionActive() then return end

    local result = lib.callback.await("t1ger_moneywash:server:cancelStockMission", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    ResetStockMission()
    _API.ShowNotification(locale("notification.stock_cancelled"), "inform")
end

RegisterCommand(Config.Business.StockMission.CancelCommand, function()
    CancelStockMission()
end, false)

CreateThread(function()
    while not _Target do Wait(100) end
    RegisterVehicleTargets()
end)

-- -----------------------------------------------------------------------
-- DEV/TEST ONLY
-- -----------------------------------------------------------------------

if Config.Debug then
    --- /teststock [businessId] [units] - starts a stock order directly via
    --- the real server callback, skipping the Handler menu. Testing only.
    RegisterCommand("teststock", function(_, args)
        local businessId = tonumber(args[1]) or 1
        local units = tonumber(args[2]) or 10

        local result = lib.callback.await("t1ger_moneywash:server:orderStock", false, businessId, units)

        if not result.success then
            _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
            return
        end

        StartStockMission(businessId, result.missionData)
    end, false)
end