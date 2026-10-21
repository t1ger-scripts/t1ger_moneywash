--- Shared NUI ownership: only one feature's screen can own the UI at a time.

---@type string|nil
local activeScreen = nil

---@type { action: string, data: any }|nil
local pendingMessage = nil

--- True once the NUI page has loaded and can receive messages.
local ready = false

--- Returns the screen that currently owns the UI, or nil.
---@return string|nil
function GetMoneywashUiScreen()
    return activeScreen
end

--- Claims the UI for a screen.
---@param screen string
---@return boolean claimed false if another screen already owns the UI
function BeginMoneywashUi(screen)
    if activeScreen then return false end

    activeScreen = screen
    return true
end

--- Sends a message to the UI and gives it focus. Held back until the page is ready.
---@param screen string The screen that claimed the UI
---@param action string
---@param payload any
---@return boolean shown false if the screen doesn't own the UI
function ShowMoneywashUi(screen, action, payload)
    if activeScreen ~= screen then return false end

    local message = { action = action, data = payload }
    pendingMessage = message

    if ready then SendNUIMessage(message) end

    SetNuiFocus(true, true)
    return true
end

--- Releases the UI and removes focus. Does nothing if the screen doesn't own it.
---@param screen string
function CloseMoneywashUi(screen)
    if activeScreen ~= screen then return end

    activeScreen = nil
    pendingMessage = nil
    SetNuiFocus(false, false)
end

--- The UI page tells us it has loaded: send the message that was waiting.
RegisterNUICallback("t1ger_moneywash:ui:ready", function(_, cb)
    ready = true
    cb({ success = true })

    if activeScreen and pendingMessage then
        SendNUIMessage(pendingMessage)
    end
end)

--- Release focus if the resource stops while a screen is open.
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and activeScreen then
        SetNuiFocus(false, false)
    end
end)