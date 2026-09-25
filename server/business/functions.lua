--- ============================================================================
--- Business Functions
--- All business logic: purchase, launder, stock, suspicion, raids, deposits,
--- and accountant review. Reads and writes state via store.lua functions.
--- Callbacks and events live in server/business/main.lua.
--- ============================================================================

--- ============================================================================
--- PURCHASE / OWNERSHIP
--- ============================================================================

--- Active ownership mutations.
--- Prevents two simultaneous actions from modifying the same owner or location.
local OwnershipLocks = {}

--- Attempts to acquire all supplied ownership locks.
--- @param keys string[]
--- @return boolean
local function TryAcquireOwnershipLocks(keys)
    for _, key in ipairs(keys) do
        if OwnershipLocks[key] then
            return false
        end
    end

    for _, key in ipairs(keys) do
        OwnershipLocks[key] = true
    end

    return true
end

--- Releases previously acquired ownership locks.
--- @param keys string[]
local function ReleaseOwnershipLocks(keys)
    for _, key in ipairs(keys) do
        OwnershipLocks[key] = nil
    end
end

--- Returns whether a player meets the reputation requirement for a given tier
--- @param src number
--- @param tier table
--- @return boolean
local function MeetsReputationRequirement(src, tier)
    if not Config.Reputation.Enable then return true end
    local rep = GetPlayerReputation(src)
    if not rep then return false end
    return rep:GetPoints() >= tier.requiredPoints
end

--- Purchases a business for a player
--- @param src number
--- @param businessType string
--- @param locationId number
--- @return boolean success, string reason
function BuyBusiness(src, businessType, locationId)
    if not IsBusinessStoreReady() then
        return false, "business_store_not_ready"
    end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then
        return false, "invalid_player"
    end

    if type(businessType) ~= "string" then
        return false, "invalid_type"
    end

    locationId = tonumber(locationId)
    if not locationId then
        return false, "invalid_location"
    end

    local tier = GetTierByType(businessType)
    if not tier then
        return false, "invalid_type"
    end

    local location = GetLocationConfig(businessType, locationId)
    if not location or not location.coords then
        return false, "invalid_location"
    end

    local lockKeys = {
        ("owner:%s"):format(identifier),
        ("location:%s:%d"):format(businessType, locationId),
    }

    if not TryAcquireOwnershipLocks(lockKeys) then
        return false, "operation_in_progress"
    end

    -- Repeat all mutable checks after acquiring the locks.
    if IsLocationOwned(businessType, locationId) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "already_owned"
    end

    if PlayerOwnsBusiness(identifier) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "already_owns_business"
    end

    if not MeetsReputationRequirement(src, tier) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "insufficient_reputation"
    end

    local price = tonumber(location.price)
    if not price or price <= 0 then
        ReleaseOwnershipLocks(lockKeys)
        return false, "invalid_price"
    end

    if _API.Player.GetMoney(src, "bank") < price then
        ReleaseOwnershipLocks(lockKeys)
        return false, "insufficient_funds"
    end

    _API.Player.RemoveMoney(src, price, "bank")

    local now = os.time()

    local insertSucceeded, id = pcall(
        MySQL.insert.await,
        "INSERT INTO moneywash_businesses " ..
        "(identifier, business_type, location_id, location_x, location_y, location_z, " ..
        "stock, safe_covered, safe_exposed, suspicion, total_laundered, " ..
        "last_laundered_at, is_closed, purchased_at) " ..
        "VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0, 0, ?)",
        {
            identifier,
            businessType,
            locationId,
            location.coords.x + 0.0,
            location.coords.y + 0.0,
            location.coords.z + 0.0,
            now,
        }
    )

    if not insertSucceeded or not id then
        -- Restore the payment if the insert failed, including duplicate-key races.
        _API.Player.AddMoney(src, price, "bank")
        ReleaseOwnershipLocks(lockKeys)

        if Config.Debug then
            print(("[MoneyWash] Purchase database error: %s"):format(
                tostring(id)
            ))
        end

        return false, "database_error"
    end

    AddToStore(id, {
        identifier        = identifier,
        business_type     = businessType,
        location_id       = locationId,
        stock             = 0,
        safe_covered      = 0,
        safe_exposed      = 0,
        suspicion         = 0,
        total_laundered   = 0,
        last_laundered_at = 0,
        is_closed         = false,
        closed_until      = nil,
        purchased_at      = now,
    })

    -- The database and in-memory store are now synchronized.
    ReleaseOwnershipLocks(lockKeys)

    -- Award reputation for the first currently registered business of this type.
    if Config.Reputation.Enable and
        Config.Reputation.Rewards.businessPurchase.enable
    then
        local previouslyOwned = MySQL.scalar.await(
            "SELECT COUNT(*) FROM moneywash_businesses " ..
            "WHERE identifier = ? AND business_type = ? AND id != ?",
            {
                identifier,
                businessType,
                id,
            }
        )

        if (previouslyOwned or 0) == 0 then
            AddReputationPoints(
                src,
                Config.Reputation.Rewards.businessPurchase.points
            )
        end
    end

    TriggerClientEvent("t1ger_moneywash:client:businessPurchased", src, id, businessType, locationId)

    if Config.Debug then
        print(("[MoneyWash] %s purchased %s #%d for $%d"):format(
            identifier,
            businessType,
            locationId,
            price
        ))
    end

    return true, "success"
end

--- Returns whether two players are within the configured transfer distance.
--- @param sourcePlayer number
--- @param targetPlayer number
--- @return boolean
local function ArePlayersWithinTransferDistance(sourcePlayer, targetPlayer)
    local sourcePed = GetPlayerPed(sourcePlayer)
    local targetPed = GetPlayerPed(targetPlayer)

    if not sourcePed or sourcePed == 0 then
        return false
    end

    if not targetPed or targetPed == 0 then
        return false
    end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(sourceCoords - targetCoords)

    return distance <= (Config.Business.TransferDistance or 10.0)
end

--- Transfers a business to another nearby online player.
--- The new owner inherits the complete business state.
--- @param src number Current owner's server ID
--- @param targetSrc number New owner's server ID
--- @param businessId number
--- @return boolean success, string reason
function TransferBusiness(src, targetSrc, businessId)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then
        return false, "invalid_player"
    end

    targetSrc = tonumber(targetSrc)
    businessId = tonumber(businessId)

    if not targetSrc then
        return false, "target_not_online"
    end

    if not businessId then
        return false, "not_found"
    end

    if targetSrc == src then
        return false, "self_transfer"
    end

    local targetIdentifier = _API.Player.GetIdentifier(targetSrc)
    if not targetIdentifier then
        return false, "target_not_online"
    end

    local business = GetBusiness(businessId)
    if not business then
        return false, "not_found"
    end

    if business.identifier ~= identifier then
        return false, "not_owner"
    end

    if not ArePlayersWithinTransferDistance(src, targetSrc) then
        return false, "target_too_far"
    end

    local lockKeys = {
        ("business:%d"):format(businessId),
        ("owner:%s"):format(identifier),
        ("owner:%s"):format(targetIdentifier),
    }

    if not TryAcquireOwnershipLocks(lockKeys) then
        return false, "operation_in_progress"
    end

    -- Revalidate all mutable state after acquiring the locks.
    business = GetBusiness(businessId)

    if not business then
        ReleaseOwnershipLocks(lockKeys)
        return false, "not_found"
    end

    if business.identifier ~= identifier then
        ReleaseOwnershipLocks(lockKeys)
        return false, "not_owner"
    end

    targetIdentifier = _API.Player.GetIdentifier(targetSrc)

    if not targetIdentifier then
        ReleaseOwnershipLocks(lockKeys)
        return false, "target_not_online"
    end

    if not ArePlayersWithinTransferDistance(src, targetSrc) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "target_too_far"
    end

    local stockMission = GetActiveStockMission(src)

    if stockMission and stockMission.businessId == businessId then
        ReleaseOwnershipLocks(lockKeys)
        return false, "active_stock_mission"
    end

    local pendingDeposit = GetActiveDeposit(identifier)

    if pendingDeposit and pendingDeposit.business_id == businessId then
        ReleaseOwnershipLocks(lockKeys)
        return false, "pending_business_deposit"
    end

    if GetQueuedRaids()[businessId] then
        ReleaseOwnershipLocks(lockKeys)
        return false, "raid_pending"
    end

    if PlayerOwnsBusiness(targetIdentifier) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "target_owns_business"
    end

    local tier = GetTierByType(business.type)

    if not tier then
        ReleaseOwnershipLocks(lockKeys)
        return false, "invalid_type"
    end

    if not MeetsReputationRequirement(targetSrc, tier) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "target_insufficient_reputation"
    end

    local updateSucceeded, affectedRows = pcall(
        MySQL.update.await,
        "UPDATE moneywash_businesses " ..
        "SET identifier = ? " ..
        "WHERE id = ? AND identifier = ?",
        {
            targetIdentifier,
            businessId,
            identifier,
        }
    )

    if not updateSucceeded or affectedRows ~= 1 then
        ReleaseOwnershipLocks(lockKeys)

        if Config.Debug then
            print(("[MoneyWash] Transfer database error: %s"):format(
                tostring(affectedRows)
            ))
        end

        return false, "database_error"
    end

    UpdateBusiness(businessId, "identifier", targetIdentifier)
    ReleaseOwnershipLocks(lockKeys)

    TriggerClientEvent(
        "t1ger_moneywash:client:businessTransferred",
        src,
        businessId
    )

    TriggerClientEvent(
        "t1ger_moneywash:client:businessReceived",
        targetSrc,
        businessId,
        business.type,
        business.locationId
    )

    if Config.Debug then
        print(("[MoneyWash] Business %d transferred: %s -> %s"):format(
            businessId,
            identifier,
            targetIdentifier
        ))
    end

    return true, "success"
end

--- Abandons a business with zero refund.
--- Safe balance, stock and all business progress are forfeited.
--- @param src number
--- @param businessId number
--- @return boolean success, string reason
function AbandonBusiness(src, businessId)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then
        return false, "invalid_player"
    end

    businessId = tonumber(businessId)
    if not businessId then
        return false, "not_found"
    end

    local business = GetBusiness(businessId)
    if not business then
        return false, "not_found"
    end

    if business.identifier ~= identifier then
        return false, "not_owner"
    end

    local lockKeys = {
        ("business:%d"):format(businessId),
        ("owner:%s"):format(identifier),
        ("location:%s:%d"):format(
            business.type,
            business.locationId
        ),
    }

    if not TryAcquireOwnershipLocks(lockKeys) then
        return false, "operation_in_progress"
    end

    -- Revalidate ownership after acquiring the locks.
    business = GetBusiness(businessId)

    if not business then
        ReleaseOwnershipLocks(lockKeys)
        return false, "not_found"
    end

    if business.identifier ~= identifier then
        ReleaseOwnershipLocks(lockKeys)
        return false, "not_owner"
    end

    local stockMission = GetActiveStockMission(src)

    if stockMission and stockMission.businessId == businessId then
        ReleaseOwnershipLocks(lockKeys)
        return false, "active_stock_mission"
    end

    local pendingDeposit = GetActiveDeposit(identifier)

    if pendingDeposit and pendingDeposit.business_id == businessId then
        ReleaseOwnershipLocks(lockKeys)
        return false, "pending_business_deposit"
    end

    if GetQueuedRaids()[businessId] then
        ReleaseOwnershipLocks(lockKeys)
        return false, "raid_pending"
    end

    local transactionExecuted, transactionSucceeded = pcall(
        MySQL.transaction.await,
        {
            {
                query = "DELETE FROM moneywash_receipts WHERE business_id = ?",
                values = { businessId },
            },
            {
                query = "DELETE FROM moneywash_businesses " ..
                    "WHERE id = ? AND identifier = ?",
                values = {
                    businessId,
                    identifier,
                },
            },
        }
    )

    if not transactionExecuted or not transactionSucceeded then
        ReleaseOwnershipLocks(lockKeys)

        if Config.Debug then
            print(("[MoneyWash] Abandon database error: %s"):format(
                tostring(transactionSucceeded)
            ))
        end

        return false, "database_error"
    end

    RemoveFromStore(businessId)
    ClearBusinessRuntimeState(businessId)
    ReleaseOwnershipLocks(lockKeys)

    TriggerClientEvent(
        "t1ger_moneywash:client:businessAbandoned",
        src,
        businessId
    )

    if Config.Debug then
        print(("[MoneyWash] Business %d abandoned by %s"):format(
            businessId,
            identifier
        ))
    end

    return true, "success"
end

--- ============================================================================
--- LAUNDERING
--- ============================================================================

--- Calculates covered and exposed split for a launder action
--- Step 1: expectedRevenue check (overage always exposed)
--- Step 2: stock check (unsupported within-revenue portion exposed)
--- @param business table
--- @param amount number gross amount being laundered
--- @param tier table
--- @return number coveredAmount, number exposedAmount
local function CalculateCoveredExposed(business, amount, tier)
    local remaining = math.max(0, tier.expectedRevenue - business.totalLaundered)
    local withinRevenue = math.min(amount, remaining)
    local overRevenue = amount - withinRevenue

    -- Stock check on within-revenue portion only
    local stockConsumed = GetStockConsumed(amount)
    local stockValue = business.stock -- units available
    local stockSupported = math.min(withinRevenue, stockValue * (tier.expectedRevenue * Config.Business.Stock.costRatio))

    local covered = math.floor(stockSupported)
    local exposed = math.floor(overRevenue + (withinRevenue - stockSupported))

    return covered, exposed
end

--- Calculates suspicion gain for a launder action
--- Formula: (progressAfter^2 - progressBefore^2) * BaseMultiplier * stockModifier * zoneModifier
--- @param business table
--- @param amount number
--- @param tier table
--- @return number gain
local function CalculateSuspicionGain(business, amount, tier)
    local expectedRevenue    = tier.expectedRevenue

    local progressBefore     = business.totalLaundered / expectedRevenue
    local progressAfter      = (business.totalLaundered + amount) / expectedRevenue

    -- Derive BaseMultiplier from CyclesUntilCritical
    -- At full expectedRevenue with full stock, gain per cycle = 75 / CyclesUntilCritical
    local targetGainPerCycle = 75.0 / Config.Suspicion.CyclesUntilCritical
    local BaseMultiplier     = targetGainPerCycle / (1.0 * (1 - Config.Suspicion.FullStockReduction / 100))

    local turnoverGain       = (progressAfter ^ 2 - progressBefore ^ 2) * BaseMultiplier

    -- Stock modifier
    local stockConsumed      = GetStockConsumed(amount)
    local stockModifier      = 1.0
    if business.stock <= 0 then
        stockModifier = 1.0 + (Config.Suspicion.NoStockPenalty / 100)
    elseif business.stock >= stockConsumed then
        stockModifier = 1.0 - (Config.Suspicion.FullStockReduction / 100)
    else
        -- Partial coverage - scale linearly
        local coverage = business.stock / stockConsumed
        local fullReduction = Config.Suspicion.FullStockReduction / 100
        local noPenalty = Config.Suspicion.NoStockPenalty / 100
        stockModifier = 1.0 - (coverage * fullReduction) + ((1 - coverage) * noPenalty)
    end

    -- Zone modifier - extra penalty if exceeding expectedRevenue
    local zoneModifier = 1.0
    if business.totalLaundered >= expectedRevenue then
        zoneModifier = Config.Suspicion.OverageMultiplier
    end

    local gain = turnoverGain * stockModifier * zoneModifier
    return math.max(0, gain)
end

--- Performs a hidden police notification roll based on current suspicion label
--- Player is never informed of the outcome
--- @param business table
--- @param notificationChances table optional override (for review vs launder)
local function RollPoliceNotification(business, notificationChances)
    local label = GetSuspicionLabel(business.suspicion)
    local chances = notificationChances or Config.Suspicion.NotificationChance
    local chance = chances[label.name] or 0

    if chance <= 0 then return end

    local roll = math.random(1, 100)
    if roll <= chance then
        local location = GetLocationConfig(business.type, business.locationId)
        local coords = location and location.coords or nil
        SendPoliceNotification(business, label.name, coords)
    end
end

--- Executes a launder action
--- Dirty cash must be carried by the player (not from Safe)
--- @param src number
--- @param businessId number
--- @param amount number gross dirty cash amount to launder
--- @return boolean success, string reason, table|nil result
function LaunderMoney(src, businessId, amount)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local business = GetBusiness(businessId)
    if not business then return false, "not_found" end
    if business.identifier ~= identifier then return false, "not_owner" end
    if business.isClosed then return false, "business_closed" end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, "invalid_amount" end

    -- Player must physically carry the dirty cash
    if not HasDirtyMoney(src, amount) then
        return false, "insufficient_dirty_cash"
    end

    local tier = GetTierByType(business.type)
    if not tier then return false, "invalid_tier" end

    -- Calculate stock consumed
    local stockConsumed = GetStockConsumed(amount)

    -- Calculate covered/exposed split
    local coveredAmount, exposedAmount = CalculateCoveredExposed(business, amount, tier)

    -- Calculate fee and clean money
    local fee = math.floor(amount * (tier.launderFee / 100))
    local cleanAmount = amount - fee

    -- Split clean money proportionally between covered and exposed
    local coveredRatio = amount > 0 and (coveredAmount / amount) or 0
    local cleanCovered = math.floor(cleanAmount * coveredRatio)
    local cleanExposed = cleanAmount - cleanCovered

    -- Calculate suspicion gain
    local suspicionGain = CalculateSuspicionGain(business, amount, tier)

    -- Execute: remove dirty cash from player
    RemoveDirtyMoney(src, amount)

    -- Consume stock (can't go below 0)
    local newStock = math.max(0, business.stock - stockConsumed)

    -- Update business state
    UpdateBusinessFields(businessId, {
        stock           = newStock,
        safeCovered     = business.safeCovered + cleanCovered,
        safeExposed     = business.safeExposed + cleanExposed,
        suspicion       = math.min(100, business.suspicion + suspicionGain),
        totalLaundered  = business.totalLaundered + amount,
        lastLaunderedAt = os.time(),
    })

    -- Award reputation
    if Config.Reputation.Enable and Config.Reputation.Rewards.launder.enable then
        AddReputationPoints(src, Config.Reputation.Rewards.launder.points)
    end

    -- Police notification roll
    local updatedBusiness = GetBusiness(businessId)
    RollPoliceNotification(updatedBusiness)

    -- Check if suspicion crossed a label threshold and notify owner
    local oldLabel = GetSuspicionLabel(business.suspicion)
    local newLabel = GetSuspicionLabel(updatedBusiness.suspicion)
    if Config.Suspicion.NotifyOnLabelChange and oldLabel.name ~= newLabel.name then
        TriggerClientEvent("t1ger_moneywash:client:suspicionLabelChanged", src, newLabel)
    end

    -- Check if suspicion has hit 100 - queue raid
    if updatedBusiness.suspicion >= 100 then
        QueueRaid(businessId)
    end

    if Config.Debug then
        print(("[MoneyWash] Launder: business %d | amount $%d | covered $%d | exposed $%d | suspicion +%.1f → %.1f")
            :format(
                businessId, amount, cleanCovered, cleanExposed, suspicionGain, updatedBusiness.suspicion))
    end

    return true, "success", {
        amount        = amount,
        fee           = fee,
        cleanCovered  = cleanCovered,
        cleanExposed  = cleanExposed,
        stockConsumed = stockConsumed,
        suspicionGain = suspicionGain,
        newSuspicion  = updatedBusiness.suspicion,
        newLabel      = newLabel,
    }
end

--- ============================================================================
--- STOCK
--- ============================================================================

--- Active stock missions keyed by player source
--- { src = { businessId, units, cost, pickupLocation, startedAt } }
local ActiveStockMissions = {}

--- Validates and starts a stock order mission
--- Payment taken from personal bank (not Safe)
--- @param src number
--- @param businessId number
--- @param units number
--- @return boolean success, string reason, table|nil missionData
function OrderStock(src, businessId, units)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local business = GetBusiness(businessId)
    if not business then return false, "not_found" end
    if business.identifier ~= identifier then return false, "not_owner" end

    -- One active order per business at a time
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

    local totalCost = units * unitPrice

    if _API.Player.GetMoney(src, "bank") < totalCost then
        return false, "insufficient_funds"
    end

    -- Deduct payment from personal bank
    _API.Player.RemoveMoney(src, totalCost, "bank")

    -- Pick random pickup location for this business type
    local stockLocations = require("shared/stocklocations")
    local pool = stockLocations[business.type]
    if not pool or #pool == 0 then
        _API.Player.AddMoney(src, totalCost, "bank")
        return false, "no_pickup_locations"
    end

    local pickupLocation = pool[math.random(1, #pool)]

    -- Store active mission
    ActiveStockMissions[src] = {
        businessId     = businessId,
        units          = units,
        cost           = totalCost,
        pickupLocation = pickupLocation,
        startedAt      = os.time(),
    }

    if Config.Debug then
        print(("[MoneyWash] Stock order: player %d | business %d | %d units | $%d"):format(
            src, businessId, units, totalCost))
    end

    return true, "success", {
        units          = units,
        cost           = totalCost,
        pickupLocation = pickupLocation,
    }
end

--- Completes a stock delivery mission
--- Called when player successfully delivers stock back to the business
--- @param src number
--- @return boolean success, string reason
function CompleteStockDelivery(src)
    local mission = ActiveStockMissions[src]
    if not mission then return false, "no_active_mission" end

    local business = GetBusiness(mission.businessId)
    if not business then
        ActiveStockMissions[src] = nil
        return false, "business_not_found"
    end

    -- Validate player is near the business Handler NPC
    local location = GetLocationConfig(business.type, business.locationId)
    if not location or not IsPlayerNearCoords(src, location.coords, 5.0) then
        return false, "target_too_far"
    end

    -- Add stock to business
    UpdateBusiness(mission.businessId, "stock", business.stock + mission.units)

    -- Generate receipt in DB
    MySQL.insert(
        "INSERT INTO moneywash_receipts (business_id, units, unit_price, total_amount, created_at) VALUES (?, ?, ?, ?, ?)",
        { mission.businessId, mission.units, GetUnitPrice(business.type), mission.cost, os.time() }
    )

    -- Award reputation
    if Config.Reputation.Enable and Config.Reputation.Rewards.stockDelivery.enable then
        AddReputationPoints(src, Config.Reputation.Rewards.stockDelivery.points)
    end

    ActiveStockMissions[src] = nil

    if Config.Debug then
        print(("[MoneyWash] Stock delivered: business %d | +%d units | new total: %d"):format(
            mission.businessId, mission.units, business.stock + mission.units))
    end

    return true, "success"
end

--- Cancels an active stock mission and refunds the player
--- @param src number
--- @return boolean success
function CancelStockMission(src)
    local mission = ActiveStockMissions[src]
    if not mission then return false end

    -- Full refund to personal bank
    _API.Player.AddMoney(src, mission.cost, "bank")
    ActiveStockMissions[src] = nil

    if Config.Debug then
        print(("[MoneyWash] Stock mission cancelled: player %d | refunded $%d"):format(src, mission.cost))
    end

    return true
end

--- Returns a player's active stock mission if one exists
--- @param src number
--- @return table|nil
function GetActiveStockMission(src)
    return ActiveStockMissions[src]
end

--- Cleans up stock mission on player disconnect
--- @param src number
function OnPlayerDroppedStockCleanup(src)
    local mission = ActiveStockMissions[src]
    if mission then
        _API.Player.AddMoney(src, mission.cost, "bank")
        ActiveStockMissions[src] = nil
    end
end

--- ============================================================================
--- BANK DEPOSITS
--- ============================================================================

--- Active deposit missions keyed by player identifier (persists through reconnect)
--- Stored in DB (moneywash_deposits) - loaded on playerLoaded
local ActiveDeposits = {} -- keyed by identifier

--- Loads any pending deposit for a player from the DB on login
--- @param src number
function LoadPendingDeposit(src)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return end

    local row = MySQL.single.await(
        "SELECT * FROM moneywash_deposits WHERE identifier = ?", { identifier })

    if row then
        ActiveDeposits[identifier] = row
        TriggerClientEvent("t1ger_moneywash:client:pendingDepositSync", src, {
            totalAmount   = row.total_amount,
            coveredAmount = row.covered_amount,
            exposedAmount = row.exposed_amount,
            clearsAt      = row.clears_at,
            flagged       = row.flagged == 1,
        })
    end
end

--- Initiates a bank deposit mission
--- Draws exposed funds first then covered to make up the remainder
--- @param src number
--- @param businessId number
--- @param amount number
--- @return boolean success, string reason, table|nil depositData
function InitiateBankDeposit(src, businessId, amount)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    -- One pending deposit per player at a time
    if ActiveDeposits[identifier] then return false, "deposit_already_pending" end

    local business = GetBusiness(businessId)
    if not business then return false, "not_found" end
    if business.identifier ~= identifier then return false, "not_owner" end
    if business.isClosed then return false, "business_closed" end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, "invalid_amount" end

    local totalSafe = business.safeCovered + business.safeExposed
    if amount > totalSafe then return false, "insufficient_safe_balance" end

    -- Draw exposed first then covered
    local exposedTaken = math.min(amount, business.safeExposed)
    local coveredTaken = amount - exposedTaken

    -- Deduct from Safe immediately
    UpdateBusinessFields(businessId, {
        safeExposed = business.safeExposed - exposedTaken,
        safeCovered = business.safeCovered - coveredTaken,
    })

    -- Pick random bank location
    local bankLocations = require("shared/banklocations")
    local bankLocation = bankLocations[math.random(1, #bankLocations)]

    -- Determine flag outcome based on current suspicion at this moment
    local label = GetSuspicionLabel(business.suspicion)
    local flagChance = Config.BankDeposit.FlagChance[label.name] or 0
    local flagged = math.random(1, 100) <= flagChance

    local now = os.time()
    local clearsAt = now + (Config.BankDeposit.ProcessingTime * 60)

    -- Store in DB (persists through disconnect)
    local depositId = MySQL.insert.await(
        "INSERT INTO moneywash_deposits " ..
        "(identifier, business_id, total_amount, covered_amount, exposed_amount, flagged, initiated_at, clears_at) " ..
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        { identifier, businessId, amount, coveredTaken, exposedTaken, flagged and 1 or 0, now, clearsAt }
    )

    if not depositId then
        -- Restore Safe on DB failure
        UpdateBusinessFields(businessId, {
            safeExposed = business.safeExposed,
            safeCovered = business.safeCovered,
        })
        return false, "database_error"
    end

    ActiveDeposits[identifier] = {
        id             = depositId,
        identifier     = identifier,
        business_id    = businessId,
        total_amount   = amount,
        covered_amount = coveredTaken,
        exposed_amount = exposedTaken,
        flagged        = flagged,
        initiated_at   = now,
        clears_at      = clearsAt,
    }

    -- Notify police if flagged
    if flagged then
        local location = GetLocationConfig(business.type, business.locationId)
        SendDepositFlagNotification(identifier, amount, bankLocation)
    end

    if Config.Debug then
        print(("[MoneyWash] Deposit initiated: %s | $%d | covered $%d | exposed $%d | flagged: %s"):format(
            identifier, amount, coveredTaken, exposedTaken, tostring(flagged)))
    end

    return true, "success", {
        amount       = amount,
        bankLocation = bankLocation,
        clearsAt     = clearsAt,
        flagged      = flagged, -- NOT sent to client - hidden from player
    }
end

--- Completes a bank deposit - wires money to player's personal bank
--- Called by the processing tick in server/main.lua
--- @param identifier string
function CompleteBankDeposit(identifier)
    local deposit = ActiveDeposits[identifier]
    if not deposit then return end

    -- Find player source if online
    local src = nil
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == identifier then
            src = player.source
            break
        end
    end

    -- Wire to personal bank
    if src then
        _API.Player.AddMoney(src, deposit.total_amount, "bank")

        -- Award reputation
        if Config.Reputation.Enable and Config.Reputation.Rewards.bankDeposit.enable then
            AddReputationPoints(src, Config.Reputation.Rewards.bankDeposit.points)
        end

        TriggerClientEvent("t1ger_moneywash:client:depositCleared", src, deposit.total_amount)
    else
        -- Player offline - add directly via identifier
        _API.Player.AddMoneyByIdentifier(identifier, deposit.total_amount, "bank")
    end

    -- Clean up
    MySQL.query("DELETE FROM moneywash_deposits WHERE id = ?", { deposit.id })
    ActiveDeposits[identifier] = nil

    if Config.Debug then
        print(("[MoneyWash] Deposit cleared: %s | $%d wired to bank"):format(identifier, deposit.total_amount))
    end
end

--- Police confiscate a flagged pending deposit
--- Entire deposit is seized regardless of covered/exposed split
--- @param src number police player source
--- @param targetIdentifier string
--- @return boolean success, string reason
function ConfiscateDeposit(src, targetIdentifier)
    local deposit = ActiveDeposits[targetIdentifier]
    if not deposit then return false, "no_pending_deposit" end
    if not deposit.flagged then return false, "not_flagged" end

    local amount = deposit.total_amount

    -- Give to police job account or vanish
    if Config.BankDeposit.PoliceKeepMoney then
        _API.JobAccount.Deposit("police", amount)
    end

    -- Notify target if online
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == targetIdentifier then
            TriggerClientEvent("t1ger_moneywash:client:depositConfiscated", player.source, amount)
            break
        end
    end

    -- Clean up
    MySQL.query("DELETE FROM moneywash_deposits WHERE id = ?", { deposit.id })
    ActiveDeposits[targetIdentifier] = nil

    if Config.Debug then
        print(("[MoneyWash] Deposit confiscated by police: %s | $%d"):format(targetIdentifier, amount))
    end

    return true, "success"
end

--- Returns all flagged pending deposits at a specific bank location
--- Used by police teller review target
--- @param bankCoords vector4
--- @return table
function GetFlaggedDepositsAtBank(bankCoords)
    local result = {}
    for identifier, deposit in pairs(ActiveDeposits) do
        if deposit.flagged then
            result[#result + 1] = {
                identifier  = identifier,
                totalAmount = deposit.total_amount,
                clearsAt    = deposit.clears_at,
            }
        end
    end
    return result
end

--- Returns a player's active deposit if one exists
--- @param identifier string
--- @return table|nil
function GetActiveDeposit(identifier)
    return ActiveDeposits[identifier]
end

--- ============================================================================
--- SUSPICION / RAIDS
--- ============================================================================

--- Active raid queues keyed by businessId
--- { businessId = raidsAt (timestamp) }
local QueuedRaids = {}
local RAID_LOCATION_COORDINATE_TOLERANCE = 0.25

--- Queues a raid for a business after the configured delay
--- @param businessId number
function QueueRaid(businessId)
    if QueuedRaids[businessId] then return end -- already queued

    local raidsAt = os.time() + (Config.Suspicion.RaidDelay * 60)
    QueuedRaids[businessId] = raidsAt

    -- Notify police via customize.lua
    local business = GetBusiness(businessId)
    if business then
        local location = GetLocationConfig(business.type, business.locationId)
        local coords = location and location.coords or nil
        SendRaidAlert(business, coords)
    end

    if Config.Debug then
        print(("[MoneyWash] Raid queued: business %d | fires at %d"):format(businessId, raidsAt))
    end
end

--- Executes a raid on a business
--- Confiscates exposed Safe funds only, resets suspicion, increments raid history
--- Called by police target interaction OR by the raid queue tick
--- @param businessId number
--- @param policeSrc number|nil nil if triggered by queue tick
function ExecuteRaid(businessId, policeSrc)
    local business = GetBusiness(businessId)
    if not business then return end

    local location = GetLocationConfig(
        business.type,
        business.locationId
    )

    if not location or not location.coords then
        return
    end

    local seizedAmount = business.safeExposed

    -- Seize exposed funds
    UpdateBusinessFields(businessId, {
        safeExposed     = 0,
        suspicion       = Config.Suspicion.PostRaidReset,
        lastLaunderedAt = os.time(), -- raid counts as activity, decay starts fresh
    })

    -- Give to police job account or vanish
    if seizedAmount > 0 then
        if Config.BankDeposit.PoliceKeepMoney and policeSrc then
            _API.JobAccount.Deposit("police", seizedAmount)
        end
    end

    -- Log raid history
    MySQL.insert(
        "INSERT INTO moneywash_raid_history " ..
        "(business_type, location_id, location_x, location_y, location_z, raided_at) " ..
        "VALUES (?, ?, ?, ?, ?, ?)",
        {
            business.type,
            business.locationId,
            location.coords.x + 0.0,
            location.coords.y + 0.0,
            location.coords.z + 0.0,
            os.time(),
        }
    )

    -- Check escalation
    CheckRaidEscalation(businessId)

    -- Clear from queue
    QueuedRaids[businessId] = nil

    -- Notify owner if online
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == business.identifier then
            TriggerClientEvent("t1ger_moneywash:client:businessRaided", player.source, businessId, seizedAmount)
            break
        end
    end

    if Config.Debug then
        print(("[MoneyWash] Raid executed: business %d | seized $%d | suspicion reset to %d"):format(
            businessId, seizedAmount, Config.Suspicion.PostRaidReset))
    end
end

--- Checks raid history and applies escalation if thresholds are met
--- @param businessId number
function CheckRaidEscalation(businessId)
    local business = GetBusiness(businessId)
    if not business then return end

    local location = GetLocationConfig(
        business.type,
        business.locationId
    )

    if not location or not location.coords then
        return
    end

    local windowSeconds = Config.Suspicion.RaidHistory.WindowDays * 86400
    local since = os.time() - windowSeconds

    local raidCount = MySQL.scalar.await(
        "SELECT COUNT(*) FROM moneywash_raid_history " ..
        "WHERE business_type = ? AND location_id = ? " ..
        "AND ABS(location_x - ?) <= ? " ..
        "AND ABS(location_y - ?) <= ? " ..
        "AND ABS(location_z - ?) <= ? " ..
        "AND raided_at > ?",
        {
            business.type,
            business.locationId,
            location.coords.x + 0.0,
            RAID_LOCATION_COORDINATE_TOLERANCE,
            location.coords.y + 0.0,
            RAID_LOCATION_COORDINATE_TOLERANCE,
            location.coords.z + 0.0,
            RAID_LOCATION_COORDINATE_TOLERANCE,
            since,
        }
    )

    raidCount = raidCount or 0

    if raidCount >= Config.Suspicion.RaidHistory.SeizeAfterRaids then
        -- Permanent seizure
        AdminRemoveBusiness(business.type, business.locationId)
        if Config.Debug then
            print(("[MoneyWash] Business %d permanently seized after %d raids"):format(businessId, raidCount))
        end
    elseif raidCount >= Config.Suspicion.RaidHistory.TempCloseAfterRaids then
        -- Temporary closure
        local closedUntil = os.time() + (Config.Suspicion.RaidHistory.TempCloseDuration * 3600)
        UpdateBusinessFields(businessId, {
            isClosed    = true,
            closedUntil = closedUntil,
        })
        MySQL.update(
            "UPDATE moneywash_businesses SET is_closed = 1, closed_until = ? WHERE id = ?",
            { closedUntil, businessId }
        )
        if Config.Debug then
            print(("[MoneyWash] Business %d temporarily closed until %d"):format(businessId, closedUntil))
        end
    end
end

--- Returns all queued raids (used by the tick in server/main.lua)
--- @return table
function GetQueuedRaids()
    return QueuedRaids
end

--- ============================================================================
--- ACCOUNTANT REVIEW
--- ============================================================================

--- Active review cooldowns keyed by businessId
--- { businessId = nextAvailableAt (cycle number) }
local ReviewCooldowns = {}

--- Removes temporary server state belonging to a deleted business.
--- @param businessId number
function ClearBusinessRuntimeState(businessId)
    QueuedRaids[businessId] = nil
    ReviewCooldowns[businessId] = nil
end

--- Returns whether a business is on review cooldown
--- @param businessId number
--- @param currentCycle number
--- @return boolean
local function IsOnReviewCooldown(businessId, currentCycle)
    local cooldownUntil = ReviewCooldowns[businessId]
    return cooldownUntil and currentCycle < cooldownUntil
end

--- Fetches available receipts for a business for the review selection UI
--- @param businessId number
--- @return table
function GetBusinessReceipts(businessId)
    local rows = MySQL.query.await(
        "SELECT id, units, unit_price, total_amount, created_at FROM moneywash_receipts WHERE business_id = ? ORDER BY created_at DESC",
        { businessId }
    )
    return rows or {}
end

--- Calculates estimated effectiveness of a review given selected receipt ids
--- Returns a label: Weak / Fair / Strong / Excellent
--- @param businessId number
--- @param selectedReceiptIds table
--- @return string effectivenessLabel, number estimatedReduction
function EstimateReviewEffectiveness(businessId, selectedReceiptIds)
    local business = GetBusiness(businessId)
    if not business then return "Weak", 0 end

    local tier = GetTierByType(business.type)
    if not tier then return "Weak", 0 end

    if not selectedReceiptIds or #selectedReceiptIds == 0 then return "Weak", 0 end

    -- Fetch selected receipts
    local placeholders = table.concat({ "?" }, ", "):rep(#selectedReceiptIds):sub(1, -3)
    -- build proper placeholders
    local ph = {}
    for i = 1, #selectedReceiptIds do ph[i] = "?" end
    local rows = MySQL.query.await(
        "SELECT total_amount FROM moneywash_receipts WHERE id IN (" .. table.concat(ph, ",") .. ") AND business_id = ?",
        vim_concat(selectedReceiptIds, { businessId })
    )

    local totalReceiptValue = 0
    local receiptCount = rows and #rows or 0
    for _, row in ipairs(rows or {}) do
        totalReceiptValue = totalReceiptValue + row.total_amount
    end

    -- Expected receipt count: how many orders a well-run business would have per cycle
    local unitPrice = GetUnitPrice(business.type)
    local expectedSpend = tier.expectedRevenue * Config.Business.Stock.costRatio
    local expectedOrders = math.max(1, math.ceil(expectedSpend / (unitPrice * GetMinOrder(business.type))))

    -- Receipt score: combination of value and count
    local valueScore = math.min(1.0, totalReceiptValue / expectedSpend)
    local countScore = math.min(1.0, receiptCount / expectedOrders)
    local receiptScore = (valueScore + countScore) / 2

    -- Situation modifier: how far past expectedRevenue is the business
    local situationModifier = math.max(0, 1 - (business.totalLaundered / tier.expectedRevenue))

    -- Final reduction
    local maxR = Config.Suspicion.AccountantReview.MaxReduction
    local minR = Config.Suspicion.AccountantReview.MinReduction
    local reduction = math.floor(minR + (maxR - minR) * receiptScore * situationModifier)
    reduction = math.max(minR, math.min(maxR, reduction))

    local label
    if receiptScore >= 0.75 then
        label = "Excellent"
    elseif receiptScore >= 0.50 then
        label = "Strong"
    elseif receiptScore >= 0.25 then
        label = "Fair"
    else
        label = "Weak"
    end

    return label, reduction
end

--- Executes an accountant records review
--- Deletes selected receipts, reduces suspicion, awards reputation
--- @param src number
--- @param businessId number
--- @param selectedReceiptIds table
--- @param currentCycle number the current global cycle number
--- @return boolean success, string reason, table|nil result
function ExecuteAccountantReview(src, businessId, selectedReceiptIds, currentCycle)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local business = GetBusiness(businessId)
    if not business then return false, "not_found" end
    if business.identifier ~= identifier then return false, "not_owner" end

    if IsOnReviewCooldown(businessId, currentCycle) then
        return false, "on_cooldown"
    end

    if not selectedReceiptIds or #selectedReceiptIds == 0 then
        return false, "no_receipts_selected"
    end

    -- Calculate reduction
    local effectivenessLabel, reduction = EstimateReviewEffectiveness(businessId, selectedReceiptIds)

    -- Deduct accountant fee (calculated as a small % of expected revenue)
    local tier = GetTierByType(business.type)
    local fee = math.floor(tier.expectedRevenue * 0.05) -- 5% of expectedRevenue as fee
    if _API.Player.GetMoney(src, "bank") < fee then
        return false, "insufficient_funds"
    end
    _API.Player.RemoveMoney(src, fee, "bank")

    -- Delete selected receipts
    for _, receiptId in ipairs(selectedReceiptIds) do
        MySQL.query("DELETE FROM moneywash_receipts WHERE id = ? AND business_id = ?",
            { receiptId, businessId })
    end

    -- Apply suspicion reduction
    local newSuspicion = math.max(0, business.suspicion - reduction)
    UpdateBusiness(businessId, "suspicion", newSuspicion)

    -- Set cooldown
    ReviewCooldowns[businessId] = currentCycle + Config.Suspicion.AccountantReview.Cooldown

    -- Police notification roll (lower chance than launder)
    RollPoliceNotification(GetBusiness(businessId), Config.Suspicion.AccountantReview.NotificationChance)

    -- Award reputation
    if Config.Reputation.Enable and Config.Reputation.Rewards.accountantReview.enable then
        AddReputationPoints(src, Config.Reputation.Rewards.accountantReview.points)
    end

    if Config.Debug then
        print(("[MoneyWash] Review: business %d | effectiveness: %s | reduction: %d | new suspicion: %.1f"):format(
            businessId, effectivenessLabel, reduction, newSuspicion))
    end

    return true, "success", {
        effectiveness = effectivenessLabel,
        reduction     = reduction,
        fee           = fee,
        newSuspicion  = newSuspicion,
    }
end

--- ============================================================================
--- ADMIN
--- ============================================================================

--- Admin: forcibly adds a business while preserving ownership invariants.
--- Reputation andprice requirements are bypassed.
--- @param identifier string
--- @param businessType string
--- @param locationId number
--- @return boolean success, string reason
function AdminAddBusiness(identifier, businessType, locationId)
    if not IsBusinessStoreReady() then
        return false, "business_store_not_ready"
    end

    if type(identifier) ~= "string" or identifier == "" then
        return false, "invalid_player"
    end

    if type(businessType) ~= "string" then
        return false, "invalid_type"
    end

    locationId = tonumber(locationId)
    if not locationId then
        return false, "invalid_location"
    end

    local tier = GetTierByType(businessType)
    if not tier then
        return false, "invalid_type"
    end

    local location = GetLocationConfig(businessType, locationId)
    if not location or not location.coords then
        return false, "invalid_location"
    end

    local lockKeys = {
        ("owner:%s"):format(identifier),
        ("location:%s:%d"):format(businessType, locationId),
    }

    if not TryAcquireOwnershipLocks(lockKeys) then
        return false, "operation_in_progress"
    end

    if IsLocationOwned(businessType, locationId) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "already_owned"
    end

    if PlayerOwnsBusiness(identifier) then
        ReleaseOwnershipLocks(lockKeys)
        return false, "already_owns_business"
    end

    local now = os.time()

    local insertSucceeded, id = pcall(
        MySQL.insert.await,
        "INSERT INTO moneywash_businesses " ..
        "(identifier, business_type, location_id, location_x, location_y, location_z, " ..
        "stock, safe_covered, safe_exposed, suspicion, total_laundered, " ..
        "last_laundered_at, is_closed, purchased_at) " ..
        "VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0, 0, ?)",
        {
            identifier,
            businessType,
            locationId,
            location.coords.x + 0.0,
            location.coords.y + 0.0,
            location.coords.z + 0.0,
            now,
        }
    )

    if not insertSucceeded or not id then
        ReleaseOwnershipLocks(lockKeys)

        if Config.Debug then
            print(("[MoneyWash] Admin add database error: %s"):format(
                tostring(id)
            ))
        end

        return false, "database_error"
    end

    AddToStore(id, {
        identifier        = identifier,
        business_type     = businessType,
        location_id       = locationId,
        stock             = 0,
        safe_covered      = 0,
        safe_exposed      = 0,
        suspicion         = 0,
        total_laundered   = 0,
        last_laundered_at = 0,
        is_closed         = false,
        closed_until      = nil,
        purchased_at      = now,
    })

    ReleaseOwnershipLocks(lockKeys)

    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == identifier then
            TriggerClientEvent(
                "t1ger_moneywash:client:businessPurchased",
                player.source,
                id,
                businessType,
                locationId
            )

            break
        end
    end

    if Config.Debug then
        print(("[MoneyWash] Admin added %s #%d to %s"):format(
            businessType,
            locationId,
            identifier
        ))
    end

    return true, "success"
end

exports("AddBusiness", AdminAddBusiness)

--- Admin: forcibly removes a business and returns its location to the market.
--- @param businessType string
--- @param locationId number
--- @return boolean success, string reason
function AdminRemoveBusiness(businessType, locationId)
    if type(businessType) ~= "string" then
        return false, "invalid_type"
    end

    locationId = tonumber(locationId)
    if not locationId then
        return false, "invalid_location"
    end

    local business = GetBusinessByLocation(businessType, locationId)
    if not business then
        return false, "not_owned"
    end

    local businessId = business.id
    local identifier = business.identifier

    local lockKeys = {
        ("business:%d"):format(businessId),
        ("owner:%s"):format(identifier),
        ("location:%s:%d"):format(businessType, locationId),
    }

    if not TryAcquireOwnershipLocks(lockKeys) then
        return false, "operation_in_progress"
    end

    -- Revalidate after acquiring the locks.
    business = GetBusinessByLocation(businessType, locationId)

    if not business or business.id ~= businessId then
        ReleaseOwnershipLocks(lockKeys)
        return false, "not_owned"
    end

    local transactionExecuted, transactionSucceeded = pcall(
        MySQL.transaction.await,
        {
            {
                query = "DELETE FROM moneywash_receipts WHERE business_id = ?",
                values = { businessId },
            },
            {
                query = "DELETE FROM moneywash_businesses WHERE id = ?",
                values = { businessId },
            },
        }
    )

    if not transactionExecuted or not transactionSucceeded then
        ReleaseOwnershipLocks(lockKeys)

        if Config.Debug then
            print(("[MoneyWash] Admin remove database error: %s"):format(
                tostring(transactionSucceeded)
            ))
        end

        return false, "database_error"
    end

    -- Refund an active stock order belonging to this business.
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == identifier then
            local mission = GetActiveStockMission(player.source)

            if mission and mission.businessId == businessId then
                CancelStockMission(player.source)
            end

            break
        end
    end

    RemoveFromStore(businessId)
    ClearBusinessRuntimeState(businessId)
    ReleaseOwnershipLocks(lockKeys)

    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == identifier then
            TriggerClientEvent(
                "t1ger_moneywash:client:businessSeized",
                player.source,
                businessId
            )

            break
        end
    end

    if Config.Debug then
        print(("[MoneyWash] Admin removed %s #%d"):format(
            businessType,
            locationId
        ))
    end

    return true, "success"
end

exports("RemoveBusiness", AdminRemoveBusiness)
