--- ============================================================================
--- Server Customize
--- ============================================================================

--- Sends a police notification for suspicious laundering activity
--- Replace with your own dispatch system (ps-dispatch, cd_dispatch, etc.)
--- @param business table
--- @param suspicionLabel string "Moderate" | "High" | "Critical" | "Max" (suspicion at 100)
--- @param coords vector4|nil
function SendPoliceNotification(business, suspicionLabel, coords)
    local messages = {
        Moderate = ("Unusual financial activity reported near %s"):format(business.type),
        High     = ("Suspicious business activity flagged at %s"):format(business.type),
        Critical = ("High-risk laundering activity detected at %s"):format(business.type),
        Max      = ("Laundering operation at %s is fully exposed - ready for a raid"):format(business.type),
    }

    local message = messages[suspicionLabel] or messages.Moderate

    -- Default: notify all online police job players
    for _, player in ipairs(_API.GetOnlinePlayers()) do
        local job = _API.Player.GetJob(player.source)
        if job then
            for _, policeJob in ipairs(Config.Police.Jobs) do
                if job.name == policeJob then
                    _API.SendNotification(player.source, message, "inform")
                    break
                end
            end
        end
    end
end

--- Sends a police notification for a flagged ATM deposit
--- @param identifier string depositor (not shown)
--- @param amount number gross amount
--- @param coords vector3 ATM location
function SendDepositFlagNotification(identifier, amount, coords)
    local message = ("Suspicious ATM deposit of %s%d flagged"):format(Config.Currency, amount)

    for _, player in ipairs(_API.GetOnlinePlayers()) do
        local job = player.job
        if job then
            for _, policeJob in ipairs(Config.Police.Jobs) do
                if job.name == policeJob then
                    _API.SendNotification(player.source, message, "inform")
                    break
                end
            end
        end
    end
end