--- Returns the number of currently on-duty players whose job matches Config.Police.Jobs.
--- @return integer count
function GetOnDutyPoliceCount()
    local count = 0
    local players = _API.GetOnlinePlayers()

    for _, playerData in ipairs(players) do
        local job = playerData.job
        if job and job.onDuty then
            for _, policeJob in ipairs(Config.Police.Jobs) do
                if job.name == policeJob then
                    count = count + 1
                    break
                end
            end
        end
    end

    return count
end

--- Checks whether the given player's coordinates are within range of a target vector.
--- @param src number Player source
--- @param target vector3|vector4 Target coordinates
--- @param maxDistance number Maximum allowed distance
--- @return boolean withinRange
function IsPlayerNearCoords(src, target, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    local dist = #(playerCoords - vector3(target.x, target.y, target.z))

    return dist <= (maxDistance or 5.0)
end
