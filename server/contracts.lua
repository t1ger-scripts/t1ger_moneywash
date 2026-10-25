--- Launder contracts (server). A shift is one player working street handovers, kept in memory only.
--- A shift ends by the player's choice, a death, a disconnect or a resource stop. Ending it by choice
--- or by disconnecting starts a cooldown, so the first drop can't be rerolled for free.

local cfg = Config.Contracts

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
---@field drop? { expiresAt: integer } The drop the player is on
---@field lastDrop? integer Index in Config.Contracts.Drops, never picked twice in a row

---@type table<integer, ContractShift> Active shifts by player source
local Shifts = {}

---@type table<string, integer> os.time() a player can start a shift again, by identifier
local Cooldowns = {}

---@type table<integer, boolean> Players inside a callback, stops double clicks
local Busy = {}

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

--- Plans the next drop after a random delay.
---@param shift ContractShift
local function scheduleNextDrop(shift)
    shift.drop = nil
    shift.nextDropAt = os.time() + math.random(cfg.DropDelay[1], cfg.DropDelay[2])
end

--- Picks a drop at least MinDropDistance from the player, never the same as the last one.
---@param shift ContractShift
---@return integer index In Config.Contracts.Drops
local function pickDropIndex(shift)
    local drops = cfg.Drops
    local origin = GetEntityCoords(GetPlayerPed(shift.src))
    local far, other = {}, {}

    for index, drop in ipairs(drops) do
        if index ~= shift.lastDrop or #drops == 1 then
            other[#other + 1] = index
            if #(origin - vec3(drop.x, drop.y, drop.z)) >= cfg.MinDropDistance then far[#far + 1] = index end
        end
    end

    return pick(#far > 0 and far or other)
end

--- Sends the player to a new drop.
---@param shift ContractShift
local function assignDrop(shift)
    local index = pickDropIndex(shift)

    shift.lastDrop = index
    shift.drop = { expiresAt = os.time() + cfg.DropTime }

    TriggerClientEvent(DROP_ASSIGNED_EVENT, shift.src, {
        coords   = cfg.Drops[index],
        model    = pick(cfg.Contacts.Models),
        scenario = pick(cfg.Contacts.Scenarios),
        seconds  = cfg.DropTime,
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

    if reason == "player" or reason == "dropped" then
        Cooldowns[shift.identifier] = os.time() + cfg.Cooldown
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

    if Config.Reputation.Enable then
        local reputation = GetPlayerReputation(src)
        if not reputation then return nil, "reputation_not_ready" end
        if reputation:GetPoints() < cfg.RequiredReputation then return nil, "insufficient_reputation" end
    end

    local remaining = getCooldownRemaining(identifier)
    if remaining > 0 then return nil, "contract_cooldown", remaining end

    if math.floor(_API.Player.GetDirtyMoney(src) or 0) < cfg.MinHandover then return nil, "insufficient_dirty_cash" end

    return identifier
end

--- Callback: starts a shift.
---@param src integer
lib.callback.register("t1ger_moneywash:server:contracts:startShift", function(src)
    return guarded(src, function()
        local identifier, reason, remaining = validateStart(src)
        if not identifier then return { success = false, reason = reason, remaining = remaining } end

        local shift = { src = src, identifier = identifier, handovers = 0, cleaned = 0, paid = 0 }
        scheduleNextDrop(shift)
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

        endShift(shift, "player")

        return { success = true, cooldown = getCooldownRemaining(shift.identifier) }
    end)
end)

--- Moves a shift along: a missed drop ends it, a new drop is assigned while dirty cash is left.
---@param shift ContractShift
---@param now integer
local function tickShift(shift, now)
    if shift.drop then
        if now > shift.drop.expiresAt then endShift(shift, "missed") end
    elseif now >= shift.nextDropAt then
        if math.floor(_API.Player.GetDirtyMoney(shift.src) or 0) < cfg.MinHandover then
            endShift(shift, "no_dirty_cash")
        else
            assignDrop(shift)
        end
    end
end

--- Ends the shift of a player who died or left, and moves the others along.
CreateThread(function()
    while true do
        Wait(next(Shifts) and 5000 or 10000)

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