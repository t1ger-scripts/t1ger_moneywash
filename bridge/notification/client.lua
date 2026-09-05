--- Validates and converts a notification type based on the configured notification system.
--- Ensures the given notification type is correctly mapped to the respective framework.
--- @param _type string The notification type to validate (e.g., "inform", "success", "error").
--- @return string The corresponding notification type for the selected framework.
local function ValidateNotifyType(_type)
    --- Table defining allowed notification types for different frameworks.
    local allowedTypes = {
        ["ox_lib"] = {
            ["inform"] = "inform",
            ["success"] = "success",
            ["error"] = "error"
        },
        ["esx"] = {
            ["inform"] = "info",
            ["success"] = "success",
            ["error"] = "error"
        },
        ["qbcore"] = {
            ["inform"] = "primary",
            ["success"] = "success",
            ["error"] = "error"
        }
    }

    -- Check if the selected notification system exists in the allowed types table.
    if allowedTypes[Bridge.Notification] then
        -- Validate if the given notification type exists, otherwise return the default type.
        if type(_type) == "string" and allowedTypes[Bridge.Notification][_type] then
            return allowedTypes[Bridge.Notification][_type]
        else
            return allowedTypes[Bridge.Notification]["inform"] -- Default to "inform" type.
        end
    else
        error("[ValidateNotifyType] Notification is not configured..")
    end
end

--- Displays a notification using the configured notification framework.
--- Supports `ox_lib`, `esx`, and `qbcore` notification systems.
--- @param text string The message to be displayed in the notification.
--- @param type string The type of notification (e.g., "inform", "success", "error").
--- @param data table|nil Optional parameters (e.g., duration, title, position, style, icon, iconColor).
function _API.ShowNotification(text, type, data)
    -- Validate and convert the notification type for the respective framework.
    local notificationType = ValidateNotifyType(type)
    local duration = data and data.duration or 3000 -- Default duration: 4000ms

    if Bridge.Notification == "ox_lib" then
        -- Display notification using ox_lib.
        lib.notify({
            title = data and data.title or nil,
            description = text,
            type = notificationType,
            duration = duration,
            position = data and data.position or 'top',
            style = data and data.style or nil,
            icon = data and data.icon or nil,
            iconColor = data and data.iconColor or nil
        })
    elseif Bridge.Notification == "esx" and Framework == Bridge.Notification then
        -- Display notification using ESX framework.
        _FW[Framework].ShowNotification(text, notificationType, duration)
    elseif Bridge.Notification == "qbcore" and Framework == Bridge.Notification then
        -- Display notification using QB-Core framework.
        _FW[Framework].Functions.Notify(text, notificationType, duration)
    else
        error("[_API.ShowNotification] Notification is not configured..")
    end
end

--- Event handler for displaying notifications from the server.
--- Listens for the `t1ger_moneywash:client:notification` event and calls `_API.ShowNotification`.
--- @param text string The notification message.
--- @param type string The type of notification (e.g., "inform", "success", "error").
--- @param data table|nil Optional parameters for customizing the notification.
RegisterNetEvent('t1ger_moneywash:client:notification', function(text, type, data)
    _API.ShowNotification(text, type, data)
end)

---Displays an advanced notification using with icon. Texture dictionary and texture name parameters are usually the same exact value.
---@param textureDict string The texture dictionary for the icon.
---@param textureName string The texture name for the icon.
---@param iconType number The icon type (1 : Chat Box, 2 : Email, 3 : Add Friend Request, 4 : Nothing, 5 : Nothing, 6 : Nothing, 7 : Right Jumping Arrow, 8 : RP Icon, 9 : $ Icon )
---@param title string The notification title (is the very top header)
---@param showInBrief boolean show the notification in brief
---@param subtitle string The notification subtitle (is the header under the sender)
---@param message string the notification message
function _API.ShowAdvancedNotification(textureDict, textureName, iconType, title, showInBrief, subtitle, message)
	RequestStreamedTextureDict(textureDict)
	BeginTextCommandThefeedPost("STRING")
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandThefeedPostMessagetext(textureDict, textureName, false, iconType, title, subtitle)
	EndTextCommandThefeedPostTicker(false, showInBrief)
end