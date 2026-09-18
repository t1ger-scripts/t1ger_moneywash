--- ============================================================================
--- Client Functions
--- Shared client-side helpers used across all client files.
--- ============================================================================

--- -------------------------------------------------------------------------
--- JOB CHECKS
--- -------------------------------------------------------------------------

--- Returns whether the player's current job is a police job
--- @return boolean
function IsPoliceJob()
    local job = _API.Player:GetJob()
    if not job or not job.name then return false end
    for _, policeJob in ipairs(Config.PoliceJobs) do
        if job.name == policeJob then return true end
    end
    return false
end

--- Returns whether the player meets the minimum grade for a police action
--- @param minGrade number
--- @return boolean
function IsPoliceJobWithGrade(minGrade)
    if not IsPoliceJob() then return false end
    local job = _API.Player:GetJob()
    return (job.grade or 0) >= minGrade
end

--- Returns whether the player can interact with the Accountant NPC
--- Police jobs cannot interact at all
--- @param entity number
--- @return boolean
function CanInteractWithAccountantNPC(entity)
    if IsPoliceJob() then return false end
    if not IsEntityValid(entity) or GetEntityType(entity) == 0 then return false end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
    return true
end

--- Returns whether the player can interact with a Handler NPC they own
--- Police jobs cannot interact
--- @param entity number
--- @return boolean
function CanInteractWithHandlerNPC(entity)
    if IsPoliceJob() then return false end
    if not IsEntityValid(entity) or GetEntityType(entity) == 0 then return false end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
    return true
end

--- Returns whether a police player can raid a Handler NPC
--- @param entity number
--- @return boolean
function CanPoliceRaidBusiness(entity)
    if not IsPoliceJobWithGrade(Config.Police.RaidMinGrade) then return false end
    if not IsEntityValid(entity) or GetEntityType(entity) == 0 then return false end
    return true
end

--- Returns whether a police player can review deposits at a bank teller
--- @param entity number
--- @return boolean
function CanPoliceReviewDeposits(entity)
    if not IsPoliceJobWithGrade(Config.Police.DepositReviewMinGrade) then return false end
    if not IsEntityValid(entity) or GetEntityType(entity) == 0 then return false end
    return true
end

--- -------------------------------------------------------------------------
--- BLIPS
--- -------------------------------------------------------------------------

--- Creates a blip and returns the handle
--- @param coords vector3|vector4
--- @param sprite number
--- @param display number
--- @param scale number
--- @param color number
--- @param label string
--- @return number blipHandle
function CreateMapBlip(coords, sprite, display, scale, color, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, display or 4)
    SetBlipScale(blip, scale or 1.0)
    SetBlipColour(blip, color or 0)
    SetBlipAsShortRange(blip, true)
    if type(label) == "string" then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(label)
        EndTextCommandSetBlipName(blip)
    end
    return blip
end

--- Safely removes a blip if it exists
--- @param blipHandle number
function RemoveMapBlip(blipHandle)
    if blipHandle and DoesBlipExist(blipHandle) then
        RemoveBlip(blipHandle)
    end
end

--- -------------------------------------------------------------------------
--- PEDS
--- -------------------------------------------------------------------------

--- Spawns a static NPC ped with standard settings
--- @param model string
--- @param coords vector4
--- @param scenario string|nil
--- @return number pedHandle
function SpawnStaticPed(model, coords, scenario)
    lib.requestModel(model)
    local ped = CreatePed(6, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end
    return ped
end

--- Safely deletes a ped entity
--- @param pedHandle number
function DeletePed(pedHandle)
    if pedHandle and DoesEntityExist(pedHandle) then
        SetEntityAsMissionEntity(pedHandle, false, true)
        DeleteEntity(pedHandle)
    end
end

--- -------------------------------------------------------------------------
--- PROPS
--- -------------------------------------------------------------------------

--- Spawns a prop and optionally attaches it to the player
--- @param model string
--- @param coords vector3
--- @param attach boolean attach to player ped
--- @param boneIndex number|nil bone to attach to (default 28422 = right hand)
--- @return number propHandle
function SpawnProp(model, coords, attach, boneIndex)
    lib.requestModel(model)
    local prop = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z, true, true, true)
    SetEntityAsMissionEntity(prop, true, true)
    if attach then
        local bone = boneIndex or 28422 -- right hand
        AttachEntityToEntity(prop, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), bone),
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    end
    return prop
end

--- Safely deletes a prop entity
--- @param propHandle number
function DeleteProp(propHandle)
    if propHandle and DoesEntityExist(propHandle) then
        SetEntityAsMissionEntity(propHandle, false, true)
        DeleteEntity(propHandle)
    end
end

--- -------------------------------------------------------------------------
--- DISTANCE
--- -------------------------------------------------------------------------

--- Returns whether the player is within a given distance of coords
--- @param coords vector3|vector4
--- @param maxDistance number
--- @return boolean
function IsNearCoords(coords, maxDistance)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    return #(pedCoords - vector3(coords.x, coords.y, coords.z)) <= maxDistance
end

--- -------------------------------------------------------------------------
--- FORMATTING
--- -------------------------------------------------------------------------

--- Formats a number as a currency string
--- @param amount number
--- @return string e.g. "$1,500"
function FormatMoney(amount)
    local formatted = tostring(math.floor(amount))
    local result = ""
    local count = 0
    for i = #formatted, 1, -1 do
        if count > 0 and count % 3 == 0 then
            result = "," .. result
        end
        result = formatted:sub(i, i) .. result
        count = count + 1
    end
    return Config.Currency .. result
end