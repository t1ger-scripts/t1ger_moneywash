--- ============================================================================
--- Server Reputation
--- OOP reputation class, DB load/save, owner-only client sync and exports.
--- Lifecycle events (playerDropped, autosave, shutdown) are handled in
--- server/main.lua — not here — to avoid double-firing.
--- ============================================================================

--- Resolves level data for a points value. Single source for the title,
--- thresholds and progress used by the class and the portal.
---@param points integer
---@return { title: string, currentPoints: integer, nextPoints: integer|nil, progress: integer }
function GetReputationLevel(points)
    local thresholds = {}
    for threshold in pairs(Config.Reputation.Levels) do
        thresholds[#thresholds + 1] = tonumber(threshold)
    end
    table.sort(thresholds)

    local current = thresholds[1] or 0
    local nextPoints = nil

    for _, threshold in ipairs(thresholds) do
        if points >= threshold then
            current = threshold
        else
            nextPoints = threshold
            break
        end
    end

    local progress = 100
    if nextPoints then
        progress = math.floor(((points - current) / (nextPoints - current)) * 100)
    end

    return {
        title         = Config.Reputation.Levels[current] or Config.Reputation.Levels[0] or "Unranked",
        currentPoints = current,
        nextPoints    = nextPoints,
        progress      = math.max(0, math.min(100, progress)),
    }
end

---@class MoneyWashReputation
---@field source number
---@field identifier string
---@field points integer
---@field title string

MoneyWashReputation = {}
MoneyWashReputation.__index = MoneyWashReputation

--- Creates a new MoneyWashReputation instance for a player
--- @param src number
--- @param data { points: integer }
--- @return MoneyWashReputation
function MoneyWashReputation:Create(src, data)
    local self = setmetatable({}, MoneyWashReputation)

    self.source     = src
    self.identifier = _API.Player.GetIdentifier(src)
    self.points     = data.points or 0
    self.title      = self:_ResolveTitle()

    return self
end

--- Returns current reputation points
--- @return integer
function MoneyWashReputation:GetPoints()
    return self.points
end

--- Returns current reputation title
--- @return string
function MoneyWashReputation:GetTitle()
    return self.title
end

--- Adds reputation points and syncs the owner's client
--- @param amount number
function MoneyWashReputation:AddPoints(amount)
    self:SetPoints(self.points + amount)
end

--- Removes reputation points (floor 0) and syncs the owner's client
--- @param amount number
function MoneyWashReputation:RemovePoints(amount)
    self:SetPoints(math.max(0, self.points - amount))
end

--- Sets reputation points directly and syncs the owner's client
--- @param amount number
function MoneyWashReputation:SetPoints(amount)
    self.points = math.max(0, math.floor(amount))
    self.title  = self:_ResolveTitle()
    self:Sync()
    RefreshPortalViewer(self.source)
end

--- Saves reputation to DB
function MoneyWashReputation:Save()
    MySQL.update("UPDATE moneywash_reputation SET points = ? WHERE identifier = ?", {
        self.points,
        self.identifier
    })
end

--- Resolves and returns the correct title for current points (no statebag sync)
--- @return string
function MoneyWashReputation:_ResolveTitle()
    return GetReputationLevel(self.points).title
end

--- Sends points and title to the owning client only
function MoneyWashReputation:Sync()
    TriggerClientEvent("t1ger_moneywash:client:reputationSync", self.source, self.points, self.title)
end

--- ============================================================================
--- PLAYER REGISTRY
--- ============================================================================

---@type table<number, MoneyWashReputation>
local PlayerReputation = {}

---@type table<string, integer>
local PendingPoints = {} -- identifier -> points earned while the profile was still loading

--- Returns the reputation object for a player
--- @param src number
--- @return MoneyWashReputation|nil
function GetPlayerReputation(src)
    return PlayerReputation[src]
end
exports("GetPlayerReputation", GetPlayerReputation)

--- Returns whether a player's reputation has finished loading from DB.
--- @param src number
--- @return boolean
function IsReputationReady(src)
    return PlayerReputation[src] ~= nil
end
exports("IsReputationReady", IsReputationReady)

--- Adds reputation points to a player
--- @param src number
--- @param amount number
--- @return boolean
function AddReputationPoints(src, amount)
    local rep = PlayerReputation[src]
    if not rep or type(amount) ~= "number" then return false end
    rep:AddPoints(amount)
    return true
end
exports("AddReputationPoints", AddReputationPoints)

--- Removes reputation points from a player
--- @param src number
--- @param amount number
--- @return boolean
function RemoveReputationPoints(src, amount)
    local rep = PlayerReputation[src]
    if not rep or type(amount) ~= "number" then return false end
    rep:RemovePoints(amount)
    return true
end
exports("RemoveReputationPoints", RemoveReputationPoints)

--- Sets a player's reputation points directly
--- @param src number
--- @param amount number
--- @return boolean
function SetReputationPoints(src, amount)
    local rep = PlayerReputation[src]
    if not rep or type(amount) ~= "number" then return false end
    rep:SetPoints(amount)
    return true
end
exports("SetReputationPoints", SetReputationPoints)

--- Applies queued points straight to the database (used when the player left before loading finished)
--- @param identifier string
local function flushPendingPoints(identifier)
    local pending = PendingPoints[identifier]
    if not pending then return end
    PendingPoints[identifier] = nil
    MySQL.update("UPDATE moneywash_reputation SET points = points + ? WHERE identifier = ?", { pending, identifier })
end

--- Awards points to a player whether they are loaded, still loading, or offline.
--- Loaded: applied in memory (saved by autosave/disconnect/shutdown).
--- Online but still loading: queued and applied when the profile finishes loading.
--- Offline: written straight to the database.
--- @param src number|nil
--- @param identifier string
--- @param amount number
function AwardReputationPoints(src, identifier, amount)
    if type(amount) ~= "number" or amount == 0 or not identifier then return end

    local rep = src and PlayerReputation[src]
    if rep then
        rep:AddPoints(amount)
    elseif src then
        PendingPoints[identifier] = (PendingPoints[identifier] or 0) + amount
    else
        MySQL.update("UPDATE moneywash_reputation SET points = points + ? WHERE identifier = ?", { amount, identifier })
    end
end

--- ============================================================================
--- LOAD / SAVE
--- ============================================================================

--- Loads a player's reputation from DB into memory and syncs statebags
--- @param src number
function LoadReputation(src)
    if type(src) ~= "number" then return end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return end

    local row = MySQL.single.await(
        "SELECT points FROM moneywash_reputation WHERE identifier = ?",
        {identifier}
    )

    if not row then
        MySQL.insert.await(
            "INSERT INTO moneywash_reputation (identifier, points) VALUES (?, 0)",
            {identifier}
        )
        row = {points = 0}
    end

    -- The player left while the profile was loading: don't register a stale entry
    -- (a reused server id would otherwise inherit this profile)
    if not GetPlayerName(src) then
        flushPendingPoints(identifier)
        return
    end

    local rep = MoneyWashReputation:Create(src, row)
    PlayerReputation[src] = rep

    -- Apply points earned while the profile was loading
    local pending = PendingPoints[identifier]
    if pending then
        PendingPoints[identifier] = nil
        rep:AddPoints(pending)
    end

    -- Sync to the owning client
    rep:Sync()

    if Config.Debug then
        print(("[MoneyWash] Reputation loaded: %s | %d points | %s"):format(
            identifier, rep.points, rep.title))
    end
end

--- Saves a single player's reputation to DB
--- @param src number
function SavePlayerReputation(src)
    local rep = PlayerReputation[src]
    if rep then rep:Save() end
end

--- Saves all reputation objects to DB
function SaveAllReputation()
    for _, rep in pairs(PlayerReputation) do
        if rep and type(rep.Save) == "function" then
            rep:Save()
        end
    end
end

--- Removes a player's reputation from memory on disconnect
--- @param src number
function UnloadReputation(src)
    PlayerReputation[src] = nil
end