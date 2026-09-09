--- Event for player loaded
RegisterNetEvent("t1ger_moneywash:server:playerLoaded", function()
    local src = source
    local player = _API.Player.GetFromId(src)

    -- Load reputation
    LoadReputation(src)

    -- Sync player's owned businesses to client
    local identifier = _API.Player.GetIdentifier(src)
    local businesses = GetPlayerBusinesses(identifier)
    TriggerClientEvent("t1ger_moneywash:client:syncBusinesses", src, businesses)

    if Config.Debug then
        print(("[MoneyWash] Player %d loaded — %d businesses synced"):format(src, #businesses))
    end
end)

--- Reputation admin commands
for action, cfg in pairs(Config.Reputation.Commands or {}) do
    if type(cfg.name) == "string" then
        RegisterCommand(cfg.name, function(src, args)
            local isConsole = (src == 0)
            if not isConsole and not cfg.enable then return end
            if not isConsole and not _API.Player.IsAdmin(src) then
                return _API.SendNotification(src, locale("notification.no_permission"), "error")
            end

            local target = tonumber(args[1])
            local amount = tonumber(args[2])

            if not target or not amount then
                local msg = string.format(Config.Reputation.CommandSuggestion, cfg.name)
                if isConsole then print(msg) else _API.SendNotification(src, msg, "inform") end
                return
            end

            local success = false
            if action == "set" then
                success = SetReputationPoints(target, amount)
            elseif action == "add" then
                success = AddReputationPoints(target, amount)
            elseif action == "remove" then
                success = RemoveReputationPoints(target, amount)
            end

            local msg = success
                and ("[MoneyWash] %s %d reputation points for player %d"):format(action, amount, target)
                or  ("[MoneyWash] Failed to %s reputation for player %d"):format(action, target)

            if isConsole then print(msg) else _API.SendNotification(src, msg, success and "success" or "error") end
        end, true)
    end
end

--- Save player data on disconnect
AddEventHandler("playerDropped", function()
    local src = source
    SavePlayerReputation(src)
    -- Businesses are saved by the autosave tick and on shutdown
    -- No per-player save needed since businesses persist independently
end)