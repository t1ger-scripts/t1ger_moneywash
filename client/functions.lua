--- Checks whether the player's current job is listed as a police job in config.
--- @return boolean isPolice `true` if the player's job is a police job, `false` otherwise
function IsPoliceJob()
    local job = _API.Player:GetJob()
    if not job or not job.name then return false end

    for _, policeJob in ipairs(Config.PoliceJobs) do
        if job.name == policeJob then
            return true
        end
    end

    return false
end

--- Determines whether the player can interact with the Accountant NPC.
--- Police jobs are never allowed to interact with the Accountant.
--- @param entity number The NPC entity handle
--- @return boolean canInteract
function CanInteractWithAccountantNPC(entity)
    if IsPoliceJob() then return false end

    if IsEntityValid(entity) and GetEntityType(entity) ~= 0 then
        if not IsPedInAnyVehicle(player, false) and not IsPedInAnyVehicle(player, true) then
            return true
        end
    end

    return false
end

--- Creates a blip on the map and returns the blip handle
--- @param pos vector3|vector4
--- @param sprite integer
--- @param display integer
--- @param scale number
--- @param color integer
--- @param label string
--- @return integer #The blip handle
function CreateMapBlip(pos, sprite, display, scale, color, label)
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, display or 4)
    SetBlipScale(blip, scale or 1.0)
    SetBlipColour(blip, color or 0)
    SetBlipAsShortRange(blip, true)

    if type(label) == "string" then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(label or "Blip")
        EndTextCommandSetBlipName(blip)
    end

    return blip
end