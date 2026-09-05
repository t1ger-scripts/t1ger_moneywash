---@class MoneyWashReputation
---@field source number             -- Player's server ID
---@field identifier string         -- Player identifier (e.g., license)
---@field points integer            -- Reputation Points
---@field contracts integer         -- Total completed street contracts
---@field totalWashed number        -- Lifetime amount of dirty money laundered
---@field title string              -- Player's reputation title

-- MoneyWashReputation class
MoneyWashReputation = {}
MoneyWashReputation.__index = MoneyWashReputation

---Creates a new MoneyWashReputation instance for a player
---@param src number
---@param data { points: integer, contracts: integer, total_washed: number }
---@return MoneyWashReputation
function MoneyWashReputation:Create(src, data)
    local self = setmetatable({}, MoneyWashReputation)

    self.source = src
    self.identifier = _API.Player.GetIdentifier(src)
    self.points = data.points or 0
    self.contracts = data.contracts or 0
    self.totalWashed = data.total_washed or 0
    self.title = self:GetTitle()

    return self
end

---Returns current reputation points
---@return integer
function MoneyWashReputation:GetPoints()
    return self.points
end

---Returns total completed street contracts
---@return integer
function MoneyWashReputation:GetContracts()
    return self.contracts
end

---Returns lifetime amount of dirty money laundered
---@return number
function MoneyWashReputation:GetTotalWashed()
    return self.totalWashed
end

--- Returns current reputation title
--- @return string
function MoneyWashReputation:GetTitle()
    if not self.title then
        self:UpdateTitle()
    end
    return self.title
end

---Adds reputation points and syncs statebag
---@param amount number
function MoneyWashReputation:AddPoints(amount)
    local newPoints = self.points + amount
    self:SetPoints(newPoints)
end

---Removes reputation points (won't go below 0) and syncs statebag
---@param amount number
function MoneyWashReputation:RemovePoints(amount)
    local newPoints = math.max(0, self.points - amount)
    self:SetPoints(newPoints)
end

---Sets the reputation points directly and syncs statebag
---@param amount number
function MoneyWashReputation:SetPoints(amount)
    amount = math.floor(amount)
    self.points = amount
    Player(self.source).state:set("t1ger_moneywash:reputationPoints", amount, true)
    self:UpdateTitle()
end

---Increments the completed street contracts counter
function MoneyWashReputation:AddContract()
    self.contracts = self.contracts + 1
end

---Adds an amount to the lifetime total washed counter
---@param amount number
function MoneyWashReputation:AddWashed(amount)
    self.totalWashed = self.totalWashed + amount
end

---Updates the reputation title
function MoneyWashReputation:UpdateTitle()
    local newTitle = "Unknown"
    local thresholds = {}
    for k in pairs(Config.Reputation.Levels) do
        table.insert(thresholds, k)
    end
    table.sort(thresholds)

    for _, threshold in ipairs(thresholds) do
        if self.points >= threshold then
            newTitle = Config.Reputation.Levels[threshold]
        else
            break
        end
    end

    if self.title ~= newTitle then
        self.title = newTitle
        Player(self.source).state:set("t1ger_moneywash:reputationTitle", newTitle, true)
    end
end

---Saves reputation data to database
function MoneyWashReputation:Save()
    MySQL.update("UPDATE t1ger_moneywash SET points = ?, contracts = ?, total_washed = ? WHERE identifier = ?", {
        self.points, self.contracts, self.totalWashed, self.identifier
    })
end

---@type table<number, MoneyWashReputation>
local PlayerReputation = {}

---Returns the MoneyWashReputation object for the given player source.
---@param src number
---@return MoneyWashReputation?
function GetPlayerReputation(src)
    return PlayerReputation[src]
end
exports("GetPlayerReputation", GetPlayerReputation)

---Returns a table of basic reputation stats for a given player.
---@param src number
---@return { points: integer, contracts: integer, totalWashed: number, title: string }?
function GetReputationData(src)
    local rep = PlayerReputation[src]
    if not rep then return nil end

    return {
        points = rep:GetPoints(),
        contracts = rep:GetContracts(),
        totalWashed = rep:GetTotalWashed(),
        title = rep:GetTitle()
    }
end
exports("GetReputationData", GetReputationData)

---Adds reputation points to a player
---@param src number
---@param amount number
---@return boolean success
function AddReputationPoints(src, amount)
    local rep = GetPlayerReputation(src)
    if rep and type(amount) == "number" then
        rep:AddPoints(amount)
        return true
    end
    return false
end
exports("AddReputationPoints", AddReputationPoints)

---Removes reputation points from a player (min 0)
---@param src number
---@param amount number
---@return boolean success
function RemoveReputationPoints(src, amount)
    local rep = GetPlayerReputation(src)
    if rep and type(amount) == "number" then
        rep:RemovePoints(amount)
        return true
    end
    return false
end
exports("RemoveReputationPoints", RemoveReputationPoints)

---Sets a player's reputation points directly
---@param src number
---@param amount number
---@return boolean success
function SetReputationPoints(src, amount)
    local rep = GetPlayerReputation(src)
    if rep and type(amount) == "number" then
        rep:SetPoints(amount)
        return true
    end
    return false
end
exports("SetReputationPoints", SetReputationPoints)

---Loads a player's reputation from the database and stores it in memory.
---@param src number
function LoadReputation(src)
    if type(src) ~= "number" then return end

    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return end

    -- Attempt to fetch reputation data
    local result = MySQL.single.await("SELECT points, contracts, total_washed FROM t1ger_moneywash WHERE identifier = ?", {identifier})

    -- Create default data if none exists
    if not result then
        MySQL.insert.await("INSERT INTO t1ger_moneywash (identifier, points, contracts, total_washed) VALUES (?, ?, ?, ?)", {identifier, 0, 0, 0})
        result = { points = 0, contracts = 0, total_washed = 0 }
    end

    -- Create and store the MoneyWashReputation object
    local rep = MoneyWashReputation:Create(src, result)
    PlayerReputation[src] = rep

    -- Sync points to client using statebag
    Player(src).state:set("t1ger_moneywash:reputationPoints", rep.points, true)
end

---Saves the player's reputation data to the database
---@param src number
function SavePlayerReputation(src)
    local rep = PlayerReputation[src]
    if rep then
        rep:Save()
    end
end

---Saves all reputation objects to the database
function SaveAllReputation()
    for src, rep in pairs(PlayerReputation) do
        if rep and type(rep.Save) == "function" then
            rep:Save()
        end
    end
end

---Removes the player's reputation data from memory on disconnect.
---@param src number
function UnloadReputation(src)
    PlayerReputation[src] = nil
end

--- Return reputation title by given points
--- @param points number
--- @return string title
function GetReputationTitle(points)
    local title = "Unknown"
    local thresholds = {}
    for k in pairs(Config.Reputation.Levels) do
        table.insert(thresholds, k)
    end
    table.sort(thresholds)

    for _, threshold in ipairs(thresholds) do
        if points >= threshold then
            title = Config.Reputation.Levels[threshold]
        else
            break
        end
    end

    return title
end

--- Callback to return reputation data
lib.callback.register("t1ger_moneywash:server:getReputationData", function(source)
    return GetReputationData(source)
end)

---Save data every x minutes
if Config.Reputation.AutosaveInterval and Config.Reputation.AutosaveInterval > 0 then
    local cronExpr = "*/" .. tostring(Config.Reputation.AutosaveInterval) .. " * * * *"
    lib.cron.new(cronExpr, function()
        SaveAllReputation()
        print(("[Reputation] Autosaved every %d minutes"):format(Config.Reputation.AutosaveInterval))
    end)
end

AddEventHandler("playerDropped", function()
    local src = source
    SavePlayerReputation(src)
    UnloadReputation(src)
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
	SaveAllReputation()
end)

AddEventHandler("txAdmin:events:scheduledRestart", function(eventData)
    if eventData.secondsRemaining ~= 60 then return end
	SaveAllReputation()
end)

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		SaveAllReputation()
	end
end)