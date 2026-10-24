--- Police raid: an officer bags the exposed Safe cash of a business and it is gone.
--- Flow: start, the officer bags the cash in the UI, then finish (or cancel).
--- While a raid runs the owner cannot use the Safe, transfer or abandon (see IsBusinessRaided).

---@class Raid
---@field businessId integer
---@field officer integer Officer source
---@field officerIdentifier string
---@field ownerIdentifier string
---@field expiresAt integer GetGameTimer() value the raid times out at
---@field working? boolean True while the finish is running

---@type table<integer, Raid> Active raids by business id
local Raids = {}

---@type table<integer, integer> Business id of the raid an officer runs, by officer source
local BySource = {}

---@type table<integer, integer> os.time() before which a business can't be raided again, by business id.
--- Memory only: a resource restart clears all cooldowns.
local Cooldowns = {}

---@param reason string Failure reason, see error.<reason> in the locales
---@return { success: false, reason: string }
local function fail(reason)
    return { success = false, reason = reason }
end

--- True while a raid is running at the business. Checked by cash operations,
--- transfer, abandon, admin remove and the handler menu.
---@param businessId integer
---@return boolean
function IsBusinessRaided(businessId)
    return Raids[businessId] ~= nil
end

--- The lock keys a raid takes, so it cannot overlap a transfer or removal.
---@param businessId integer
---@param ownerIdentifier string
---@return string[]
local function lockKeys(businessId, ownerIdentifier)
    return { ("business:%d"):format(businessId), "owner:" .. ownerIdentifier }
end

--- Why the officer can no longer run this raid, or nil if all is fine.
---@param src integer Officer source
---@param raid Raid
---@return "gone"|"dead"|"too_far"|nil reason
local function officerProblem(src, raid)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return "gone" end
    if GetEntityHealth(ped) <= 0 then return "dead" end

    local business = GetBusiness(raid.businessId)
    if not business then return "gone" end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location then return "gone" end

    local config = Config.Police.Raid
    if not IsPlayerNearCoords(src, location.coords, config.Target.distance + config.Margin) then return "too_far" end

    return nil
end

--- The suspicion a business has after a raid (Config.Police.Raid.SuspicionAfter). Never higher than before.
---@param current number
---@return number suspicion
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

---@param raid Raid
local function removeRaid(raid)
    Raids[raid.businessId] = nil

    if BySource[raid.officer] == raid.businessId then
        BySource[raid.officer] = nil
    end
end

--- Ends a raid without seizing anything. Nothing happened, so there is no cooldown.
---@param raid Raid
---@param reason "aborted"|"timeout"|"too_far"|"dead"|"gone" "aborted" = the officer closed the UI, "gone" = the officer left
local function cancelRaid(raid, reason)
    -- A finish is already running: let it complete
    if raid.working then return end

    removeRaid(raid)

    if reason ~= "aborted" and GetPlayerName(raid.officer) then
        TriggerClientEvent("t1ger_moneywash:client:raidCancelled", raid.officer, reason)
    end

    local owner = GetOnlineSourceByIdentifier(raid.ownerIdentifier)
    if owner then
        _API.SendNotification(owner, locale("notification.raid_ended"), "inform")
    end
end

--- Callback: starts a raid. Returns the exposed amount the UI turns into cash piles.
---@param src integer
---@param businessId integer
lib.callback.register("t1ger_moneywash:server:raid:start", function(src, businessId)
    local config = Config.Police.Raid

    if not config.Enable then return fail("raid_disabled") end
    if not IsBusinessStoreReady() then return fail("not_ready") end

    local officerIdentifier = _API.Player.GetIdentifier(src)
    if not officerIdentifier then return fail("invalid_player") end
    if not IsPoliceOfficer(src, config.MinGrade, config.RequireDuty) then return fail("raid_not_allowed") end
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

    -- Money is moving right now
    if HasPendingCashOperation(businessId) then return fail("business_busy") end
    if business.safeExposed <= 0 then return fail("nothing_to_seize") end

    -- A transfer or removal holds these keys. Nothing yields from the checks above to the release below.
    local keys = lockKeys(businessId, business.identifier)
    if not AcquireCashOperationLocks(keys) then return fail("business_busy") end

    Raids[businessId] = {
        businessId        = businessId,
        officer           = src,
        officerIdentifier = officerIdentifier,
        ownerIdentifier   = business.identifier,
        expiresAt         = GetGameTimer() + math.max(1, tonumber(config.MaxTime) or 5) * 60000,
    }
    BySource[src] = businessId

    ReleaseCashOperationLocks(keys)

    local owner = GetOnlineSourceByIdentifier(business.identifier)
    if owner then
        _API.SendNotification(owner, locale("notification.raid_started"), "error")
    end

    return { success = true, data = { exposed = business.safeExposed } }
end)

--- Callback: finishes the officer's raid and seizes the exposed Safe cash. The returned
--- amount is what the UI shows, so it is always the real seized amount.
---@param src integer
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

    local keys = lockKeys(businessId, raid.ownerIdentifier)
    if not AcquireCashOperationLocks(keys) then return fail("business_busy") end

    raid.working = true

    -- An autosave may be writing right now: wait for it, then change the Safe
    while IsBusinessSaveInProgress(businessId) do
        Wait(20)
    end

    local business = GetBusiness(businessId)

    if not business or business.identifier ~= raid.ownerIdentifier then
        removeRaid(raid)
        ReleaseCashOperationLocks(keys)
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
    Cooldowns[businessId] = os.time() + math.max(0, tonumber(Config.Police.Raid.Cooldown) or 0) * 60

    ReleaseCashOperationLocks(keys)

    local owner = GetOnlineSourceByIdentifier(raid.ownerIdentifier)
    if owner then
        _API.SendNotification(owner, string.format(locale("notification.raid_seized_owner"), FormatMoney(seized)), "error")
    end

    RunHook("OnBusinessRaided", raid.officerIdentifier, raid.ownerIdentifier, businessId, seized)

    return { success = true, data = { seized = seized } }
end)

--- Callback: cancels the officer's running raid (the UI was closed before finishing).
---@param src integer
lib.callback.register("t1ger_moneywash:server:raid:cancel", function(src)
    local businessId = BySource[src]
    local raid = businessId and Raids[businessId]

    if raid then cancelRaid(raid, "aborted") end

    return { success = true }
end)

--- Ends raids that time out, or whose officer died, left or moved away.
--- Sleeps longer while no raid is running.
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