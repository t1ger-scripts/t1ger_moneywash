--- Shared client helpers used across the client files.

--- Returns whether the player's job is one of Config.Police.Jobs.
---@return boolean
function IsPoliceJob()
    local job = _API.Player:GetJob()
    if not job or not job.name then return false end

    for _, policeJob in ipairs(Config.Police.Jobs) do
        if job.name == policeJob then return true end
    end

    return false
end

--- Returns whether the player is police and meets a minimum grade.
---@param minGrade number
---@return boolean
function IsPoliceJobWithGrade(minGrade)
    if not IsPoliceJob() then return false end

    local job = _API.Player:GetJob()
    return (job.grade or 0) >= minGrade
end

--- Returns whether an entity handle is valid and the entity exists.
---@param entity number|nil
---@return boolean
function IsEntityValid(entity)
    if not entity or entity == -1 then return false end
    return DoesEntityExist(entity)
end

--- Returns whether the player can use an owner option on a handler NPC.
--- Police can't (unless Config.Debug), nor can anyone inside a vehicle.
---@param entity number
---@return boolean
function CanInteractWithHandlerNPC(entity)
    if IsPoliceJob() and not Config.Debug then return false end
    if not IsEntityValid(entity) or GetEntityType(entity) == 0 then return false end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
    return true
end

--- Finds the tier config for a business type.
---@param businessType string
---@return table|nil tier
function GetBusinessTier(businessType)
    for _, tier in pairs(Config.Business.Tiers) do
        if tier.type == businessType then return tier end
    end
end

--- Finds the location config for a business.
---@param data { type: string, locationId: number }
---@return table|nil location
function GetBusinessLocation(data)
    local group = Config.Business.Locations[data.type]
    return group and group[data.locationId]
end

--- Creates a map blip at coords.
---@param coords vector3|vector4
---@param sprite number|nil Default 1
---@param display number|nil Default 4
---@param scale number|nil Default 1.0
---@param color number|nil Default 0
---@param label string|nil Blip name
---@return number blip
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

--- Removes a blip if it exists.
---@param blipHandle number|nil
function RemoveMapBlip(blipHandle)
    if blipHandle and DoesBlipExist(blipHandle) then
        RemoveBlip(blipHandle)
    end
end

--- Spawns a local, invincible, frozen ped. Errors if the model is invalid, so check IsModelInCdimage first.
---@param model string
---@param coords vector4
---@param scenario string|nil Scenario to play in place
---@return number ped
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

--- Deletes a ped if it exists.
---@param pedHandle number|nil
function DeletePed(pedHandle)
    if pedHandle and DoesEntityExist(pedHandle) then
        SetEntityAsMissionEntity(pedHandle, false, true)
        DeleteEntity(pedHandle)
    end
end

--- Formats a number as money with thousands separators, using Config.Currency.
---@param amount number
---@return string formatted e.g. "$1,500"
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

--- Builds a readable location for coords: "Street / Cross street, Zone".
---@param coords vector3
---@return string
function GetLocationName(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local location = GetStreetNameFromHashKey(streetHash)

    if crossingHash ~= 0 then
        local crossing = GetStreetNameFromHashKey(crossingHash)
        if crossing ~= "" then location = ("%s / %s"):format(location, crossing) end
    end

    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if zone ~= "NULL" and zone ~= "" then
        location = ("%s, %s"):format(location, zone)
    end

    return location
end