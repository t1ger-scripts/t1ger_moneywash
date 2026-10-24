--- Stock delivery mission (server). The server owns the mission from order to delivery.
--- The client only asks for a step (pickup, load, unload, deliver, cancel) or reports a collision,
--- it never sets how much stock is lost or whether a delivery works.
--- States: awaiting_pickup -> carried <-> loaded -> delivered. The box can be loaded into a vehicle
--- and taken out again any number of times.
--- The order is paid when it is placed and lives in memory only. A disconnect is refunded when the
--- player is back, a resource restart refunds it, a timeout or a server restart does not.

---@class StockMission
---@field identifier string
---@field businessId integer
---@field units integer Units ordered and paid for
---@field currentUnits number Units that can still be delivered, lowered by collisions
---@field cost integer Paid for the order, refunded if it is cancelled
---@field pickupLocation vector4
---@field pickupIndex integer Index in Config.Stock.Mission.PickupLocations
---@field state "awaiting_pickup"|"carried"|"loaded"
---@field vehicleNetId? integer Only while loaded
---@field lastCollisionCheck integer GetGameTimer() of the last accepted collision report
---@field expiresAt integer os.time() the order runs out

---@type table<integer, StockMission> Active missions by player source
local Missions = {}

---@type table<string, integer> Refunds for players who disconnected, by identifier. Memory only.
local PendingRefunds = {}

---@type table<string, integer> os.time() before which a player can't order again, by identifier
local CancelCooldowns = {}

---@type table<integer, boolean> Pickup spots in use, by index in Config.Stock.Mission.PickupLocations
local OccupiedPickups = {}

---@param reason string|nil Nil on success
---@return { success: boolean, reason?: string }
local function result(reason)
    return { success = reason == nil, reason = reason }
end

--- Ends a mission and frees its pickup spot. Money is not touched here.
---@param src integer
---@param mission StockMission
local function finishMission(src, mission)
    OccupiedPickups[mission.pickupIndex] = nil
    Missions[src] = nil
end

--- Tells the client its mission is over, so it removes the box, the blips and the meter.
---@param src integer
local function notifyMissionEnded(src)
    TriggerClientEvent("t1ger_moneywash:client:stockMissionEnded", src)
end

--- The player's mission, optionally in a required state.
---@param src integer
---@param state? "awaiting_pickup"|"carried"|"loaded"
---@return StockMission|nil mission
---@return string|nil reason
local function getMission(src, state)
    local mission = Missions[src]
    if not mission then return nil, "no_active_mission" end
    if state and mission.state ~= state then return nil, "invalid_state" end

    return mission
end

--- Seconds until the player may order again.
---@param identifier string
---@return integer seconds 0 when the player may order
local function getCooldownRemaining(identifier)
    return math.max(0, (CancelCooldowns[identifier] or 0) - os.time())
end

--- A random pickup spot that no other mission uses.
---@return integer|nil index
local function pickFreePickup()
    local free = {}

    for index = 1, #Config.Stock.Mission.PickupLocations do
        if not OccupiedPickups[index] then free[#free + 1] = index end
    end

    if #free == 0 then return nil end

    return free[math.random(1, #free)]
end

--- The vehicle entity for a network id, or nil if it doesn't exist.
---@param netId integer
---@return integer|nil entity
local function resolveVehicle(netId)
    if not netId or netId == 0 then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return nil end

    return entity
end

--- True if the business has a stock mission running. Checked by transfer and abandon.
---@param businessId integer
---@return boolean
function HasActiveStockOrder(businessId)
    for _, mission in pairs(Missions) do
        if mission.businessId == businessId then return true end
    end

    return false
end

--- Ends the stock mission of a business that is being removed, and refunds it in full.
---@param businessId integer
function EndStockOrderForBusiness(businessId)
    for src, mission in pairs(Missions) do
        if mission.businessId == businessId then
            _API.Player.AddMoney(src, mission.cost, "bank")
            finishMission(src, mission)
            _API.SendNotification(src, string.format(locale("notification.stock_refunded"), FormatMoney(mission.cost)), "inform")
            notifyMissionEnded(src)
            return
        end
    end
end

--- A player disconnected: the mission ends and the refund waits until they are back.
--- The refund can't be paid now, the framework has already unloaded the player.
---@param src integer
function HandleStockPlayerDropped(src)
    local mission = Missions[src]
    if not mission then return end

    PendingRefunds[mission.identifier] = (PendingRefunds[mission.identifier] or 0) + mission.cost
    finishMission(src, mission)
end

--- A player loaded in: pays the refund of a mission they left behind when they disconnected.
---@param src integer
function PayPendingStockRefund(src)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return end

    -- The old connection may not have dropped yet (client crash and a quick reconnect)
    for oldSrc, mission in pairs(Missions) do
        if oldSrc ~= src and mission.identifier == identifier then HandleStockPlayerDropped(oldSrc) end
    end

    local amount = PendingRefunds[identifier]
    if not amount then return end

    PendingRefunds[identifier] = nil
    _API.Player.AddMoney(src, amount, "bank")
    _API.SendNotification(src, string.format(locale("notification.stock_refunded"), FormatMoney(amount)), "inform")
end

--- Places an order. The money is taken from the bank account, not the Safe.
---@param src integer
---@param businessId any
---@param units any
---@return string|nil reason
---@return table|nil missionData
local function placeOrder(src, businessId, units)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return "invalid_player" end
    if getCooldownRemaining(identifier) > 0 then return "order_on_cooldown" end

    businessId = tonumber(businessId)
    local business = businessId and GetBusiness(businessId)
    if not business then return "not_found" end
    if business.identifier ~= identifier then return "not_owner" end
    if Missions[src] or HasActiveStockOrder(businessId) then return "order_already_active" end

    local pickupIndex = pickFreePickup()
    if not pickupIndex then return "no_pickup_locations" end

    local minOrder, maxOrder, unitPrice = GetMinOrder(business.type), GetMaxOrder(business.type), GetUnitPrice(business.type)
    if not minOrder or not maxOrder or not unitPrice then return "invalid_type" end

    units = math.floor(tonumber(units) or 0)
    if units < minOrder or units > maxOrder then return "invalid_units" end

    local room = GetStockCapacity(business.type) - business.stock
    if room <= 0 then return "stock_full" end

    -- Clamped down rather than rejected, so the trip is never wasted
    units = math.min(units, room)

    local cost = units * unitPrice
    local bank = _API.Player.GetMoney(src, "bank")
    if bank < cost then return "insufficient_funds" end

    _API.Player.RemoveMoney(src, cost, "bank")
    if _API.Player.GetMoney(src, "bank") > bank - cost then return "request_failed" end

    local config = Config.Stock.Mission
    local pickupLocation = config.PickupLocations[pickupIndex]
    OccupiedPickups[pickupIndex] = true

    Missions[src] = {
        identifier         = identifier,
        businessId         = businessId,
        units              = units,
        currentUnits       = units,
        cost               = cost,
        pickupLocation     = pickupLocation,
        pickupIndex        = pickupIndex,
        state              = "awaiting_pickup",
        lastCollisionCheck = 0,
        expiresAt          = os.time() + math.max(1, tonumber(config.MaxTime) or 30) * 60,
    }

    local location = GetLocationConfig(business.type, business.locationId)

    return nil, {
        units          = units,
        cost           = cost,
        pickupLocation = pickupLocation,
        businessCoords = location and location.coords,
        minutes        = math.max(1, tonumber(config.MaxTime) or 30),
    }
end

--- The player picks up the box. They must be at the assigned pickup spot.
---@param src integer
---@return string|nil reason
local function pickupShipment(src)
    local mission, reason = getMission(src, "awaiting_pickup")
    if not mission then return reason end

    if not IsPlayerNearCoords(src, mission.pickupLocation, Config.Stock.Mission.PickupDistance) then
        return "pickup_too_far"
    end

    mission.state = "carried"

    return nil
end

--- The player loads the carried box into a vehicle they stand next to.
---@param src integer
---@param vehicleNetId integer
---@return string|nil reason
local function loadShipment(src, vehicleNetId)
    local mission, reason = getMission(src, "carried")
    if not mission then return reason end

    local vehicle = resolveVehicle(vehicleNetId)
    if not vehicle then return "invalid_vehicle" end

    if not IsPlayerNearCoords(src, GetEntityCoords(vehicle), Config.Stock.Mission.VehicleTargetDistance) then
        return "vehicle_too_far"
    end

    mission.state = "loaded"
    mission.vehicleNetId = vehicleNetId
    mission.lastCollisionCheck = 0

    return nil
end

--- The player takes the box out of the vehicle.
---@param src integer
---@return string|nil reason
local function unloadShipment(src)
    local mission, reason = getMission(src, "loaded")
    if not mission then return reason end

    local vehicle = resolveVehicle(mission.vehicleNetId)
    if vehicle and not IsPlayerNearCoords(src, GetEntityCoords(vehicle), Config.Stock.Mission.VehicleTargetDistance) then
        return "vehicle_too_far"
    end

    mission.state = "carried"
    mission.vehicleNetId = nil

    return nil
end

--- A collision report from the client. It only says "check now": the server finds the vehicle
--- itself and rolls the damage, and the client's own vehicle id is never trusted.
---@param src integer
---@return boolean applied
---@return integer|nil deductedPercent
---@return integer|nil remainingUnits
local function reportCollision(src)
    local config = Config.Stock.Mission.CollisionDamage
    if not config.Enable then return false end

    local mission = getMission(src, "loaded")
    if not mission then return false end

    local now = GetGameTimer()
    if now - mission.lastCollisionCheck < config.PingCooldown then return false end
    mission.lastCollisionCheck = now

    local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if vehicle == 0 or NetworkGetNetworkIdFromEntity(vehicle) ~= mission.vehicleNetId then return false end

    local percent = math.random(config.MinDeductionPercent, config.MaxDeductionPercent)
    mission.currentUnits = math.max(0, mission.currentUnits - mission.currentUnits * (percent / 100))

    return true, percent, math.floor(mission.currentUnits)
end

--- Delivers the box at the business. The player must hold it, not drive with it loaded.
---@param src integer
---@return string|nil reason
local function completeDelivery(src)
    local mission, reason = getMission(src, "carried")
    if not mission then return reason end

    local business = GetBusiness(mission.businessId)
    if not business then
        _API.Player.AddMoney(src, mission.cost, "bank")
        finishMission(src, mission)
        return "not_found"
    end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location or not IsPlayerNearCoords(src, location.coords, Config.Stock.Mission.PickupTargetDistance + 2.0) then
        return "business_too_far"
    end

    local delivered = math.floor(mission.currentUnits)
    local capacity = GetStockCapacity(business.type) or business.stock

    UpdateBusiness(mission.businessId, "stock", math.min(capacity, business.stock + delivered))

    -- Ended before the database call below, which yields
    finishMission(src, mission)

    local ok, err = pcall(MySQL.insert.await,
        "INSERT INTO moneywash_receipts (business_id, units, unit_price, total_amount, created_at) VALUES (?, ?, ?, ?, ?)",
        { mission.businessId, delivered, GetUnitPrice(business.type), mission.cost, os.time() })

    if not ok then
        print(("[MoneyWash] Stock receipt for business %d could not be saved: %s"):format(mission.businessId, tostring(err)))
    end

    if Config.Reputation.Enable and Config.Reputation.Rewards.stockDelivery.enable then
        AwardReputationPoints(src, business.identifier, Config.Reputation.Rewards.stockDelivery.points)
    end

    RunHook("OnStockOrderCompleted", business.identifier, mission.businessId, business.type, mission.units, delivered, mission.cost)

    return nil
end

--- The player cancels: the order is refunded minus the penalty, and a cooldown starts.
---@param src integer
---@return string|nil reason
---@return integer|nil refund
local function cancelOrder(src)
    local mission, reason = getMission(src)
    if not mission then return reason end

    local penalty = Config.Stock.Mission.CancelPenaltyPercent or 0
    local refund = math.floor(mission.cost * (1 - penalty / 100))

    _API.Player.AddMoney(src, refund, "bank")
    finishMission(src, mission)
    CancelCooldowns[mission.identifier] = os.time() + (Config.Stock.Mission.CancelCooldown or 0)

    return nil, refund
end

--- Callback: places an order.
---@param src integer
---@param businessId integer
---@param units integer
lib.callback.register("t1ger_moneywash:server:orderStock", function(src, businessId, units)
    local reason, missionData = placeOrder(src, businessId, units)

    return { success = reason == nil, reason = reason, missionData = missionData }
end)

--- Callback: early warning for the order dialog. placeOrder checks the cooldown again.
---@param src integer
lib.callback.register("t1ger_moneywash:server:canPlaceStockOrder", function(src)
    local identifier = _API.Player.GetIdentifier(src)
    local remaining = identifier and getCooldownRemaining(identifier) or 0

    return { eligible = remaining == 0, cooldownRemaining = remaining > 0 and remaining or nil }
end)

--- Callback: picks up the box.
---@param src integer
lib.callback.register("t1ger_moneywash:server:pickupStockShipment", function(src)
    return result(pickupShipment(src))
end)

--- Callback: loads the box into a vehicle.
---@param src integer
---@param vehicleNetId integer
lib.callback.register("t1ger_moneywash:server:loadStockShipment", function(src, vehicleNetId)
    return result(loadShipment(src, tonumber(vehicleNetId)))
end)

--- Callback: takes the box out of the vehicle.
---@param src integer
lib.callback.register("t1ger_moneywash:server:unloadStockShipment", function(src)
    return result(unloadShipment(src))
end)

--- Callback: a collision report. The answer carries the damage the server rolled.
---@param src integer
lib.callback.register("t1ger_moneywash:server:reportStockCollision", function(src)
    local applied, deductedPercent, remainingUnits = reportCollision(src)

    return { success = applied, deductedPercent = deductedPercent, remainingUnits = remainingUnits }
end)

--- Callback: delivers the box.
---@param src integer
lib.callback.register("t1ger_moneywash:server:completeStockDelivery", function(src)
    return result(completeDelivery(src))
end)

--- Callback: cancels the order.
---@param src integer
lib.callback.register("t1ger_moneywash:server:cancelStockMission", function(src)
    local reason, refund = cancelOrder(src)

    return { success = reason == nil, reason = reason, refund = refund }
end)

--- Ends missions that ran out of time. The money is lost, and the player is told.
CreateThread(function()
    while true do
        Wait(next(Missions) and 5000 or 10000)

        local now = os.time()

        for src, mission in pairs(Missions) do
            if now >= mission.expiresAt then
                finishMission(src, mission)
                _API.SendNotification(src, locale("notification.stock_expired"), "error")
                notifyMissionEnded(src)
            end
        end
    end
end)

--- Refunds every mission when the resource stops, in full. Players are still online here.
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for src, mission in pairs(Missions) do
        _API.Player.AddMoney(src, mission.cost, "bank")
        finishMission(src, mission)
    end
end)

--- Most stock units a business can hold at once.
---@param businessType string
---@return number|nil
function GetStockCapacity(businessType)
    local tier = GetTierByType(businessType)
    if not tier then return nil end

    local cfg = Config.Stock
    local unitsPerCycle = tier.expectedRevenue / cfg.LaunderDollarsPerUnit

    return math.floor(unitsPerCycle * cfg.MaxCapacityCycles)
end

--- Price of one stock unit. The same for every business type.
---@param businessType string
---@return number|nil
function GetUnitPrice(businessType)
    if not GetTierByType(businessType) then return nil end

    local cfg = Config.Stock

    return math.floor(cfg.LaunderDollarsPerUnit * (cfg.UnitPricePercent / 100))
end

--- Smallest order, in units.
---@param businessType string
---@return number|nil
function GetMinOrder(businessType)
    local capacity = GetStockCapacity(businessType)
    if not capacity then return nil end

    return math.max(1, math.floor(capacity * (Config.Stock.MinOrderPercent / 100)))
end

--- Largest order, in units.
---@param businessType string
---@return number|nil
function GetMaxOrder(businessType)
    local capacity = GetStockCapacity(businessType)
    if not capacity then return nil end

    return math.floor(capacity * (Config.Stock.MaxOrderPercent / 100))
end

--- Stock units needed to launder a dollar amount.
---@param amount number
---@return number
function GetStockUnitsForAmount(amount)
    return math.ceil(amount / Config.Stock.LaunderDollarsPerUnit)
end