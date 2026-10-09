--- ============================================================================
--- Server Main
--- Wiring only: player lifecycle, master tick, autosave, shutdown handlers and reputation commands.
--- ============================================================================

--- -------------------------------------------------------------------------
--- PLAYER LIFECYCLE
--- -------------------------------------------------------------------------
RegisterNetEvent("t1ger_moneywash:server:playerLoaded", function()
    local src = source

    -- Load reputation
    LoadReputation(src)

    -- Sync owned businesses to client
    local identifier = _API.Player.GetIdentifier(src)
    local businesses = GetPlayerBusinesses(identifier)
    TriggerClientEvent("t1ger_moneywash:client:syncBusinesses", src, businesses)

    if Config.Debug then
        print(("[MoneyWash] Player %d loaded | %d businesses synced"):format(src, #businesses))
    end
end)

AddEventHandler("playerDropped", function()
    local src = source

    -- Save and unload reputation
    SavePlayerReputation(src)
    UnloadReputation(src)

    -- Refund any active stock mission
    OnPlayerDroppedStockCleanup(src)
end)

--- -------------------------------------------------------------------------
--- MASTER TICK — fires every real minute
--- -------------------------------------------------------------------------
CreateThread(function()
    if not LoadBusinesses() then return end

    while true do
        Wait(60000)

        CheckGlobalCycle()

        for _, business in pairs(GetAllBusinesses()) do
            ApplySuspicionDecay(business)
        end
    end
end)

--- -------------------------------------------------------------------------
--- AUTOSAVE
--- -------------------------------------------------------------------------
lib.cron.new(("*/%d * * * *"):format(Config.Reputation.AutosaveInterval), function()
    SaveAllBusinesses()
    SaveAllReputation()
end)

--- -------------------------------------------------------------------------
--- SHUTDOWN HANDLERS
--- -------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SaveAllBusinesses()
    SaveAllReputation()
end)

AddEventHandler("txAdmin:events:scheduledRestart", function(data)
    if data.secondsRemaining ~= 60 then return end
    SaveAllBusinesses()
    SaveAllReputation()
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
    SaveAllBusinesses()
    SaveAllReputation()
end)

--- -------------------------------------------------------------------------
--- REPUTATION COMMANDS
--- -------------------------------------------------------------------------
for action, cfg in pairs(Config.Reputation.Commands or {}) do
    if type(cfg.name) == "string" then
        RegisterCommand(cfg.name, function(src, args)
            local isConsole = (src == 0)
            if not isConsole and not cfg.enable then return end
            if not isConsole and not _API.Player.IsAdmin(src) then
                _API.SendNotification(src, locale("notification.no_permission"), "error")
                return
            end

            local target = tonumber(args[1])
            local amount = tonumber(args[2])

            if not target or not amount then
                local msg = string.format(Config.Reputation.CommandSuggestion or "Usage: /%s <playerId> <amount>",
                    cfg.name)
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
                and ("[MoneyWash] %s %d rep points for player %d"):format(action, amount, target)
                or ("[MoneyWash] Failed to %s rep for player %d"):format(action, target)
            if isConsole then print(msg) else _API.SendNotification(src, msg, success and "success" or "error") end
        end, true)
    end
end
