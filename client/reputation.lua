---@class PlayerReputation
---@field points integer  -- Total reputation points
---@field level string    -- Current reputation level title

reputationPoints = LocalPlayer.state["t1ger_moneywash:reputationPoints"] or 0

--- Returns the player's current reputation points.
--- @return integer points # The player's reputation points (0 if none)
function GetPlayerReputationPoints()
    return LocalPlayer.state["t1ger_moneywash:reputationPoints"] or 0
end
exports("GetPlayerReputationPoints", GetPlayerReputationPoints)

--- Get the player's reputation points and level title.
--- @return PlayerReputation
function GetPlayerReputation()
    local points = GetPlayerReputationPoints() or 0
    local currentLevel = "None"

    local levels = {}
    for pts, title in pairs(Config.Reputation.Levels) do
        table.insert(levels, { points = pts, title = title })
    end
    table.sort(levels, function(a, b) return a.points < b.points end)

    for _, level in ipairs(levels) do
        if points >= level.points then
            currentLevel = level.title
        end
    end

    return {
        points = points,
        level = currentLevel
    }
end
exports("GetPlayerReputation", GetPlayerReputation)

--- Returns the player's reputation progress data.
--- @return { points: integer, levelPoints: integer, nextPoints: integer?, title: string, progress: integer, color: string }
function GetReputationData()
    local points = GetPlayerReputationPoints() or 0
    local currentLevelPoints = 0
    local currentTitle = "Unranked"
    local nextLevelPoints = nil

    local levels = {}
    for pts, title in pairs(Config.Reputation.Levels) do
        table.insert(levels, { points = pts, title = title })
    end
    table.sort(levels, function(a, b) return a.points < b.points end)

    for _, level in ipairs(levels) do
        if points >= level.points then
            currentLevelPoints = level.points
            currentTitle = level.title
        elseif not nextLevelPoints then
            nextLevelPoints = level.points
        end
    end

    local progress = 100
    if nextLevelPoints then
        progress = math.floor(((points - currentLevelPoints) / (nextLevelPoints - currentLevelPoints)) * 100)
    end

    -- Determine color scheme based on progress
    local color = "#16a34a" -- fallback color
    for _, entry in ipairs(Config.Reputation.ProgressColors) do
        if progress >= entry.threshold then
            color = entry.color
        else
            break
        end
    end

    return {
        points = points,
        levelPoints = currentLevelPoints,
        nextPoints = nextLevelPoints,
        title = currentTitle,
        progress = progress,
        color = color
    }
end

AddStateBagChangeHandler("t1ger_moneywash:reputationPoints", nil, function(bagName, key, value)
    local expectedBag = ("player:%s"):format(GetPlayerServerId(PlayerId()))
    if bagName == expectedBag then
        reputationPoints = value
        if Config.Debug then
            print("[MoneyWash] Updated local reputation points to:", reputationPoints)
        end
    end
end)