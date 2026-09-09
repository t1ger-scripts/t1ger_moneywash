--- ============================================================
--- Business Manager
--- Handles lifecycle: loading from DB, saving to DB,
--- global cycle resets, suspicion decay ticks and autosave.
--- Reads and writes state exclusively through store.lua functions.
--- ============================================================

--- Global cycle start timestamp - set once on server start, never persisted to DB
--- All businesses share one cycle. totalLaundered resets simultaneously for all.
local CycleStartedAt = os.time()

--- Loads all owned businesses from the database into memory on server start
function LoadAllBusinesses()
    local results = MySQL.query.await("SELECT * FROM moneywash_businesses")
    if not results then return end

    for _, row in ipairs(results) do
        AddToStore(row.id, row)
    end

    if Config.Debug then
        print(("[MoneyWash] Loaded %d businesses into memory"):format(#results))
    end
end

--- Saves a single business's current in-memory state to the database
--- @param id number
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

--- Saves all businesses currently in memory to the database
function SaveAllBusinesses()
    for id in pairs(GetAllBusinesses()) do
        SaveBusiness(id)
    end
    if Config.Debug then
        print("[MoneyWash] All businesses saved to database")
    end
end

--- Checks whether the global revenue cycle has completed and resets all businesses if so
--- One cycle = Config.Business.CycleDuration real minutes
--- totalLaundered resets to 0 for ALL businesses simultaneously
local function CheckGlobalCycleReset()
    local cycleDurationSeconds = Config.Business.CycleDuration * 60
    local now = os.time()

    if (now - CycleStartedAt) >= cycleDurationSeconds then
        CycleStartedAt = now

        for id in pairs(GetAllBusinesses()) do
            UpdateBusiness(id, "totalLaundered", 0)
        end

        if Config.Debug then
            print("[MoneyWash] New revenue cycle started — totalLaundered reset for all businesses")
        end
    end
end

--- Calculates and applies suspicion decay for a single business based on inactivity
--- Decay only begins after the configured inactivity period has passed with no launder actions
--- Online owners decay faster than offline owners to reward active management
--- @param business table
local function ApplySuspicionDecay(business)
    if business.suspicion <= 0 then return end

    local now = os.time()
    local cycleDurationSeconds = Config.Business.CycleDuration * 60
    local inactivitySeconds = Config.Suspicion.Decay.InactivityPeriod * cycleDurationSeconds
    local timeSinceLastLaunder = now - business.lastLaunderedAt

    -- Not yet inactive long enough for decay to begin
    if timeSinceLastLaunder < inactivitySeconds then return end

    -- Determine if the owner is currently online
    local isOnline = false
    local players = _API.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.identifier == business.identifier then
            isOnline = true
            break
        end
    end

    local decayPerCycle = isOnline
        and Config.Suspicion.Decay.OnlinePointsPerCycle
        or Config.Suspicion.Decay.OfflinePointsPerCycle

    -- Convert per-cycle decay to per-tick (tick fires every real minute)
    local decayPerTick = decayPerCycle / Config.Business.CycleDuration

    local newSuspicion = math.max(0, business.suspicion - decayPerTick)
    UpdateBusiness(business.id, "suspicion", newSuspicion)
end

--- Checks whether a temporarily closed business should reopen
--- @param business table
local function CheckClosure(business)
    if not business.isClosed then return end
    if not business.closedUntil then return end

    if os.time() >= business.closedUntil then
        UpdateBusinessFields(business.id, {
            isClosed    = false,
            closedUntil = nil,
        })

        -- Notify owner if online
        local players = _API.GetOnlinePlayers()
        for _, player in ipairs(players) do
            if player.identifier == business.identifier then
                _API.SendNotification(player.source, locale("notification.business_reopened"), "inform")
                break
            end
        end

        if Config.Debug then
            print(("[MoneyWash] Business %d reopened after temporary closure"):format(business.id))
        end
    end
end

--- Master tick — fires every real minute
--- Handles global cycle reset, suspicion decay and closure checks for all businesses
local function StartMasterTick()
    CreateThread(function()
        while true do
            Wait(60000) -- every real minute

            CheckGlobalCycleReset()

            for _, business in pairs(GetAllBusinesses()) do
                ApplySuspicionDecay(business)
                CheckClosure(business)
            end
        end
    end)
end

--- Autosave cron job
local function StartAutosave()
    local interval = Config.Reputation.AutosaveInterval or 5
    local cronExpr = ("*/%d * * * *"):format(interval)

    lib.cron.new(cronExpr, function()
        SaveAllBusinesses()
        if Config.Debug then
            print("[MoneyWash] Autosave completed")
        end
    end)
end

--- Save all on resource stop
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SaveAllBusinesses()
end)

--- Save all on txAdmin scheduled restart (60 second warning)
AddEventHandler("txAdmin:events:scheduledRestart", function(data)
    if data.secondsRemaining ~= 60 then return end
    SaveAllBusinesses()
end)

--- Save all on txAdmin shutdown
AddEventHandler("txAdmin:events:serverShuttingDown", function()
    SaveAllBusinesses()
end)

--- Initialise on resource start
CreateThread(function()
    LoadAllBusinesses()
    StartMasterTick()
    StartAutosave()

    if Config.Debug then
        print(("[MoneyWash] Business manager initialised — cycle started at %d"):format(CycleStartedAt))
    end
end)