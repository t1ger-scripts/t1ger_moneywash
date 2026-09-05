--- Active exchange sessions, keyed by player source.
--- Each session holds everything the server decided - the client never dictates any of this.
---@type table<number, { location: vector4, model: string, amount: number, expiresAt: number }>
local ActiveExchange = {}

--- Cooldown expiry timestamps, keyed by player identifier (persists across reconnects within session lifetime).
---@type table<string, number>
local Cooldowns = {}

--- Returns the maximum amount a player is trusted to exchange, based on their reputation points.
--- @param src number
--- @return number maxAmount
local function GetPlayerTrustLimit(src)
    local fallback = Config.RunnerExchange.AmountLimits.max

    if not Config.Reputation.Enable then return fallback end

    local rep = GetPlayerReputation(src)
    if not rep then return fallback end

    local points = rep:GetPoints()
    local limit = fallback
    local thresholds = {}

    for k in pairs(Config.RunnerExchange.TrustLimits) do
        table.insert(thresholds, k)
    end
    table.sort(thresholds)

    for _, threshold in ipairs(thresholds) do
        if points >= threshold then
            limit = Config.RunnerExchange.TrustLimits[threshold]
        else
            break
        end
    end

    return limit
end

--- Checks whether the given identifier is currently on cooldown.
--- @param identifier string
--- @return boolean onCooldown, integer remainingSeconds
local function IsOnCooldown(identifier)
    local expiresAt = Cooldowns[identifier]
    if not expiresAt then return false, 0 end

    local remaining = expiresAt - os.time()
    if remaining <= 0 then
        Cooldowns[identifier] = nil
        return false, 0
    end

    return true, remaining
end

--- Starts the global Runner Exchange cooldown for the given identifier.
--- @param identifier string
local function StartCooldown(identifier)
    if not Config.RunnerExchange.Cooldown.enable then return end
    Cooldowns[identifier] = os.time() + (Config.RunnerExchange.Cooldown.duration * 60)
end

--- Clears an active session for the given source, if any.
--- @param src number
local function ClearSession(src)
    ActiveExchange[src] = nil
end

--- Callback: player requests a new Runner Exchange session.
--- @param source number
--- @param amount number Requested dirty cash amount to exchange
lib.callback.register("t1ger_moneywash:server:requestRunnerExchange", function(source, amount)
    local src = source

    if not Config.RunnerExchange.Enable then
        return {success = false, reason = "disabled"}
    end

    if ActiveExchange[src] then
        return {success = false, reason = "already_active"}
    end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then
        return {success = false, reason = "invalid_player"}
    end

    local onCooldown, remaining = IsOnCooldown(identifier)
    if onCooldown then
        return {success = false, reason = "cooldown", remaining = remaining}
    end

    if Config.RunnerExchange.RequiredPolice.enable then
        local policeCount = GetOnDutyPoliceCount()
        if policeCount < Config.RunnerExchange.RequiredPolice.minimum then
            return {success = false, reason = "not_enough_police"}
        end
    end

    -- Validate amount server-side - never trust the client's number beyond using it as a request value
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) then
        return {success = false, reason = "invalid_amount"}
    end

    local maxAllowed = GetPlayerTrustLimit(src)
    if amount < Config.RunnerExchange.AmountLimits.min or amount > maxAllowed then
        return {success = false, reason = "invalid_amount", min = Config.RunnerExchange.AmountLimits.min, max = maxAllowed}
    end

    -- Confirm the player actually has the dirty cash to offer
    if not HasDirtyMoney(src, amount) then
        return {success = false, reason = "insufficient_cash"}
    end

    -- Build the session - location/model are picked server-side only
    local location = Config.RunnerExchange.RunnerLocations[math.random(1, #Config.RunnerExchange.RunnerLocations)]
    local model = Config.RunnerExchange.RunnerModels[math.random(1, #Config.RunnerExchange.RunnerModels)]
    local expiresAt = os.time() + Config.RunnerExchange.Timer.duration

    ActiveExchange[src] = {
        location = location,
        model = model,
        amount = amount,
        expiresAt = expiresAt
    }

    return {
        success = true,
        location = location,
        model = model,
        duration = Config.RunnerExchange.Timer.duration
    }
end)

--- Callback: player has reached the runner and wants to finalize the exchange.
--- The outcome (success/hustle) is entirely decided here - the client only reacts to the result.
--- @param source number
lib.callback.register("t1ger_moneywash:server:finalizeRunnerExchange", function(source)
    local src = source
    local session = ActiveExchange[src]

    if not session then
        return {success = false, reason = "no_session"}
    end

    local identifier = _API.Player.GetIdentifier(src)

    if os.time() > session.expiresAt then
        ClearSession(src)
        if identifier then StartCooldown(identifier) end
        return {success = false, reason = "expired"}
    end

    if not IsPlayerNearCoords(src, session.location, 5.0) then
        return {success = false, reason = "too_far"}
    end

    -- Re-verify the player still actually holds the dirty cash (could've been removed/traded since the request)
    if not HasDirtyMoney(src, session.amount) then
        ClearSession(src)
        if identifier then StartCooldown(identifier) end
        return {success = false, reason = "insufficient_cash"}
    end

    -- Roll the hustle chance server-side - never influenced by the client
    local hustleRoll = math.random(1, 100)
    local isHustle = hustleRoll <= Config.RunnerExchange.Hustle.chance

    ClearSession(src)
    if identifier then StartCooldown(identifier) end

    if isHustle then
        local weapon = Config.RunnerExchange.Hustle.weapons[math.random(1, #Config.RunnerExchange.Hustle.weapons)]
        return {success = true, outcome = "hustle", weapon = weapon}
    end

    -- Successful exchange: remove dirty cash, pay out clean money minus commission
    local commission = Config.RunnerExchange.Commission
    local cleanAmount = math.floor(session.amount * (1 - (commission / 100)))

    RemoveDirtyMoney(src, session.amount)
    _API.Player.AddMoney(src, cleanAmount, "bank")

    if Config.Reputation.Enable and Config.RunnerExchange.ReputationReward > 0 then
        AddReputationPoints(src, Config.RunnerExchange.ReputationReward)
    end

    return {success = true, outcome = "success", cleanAmount = cleanAmount, commission = commission}
end)

--- Event: player manually cancels an active Runner Exchange session.
--- Registered as a protected server event - only reads `source`, no client-supplied parameters to trust.
RegisterServerEvent("t1ger_moneywash:server:cancelRunnerExchange")
AddEventHandler("t1ger_moneywash:server:cancelRunnerExchange", function()
    local src = source
    local session = ActiveExchange[src]
    if not session then return end

    local identifier = _API.Player.GetIdentifier(src)

    if Config.RunnerExchange.CancelPenalty.enable and Config.Reputation.Enable then
        RemoveReputationPoints(src, Config.RunnerExchange.CancelPenalty.reputationLoss)
    end

    ClearSession(src)
    if identifier then StartCooldown(identifier) end
end)

--- Periodically sweeps for expired sessions in case a client never calls finalize
--- (disconnects, alt-tabs, walks away). Ensures cooldown always starts on expiry.
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, session in pairs(ActiveExchange) do
            if now > session.expiresAt then
                local identifier = _API.Player.GetIdentifier(src)
                ClearSession(src)
                if identifier then StartCooldown(identifier) end
                TriggerClientEvent("t1ger_moneywash:client:runnerExchangeExpired", src)
            end
        end
    end
end)

--- Cleans up any active session when a player disconnects.
AddEventHandler("playerDropped", function()
    local src = source
    ClearSession(src)
end)