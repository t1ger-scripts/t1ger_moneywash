--- ============================================================================
--- Business Suspicion
--- Suspicion gain, hidden police notification roll, and constant decay.
--- ============================================================================

--- Constant decay, run per business every real minute. It does not depend on
--- recent laundering. The gain formula vs. the decay rate defines the
--- "safe laundering rate" per cycle.
--- @param business table
function ApplySuspicionDecay(business)
    if business.suspicion <= 0 then return end

    local isOnline = false
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == business.identifier then
            isOnline = true
            break
        end
    end

    local decayPerCycle = isOnline and Config.Suspicion.Decay.OnlinePointsPerCycle or
    Config.Suspicion.Decay.OfflinePointsPerCycle

    -- Convert per-cycle to per-tick (tick = 1 real minute, cycle = CycleDuration minutes)
    local decayPerTick = decayPerCycle / Config.Business.CycleDuration

    UpdateBusiness(business.id, "suspicion", math.max(0, business.suspicion - decayPerTick))
end

--- Calculates suspicion gain for a launder action
--- Formula: (progressAfter^2 - progressBefore^2) * BaseMultiplier * stockModifier
--- @param business table
--- @param amount number
--- @param tier table
--- @return number gain
function CalculateSuspicionGain(business, amount, tier)
    local expectedRevenue    = tier.expectedRevenue

    local progressBefore     = business.cycleLaundered / expectedRevenue
    local progressAfter      = (business.cycleLaundered + amount) / expectedRevenue

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
function RollPoliceNotification(business, notificationChances)
    local label = GetSuspicionLabel(business.suspicion)
    local chances = notificationChances or Config.Suspicion.NotificationChance
    local chance = (business.suspicion >= 100 and chances.Max) or chances[label.name] or 0

    if chance <= 0 then return end

    local roll = math.random(1, 100)
    if roll <= chance then
        local location = GetLocationConfig(business.type, business.locationId)
        local coords = location and location.coords or nil
        SendPoliceNotification(business, business.suspicion >= 100 and "Max" or label.name, coords)
    end
end