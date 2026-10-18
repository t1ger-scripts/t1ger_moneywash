--- ============================================================================
--- Client Customize
--- OPEN FILE - safe to edit without touching core logic.
--- Swap out progress bars, skill checks and animations to match your server.
--- ============================================================================

--- Progress bar wrapper
--- Replace with your own progress bar resource if needed
--- @param options table ox_lib progressBar options
--- @return boolean completed (false if cancelled)
function ProgressBar(options)
    return lib.progressBar(options)
end

--- Skill check wrapper
--- Replace with your own minigame or skill check resource if needed
--- @param difficulty string|table ox_lib skillCheck difficulty
--- @param inputs table|nil key inputs
--- @return boolean passed
function SkillCheck(difficulty, inputs)
    return lib.skillCheck(difficulty, inputs or {'w', 'a', 's', 'd'})
end

--- Builds a readable location ("Street / Cross street, Zone") for coords.
--- @param coords vector3
--- @return string
local function GetLocationName(coords)
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

--- Shown to police for every alert: notification with the street name plus a blip
--- on the location. Replace with your own dispatch alert if needed.
--- @param alertType string "Moderate" | "High" | "Critical" | "Max" | "Deposit"
--- @param coords vector3|nil
--- @param data table|nil { business = string } or { amount = number }
function ShowPoliceAlert(alertType, coords, data)
    local cfg = Config.Police.Alerts[alertType]
    if not cfg or not cfg.Enable then return end

    local subject = ""
    if data then
        subject = data.amount and FormatMoney(data.amount) or (data.business or "")
    end

    local location = coords and GetLocationName(coords) or locale("notification.unknown_location")

    _API.ShowNotification(string.format(locale("notification.police_alert." .. alertType), subject, location), "inform", {})

    if not coords then return end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, cfg.BlipSprite)
    SetBlipColour(blip, cfg.BlipColour)
    SetBlipScale(blip, cfg.BlipScale)
    SetBlipAsShortRange(blip, false)
    if cfg.BlipFlash then SetBlipFlashes(blip, true) end

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(cfg.BlipName)
    EndTextCommandSetBlipName(blip)

    SetTimeout(cfg.BlipDuration * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end