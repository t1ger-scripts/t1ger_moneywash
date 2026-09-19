--- ============================================================================
--- Browser Server
--- Builds the authoritative Ledger Capital browser snapshot.
--- ============================================================================

--- Returns sorted reputation levels for the browser.
--- @return table
local function GetBrowserReputationLevels()
    local levels = {}

    for points, label in pairs(Config.Reputation.Levels) do
        levels[#levels + 1] = {
            points = tonumber(points) or 0,
            label = label,
        }
    end

    table.sort(levels, function(a, b)
        return a.points < b.points
    end)

    return levels
end

--- Converts a FiveM vector into a plain serializable table.
--- @param coords vector3|vector4
--- @return table
local function SerializeBrowserCoords(coords)
    return {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        heading = coords.w and (coords.w + 0.0) or 0.0,
    }
end

--- Builds all browser data visible to one player.
--- Locked-tier location coordinates are deliberately excluded.
--- @param src number
--- @return table|nil data
--- @return string|nil reason
local function BuildBrowserSnapshot(src)
    if not IsBusinessStoreReady() then
        return nil, "business_store_not_ready"
    end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then
        return nil, "invalid_player"
    end

    local characterName = _API.Player.GetCharacterName(src)
    if not characterName then
        return nil, "invalid_player"
    end

    local reputation = GetPlayerReputation(src)
    if not reputation then
        return nil, "player_data_not_ready"
    end

    local points = reputation:GetPoints()
    local portfolioWeight = GetPlayerPortfolioWeight(identifier)
    local configuredLocations = require("shared/business_locations")

    local tiers = {}
    local locations = {}

    for tierNumber, tier in ipairs(Config.Business.Tiers) do
        local unlocked =
            not Config.Reputation.Enable or
            points >= tier.requiredPoints

        local alreadyOwns = PlayerOwnsType(identifier, tier.type)
        local hasCapacity =
            (portfolioWeight + tier.weight) <=
            Config.Business.PortfolioLimit

        local availableCount = 0

        -- Only unlocked locations are serialized.
        if unlocked then
            local tierLocations = configuredLocations[tier.type] or {}
            local locationIds = {}

            for locationId in pairs(tierLocations) do
                locationIds[#locationIds + 1] = locationId
            end

            table.sort(locationIds)

            for _, locationId in ipairs(locationIds) do
                local location = tierLocations[locationId]
                local ownedBusiness = GetBusinessByLocation(
                    tier.type,
                    locationId
                )

                local status = "available"
                local businessId = nil

                if ownedBusiness then
                    if ownedBusiness.identifier == identifier then
                        status = "active"
                        businessId = ownedBusiness.id
                    else
                        status = "acquired"
                    end
                else
                    availableCount = availableCount + 1
                end

                locations[#locations + 1] = {
                    uid = ("%s:%d"):format(tier.type, locationId),
                    id = locationId,
                    businessId = businessId,
                    type = tier.type,
                    brand = location.brand,
                    coords = SerializeBrowserCoords(location.coords),
                    price = location.price or tier.price,
                    status = status,
                }
            end
        end

        tiers[#tiers + 1] = {
            tier = tierNumber,
            type = tier.type,
            label = tier.label,
            weight = tier.weight,
            requiredPoints = tier.requiredPoints,
            price = tier.price,
            expectedRevenue = tier.expectedRevenue,
            launderFee = tier.launderFee,
            unlocked = unlocked,
            alreadyOwns = alreadyOwns,
            hasCapacity = hasCapacity,
            availableCount = unlocked and availableCount or nil,
        }
    end

    return {
        profile = {
            characterName = characterName,
            balance = _API.Player.GetMoney(src, "bank"),
            reputation = points,
            reputationLabel = reputation:GetTitle(),
            portfolioWeight = portfolioWeight,
            portfolioLimit = Config.Business.PortfolioLimit,
        },

        tiers = tiers,
        locations = locations,
        reputationLevels = GetBrowserReputationLevels(),

        settings = {
            currency = Config.Currency,
            theme = Config.BrowserUI.Theme,
            transferDistance = Config.Browser.TransferDistance,
        },
    }
end

lib.callback.register(
    "t1ger_moneywash:server:getBrowserBootstrap",
    function(source)
        local data, reason = BuildBrowserSnapshot(source)

        if not data then
            return {
                success = false,
                reason = reason or "unknown",
            }
        end

        return {
            success = true,
            data = data,
        }
    end
)