--- Sends a notification to a specific player.
--- This function triggers the client event `t1ger_mechanic:client:notification` to display a notification.
--- @param src number The player server ID to whom the notification should be sent.
--- @param text string The message to be displayed in the notification.
--- @param type string The type of notification (e.g., "inform", "success", "error").
--- @param data table|nil Optional parameters for customizing the notification (e.g., duration, title, position, icon).
function _API.SendNotification(src, text, type, data)
    if src and tonumber(src) then
        TriggerClientEvent("t1ger_mechanic:client:notification", src, text, type, data)
    else
        print("^1[_API.SendNotification] Expected a valid player ID, got: " .. tostring(src).."^7")
    end
end
