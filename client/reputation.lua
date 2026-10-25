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

--- Returns the player's reputation points and level title.
---@return PlayerReputation
function GetPlayerReputation()
    return {
        points = reputation.points,
        level  = reputation.title,
    }
end

exports("GetPlayerReputation", function(src)
    local reputation = PlayerReputation[src]
    if not reputation then return nil end

    return { points = reputation.points, level = reputation.title }
end)

--- The server sends the current reputation when it changes.
---@param points integer
---@param title string
RegisterNetEvent("t1ger_moneywash:client:reputationSync", function(points, title)
    reputation.points = points
    reputation.title  = title

    DebugPrint("reputation", ("synced %d points | %s"):format(points, title))
end)