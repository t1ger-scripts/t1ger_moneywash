--- Client copy of the player's reputation, kept in sync by the server.

---@class PlayerReputation
---@field points integer Total reputation points
---@field level string Current reputation level title

---@type { points: integer, title: string }
local reputation = { points = 0, title = "" }

--- Returns the player's reputation points.
---@return integer points
function GetPlayerReputationPoints()
    return reputation.points
end
exports("GetPlayerReputationPoints", GetPlayerReputationPoints)

--- Returns the player's reputation points and level title.
---@return PlayerReputation
function GetPlayerReputation()
    return {
        points = reputation.points,
        level  = reputation.title,
    }
end
exports("GetPlayerReputation", GetPlayerReputation)

--- The server sends the current reputation when it changes.
---@param points integer
---@param title string
RegisterNetEvent("t1ger_moneywash:client:reputationSync", function(points, title)
    reputation.points = points
    reputation.title  = title

    if Config.Debug then
        print(("[MoneyWash] Reputation synced: %d points | %s"):format(points, title))
    end
end)