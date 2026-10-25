--- Launder contracts (server). A shift is one player working one contract, kept in memory only.
--- A shift ends by the player's choice, a death, a disconnect or a resource stop. Ending it by choice
--- or by disconnecting starts a cooldown, so the first drop can't be rerolled for free.

local CLIENT_EVENT = "t1ger_moneywash:client:contractShiftEnded"

---@class ContractShift
---@field src integer
---@field identifier string
---@field contractId string
---@field handovers integer Completed handovers
---@field cleaned integer Dirty cash handed over
---@field paid integer Clean money paid out

---@type table<integer, ContractShift> Active shifts by player source
local Shifts = {}

---@type table<string, integer> os.time() a player can start a shift again, by identifier
local Cooldowns = {}

---@type table<integer, boolean> Players inside a callback, stops double clicks
local Busy = {}

---@param contractId any
---@return table|nil contract Entry of Config.Contracts.List
local function getContract(contractId)
    for _, contract in ipairs(Config.Contracts.List) do
        if contract.Id == contractId then return contract end
    end
end

---@param identifier string
---@return integer seconds 0 when the player can start
local function getCooldownRemaining(identifier)
    local remaining = (Cooldowns[identifier] or 0) - os.time()
    if remaining > 0 then return remaining end

    Cooldowns[identifier] = nil

    return 0
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
---@param reason "player"|"died"|"dropped"|"stopped"
local function endShift(shift, reason)
    Shifts[shift.src] = nil

    if reason == "player" or reason == "dropped" then
        local contract = getContract(shift.contractId)
        Cooldowns[shift.identifier] = os.time() + (contract and contract.Cooldown or 0)
    end

    if reason == "died" then TriggerClientEvent(CLIENT_EVENT, shift.src, reason) end

    RunHook("OnContractShiftEnded", shift.identifier, shift.contractId, reason, shift.handovers, shift.cleaned, shift.paid)
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
---@param contractId any
---@return table|nil contract
---@return string|nil identifier Or the reason when the contract is nil
---@return integer? remaining Cooldown seconds, only with "contract_cooldown"
local function validateStart(src, contractId)
    local contract = getContract(contractId)
    if not contract then return nil, "invalid_contract" end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return nil, "unknown" end
    if Shifts[src] then return nil, "contract_active" end

    if Config.Reputation.Enable then
        local reputation = GetPlayerReputation(src)
        if not reputation then return nil, "reputation_not_ready" end
        if reputation:GetPoints() < contract.RequiredReputation then return nil, "insufficient_reputation" end
    end

    local remaining = getCooldownRemaining(identifier)
    if remaining > 0 then return nil, "contract_cooldown", remaining end

    if math.floor(_API.Player.GetDirtyMoney(src) or 0) < contract.MinHandover then return nil, "insufficient_dirty_cash" end

    return contract, identifier
end

--- Callback: starts a shift.
---@param src integer
---@param contractId string
lib.callback.register("t1ger_moneywash:server:contracts:startShift", function(src, contractId)
    return guarded(src, function()
        local contract, identifier, remaining = validateStart(src, contractId)
        if not contract then return { success = false, reason = identifier, remaining = remaining } end

        Shifts[src] = { src = src, identifier = identifier, contractId = contract.Id, handovers = 0, cleaned = 0, paid = 0 }

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

--- Ends the shift of a player who died or left the server.
CreateThread(function()
    while true do
        Wait(next(Shifts) and 5000 or 10000)

        for src, shift in pairs(Shifts) do
            if not GetPlayerName(src) then
                endShift(shift, "dropped")
            elseif GetEntityHealth(GetPlayerPed(src)) <= 0 then
                endShift(shift, "died")
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