--- DEV TOOL - not required for production use.
--- Scans nearby CObject entities for vending machine models and reports coordinates to the server
--- so a ready-to-use shared/business_locations_vending.lua can be exported.
--- Remove or disable this folder before shipping to a live server.

Config.Dev = Config.Dev or {}
Config.Dev.VendingModels = { -- add/remove model names as needed for your map (vanilla + any custom vending props)
    "prop_vend_soda_01",
    "prop_vend_water_01",
    "prop_vend_snak_01",
    "prop_vend_coffe_01",
}

local scanning = false
local knownCoords = {} -- local dedupe cache, keyed by rounded coord string

--- Rounds coordinates to build a dedupe key so the same machine isn't reported twice.
--- @param coords vector3
--- @return string
local function CoordKey(coords)
    return string.format("%.1f_%.1f_%.1f", coords.x, coords.y, coords.z)
end

--- Checks whether the given model hash matches one of the configured vending models.
--- @param modelHash number
--- @return boolean
local function IsVendingModel(modelHash)
    for _, name in ipairs(Config.Dev.VendingModels) do
        if modelHash == GetHashKey(name) then
            return true
        end
    end
    return false
end

--- Scans the local CObject pool for vending machine models and reports new finds to the server.
local function ScanNearbyObjects()
    local objects = GetGamePool("CObject")

    for _, obj in ipairs(objects) do
        if DoesEntityExist(obj) then
            local model = GetEntityModel(obj)
            if IsVendingModel(model) then
                local coords = GetEntityCoords(obj)
                local key = CoordKey(coords)

                if not knownCoords[key] then
                    knownCoords[key] = true
                    TriggerServerEvent("t1ger_moneywash:devtools:reportVendingMachine", coords)
                end
            end
        end
    end
end

--- Toggles the scanning thread on/off.
RegisterCommand("vendscan", function()
    scanning = not scanning

    if scanning then
        _API.ShowNotification("[DevTool] Vending scan started - walk/drive around the map.", "inform")
        CreateThread(function()
            while scanning do
                ScanNearbyObjects()
                Wait(1500)
            end
        end)
    else
        _API.ShowNotification("[DevTool] Vending scan stopped.", "inform")
    end
end, false)

--- Prints how many unique machines have been found so far (local client count only).
RegisterCommand("vendscancount", function()
    local count = 0
    for _ in pairs(knownCoords) do count = count + 1 end
    _API.ShowNotification(("[DevTool] %d unique vending machines found locally so far."):format(count), "inform")
end, false)