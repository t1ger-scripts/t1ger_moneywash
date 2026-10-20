--- ============================================================================
--- Street Wash Server
--- Everything lives in memory: no database. The server picks the spot, takes
--- the dirty cash only at the handover, rolls the betrayal, pays the bank and
--- returns the cash on a valid recovery claim. The client only travels and
--- presses buttons.
--- ============================================================================

local CLIENT_EVENTS = {
    ended = "t1ger_moneywash:client:streetWashEnded",
}

--- Runs waiting for the handover
---@type table<number, table> src -> { identifier, amount, spot, expiresAt }
local Runs = {}

--- Betrayed runs waiting for the player to get the cash back
---@type table<number, table> src -> { identifier, amount, spot, expiresAt }
local Betrayals = {}

--- identifier -> os.time() when the cooldown ends
local Cooldowns = {}

--- identifier -> { start, amount } rolling 24h window
local Daily = {}

--- Per-player guard against double-click interleaving
local Busy = {}

local DAY = 24 * 60 * 60


--- ---------------------------------------------------------------------------
--- HELPERS
--- ---------------------------------------------------------------------------

--- Runs a callback body under the per-player busy guard. Whatever happens
--- (even an error), the guard is released and the player gets a clean reply.
local function guarded(source, fn)
    if Busy[source] then return { success = false, reason = "busy" } end
    Busy[source] = true

    local ok, response = pcall(fn)
    Busy[source] = nil

    if not ok then
        print(("^1[MoneyWash] Street wash error: %s^7"):format(tostring(response)))
        return { success = false, reason = "unknown" }
    end

    return response
end

local function toTable(spot)
    return { x = spot.x, y = spot.y, z = spot.z, w = spot.w }
end

--- Cooldown seconds left for a player (0 when none).
local function cooldownRemaining(identifier)
    local endsAt = Cooldowns[identifier]
    if not endsAt then return 0 end

    local remaining = endsAt - os.time()
    if remaining <= 0 then
        Cooldowns[identifier] = nil
        return 0
    end

    return remaining
end

--- Dirty cash already handed over in the player's rolling 24h window.
local function dailyUsed(identifier)
    local window = Daily[identifier]
    if not window then return 0 end

    if os.time() - window.start >= DAY then
        Daily[identifier] = nil
        return 0
    end

    return window.amount
end

local function addDaily(identifier, amount)
    local window = Daily[identifier]

    if not window or os.time() - window.start >= DAY then
        window = { start = os.time(), amount = 0 }
        Daily[identifier] = window
    end

    window.amount = window.amount + amount
end

--- Largest amount the player may start with right now (before checking cash).
local function allowedMax(identifier)
    local cfg = Config.StreetWash
    local max = cfg.MaxAmount

    if cfg.DailyLimit and cfg.DailyLimit > 0 then
        max = math.min(max, cfg.DailyLimit - dailyUsed(identifier))
    end

    return math.floor(max)
end

--- Betrayal chance (0-100) for an amount: MinAmount -> ChanceAtMin,
--- MaxAmount -> ChanceAtMax, linear in between.
local function betrayalChance(amount)
    local cfg = Config.StreetWash
    local betrayal = cfg.Betrayal

    if not betrayal or not betrayal.Enable or amount < betrayal.MinAmount then return 0 end

    local span = cfg.MaxAmount - betrayal.MinAmount
    local progress = span > 0 and math.min(1.0, (amount - betrayal.MinAmount) / span) or 1.0

    return betrayal.ChanceAtMin + (betrayal.ChanceAtMax - betrayal.ChanceAtMin) * progress
end

local function isDead(src)
    local ped = GetPlayerPed(src)
    return not ped or ped == 0 or GetEntityHealth(ped) <= 0
end

--- Ends whatever the player has going. The client is told why.
---@param src number
---@param reason string|nil "timeout" | "dead" | "lost"; nil = silent
local function releasePlayer(src, reason)
    local hadRun = Runs[src] ~= nil
    local betrayal = Betrayals[src]

    Runs[src] = nil
    Betrayals[src] = nil
    Busy[src] = nil

    if betrayal then
        RunHook("OnStreetWashBetrayed", betrayal.identifier, betrayal.amount, false)
    end

    if reason and (hadRun or betrayal) and GetPlayerName(src) then
        TriggerClientEvent(CLIENT_EVENTS.ended, src, reason)
    end
end

--- Common checks before a run. Returns the identifier on success.
---@param src number
---@return string|nil identifier
---@return string|nil reason
local function validateStart(src)
    local cfg = Config.StreetWash
    if not cfg or not cfg.Enable then return nil, "street_wash_disabled" end
    if not cfg.Spots or #cfg.Spots == 0 then return nil, "street_wash_no_spots" end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return nil, "unknown" end

    if Runs[src] or Betrayals[src] then return nil, "street_wash_active" end
    if cooldownRemaining(identifier) > 0 then return nil, "street_wash_cooldown" end

    if allowedMax(identifier) < cfg.MinAmount then return nil, "street_wash_daily_limit" end
    if _API.Player.GetDirtyMoney(src) < cfg.MinAmount then return nil, "insufficient_dirty_cash" end

    return identifier
end


--- ---------------------------------------------------------------------------
--- CALLBACKS
--- ---------------------------------------------------------------------------

--- Called before the amount input: refuses early when a run is impossible and
--- tells the client the limits to show.
lib.callback.register("t1ger_moneywash:server:streetWash:info", function(source)
    return guarded(source, function()
        local identifier, reason = validateStart(source)
        if not identifier then return { success = false, reason = reason } end

        local cfg = Config.StreetWash
        local dirty = _API.Player.GetDirtyMoney(source)

        return {
            success    = true,
            min        = cfg.MinAmount,
            max        = math.min(allowedMax(identifier), math.floor(dirty)),
            dirty      = dirty,
            cutPercent = cfg.CutPercent,
        }
    end)
end)


--- Starts the run: picks the spot and starts the timer. Nothing is taken yet.
lib.callback.register("t1ger_moneywash:server:streetWash:start", function(source, amount)
    return guarded(source, function()
        local identifier, reason = validateStart(source)
        if not identifier then return { success = false, reason = reason } end

        local cfg = Config.StreetWash

        amount = tonumber(amount)
        if not amount or amount ~= math.floor(amount)
            or amount < cfg.MinAmount or amount > cfg.MaxAmount
            or amount > allowedMax(identifier)
        then
            return { success = false, reason = "invalid_amount" }
        end

        if _API.Player.GetDirtyMoney(source) < amount then
            return { success = false, reason = "insufficient_dirty_cash" }
        end

        local spot = cfg.Spots[math.random(#cfg.Spots)]

        Runs[source] = {
            identifier = identifier,
            amount     = amount,
            spot       = spot,
            expiresAt  = os.time() + cfg.MaxTime * 60,
        }

        return { success = true, spot = toTable(spot), maxTime = cfg.MaxTime }
    end)
end)


--- The handover: takes the cash, then either pays the bank or betrays.
lib.callback.register("t1ger_moneywash:server:streetWash:handover", function(source)
    return guarded(source, function()
        local run = Runs[source]
        if not run then return { success = false, reason = "street_wash_no_run" } end

        local cfg = Config.StreetWash

        if os.time() > run.expiresAt then
            releasePlayer(source, "timeout")
            return { success = false, reason = "street_wash_no_run" }
        end

        if not IsPlayerNearCoords(source, run.spot, cfg.Contact.TargetDistance + 4.0) then
            return { success = false, reason = "contact_too_far" }
        end

        -- Re-check that they still carry the amount, then take it.
        if _API.Player.GetDirtyMoney(source) < run.amount
            or not _API.Player.RemoveDirtyMoney(source, run.amount)
        then
            return { success = false, reason = "insufficient_dirty_cash" }
        end

        Runs[source] = nil
        addDaily(run.identifier, run.amount)
        Cooldowns[run.identifier] = os.time() + cfg.Cooldown * 60

        -- Betrayal: decided here, on the server.
        local chance = betrayalChance(run.amount)

        if chance > 0 and math.random() * 100 < chance then
            local kind = (math.random() * 100 < cfg.Betrayal.FleeShare) and "flee" or "attack"

            Betrayals[source] = {
                identifier = run.identifier,
                amount     = run.amount,
                spot       = run.spot,
                expiresAt  = os.time() + cfg.Betrayal.ResolveTime,
            }

            return { success = true, outcome = "betrayed", kind = kind, amount = run.amount }
        end

        -- Honest: pay the bank. If paying fails, give the cash back.
        local cut = math.floor(run.amount * cfg.CutPercent / 100 + 0.5)
        local payout = run.amount - cut

        local paid = pcall(_API.Player.AddMoney, source, payout, "bank")

        if not paid then
            _API.Player.AddDirtyMoney(source, run.amount)
            return { success = false, reason = "unknown" }
        end

        local reward = Config.Reputation.Enable and Config.Reputation.Rewards.streetWash
        if reward and reward.enable then
            AwardReputationPoints(source, run.identifier, reward.points)
        end

        RunHook("OnStreetWashCompleted", run.identifier, run.amount, cut, payout)

        return {
            success = true,
            outcome = "completed",
            amount  = run.amount,
            cut     = cut,
            payout  = payout,
        }
    end)
end)


--- Takes the bag back after a betrayal: returns the dirty cash, no payout.
lib.callback.register("t1ger_moneywash:server:streetWash:claim", function(source)
    return guarded(source, function()
        local betrayal = Betrayals[source]
        if not betrayal then return { success = false, reason = "nothing_to_claim" } end

        if os.time() > betrayal.expiresAt then
            releasePlayer(source, "lost")
            return { success = false, reason = "nothing_to_claim" }
        end

        if not IsPlayerNearCoords(source, betrayal.spot, Config.StreetWash.Betrayal.ClaimDistance) then
            return { success = false, reason = "nothing_to_claim" }
        end

        Betrayals[source] = nil
        _API.Player.AddDirtyMoney(source, betrayal.amount)

        RunHook("OnStreetWashBetrayed", betrayal.identifier, betrayal.amount, true)

        return { success = true, amount = betrayal.amount }
    end)
end)


--- The client reports the contact got away: the cash is lost.
lib.callback.register("t1ger_moneywash:server:streetWash:escaped", function(source)
    if not Betrayals[source] then return { success = false } end

    releasePlayer(source, nil)
    return { success = true }
end)


--- The player calls the meeting off (only before the handover).
lib.callback.register("t1ger_moneywash:server:streetWash:cancel", function(source)
    if Busy[source] then return { success = false, reason = "busy" } end
    if not Runs[source] then return { success = false, reason = "street_wash_no_run" } end

    Runs[source] = nil
    return { success = true }
end)


--- ---------------------------------------------------------------------------
--- CLEANUP
--- ---------------------------------------------------------------------------

--- Timeouts and dead players.
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()

        for src, run in pairs(Runs) do
            if now > run.expiresAt then
                releasePlayer(src, "timeout")
            elseif GetPlayerName(src) and isDead(src) then
                releasePlayer(src, "dead")
            end
        end

        for src, betrayal in pairs(Betrayals) do
            if now > betrayal.expiresAt or (GetPlayerName(src) and isDead(src)) then
                releasePlayer(src, "lost")
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    releasePlayer(source, nil)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Runs, Betrayals = {}, {}
end)