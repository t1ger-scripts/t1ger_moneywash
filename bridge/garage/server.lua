local garageColumn, storedColumn = nil, nil

--- Initializes the database column names for the garage system based on the framework.
-- This ensures that the script correctly references the appropriate columns in different garage system databases.
-- Supports `esx`, `qbox`, `qbcore`, and custom garage systems like `jg-advancedgarages` and `qs-advancedgarages`.
local function InitializeColumns()
    -- Default garage/stored columns based on framework
    if Framework == "esx" then
        garageColumn = "parking"
        storedColumn = "stored"
    elseif Framework == "qbox" or Framework == "qbcore" then
        garageColumn = "garage"
        storedColumn = "state"
    else
        error(("[InitializeColumns] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end

    local attempts = 10
    while not _Garage and attempts > 0 do
        Wait(500)
        attempts = attempts - 1
    end
    if not _Garage and attempts <= 0 then return end

    -- Custom column names based on specific garage system
    if _Garage == "jg-advancedgarages" then
        garageColumn = "garage_id"
        storedColumn = "in_garage"
    elseif _Garage == "cd_garage" then
        garageColumn = "garage_id"
        storedColumn = "in_garage"
    elseif _Garage == "okokGarage" then
        -- uses default framework columns
    elseif _Garage == "codem-garage" then
        garageColumn = "parking"
        storedColumn = "stored"
    elseif _Garage == "rcore_garage" then
        garageColumn = "stored_in_garage"
        storedColumn = "stored"
    elseif _Garage == "renzu_garage" then
        garageColumn = "garage_id"
    elseif _Garage == "qs-advancedgarages" then
        garageColumn = "garage_id"
    elseif _Garage == "ak47_garage" then
        storedColumn = "stored"
    elseif _Garage == "loaf_garage" then
        garageColumn = "garage"
    else
        -- add your own custom columns in here
    end

end

--- Formats a database row into structured vehicle data.
-- Extracts relevant fields from a database result and structures them in a uniform format.
---@param result table The vehicle database row.
---@return table vehicle A structured table containing the vehicle's plate, owner, props, garage, and stored status.
local function FormatVehicleData(result)
    return {
        plate = result.plate,
        owner = result[_DB.vehicleOwnerColumn],
        props = result[_DB.vehiclePropsColumn],
        garage = result[garageColumn],
        stored = result[storedColumn],
        id = result.id or nil
    }
end

--- Trims leading and trailing spaces from a plate string.
--- Ensures that plate numbers are formatted correctly to prevent inconsistencies in database lookups.
--- @param plate string The plate string to be trimmed.
--- @return string trimmedPlate The trimmed plate string.
local function TrimPlate(plate)
    if type(plate) ~= "string" or not plate:match("%S") then
        error("[TrimPlate] Invalid plate type. Expected a non-empty string")
    end
    return string.gsub(plate, "^%s*(.-)%s*$", "%1")
end
exports("TrimPlate", TrimPlate)

--- Checks if a plate exists in the vehicles table in the database.
-- Some servers store plates with trailing spaces, so the function checks both the original and trimmed plate.
---@param plate string The plate number to search for. Must be a non-empty string.
---@return boolean exists True if the plate exists in the database, false otherwise.
function _API.DoesVehiclePlateExist(plate)
    if type(plate) ~= "string" or not plate:match("%S") then
        return error("[_API.DoesVehiclePlateExist] Invalid plate type. Expected a non-empty string")
    end

    local trimmedPlate = TrimPlate(plate)

    -- Query database for matching plate
    local queryResult = MySQL.scalar.await("SELECT plate FROM ".._DB.vehicleTable.." WHERE plate = ? OR plate = ?", {plate, trimmedPlate})

    -- Return true if found, false otherwise
    return queryResult ~= nil
end

--- Retrieves a vehicle from the database by its plate number.
-- Some servers store plates with trailing spaces, so the function checks both the original and trimmed plate.
---@param plate string The plate number to search for. Must be a non-empty string.
---@return table|nil vehicle The vehicle data if found, otherwise nil.
function _API.GetVehicleByPlate(plate)
    if type(plate) ~= "string" or not plate:match("%S") then
        return error("[_API.GetVehicleByPlate] Invalid plate type. Expected a non-empty string")
    end

    local trimmedPlate = TrimPlate(plate)

    -- Query the database for a vehicle with the given plate
    local result = MySQL.query.await("SELECT * FROM ".._DB.vehicleTable.." WHERE plate = ? OR plate = ?", {plate, trimmedPlate})

    -- Validate the result
    if not result or type(result) ~= "table" or #result == 0 then
        print("[_API.GetVehicleByPlate] No vehicle found for plate: " .. tostring(plate))
        return nil
    end

    return FormatVehicleData(result[1])
end

--- Checks if a vehicle with the given plate exists in the database (i.e., is owned).
---@param plate string The license plate to check (can be trimmed or untrimmed).
---@return boolean #Returns true if the vehicle exists, otherwise false.
function _API.IsVehicleOwned(plate)
    if type(plate) ~= "string" or not plate:match("%S") then
        return false
    end

    local trimmedPlate = TrimPlate(plate)
    local result = MySQL.scalar.await("SELECT 1 FROM ".._DB.vehicleTable.." WHERE plate = ? OR plate = ? LIMIT 1", {plate, trimmedPlate})

    return result ~= nil
end

--- Retrieves all owned vehicles for a specific player.
-- Queries the database for vehicles owned by the player's unique identifier.
---@param src number The player's ID/source.
---@return table|nil ownedVehicles A table containing all owned vehicles if found, otherwise nil.
function _API.GetOwnedVehicles(src)
    local player = _API.Player.GetFromId(src)
    if not player then
        print(string.format("[_API.GetOwnedVehicles] Player not found (source: %s)", tostring(src)))
        return nil
    end

    local identifier = _API.Player.GetIdentifier(src)
    local ownedVehicles = {}

    -- Query the database for owned vehicles with the given owner identifier
    local results = MySQL.query.await("SELECT * FROM ".._DB.vehicleTable.." WHERE ".._DB.vehicleOwnerColumn.." = ?", {identifier})

    -- Validate the results
    if not results or type(results) ~= "table" or #results == 0 then
        print(string.format("[_API.GetOwnedVehicles] No owned vehicles found for player (%s) with identifier: %s", tostring(src), identifier))
        return nil
    end

    -- Populate owned vehicles table efficiently
    for _, row in ipairs(results) do
        table.insert(ownedVehicles, FormatVehicleData(row))
    end

    return ownedVehicles
end

--- Returns all owned vehicles on the server.
-- Queries the database for all vehicles owned.
---@return table|nil #Returns a table containing all owned vehicles if found, otherwise nil.
function _API.GetAllOwnedVehicles()
    while not _DB do 
        Wait(100)
    end
    local results = MySQL.query.await('SELECT * from '.._DB.vehicleTable)

    -- Populate owned vehicles table efficiently
    local ownedVehicles = {}
    for _, row in ipairs(results) do
        table.insert(ownedVehicles, FormatVehicleData(row))
    end

    return ownedVehicles
end

--- Function to update stored state of an owned vehicle in the database
---@param stored number state 0 = out, 1 = in
---@param garage string unique identifier for the garage
---@param props table the vehicle properties
function _API.SetVehicleStored(stored, garage, props)
    local trimmedPlate = TrimPlate(props.plate)

    if stored == 1 then
        -- remove persistency?
        if _Garage == "qs-advancedgarages" then
            exports['qs-advancedgarages']:removeVehicleFromPersistent(props.plate, trimmedPlate)
        end
    else
        garage = nil
    end

    MySQL.update("UPDATE ".._DB.vehicleTable.." SET `"..storedColumn.."` = ?, `".._DB.vehiclePropsColumn.."` = ?, `"..garageColumn.."` = ? WHERE plate = ? OR plate = ?", {
		stored,
        json.encode(props),
        garage,
        props.plate,
        trimmedPlate
	})
end

--- Saves vehicle properties to the database by plate.
--- Only updates the props column — does not affect stored state or garage.
--- @param plate string
--- @param props table
function _API.SaveVehicleProperties(plate, props)
    if type(plate) ~= "string" or plate == "" then return end
    if type(props) ~= "table" then return end

    local trimmed = TrimPlate(plate)
    MySQL.update(
        "UPDATE " .. _DB.vehicleTable .. " SET `" .. _DB.vehiclePropsColumn .. "` = ? WHERE plate = ? OR plate = ?",
        { json.encode(props), plate, trimmed },
        function(rowsChanged)
            if rowsChanged == 0 then
                print(("[_API.SaveVehicleProperties] no rows updated for plate %s"):format(plate))
            else
                print(("[_API.SaveVehicleProperties] saved vehicle props for plate %s"):format(plate))
            end
        end
    )
end

---Function to set vehicle as impounded in database
---@param plate string the vehicle plate
---@param props table the vehicle properties/mods
function _API.SetVehicleImpounded(plate, props)

    -- check if vehicle is owned
    local vehicle = _API.GetVehicleByPlate(plate)
    if type(vehicle) ~= "table" then 
        return 
    end

    if _Garage == "esx_garage" then
        MySQL.update("UPDATE ".._DB.vehicleTable.." SET `"..storedColumn.."` = ?, `".._DB.vehiclePropsColumn.."` = ?, `pound` = ? WHERE plate = ? OR plate = ?", {2, json.encode(props), 'LosSantos', props.plate, trimmedPlate})
    elseif _Garage == "qbx_garages" then
        _FW[Framework]:setVehicleGarage(vehicle.id, "impoundlot")
        _FW[Framework]:setVehicleDepotPrice(vehicle.id, 500) -- depot price
    elseif _Garage == "qb-garages" then
        MySQL.update("UPDATE ".._DB.vehicleTable.." SET `"..storedColumn.."` = ?, `".._DB.vehiclePropsColumn.."` = ?, `depotprice` = ? WHERE plate = ? OR plate = ?", {2, json.encode(props), 500, props.plate, trimmedPlate})
    else
        -- add your custom event/export in here
    end
    
end

--- Callback function to retrieve a player's owned vehicles.
-- This allows other scripts to request vehicle data asynchronously.
---@param source number The player's ID/source.
---@return table|nil GetOwnedVehicles The player's owned vehicles, structured as a table.
lib.callback.register("t1ger_moneywash:server:getOwnedVehicles", function(source)
    return _API.GetOwnedVehicles(source)
end)

--- Callback function to check if a plate exists in database
---@param source number The player's ID/source.
---@param plate string The vehicle's plate number to check for
---@return boolean DoesVehiclePlateExist whether the plate exists or not 
lib.callback.register("t1ger_moneywash:server:doesVehiclePlateExist", function(source, plate)
    return _API.DoesVehiclePlateExist(plate)
end)

--- Callback function to check if a plate exists in database
---@param source number The player's ID/source.
---@param plate string The vehicle's plate number to check for
---@return boolean DoesVehiclePlateExist whether the plate exists or not 
lib.callback.register("t1ger_moneywash:server:spawnVehicle", function(source, model, coords, heading, warp)
    local src = source
    local netId = qbx.spawnVehicle({ spawnSource = vector4(coords.x, coords.y, coords.z, heading), model = model, warp = warp})
    return netId
end)

-- Server event to set vehicle impounded
RegisterServerEvent("t1ger_moneywash:server:impoundVehicle")
AddEventHandler("t1ger_moneywash:server:impoundVehicle", function(plate, props)
    _API.SetVehicleImpounded(plate, props)
end)

while not _DB do
    Wait(1000)
end
InitializeColumns()