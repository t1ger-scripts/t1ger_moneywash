--- Launder contracts (server). A shift is one player working street handovers, kept in memory only.
--- A shift ends by the player's choice, a death, a disconnect or a resource stop. Ending it by choice
--- or by disconnecting starts a cooldown, so the first drop can't be rerolled for free.

local cfg = Config.Contracts

local HANDOFF_DELAY = 800 -- ms between the end of the negotiation and the cash changing hands, in sync with the handoff animation

local SHIFT_ENDED_EVENT = "t1ger_moneywash:client:contractShiftEnded"
local DROP_ASSIGNED_EVENT = "t1ger_moneywash:client:contractDropAssigned"

---@type table<string, boolean> End reasons the client is told about. It knows the others already.
local NOTIFY_REASONS = { died = true, missed = true, no_dirty_cash = true }

---@class ContractShift
---@field src integer
---@field identifier string
---@field handovers integer Completed handovers
---@field cleaned integer Dirty cash handed over
---@field paid integer Clean money paid out
---@field nextDropAt integer os.time() the next drop is assigned, while there is no drop
---@field drop? { index: integer, expiresAt: integer } The drop the player is on, index in Config.Contracts.Drops
---@field lastDrop? integer Index in Config.Contracts.Drops of the previous drop, not picked again right away
---@field pending? { startedAt: integer, expiresAt: integer, resolving?: boolean } A deal in progress. The cash is taken when it is completed
---@field betrayal? { amount: integer, expiresAt: integer } Dirty cash a contact ran off with, recoverable until it expires

---@type table<integer, ContractShift> Active shifts by player source
local Shifts = {}

---@type table<string, integer> os.time() a player can start a shift again, by identifier
local Cooldowns = {}

---@type table<integer, boolean> Players inside a callback, stops double clicks
local Busy = {}

---@type table<integer, boolean> Indexes in Config.Contracts.Drops that a player is heading to right now
local TakenDrops = {}

---@param identifier string
---@return integer seconds 0 when the player can start
local function getCooldownRemaining(identifier)
    local remaining = (Cooldowns[identifier] or 0) - os.time()
    if remaining > 0 then return remaining end

    Cooldowns[identifier] = nil

    return 0
end

---@param list any[]
---@return any
local function pick(list)
    return list[math.random(#list)]
end

--- Frees the drop a shift is on, so another player can get it.
---@param shift ContractShift
local function releaseDrop(shift)
    if shift.drop then TakenDrops[shift.drop.index] = nil end

    shift.drop = nil
end

--- Plans the next drop after a random delay.
---@param shift ContractShift
---@param delay integer[] Min and max seconds
local function scheduleNextDrop(shift, delay)
    releaseDrop(shift)
    shift.nextDropAt = os.time() + math.random(delay[1], delay[2])
end

--- Picks a free drop between MinDropDistance and MaxDropDistance from the player, not the previous one.
--- If none fits it takes any free drop, and the previous one only when nothing else is left.
---@param shift ContractShift
---@return integer|nil index In Config.Contracts.Drops, nil when every drop is taken
local function pickDropIndex(shift)
    local origin = GetEntityCoords(GetPlayerPed(shift.src))
    local inRange, free, previous = {}, {}, nil

    for index, drop in ipairs(cfg.Drops) do
        if not TakenDrops[index] then
            if index == shift.lastDrop then
                previous = index
            else
                free[#free + 1] = index

                local distance = #(origin - vec3(drop.x, drop.y, drop.z))
                if distance >= cfg.Shift.MinDropDistance and distance <= cfg.Shift.MaxDropDistance then inRange[#inRange + 1] = index end
            end
        end
    end

    if #inRange > 0 then return pick(inRange) end
    if #free > 0 then return pick(free) end

    return previous
end

--- Sends the player to a new drop. With every drop taken the shift waits and tries again.
---@param shift ContractShift
local function assignDrop(shift)
    local index = pickDropIndex(shift)
    if not index then return end

    TakenDrops[index] = true
    shift.lastDrop = index
    shift.drop = { index = index, expiresAt = os.time() + cfg.Shift.DropTime }

    TriggerClientEvent(DROP_ASSIGNED_EVENT, shift.src, {
        coords   = cfg.Drops[index],
        model    = pick(cfg.Contact.Models),
        scenario = "WORLD_HUMAN_STAND_IMPATIENT",
        seconds  = cfg.Shift.DropTime,
    })
end

--- True while the player is on a shift.
---@param src integer
---@return boolean
function IsOnContractShift(src)
    return Shifts[src] ~= nil
end
exports("IsOnContractShift", IsOnContractShift)

--- Ends a shift. A choice or a disconnect starts the cooldown, a death or a resource stop does not.
---@param shift ContractShift
---@param reason "player"|"died"|"dropped"|"stopped"|"missed"|"no_dirty_cash"
local function endShift(shift, reason)
    Shifts[shift.src] = nil
    releaseDrop(shift)

    -- A resource stop gives back the cash of a betrayal. A death or a disconnect loses it.
    if reason == "stopped" and shift.betrayal then
        _API.Player.AddDirtyMoney(shift.src, shift.betrayal.amount)
    end

    if reason == "player" or reason == "dropped" then
        Cooldowns[shift.identifier] = os.time() + cfg.Shift.Cooldown
    end

    if NOTIFY_REASONS[reason] then TriggerClientEvent(SHIFT_ENDED_EVENT, shift.src, reason) end

    RunHook("OnContractShiftEnded", shift.identifier, reason, shift.handovers, shift.cleaned, shift.paid)
end

--- Runs a callback body once per player at a time. An error gives a clean reply and frees the guard.
---@param src integer
---@param fn fun(): table
---@return table
local function guarded(src, fn)
    if Busy[src] then return { success = false, reason = "request_failed" } end
    Busy[src] = true

    local ok, response = pcall(fn)
    Busy[src] = nil

    if not ok then
        print(("^1[MoneyWash] Contract error: %s^7"):format(tostring(response)))
        return { success = false, reason = "unknown" }
    end

    return response
end

--- Checks the player may start a shift.
---@param src integer
---@return string|nil identifier Or nil when the player can't start
---@return string? reason
---@return integer? remaining Cooldown seconds, only with "contract_cooldown"
local function validateStart(src)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return nil, "unknown" end
    if Shifts[src] then return nil, "contract_active" end

    local remaining = getCooldownRemaining(identifier)
    if remaining > 0 then return nil, "contract_cooldown", remaining end

    if math.floor(_API.Player.GetDirtyMoney(src) or 0) < cfg.Deal.MinAmount then return nil, "insufficient_dirty_cash" end

    return identifier
end

--- Callback: starts a shift.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:startShift", function(src)
    return guarded(src, function()
        local identifier, reason, remaining = validateStart(src)
        if not identifier then return { success = false, reason = reason, remaining = remaining } end

        local shift = { src = src, identifier = identifier, handovers = 0, cleaned = 0, paid = 0 }
        scheduleNextDrop(shift, cfg.Shift.FirstDropDelay)
        Shifts[src] = shift

        return { success = true }
    end)
end)

--- Callback: the player ends their own shift.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:endShift", function(src)
    return guarded(src, function()
        local shift = Shifts[src]
        if not shift then return { success = false, reason = "no_contract_shift" } end
        if shift.pending then return { success = false, reason = "contract_dealing" } end

        endShift(shift, "player")

        return { success = true, cooldown = getCooldownRemaining(shift.identifier) }
    end)
end)

--- Takes dirty cash and checks the balance really dropped by that amount.
---@param src integer
---@param amount integer
---@return boolean taken
local function takeDirtyCash(src, amount)
    local before = _API.Player.GetDirtyMoney(src)
    pcall(_API.Player.RemoveDirtyMoney, src, amount)
    local after = _API.Player.GetDirtyMoney(src)

    if after == before - amount then return true end

    -- Some cash may be gone anyway, so don't retry: an administrator has to look at it
    if after < before then
        print(("^1[MoneyWash] Contract handover removed %s of %s dirty cash from source %d. Check the player.^7"):format(before - after, amount, src))
    end

    return false
end

--- Callback: the player starts the deal. The progress bar is the negotiation, nothing is taken yet.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:beginHandover", function(src)
    return guarded(src, function()
        local shift = Shifts[src]
        if not shift then return { success = false, reason = "no_contract_shift" } end
        if shift.pending then return { success = false, reason = "contract_dealing" } end
        if not shift.drop or os.time() > shift.drop.expiresAt then return { success = false, reason = "contract_no_drop" } end

        if not IsPlayerNearCoords(src, cfg.Drops[shift.drop.index], cfg.Contact.Target.Distance + 3.0) then
            return { success = false, reason = "contract_too_far" }
        end

        if math.floor(_API.Player.GetDirtyMoney(src) or 0) < cfg.Deal.MinAmount then
            endShift(shift, "no_dirty_cash")
            return { success = false, reason = "shift_over" }
        end

        local duration = cfg.Deal.Duration

        shift.pending = {
            startedAt = GetGameTimer(),
            expiresAt = os.time() + math.ceil(duration / 1000) + 15,
        }

        return { success = true, duration = duration }
    end)
end)

--- Callback: the player cancelled the negotiation. Nothing was taken, so the contact can be approached again.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:cancelHandover", function(src)
    return guarded(src, function()
        local shift = Shifts[src]

        if shift and shift.pending and not shift.pending.resolving then shift.pending = nil end

        return { success = true }
    end)
end)

--- Callback: the negotiation is over. The outcome is decided here and told to the client at once.
--- The cash is taken, and paid out on a clean deal, a moment later when the handoff animation plays.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:completeHandover", function(src)
    return guarded(src, function()
        local shift = Shifts[src]
        if not shift then return { success = false, reason = "no_contract_shift" } end

        local pending = shift.pending
        if not pending or pending.resolving then return { success = false, reason = "contract_no_deal" } end

        -- The client can't finish the deal faster than the progress bar. A little room covers latency.
        if GetGameTimer() - pending.startedAt < cfg.Deal.Duration - 500 then
            return { success = false, reason = "contract_deal_early" }
        end

        -- The amount is decided now, from what the player carries
        local dirty = math.floor(_API.Player.GetDirtyMoney(src) or 0)
        if dirty < cfg.Deal.MinAmount then
            shift.pending = nil
            endShift(shift, "no_dirty_cash")
            return { success = false, reason = "shift_over" }
        end

        local amount = math.min(dirty, math.random(cfg.Deal.MinAmount, cfg.Deal.MaxAmount))
        local paid = math.floor(amount * (100 - cfg.Deal.Cut) / 100)
        local betrayal = cfg.Betrayal
        local betrayed = math.random(100) <= betrayal.Chance

        -- The deal is settled while the handoff animation plays
        pending.resolving = true

        SetTimeout(HANDOFF_DELAY, function()
            if Shifts[src] ~= shift then return end

            shift.pending = nil

            if not takeDirtyCash(src, amount) then
                _API.SendNotification(src, locale("notification.contract_deal_failed"), "error")
                scheduleNextDrop(shift, cfg.Shift.DropDelay)
                return
            end

            if betrayed then
                -- No new drop until the player has the cash back or has lost it
                releaseDrop(shift)
                shift.nextDropAt = math.huge
                shift.betrayal = { amount = amount, expiresAt = os.time() + betrayal.Time + 5 }

                RunHook("OnContractBetrayed", shift.identifier, amount)
                return
            end

            _API.Player.AddMoney(src, paid, cfg.Deal.Account)

            shift.handovers, shift.cleaned, shift.paid = shift.handovers + 1, shift.cleaned + amount, shift.paid + paid
            scheduleNextDrop(shift, cfg.Shift.DropDelay)

            local reward = Config.Reputation.Enable and Config.Reputation.Rewards.contractHandover
            if reward and reward.enable then AwardReputationPoints(src, shift.identifier, reward.points) end

            RunHook("OnContractHandover", shift.identifier, amount, paid, shift.handovers)
        end)

        if betrayed then
            return {
                success = true,
                betrayed = true,
                mode = math.random(100) <= betrayal.AttackChance and "attack" or "flee",
                weapon = pick(betrayal.Weapons),
                amount = amount,
                seconds = betrayal.Time,
                delay = HANDOFF_DELAY,
            }
        end

        return { success = true, amount = amount, paid = paid, delay = HANDOFF_DELAY }
    end)
end)

--- Callback: the player took the cash back from the contact they put down.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:recoverCash", function(src)
    return guarded(src, function()
        local shift = Shifts[src]
        if not shift then return { success = false, reason = "no_contract_shift" } end

        local betrayal = shift.betrayal
        if not betrayal or os.time() > betrayal.expiresAt then return { success = false, reason = "contract_cash_gone" } end

        shift.betrayal = nil
        _API.Player.AddDirtyMoney(src, betrayal.amount)
        scheduleNextDrop(shift, cfg.Shift.DropDelay)

        return { success = true, amount = betrayal.amount }
    end)
end)

--- Callback: the contact got away, so the player gives up on the cash and the shift moves on.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:forfeitCash", function(src)
    return guarded(src, function()
        local shift = Shifts[src]

        if shift and shift.betrayal then
            shift.betrayal = nil
            scheduleNextDrop(shift, cfg.Shift.DropDelay)
        end

        return { success = true }
    end)
end)

--- Moves a shift along: a missed drop ends it, a new drop is assigned while dirty cash is left.
---@param shift ContractShift
---@param now integer
local function tickShift(shift, now)
    if shift.betrayal and now > shift.betrayal.expiresAt then
        shift.betrayal = nil
        scheduleNextDrop(shift, cfg.Shift.DropDelay)
    end

    if shift.pending then
        -- A deal that never finished (the client was interrupted): nothing was taken, the shift carries on
        if now > shift.pending.expiresAt then
            shift.pending = nil
            _API.SendNotification(shift.src, locale("notification.contract_deal_failed"), "error")
        end
    elseif shift.drop then
        if now > shift.drop.expiresAt then endShift(shift, "missed") end
    elseif now >= shift.nextDropAt then
        if math.floor(_API.Player.GetDirtyMoney(shift.src) or 0) < cfg.Deal.MinAmount then
            endShift(shift, "no_dirty_cash")
        else
            assignDrop(shift)
        end
    end
end

--- Ends the shift of a player who died or left, and moves the others along.
CreateThread(function()
    while true do
        Wait(1000)

        local now = os.time()

        for src, shift in pairs(Shifts) do
            if not GetPlayerName(src) then
                endShift(shift, "dropped")
            elseif GetEntityHealth(GetPlayerPed(src)) <= 0 then
                endShift(shift, "died")
            else
                local ok, err = pcall(tickShift, shift, now)
                if not ok then print(("^1[MoneyWash] Contract error: %s^7"):format(tostring(err))) end
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    Busy[src] = nil

    if Shifts[src] then endShift(Shifts[src], "dropped") end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, shift in pairs(Shifts) do endShift(shift, "stopped") end
end)