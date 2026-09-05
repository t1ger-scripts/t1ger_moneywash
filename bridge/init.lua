Framework, _Framework, _Inventory, _Target, _JobAccount, _Garage, _VehicleKeys = nil, nil, nil, nil, nil, nil, nil  -- Global variables for framework, inventory, targeting, job account, garage and vehicle keys systems
_FW = {} -- Stores framework objects dynamically
_DB = nil -- global variables for framework's database table/column names
local qbx = nil

-- List of supported frameworks (DO NOT MODIFY)
local supportedFrameworks = {
    {
        name = "esx",
        resource = "es_extended",
        db = {playerTable = "users", playerColumn = "identifier", vehicleTable = "owned_vehicles", vehiclePropsColumn = "vehicle", vehicleOwnerColumn = "owner"},
        getter = function() return exports["es_extended"]:getSharedObject() end
    },
    {
        name = "qbox",
        resource = "qbx_core",
        db = {playerTable = "players", playerColumn = "citizenid", vehicleTable = "player_vehicles", vehiclePropsColumn = "mods", vehicleOwnerColumn = "citizenid"},
        getter = function() return setmetatable({}, {
            __index = function(_, key) return function(...) return exports["qbx_core"][key](...) end end
        }) end
    },
    {
        name = "qbcore",
        resource = "qb-core",
        db = {playerTable = "players", playerColumn = "citizenid", vehicleTable = "player_vehicles", vehiclePropsColumn = "mods", vehicleOwnerColumn = "citizenid"},
        getter = function() return exports["qb-core"]:GetCoreObject() end
    }
}

--- Function to Initialize the Framework
local function InitializeFramework()
    if Bridge.Framework ~= "auto" then
        for _, fw in ipairs(supportedFrameworks) do
            if fw.name == Bridge.Framework and GetResourceState(fw.resource) == "started" then
                _FW[fw.name] = fw.getter()
                _DB = fw.db
                if fw.name == "qbox" then
                    qbx = require("@qbx_core/modules/lib")
                end
                _Framework = fw.resource
                return fw.name
            end
        end
        return error(string.format("[InitializeFramework] Specified framework (%s) is not running!", Bridge.Framework))
    end

    for _, fw in ipairs(supportedFrameworks) do
        if GetResourceState(fw.resource) == "started" then
            _FW[fw.name] = fw.getter()
            _DB = fw.db
            local currentVersion = GetResourceMetadata(fw.resource, "version", 0)
            if fw.name == "qbox" then
                qbx = require("@qbx_core/modules/lib")
            end
            _Framework = fw.resource
            return fw.name
        end
    end

    error("[InitializeFramework] No supported framework detected. The script requires ESX, QBCore, or QBX to function.")
end

--- Function to Initialize the Inventory System
local function InitializeInventory()
    if Bridge.Inventory ~= "auto" then
        if GetResourceState(Bridge.Inventory) == "started" then
            return Bridge.Inventory
        else
            error(string.format("[InitializeInventory] Specified inventory (%s) is not running!", Bridge.Inventory))
        end
    end

    for _, inv in ipairs(Bridge.CompatibleInventories) do
        if GetResourceState(inv) == "started" then
            return inv
        end
    end

    error("[InitializeInventory] No supported inventory system detected!")
end

--- Function to Initialize the Targeting System
local function InitializeTarget()
    if Bridge.Target ~= "auto" then
        if GetResourceState(Bridge.Target) == "started" then
            return Bridge.Target
        else
            error(string.format("[InitializeTarget] Specified targeting system (%s) is not running!", Bridge.Target))
        end
    end

    for _, target in ipairs(Bridge.CompatibleTargets) do
        if GetResourceState(target) == "started" then
            return target
        end
    end

    error("[InitializeTarget] No supported targeting system detected. The script requires Ox Target or QB Target")
end

--- Function to Initialize the job account System
local function InitializeJobAccount()
    if Bridge.JobAccount ~= "auto" then
        if GetResourceState(Bridge.JobAccount) == "started" then
            return Bridge.JobAccount
        else
            error(string.format("[InitializeJobAccount] Specified job account system (%s) is not running!", Bridge.JobAccount))
        end
    end

    if not Bridge.CompatibleJobAccounts[Framework] then
        error(string.format("[InitializeJobAccount] Unsupported framework detected: %s", Framework))
    end

    -- Loop through the prioritized list for the detected framework
    for _, jobAccount in ipairs(Bridge.CompatibleJobAccounts[Framework]) do
        if GetResourceState(jobAccount) == "started" then
            return jobAccount
        end
    end

    error("[InitializeJobAccount] No supported job account system detected.")
end

--- Function to Initialize the Garage System
local function InitializeGarage()
    if Bridge.Garage ~= "auto" then
        if GetResourceState(Bridge.Garage) == "started" then
            return Bridge.Garage
        else
            error(string.format("[InitializeGarage] Specified garage system (%s) is not running!", Bridge.Garage))
        end
    end

    for _, garage in ipairs(Bridge.CompatibleGarages) do
        if GetResourceState(garage) == "started" then
            return garage
        end
    end

    return nil
end

--- Function to Initialize the Vehicle Keys System
local function InitializeVehicleKeys()
    if Bridge.VehicleKeys ~= "auto" then
        if GetResourceState(Bridge.VehicleKeys) == "started" then
            return Bridge.VehicleKeys
        else
            error(string.format("[InitializeVehicleKeys] Specified vehicle keys system (%s) is not running!", Bridge.VehicleKeys))
        end
    end

    for _, vehicleKey in ipairs(Bridge.CompatibleVehicleKeys) do
        if GetResourceState(vehicleKey) == "started" then
            return vehicleKey
        end
    end

    return nil
end

CreateThread(function()
    Wait(1000)
    Framework = InitializeFramework()
    _Inventory = InitializeInventory()
    _Target = InitializeTarget()
    _JobAccount = InitializeJobAccount()
    _Garage = InitializeGarage()
    _VehicleKeys = InitializeVehicleKeys()

    print(string.format("^5[DETECTED SYSTEMS]^7 %s | %s | %s | %s", _Framework, _Inventory, _Target, _JobAccount))

    if _Garage then
        print(string.format("^5[DETECTED GARAGE SYSTEM]^7 %s", _Garage))
    end

    if _VehicleKeys then
        print(string.format("^5[DETECTED VEHICLE KEYS SYSTEM]^7 %s", _VehicleKeys))
    end
end)