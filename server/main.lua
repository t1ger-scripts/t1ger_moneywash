--- ============================================================================
--- Server Main
--- Player lifecycle, global cycle tick, suspicion decay, 
--- autosave and shutdown handlers.
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

--- Testing/admin: rolls the global cycle over immediately, bypassing the
--- normal CycleDuration wait. Reuses CheckGlobalCycle's own logic by
--- backdating CycleStartedAt instead of duplicating the reset code.
local function ForceGlobalCycle()
    CycleStartedAt = os.time() - (Config.Business.CycleDuration * 60)
    CheckGlobalCycle()
end

RegisterCommand("moneywash:forcecycle", function(src, args)
    local isConsole = (src == 0)
    if not isConsole and not _API.Player.IsAdmin(src) then return end

    ForceGlobalCycle()

    local msg = ("Cycle forced — now on cycle %d"):format(CurrentCycle)
    if isConsole then print(msg) else _API.SendNotification(src, msg, "success") end
end, true)

--- -------------------------------------------------------------------------
--- SUSPICION DECAY TICK
--- Runs per business every real minute. Decay is constant: it does not
--- depend on recent laundering. The gain formula vs. the decay rate defines
--- the "safe laundering rate" per cycle.
--- -------------------------------------------------------------------------
local function ApplySuspicionDecay(business)
    if business.suspicion <= 0 then return end

    local isOnline = false
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        if player.identifier == business.identifier then
            isOnline = true
            break
        end
    end

    local decayPerCycle = isOnline and Config.Suspicion.Decay.OnlinePointsPerCycle or
    Config.Suspicion.Decay.OfflinePointsPerCycle

    -- Convert per-cycle to per-tick (tick = 1 real minute, cycle = CycleDuration minutes)
    local decayPerTick = decayPerCycle / Config.Business.CycleDuration

    UpdateBusiness(business.id, "suspicion", math.max(0, business.suspicion - decayPerTick))
end



local BUSINESS_LOCATION_COORDINATE_TOLERANCE = 0.25

--- Validates that a stored location ID still references the physical
--- location that was recorded when the business was purchased.
---@param row table
---@return boolean valid
---@return string|nil errorMessage
local function validateBusinessLocationSnapshot(row)
    local locationId = tonumber(row.location_id)
    local location = locationId
        and GetLocationConfig(row.business_type, locationId)
        or nil

    if not location or not location.coords then
        return false, (
            "[MoneyWash] Business #%s references missing location %s #%s."
        ):format(
            tostring(row.id),
            tostring(row.business_type),
            tostring(row.location_id)
        )
    end

    local configuredX = tonumber(location.coords.x)
    local configuredY = tonumber(location.coords.y)
    local configuredZ = tonumber(location.coords.z)

    if not configuredX or not configuredY or not configuredZ then
        return false, (
            "[MoneyWash] Configured coordinates are invalid for %s #%s."
        ):format(
            tostring(row.business_type),
            tostring(row.location_id)
        )
    end

    local storedX = tonumber(row.location_x)
    local storedY = tonumber(row.location_y)
    local storedZ = tonumber(row.location_z)

    -- One-time migration for businesses created before coordinate snapshots
    -- were introduced. The current configuration becomes the baseline.
    if not storedX or not storedY or not storedZ then
        local updateSucceeded, updateResult = pcall(
            MySQL.update.await,
            "UPDATE moneywash_businesses " ..
            "SET location_x = ?, location_y = ?, location_z = ? " ..
            "WHERE id = ?",
            {
                configuredX,
                configuredY,
                configuredZ,
                row.id,
            }
        )

        if not updateSucceeded or updateResult == nil then
            return false, (
                "[MoneyWash] Failed to create the location snapshot for business #%s: %s"
            ):format(
                tostring(row.id),
                tostring(updateResult)
            )
        end

        row.location_x = configuredX
        row.location_y = configuredY
        row.location_z = configuredZ

        storedX = configuredX
        storedY = configuredY
        storedZ = configuredZ

        if Config.Debug then
            print((
                "[MoneyWash] Created location snapshot for business #%s (%s #%s)."
            ):format(
                tostring(row.id),
                tostring(row.business_type),
                tostring(row.location_id)
            ))
        end
    end

    local differenceX = configuredX - storedX
    local differenceY = configuredY - storedY
    local differenceZ = configuredZ - storedZ

    local distance = math.sqrt(
        differenceX * differenceX
        + differenceY * differenceY
        + differenceZ * differenceZ
    )

    if distance > BUSINESS_LOCATION_COORDINATE_TOLERANCE then
        return false, ([[
[MoneyWash] Business location validation failed.
Business ID: %s
Type: %s
Location ID: %s
Stored coordinates: %.6f, %.6f, %.6f
Configured coordinates: %.6f, %.6f, %.6f
Distance changed: %.3f metres
The location ID appears to have been moved or reassigned.]]):format(
            tostring(row.id),
            tostring(row.business_type),
            tostring(row.location_id),
            storedX,
            storedY,
            storedZ,
            configuredX,
            configuredY,
            configuredZ,
            distance
        )
    end

    return true
end

--- -------------------------------------------------------------------------
--- MASTER TICK — fires every real minute
--- -------------------------------------------------------------------------
CreateThread(function()
    -- Validate every persisted location before exposing the business store.
    local results = MySQL.query.await(
        "SELECT * FROM moneywash_businesses"
    )

    if not results then
        print(
            "[MoneyWash] Failed to load businesses. " ..
            "The business portal will remain unavailable."
        )

        return
    end

    local validationFailed = false

    for _, row in ipairs(results) do
        local valid, errorMessage =
            validateBusinessLocationSnapshot(row)

        if not valid then
            validationFailed = true
            print(errorMessage)
        end
    end

    if validationFailed then
        print(
            "[MoneyWash] Business initialization stopped because one or " ..
            "more persisted locations no longer match the configuration."
        )

        return
    end

    for _, row in ipairs(results) do
        AddToStore(row.id, row)
    end

    SetBusinessStoreReady(true)

    if Config.Debug then
        print(("[MoneyWash] Loaded %d businesses on startup"):format(
            #results
        ))
    end

    while true do
        Wait(60000)

        CheckGlobalCycle()

        for _, business in pairs(GetAllBusinesses()) do
            ApplySuspicionDecay(business)
        end
    end
end)

--- -------------------------------------------------------------------------
--- SAVE FUNCTIONS
--- -------------------------------------------------------------------------

local BusinessSaves = {}
function IsBusinessSaveInProgress(id) return BusinessSaves[id] == true end

function SaveBusiness(id, force)
    if not force and IsCashCounterSaveBlocked(id) then
        return false
    end

    while BusinessSaves[id] do
        Wait(10)
    end

    if not force and IsCashCounterSaveBlocked(id) then
        return false
    end

    local business = GetBusiness(id)
    if not business then
        return false
    end

    local identifier = business.identifier

    BusinessSaves[id] = true

    local ok, affectedRows = pcall(
        MySQL.update.await,
        "UPDATE moneywash_businesses SET " ..
        "stock = ?, safe_covered = ?, safe_exposed = ?, suspicion = ?, " ..
        "total_laundered = ? " ..
        "WHERE id = ? AND identifier = ?",
        {
            business.stock,
            business.safeCovered,
            business.safeExposed,
            business.suspicion,
            business.totalLaundered,
            business.id,
            identifier,
        }
    )

    local saved = ok
        and type(affectedRows) == "number"
        and affectedRows > 0

    -- Zero changed rows can mean the values were already saved.
    -- Verify that the expected business/owner still exists.
    if ok and affectedRows == 0 then
        local found, existingId = pcall(
            MySQL.scalar.await,
            "SELECT id FROM moneywash_businesses " ..
            "WHERE id = ? AND identifier = ? LIMIT 1",
            { id, identifier }
        )

        saved = found and existingId ~= nil and existingId ~= false
    end

    BusinessSaves[id] = nil

    if not saved then
        print((
            "[MoneyWash] Business #%s save failed: %s"
        ):format(
            tostring(id),
            ok
            and "No valid save result for the expected business owner."
            or tostring(affectedRows)
        ))
    end

    return saved
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
