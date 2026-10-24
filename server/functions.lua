--- Returns the server id of an online player by identifier, or nil if offline.
--- Single framework lookup - never scans the player list.
--- @param identifier string
--- @return integer|nil source
function GetOnlineSourceByIdentifier(identifier)
    if type(identifier) ~= "string" then return nil end

    local ok, player = pcall(_API.Player.GetFromIdentifier, identifier)
    if not ok or not player then return nil end

    local src = player.source or (player.PlayerData and player.PlayerData.source) -- esx / qb, qbox
    if src and src > 0 then return src end

    return nil
end

--- Returns the sources of online players holding a Config.Police.Jobs job.
--- One framework lookup per player (job only).
--- @param onDutyOnly boolean|nil
--- @return integer[] sources
function GetPoliceSources(onDutyOnly)
    local sources = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local job = src and _API.Player.GetJob(src)

        if job and (not onDutyOnly or job.onDuty) then
            for _, policeJob in ipairs(Config.Police.Jobs) do
                if job.name == policeJob then
                    sources[#sources + 1] = src
                    break
                end
            end
        end
    end

    return sources
end

--- Returns the number of currently on-duty players whose job matches Config.Police.Jobs.
--- @return integer count
function GetOnDutyPoliceCount()
    return #GetPoliceSources(true)
end

--- Checks whether the given player's coordinates are within range of a target vector.
--- @param src number Player source
--- @param target vector3|vector4 Target coordinates
--- @param maxDistance number Maximum allowed distance
--- @return boolean withinRange
function IsPlayerNearCoords(src, target, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    local dist = #(playerCoords - vector3(target.x, target.y, target.z))

    return dist <= (maxDistance or 5.0)
end

--- Runs a hook from server/hooks.lua safely. A broken hook (server-owner code)
--- prints an error but never interrupts the script's own flow.
--- @param name string Global hook function name, e.g. "OnMoneyLaundered"
--- @param ... any Hook arguments
function RunHook(name, ...)
    local hook = _G[name]
    if type(hook) ~= "function" then return end

    local ok, err = pcall(hook, ...)
    if not ok then
        print(("^1[MoneyWash] Hook %s failed: %s^7"):format(name, tostring(err)))
    end
end

--- Returns the tier config for a business type.
---@param businessType string
---@return table|nil
function GetTierByType(businessType)
    for _, tier in pairs(Config.Business.Tiers) do
        if tier.type == businessType then return tier end
    end

    return nil
end

--- Returns the config of one business location.
---@param businessType string
---@param locationId number
---@return table|nil
function GetLocationConfig(businessType, locationId)
    local locations = Config.Business.Locations[businessType]

    return locations and locations[locationId] or nil
end

--- Readable business name for players, e.g. "Gas Station (Ron)".
---@param business table
---@return string
function GetBusinessLabel(business)
    local tier = GetTierByType(business.type)
    local label = tier and tier.label or business.type

    local location = GetLocationConfig(business.type, business.locationId)
    if location and location.brand then
        label = ("%s (%s)"):format(label, location.brand)
    end

    return label
end

--- Answers a command in the console, or as a notification to the player who ran it.
---@param src number 0 = console
---@param message string
---@param kind string|nil "success", "error" or "inform"
function ReplyToCommand(src, message, kind)
    if src == 0 then
        print(message)
    else
        _API.SendNotification(src, message, kind or "inform")
    end
end