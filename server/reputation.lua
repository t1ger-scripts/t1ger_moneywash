--- ============================================================================
--- Server Reputation
--- OOP reputation class, DB load/save, statebag sync and exports.
--- Lifecycle events (playerDropped, autosave, shutdown) are handled in
--- server/main.lua — not here — to avoid double-firing.
--- ============================================================================

---@class MoneyWashReputation
---@field source number
---@field identifier string
---@field points integer
---@field totalWashed number
---@field title string

MoneyWashReputation = {}
MoneyWashReputation.__index = MoneyWashReputation

--- Creates a new MoneyWashReputation instance for a player
--- @param src number
--- @param data { points: integer, total_washed: number }
--- @return MoneyWashReputation
function MoneyWashReputation:Create(src, data)
    local self = setmetatable({}, MoneyWashReputation)

    self.source     = src
    self.identifier = _API.Player.GetIdentifier(src)
    self.points     = data.points or 0
    self.totalWashed = data.total_washed or 0
    self.title      = self:_ResolveTitle()

    return self
end

--- Returns current reputation points
--- @return integer
function MoneyWashReputation:GetPoints()
    return self.points
end

--- Returns lifetime dirty money laundered
--- @return number
function MoneyWashReputation:GetTotalWashed()
    return self.totalWashed
end

--- Returns current reputation title
--- @return string
function MoneyWashReputation:GetTitle()
    return self.title
end

--- Adds reputation points and syncs statebag
--- @param amount number
function MoneyWashReputation:AddPoints(amount)
    self:SetPoints(self.points + amount)
end

--- Removes reputation points (floor 0) and syncs statebag
--- @param amount number
function MoneyWashReputation:RemovePoints(amount)
    self:SetPoints(math.max(0, self.points - amount))
end

--- Sets reputation points directly and syncs statebag
--- @param amount number
function MoneyWashReputation:SetPoints(amount)
    self.points = math.floor(amount)
    Player(self.source).state:set("t1ger_moneywash:reputationPoints", self.points, true)
    self:_SyncTitle()
end

--- Adds to the lifetime total washed counter
--- @param amount number
function MoneyWashReputation:AddWashed(amount)
    self.totalWashed = self.totalWashed + amount
end

--- Saves reputation to DB
function MoneyWashReputation:Save()
    MySQL.update(
        "UPDATE moneywash_reputation SET points = ?, total_washed = ? WHERE identifier = ?",
        {self.points, self.totalWashed, self.identifier}
    )
end

--- Resolves and returns the correct title for current points (no statebag sync)
--- @return string
function MoneyWashReputation:_ResolveTitle()
    local title = "Unknown"
    local thresholds = {}
    for k in pairs(Config.Reputation.Levels) do
        thresholds[#thresholds + 1] = k
    end
    table.sort(thresholds)
    for _, threshold in ipairs(thresholds) do
        if self.points >= threshold then
            title = Config.Reputation.Levels[threshold]
        else
            break
        end
    end
    return title
end

--- Updates title and syncs statebag if it changed
function MoneyWashReputation:_SyncTitle()
    local newTitle = self:_ResolveTitle()
    if self.title ~= newTitle then
        self.title = newTitle
        Player(self.source).state:set("t1ger_moneywash:reputationTitle", newTitle, true)
    end
end

--- ============================================================================
--- PLAYER REGISTRY
--- ============================================================================

---@type table<number, MoneyWashReputation>
local PlayerReputation = {}

--- Returns the reputation object for a player
--- @param src number
--- @return MoneyWashReputation|nil
function GetPlayerReputation(src)
    return PlayerReputation[src]
end
exports("GetPlayerReputation", GetPlayerReputation)

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
        "SELECT points, total_washed FROM moneywash_reputation WHERE identifier = ?",
        {identifier}
    )

    if not row then
        MySQL.insert.await(
            "INSERT INTO moneywash_reputation (identifier, points, total_washed) VALUES (?, 0, 0)",
            {identifier}
        )
        row = {points = 0, total_washed = 0}
    end

    local rep = MoneyWashReputation:Create(src, row)
    PlayerReputation[src] = rep

    -- Sync to client statebags
    Player(src).state:set("t1ger_moneywash:reputationPoints", rep.points, true)
    Player(src).state:set("t1ger_moneywash:reputationTitle",  rep.title,  true)

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

--- ============================================================================
--- CALLBACKS
--- ============================================================================

lib.callback.register("t1ger_moneywash:server:getReputationData", function(source)
    local rep = PlayerReputation[source]
    if not rep then return nil end
    return {
        points      = rep:GetPoints(),
        totalWashed = rep:GetTotalWashed(),
        title       = rep:GetTitle(),
    }
end)