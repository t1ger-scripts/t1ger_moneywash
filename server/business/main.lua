--- Returns display names for a list of player server IDs — character
lib.callback.register("t1ger_moneywash:server:getPlayerNames", function(src, serverIds)
    local names = {}

    if type(serverIds) ~= "table" then
        return names
    end

    for _, targetSrc in ipairs(serverIds) do
        names[targetSrc] = (Config.UseCharacterNames and _API.Player.GetCharacterName(targetSrc))
            or GetPlayerName(targetSrc)
            or ("Player %d"):format(targetSrc)
    end

    return names
end)

--- Transfer a business to another player
lib.callback.register("t1ger_moneywash:server:transferBusiness", function(source, targetId, businessId)
    local success, reason = TransferBusiness(source, targetId, businessId)
    return {success = success, reason = reason}
end)

--- Abandon a business
lib.callback.register("t1ger_moneywash:server:abandonBusiness", function(source, businessId)
    local success, reason = AbandonBusiness(source, businessId)
    return { success = success, reason = reason }
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
        unitPrice       = GetUnitPrice(business.type),
        minOrder        = GetMinOrder(business.type),
        maxOrder        = GetMaxOrder(business.type),
    }
end)

lib.callback.register("t1ger_moneywash:server:getDirtyMoney", function(source)
    return _API.Player.GetDirtyMoney(source)
end)

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