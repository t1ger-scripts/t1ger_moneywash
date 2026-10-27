--- Stock delivery mission (client). Every step (pickup, load, unload, deliver, cancel) is a request
--- to the server. This file never decides how much stock is lost or whether a delivery works, it
--- only shows the mission: the box, the blips, the cargo meter and the carry animation.

---@class StockMission
---@field businessId integer
---@field units integer Units ordered
---@field cost integer Paid for the order
---@field currentUnits number Units left, only updated from collisions the server confirmed
---@field pickupLocation vector4
---@field businessCoords? vector3
---@field state "awaiting_pickup"|"carried"|"loaded"
---@field prop? integer The box
---@field point? table ox_lib point at the pickup spot, only while awaiting pickup
---@field blip? integer Pickup blip
---@field deliveryBlip? integer Business blip
---@field vehicleNetId? integer Only while loaded

---@type StockMission|nil
local mission = nil

---@type integer GetGameTimer() of the last collision report sent
local lastCollisionReport = 0

---@type table<string, fun(config: table): number, number> Screen position of the cargo meter
local meterPositions = {
    ["top-left"]      = function(cfg) return cfg.Margin + cfg.Width / 2,       cfg.Margin + cfg.Height / 2 end,
    ["top-right"]     = function(cfg) return 1.0 - cfg.Margin - cfg.Width / 2, cfg.Margin + cfg.Height / 2 end,
    ["bottom-left"]   = function(cfg) return cfg.Margin + cfg.Width / 2,       1.0 - cfg.Margin - cfg.Height / 2 end,
    ["bottom-right"]  = function(cfg) return 1.0 - cfg.Margin - cfg.Width / 2, 1.0 - cfg.Margin - cfg.Height / 2 end,
    ["top-center"]    = function(cfg) return 0.5,                              cfg.Margin + cfg.Height / 2 end,
    ["bottom-center"] = function(cfg) return 0.5,                              1.0 - cfg.Margin - cfg.Height / 2 end,
}

--- Spawns an object and settles it onto the ground below it.
---@param model string
---@param coords vector3|vector4
---@return integer object
local function spawnGroundObject(model, coords)
    lib.requestModel(model)

    local object = CreateObject(joaat(model), coords.x, coords.y, coords.z, true, true, true)
    PlaceObjectOnGroundOrObjectProperly(object)
    SetEntityAsMissionEntity(object, true, true)
    SetModelAsNoLongerNeeded(joaat(model))

    return object
end

--- Deletes an object this file spawned.
---@param object integer|nil
local function deleteObject(object)
    if object and DoesEntityExist(object) then
        SetEntityAsMissionEntity(object, false, true)
        DeleteEntity(object)
    end
end

--- Creates a map blip.
---@param coords vector3|vector4
---@param config { Sprite: integer, Display: integer, Scale: number, Color: integer, Label?: string, Route?: boolean, RouteColor?: integer }
---@return integer blip
local function createBlip(coords, config)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, config.Sprite)
    SetBlipDisplay(blip, config.Display)
    SetBlipScale(blip, config.Scale)
    SetBlipColour(blip, config.Color)
    SetBlipAsShortRange(blip, false)

    if config.Label then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(config.Label)
        EndTextCommandSetBlipName(blip)
    end

    if config.Route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, config.RouteColor)
    end

    return blip
end

--- Removes a map blip.
---@param blip integer|nil
local function removeBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

--- Starts the looping carry animation.
local function startCarryAnimation()
    local anim = Config.Stock.Mission.CarryAnimation

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.name, anim.blendIn, anim.blendOut, anim.duration, anim.flag, 0, false, false, false)
    RemoveAnimDict(anim.dict)
end

--- Stops the carry animation if it is playing.
local function stopCarryAnimation()
    local anim = Config.Stock.Mission.CarryAnimation
    local ped = PlayerPedId()

    if IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
        StopAnimTask(ped, anim.dict, anim.name, anim.blendOut)
    end
end

--- Attaches the box to the player's hand and starts the carry animation.
local function attachBoxToPlayer()
    local config = Config.Stock.Mission.PickupObject
    local ped = PlayerPedId()

    SetEntityVisible(mission.prop, true, false)
    AttachEntityToEntity(
        mission.prop, ped, GetPedBoneIndex(ped, config.bone),
        config.pos.x, config.pos.y, config.pos.z,
        config.rot.x, config.rot.y, config.rot.z,
        true, true, false, true, 1, true
    )

    startCarryAnimation()
end

--- Hides the box inside the vehicle and stops the carry animation.
---@param vehicle integer
local function attachBoxToVehicle(vehicle)
    SetEntityVisible(mission.prop, false, false)
    AttachEntityToEntity(mission.prop, vehicle, 0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    stopCarryAnimation()
end

--- Draws the cargo condition meter for this frame.
local function drawCargoMeter()
    local config = Config.Stock.Mission.DamageMeter
    if not config.Enable or not mission then return end

    local percent = math.max(0, math.min(100, (mission.currentUnits / mission.units) * 100))
    local centerX, centerY = (meterPositions[config.Position] or meterPositions["bottom-right"])(config)

    local background = config.BackgroundColor
    DrawRect(centerX, centerY, config.Width, config.Height, background.r, background.g, background.b, background.a)

    local fillWidth = config.Width * (percent / 100)

    if fillWidth > 0 then
        local color = config.FillColor

        if percent <= config.DangerThreshold then
            color = config.DangerColor
        elseif percent <= config.WarningThreshold then
            color = config.WarningColor
        end

        DrawRect((centerX - config.Width / 2) + (fillWidth / 2), centerY, fillWidth, config.Height, color.r, color.g, color.b, color.a)
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

--- True while a stock mission is running.
---@return boolean
function IsStockMissionActive()
    return mission ~= nil
end

--- True while the player holds the box in their hands.
---@param businessId? integer If given, the box must belong to this business
---@return boolean
function IsCarryingStockBox(businessId)
    if not mission or mission.state ~= "carried" then return false end

    return businessId == nil or mission.businessId == businessId
end

--- Removes everything the mission created, whatever stage it was at.
local function resetMission()
    if not mission then return end

    if mission.state == "carried" then stopCarryAnimation() end
    if mission.point then mission.point:remove() end

    removeBlip(mission.blip)
    removeBlip(mission.deliveryBlip)
    deleteObject(mission.prop)

    mission = nil
end

--- Asks the server to pick up the box, then moves the same box into the player's hands.
local function requestPickup()
    if not mission or not mission.prop then return end

    local response = ServerRequest("t1ger_moneywash:server:pickupStockShipment")

    if not response.success then
        NotifyError(response.reason)
        return
    end

    -- The server may have ended the mission while this request was running
    if not mission then return end

    _API.Target.RemoveLocalEntity(mission.prop, { names = { "moneywash:stock:pickup" } })
    attachBoxToPlayer()

    mission.state = "carried"

    if mission.point then
        mission.point:remove()
        mission.point = nil
    end

    removeBlip(mission.blip)
    mission.blip = nil

    if mission.businessCoords then
        mission.deliveryBlip = createBlip(mission.businessCoords, Config.Stock.Mission.DeliveryBlip)
    end

    _API.ShowNotification(locale("notification.stock_picked_up"), "inform")
end

--- Spawns the box when the player gets near the pickup spot and draws a marker above it.
local function setupPickupPoint()
    local config = Config.Stock.Mission
    local pickup = mission.pickupLocation

    mission.point = lib.points.new({
        coords   = vector3(pickup.x, pickup.y, pickup.z),
        distance = config.PickupDistance,
    })

    function mission.point:onEnter()
        if mission.prop then return end -- already spawned, the player came back

        mission.prop = spawnGroundObject(config.PickupObject.model, pickup)

        _API.Target.AddLocalEntity(mission.prop, {
            {
                name        = "moneywash:stock:pickup",
                icon        = config.Icons.PickupTarget,
                label       = locale("target.pickup_box"),
                distance    = config.PickupTargetDistance,
                canInteract = function()
                    return mission ~= nil and mission.state == "awaiting_pickup"
                end,
                onSelect    = requestPickup,
            },
        })
    end

    function mission.point:nearby()
        if not mission.prop or mission.state ~= "awaiting_pickup" then return end
        if self.currentDistance >= config.PickupMarker.Distance then return end

        local marker = config.PickupMarker
        local coords = GetEntityCoords(mission.prop)

        DrawMarker(
            marker.Type,
            coords.x, coords.y, coords.z + marker.ZOffset,
            0.0, 0.0, 0.0,
            marker.Rotation.x, marker.Rotation.y, marker.Rotation.z,
            marker.Scale.x, marker.Scale.y, marker.Scale.z,
            marker.Color.r, marker.Color.g, marker.Color.b, marker.Color.a,
            marker.BobUpAndDown, marker.FaceCamera, marker.RotationOrder, marker.Rotate,
            nil, nil, false
        )
    end
end

--- Asks the server to load the box into a vehicle.
---@param vehicle integer
local function requestLoad(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local response = ServerRequest("t1ger_moneywash:server:loadStockShipment", netId)

    if not response.success then
        NotifyError(response.reason)
        return
    end

    if not mission then return end

    attachBoxToVehicle(vehicle)

    mission.state = "loaded"
    mission.vehicleNetId = netId

    _API.ShowNotification(locale("notification.stock_loaded"), "inform")
end

--- Asks the server to take the box out of the vehicle.
local function requestUnload()
    local response = ServerRequest("t1ger_moneywash:server:unloadStockShipment")

    if not response.success then
        NotifyError(response.reason)
        return
    end

    if not mission then return end

    attachBoxToPlayer()

    mission.state = "carried"
    mission.vehicleNetId = nil

    _API.ShowNotification(locale("notification.stock_unloaded"), "inform")
end

--- Adds the load and unload options to every vehicle. They can't be removed one by one,
--- so canInteract decides when they show.
local function registerVehicleTargets()
    local config = Config.Stock.Mission

    _API.Target.AddGlobalVehicle({
        {
            name        = "moneywash:stock:load",
            icon        = config.Icons.LoadTarget,
            label       = locale("target.load_stock"),
            distance    = config.VehicleTargetDistance,
            canInteract = function()
                return IsCarryingStockBox()
            end,
            onSelect    = requestLoad,
        },
        {
            name        = "moneywash:stock:unload",
            icon        = config.Icons.UnloadTarget,
            label       = locale("target.unload_stock"),
            distance    = config.VehicleTargetDistance,
            canInteract = function(vehicle)
                return mission ~= nil and mission.state == "loaded"
                    and mission.vehicleNetId == NetworkGetNetworkIdFromEntity(vehicle)
            end,
            onSelect    = requestUnload,
        },
    })
end

--- Starts the mission after the server accepted the order (the order dialog is in menu.lua).
---@param businessId integer
---@param missionData { units: integer, cost: integer, pickupLocation: vector4, businessCoords?: vector3, minutes: integer }
function StartStockMission(businessId, missionData)
    if mission then
        NotifyError("order_already_active")
        return
    end

    mission = {
        businessId     = businessId,
        units          = missionData.units,
        cost           = missionData.cost,
        currentUnits   = missionData.units,
        pickupLocation = missionData.pickupLocation,
        businessCoords = missionData.businessCoords,
        state          = "awaiting_pickup",
    }

    _API.ShowNotification(string.format(locale("notification.stock_order_placed"), missionData.minutes), "inform")

    mission.blip = createBlip(mission.pickupLocation, Config.Stock.Mission.PickupBlip)

    setupPickupPoint()
end

--- Delivers the box at the business. The box must be in the player's hands, not in a vehicle.
function DeliverStock()
    if not IsCarryingStockBox() then return end

    local response = ServerRequest("t1ger_moneywash:server:completeStockDelivery")

    if not response.success then
        NotifyError(response.reason)
        return
    end

    resetMission()
    _API.ShowNotification(locale("notification.stock_delivered"), "success")
end

--- What the player gets back if they cancel now, and what they lose. The server decides the real amounts.
---@return integer|nil refund Nil when there is no mission
---@return integer|nil lost
function GetStockCancelRefund()
    if not mission then return nil end

    local refund = math.floor(mission.cost * (1 - (Config.Stock.Mission.CancelPenaltyPercent or 0) / 100))

    return refund, mission.cost - refund
end

--- Cancels the mission. The server refunds the order minus the penalty and starts the cooldown.
---@return boolean cancelled
function CancelStockOrder()
    if not mission then return false end

    local response = ServerRequest("t1ger_moneywash:server:cancelStockMission")

    if not response.success then
        NotifyError(response.reason)
        return false
    end

    resetMission()
    _API.ShowNotification(string.format(locale("notification.stock_cancelled"), FormatMoney(response.refund)), "inform")

    return true
end

--- Asks the player to confirm, then cancels the stock order.
---@return boolean cancelled
function RequestStockCancel()
    local refund, lost = GetStockCancelRefund()
    if not refund or not ConfirmStockCancel(refund, lost) then return false end

    return CancelStockOrder()
end

--- Places a stock order: checks the cooldown, asks how many units, asks to confirm, then orders.
--- The cost is taken from the bank when the order is placed.
---@param businessId integer
---@param status table From getBusinessStatus
---@return boolean started True if the mission started
function PlaceStockOrder(businessId, status)
    if IsStockMissionActive() then
        NotifyError("order_already_active")
        return false
    end

    local eligibility = ServerRequest("t1ger_moneywash:server:canPlaceStockOrder")

    if eligibility.success == false then
        NotifyError(eligibility.reason)
        return false
    end

    if not eligibility.eligible then
        _API.ShowNotification(string.format(locale("menu.stock.order_on_cooldown"), eligibility.cooldownRemaining or 0), "error")
        return false
    end

    local maxOrder = math.min(status.maxOrder, status.stockCapacity - status.stock)
    local minOrder = math.min(status.minOrder, maxOrder)

    local units = AskStockUnits({ min = minOrder, max = maxOrder, unitPrice = status.unitPrice })
    if not units then return false end

    if units < minOrder or units > maxOrder then
        NotifyError("invalid_units")
        return false
    end

    if not ConfirmStockOrder(units, units * status.unitPrice) then return false end

    local result = ServerRequest("t1ger_moneywash:server:orderStock", businessId, units)

    if not result.success then
        NotifyError(result.reason)
        return false
    end

    StartStockMission(businessId, result.missionData)

    return true
end

--- Restarts the carry animation if something interrupted it while the box is still in the player's hands.
CreateThread(function()
    while true do
        Wait(1000)

        if mission and mission.state == "carried" then
            local anim = Config.Stock.Mission.CarryAnimation
            local ped = PlayerPedId()

            if not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped) and not IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
                startCarryAnimation()
            end
        end
    end
end)

--- Draws the cargo meter every frame while the player has the box. Sleeps otherwise.
CreateThread(function()
    while true do
        if mission and (mission.state == "carried" or mission.state == "loaded") then
            Wait(0)

            drawCargoMeter()

            -- With the box in the hands there is no getting into a vehicle: load it onto one instead
            if mission and mission.state == "carried" then
                DisableControlAction(0, 23, true) -- INPUT_ENTER

                if IsDisabledControlJustPressed(0, 23) then
                    _API.ShowNotification(locale("notification.stock_cannot_enter_vehicle"), "error")
                end
            end
        else
            Wait(1000)
        end
    end
end)

--- Vehicle damage while the box is loaded: tells the server to check for a collision.
--- The server finds the vehicle and rolls the damage, this only shows what it answered.
AddEventHandler("gameEventTriggered", function(eventName, args)
    if eventName ~= "CEventNetworkEntityDamage" then return end
    if not mission or mission.state ~= "loaded" then return end

    local damagedVehicle, entityHit = args[1], args[2]
    if entityHit == -1 then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or damagedVehicle ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    local config = Config.Stock.Mission.CollisionDamage
    if GetEntitySpeed(vehicle) < config.MinImpactSpeed then return end

    local now = GetGameTimer()
    if now - lastCollisionReport < config.PingCooldown then return end
    lastCollisionReport = now

    local response = ServerRequest("t1ger_moneywash:server:reportStockCollision")

    if response.success and mission then
        mission.currentUnits = response.remainingUnits

        _API.ShowNotification(string.format(locale("notification.stock_damaged"), response.deductedPercent, response.remainingUnits), "error")
    end
end)

--- The server ended the mission (it ran out of time, or the business was removed).
RegisterNetEvent("t1ger_moneywash:client:stockMissionEnded", resetMission)

RegisterCommand(Config.Stock.Mission.CancelCommand, CancelStockOrder, false)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then resetMission() end
end)

CreateThread(function()
    while not _Target do Wait(100) end

    registerVehicleTargets()
end)