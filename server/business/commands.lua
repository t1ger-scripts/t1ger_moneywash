--- ============================================================================
--- Business Commands
--- Admin and testing commands.
--- ============================================================================

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

RegisterCommand("moneywash:forcecycle", function(src, args)
    local isConsole = (src == 0)
    if not isConsole and not _API.Player.IsAdmin(src) then return end

    ForceGlobalCycle()

    local msg = ("Cycle forced — now on cycle %d"):format(GetCurrentCycle())
    if isConsole then print(msg) else _API.SendNotification(src, msg, "success") end
end, true)