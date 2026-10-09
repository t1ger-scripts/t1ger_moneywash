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
local function CreateMissionBlip(coords, sprite, display, scale, color, label)
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
local function RemoveMissionBlip(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

--- Starts the looping carry animation.
local function StartCarryAnimation()
    local anim = Config.Business.StockMission.CarryAnimation
    local playerPed = PlayerPedId()

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(playerPed, anim.dict, anim.name, anim.blendIn, anim.blendOut, anim.duration, anim.flag, 0, false, false, false)
    RemoveAnimDict(anim.dict)
end

--- Stops the carry animation, if currently playing.
local function StopCarryAnimation()
    local anim = Config.Business.StockMission.CarryAnimation
    local playerPed = PlayerPedId()

    if IsEntityPlayingAnim(playerPed, anim.dict, anim.name, 3) then
        StopAnimTask(playerPed, anim.dict, anim.name, anim.blendOut)
    end
end

--- Watchdog: if the carry animation gets interrupted for any reason while
--- the box is still meant to be carried (damage, ragdoll, another system's
--- animation, etc.), this notices and restarts it. Single persistent
--- thread for the resource's lifetime - cheap no-op whenever there's
--- nothing to fix.
CreateThread(function()
    while true do
        Wait(1000)

        if stockMission and stockMission.state == "carried" then
            local anim = Config.Business.StockMission.CarryAnimation
            local playerPed = PlayerPedId()

            local inVehicle = IsPedInAnyVehicle(playerPed, false)
            local ragdolling = IsPedRagdoll(playerPed)
            local playing = IsEntityPlayingAnim(playerPed, anim.dict, anim.name, 3)

            if not inVehicle and not ragdolling and not playing then
                StartCarryAnimation()
            end
        end
    end
end)

--- Attaches the box to the player's hand using the configured offset,
--- and starts the carry animation.
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

    StartCarryAnimation()
end

--- Hides the box and attaches it to the vehicle currently carrying it,
--- and stops the carry animation since the player's hands are free again.
--- @param vehicle number
local function AttachBoxToVehicle(vehicle)
    SetEntityVisible(stockMission.prop, false, false)
    AttachEntityToEntity(
        stockMission.prop, vehicle, 0,
        0.0, -1.0, 0.0, 0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    StopCarryAnimation()
end

local METER_POSITIONS = {
    ["top-left"]      = function(cfg) return cfg.Margin + cfg.Width / 2,       cfg.Margin + cfg.Height / 2 end,
    ["top-right"]     = function(cfg) return 1.0 - cfg.Margin - cfg.Width / 2, cfg.Margin + cfg.Height / 2 end,
    ["bottom-left"]   = function(cfg) return cfg.Margin + cfg.Width / 2,       1.0 - cfg.Margin - cfg.Height / 2 end,
    ["bottom-right"]  = function(cfg) return 1.0 - cfg.Margin - cfg.Width / 2, 1.0 - cfg.Margin - cfg.Height / 2 end,
    ["top-center"]    = function(cfg) return 0.5,                              cfg.Margin + cfg.Height / 2 end,
    ["bottom-center"] = function(cfg) return 0.5,                              1.0 - cfg.Margin - cfg.Height / 2 end,
}

--- Draws the cargo condition meter for the current frame.
local function DrawStockDamageMeter()
    local cfg = Config.Business.StockMission.DamageMeter
    if not cfg.Enable then return end

    local percent = math.max(0, math.min(100, (stockMission.currentUnits / stockMission.units) * 100))
    local getCenter = METER_POSITIONS[cfg.Position] or METER_POSITIONS["bottom-right"]
    local centerX, centerY = getCenter(cfg)

    local bg = cfg.BackgroundColor
    DrawRect(centerX, centerY, cfg.Width, cfg.Height, bg.r, bg.g, bg.b, bg.a)

    local fillWidth = cfg.Width * (percent / 100)

    if fillWidth > 0 then
        local fillCenterX = (centerX - cfg.Width / 2) + (fillWidth / 2)
        local color = cfg.FillColor

        if percent <= cfg.DangerThreshold then
            color = cfg.DangerColor
        elseif percent <= cfg.WarningThreshold then
            color = cfg.WarningColor
        end

        DrawRect(fillCenterX, centerY, fillWidth, cfg.Height, color.r, color.g, color.b, color.a)
    end

    SetTextFont(4)
    SetTextScale(0.3, 0.3)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(("%d%%"):format(math.floor(percent)))
    EndTextCommandDisplayText(centerX, centerY - 0.01)
end

--- Single persistent render loop, for the resource's whole lifetime - no
--- new thread per mission. Draws only while a mission genuinely holds
--- cargo the player could see damage on.
CreateThread(function()
    while true do
        Wait(0)

        if stockMission and (stockMission.state == "carried" or stockMission.state == "loaded") then
            DrawStockDamageMeter()
        end

        -- Carrying the box by hand: no getting into vehicles. The only way to
        -- use a vehicle is to load the box onto it with the vehicle target.
        if stockMission and stockMission.state == "carried" then
            DisableControlAction(0, 23, true) -- INPUT_ENTER (F / controller Y)
            if IsDisabledControlJustPressed(0, 23) then
                _API.ShowNotification(locale("notification.stock_cannot_enter_vehicle"), "error")
            end
        end
    end
end)

-- -----------------------------------------------------------------------
-- STATE QUERIES
-- -----------------------------------------------------------------------

--- @return boolean
function IsStockMissionActive()
    return stockMission ~= nil and stockMission.active
end

--- @param businessId number|nil  if given, also requires the carried box to belong to this business
--- @return boolean
function IsCarryingStockBox(businessId)
    if not stockMission or stockMission.state ~= "carried" then return false end
    if businessId and stockMission.businessId ~= businessId then return false end
    return true
end

-- -----------------------------------------------------------------------
-- CLEANUP
-- -----------------------------------------------------------------------

--- Tears down mission state, whatever stage it was at. The single thing
--- to call for both a successful delivery and a full cancel.
local function ResetStockMission()
    if stockMission then
        if stockMission.state == "carried" then
            StopCarryAnimation()
        end

        if stockMission.point then
            stockMission.point:remove()
        end

        if stockMission.blip then
            RemoveMissionBlip(stockMission.blip)
        end

        if stockMission.deliveryBlip then
            RemoveMissionBlip(stockMission.deliveryBlip)
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
        RemoveMissionBlip(stockMission.blip)
        stockMission.blip = nil
    end

    if stockMission.businessCoords then
        local cfg = Config.Business.StockMission.DeliveryBlip

        stockMission.deliveryBlip = CreateMissionBlip(
            stockMission.businessCoords, cfg.Sprite, cfg.Display, cfg.Scale, cfg.Color, cfg.Label
        )

        if cfg.Route then
            SetBlipRoute(stockMission.deliveryBlip, true)
            SetBlipRouteColour(stockMission.deliveryBlip, cfg.RouteColor)
        end
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
            distance    = cfg.VehicleTargetDistance,
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
            distance    = cfg.VehicleTargetDistance,
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
        stockMission.currentUnits = remainingUnits

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
        currentUnits   = missionData.units, -- live, only ever updated from server-confirmed collision reports
        cost           = missionData.cost,
        pickupLocation = missionData.pickupLocation,
        businessCoords = missionData.businessCoords,
        state          = "awaiting_pickup",
        prop           = nil,
        point          = nil,
        blip           = nil,
        deliveryBlip   = nil,
        vehicleNetId   = nil,
    }

    _API.ShowNotification(locale("notification.stock_order_placed"), "inform")

    stockMission.blip = CreateMissionBlip(
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

    StopCarryAnimation()
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

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ResetStockMission()
end)

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