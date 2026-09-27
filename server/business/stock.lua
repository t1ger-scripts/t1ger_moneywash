-- ============================================================================
-- STOCK DELIVERY MISSION (server)
-- The server owns the shipment record end-to-end. The client only ever
-- requests a transition (pickup / load / unload / deliver / cancel) or
-- reports "a collision happened" - it never reports or sets how much
-- stock was lost, or whether delivery succeeds.
--
-- Shipment states: awaiting_pickup -> carried -> loaded -> carried -> ... -> delivered
-- ("loaded" and "carried" can alternate any number of times as the player
-- switches vehicles or chooses to walk the rest of the way.)
-- ============================================================================

--- Active stock shipments keyed by player source.
--- @field businessId number
--- @field units number             units originally ordered and paid for (fixed)
--- @field currentUnits number      live, decaying deliverable amount (starts == units)
--- @field cost number              amount paid, for refunds
--- @field pickupLocation vector4
--- @field state string             "awaiting_pickup" | "carried" | "loaded"
--- @field vehicleNetId number|nil  set only while state == "loaded"
--- @field lastCollisionCheck number game timer of the last accepted collision ping
local ActiveStockMissions = {}

--- Players currently on a cancel cooldown (re-roll gating), keyed by identifier.
local CancelCooldowns = {}

--- Pool indices currently claimed by an active mission, so two players
--- can never be assigned the same pickup location at once.
--- @field [index] boolean
local OccupiedPickupIndices = {}

-- -----------------------------------------------------------------------
-- ORDER
-- -----------------------------------------------------------------------

--- Releases a claimed pickup location index so another player's mission
--- can use it. Safe to call even if the index was never actually claimed.
--- @param mission table
local function ReleasePickupLocation(mission)
    if mission and mission.pickupIndex then
        OccupiedPickupIndices[mission.pickupIndex] = nil
    end
end

--- Checks whether a player is currently eligible to place a new stock
--- order (i.e. not on a post-cancel cooldown). This is a convenience for
--- the client to show an early warning before the units-input dialog -
--- OrderStock() still re-checks this itself and remains the real gate.
--- @param src number
--- @return boolean eligible, number|nil cooldownRemaining
function CanPlaceStockOrder(src)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false end

    local cooldownUntil = CancelCooldowns[identifier]
    if cooldownUntil and os.time() < cooldownUntil then
        return false, cooldownUntil - os.time()
    end

    return true
end

--- Validates and starts a stock order.
--- Payment is taken from the personal bank account, not the business Safe.
--- @param src number
--- @param businessId number
--- @param units number
--- @return boolean success, string reason, table|nil missionData
function OrderStock(src, businessId, units)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local cooldownUntil = CancelCooldowns[identifier]
    if cooldownUntil and os.time() < cooldownUntil then
        return false, "order_on_cooldown"
    end

    local business = GetBusiness(businessId)
    if not business then return false, "not_found" end
    if business.identifier ~= identifier then return false, "not_owner" end

    for _, mission in pairs(ActiveStockMissions) do
        if mission.businessId == businessId then
            return false, "order_already_active"
        end
    end

    units = math.floor(tonumber(units) or 0)

    local minOrder = GetMinOrder(business.type)
    local maxOrder = GetMaxOrder(business.type)
    local unitPrice = GetUnitPrice(business.type)

    if not minOrder or not maxOrder or not unitPrice then
        return false, "invalid_type"
    end

    if units < minOrder or units > maxOrder then
        return false, "invalid_units"
    end

    local pool = Config.Business.StockMission.PickupLocations
    if not pool or #pool == 0 then
        return false, "no_pickup_locations"
    end

    local freeIndices = {}
    for i = 1, #pool do
        if not OccupiedPickupIndices[i] then
            freeIndices[#freeIndices + 1] = i
        end
    end

    if #freeIndices == 0 then
        return false, "no_pickup_locations"
    end

    local totalCost = units * unitPrice

    if _API.Player.GetMoney(src, "bank") < totalCost then
        return false, "insufficient_funds"
    end

    _API.Player.RemoveMoney(src, totalCost, "bank")

    local pickupIndex = freeIndices[math.random(1, #freeIndices)]
    local pickupLocation = pool[pickupIndex]
    OccupiedPickupIndices[pickupIndex] = true

    ActiveStockMissions[src] = {
        businessId         = businessId,
        units              = units,
        currentUnits       = units,
        cost               = totalCost,
        pickupLocation     = pickupLocation,
        pickupIndex        = pickupIndex,
        state              = "awaiting_pickup",
        vehicleNetId       = nil,
        lastCollisionCheck = 0,
    }

    if Config.Debug then
        print(("[MoneyWash] Stock order: player %d | business %d | %d units | $%d"):format(
            src, businessId, units, totalCost))
    end

    local location = GetLocationConfig(business.type, business.locationId)

    return true, "success", {
        units          = units,
        cost           = totalCost,
        pickupLocation = pickupLocation,
        businessCoords = location and location.coords,
    }
end

-- -----------------------------------------------------------------------
-- PICKUP
-- -----------------------------------------------------------------------

--- Validates the player is actually at the assigned pickup location before
--- allowing the shipment to progress to "carried". Prevents a modified
--- client from skipping the drive entirely.
--- @param src number
--- @return boolean success, string reason
function PickupStockShipment(src)
    local mission = ActiveStockMissions[src]
    if not mission then return false, "no_active_mission" end
    if mission.state ~= "awaiting_pickup" then return false, "invalid_state" end

    if not IsPlayerNearCoords(src, mission.pickupLocation, Config.Business.StockMission.PickupDistance) then
        return false, "pickup_too_far"
    end

    mission.state = "carried"
    return true, "success"
end

-- -----------------------------------------------------------------------
-- LOAD / UNLOAD (vehicle transfers)
-- -----------------------------------------------------------------------

--- Resolves a network ID to a live vehicle entity, or nil if it doesn't exist.
--- @param netId number
--- @return number|nil
local function ResolveVehicle(netId)
    if not netId or netId == 0 then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return nil end

    return entity
end

--- Loads the carried shipment into a vehicle. The player targets the
--- vehicle from outside it, so proximity is validated by distance.
--- @param src number
--- @param vehicleNetId number  the vehicle the client is targeting
--- @return boolean success, string reason
function LoadStockIntoVehicle(src, vehicleNetId)
    local mission = ActiveStockMissions[src]
    if not mission then return false, "no_active_mission" end
    if mission.state ~= "carried" then return false, "invalid_state" end

    local vehicle = ResolveVehicle(vehicleNetId)
    if not vehicle then return false, "invalid_vehicle" end

    if not IsPlayerNearCoords(src, GetEntityCoords(vehicle), Config.Business.StockMission.VehicleTargetDistance) then
        return false, "vehicle_too_far"
    end

    mission.state = "loaded"
    mission.vehicleNetId = vehicleNetId
    mission.lastCollisionCheck = 0

    return true, "success"
end

--- Removes the shipment from its current vehicle.
--- @param src number
--- @return boolean success, string reason
function UnloadStockFromVehicle(src)
    local mission = ActiveStockMissions[src]
    if not mission then return false, "no_active_mission" end
    if mission.state ~= "loaded" then return false, "invalid_state" end

    local vehicle = ResolveVehicle(mission.vehicleNetId)
    if vehicle then
        if not IsPlayerNearCoords(src, GetEntityCoords(vehicle), Config.Business.StockMission.VehicleTargetDistance) then
            return false, "vehicle_too_far"
        end
    end

    mission.state = "carried"
    mission.vehicleNetId = nil

    return true, "success"
end

-- -----------------------------------------------------------------------
-- COLLISION REPORTING
-- -----------------------------------------------------------------------

--- Lightweight ping from the client's collision detection. Carries no
--- authoritative damage data - it only tells the server "check now". The
--- server independently resolves the real vehicle and rolls the penalty
--- itself; the client's claimed vehicle ID is cross-check-only.
--- @param src number
--- @param clientVehicleNetId number|nil
--- @return boolean applied, number|nil deductedPercent, number|nil currentUnits
function ReportVehicleCollision(src, clientVehicleNetId)
    local cfg = Config.Business.StockMission.CollisionDamage
    if not cfg.Enable then return false end

    local mission = ActiveStockMissions[src]
    if not mission or mission.state ~= "loaded" then return false end

    local now = GetGameTimer()
    if now - (mission.lastCollisionCheck or 0) < cfg.PingCooldown then
        return false
    end
    mission.lastCollisionCheck = now

    -- The server resolves the vehicle itself - it never trusts the client's claim.
    local playerPed = GetPlayerPed(src)
    local serverVehicle = GetVehiclePedIsIn(playerPed, false)
    if serverVehicle == 0 then return false end

    local serverNetId = NetworkGetNetworkIdFromEntity(serverVehicle)
    if serverNetId ~= mission.vehicleNetId then return false end

    if Config.Debug and clientVehicleNetId and clientVehicleNetId ~= serverNetId then
        print(("[MoneyWash] Stock collision vehicle mismatch for player %d (client: %s, server: %s)"):format(
            src, tostring(clientVehicleNetId), tostring(serverNetId)))
    end

    local deductionPercent = math.random(cfg.MinDeductionPercent, cfg.MaxDeductionPercent)
    mission.currentUnits = math.max(0, mission.currentUnits - (mission.currentUnits * (deductionPercent / 100)))

    if Config.Debug then
        print(("[MoneyWash] Stock collision: player %d | -%d%% | %.1f units remaining"):format(
            src, deductionPercent, mission.currentUnits))
    end

    return true, deductionPercent, math.floor(mission.currentUnits)
end

-- -----------------------------------------------------------------------
-- DELIVERY
-- -----------------------------------------------------------------------

--- Completes a stock delivery. Requires the shipment to have already been
--- unloaded (state == "carried") - the player must physically be holding
--- it, not still driving with it in the vehicle.
--- @param src number
--- @return boolean success, string reason
function CompleteStockDelivery(src)
    local mission = ActiveStockMissions[src]
    if not mission then return false, "no_active_mission" end
    if mission.state ~= "carried" then return false, "invalid_state" end

    local business = GetBusiness(mission.businessId)
    if not business then
        ActiveStockMissions[src] = nil
        return false, "business_not_found"
    end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location or not IsPlayerNearCoords(src, location.coords, 5.0) then
        return false, "business_too_far"
    end

    local deliveredUnits = math.floor(mission.currentUnits)

    UpdateBusiness(mission.businessId, "stock", business.stock + deliveredUnits)

    MySQL.insert(
        "INSERT INTO moneywash_receipts (business_id, units, unit_price, total_amount, created_at) VALUES (?, ?, ?, ?, ?)",
        { mission.businessId, deliveredUnits, GetUnitPrice(business.type), mission.cost, os.time() }
    )

    if Config.Reputation.Enable and Config.Reputation.Rewards.stockDelivery.enable then
        AddReputationPoints(src, Config.Reputation.Rewards.stockDelivery.points)
    end

    OnStockOrderCompleted(business.identifier, mission.businessId, business.type, mission.units, deliveredUnits, mission.cost)

    if Config.Debug then
        print(("[MoneyWash] Stock delivered: business %d | ordered %d | delivered %d units"):format(
            mission.businessId, mission.units, deliveredUnits))
    end

    ReleasePickupLocation(mission)
    ActiveStockMissions[src] = nil

    return true, "success"
end

-- -----------------------------------------------------------------------
-- CANCEL
-- -----------------------------------------------------------------------

--- Cancels an active mission voluntarily. Refunds the original cost minus
--- a configurable penalty, and applies a cooldown to gate re-rolling for a
--- more favourable pickup location. The penalty is flat and unrelated to
--- any cargo damage already accrued.
--- @param src number
--- @return boolean success, string reason, number|nil refundAmount
function CancelStockMission(src)
    local mission = ActiveStockMissions[src]
    if not mission then return false, "no_active_mission" end

    local identifier = _API.Player.GetIdentifier(src)
    local penaltyPercent = Config.Business.StockMission.CancelPenaltyPercent or 0
    local refund = math.floor(mission.cost * (1 - (penaltyPercent / 100)))

    _API.Player.AddMoney(src, refund, "bank")
    ReleasePickupLocation(mission)
    ActiveStockMissions[src] = nil

    if identifier then
        CancelCooldowns[identifier] = os.time() + (Config.Business.StockMission.CancelCooldown or 0)
    end

    if Config.Debug then
        print(("[MoneyWash] Stock mission cancelled: player %d | refunded $%d (penalty %d%%)"):format(
            src, refund, penaltyPercent))
    end

    return true, "success", refund
end

--- Cleans up an active mission on disconnect. Full refund, no penalty -
--- this isn't a voluntary re-roll attempt.
--- @param src number
function OnPlayerDroppedStockCleanup(src)
    local mission = ActiveStockMissions[src]
    if mission then
        _API.Player.AddMoney(src, mission.cost, "bank")
        ReleasePickupLocation(mission)
        ActiveStockMissions[src] = nil
    end
end

--- Returns a player's active stock mission, if one exists.
--- @param src number
--- @return table|nil
function GetActiveStockMission(src)
    return ActiveStockMissions[src]
end

lib.callback.register("t1ger_moneywash:server:orderStock", function(source, businessId, units)
    local success, reason, missionData = OrderStock(source, businessId, units)
    return { success = success, reason = reason, missionData = missionData }
end)

lib.callback.register("t1ger_moneywash:server:canPlaceStockOrder", function(source)
    local eligible, cooldownRemaining = CanPlaceStockOrder(source)
    return { eligible = eligible, cooldownRemaining = cooldownRemaining }
end)

lib.callback.register("t1ger_moneywash:server:pickupStockShipment", function(source)
    local success, reason = PickupStockShipment(source)
    return { success = success, reason = reason }
end)

lib.callback.register("t1ger_moneywash:server:loadStockShipment", function(source, vehicleNetId)
    local success, reason = LoadStockIntoVehicle(source, vehicleNetId)
    return { success = success, reason = reason }
end)

lib.callback.register("t1ger_moneywash:server:unloadStockShipment", function(source)
    local success, reason = UnloadStockFromVehicle(source)
    return { success = success, reason = reason }
end)

lib.callback.register("t1ger_moneywash:server:reportStockCollision", function(source, vehicleNetId)
    local applied, deductedPercent, remainingUnits = ReportVehicleCollision(source, vehicleNetId)
    return applied, deductedPercent, remainingUnits
end)

lib.callback.register("t1ger_moneywash:server:completeStockDelivery", function(source)
    local success, reason = CompleteStockDelivery(source)
    return { success = success, reason = reason }
end)

lib.callback.register("t1ger_moneywash:server:cancelStockMission", function(source)
    local success, reason, refund = CancelStockMission(source)
    return { success = success, reason = reason, refund = refund }
end)