--- Business portal client: registers the target, manages NUI focus, resolves addresses and handles purchases, waypoints and live refreshes.

local NOT_READY_REASONS = {
    business_store_not_ready = true,
    reputation_not_ready = true,
}

local isPortalOpen = false
local isPortalOpening = false
local isTargetRegistered = false

local portalOpenCoords = nil
local portalSession = 0
local closeBusinessPortal -- forward declaration, defined below

--- Converts an empty or invalid game label into nil.
---@param value any
---@return string|nil
local function normalizeGameLabel(value)
    if type(value) ~= "string" then
        return nil
    end

    value = value:gsub("^%s+", ""):gsub("%s+$", "")

    if value == "" or value == "NULL" then
        return nil
    end

    return value
end

--- Resolves a GTA coordinate into its street, crossing road and zone.
---@param coordinates table
---@return table
local function resolveLocationAddress(coordinates)
    local x = tonumber(coordinates and coordinates.x)
    local y = tonumber(coordinates and coordinates.y)
    local z = tonumber(coordinates and coordinates.z)

    if not x or not y or not z then
        return {street = nil, crossingRoad = nil, zone = nil}
    end

    local streetHash, crossingRoadHash = GetStreetNameAtCoord(x + 0.0, y + 0.0, z + 0.0)

    local street = nil
    local crossingRoad = nil

    if streetHash and streetHash ~= 0 then
        street = normalizeGameLabel(GetStreetNameFromHashKey(streetHash))
    end

    if crossingRoadHash and crossingRoadHash ~= 0 and crossingRoadHash ~= streetHash then
        crossingRoad = normalizeGameLabel(GetStreetNameFromHashKey(crossingRoadHash))
    end

    local zoneCode = normalizeGameLabel(GetNameOfZone(x + 0.0, y + 0.0, z + 0.0))
    local zone = nil

    if zoneCode then
        zone = normalizeGameLabel(GetLabelText(zoneCode)) or zoneCode
    end

    return {street = street, crossingRoad = crossingRoad, zone = zone}
end

-- Locations never move, so each address is resolved once per session.
local addressCache = {}

--- Adds client-resolved address information to every visible location.
---@param snapshot table
---@return table
local function prepareSnapshotForNui(snapshot)
    if type(snapshot) ~= "table" then
        return snapshot
    end

    local localeName, messages = GetMoneywashUiLocale()
    snapshot.localization = { locale = localeName, messages = messages }

    if type(snapshot.locations) ~= "table" then
        snapshot.locations = {}
        return snapshot
    end

    for _, location in ipairs(snapshot.locations) do
        local address = addressCache[location.key]

        if not address then
            address = resolveLocationAddress(location.coordinates)
            addressCache[location.key] = address
        end

        location.address = address
    end

    return snapshot
end

--- Requests the player's current authoritative marketplace snapshot.
---@return table|nil response
local function requestMarketplaceSnapshot()
    local callbackSucceeded, response = pcall(lib.callback.await, "t1ger_moneywash:server:businessPortal:getSnapshot", false)

    if not callbackSucceeded then
        if Config.Debug then
            print(("[MoneyWash] Portal snapshot request failed: %s"):format(tostring(response)))
        end
        return nil
    end

    if type(response) ~= "table" then
        return nil
    end

    if response.success and response.data then
        response.data = prepareSnapshotForNui(response.data)
    end

    return response
end

--- Closes the portal if the player dies, gets cuffed or walks away from the computer.
---@param session number
local function watchPortal(session)
    local maxDistance = (Config.WebPortal and Config.WebPortal.CloseDistance) or 6.0

    while isPortalOpen and portalSession == session do
        Wait(500)

        local ped = PlayerPedId()

        if isPortalOpen and portalSession == session and (IsEntityDead(ped) or IsPedCuffed(ped) or #(GetEntityCoords(ped) - portalOpenCoords) > maxDistance) then
            closeBusinessPortal(true)
            return
        end
    end
end

--- Opens the portal after successfully obtaining its data.
function OpenBusinessPortal()
    if isPortalOpen or isPortalOpening then return end
    if not BeginMoneywashUi("marketplace") then return end

    isPortalOpening = true

    local response = requestMarketplaceSnapshot()
    local attempts = 0

    while response and not response.success and NOT_READY_REASONS[response.reason] and attempts < 10 do
        attempts = attempts + 1

        if attempts == 1 then
            _API.ShowNotification(locale("notification.portal_loading"), "inform", {})
        end

        Wait(500)
        response = requestMarketplaceSnapshot()
    end

    if not response or not response.success or not response.data then
        isPortalOpening = false
        CloseMoneywashUi("marketplace")
        _API.ShowNotification(locale("notification.portal_unavailable"), "error", {})
        return
    end

    ShowMoneywashUi("marketplace", "t1ger_moneywash:portal:open", response.data)

    isPortalOpen = true
    isPortalOpening = false

    portalOpenCoords = GetEntityCoords(PlayerPedId())
    portalSession = portalSession + 1

    CreateThread(function()
        watchPortal(portalSession)
    end)
end

--- Refreshes an already-open portal without resetting its selection.
local function refreshBusinessPortal()
    if not isPortalOpen then return end
    local response = requestMarketplaceSnapshot()
    if not response or not response.success or not response.data then return end
    if not isPortalOpen or GetMoneywashUiScreen() ~= "marketplace" then return end

    SendNUIMessage({
        action = "t1ger_moneywash:portal:refresh",
        data = response.data,
    })
end

--- Closes the portal locally and optionally notifies Vue.
---@param notifyNui boolean
function closeBusinessPortal(notifyNui)
    if notifyNui then
        SendNUIMessage({
            action = "t1ger_moneywash:portal:close",
        })
    end

    CloseMoneywashUi("marketplace")

    isPortalOpen = false
    isPortalOpening = false

    TriggerServerEvent("t1ger_moneywash:server:businessPortal:closed")
end

--- Allows other client files to open the portal without duplicating logic.
RegisterNetEvent( "t1ger_moneywash:client:businessPortal:open", OpenBusinessPortal)
exports("OpenBusinessPortal", OpenBusinessPortal)

--- The server requests fresh data when marketplace availability changes.
RegisterNetEvent("t1ger_moneywash:client:businessPortal:refresh", function()
    refreshBusinessPortal()
end)

--- Vue announces that its NUI document has loaded.
--- This does not open the portal automatically.
RegisterNUICallback("t1ger_moneywash:portal:ready", function(_, callback)
    callback({success = true})
end)

--- Vue requests that the portal be closed.
RegisterNUICallback("t1ger_moneywash:portal:close", function(_, callback)
    closeBusinessPortal(false)
    callback({success = true})
end)

--- Vue submits a confirmed business purchase.
RegisterNUICallback("t1ger_moneywash:portal:purchaseBusiness", function(request, callback)
    if not isPortalOpen then
        callback({success = false, reason = "portal_closed"})
        return
    end

    if type(request) ~= "table" then
        callback({success = false, reason = "invalid_request",})
        return
    end

    local callbackSucceeded, response = pcall(lib.callback.await, "t1ger_moneywash:server:businessPortal:purchaseBusiness", false, request.businessType, request.locationId)

    if not callbackSucceeded or type(response) ~= "table" then
        callback({success = false, reason = "request_failed",})
        return
    end

    if response.success and response.data then
        response.data = prepareSnapshotForNui(response.data)

        SendNUIMessage({
            action = "t1ger_moneywash:portal:refresh",
            data = response.data,
        })
    end

    callback(response)
end)

--- Vue requests a waypoint for the player's owned business.
RegisterNUICallback("t1ger_moneywash:portal:setBusinessWaypoint", function(request, callback)
    if not isPortalOpen then
        callback({success = false, reason = "portal_closed" })
        return
    end

    if type(request) ~= "table" then
        callback({ success = false, reason = "invalid_request" })
        return
    end

    local callbackSucceeded, response = pcall(lib.callback.await, "t1ger_moneywash:server:businessPortal:getWaypoint", false, request.businessType, request.locationId)

    if not callbackSucceeded or type(response) ~= "table" then
        callback({ success = false, reason = "request_failed" })
        return
    end

    if response.success and response.data then
        local x = tonumber(response.data.x)
        local y = tonumber(response.data.y)

        if x and y then
            SetNewWaypoint(x + 0.0, y + 0.0)
        end
    end

    callback({success = response.success == true, reason = response.reason})
end)


--- Registers the configured computers and laptops with the target bridge.
CreateThread(function()
    while not _Target do Wait(100) end

    if not Config.WebPortal or type(Config.WebPortal.Target.models) ~= "table" or #Config.WebPortal.Target.models == 0 then
        print("^1[MoneyWash] No business portal target models configured.^7")
        return
    end

    _API.Target.AddModel(Config.WebPortal.Target.models, {
        {
            name = "t1ger_moneywash_business_portal",
            icon = Config.WebPortal.Target.icon,
            label = locale("target.portal_npc"),
            distance = Config.WebPortal.Target.distance or 2.0,

            canInteract = function()
                return not isPortalOpen and not isPortalOpening and GetMoneywashUiScreen() == nil
            end,

            onSelect = function()
                OpenBusinessPortal()
            end,
        },
    })

    isTargetRegistered = true

    if Config.Debug then
        print(("[MoneyWash] Registered business portal target on %d models."):format(
            #Config.WebPortal.Target.models
        ))
    end
end)

--- Clean up focus and target registrations if the resource is stopped.
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if isPortalOpen or isPortalOpening then
        SetNuiFocus(false, false)
    end

    if isTargetRegistered and Config.WebPortal then
        _API.Target.RemoveModel(Config.WebPortal.Target.models, {
            names = { "t1ger_moneywash_business_portal" },
            labels = { locale("target.portal_npc") },
        })
    end
end)