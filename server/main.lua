--- ============================================================================
--- Server Main
--- Wiring only: player lifecycle, master tick, autosave and shutdown handlers.
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
    BroadcastBusinessLocations(src)
    TriggerClientEvent("t1ger_moneywash:client:bankDepositSync", src, GetBankDepositPublic(identifier))

    -- Tell the owner if their unfinished deposit was returned to the Safe by a restart
    local refunded = ConsumeStartupRefund(identifier)
    if refunded then
        _API.SendNotification(src, string.format(locale("notification.deposit_refunded"), Config.Currency .. refunded), "inform")
    end

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

--- Display names for a list of player server ids (the nearby players shown when transferring).
lib.callback.register("t1ger_moneywash:server:getPlayerNames", function(_, serverIds)
    local names = {}

    if type(serverIds) ~= "table" then return names end

    for _, targetSrc in ipairs(serverIds) do
        if type(targetSrc) == "number" then
            names[targetSrc] = (Config.UseCharacterNames and _API.Player.GetCharacterName(targetSrc))
                or GetPlayerName(targetSrc)
                or ("Player %d"):format(targetSrc)
        end
    end

    return names
end)

--- -------------------------------------------------------------------------
--- MASTER TICK — fires every real minute
--- -------------------------------------------------------------------------
CreateThread(function()
    if not LoadBusinesses() then return end

    local loaded, err = pcall(LoadBankDeposits)
    if not loaded then
        print(("[MoneyWash] Bank deposit startup recovery failed: %s"):format(tostring(err)))
    end

    while true do
        Wait(60000)

        CheckGlobalCycle()
        ProcessBankDeposits()

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
