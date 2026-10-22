--- Business portal server: builds marketplace snapshots, validates portal actions and syncs open portals on purchase.

local ActivePortalViewers = {}
local QueuedViewerRefresh = {}

--- Counts the entries in a keyed table.
---@param collection table|nil
---@return number
local function countEntries(collection)
    local count = 0
    for _ in pairs(collection or {}) do
        count = count + 1
    end
    return count
end

--- Returns reputation progression data for the portal header.
---@param source number
---@return table
local function createInvestorProgress(source)
    if not Config.Reputation.Enable then
        return {
            points = 0,
            rank = Config.Reputation.Levels[0] or "Investor",
            currentRankPoints = 0,
            nextRankPoints = nil,
            percentage = 100,
        }
    end

    local reputation = GetPlayerReputation(source)
    local points = reputation and reputation:GetPoints() or 0
    local level = GetReputationLevel(points)

    return {
        points = points,
        rank = level.title,
        currentRankPoints = level.currentPoints,
        nextRankPoints = level.nextPoints,
        percentage = level.progress,
    }
end



--- Creates a plain coordinate table safe for NUI serialization.
---@param coordinates vector3|vector4|table
---@return table
local function serializeCoordinates(coordinates)
    return {
        x = coordinates.x + 0.0,
        y = coordinates.y + 0.0,
        z = coordinates.z + 0.0,
    }
end

--- Creates the complete player-specific marketplace payload.
---@param source number
---@return table|nil payload
---@return string|nil reason
local function createMarketplaceSnapshot(source)
    if type(IsBusinessStoreReady) == "function"
        and not IsBusinessStoreReady()
    then
        return nil, "business_store_not_ready"
    end

    if Config.Reputation.Enable and type(IsReputationReady) == "function" and not IsReputationReady(source) then
        return nil, "reputation_not_ready"
    end

    local identifier = _API.Player.GetIdentifier(source)

    if not identifier then
        return nil, "invalid_player"
    end

    local playerBusinesses = GetPlayerBusinesses(identifier)
    local ownsAnyBusiness = #playerBusinesses > 0

    local ownedLocations = {}

    for _, business in ipairs(playerBusinesses) do
        ownedLocations[("%s:%d"):format(business.type, business.locationId)] = business
    end

    local reputation = GetPlayerReputation(source)
    local reputationPoints = reputation and reputation:GetPoints() or 0

    local configuredLocations = Config.Business.Locations

    local tiers = {}
    local visibleLocations = {}

    for tierNumber, tier in pairs(Config.Business.Tiers) do
        local tierLocations = configuredLocations[tier.type] or {}
        local totalLocationCount = countEntries(tierLocations)

        local isUnlocked = not Config.Reputation.Enable or reputationPoints >= tier.requiredPoints

        local availableLocationCount = 0

        if isUnlocked then
            for locationId in pairs(tierLocations) do
                if not IsLocationOwned(tier.type, locationId) then
                    availableLocationCount = availableLocationCount + 1
                end
            end
        end

        tiers[#tiers + 1] = {
            tierNumber = tierNumber,
            businessType = tier.type,
            displayName = tier.label,
            requiredInvestorScore = tier.requiredPoints,
            projectedRevenue = tier.expectedRevenue,
            isUnlocked = isUnlocked,
            availableLocationCount = availableLocationCount,
            totalLocationCount = totalLocationCount,
        }

        for locationId, location in pairs(tierLocations) do
            local locationKey = ("%s:%d"):format(tier.type, locationId)

            local ownedBusiness = ownedLocations[locationKey]
            local isAvailable = not IsLocationOwned(tier.type, locationId)

            -- Locked locations and locations owned by other players are never
            -- sent to the client, preventing their coordinates being exposed.
            if ownedBusiness or (isUnlocked and isAvailable) then
                visibleLocations[#visibleLocations + 1] = {
                    key = locationKey,
                    locationId = locationId,
                    ownedBusinessId = ownedBusiness and ownedBusiness.id or nil,
                    businessType = tier.type,
                    displayName = location.brand or tier.label,
                    imageFileName = location.image or ("%s_%03d.webp"):format(tier.type, locationId),
                    price = location.price,
                    ownership = ownedBusiness and "ownedByPlayer" or "available",
                    coordinates = serializeCoordinates(location.coords),
                    address = { street = nil, crossingRoad = nil, zone = nil },
                }
            end
        end
    end

    table.sort(tiers, function(firstTier, secondTier)
        return firstTier.tierNumber < secondTier.tierNumber
    end)

    table.sort(visibleLocations, function(firstLocation, secondLocation)
        if firstLocation.businessType == secondLocation.businessType then
            return firstLocation.locationId < secondLocation.locationId
        end

        return firstLocation.businessType < secondLocation.businessType
    end)

    return {
        profile = {
            characterName = _API.Player.GetCharacterName(source) or GetPlayerName(source) or locale("general.unknown_investor"),

            bankBalance = _API.Player.GetMoney(source, "bank"),
            ownsBusiness = ownsAnyBusiness,

            investorProgress = createInvestorProgress(source),
        },

        tiers = tiers,
        locations = visibleLocations,

        settings = {
            currencySymbol = Config.Currency or "$",
            theme = Config.WebPortal.Theme or {},
        },
    }
end


--- Prompts every player with an open portal to request a fresh snapshot.
---@param excludedSource number|nil
function RefreshBusinessPortalViewers(excludedSource)
    for playerSource in pairs(ActivePortalViewers) do
        if not GetPlayerName(playerSource) then
            ActivePortalViewers[playerSource] = nil
        elseif playerSource ~= excludedSource then
            TriggerClientEvent("t1ger_moneywash:client:portal:refresh", playerSource)
        end
    end
end

--- Refreshes one player's open portal. Calls within 500 ms are merged into one refresh.
---@param playerSource number
function RefreshBusinessPortalViewer(playerSource)
    if not ActivePortalViewers[playerSource] or QueuedViewerRefresh[playerSource] then
        return
    end

    QueuedViewerRefresh[playerSource] = true

    SetTimeout(500, function()
        QueuedViewerRefresh[playerSource] = nil

        if ActivePortalViewers[playerSource] and GetPlayerName(playerSource) then
            TriggerClientEvent("t1ger_moneywash:client:portal:refresh", playerSource)
        end
    end)
end

--- Returns the initial portal snapshot and registers the player as a viewer.
lib.callback.register("t1ger_moneywash:server:portal:snapshot", function(source)
    local snapshot, reason = createMarketplaceSnapshot(source)

    if not snapshot then
        return {success = false, reason = reason or "snapshot_unavailable"}
    end

    ActivePortalViewers[source] = true

    return {success = true, data = snapshot}
end)

--- Performs a server-authoritative purchase using the existing business logic.
lib.callback.register("t1ger_moneywash:server:portal:purchase", function(source, businessType, locationId)
    if not ActivePortalViewers[source] then
        return { success = false, reason = "portal_closed" }
    end

    if type(businessType) ~= "string" then
        return { success = false, reason = "invalid_type" }
    end

    locationId = tonumber(locationId)

    if not locationId then
        return { success = false, reason = "invalid_location" }
    end

    local purchaseSucceeded, reason = BuyBusiness(source, businessType, locationId)

    if not purchaseSucceeded then
        return { success = false, reason = reason or "purchase_failed" }
    end

    local snapshot, snapshotReason = createMarketplaceSnapshot(source)

    -- Other open portals immediately stop exposing the purchased location.
    RefreshBusinessPortalViewers(source)

    if not snapshot then
        return { success = true, reason = snapshotReason }
    end

    return { success = true, data = snapshot }
end)

--- Validates ownership before returning waypoint coordinates.
lib.callback.register("t1ger_moneywash:server:portal:waypoint", function(source, businessType, locationId)
    if not ActivePortalViewers[source] then
        return { success = false, reason = "portal_closed" }
    end

    if type(businessType) ~= "string" then
        return { success = false, reason = "invalid_type" }
    end

    locationId = tonumber(locationId)

    if not locationId then
        return { success = false, reason = "invalid_location" }
    end

    local identifier = _API.Player.GetIdentifier(source)
    local business = GetBusinessByLocation(businessType, locationId)

    if not identifier or not business or business.identifier ~= identifier then
        return { success = false, reason = "not_owner" }
    end

    local location = GetLocationConfig(businessType, locationId)

    if not location or not location.coords then
        return { success = false, reason = "invalid_location" }
    end

    return {
        success = true,
        data = serializeCoordinates(location.coords),
    }
end)

--- Stops sending refresh events after the player closes the portal.
RegisterNetEvent("t1ger_moneywash:server:portal:closed", function()
    ActivePortalViewers[source] = nil
end)

AddEventHandler("playerDropped", function()
    ActivePortalViewers[source] = nil
end)