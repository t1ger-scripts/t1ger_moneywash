--- Business portal client: opens the portal from the computer target, keeps it in sync with the server and handles purchases and waypoints.

local SCREEN = "portal"
local LOAD_ATTEMPTS = 10 -- Tries (500 ms apart) while the server is still loading

--- Reasons that mean "the server isn't ready yet, try again".
local NOT_READY = {
    business_store_not_ready = true,
    reputation_not_ready = true,
}

local isOpen = false -- True once the portal is on screen
local openCoords = nil -- Where the player stood when opening it
local session = 0 -- Tells an old distance check from the current one
local targetRegistered = false

--- Locations never move, so each address is looked up once.
---@type table<string, table>
local addressCache = {}

--- Adds the UI text and the street address of every location to a snapshot.
---@param snapshot table
---@return table snapshot
local function buildNuiSnapshot(snapshot)
    local localeName, messages = GetMoneywashUiLocale()
    snapshot.localization = { locale = localeName, messages = messages }

    for _, location in ipairs(snapshot.locations or {}) do
        local key = location.key
        addressCache[key] = addressCache[key] or GetLocationAddress(location.coordinates)
        location.address = addressCache[key]
    end

    return snapshot
end

--- Asks the server for the player's portal data.
---@return table response
local function loadSnapshot()
    local response = ServerRequest("t1ger_moneywash:server:portal:snapshot")

    if response.success and response.data then
        buildNuiSnapshot(response.data)
    end

    return response
end

--- Closes the portal and tells the server to stop sending refreshes.
---@param notifyUi boolean Also tell the UI to close (false when the UI closed itself)
local function closePortal(notifyUi)
    if notifyUi then
        SendNUIMessage({ action = "t1ger_moneywash:portal:close" })
    end

    CloseMoneywashUi(SCREEN)
    isOpen = false

    TriggerServerEvent("t1ger_moneywash:server:portal:closed")
end

--- Closes the portal if the player dies, gets cuffed or walks away from the computer.
---@param id number The session this check belongs to
local function watchPortalDistance(id)
    local maxDistance = Config.WebPortal.CloseDistance or 6.0

    while isOpen and session == id do
        Wait(500)

        local ped = PlayerPedId()
        local tooFar = #(GetEntityCoords(ped) - openCoords) > maxDistance

        if isOpen and session == id and (IsEntityDead(ped) or IsPedCuffed(ped) or tooFar) then
            closePortal(true)
            return
        end
    end
end

--- Opens the portal once the server has sent its data.
local function openPortal()
    if not BeginMoneywashUi(SCREEN) then return end

    local response = loadSnapshot()
    local attempts = 0

    while NOT_READY[response.reason] and attempts < LOAD_ATTEMPTS do
        attempts = attempts + 1

        if attempts == 1 then
            _API.ShowNotification(locale("notification.portal_loading"), "inform", {})
        end

        Wait(500)
        response = loadSnapshot()
    end

    if not response.success or not response.data then
        CloseMoneywashUi(SCREEN)
        NotifyError("snapshot_unavailable")
        return
    end

    ShowMoneywashUi(SCREEN, "t1ger_moneywash:portal:open", response.data)

    isOpen = true
    openCoords = GetEntityCoords(PlayerPedId())
    session = session + 1

    local id = session
    CreateThread(function() watchPortalDistance(id) end)
end

RegisterNetEvent("t1ger_moneywash:client:portal:open", openPortal)
exports("OpenBusinessPortal", openPortal)

--- The server says the data changed: fetch it again without resetting the UI's selection.
RegisterNetEvent("t1ger_moneywash:client:portal:refresh", function()
    if not isOpen then return end

    local response = loadSnapshot()
    if not response.success or not response.data or not isOpen then return end

    SendNUIMessage({ action = "t1ger_moneywash:portal:refresh", data = response.data })
end)

--- Passes a purchase or waypoint request from the UI on to the server.
---@param callbackName string Server callback
---@param request any What the UI sent: { businessType, locationId }
---@return table response
local function forwardRequest(callbackName, request)
    if not isOpen then return ErrorResponse("portal_closed") end
    if type(request) ~= "table" then return ErrorResponse("invalid_request") end

    return ServerRequest(callbackName, request.businessType, request.locationId)
end

--- The UI closed itself (ESC or close button).
RegisterNUICallback("t1ger_moneywash:portal:close", function(_, cb)
    closePortal(false)
    cb({ success = true })
end)

--- The UI confirmed a purchase.
RegisterNUICallback("t1ger_moneywash:portal:purchase", function(request, cb)
    local response = forwardRequest("t1ger_moneywash:server:portal:purchase", request)

    if response.success and response.data then
        buildNuiSnapshot(response.data)
        SendNUIMessage({ action = "t1ger_moneywash:portal:refresh", data = response.data })
    end

    cb(response)
end)

--- The UI wants a waypoint to a business the player owns.
RegisterNUICallback("t1ger_moneywash:portal:waypoint", function(request, cb)
    local response = forwardRequest("t1ger_moneywash:server:portal:waypoint", request)

    if response.success and response.data then
        SetNewWaypoint(response.data.x + 0.0, response.data.y + 0.0)
    end

    cb({ success = response.success == true, reason = response.reason, message = response.message })
end)

--- Adds the "open portal" option to the configured computer models.
CreateThread(function()
    while not _Target do Wait(100) end

    local models = Config.WebPortal.Target.models

    if #models == 0 then
        print("^1[t1ger_moneywash] No portal target models configured (Config.WebPortal.Target.models).^7")
        return
    end

    _API.Target.AddModel(models, {
        {
            name = "t1ger_moneywash_business_portal",
            icon = Config.WebPortal.Target.icon,
            label = locale("target.portal_npc"),
            distance = Config.WebPortal.Target.distance or 2.0,
            canInteract = function() return GetMoneywashUiScreen() == nil end,
            onSelect = openPortal,
        },
    })

    targetRegistered = true
    DebugPrint("portal", "target registered on", #models, "models")
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() or not targetRegistered then return end

    _API.Target.RemoveModel(Config.WebPortal.Target.models, {
        names = { "t1ger_moneywash_business_portal" },
        labels = { locale("target.portal_npc") },
    })
end)