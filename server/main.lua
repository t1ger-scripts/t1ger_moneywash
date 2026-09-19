--- ============================================================================
--- Server Main
--- Player lifecycle, global cycle tick, suspicion decay, deposit processing,
--- raid queue processing, autosave and shutdown handlers.
--- ============================================================================

--- Global cycle tracking - starts on server start, never persisted to DB
local CycleStartedAt = os.time()
local CurrentCycle   = 1 -- increments each time a cycle completes

--- -------------------------------------------------------------------------
--- PLAYER LIFECYCLE
--- -------------------------------------------------------------------------

RegisterNetEvent("t1ger_moneywash:server:playerLoaded", function()
    local src = source

    -- Load reputation
    LoadReputation(src)

    -- Load any pending bank deposit
    LoadPendingDeposit(src)

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
--- GLOBAL CYCLE TICK
--- Checks every real minute if the cycle has completed
--- Resets totalLaundered for ALL businesses simultaneously on cycle end
--- -------------------------------------------------------------------------
local function CheckGlobalCycle()
    local cycleDurationSeconds = Config.Business.CycleDuration * 60
    local now = os.time()

    if (now - CycleStartedAt) >= cycleDurationSeconds then
        CycleStartedAt = now
        CurrentCycle   = CurrentCycle + 1

        for id in pairs(GetAllBusinesses()) do
            UpdateBusiness(id, "totalLaundered", 0)
        end

        if Config.Debug then
            print(("[MoneyWash] Cycle %d started — totalLaundered reset for all businesses"):format(CurrentCycle))
        end
    end
end

--- -------------------------------------------------------------------------
--- SUSPICION DECAY TICK
--- Runs per business every real minute
--- Only decays after configured inactivity period with no launder actions
--- -------------------------------------------------------------------------
local function ApplySuspicionDecay(business)
    if business.suspicion <= 0 then return end

    local now = os.time()
    local cycleDurationSeconds = Config.Business.CycleDuration * 60
    local inactivitySeconds = Config.Suspicion.Decay.InactivityPeriod * cycleDurationSeconds
    local timeSinceLastLaunder = now - business.lastLaunderedAt

    if timeSinceLastLaunder < inactivitySeconds then return end

    -- Determine if owner is online
    local isOnline = false
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == business.identifier then
            isOnline = true
            break
        end
    end

    local decayPerCycle = isOnline
        and Config.Suspicion.Decay.OnlinePointsPerCycle
        or  Config.Suspicion.Decay.OfflinePointsPerCycle

    -- Convert per-cycle to per-tick (tick = 1 real minute, cycle = CycleDuration minutes)
    local decayPerTick = decayPerCycle / Config.Business.CycleDuration
    local newSuspicion = math.max(0, business.suspicion - decayPerTick)

    UpdateBusiness(business.id, "suspicion", newSuspicion)
end

--- -------------------------------------------------------------------------
--- CLOSURE CHECK
--- Reopens temporarily closed businesses when the closure period ends
--- -------------------------------------------------------------------------
local function CheckClosure(business)
    if not business.isClosed then return end
    if not business.closedUntil then return end
    if os.time() < business.closedUntil then return end

    UpdateBusinessFields(business.id, {isClosed = false, closedUntil = nil})
    MySQL.update("UPDATE moneywash_businesses SET is_closed = 0, closed_until = NULL WHERE id = ?", {business.id})

    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == business.identifier then
            _API.SendNotification(player.source, locale("notification.business_reopened"), "inform")
            break
        end
    end
end

--- -------------------------------------------------------------------------
--- DEPOSIT PROCESSING TICK
--- Checks every minute for deposits that have cleared their processing timer
--- -------------------------------------------------------------------------
local function ProcessDeposits()
    local now = os.time()
    -- Query DB for all deposits that have cleared
    local cleared = MySQL.query.await(
        "SELECT identifier FROM moneywash_deposits WHERE clears_at <= ?", {now})

    if not cleared then return end

    for _, row in ipairs(cleared) do
        CompleteBankDeposit(row.identifier)
    end
end

--- -------------------------------------------------------------------------
--- RAID QUEUE TICK
--- Checks every minute for queued raids that should now fire
--- -------------------------------------------------------------------------
local function ProcessRaidQueue()
    local now = os.time()
    for businessId, raidsAt in pairs(GetQueuedRaids()) do
        if now >= raidsAt then
            ExecuteRaid(businessId, nil)
        end
    end
end

--- -------------------------------------------------------------------------
--- MASTER TICK — fires every real minute
--- -------------------------------------------------------------------------
CreateThread(function()
    -- Load all businesses on startup
    local results = MySQL.query.await("SELECT * FROM moneywash_businesses")
    if results then
        for _, row in ipairs(results) do
            AddToStore(row.id, row)
        end
        if Config.Debug then
            print(("[MoneyWash] Loaded %d businesses on startup"):format(#results))
        end
    end

    while true do
        Wait(60000)

        CheckGlobalCycle()
        ProcessDeposits()
        ProcessRaidQueue()

        for _, business in pairs(GetAllBusinesses()) do
            ApplySuspicionDecay(business)
            CheckClosure(business)
        end
    end
end)

--- -------------------------------------------------------------------------
--- SAVE FUNCTIONS
--- -------------------------------------------------------------------------

function SaveBusiness(id)
    local b = GetBusiness(id)
    if not b then return end

    MySQL.update(
        "UPDATE moneywash_businesses SET " ..
        "stock = ?, safe_covered = ?, safe_exposed = ?, suspicion = ?, " ..
        "total_laundered = ?, last_laundered_at = ?, is_closed = ?, closed_until = ? " ..
        "WHERE id = ?",
        {
            b.stock, b.safeCovered, b.safeExposed, b.suspicion,
            b.totalLaundered, b.lastLaunderedAt,
            b.isClosed and 1 or 0, b.closedUntil,
            b.id
        }
    )
end

local function SaveAllBusinesses()
    for id in pairs(GetAllBusinesses()) do
        SaveBusiness(id)
    end
    if Config.Debug then
        print("[MoneyWash] All businesses saved")
    end
end

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
                local msg = string.format(Config.Reputation.CommandSuggestion or "Usage: /%s <playerId> <amount>", cfg.name)
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
                or  ("[MoneyWash] Failed to %s rep for player %d"):format(action, target)
            if isConsole then print(msg) else _API.SendNotification(src, msg, success and "success" or "error") end
        end, true)
    end
end
