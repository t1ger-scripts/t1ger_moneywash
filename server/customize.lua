--- ============================================================================
--- Server Customize
--- OPEN FILE - safe to edit without touching core logic.
--- Hook functions called by the business system at key moments.
--- Replace these with your own dispatch system, logging, or integrations.
--- ============================================================================

--- Called after every launder action
--- @param business table the business state at time of launder
--- @param amount number gross amount laundered
--- @param coveredAmount number clean covered funds added to Safe
--- @param exposedAmount number clean exposed funds added to Safe
function OnMoneyLaundered(business, amount, coveredAmount, exposedAmount)
    -- Example: Discord log, external stat tracking, etc.
end

--- Called when a business is successfully purchased
--- @param identifier string new owner identifier
--- @param businessType string
--- @param locationId number
--- @param price number amount paid
function OnBusinessPurchased(identifier, businessType, locationId, price)
end

--- Called when a business is raided
--- @param business table
--- @param seizedAmount number exposed funds confiscated
--- @param policeSrc number|nil source of the raiding officer, nil if queue-triggered
function OnBusinessRaided(business, seizedAmount, policeSrc)
end

--- Called when a bank deposit clears into the player's personal bank
--- @param identifier string
--- @param amount number
function OnDepositCleared(identifier, amount)
end

--- Called when a business is permanently seized via raid escalation
--- @param businessType string
--- @param locationId number
function OnBusinessSeized(businessType, locationId)
end

--- Sends a police notification for suspicious laundering activity
--- Replace with your own dispatch system (ps-dispatch, cd_dispatch, etc.)
--- @param business table
--- @param suspicionLabel string "Moderate" | "High" | "Critical"
--- @param coords vector4|nil
function SendPoliceNotification(business, suspicionLabel, coords)
    local messages = {
        Moderate = ("Unusual financial activity reported near %s"):format(business.type),
        High     = ("Suspicious business activity flagged at %s"):format(business.type),
        Critical = ("High-risk laundering activity detected at %s"):format(business.type),
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

--- Sends a police notification when a raid is queued (suspicion hit 100)
--- Replace with your own dispatch system
--- @param business table
--- @param coords vector4|nil
function SendRaidAlert(business, coords)
    local message = ("Suspicious activity at %s — respond immediately"):format(business.type)

    for _, player in ipairs(_API.GetOnlinePlayers()) do
        local job = _API.Player.GetJob(player.source)
        if job then
            for _, policeJob in ipairs(Config.Police.Jobs) do
                if job.name == policeJob then
                    _API.SendNotification(player.source, message, "error")
                    break
                end
            end
        end
    end
end

--- Sends a police notification when a bank deposit is flagged
--- Replace with your own dispatch system
--- @param identifier string depositing player identifier
--- @param amount number
--- @param bankLocation vector4
function SendDepositFlagNotification(identifier, amount, bankLocation)
    local message = ("Large cash deposit flagged at bank — $%d"):format(amount)

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
