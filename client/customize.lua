--- Open file: safe to edit without touching core logic.
--- Swap the progress bar, skill check and police alert for your own resources.

--- Runs when the player has loaded. Add your own client code here.
function OnPlayerLoaded()
end

--- Progress bar wrapper. Replace with your own progress bar resource if needed.
---@param options table ox_lib progressBar options
---@return boolean completed false if cancelled
function ProgressBar(options)
    return lib.progressBar(options)
end

--- Shown to police for every alert: a notification with the street name and a blip on the location.
--- Replace with your own dispatch alert if needed.
---@param alertType "Moderate"|"High"|"Critical"|"Max"|"Deposit"
---@param coords vector3|nil Alert location (no blip when nil)
---@param data { business: string|nil, amount: number|nil }|nil Business name or deposit amount for the message
function ShowPoliceAlert(alertType, coords, data)
    local cfg = Config.Police.Alerts[alertType]
    if not cfg or not cfg.Enable then return end

    local subject = ""
    if data then
        subject = data.amount and FormatMoney(data.amount) or (data.business or "")
    end

    local location = coords and GetLocationName(coords) or locale("notification.unknown_location")

    _API.ShowNotification(string.format(locale("notification.police_alert." .. alertType), subject, location), "inform", {
        duration = Config.Police.AlertNotifyDuration or 10000
    })

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

--- Shown when money is laundered into the safe.
---@param amount number Total laundered
---@param covered number Part covered by stock
---@param exposed number Part not covered by stock
function NotifyMoneyLaundered(amount, covered, exposed)
    _API.ShowNotification(string.format(locale("notification.money_laundered"), FormatMoney(amount), FormatMoney(covered), FormatMoney(exposed)),"success", {})
end

--- Shown when a launder raises the suspicion label.
---@param newLabel { name: string, color: string }
function NotifySuspicionChanged(newLabel)
    if not Config.Suspicion.NotifyOnLabelChange then return end
    _API.ShowNotification(string.format(locale("notification.suspicion_changed"), newLabel.name), "inform", {})
end