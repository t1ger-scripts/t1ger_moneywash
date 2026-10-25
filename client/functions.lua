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

--- Returns whether the player is police and meets a minimum grade (and is on duty if required).
--- The server checks this again, so this only decides what the player is offered.
---@param minGrade number
---@param onDutyOnly? boolean
---@return boolean
function IsPoliceJobWithGrade(minGrade, onDutyOnly)
    if not IsPoliceJob() then return false end

    local job = _API.Player:GetJob()
    if onDutyOnly and job.onDuty == false then return false end

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

---@type table<integer, { heading: number, token: integer }> Running reactions by ped
local reactions = {}

--- The ped turns to the player and says a line, then goes back to its idle animation.
---@param ped integer|nil A local ped
---@param speech string|nil Ambient speech name, silent when nil
---@param scenario string|nil Idle scenario to resume
---@param duration? integer Ms before the ped goes back to idle (default 5000)
function ReactPed(ped, speech, scenario, duration)
    if not ped or not DoesEntityExist(ped) then return end

    duration = duration or 5000

    local state = reactions[ped]
    if not state then
        state = { heading = GetEntityHeading(ped), token = 0 }
        reactions[ped] = state
    end

    state.token = state.token + 1
    local token = state.token

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    TaskTurnPedToFaceEntity(ped, PlayerPedId(), duration)

    if speech and speech ~= "" then
        PlayPedAmbientSpeechNative(ped, speech, "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
    end

    SetTimeout(duration, function()
        if reactions[ped] ~= state or state.token ~= token then return end

        reactions[ped] = nil
        if not DoesEntityExist(ped) then return end

        SetEntityHeading(ped, state.heading)
        FreezeEntityPosition(ped, true)
        if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    end)
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

--- Returns a game label as text, or nil when it is empty or "NULL".
---@param value any
---@return string|nil
local function cleanLabel(value)
    if type(value) ~= "string" then return nil end

    value = value:match("^%s*(.-)%s*$")
    if value == "" or value == "NULL" then return nil end

    return value
end

--- Looks up the street, cross street and zone at a position.
---@param coords vector3|table
---@return { street: string|nil, crossingRoad: string|nil, zone: string|nil }
function GetLocationAddress(coords)
    local x, y, z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
    local streetHash, crossingHash = GetStreetNameAtCoord(x, y, z)

    local street, crossingRoad, zone

    if streetHash ~= 0 then street = cleanLabel(GetStreetNameFromHashKey(streetHash)) end

    if crossingHash ~= 0 and crossingHash ~= streetHash then
        crossingRoad = cleanLabel(GetStreetNameFromHashKey(crossingHash))
    end

    local zoneCode = cleanLabel(GetNameOfZone(x, y, z))
    if zoneCode then zone = cleanLabel(GetLabelText(zoneCode)) or zoneCode end

    return { street = street, crossingRoad = crossingRoad, zone = zone }
end

--- Builds a readable location for coords: "Street / Cross street, Zone".
---@param coords vector3
---@return string
function GetLocationName(coords)
    local address = GetLocationAddress(coords)

    local streets = {}
    if address.street then streets[#streets + 1] = address.street end
    if address.crossingRoad then streets[#streets + 1] = address.crossingRoad end

    local name = table.concat(streets, " / ")

    if address.zone then
        name = name ~= "" and ("%s, %s"):format(name, address.zone) or address.zone
    end

    return name
end

--- Returns the translated message for a failure reason (error.<reason> in the locales).
--- A reason without a message gives error.unknown.
---@param reason? string
---@return string
function GetErrorMessage(reason)
    local key = "error." .. tostring(reason or "unknown")
    local message = locale(key)

    if message == key then return locale("error.unknown") end

    return message
end

--- Shows an error notification for a failure reason.
---@param reason? string
function NotifyError(reason)
    _API.ShowNotification(GetErrorMessage(reason), "error")
end

--- Builds a failed NUI response. The UI shows `message` as it is.
---@param reason string
---@return { success: false, reason: string, message: string }
function ErrorResponse(reason)
    return { success = false, reason = reason, message = GetErrorMessage(reason) }
end

--- Prints a debug line tagged with the feature name. Only prints when Config.Debug is on.
---@param tag string Feature name, e.g. "cash_counter"
---@param ... any
function DebugPrint(tag, ...)
    if not Config.Debug then return end

    local parts = table.pack(...)
    for i = 1, parts.n do parts[i] = tostring(parts[i]) end

    print(("[t1ger_moneywash:%s] %s"):format(tag, table.concat(parts, " ")))
end

--- Calls a server callback and always returns a table, so a callback that errors or
--- returns nothing can't break the caller. A failed response gets a translated `message`.
---@param name string Callback name
---@param ... any Callback arguments
---@return { success: boolean, reason?: string, message?: string, data?: any }
function ServerRequest(name, ...)
    local ok, response = pcall(lib.callback.await, name, false, ...)

    if not ok or type(response) ~= "table" then
        DebugPrint("server_request", name, "failed:", ok and "no answer" or response)
        return ErrorResponse("request_failed")
    end

    if response.success == false then response.message = GetErrorMessage(response.reason) end

    return response
end