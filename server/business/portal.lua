--- ============================================================================
--- Business Portal Server
--- Creates authoritative marketplace snapshots, validates portal actions and
--- keeps open portals synchronized when a location is purchased.
--- ============================================================================

local ActivePortalViewers = {}

local CLIENT_EVENTS = {
    refresh = "t1ger_moneywash:client:businessPortal:refresh",
}

local SERVER_CALLBACKS = {
    getSnapshot = "t1ger_moneywash:server:businessPortal:getSnapshot",
    purchaseBusiness = "t1ger_moneywash:server:businessPortal:purchaseBusiness",
    getWaypoint = "t1ger_moneywash:server:businessPortal:getWaypoint",
}


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
    local rank = reputation and reputation:GetTitle()
        or Config.Reputation.Levels[0]
        or "Investor"

    local thresholds = {}

    for threshold in pairs(Config.Reputation.Levels) do
        thresholds[#thresholds + 1] = tonumber(threshold)
    end

    table.sort(thresholds)

    local currentRankPoints = thresholds[1] or 0
    local nextRankPoints = nil

    for _, threshold in ipairs(thresholds) do
        if points >= threshold then
            currentRankPoints = threshold
        elseif not nextRankPoints then
            nextRankPoints = threshold
            break
        end
    end

    local percentage = 100

    if nextRankPoints then
        local range = nextRankPoints - currentRankPoints

        if range > 0 then
            percentage = math.floor(
                ((points - currentRankPoints) / range) * 100
            )
        end
    end

    percentage = math.max(0, math.min(100, percentage))

    return {
        points = points,
        rank = rank,
        currentRankPoints = currentRankPoints,
        nextRankPoints = nextRankPoints,
        percentage = percentage,
    }
end


--- Loads the current runtime locale JSON without requiring a UI rebuild.
---@return string localeName
---@return table messages
local function loadPortalLocalization()
    local portalConfig = Config.BusinessPortal or {}

    local localeName = portalConfig.Locale
        or GetConvar("ox:locale", "en")
        or "en"

    if type(localeName) ~= "string"
        or not localeName:match("^[%w_-]+$")
    then
        localeName = "en"
    end

    local resourceName = GetCurrentResourceName()
    local localeContents = LoadResourceFile(
        resourceName,
        ("locales/%s.json"):format(localeName)
    )

    if not localeContents and localeName ~= "en" then
        localeName = "en"
        localeContents = LoadResourceFile(
            resourceName,
            "locales/en.json"
        )
    end

    if not localeContents then
        return localeName, {}
    end

    local decodeSucceeded, messages = pcall(
        json.decode,
        localeContents
    )

    if not decodeSucceeded or type(messages) ~= "table" then
        print(("^1[MoneyWash] Failed to decode locales/%s.json.^7"):format(
            localeName
        ))

        return localeName, {}
    end

    return localeName, messages
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

    local identifier = _API.Player.GetIdentifier(source)

    if not identifier then
        return nil, "invalid_player"
    end

    local playerBusinesses = GetPlayerBusinesses(identifier)
    local ownsAnyBusiness = #playerBusinesses > 0

    local ownedLocations = {}

    for _, business in ipairs(playerBusinesses) do
        ownedLocations[
            ("%s:%d"):format(business.type, business.locationId)
        ] = business
    end

    local reputation = GetPlayerReputation(source)
    local reputationPoints = reputation and reputation:GetPoints() or 0

    local configuredLocations = require("shared/business_locations")

    local tiers = {}
    local visibleLocations = {}

    for tierNumber, tier in pairs(Config.Business.Tiers) do
        local tierLocations = configuredLocations[tier.type] or {}
        local totalLocationCount = countEntries(tierLocations)

        local isUnlocked = not Config.Reputation.Enable
            or reputationPoints >= tier.requiredPoints

        local availableLocationCount = 0

        if isUnlocked then
            for locationId in pairs(tierLocations) do
                if not IsLocationOwned(tier.type, locationId) then
                    availableLocationCount =
                        availableLocationCount + 1
                end
            end
        end

        tiers[#tiers + 1] = {
            tierNumber = tierNumber,
            businessType = tier.type,
            displayName = tier.label,
            requiredInvestorScore = tier.requiredPoints,
            purchasePrice = tier.price,
            projectedRevenue = tier.expectedRevenue,
            operatingFeePercentage = tier.launderFee,
            isUnlocked = isUnlocked,
            availableLocationCount = availableLocationCount,
            totalLocationCount = totalLocationCount,
        }

        for locationId, location in pairs(tierLocations) do
            local locationKey = ("%s:%d"):format(
                tier.type,
                locationId
            )

            local ownedBusiness = ownedLocations[locationKey]
            local isAvailable = not IsLocationOwned(
                tier.type,
                locationId
            )

            -- Locked locations and locations owned by other players are never
            -- sent to the client, preventing their coordinates being exposed.
            if ownedBusiness or (isUnlocked and isAvailable) then
                visibleLocations[#visibleLocations + 1] = {
                    key = locationKey,
                    locationId = locationId,
                    ownedBusinessId = ownedBusiness
                        and ownedBusiness.id
                        or nil,
                    businessType = tier.type,
                    displayName = location.brand or tier.label,
                    imageFileName = location.imageFileName,
                    price = location.price or tier.price,
                    ownership = ownedBusiness
                        and "ownedByPlayer"
                        or "available",
                    coordinates = serializeCoordinates(
                        location.coords
                    ),
                    address = {
                        street = nil,
                        crossingRoad = nil,
                        zone = nil,
                    },
                }
            end
        end
    end

    table.sort(tiers, function(firstTier, secondTier)
        return firstTier.tierNumber < secondTier.tierNumber
    end)

    table.sort(visibleLocations, function(firstLocation, secondLocation)
        if firstLocation.businessType == secondLocation.businessType then
            return firstLocation.locationId
                < secondLocation.locationId
        end

        return firstLocation.businessType
            < secondLocation.businessType
    end)

    local localeName, messages = loadPortalLocalization()
    local portalConfig = Config.BusinessPortal or {}

    return {
        profile = {
            characterName =
                _API.Player.GetCharacterName(source)
                or GetPlayerName(source)
                or "Unknown Investor",

            bankBalance = _API.Player.GetMoney(source, "bank"),
            ownsBusiness = ownsAnyBusiness,

            investorProgress = createInvestorProgress(source),
        },

        tiers = tiers,
        locations = visibleLocations,

        settings = {
            currencySymbol = Config.Currency or "$",

            -- These values will begin overriding the compiled design tokens
            -- when Config.BusinessPortal.Theme is added later.
            theme = portalConfig.Theme or {},
        },

        localization = {
            locale = localeName,
            messages = messages,
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
            TriggerClientEvent(
                CLIENT_EVENTS.refresh,
                playerSource
            )
        end
    end
end


--- Returns the initial portal snapshot and registers the player as a viewer.
lib.callback.register(
    SERVER_CALLBACKS.getSnapshot,
    function(source)
        local snapshot, reason = createMarketplaceSnapshot(source)

        if not snapshot then
            return {
                success = false,
                reason = reason or "snapshot_unavailable",
            }
        end

        ActivePortalViewers[source] = true

        return {
            success = true,
            data = snapshot,
        }
    end
)


--- Performs a server-authoritative purchase using the existing business logic.
lib.callback.register(
    SERVER_CALLBACKS.purchaseBusiness,
    function(source, businessType, locationId)
        if not ActivePortalViewers[source] then
            return {
                success = false,
                reason = "portal_closed",
            }
        end

        if type(businessType) ~= "string" then
            return {
                success = false,
                reason = "invalid_type",
            }
        end

        locationId = tonumber(locationId)

        if not locationId then
            return {
                success = false,
                reason = "invalid_location",
            }
        end

        local purchaseSucceeded, reason = BuyBusiness(
            source,
            businessType,
            locationId
        )

        if not purchaseSucceeded then
            return {
                success = false,
                reason = reason or "purchase_failed",
            }
        end

        local snapshot, snapshotReason =
            createMarketplaceSnapshot(source)

        -- Other open portals immediately stop exposing the purchased location.
        RefreshBusinessPortalViewers(source)

        if not snapshot then
            return {
                success = true,
                reason = snapshotReason,
            }
        end

        return {
            success = true,
            data = snapshot,
        }
    end
)


--- Validates ownership before returning waypoint coordinates.
lib.callback.register(
    SERVER_CALLBACKS.getWaypoint,
    function(source, businessType, locationId)
        if not ActivePortalViewers[source] then
            return {
                success = false,
                reason = "portal_closed",
            }
        end

        if type(businessType) ~= "string" then
            return {
                success = false,
                reason = "invalid_type",
            }
        end

        locationId = tonumber(locationId)

        if not locationId then
            return {
                success = false,
                reason = "invalid_location",
            }
        end

        local identifier = _API.Player.GetIdentifier(source)
        local business = GetBusinessByLocation(
            businessType,
            locationId
        )

        if not identifier
            or not business
            or business.identifier ~= identifier
        then
            return {
                success = false,
                reason = "not_owner",
            }
        end

        local location = GetLocationConfig(
            businessType,
            locationId
        )

        if not location or not location.coords then
            return {
                success = false,
                reason = "invalid_location",
            }
        end

        return {
            success = true,
            data = serializeCoordinates(location.coords),
        }
    end
)


--- Stops sending refresh events after the player closes the portal.
RegisterNetEvent(
    "t1ger_moneywash:server:businessPortal:closed",
    function()
        ActivePortalViewers[source] = nil
    end
)


AddEventHandler("playerDropped", function()
    ActivePortalViewers[source] = nil
end)