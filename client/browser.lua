--- ============================================================================
--- Browser Client
--- Controls the Ledger Capital NUI lifecycle and browser data loading.
--- ============================================================================

local BrowserOpen = false
local NuiReady = false
local BootstrapLoading = false
local BootstrapRequestId = 0

local LocationAddressCache = {}
local BrowserLocales = nil

--- Loads the configured ox_lib locale file for use inside the NUI.
--- Falls back to English when the selected locale does not exist.
--- @return table
local function LoadBrowserLocales()
    if BrowserLocales then
        return BrowserLocales
    end

    local resourceName = GetCurrentResourceName()
    local localeName = GetConvar("ox:locale", "en")

    local localePath = ("locales/%s.json"):format(localeName)
    local rawLocale = LoadResourceFile(resourceName, localePath)

    if not rawLocale then
        rawLocale = LoadResourceFile(resourceName, "locales/en.json")
    end

    if not rawLocale then
        BrowserLocales = {}
        return BrowserLocales
    end

    local decoded, localeData = pcall(json.decode, rawLocale)

    if not decoded or type(localeData) ~= "table" then
        BrowserLocales = {}
        return BrowserLocales
    end

    BrowserLocales = localeData

    return BrowserLocales
end

--- Resolves an address from GTA natives and caches the result.
--- @param location table
--- @return table
local function ResolveLocationAddress(location)
    local cached = LocationAddressCache[location.uid]

    if cached then
        return cached
    end

    local coords = location.coords

    local streetHash, crossingHash = GetStreetNameAtCoord(
        coords.x,
        coords.y,
        coords.z
    )

    local street = nil
    local crossingStreet = nil

    if streetHash and streetHash ~= 0 then
        local resolvedStreet = GetStreetNameFromHashKey(streetHash)

        if resolvedStreet and resolvedStreet ~= "" then
            street = resolvedStreet
        end
    end

    if crossingHash and crossingHash ~= 0 then
        local resolvedCrossing = GetStreetNameFromHashKey(crossingHash)

        if resolvedCrossing and resolvedCrossing ~= "" then
            crossingStreet = resolvedCrossing
        end
    end

    local zone = nil
    local zoneName = GetNameOfZone(
        coords.x,
        coords.y,
        coords.z
    )

    if zoneName and zoneName ~= "" then
        local resolvedZone = GetLabelText(zoneName)

        if resolvedZone and
            resolvedZone ~= "" and
            resolvedZone ~= "NULL"
        then
            zone = resolvedZone
        else
            zone = zoneName
        end
    end

    local address = {
        street = street,
        crossingStreet = crossingStreet,
        zone = zone,
    }

    LocationAddressCache[location.uid] = address

    return address
end

--- Adds localized street and zone names to browser locations.
--- @param snapshot table
local function EnrichBrowserLocations(snapshot)
    for _, location in ipairs(snapshot.locations or {}) do
        local address = ResolveLocationAddress(location)

        location.street = address.street
        location.crossingStreet = address.crossingStreet
        location.zone = address.zone
    end
end

--- Requests a fresh authoritative browser snapshot.
local function RequestBrowserBootstrap()
    if not BrowserOpen or not NuiReady or BootstrapLoading then
        return
    end

    BootstrapLoading = true
    BootstrapRequestId = BootstrapRequestId + 1

    local requestId = BootstrapRequestId

    SendNUIMessage({
        action = "t1ger_moneywash:browser:loading",
    })

    CreateThread(function()
        local response = lib.callback.await(
            "t1ger_moneywash:server:getBrowserBootstrap",
            false
        )

        if requestId ~= BootstrapRequestId or not BrowserOpen then
            BootstrapLoading = false
            return
        end

        BootstrapLoading = false

        if not response or not response.success or not response.data then
            SendNUIMessage({
                action = "t1ger_moneywash:browser:error",
                data = {
                    reason = response and response.reason or
                        "browser_data_unavailable",
                },
            })

            return
        end

        EnrichBrowserLocations(response.data)

        response.data.locales = LoadBrowserLocales()

        SendNUIMessage({
            action = "t1ger_moneywash:browser:bootstrap",
            data = response.data,
        })
    end)
end

--- Opens the Ledger Capital browser.
--- Can be called by the configured model target or another resource export.
--- @return boolean opened
local function OpenBrowser()
    if BrowserOpen then
        return false
    end

    BrowserOpen = true

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = "t1ger_moneywash:browser:open",
    })

    if NuiReady then
        RequestBrowserBootstrap()
    end

    return true
end

--- Closes the Ledger Capital browser.
--- @return boolean closed
local function CloseBrowser()
    if not BrowserOpen then
        return false
    end

    BrowserOpen = false
    BootstrapLoading = false
    BootstrapRequestId = BootstrapRequestId + 1

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = "t1ger_moneywash:browser:close",
    })

    return true
end

exports("OpenBrowser", OpenBrowser)
exports("CloseBrowser", CloseBrowser)

RegisterNUICallback("ready", function(_, cb)
    NuiReady = true

    cb({
        success = true,
    })

    if BrowserOpen then
        RequestBrowserBootstrap()
    end
end)

RegisterNUICallback("retryBootstrap", function(_, cb)
    cb({
        success = true,
    })

    RequestBrowserBootstrap()
end)

RegisterNUICallback("close", function(_, cb)
    CloseBrowser()

    cb({
        success = true,
    })
end)

CreateThread(function()
    while not _Target do Wait(100) end -- wait for target to initialize
    
    _API.Target.AddModel(Config.Browser.Models, {
        {
            name = "t1ger_moneywash:open_browser",
            label = Config.Browser.TargetLabel,
            icon = Config.Browser.TargetIcon,
            distance = Config.Browser.TargetDistance,

            canInteract = function(entity)
                if BrowserOpen then
                    return false
                end

                if not entity or entity == 0 or not DoesEntityExist(entity) then
                    return false
                end

                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    return false
                end

                return true
            end,

            onSelect = function()
                OpenBrowser()
            end,
        },
    })
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    _API.Target.RemoveModel(Config.Browser.Models, {
        names = {
            "t1ger_moneywash:open_browser",
        },

        labels = {
            Config.Browser.TargetLabel,
        },
    })
end)