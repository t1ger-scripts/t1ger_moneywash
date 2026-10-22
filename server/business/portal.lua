--- Business portal server: builds the portal snapshot, validates portal actions and refreshes open portals.

--- Players who currently have the portal open.
---@type table<number, boolean>
local viewers = {}

--- Players with a refresh already waiting (see RefreshPortalViewer).
---@type table<number, boolean>
local queuedRefresh = {}

--- Turns coordinates into a plain table the UI can receive.
---@param coords vector3|vector4|table
---@return { x: number, y: number, z: number }
local function toCoordinates(coords)
    return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

--- Checks the business type and location id sent by the UI.
---@param businessType any
---@param locationId any
---@return string|nil businessType
---@return number|string|nil locationId The number, or the failure reason when businessType is nil
local function parseLocation(businessType, locationId)
    if type(businessType) ~= "string" then return nil, "invalid_type" end

    locationId = tonumber(locationId)
    if not locationId then return nil, "invalid_location" end

    return businessType, locationId
end

--- Reputation data for the portal header.
---@param source number
---@return table
local function getInvestorProgress(source)
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

--- Builds everything the portal shows for one player.
--- Locked locations and locations owned by others are never included, so their coordinates are never sent.
---@param source number
---@return table|nil snapshot
---@return string|nil reason
local function buildSnapshot(source)
    if not IsBusinessStoreReady() then return nil, "business_store_not_ready" end

    if Config.Reputation.Enable and not IsReputationReady(source) then
        return nil, "reputation_not_ready"
    end

    local identifier = _API.Player.GetIdentifier(source)
    if not identifier then return nil, "invalid_player" end

    local playerBusinesses = GetPlayerBusinesses(identifier)

    local ownedByPlayer = {}
    for _, business in ipairs(playerBusinesses) do
        ownedByPlayer[("%s:%d"):format(business.type, business.locationId)] = business
    end

    local reputation = GetPlayerReputation(source)
    local points = reputation and reputation:GetPoints() or 0

    local tiers = {}
    local locations = {}

    for tierNumber, tier in pairs(Config.Business.Tiers) do
        local unlocked = not Config.Reputation.Enable or points >= tier.requiredPoints
        local totalCount, availableCount = 0, 0

        for locationId, location in pairs(Config.Business.Locations[tier.type] or {}) do
            local key = ("%s:%d"):format(tier.type, locationId)
            local owned = ownedByPlayer[key]
            local available = not IsLocationOwned(tier.type, locationId)

            totalCount = totalCount + 1
            if unlocked and available then availableCount = availableCount + 1 end

            if owned or (unlocked and available) then
                locations[#locations + 1] = {
                    key = key,
                    locationId = locationId,
                    ownedBusinessId = owned and owned.id or nil,
                    businessType = tier.type,
                    displayName = location.brand or tier.label,
                    imageFileName = location.image or ("%s_%03d.webp"):format(tier.type, locationId),
                    price = location.price,
                    ownership = owned and "ownedByPlayer" or "available",
                    coordinates = toCoordinates(location.coords),
                    address = { street = nil, crossingRoad = nil, zone = nil }, -- Filled in by the client
                }
            end
        end

        tiers[#tiers + 1] = {
            tierNumber = tierNumber,
            businessType = tier.type,
            displayName = tier.label,
            requiredInvestorScore = tier.requiredPoints,
            projectedRevenue = tier.expectedRevenue,
            isUnlocked = unlocked,
            availableLocationCount = availableCount,
            totalLocationCount = totalCount,
        }
    end

    table.sort(tiers, function(a, b) return a.tierNumber < b.tierNumber end)

    table.sort(locations, function(a, b)
        if a.businessType == b.businessType then return a.locationId < b.locationId end
        return a.businessType < b.businessType
    end)

    return {
        profile = {
            characterName = _API.Player.GetCharacterName(source) or GetPlayerName(source) or locale("general.unknown_investor"),
            bankBalance = _API.Player.GetMoney(source, "bank"),
            ownsBusiness = #playerBusinesses > 0,
            investorProgress = getInvestorProgress(source),
        },
        tiers = tiers,
        locations = locations,
        settings = {
            currencySymbol = Config.Currency or "$",
            theme = Config.WebPortal.Theme or {},
        },
    }
end

--- Asks every open portal to fetch a fresh snapshot.
---@param excludedSource number|nil Player to skip (the one who already has fresh data)
function RefreshPortalViewers(excludedSource)
    for source in pairs(viewers) do
        if not GetPlayerName(source) then
            viewers[source] = nil
        elseif source ~= excludedSource then
            TriggerClientEvent("t1ger_moneywash:client:portal:refresh", source)
        end
    end
end

--- Asks one player's open portal to refresh. Calls within 500 ms are merged into one.
---@param source number
function RefreshPortalViewer(source)
    if not viewers[source] or queuedRefresh[source] then return end

    queuedRefresh[source] = true

    SetTimeout(500, function()
        queuedRefresh[source] = nil

        if viewers[source] and GetPlayerName(source) then
            TriggerClientEvent("t1ger_moneywash:client:portal:refresh", source)
        end
    end)
end

--- Returns the portal snapshot and registers the player as a viewer.
lib.callback.register("t1ger_moneywash:server:portal:snapshot", function(source)
    local snapshot, reason = buildSnapshot(source)
    if not snapshot then
        return { success = false, reason = reason or "snapshot_unavailable" }
    end

    viewers[source] = true

    return { success = true, data = snapshot }
end)

--- Buys a business. Returns a fresh snapshot and refreshes everyone else's portal.
lib.callback.register("t1ger_moneywash:server:portal:purchase", function(source, businessType, locationId)
    if not viewers[source] then return { success = false, reason = "portal_closed" } end

    local parsedType, parsedId = parseLocation(businessType, locationId)
    if not parsedType then return { success = false, reason = parsedId } end

    local bought, reason = BuyBusiness(source, parsedType, parsedId)
    if not bought then
        return { success = false, reason = reason or "purchase_failed" }
    end

    local snapshot, snapshotReason = buildSnapshot(source)

    RefreshPortalViewers(source) -- Other portals stop showing the location

    if not snapshot then return { success = true, reason = snapshotReason } end

    return { success = true, data = snapshot }
end)

--- Returns the coordinates of a business the player owns.
lib.callback.register("t1ger_moneywash:server:portal:waypoint", function(source, businessType, locationId)
    if not viewers[source] then return { success = false, reason = "portal_closed" } end

    local parsedType, parsedId = parseLocation(businessType, locationId)
    if not parsedType then return { success = false, reason = parsedId } end

    local identifier = _API.Player.GetIdentifier(source)
    local business = GetBusinessByLocation(parsedType, parsedId)
    if not identifier or not business or business.identifier ~= identifier then
        return { success = false, reason = "not_owner" }
    end

    local location = GetLocationConfig(parsedType, parsedId)
    if not location or not location.coords then
        return { success = false, reason = "invalid_location" }
    end

    return { success = true, data = toCoordinates(location.coords) }
end)

--- The player closed the portal: stop sending refreshes.
RegisterNetEvent("t1ger_moneywash:server:portal:closed", function()
    viewers[source] = nil
end)

AddEventHandler("playerDropped", function()
    viewers[source] = nil
    queuedRefresh[source] = nil
end)