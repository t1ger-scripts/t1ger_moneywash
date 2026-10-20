---@class PlayerReputation
---@field points integer  -- Total reputation points
---@field level string    -- Current reputation level title

local reputation = { points = 0, title = "" }

--- Returns the player's current reputation points.
--- @return integer points
function GetPlayerReputationPoints()
    return reputation.points
end
exports("GetPlayerReputationPoints", GetPlayerReputationPoints)

--- Returns the player's reputation points and level title.
--- @return PlayerReputation
function GetPlayerReputation()
    return {
        points = reputation.points,
        level  = reputation.title,
    }
end
exports("GetPlayerReputation", GetPlayerReputation)

RegisterNetEvent("t1ger_moneywash:client:reputationSync", function(points, title)
    reputation.points = points
    reputation.title  = title

    if Config.Debug then
        print(("[MoneyWash] Reputation synced: %d points | %s"):format(points, title))
    end
end)