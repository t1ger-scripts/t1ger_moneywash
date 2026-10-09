--- ============================================================================
--- Business Laundering
--- Covered/exposed split and settlement of a cash-counter batch.
--- ============================================================================

--- Calculates covered and exposed split for a launder action
--- Step 1: expectedRevenue check (overage always exposed)
--- Step 2: stock check (unsupported within-revenue portion exposed)
--- @param business table
--- @param amount number gross amount being laundered
--- @param tier table
--- @return number coveredAmount, number exposedAmount
local function CalculateCoveredExposed(business, amount, tier)
    local remaining = math.max(0, tier.expectedRevenue - business.cycleLaundered)
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
        cycleLaundered = business.cycleLaundered + amount,
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
    
    if src then
        TriggerClientEvent("t1ger_moneywash:client:moneyLaundered", src, amount, result.covered, result.exposed)
    end

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

    if src and Config.Suspicion.NotifyOnLabelChange and result.newLabel.threshold > result.oldLabel.threshold then
        TriggerClientEvent("t1ger_moneywash:client:suspicionLabelChanged", src, result.newLabel)
    end
end