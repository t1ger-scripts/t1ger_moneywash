--- ============================================================================
--- Business Portal Client
--- Handles target registration, NUI focus, portal lifecycle, address resolution,
--- purchases, waypoints and live marketplace refreshes.
--- ============================================================================

local TARGET_OPTION_NAME = "t1ger_moneywash_business_portal"
local TARGET_OPTION_LABEL = locale("target.portal_npc")

local SERVER_CALLBACKS = {
    getSnapshot = "t1ger_moneywash:server:businessPortal:getSnapshot",
    purchaseBusiness = "t1ger_moneywash:server:businessPortal:purchaseBusiness",
    getWaypoint = "t1ger_moneywash:server:businessPortal:getWaypoint",
}

local NUI_CALLBACKS = {
    ready = "t1ger_moneywash:portal:ready",
    close = "t1ger_moneywash:portal:close",
    purchaseBusiness = "t1ger_moneywash:portal:purchaseBusiness",
    setBusinessWaypoint = "t1ger_moneywash:portal:setBusinessWaypoint",
}

local NUI_MESSAGES = {
    open = "t1ger_moneywash:portal:open",
    refresh = "t1ger_moneywash:portal:refresh",
    close = "t1ger_moneywash:portal:close",
}

local NOT_READY_REASONS = {
    business_store_not_ready = true,
    reputation_not_ready = true,
}

local MAX_READY_RETRIES = 10
local READY_RETRY_DELAY = 500

local isPortalOpen = false
local isPortalOpening = false
local isTargetRegistered = false


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
        return {
            street = nil,
            crossingRoad = nil,
            zone = nil,
        }
    end

    local streetHash, crossingRoadHash = GetStreetNameAtCoord(
        x + 0.0,
        y + 0.0,
        z + 0.0
    )

    local street = nil
    local crossingRoad = nil

    if streetHash and streetHash ~= 0 then
        street = normalizeGameLabel(
            GetStreetNameFromHashKey(streetHash)
        )
    end

    if crossingRoadHash
        and crossingRoadHash ~= 0
        and crossingRoadHash ~= streetHash
    then
        crossingRoad = normalizeGameLabel(
            GetStreetNameFromHashKey(crossingRoadHash)
        )
    end

    local zoneCode = normalizeGameLabel(
        GetNameOfZone(x + 0.0, y + 0.0, z + 0.0)
    )

    local zone = nil

    if zoneCode then
        zone = normalizeGameLabel(GetLabelText(zoneCode)) or zoneCode
    end

    return {
        street = street,
        crossingRoad = crossingRoad,
        zone = zone,
    }
end


--- Adds client-resolved address information to every visible location.
---@param snapshot table
---@return table
local function prepareSnapshotForNui(snapshot)
    if type(snapshot) ~= "table" then
        return snapshot
    end

    if type(snapshot.locations) ~= "table" then
        snapshot.locations = {}
        return snapshot
    end

    for _, location in ipairs(snapshot.locations) do
        location.address = resolveLocationAddress(location.coordinates)
    end

    return snapshot
end


--- Requests the player's current authoritative marketplace snapshot.
---@return table|nil response
local function requestMarketplaceSnapshot()
    local callbackSucceeded, response = pcall(
        lib.callback.await,
        SERVER_CALLBACKS.getSnapshot,
        false
    )

    if not callbackSucceeded then
        if Config.Debug then
            print(("[MoneyWash] Portal snapshot request failed: %s"):format(
                tostring(response)
            ))
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


--- Opens the portal after successfully obtaining its data.
function OpenBusinessPortal()
    if isPortalOpen or isPortalOpening then
        return
    end

    isPortalOpening = true

    local response = requestMarketplaceSnapshot()
    local attempts = 0

    while
        response
        and not response.success
        and NOT_READY_REASONS[response.reason]
        and attempts < MAX_READY_RETRIES
    do
        attempts = attempts + 1
        Wait(READY_RETRY_DELAY)
        response = requestMarketplaceSnapshot()
    end

    if not response or not response.success or not response.data then
        isPortalOpening = false

        _API.ShowNotification(
            "The business portal is currently unavailable.",
            "error"
        )

        return
    end

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = NUI_MESSAGES.open,
        data = response.data,
    })

    isPortalOpen = true
    isPortalOpening = false
end

--- Refreshes an already-open portal without resetting its selection.
local function refreshBusinessPortal()
    if not isPortalOpen then
        return
    end

    local response = requestMarketplaceSnapshot()

    if not response or not response.success or not response.data then
        return
    end

    SendNUIMessage({
        action = NUI_MESSAGES.refresh,
        data = response.data,
    })
end


--- Closes the portal locally and optionally notifies Vue.
---@param notifyNui boolean
local function closeBusinessPortal(notifyNui)
    if notifyNui then
        SendNUIMessage({
            action = NUI_MESSAGES.close,
        })
    end

    SetNuiFocus(false, false)

    isPortalOpen = false
    isPortalOpening = false

    TriggerServerEvent(
        "t1ger_moneywash:server:businessPortal:closed"
    )
end


--- Allows other client files to open the portal without duplicating logic.
RegisterNetEvent(
    "t1ger_moneywash:client:businessPortal:open",
    OpenBusinessPortal
)

exports("OpenBusinessPortal", OpenBusinessPortal)


--- The server requests fresh data when marketplace availability changes.
RegisterNetEvent(
    "t1ger_moneywash:client:businessPortal:refresh",
    function()
        refreshBusinessPortal()
    end
)


--- Vue announces that its NUI document has loaded.
--- This does not open the portal automatically.
RegisterNUICallback(NUI_CALLBACKS.ready, function(_, callback)
    callback({
        success = true,
    })
end)


--- Vue requests that the portal be closed.
RegisterNUICallback(NUI_CALLBACKS.close, function(_, callback)
    closeBusinessPortal(false)

    callback({
        success = true,
    })
end)


--- Vue submits a confirmed business purchase.
RegisterNUICallback(
    NUI_CALLBACKS.purchaseBusiness,
    function(request, callback)
        if not isPortalOpen then
            callback({
                success = false,
                reason = "portal_closed",
            })

            return
        end

        if type(request) ~= "table" then
            callback({
                success = false,
                reason = "invalid_request",
            })

            return
        end

        local callbackSucceeded, response = pcall(
            lib.callback.await,
            SERVER_CALLBACKS.purchaseBusiness,
            false,
            request.businessType,
            request.locationId
        )

        if not callbackSucceeded or type(response) ~= "table" then
            callback({
                success = false,
                reason = "request_failed",
            })

            return
        end

        if response.success and response.data then
            response.data = prepareSnapshotForNui(response.data)

            SendNUIMessage({
                action = NUI_MESSAGES.refresh,
                data = response.data,
            })
        end

        callback(response)
    end
)


--- Vue requests a waypoint for the player's owned business.
RegisterNUICallback(
    NUI_CALLBACKS.setBusinessWaypoint,
    function(request, callback)
        if not isPortalOpen then
            callback({
                success = false,
                reason = "portal_closed",
            })

            return
        end

        if type(request) ~= "table" then
            callback({
                success = false,
                reason = "invalid_request",
            })

            return
        end

        local callbackSucceeded, response = pcall(
            lib.callback.await,
            SERVER_CALLBACKS.getWaypoint,
            false,
            request.businessType,
            request.locationId
        )

        if not callbackSucceeded or type(response) ~= "table" then
            callback({
                success = false,
                reason = "request_failed",
            })

            return
        end

        if response.success and response.data then
            local x = tonumber(response.data.x)
            local y = tonumber(response.data.y)

            if x and y then
                SetNewWaypoint(x + 0.0, y + 0.0)
            end
        end

        callback({
            success = response.success == true,
            reason = response.reason,
        })
    end
)


--- Registers the configured computers and laptops with the target bridge.
CreateThread(function()
    while not _Target do
        Wait(100)
    end

    local portalConfig = Config.BusinessPortal

    if not portalConfig
        or type(portalConfig.Models) ~= "table"
        or #portalConfig.Models == 0
    then
        print("^1[MoneyWash] No business portal target models configured.^7")
        return
    end

    _API.Target.AddModel(portalConfig.Models, {
        {
            name = TARGET_OPTION_NAME,
            icon = portalConfig.TargetIcon,
            label = TARGET_OPTION_LABEL,
            distance = portalConfig.TargetDistance or 2.0,

            canInteract = function()
                return not isPortalOpen and not isPortalOpening
            end,

            onSelect = function()
                OpenBusinessPortal()
            end,
        },
    })

    isTargetRegistered = true

    if Config.Debug then
        print(("[MoneyWash] Registered business portal target on %d models."):format(
            #portalConfig.Models
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

    if isTargetRegistered and Config.BusinessPortal then
        _API.Target.RemoveModel(Config.BusinessPortal.Models, {
            names = {
                TARGET_OPTION_NAME,
            },
            labels = {
                TARGET_OPTION_LABEL,
            },
        })
    end
end)
