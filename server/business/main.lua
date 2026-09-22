--- ============================================================================
--- Business Main
--- All client-facing callbacks and server events for the business system.
--- All logic calls into server/business/functions.lua.
--- ============================================================================

--- -------------------------------------------------------------------------
--- BUSINESS PURCHASE / OWNERSHIP
--- -------------------------------------------------------------------------

--- Returns available, unowned locations for an unlocked business tier.
--- Locked-tier coordinates are never returned by this callback.
lib.callback.register("t1ger_moneywash:server:getAvailableLocations", function(source, businessType)
    if not IsBusinessStoreReady() then
        return {}
    end
    
    local identifier = _API.Player.GetIdentifier(source)
    if not identifier then return {} end

    if type(businessType) ~= "string" then return {} end

    local tier = GetTierByType(businessType)
    if not tier then return {} end

    if Config.Reputation.Enable then
        local reputation = GetPlayerReputation(source)

        if not reputation or reputation:GetPoints() < tier.requiredPoints then
            return {}
        end
    end

    local locations = require("shared/business_locations")
    local businessLocations = locations[businessType]

    if not businessLocations then return {} end

    local availableLocations = {}

    for locationId, locationData in pairs(businessLocations) do
        if not IsLocationOwned(businessType, locationId) then
            availableLocations[#availableLocations + 1] = {
                id = locationId,
                coords = locationData.coords,
                brand = locationData.brand,
                price = locationData.price or tier.price,
            }
        end
    end

    table.sort(availableLocations, function(firstLocation, secondLocation)
        return firstLocation.id < secondLocation.id
    end)

    return availableLocations
end
)

--- Returns all business tiers and their availability for the requesting player.
lib.callback.register("t1ger_moneywash:server:getUnlockedTiers", function(source)
    local identifier = _API.Player.GetIdentifier(source)
    if not identifier then return {} end

    local reputationPoints = 0

    if Config.Reputation.Enable then
        local reputation = GetPlayerReputation(source)

        if reputation then
            reputationPoints = reputation:GetPoints()
        end
    end

    local playerOwnsBusiness = PlayerOwnsBusiness(identifier)
    local tiers = {}

    for tierId, tier in ipairs(Config.Business.Tiers) do
        local isUnlocked =
            not Config.Reputation.Enable
            or reputationPoints >= tier.requiredPoints

        tiers[#tiers + 1] = {
            id             = tierId,
            type           = tier.type,
            label          = tier.label,
            requiredPoints = tier.requiredPoints,
            price          = tier.price,
            unlocked       = isUnlocked,
            alreadyOwns    = playerOwnsBusiness,
        }
    end

    return tiers
end
)

--- Purchase a business
lib.callback.register("t1ger_moneywash:server:buyBusiness", function(source, businessType, locationId)
    local success, reason = BuyBusiness(source, businessType, locationId)
    return { success = success, reason = reason }
end)

--- Transfer a business to another player
lib.callback.register("t1ger_moneywash:server:transferBusiness", function(source, targetId, businessId)
    local success, reason = TransferBusiness(source, targetId, businessId)

    return {
        success = success,
        reason = reason,
    }
end)

--- Abandon a business
lib.callback.register("t1ger_moneywash:server:abandonBusiness", function(source, businessId)
    local success, reason = AbandonBusiness(source, businessId)
    return { success = success, reason = reason }
end)

--- Get player's owned businesses (for client sync on load)
lib.callback.register("t1ger_moneywash:server:getPlayerBusinesses", function(source)
    local identifier = _API.Player.GetIdentifier(source)
    return GetPlayerBusinesses(identifier)
end)

--- Get live business status for Handler NPC menu header
lib.callback.register("t1ger_moneywash:server:getBusinessStatus", function(source, businessId)
    local identifier = _API.Player.GetIdentifier(source)
    local business = GetBusiness(businessId)

    if not business or business.identifier ~= identifier then return nil end

    local tier = GetTierByType(business.type)
    local label = GetSuspicionLabel(business.suspicion)

    return {
        type            = business.type,
        locationId      = business.locationId,
        stock           = business.stock,
        safeCovered     = business.safeCovered,
        safeExposed     = business.safeExposed,
        suspicion       = Config.Suspicion.ShowExactValue and business.suspicion or nil,
        suspicionLabel  = label.name,
        suspicionColor  = label.color,
        totalLaundered  = business.totalLaundered,
        expectedRevenue = tier and tier.expectedRevenue or 0,
        isClosed        = business.isClosed,
        closedUntil     = business.closedUntil,
        unitPrice       = GetUnitPrice(business.type),
        minOrder        = GetMinOrder(business.type),
        maxOrder        = GetMaxOrder(business.type),
    }
end)

--- -------------------------------------------------------------------------
--- LAUNDERING
--- -------------------------------------------------------------------------

lib.callback.register("t1ger_moneywash:server:launderMoney", function(source, businessId, amount)
    local success, reason, result = LaunderMoney(source, businessId, amount)
    return { success = success, reason = reason, result = result }
end)

--- -------------------------------------------------------------------------
--- STOCK
--- -------------------------------------------------------------------------

lib.callback.register("t1ger_moneywash:server:orderStock", function(source, businessId, units)
    local success, reason, missionData = OrderStock(source, businessId, units)
    return { success = success, reason = reason, missionData = missionData }
end)

lib.callback.register("t1ger_moneywash:server:completeStockDelivery", function(source)
    local success, reason = CompleteStockDelivery(source)
    return { success = success, reason = reason }
end)

--- Player cancels stock mission (voluntary)
RegisterServerEvent("t1ger_moneywash:server:cancelStockMission")
AddEventHandler("t1ger_moneywash:server:cancelStockMission", function()
    CancelStockMission(source)
end)

--- -------------------------------------------------------------------------
--- BANK DEPOSITS
--- -------------------------------------------------------------------------

lib.callback.register("t1ger_moneywash:server:initiateBankDeposit", function(source, businessId, amount)
    local success, reason, depositData = InitiateBankDeposit(source, businessId, amount)
    -- Never send flagged status to client
    if depositData then depositData.flagged = nil end
    return { success = success, reason = reason, depositData = depositData }
end)

--- Police: get flagged deposits at a specific bank teller
lib.callback.register("t1ger_moneywash:server:getFlaggedDeposits", function(source, bankCoords)
    -- Validate police job and grade
    local job = _API.Player.GetJob(source)
    if not job then return {} end

    local isPolice = false
    for _, policeJob in ipairs(Config.Police.Jobs) do
        if job.name == policeJob then
            isPolice = true
            break
        end
    end
    if not isPolice then return {} end
    if (job.grade or 0) < Config.Police.DepositReviewMinGrade then return {} end

    return GetFlaggedDepositsAtBank(bankCoords)
end)

--- Police: confiscate a flagged deposit
lib.callback.register("t1ger_moneywash:server:confiscateDeposit", function(source, targetIdentifier)
    local job = _API.Player.GetJob(source)
    if not job then return { success = false, reason = "invalid_job" } end

    local isPolice = false
    for _, policeJob in ipairs(Config.Police.Jobs) do
        if job.name == policeJob then
            isPolice = true
            break
        end
    end
    if not isPolice then return { success = false, reason = "not_police" } end
    if (job.grade or 0) < Config.Police.DepositReviewMinGrade then
        return { success = false, reason = "insufficient_grade" }
    end

    local success, reason = ConfiscateDeposit(source, targetIdentifier)
    return { success = success, reason = reason }
end)

--- -------------------------------------------------------------------------
--- RAIDS
--- -------------------------------------------------------------------------

--- Police: raid a business via Handler NPC target
lib.callback.register("t1ger_moneywash:server:raidBusiness", function(source, businessId)
    local job = _API.Player.GetJob(source)
    if not job then return { success = false, reason = "invalid_job" } end

    local isPolice = false
    for _, policeJob in ipairs(Config.Police.Jobs) do
        if job.name == policeJob then
            isPolice = true
            break
        end
    end
    if not isPolice then return { success = false, reason = "not_police" } end
    if (job.grade or 0) < Config.Police.RaidMinGrade then
        return { success = false, reason = "insufficient_grade" }
    end

    local business = GetBusiness(businessId)
    if not business then return { success = false, reason = "not_found" } end

    -- Validate police officer is near the business
    local location = GetLocationConfig(business.type, business.locationId)
    if not location or not IsPlayerNearCoords(source, location.coords, 10.0) then
        return { success = false, reason = "target_too_far" }
    end

    ExecuteRaid(businessId, source)
    return { success = true }
end)

--- -------------------------------------------------------------------------
--- ACCOUNTANT REVIEW
--- -------------------------------------------------------------------------

--- Get available receipts for a business (shown before player commits)
lib.callback.register("t1ger_moneywash:server:getBusinessReceipts", function(source, businessId)
    local identifier = _API.Player.GetIdentifier(source)
    local business = GetBusiness(businessId)
    if not business or business.identifier ~= identifier then return {} end
    return GetBusinessReceipts(businessId)
end)

--- Get estimated effectiveness for selected receipts (live preview)
lib.callback.register("t1ger_moneywash:server:estimateReviewEffectiveness",
    function(source, businessId, selectedReceiptIds)
        local identifier = _API.Player.GetIdentifier(source)
        local business = GetBusiness(businessId)
        if not business or business.identifier ~= identifier then return nil end

        local label, reduction = EstimateReviewEffectiveness(businessId, selectedReceiptIds)
        return { label = label, reduction = reduction }
    end)

--- Execute accountant review
lib.callback.register("t1ger_moneywash:server:executeReview",
    function(source, businessId, selectedReceiptIds, currentCycle)
        local success, reason, result = ExecuteAccountantReview(source, businessId, selectedReceiptIds, currentCycle)
        return { success = success, reason = reason, result = result }
    end)

--- -------------------------------------------------------------------------
--- ADMIN COMMANDS
--- -------------------------------------------------------------------------

RegisterCommand("moneywash:addbusiness", function(src, args)
    local isConsole = (src == 0)
    if not isConsole and not _API.Player.IsAdmin(src) then return end

    local identifier   = args[1]
    local businessType = args[2]
    local locationId   = tonumber(args[3])

    if not identifier or not businessType or not locationId then
        local msg = "Usage: /moneywash:addbusiness <identifier> <type> <locationId>"
        if isConsole then print(msg) else _API.SendNotification(src, msg, "error") end
        return
    end

    local success, reason = AdminAddBusiness(identifier, businessType, locationId)
    local msg = success
        and ("Business added: %s #%d → %s"):format(businessType, locationId, identifier)
        or ("Failed: %s"):format(reason)
    if isConsole then print(msg) else _API.SendNotification(src, msg, success and "success" or "error") end
end, true)

RegisterCommand("moneywash:removebusiness", function(src, args)
    local isConsole = (src == 0)
    if not isConsole and not _API.Player.IsAdmin(src) then return end

    local businessType = args[1]
    local locationId   = tonumber(args[2])

    if not businessType or not locationId then
        local msg = "Usage: /moneywash:removebusiness <type> <locationId>"
        if isConsole then print(msg) else _API.SendNotification(src, msg, "error") end
        return
    end

    local success, reason = AdminRemoveBusiness(businessType, locationId)
    local msg = success
        and ("Business removed: %s #%d"):format(businessType, locationId)
        or ("Failed: %s"):format(reason)
    if isConsole then print(msg) else _API.SendNotification(src, msg, success and "success" or "error") end
end, true)
