--- ============================================================
--- Business Purchase, Transfer, Abandon and Admin Controls
--- All operations validate fully server-side before executing.
--- Exports available for use by other resources (crime tablets etc.)
--- ============================================================

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

--- Returns whether a player has enough portfolio capacity to add a given tier
--- @param identifier string
--- @param tier table
--- @return boolean
local function HasPortfolioCapacity(identifier, tier)
    local currentWeight = GetPlayerPortfolioWeight(identifier)
    return (currentWeight + tier.weight) <= Config.Business.PortfolioLimit
end

--- Purchases a business for a player
--- @param src number player source
--- @param businessType string
--- @param locationId number
--- @return boolean success, string reason
function BuyBusiness(src, businessType, locationId)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local tier = GetTierByType(businessType)
    if not tier then return false, "invalid_type" end

    local location = GetLocationConfig(businessType, locationId)
    if not location then return false, "invalid_location" end

    if IsLocationOwned(businessType, locationId) then
        return false, "already_owned"
    end

    if PlayerOwnsType(identifier, businessType) then
        return false, "already_owns_type"
    end

    if not MeetsReputationRequirement(src, tier) then
        return false, "insufficient_reputation"
    end

    if not HasPortfolioCapacity(identifier, tier) then
        return false, "portfolio_full"
    end

    local price = location.price or tier.price
    local playerMoney = _API.Player.GetMoney(src, "bank")
    if playerMoney < price then return false, "insufficient_funds" end

    _API.Player.RemoveMoney(src, price, "bank")

    local now = os.time()
    local id = MySQL.insert.await(
        "INSERT INTO moneywash_businesses " ..
        "(identifier, business_type, location_id, stock, safe_covered, safe_exposed, " ..
        "suspicion, total_laundered, last_laundered_at, is_closed, purchased_at) " ..
        "VALUES (?, ?, ?, 0, 0, 0, 0, 0, 0, 0, ?)",
        {identifier, businessType, locationId, now}
    )

    if not id then
        _API.Player.AddMoney(src, price, "bank")
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

    TriggerClientEvent("t1ger_moneywash:client:businessPurchased", src, id, businessType, locationId)

    if Config.Debug then
        print(("[MoneyWash] Player %d purchased %s (location %d) for $%d"):format(
            src, businessType, locationId, price))
    end

    return true, "success"
end

--- Transfers a business to another player
--- New owner inherits everything as-is (safe balances, stock, suspicion, totalLaundered)
--- @param src number current owner source
--- @param targetIdentifier string new owner identifier
--- @param businessId number
--- @return boolean success, string reason
function TransferBusiness(src, targetIdentifier, businessId)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local business = GetBusiness(businessId)
    if not business then return false, "not_found" end

    if business.identifier ~= identifier then return false, "not_owner" end

    -- Target must be online for transfer
    local targetSrc = nil
    local players = _API.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.identifier == targetIdentifier then
            targetSrc = player.source
            break
        end
    end
    if not targetSrc then return false, "target_not_online" end

    if PlayerOwnsType(targetIdentifier, business.type) then
        return false, "target_owns_type"
    end

    local tier = GetTierByType(business.type)
    if not HasPortfolioCapacity(targetIdentifier, tier) then
        return false, "target_portfolio_full"
    end

    MySQL.update("UPDATE moneywash_businesses SET identifier = ? WHERE id = ?",
        {targetIdentifier, businessId})

    UpdateBusiness(businessId, "identifier", targetIdentifier)

    TriggerClientEvent("t1ger_moneywash:client:businessTransferred", src, businessId)
    TriggerClientEvent("t1ger_moneywash:client:businessReceived", targetSrc, businessId, business.type, business.locationId)

    if Config.Debug then
        print(("[MoneyWash] Business %d transferred from %s to %s"):format(
            businessId, identifier, targetIdentifier))
    end

    return true, "success"
end

--- Abandons a business with zero refund
--- Safe balance is forfeited, location returns to market immediately
--- @param src number
--- @param businessId number
--- @return boolean success, string reason
function AbandonBusiness(src, businessId)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local business = GetBusiness(businessId)
    if not business then return false, "not_found" end

    if business.identifier ~= identifier then return false, "not_owner" end

    MySQL.query("DELETE FROM moneywash_businesses WHERE id = ?", {businessId})
    MySQL.query("DELETE FROM moneywash_receipts WHERE business_id = ?", {businessId})

    RemoveFromStore(businessId)

    TriggerClientEvent("t1ger_moneywash:client:businessAbandoned", src, businessId)

    if Config.Debug then
        print(("[MoneyWash] Business %d abandoned by %s"):format(businessId, identifier))
    end

    return true, "success"
end

--- Admin: forcibly adds a business, bypassing reputation and portfolio checks
--- @param identifier string
--- @param businessType string
--- @param locationId number
--- @return boolean success, string reason
function AdminAddBusiness(identifier, businessType, locationId)
    local tier = GetTierByType(businessType)
    if not tier then return false, "invalid_type" end

    local location = GetLocationConfig(businessType, locationId)
    if not location then return false, "invalid_location" end

    if IsLocationOwned(businessType, locationId) then
        return false, "already_owned"
    end

    local now = os.time()
    local id = MySQL.insert.await(
        "INSERT INTO moneywash_businesses " ..
        "(identifier, business_type, location_id, stock, safe_covered, safe_exposed, " ..
        "suspicion, total_laundered, last_laundered_at, is_closed, purchased_at) " ..
        "VALUES (?, ?, ?, 0, 0, 0, 0, 0, 0, 0, ?)",
        {identifier, businessType, locationId, now}
    )

    if not id then return false, "database_error" end

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

    -- Notify owner if online
    local players = _API.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.identifier == identifier then
            TriggerClientEvent("t1ger_moneywash:client:businessPurchased", player.source, id, businessType, locationId)
            break
        end
    end

    if Config.Debug then
        print(("[MoneyWash] Admin added %s #%d to %s"):format(businessType, locationId, identifier))
    end

    return true, "success"
end
exports("AddBusiness", AdminAddBusiness)

--- Admin: forcibly removes a business, returning location to market
--- @param businessType string
--- @param locationId number
--- @return boolean success, string reason
function AdminRemoveBusiness(businessType, locationId)
    local business = GetBusinessByLocation(businessType, locationId)
    if not business then return false, "not_owned" end

    MySQL.query("DELETE FROM moneywash_businesses WHERE id = ?", {business.id})
    MySQL.query("DELETE FROM moneywash_receipts WHERE business_id = ?", {business.id})

    -- Notify owner if online
    local players = _API.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.identifier == business.identifier then
            TriggerClientEvent("t1ger_moneywash:client:businessSeized", player.source, business.id)
            break
        end
    end

    RemoveFromStore(business.id)

    if Config.Debug then
        print(("[MoneyWash] Admin removed %s #%d"):format(businessType, locationId))
    end

    return true, "success"
end
exports("RemoveBusiness", AdminRemoveBusiness)

--- Admin commands
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
        or  ("Failed to add business: %s"):format(reason)

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
        or  ("Failed to remove business: %s"):format(reason)

    if isConsole then print(msg) else _API.SendNotification(src, msg, success and "success" or "error") end
end, true)

--- Callback: available unowned locations for a given business type
lib.callback.register("t1ger_moneywash:server:getAvailableLocations", function(source, businessType)
    local locations = require("shared/business_locations")
    if not locations[businessType] then return {} end

    local tier = GetTierByType(businessType)
    if not tier then return {} end

    local available = {}
    for locationId, locationData in pairs(locations[businessType]) do
        if not IsLocationOwned(businessType, locationId) then
            available[#available + 1] = {
                id     = locationId,
                coords = locationData.coords,
                brand  = locationData.brand,
                price  = locationData.price or tier.price,
            }
        end
    end

    return available
end)

--- Callback: purchase a business
lib.callback.register("t1ger_moneywash:server:buyBusiness", function(source, businessType, locationId)
    local success, reason = BuyBusiness(source, businessType, locationId)
    return {success = success, reason = reason}
end)

--- Callback: transfer a business
lib.callback.register("t1ger_moneywash:server:transferBusiness", function(source, targetIdentifier, businessId)
    local success, reason = TransferBusiness(source, targetIdentifier, businessId)
    return {success = success, reason = reason}
end)

--- Callback: abandon a business
lib.callback.register("t1ger_moneywash:server:abandonBusiness", function(source, businessId)
    local success, reason = AbandonBusiness(source, businessId)
    return {success = success, reason = reason}
end)

--- Callback: get player's own businesses (called on player load)
lib.callback.register("t1ger_moneywash:server:getPlayerBusinesses", function(source)
    local identifier = _API.Player.GetIdentifier(source)
    return GetPlayerBusinesses(identifier)
end)