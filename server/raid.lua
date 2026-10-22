--- ============================================================================
--- Business Raid
--- A police officer raids a business and seizes its exposed Safe cash.
--- Flow: start -> officer bags the cash in the UI -> finish, or cancel.
--- While a raid runs the owner cannot use the Safe, transfer or abandon
--- (see IsBusinessRaided, checked by cash operations and ownership code).
--- ============================================================================

---@type table<integer, table> Active raids by business id
local Raids = {}

---@type table<integer, integer> Business id of the raid an officer is running, by officer source
local BySource = {}

---@type table<integer, integer> os.time() before which a business can't be raided again, by business id.
--- Memory only: a resource restart clears all cooldowns.
local Cooldowns = {}

--- Extra distance (on top of the target distance) the officer may drift from the NPC
--- before the raid is called off. Absorbs position lag and small pushes.
local RANGE_MARGIN = 6.0

local function fail(reason)
    return { success = false, reason = reason }
end

local function onlineSource(identifier)
    return GetOnlineSourceByIdentifier(identifier)
end

--- True while a raid is running at the business. Checked by cash operations,
--- transfer, abandon, admin remove and the handler menu.
---@param businessId integer
---@return boolean
function IsBusinessRaided(businessId)
    return Raids[businessId] ~= nil
end

--- True if the player has a police job with the minimum raid grade.
local function isRaider(src)
    local job = _API.Player.GetJob(src)
    if not job then return false end

    for _, name in ipairs(Config.Police.Jobs) do
        if job.name == name then
            return (job.grade or 0) >= Config.Police.Raid.MinGrade
        end
    end

    return false
end

--- Returns why the officer can no longer run this raid, or nil if all is fine.
---@return string|nil reason "gone" | "dead" | "too_far"
local function officerProblem(src, raid)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return "gone" end
    if GetEntityHealth(ped) <= 0 then return "dead" end

    local business = GetBusiness(raid.businessId)
    if not business then return "gone" end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location then return "gone" end

    local range = Config.Police.Raid.Target.distance + RANGE_MARGIN
    if not IsPlayerNearCoords(src, location.coords, range) then return "too_far" end

    return nil
end

--- What a finished raid does to the business suspicion. Never raises it.
---@param current number
---@return number
local function suspicionAfterRaid(current)
    local rule = Config.Police.Raid.SuspicionAfter or {}
    local value = math.max(0, math.min(100, tonumber(rule.Value) or 0))

    if rule.Mode == "set" then
        return math.min(current, value)
    elseif rule.Mode == "reduce" then
        return current * (1 - value / 100)
    end

    return current
end

local function removeRaid(raid)
    Raids[raid.businessId] = nil

    if BySource[raid.officer] == raid.businessId then
        BySource[raid.officer] = nil
    end
end

--- Ends a raid without seizing anything. Nothing happened, so there is no cooldown.
---@param raid table
---@param reason string "aborted" | "timeout" | "too_far" | "dead" | "gone"
local function cancelRaid(raid, reason)
    -- A finish is already running: let it complete.
    if raid.working then return end

    removeRaid(raid)

    -- "aborted" means the officer closed the UI themselves; "gone" means they left.
    if reason ~= "aborted" and GetPlayerName(raid.officer) then
        TriggerClientEvent("t1ger_moneywash:client:raidCancelled", raid.officer, reason)
    end

    local owner = onlineSource(raid.ownerIdentifier)
    if owner then
        _API.SendNotification(owner, locale("notification.raid_ended"), "inform")
    end
end

--- -------------------------------------------------------------------------
--- CALLBACKS
--- -------------------------------------------------------------------------

--- Starts a raid. Returns the exposed amount the UI turns into cash piles.
lib.callback.register("t1ger_moneywash:server:raid:start", function(src, businessId)
    local config = Config.Police.Raid

    if not config.Enable then return fail("raid_disabled") end
    if not IsBusinessStoreReady() then return fail("not_ready") end

    local officerIdentifier = _API.Player.GetIdentifier(src)
    if not officerIdentifier then return fail("invalid_player") end
    if not isRaider(src) then return fail("raid_not_allowed") end
    if BySource[src] then return fail("raid_active") end

    businessId = tonumber(businessId)
    local business = businessId and GetBusiness(businessId)
    if not business then return fail("not_found") end
    if business.identifier == officerIdentifier and not Config.Debug then return fail("own_business") end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location or not IsPlayerNearCoords(src, location.coords, config.Target.distance + 2.0) then
        return fail("business_too_far")
    end

    if Raids[businessId] then return fail("raid_in_progress") end

    local readyAt = Cooldowns[businessId]
    if readyAt and readyAt > os.time() then return fail("raid_cooldown") end

    -- A cash operation is running: money is moving right now.
    if HasPendingCashOperation(businessId) then return fail("business_busy") end

    local lockKeys = { ("business:%d"):format(businessId), "owner:" .. business.identifier }

    if not AcquireCashOperationLocks(lockKeys) then
        return fail("business_busy")
    end

    -- No yielding between here and the end of this block, so these checks hold.
    business = GetBusiness(businessId)

    local problem
    if not business or (business.identifier == officerIdentifier and not Config.Debug) then
        problem = "not_found"
    elseif Raids[businessId] then
        problem = "raid_in_progress"
    elseif HasPendingCashOperation(businessId) then
        problem = "business_busy"
    elseif business.safeExposed <= 0 then
        problem = "nothing_to_seize"
    end

    if problem then
        ReleaseCashOperationLocks(lockKeys)
        return fail(problem)
    end

    local maxTime = math.max(1, tonumber(config.MaxTime) or 5)

    Raids[businessId] = {
        businessId        = businessId,
        officer           = src,
        officerIdentifier = officerIdentifier,
        ownerIdentifier   = business.identifier,
        expiresAt         = GetGameTimer() + maxTime * 60000,
    }
    BySource[src] = businessId

    ReleaseCashOperationLocks(lockKeys)

    local owner = onlineSource(business.identifier)
    if owner then
        _API.SendNotification(owner, locale("notification.raid_started"), "error")
    end

    return { success = true, data = { exposed = business.safeExposed } }
end)

--- Finishes a raid: seizes the exposed Safe cash. The amount returned is what
--- the UI shows, so it is always the real seized amount.
lib.callback.register("t1ger_moneywash:server:raid:finish", function(src)
    local businessId = BySource[src]
    local raid = businessId and Raids[businessId]
    if not raid or raid.working then return fail("no_raid") end

    local problem = officerProblem(src, raid)
    if problem == "too_far" then return fail("too_far") end
    if problem then
        cancelRaid(raid, problem)
        return fail("no_raid")
    end

    local lockKeys = { ("business:%d"):format(businessId), "owner:" .. raid.ownerIdentifier }

    if not AcquireCashOperationLocks(lockKeys) then
        return fail("business_busy")
    end

    raid.working = true

    -- An autosave may be writing right now: wait for it, then change the Safe.
    while IsBusinessSaveInProgress(businessId) do
        Wait(20)
    end

    local business = GetBusiness(businessId)

    if not business or business.identifier ~= raid.ownerIdentifier then
        removeRaid(raid)
        ReleaseCashOperationLocks(lockKeys)
        return fail("no_raid")
    end

    local seized = business.safeExposed

    UpdateBusinessFields(businessId, {
        safeExposed = 0,
        suspicion   = suspicionAfterRaid(business.suspicion),
    })

    -- Memory is authoritative. If this save fails, the next autosave writes it.
    if not SaveBusiness(businessId, true) then
        print(("[MoneyWash] Raid on business %d: save failed, the next autosave will retry it."):format(businessId))
    end

    removeRaid(raid)

    local cooldown = math.max(0, tonumber(Config.Police.Raid.Cooldown) or 0)
    Cooldowns[businessId] = os.time() + cooldown * 60

    ReleaseCashOperationLocks(lockKeys)

    local owner = onlineSource(raid.ownerIdentifier)
    if owner then
        _API.SendNotification(owner,
            string.format(locale("notification.raid_seized_owner"), Config.Currency .. seized), "error")
    end

    RunHook("OnBusinessRaided", raid.officerIdentifier, raid.ownerIdentifier, businessId, seized)

    return { success = true, data = { seized = seized } }
end)

--- Cancels the officer's running raid (UI closed with ESC, or closed before finishing).
lib.callback.register("t1ger_moneywash:server:raid:cancel", function(src)
    local businessId = BySource[src]
    local raid = businessId and Raids[businessId]

    if raid then cancelRaid(raid, "aborted") end

    return { success = true }
end)

--- -------------------------------------------------------------------------
--- WATCHER
--- Ends raids that time out, or whose officer died, left or moved away.
--- Sleeps longer while no raid is running.
--- -------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(next(Raids) and 1000 or 3000)

        local now = GetGameTimer()

        for _, raid in pairs(Raids) do
            if not raid.working then
                if now >= raid.expiresAt then
                    cancelRaid(raid, "timeout")
                else
                    local problem = officerProblem(raid.officer, raid)
                    if problem then cancelRaid(raid, problem) end
                end
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    local businessId = BySource[src]
    local raid = businessId and Raids[businessId]

    if raid then cancelRaid(raid, "gone") end
end)