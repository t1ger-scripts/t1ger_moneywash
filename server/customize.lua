--- The single entry point for every police alert in the script.
--- The client builds the message (with street name) and the blip, see
--- ShowPoliceAlert in client/customize.lua. Replace this with your own dispatch
--- system (ps-dispatch, cd_dispatch, etc.) if you like.
--- @param alertType string "Moderate" | "High" | "Critical" | "Max" | "Deposit"
--- @param coords vector3|vector4|nil where it happened
--- @param data table|nil { business = string } for suspicion alerts, { amount = number } for deposits
function SendPoliceNotification(alertType, coords, data)
    local alert = Config.Police.Alerts[alertType]
    if not alert or not alert.Enable then return end

    local position = coords and vector3(coords.x, coords.y, coords.z) or nil

    for _, policeSrc in ipairs(GetPoliceSources(false)) do
        TriggerClientEvent("t1ger_moneywash:client:policeAlert", policeSrc, alertType, position, data)
    end
end