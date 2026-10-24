--- Business ownership: buy, transfer, abandon and the admin add/remove.
--- Each action locks the owner, business and location it touches, so two actions can't change the same business at once.

local locks = {} -- lock keys currently held

--- Takes every key, or none of them if any is already held.
--- Cash operations and raids use this too, so they can't run during a transfer or removal.
---@param keys string[]
---@return boolean acquired
function AcquireCashOperationLocks(keys)
    for _, key in ipairs(keys) do
        if locks[key] then return false end
    end

    for _, key in ipairs(keys) do
        locks[key] = true
    end

    return true
end

--- Releases keys taken with AcquireCashOperationLocks.
---@param keys string[]
function ReleaseCashOperationLocks(keys)
    for _, key in ipairs(keys) do
        locks[key] = nil
    end
end

local function ownerKey(identifier) return "owner:" .. identifier end
local function businessKey(businessId) return ("business:%d"):format(businessId) end
local function locationKey(businessType, locationId) return ("location:%s:%d"):format(businessType, locationId) end

--- Runs fn while holding the locks and always releases them. fn returns true, or false and a reason.
---@param keys string[]
---@param fn fun(): boolean, string|nil
---@return boolean success
---@return string|nil reason
local function withLocks(keys, fn)
    if not AcquireCashOperationLocks(keys) then return false, "operation_in_progress" end

    local ran, success, reason = pcall(fn)
    ReleaseCashOperationLocks(keys)

    if not ran then
        print(("^1[MoneyWash] Ownership action failed: %s^7"):format(tostring(success)))
        return false, "unknown"
    end

    return success, reason
end

--- Converts a value to a whole number, or nil.
---@param value any
---@return integer|nil
local function toInteger(value)
    value = tonumber(value)

    return value and math.tointeger(value) or nil
end

--- Checks a business type and location id against the config.
---@param businessType any
---@param locationId any
---@return { type: string, locationId: number, tier: table, location: table }|nil place
---@return string|nil reason
local function resolvePlace(businessType, locationId)
    if type(businessType) ~= "string" then return nil, "invalid_type" end

    locationId = tonumber(locationId)
    if not locationId then return nil, "invalid_location" end

    local tier = GetTierByType(businessType)
    if not tier then return nil, "invalid_type" end

    local location = GetLocationConfig(businessType, locationId)
    if not location or not location.coords then return nil, "invalid_location" end

    return { type = businessType, locationId = locationId, tier = tier, location = location }
end

--- Returns the business if the player owns it.
---@param identifier string
---@param businessId number
---@return table|nil business
---@return string|nil reason
local function getOwnedBusiness(identifier, businessId)
    local business = GetBusiness(businessId)

    if not business then return nil, "not_found" end
    if business.identifier ~= identifier then return nil, "not_owner" end

    return business
end

--- Returns why a business can't be moved or removed right now, or nil.
---@param businessId number
---@param checkStock? boolean Also block while a stock order is running (not for an admin removal, which ends it)
---@return string|nil reason
local function getBusyReason(businessId, checkStock)
    if checkStock and HasActiveStockOrder(businessId) then return "active_stock_mission" end
    if IsBusinessRaided(businessId) then return "raid_in_progress" end
    if IsBusinessInReview(businessId) then return "review_in_progress" end

    return nil
end

--- Checks the player has enough reputation for a tier.
---@param src number
---@param tier table
---@return boolean
local function meetsReputation(src, tier)
    if not Config.Reputation.Enable then return true end

    local reputation = GetPlayerReputation(src)

    return reputation ~= nil and reputation:GetPoints() >= tier.requiredPoints
end

--- Inserts a new business and adds it to the store.
---@param identifier string
---@param place table From resolvePlace
---@return number|nil id
---@return any error
local function insertBusiness(identifier, place)
    local now = os.time()
    local coords = place.location.coords

    local ok, id = pcall(
        MySQL.insert.await,
        "INSERT INTO moneywash_businesses " ..
        "(identifier, business_type, location_id, location_x, location_y, location_z, " ..
        "stock, safe_covered, safe_exposed, suspicion, total_laundered, purchased_at) " ..
        "VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, ?)",
        { identifier, place.type, place.locationId, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, now }
    )

    if not ok or not id then return nil, id end

    AddToStore(id, {
        identifier    = identifier,
        business_type = place.type,
        location_id   = place.locationId,
        purchased_at  = now,
    })

    return id
end

--- Deletes a business and its receipts from the database. The caller removes it from the store.
---@param businessId number
---@param identifier string
---@return boolean success
---@return any error
local function deleteBusiness(businessId, identifier)
    local ran, success = pcall(MySQL.transaction.await, {
        { query = "DELETE FROM moneywash_receipts WHERE business_id = ?", values = { businessId } },
        { query = "DELETE FROM moneywash_businesses WHERE id = ? AND identifier = ?", values = { businessId, identifier } },
    })

    return ran and success == true, success
end

--- Returns whether two players are close enough to transfer a business.
---@param first number
---@param second number
---@return boolean
local function arePlayersNear(first, second)
    local firstPed, secondPed = GetPlayerPed(first), GetPlayerPed(second)

    if not firstPed or firstPed == 0 or not secondPed or secondPed == 0 then return false end

    return #(GetEntityCoords(firstPed) - GetEntityCoords(secondPed)) <= (Config.HandlerNPC.TransferDistance or 10.0)
end

--- Buys a business: takes the price from the player's bank and gives them the location.
---@param src number
---@param businessType string
---@param locationId number
---@return boolean success
---@return string reason
function BuyBusiness(src, businessType, locationId)
    if not IsBusinessStoreReady() then return false, "business_store_not_ready" end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    local place, placeReason = resolvePlace(businessType, locationId)
    if not place then return false, placeReason end

    local price, id

    local success, reason = withLocks({ ownerKey(identifier), locationKey(place.type, place.locationId) }, function()
        if IsLocationOwned(place.type, place.locationId) then return false, "already_owned" end
        if PlayerOwnsBusiness(identifier) then return false, "already_owns_business" end
        if not meetsReputation(src, place.tier) then return false, "insufficient_reputation" end

        price = tonumber(place.location.price)
        if not price or price <= 0 then return false, "invalid_price" end

        if _API.Player.GetMoney(src, "bank") < price then return false, "insufficient_funds" end

        _API.Player.RemoveMoney(src, price, "bank")

        local newId, err = insertBusiness(identifier, place)
        if not newId then
            _API.Player.AddMoney(src, price, "bank") -- Give the money back, e.g. after a duplicate-key race

            if Config.Debug then
                print(("[MoneyWash] Purchase database error: %s"):format(tostring(err)))
            end

            return false, "database_error"
        end

        id = newId

        return true
    end)

    if not success then return false, reason end

    if Config.Reputation.Enable and Config.Reputation.Rewards.businessPurchase.enable then
        AwardReputationPoints(src, identifier, Config.Reputation.Rewards.businessPurchase.points)
    end

    TriggerClientEvent("t1ger_moneywash:client:businessPurchased", src, id, place.type, place.locationId)
    BroadcastBusinessLocations()

    RunHook("OnBusinessPurchased", identifier, place.type, place.locationId, price)

    if Config.Debug then
        print(("[MoneyWash] %s purchased %s #%d for $%d"):format(identifier, place.type, place.locationId, price))
    end

    return true, "success"
end

--- Transfers a business, with all its state, to another nearby online player.
---@param src number Current owner
---@param targetSrc number New owner
---@param businessId number
---@return boolean success
---@return string reason
function TransferBusiness(src, targetSrc, businessId)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return false, "target_not_online" end

    businessId = toInteger(businessId)
    if not businessId then return false, "not_found" end

    if targetSrc == src then return false, "self_transfer" end

    local targetIdentifier = _API.Player.GetIdentifier(targetSrc)
    if not targetIdentifier then return false, "target_not_online" end

    local business

    local success, reason = withLocks({ businessKey(businessId), ownerKey(identifier), ownerKey(targetIdentifier) }, function()
        local owned, ownedReason = getOwnedBusiness(identifier, businessId)
        if not owned then return false, ownedReason end

        business = owned

        if not arePlayersNear(src, targetSrc) then return false, "target_too_far" end

        local busy = getBusyReason(businessId, true)
        if busy then return false, busy end

        if PlayerOwnsBusiness(targetIdentifier) then return false, "target_owns_business" end

        local tier = GetTierByType(business.type)
        if not tier then return false, "invalid_type" end

        if not meetsReputation(targetSrc, tier) then return false, "target_insufficient_reputation" end

        local ran, affected = pcall(
            MySQL.update.await,
            "UPDATE moneywash_businesses SET identifier = ? WHERE id = ? AND identifier = ?",
            { targetIdentifier, businessId, identifier }
        )

        if not ran or affected ~= 1 then
            if Config.Debug then
                print(("[MoneyWash] Transfer database error: %s"):format(tostring(affected)))
            end

            return false, "database_error"
        end

        UpdateBusiness(businessId, "identifier", targetIdentifier)

        return true
    end)

    if not success then return false, reason end

    TriggerClientEvent("t1ger_moneywash:client:businessTransferred", src, businessId)
    TriggerClientEvent("t1ger_moneywash:client:businessReceived", targetSrc, businessId, business.type, business.locationId)

    RunHook("OnBusinessTransferred", identifier, targetIdentifier, businessId, business.type, business.locationId)
    RefreshPortalViewers()

    if Config.Debug then
        print(("[MoneyWash] Business %d transferred: %s -> %s"):format(businessId, identifier, targetIdentifier))
    end

    return true, "success"
end

--- Abandons a business with no refund. Its safe, stock and progress are lost.
---@param src number
---@param businessId number
---@return boolean success
---@return string reason
function AbandonBusiness(src, businessId)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return false, "invalid_player" end

    businessId = toInteger(businessId)
    if not businessId then return false, "not_found" end

    local business, ownedReason = getOwnedBusiness(identifier, businessId)
    if not business then return false, ownedReason end

    local keys = {
        businessKey(businessId),
        ownerKey(identifier),
        locationKey(business.type, business.locationId),
    }

    local success, reason = withLocks(keys, function()
        local owned, lockedReason = getOwnedBusiness(identifier, businessId)
        if not owned then return false, lockedReason end

        local busy = getBusyReason(businessId, true)
        if busy then return false, busy end

        local deleted, err = deleteBusiness(businessId, identifier)
        if not deleted then
            if Config.Debug then
                print(("[MoneyWash] Abandon database error: %s"):format(tostring(err)))
            end

            return false, "database_error"
        end

        RemoveFromStore(businessId)

        return true
    end)

    if not success then return false, reason end

    TriggerClientEvent("t1ger_moneywash:client:businessAbandoned", src, businessId)
    BroadcastBusinessLocations()
    RefreshPortalViewers()

    RunHook("OnBusinessAbandoned", identifier, businessId, business.type, business.locationId)

    if Config.Debug then
        print(("[MoneyWash] Business %d abandoned by %s"):format(businessId, identifier))
    end

    return true, "success"
end

--- Admin: gives a player a business. Skips the reputation and price requirements.
---@param identifier string
---@param businessType string
---@param locationId number
---@return boolean success
---@return string reason
function AdminAddBusiness(identifier, businessType, locationId)
    if not IsBusinessStoreReady() then return false, "business_store_not_ready" end

    if type(identifier) ~= "string" or identifier == "" then return false, "invalid_player" end

    local place, placeReason = resolvePlace(businessType, locationId)
    if not place then return false, placeReason end

    local id

    local success, reason = withLocks({ ownerKey(identifier), locationKey(place.type, place.locationId) }, function()
        if IsLocationOwned(place.type, place.locationId) then return false, "already_owned" end
        if PlayerOwnsBusiness(identifier) then return false, "already_owns_business" end

        local newId, err = insertBusiness(identifier, place)
        if not newId then
            if Config.Debug then
                print(("[MoneyWash] Admin add database error: %s"):format(tostring(err)))
            end

            return false, "database_error"
        end

        id = newId

        return true
    end)

    if not success then return false, reason end

    local ownerSrc = GetOnlineSourceByIdentifier(identifier)
    if ownerSrc then
        TriggerClientEvent("t1ger_moneywash:client:businessPurchased", ownerSrc, id, place.type, place.locationId)
    end

    BroadcastBusinessLocations()
    RefreshPortalViewers()

    if Config.Debug then
        print(("[MoneyWash] Admin added %s #%d to %s"):format(place.type, place.locationId, identifier))
    end

    return true, "success"
end

exports("AddBusiness", AdminAddBusiness)

--- Admin: removes a business and puts its location back on the market.
--- An active stock order for it is cancelled and refunded.
---@param businessType string
---@param locationId number
---@return boolean success
---@return string reason
function AdminRemoveBusiness(businessType, locationId)
    if type(businessType) ~= "string" then return false, "invalid_type" end

    locationId = tonumber(locationId)
    if not locationId then return false, "invalid_location" end

    local business = GetBusinessByLocation(businessType, locationId)
    if not business then return false, "not_owned" end

    local businessId, identifier = business.id, business.identifier

    local keys = {
        businessKey(businessId),
        ownerKey(identifier),
        locationKey(businessType, business.locationId),
    }

    local success, reason = withLocks(keys, function()
        if GetBusinessByLocation(businessType, locationId) ~= business then return false, "not_owned" end

        local busy = getBusyReason(businessId)
        if busy then return false, busy end

        local deleted, err = deleteBusiness(businessId, identifier)
        if not deleted then
            if Config.Debug then
                print(("[MoneyWash] Admin remove database error: %s"):format(tostring(err)))
            end

            return false, "database_error"
        end

        EndStockOrderForBusiness(businessId)
        EndReviewForBusiness(businessId)

        RemoveFromStore(businessId)

        return true
    end)

    if not success then return false, reason end

    local ownerSrc = GetOnlineSourceByIdentifier(identifier)
    if ownerSrc then
        TriggerClientEvent("t1ger_moneywash:client:businessRemoved", ownerSrc, businessId)
    end

    BroadcastBusinessLocations()
    RefreshPortalViewers()

    if Config.Debug then
        print(("[MoneyWash] Admin removed %s #%d"):format(businessType, locationId))
    end

    return true, "success"
end

exports("RemoveBusiness", AdminRemoveBusiness)

--- Transfers the player's business to another player.
lib.callback.register("t1ger_moneywash:server:transferBusiness", function(source, targetId, businessId)
    local success, reason = TransferBusiness(source, targetId, businessId)

    return { success = success, reason = reason }
end)

--- Abandons the player's business.
lib.callback.register("t1ger_moneywash:server:abandonBusiness", function(source, businessId)
    local success, reason = AbandonBusiness(source, businessId)

    return { success = success, reason = reason }
end)

--- Admin command: /moneywash:addbusiness <playerId> <type> <locationId> (online players only)
RegisterCommand("moneywash:addbusiness", function(src, args)
    if src ~= 0 and not _API.Player.IsAdmin(src) then return end

    local target, businessType, locationId = tonumber(args[1]), args[2], tonumber(args[3])

    if not target or not businessType or not locationId then
        ReplyToCommand(src, "Usage: /moneywash:addbusiness <playerId> <type> <locationId>", "error")
        return
    end

    local identifier = _API.Player.GetIdentifier(target)

    if not identifier then
        ReplyToCommand(src, ("Player %d is not online."):format(target), "error")
        return
    end

    local success, reason = AdminAddBusiness(identifier, businessType, locationId)

    ReplyToCommand(
        src,
        success and ("Business added: %s #%d → player %d"):format(businessType, locationId, target)
            or ("Failed: %s"):format(reason),
        success and "success" or "error"
    )
end, true)

--- Admin command: /moneywash:removebusiness <playerId> (online players only)
RegisterCommand("moneywash:removebusiness", function(src, args)
    if src ~= 0 and not _API.Player.IsAdmin(src) then return end

    local target = tonumber(args[1])

    if not target then
        ReplyToCommand(src, "Usage: /moneywash:removebusiness <playerId>", "error")
        return
    end

    local identifier = _API.Player.GetIdentifier(target)

    if not identifier then
        ReplyToCommand(src, ("Player %d is not online."):format(target), "error")
        return
    end

    local business = GetPlayerBusinesses(identifier)[1]

    if not business then
        ReplyToCommand(src, ("Player %d does not own a business."):format(target), "error")
        return
    end

    local success, reason = AdminRemoveBusiness(business.type, business.locationId)

    ReplyToCommand(src,
        success and ("Business removed: %s #%d from player %d"):format(business.type, business.locationId, target)
            or ("Failed: %s"):format(reason),
        success and "success" or "error"
    )
end, true)