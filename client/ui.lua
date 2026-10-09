-- Shared NUI ownership for every feature in this resource.
local activeScreen, pendingMessage = nil, nil
local ready = false
function GetMoneywashUiScreen() return activeScreen end

function BeginMoneywashUi(screen)
    if activeScreen then return false end
    activeScreen = screen
    return true
end

function ShowMoneywashUi(screen, action, payload)
    if activeScreen ~= screen then return false end
    local message = { action = action, data = payload }
    pendingMessage = message
    if ready then SendNUIMessage(message) end
    SetNuiFocus(true, true)
    return true
end

function CloseMoneywashUi(screen)
    if activeScreen ~= screen then return end
    activeScreen = nil; pendingMessage = nil
    SetNuiFocus(false, false)
end

RegisterNUICallback("t1ger_moneywash:ui:ready", function(_, cb)
    ready = true
    cb({ success = true })
    if activeScreen and pendingMessage then SendNUIMessage(pendingMessage) end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and activeScreen then SetNuiFocus(false, false) end
end)
