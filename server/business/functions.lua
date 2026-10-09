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

-- Shared with the counter to exclude transfers/removal while a batch is reserved.
function AcquireCashCounterOwnershipLocks(keys) return TryAcquireOwnershipLocks(keys) end
function ReleaseCashCounterOwnershipLocks(keys) ReleaseOwnershipLocks(keys) end

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
        "stock, safe_covered, safe_exposed, suspicion, total_laundered, purchased_at) " ..
        "VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, ?)",
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

    OnBusinessPurchased(identifier, businessType, locationId, price)

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

    TriggerClientEvent("t1ger_moneywash:client:businessReceived", targetSrc, businessId, business.type, business.locationId)

    OnBusinessTransferred(identifier, targetIdentifier, businessId, business.type, business.locationId)

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

    TriggerClientEvent("t1ger_moneywash:client:businessAbandoned", src, businessId)

    OnBusinessAbandoned(identifier, businessId, business.type, business.locationId)

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
    local stockSupported = math.min(withinRevenue, stockValue * Config.Business.Stock.LaunderDollarsPerUnit)

    local covered = math.floor(stockSupported)
    local exposed = math.floor(overRevenue + (withinRevenue - stockSupported))

    return covered, exposed
end

--- Calculates suspicion gain for a launder action
--- Formula: (progressAfter^2 - progressBefore^2) * BaseMultiplier * stockModifier
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

    local gain = turnoverGain * stockModifier
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

--- Pure calculation shared by the server-controlled cash-counter settlement.
function BuildCashInjection(business, amount)
    local tier = GetTierByType(business.type)
    if not tier then return nil end
    local covered, exposed = CalculateCoveredExposed(business, amount, tier)
    local gain = CalculateSuspicionGain(business, amount, tier)
    local suspicion = math.min(100, business.suspicion + gain)
    return {
        stock = math.max(0, business.stock - GetStockConsumed(amount)),
        safeCovered = business.safeCovered + covered,
        safeExposed = business.safeExposed + exposed,
        suspicion = suspicion,
        totalLaundered = business.totalLaundered + amount,
    }, {
        oldLabel = GetSuspicionLabel(business.suspicion),
        newLabel = GetSuspicionLabel(suspicion),
        covered  = covered,
        exposed  = exposed,
    }
end

--- Side effects run only after durable settlement, never on a client completion event.
function PublishCashInjection(src, identifier, businessId, amount, result)
    local business = GetBusiness(businessId)
    if not business then return end

    OnMoneyLaundered(identifier, businessId, business.type, amount, result.covered, result.exposed)
    
    if Config.Reputation.Enable and Config.Reputation.Rewards.launder.enable then
        local points = Config.Reputation.Rewards.launder.points
        if src and IsReputationReady(src) then
            AddReputationPoints(src, points)
            SavePlayerReputation(src)
        else
            MySQL.update("UPDATE moneywash_reputation SET points = points + ? WHERE identifier = ?", { points, identifier })
        end
    end

    RollPoliceNotification(business)

    if src and Config.Suspicion.NotifyOnLabelChange and result.oldLabel.name ~= result.newLabel.name then
        TriggerClientEvent("t1ger_moneywash:client:suspicionLabelChanged", src, result.newLabel)
    end

    if business.suspicion >= 100 then QueueRaid(businessId) end
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
        "stock, safe_covered, safe_exposed, suspicion, total_laundered, purchased_at) " ..
        "VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0, ?)",
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
