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

--- Constant suspicion decay, run per business every real minute. It does not depend on recent
--- laundering. The gain formula vs. the decay rate defines the "safe laundering rate" per cycle.
---@param business table
local function applySuspicionDecay(business)
    if business.suspicion <= 0 then return end

    local isOnline = GetOnlineSourceByIdentifier(business.identifier) ~= nil
    local decay = Config.Suspicion.Decay
    local decayPerCycle = isOnline and decay.OnlinePointsPerCycle or decay.OfflinePointsPerCycle

    -- Convert per-cycle to per-tick (tick = 1 real minute, cycle = CycleDuration minutes)
    local decayPerTick = decayPerCycle / Config.Business.CycleDuration

    UpdateBusiness(business.id, "suspicion", math.max(0, business.suspicion - decayPerTick))
end

--- -------------------------------------------------------------------------
--- MASTER TICK — fires every real minute
--- -------------------------------------------------------------------------
CreateThread(function()
    if not LoadBusinesses() then return end

    local loaded, err = pcall(LoadCashBags)
    if not loaded then
        print(("[MoneyWash] Loading the cash bags failed, withdrawals and deposits stay off: %s"):format(tostring(err)))
    end

    while true do
        Wait(60000)

        CheckGlobalCycle()
        ProcessCashBags()

        for _, business in pairs(GetAllBusinesses()) do
            applySuspicionDecay(business)
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