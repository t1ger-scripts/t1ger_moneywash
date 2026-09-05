local gameBuild = GetGameBuildNumber()

--- Trims leading and trailing spaces from a plate string.
-- Ensures that plate numbers are formatted correctly to prevent inconsistencies in database lookups.
---@param input string The plate string to be trimmed.
---@return string trimmedPlate The trimmed plate string.
local function TrimPlate(input)
    if type(input) ~= "string" or input == "" then
        error("[TrimPlate] Invalid input type. Expected a non-empty string")
    end
    return string.gsub(input, "^%s*(.-)%s*$", "%1")
end
exports("TrimPlate", TrimPlate)

_API.VehicleWheels = {
    ["2"] = { -- Bike and cycle.
        ["0"] = {label = "Wheel Front", bone = "wheel_lf", index = 0, wheelId = 0},
        ["4"] = {label = "Wheel Rear", bone = "wheel_lr", index = 4, wheelId = 1},
    },
    ["3"] = { -- Vehicle with 3 wheels (get for wheels because some 3 wheels vehicles have 2 wheels on front and one rear or the reverse).
        ["0"] = {label = "Wheel Front (L)", bone = "wheel_lf", index = 0, wheelId = 0},
        ["1"] = {label = "Wheel Front (R)", bone = "wheel_rf", index = 1, wheelId = 1},
        ["4"] = {label = "Wheel Rear (L)", bone = "wheel_lr", index = 4, wheelId = 2},
        ["5"] = {label = "Wheel Rear (R)", bone = "wheel_rr", index = 5, wheelId = 3},
    },
    ["4"] = { -- Vehicle with 4 wheels.
        ["0"] = {label = "Wheel Front (L)", bone = "wheel_lf", index = 0, wheelId = 0},
        ["1"] = {label = "Wheel Front (R)", bone = "wheel_rf", index = 1, wheelId = 1},
        ["4"] = {label = "Wheel Rear (L)", bone = "wheel_lr", index = 4, wheelId = 2},
        ["5"] = {label = "Wheel Rear (R)", bone = "wheel_rr", index = 5, wheelId = 3},
    },
    ["6"] = { -- Vehicle with 6 wheels.
        ["0"] = {label = "Wheel Front (L)", bone = "wheel_lf", index = 0, wheelId = 0},
        ["1"] = {label = "Wheel Front (R)", bone = "wheel_rf", index = 1, wheelId = 1},
        ["2"] = {label = "Wheel Middle (L)", bone = "wheel_lm1", index = 2, wheelId = 4},
        ["3"] = {label = "Wheel Middle (R)", bone = "wheel_rm1", index = 3, wheelId = 5},
        ["4"] = {label = "Wheel Rear (L)", bone = "wheel_lr", index = 4, wheelId = 2},
        ["5"] = {label = "Wheel Rear (R)", bone = "wheel_rr", index = 5, wheelId = 3},
    },
    ["8"] = { -- Vehicle with 8 wheels.
        ["0"] = {label = "Wheel Front (L)", bone = "wheel_lf", index = 0, wheelId = 0},
        ["1"] = {label = "Wheel Front (R)", bone = "wheel_rf", index = 1, wheelId = 1},
        ["2"] = {label = "Wheel Middle (L)", bone = "wheel_lm1", index = 2, wheelId = 4},
        ["3"] = {label = "Wheel Middle (R)", bone = "wheel_rm1", index = 3, wheelId = 5},
        ["4"] = {label = "Wheel Rear (L)", bone = "wheel_lr", index = 4, wheelId = 2},
        ["5"] = {label = "Wheel Rear (R)", bone = "wheel_rr", index = 5, wheelId = 3},
    },
}

_API.VehicleDoors = {
    ["0"] = {label = "Door Front (L)", bone = "door_dside_f", bone2 = "seat_dside_f", index = 0},
    ["1"] = {label = "Door Front (R)", bone = "door_pside_f", bone2 = "seat_pside_f", index = 1},
    ["2"] = {label = "Door Rear (L)", bone = "door_dside_r", bone2 = "seat_dside_r", index = 2},
    ["3"] = {label = "Door Rear (R)", bone = "door_pside_r", bone2 = "seat_pside_r", index = 3},
    ["4"] = {label = "Hood", bone = "bonnet", index = 4},
    ["5"] = {label = "Trunk", bone = "boot", index = 5},
}

_API.VehicleWindows = {
    ["0"] = {label = "Window Front (L)", bone = "window_lf", index = 0},
    ["1"] = {label = "Window Front (R)", bone = "window_rf", index = 1},
    ["2"] = {label = "Window Rear (L)", bone = "window_lr", index = 2},
    ["3"] = {label = "Window Rear (R)", bone = "window_rr", index = 3},
    ["6"] = {label = "Windscreen Front", bone = "windscreen", index = 6},
    ["7"] = {label = "Windscreen Rear", bone = "windscreen_r", index = 7},
}

--- Function to spawn vehicle
---@param model number The vehicle model
function _API.SpawnVehicle(model, vehicleCoords, heading, warp, cb, networked)
    if Framework == "esx" then
        _FW[Framework].Game.SpawnVehicle(model, vehicleCoords, heading, cb, networked)
    elseif Framework == "qbox" then
        local netId = lib.callback.await("t1ger_mechanic:server:spawnVehicle", false, model, vehicleCoords, heading, warp)
        if not netId then cb(0) end

        local vehicle = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)
        if cb then
            cb(vehicle)
        end
    elseif Framework == "qbcore" then
        _FW[Framework].Functions.SpawnVehicle(model, cb, coords, networked)
    end
end

--- Function to delete vehicle
---@param vehicle number The vehicle handle
function _API.DeleteVehicle(vehicle)
    if Framework == "esx" then
        _FW[Framework].Game.DeleteVehicle(vehicle)
    elseif Framework == "qbox" then
        qbx.deleteVehicle(vehicle)
    elseif Framework == "qbcore" then
        _FW[Framework].Functions.DeleteVehicle(vehicle)
    end
end

--- Adds keys to player for a given vehicle
--- @param vehicle number The vehicle entity handle
function _API.GiveVehicleKeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    if type(plate) ~= "string" or not plate:match("%S") then return end
    if not _VehicleKeys then return end

    if _VehicleKeys == "qbx_vehiclekeys" then
        lib.callback.await("qbx_vehiclekeys:server:giveKeys", false, VehToNet(vehicle))
    elseif _VehicleKeys == "qb-vehiclekeys" then
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    elseif _VehicleKeys == "t1ger_keys" then
        TriggerServerEvent("t1ger_keys:updateOwnedKeys", plate, true)
    elseif _VehicleKeys == "qs-vehiclekeys" then
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        exports["qs-vehiclekeys"]:GiveKeys(plate, model)
    else
        -- add your own custom vehicle keys export/event in here to add keys
    end
end

--- Remove keys from a player for a given vehicle
--- @param vehicle number The vehicle entity handle
function _API.RemoveVehicleKeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    if type(plate) ~= "string" or not plate:match("%S") then return end
    if not _VehicleKeys then return end

    if _VehicleKeys == "t1ger_keys" then
        TriggerServerEvent("t1ger_keys:updateOwnedKeys", plate, false)
    elseif _VehicleKeys == "qs-vehiclekeys" then
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        exports["qs-vehiclekeys"]:RemoveKeys(plate, model)
    else
        -- add your own custom vehicle keys export/event in here to remove keys
    end
end

-- Public export — sets props via statebag so it replicates to all clients
local function SetVehicleProperties(vehicle, props)
    local ent = Entity(vehicle).state
    ent:set("t1ger_mechanic:setVehicleProps", props, true)
end
exports("SetVehicleProperties", SetVehicleProperties)

--- Function to set vehicle properties
---@param vehicle number The vehicle handle
---@param props table The vehicle properties
function _API.SetVehicleProperties(vehicle, props)
    if Bridge.UseFrameworkVehicleProps then
        if Framework == "esx" then
            _FW[Framework].Game.SetVehicleProperties(vehicle, props)
        elseif Framework == "qbox" then 
            lib.setVehicleProperties(vehicle, props)
        elseif Framework == "qbcore" then
            _FW[Framework].Functions.SetVehicleProperties(vehicle, props)
        end
    else        
        SetVehicleProperties(vehicle, props)
    end
end

--- Custom function to retrieve vehicle properties.
--- Includes compatibility aliases for esx/qbcore/qbox door, window, tyre and
--- xenon/livery key names so external scripts (garages, dealerships etc.)
--- reading the "standard" prop format for their framework still work when
--- this overrides the framework's own vehicle property function.
---@param vehicle number the vehicle handle
---@return props table the properties of the vehicle
local function GetVehicleProperties(vehicle)
    if DoesEntityExist(vehicle) then
        ---@type number | number[], number | number[]
        local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
        local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
        local paintType1 = GetVehicleModColor_1(vehicle)
        local paintType2 = GetVehicleModColor_2(vehicle)

        -- Custom Colors:
        if GetIsVehiclePrimaryColourCustom(vehicle) then
            colorPrimary = { GetVehicleCustomPrimaryColour(vehicle) }
        end

        if GetIsVehicleSecondaryColourCustom(vehicle) then
            colorSecondary = { GetVehicleCustomSecondaryColour(vehicle) }
        end

        -- Custom Xenon (RGB):
        local hasCustomXenon, customXenonR, customXenonG, customXenonB = GetVehicleXenonLightsCustomColor(vehicle)
        local customXenon = nil
        if hasCustomXenon then
            customXenon = {customXenonR, customXenonG, customXenonB}
        end

        local extras = {}
        for i = 0, 20 do
            if DoesExtraExist(vehicle, i) then
                extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i) and 0 or 1
            end
        end

        -- Roll up windows before checking status (fixes state when storing
        -- a vehicle with windows down). Door/window/tyre status themselves
        -- are computed per-framework below, only for the active framework.
        for index = 0, 7 do
            RollUpWindow(vehicle, index)
        end

        local numDoors  = GetNumberOfVehicleDoors(vehicle)
        local numWheels = GetVehicleNumberOfWheels(vehicle)

        local neons = {}
        for i = 0, 3 do
            neons[tostring(i)] = IsVehicleNeonLightEnabled(vehicle, i)
        end

        local plate = GetVehicleNumberPlateText(vehicle)

        local props = {
            model = GetEntityModel(vehicle),
            plate = Bridge.TrimPlates and TrimPlate(plate) or plate,
            plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
            bodyHealth = math.floor(GetVehicleBodyHealth(vehicle) + 0.5),
            engineHealth = math.floor(GetVehicleEngineHealth(vehicle) + 0.5),
            tankHealth = math.floor(GetVehiclePetrolTankHealth(vehicle) + 0.5),
            fuelLevel = math.floor(GetVehicleFuelLevel(vehicle) + 0.5),
            oilLevel = math.floor(GetVehicleOilLevel(vehicle) + 0.5),
            dirtLevel = math.floor(GetVehicleDirtLevel(vehicle) + 0.5),
            paintType1 = paintType1,
            paintType2 = paintType2,
            color1 = colorPrimary,
            color2 = colorSecondary,
            pearlescentColor = pearlescentColor,
            interiorColor = GetVehicleInteriorColor(vehicle),
            dashboardColor = GetVehicleDashboardColour(vehicle),
            wheelColor = wheelColor,
            wheelWidth = GetVehicleWheelWidth(vehicle),
            wheelSize = GetVehicleWheelSize(vehicle),
            wheels = GetVehicleWheelType(vehicle),
            windowTint = GetVehicleWindowTint(vehicle),
            xenonColor = GetVehicleXenonLightsColor(vehicle),
            customXenon = customXenon,
            neonEnabled = neons,
            neonColor = { GetVehicleNeonLightsColour(vehicle) },
            extras = extras,
            tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
            modSpoilers = GetVehicleMod(vehicle, 0),
            modFrontBumper = GetVehicleMod(vehicle, 1),
            modRearBumper = GetVehicleMod(vehicle, 2),
            modSideSkirt = GetVehicleMod(vehicle, 3),
            modExhaust = GetVehicleMod(vehicle, 4),
            modFrame = GetVehicleMod(vehicle, 5),
            modGrille = GetVehicleMod(vehicle, 6),
            modHood = GetVehicleMod(vehicle, 7),
            modFender = GetVehicleMod(vehicle, 8),
            modRightFender = GetVehicleMod(vehicle, 9),
            modRoof = GetVehicleMod(vehicle, 10),
            modEngine = GetVehicleMod(vehicle, 11),
            modBrakes = GetVehicleMod(vehicle, 12),
            modTransmission = GetVehicleMod(vehicle, 13),
            modHorns = GetVehicleMod(vehicle, 14),
            modSuspension = GetVehicleMod(vehicle, 15),
            modArmor = GetVehicleMod(vehicle, 16),
            modNitrous = GetVehicleMod(vehicle, 17),
            modTurbo = IsToggleModOn(vehicle, 18),
            modSubwoofer = GetVehicleMod(vehicle, 19),
            modSmokeEnabled = IsToggleModOn(vehicle, 20),
            modHydraulics = IsToggleModOn(vehicle, 21),
            modXenon = IsToggleModOn(vehicle, 22),
            modFrontWheels = GetVehicleMod(vehicle, 23),
            modBackWheels = GetVehicleMod(vehicle, 24),
            modCustomTiresF = GetVehicleModVariation(vehicle, 23),
            modCustomTiresR = GetVehicleModVariation(vehicle, 24),
            modPlateHolder = GetVehicleMod(vehicle, 25),
            modVanityPlate = GetVehicleMod(vehicle, 26),
            modTrimA = GetVehicleMod(vehicle, 27),
            modOrnaments = GetVehicleMod(vehicle, 28),
            modDashboard = GetVehicleMod(vehicle, 29),
            modDial = GetVehicleMod(vehicle, 30),
            modDoorSpeaker = GetVehicleMod(vehicle, 31),
            modSeats = GetVehicleMod(vehicle, 32),
            modSteeringWheel = GetVehicleMod(vehicle, 33),
            modShifterLeavers = GetVehicleMod(vehicle, 34),
            modAPlate = GetVehicleMod(vehicle, 35),
            modSpeakers = GetVehicleMod(vehicle, 36),
            modTrunk = GetVehicleMod(vehicle, 37),
            modHydrolic = GetVehicleMod(vehicle, 38),
            modEngineBlock = GetVehicleMod(vehicle, 39),
            modAirFilter = GetVehicleMod(vehicle, 40),
            modStruts = GetVehicleMod(vehicle, 41),
            modArchCover = GetVehicleMod(vehicle, 42),
            modAerials = GetVehicleMod(vehicle, 43),
            modTrimB = GetVehicleMod(vehicle, 44),
            modTank = GetVehicleMod(vehicle, 45),
            modWindows = GetVehicleMod(vehicle, 46),
            modDoorR = GetVehicleMod(vehicle, 47),
            modLivery = GetVehicleMod(vehicle, 48) == -1 and GetVehicleLivery(vehicle) or GetVehicleMod(vehicle, 48),
            modRoofLivery = GetVehicleRoofLivery(vehicle),
            modLightbar = GetVehicleMod(vehicle, 49),
            customTires = GetVehicleModVariation(vehicle, 23),
            bulletProofTyres = GetVehicleTyresCanBurst(vehicle),
            driftTyres = GetGameBuildNumber() >= 2372 and GetDriftTyresEnabled(vehicle) or nil,
        }

        -- Framework compatibility aliases:
        -- Only computed for the active framework, matching that framework's
        -- exact loop ranges, key types and semantics (these genuinely differ
        -- between esx/qbcore/qbox — not just key names).

        if Framework == "esx" then
            local doorsBroken, windowsBroken, tyreBurst = {}, {}, {}

            for doorId = 0, numDoors do
                doorsBroken[tostring(doorId)] = IsVehicleDoorDamaged(vehicle, doorId)
            end

            for windowId = 0, 7 do
                windowsBroken[tostring(windowId)] = not IsVehicleWindowIntact(vehicle, windowId)
            end

            local tyresIndex = {
                ["2"] = { 0, 4 },
                ["3"] = { 0, 1, 4, 5 },
                ["4"] = { 0, 1, 4, 5 },
                ["6"] = { 0, 1, 2, 3, 4, 5 },
            }
            local numWheelsStr = tostring(numWheels)
            if tyresIndex[numWheelsStr] then
                for _, idx in ipairs(tyresIndex[numWheelsStr]) do
                    tyreBurst[tostring(idx)] = IsVehicleTyreBurst(vehicle, idx, false)
                end
            end

            props.doorsBroken      = doorsBroken
            props.windowsBroken    = windowsBroken
            props.tyreBurst        = tyreBurst
            props.customXenonColor = customXenon
            props.tyresCanBurst    = props.bulletProofTyres
            props.modCustomFrontWheels = props.modCustomTiresF
            props.modCustomBackWheels  = props.modCustomTiresR

        elseif Framework == "qbcore" then
            local doorStatus, windowStatus, tireBurstState, tireBurstCompletely, tireHealth = {}, {}, {}, {}, {}

            for i = 0, 5 do
                doorStatus[i]          = IsVehicleDoorDamaged(vehicle, i) == 1
                tireBurstState[i]      = IsVehicleTyreBurst(vehicle, i, false)
                tireBurstCompletely[i] = IsVehicleTyreBurst(vehicle, i, true)
                tireHealth[i]          = GetVehicleWheelHealth(vehicle, i)
            end
            for i = 0, 7 do
                windowStatus[i] = IsVehicleWindowIntact(vehicle, i) == 1
            end

            props.doorStatus          = doorStatus
            props.windowStatus        = windowStatus
            props.tireBurstState      = tireBurstState
            props.tireBurstCompletely = tireBurstCompletely
            props.tireHealth          = tireHealth
            props.liveryRoof          = props.modRoofLivery

        elseif Framework == "qbox" then
            local damageWindows, damageDoors, damageTyres = {}, {}, {}
            local windowCount, doorCount = 0, 0

            for i = 0, 7 do
                if not IsVehicleWindowIntact(vehicle, i) then
                    windowCount = windowCount + 1
                    damageWindows[windowCount] = i
                end
            end
            for i = 0, 5 do
                if IsVehicleDoorDamaged(vehicle, i) then
                    doorCount = doorCount + 1
                    damageDoors[doorCount] = i
                end
            end
            for i = 0, 7 do
                if IsVehicleTyreBurst(vehicle, i, false) then
                    damageTyres[i] = IsVehicleWheelBrokenOff(vehicle, i) and 3
                        or (IsVehicleTyreBurst(vehicle, i, true) and 2 or 1)
                end
            end

            props.doors   = damageDoors
            props.windows = damageWindows
            props.tyres   = damageTyres
            props.livery  = GetVehicleLivery(vehicle)
        end

        return props
    end
end
exports("GetVehicleProperties", GetVehicleProperties)

--- Function to get vehicle properties
---@param vehicle number The vehicle handle
---@return props table The vehicle properties
function _API.GetVehicleProperties(vehicle)
    if Bridge.UseFrameworkVehicleProps then
        if Framework == "esx" then
            return _FW[Framework].Game.GetVehicleProperties(vehicle)
        elseif Framework == "qbox" then
            return lib.getVehicleProperties(vehicle)
        elseif Framework == "qbcore" then
            return  _FW[Framework].Functions.GetVehicleProperties(vehicle)
        end
    else
        return GetVehicleProperties(vehicle)
    end
end

--- Function to get vehicle fuel level
---@param vehicle number The vehicle handle
---@return fuelLevel number The fuel level
function _API.GetVehicleFuel(vehicle)
    return GetVehicleFuelLevel(vehicle)
end

--- Function to set vehicle fuel level
---@param vehicle number The vehicle entity handle
---@param fuelLevel number The fuel level to set
function _API.SetVehicleFuel(vehicle, fuel)
    SetVehicleFuelLevel(vehicle, fuel)
end

--- Function to impound a vehicle
---@param vehicle number The vehicle entity handle
function _API.ImpoundVehicle(vehicle)
    local props = _API.GetVehicleProperties(vehicle)

    -- if u have a custom client export/event, then use that and comment out this trigger server event
    TriggerServerEvent("t1ger_mechanic:server:impoundVehicle", props.plate, props)

    -- delete the vehicle? Comment out if your own export/event deletes a vehicle
    _API.DeleteVehicle(vehicle)
end

--- Custom function to set vehicle properties.
--- Reads door/window/tyre/xenon/livery data using esx/qbcore/qbox naming
--- conventions directly — since each framework stores this with different
--- meaning (not just different key names), each is handled explicitly below.
---@param vehicle number the vehicle handle
---@param props table the properties of the vehicle
local function ApplyVehicleProperties(vehicle, props)

    if not DoesEntityExist(vehicle) then
        return
    end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    SetVehicleModKit(vehicle, 0)

    if props.extras then
        for id, toggle in pairs(props.extras) do
            local extraId = tonumber(id)
            if type(toggle) == "boolean" then
                if toggle then
                    SetVehicleExtra(vehicle, extraId, 0)
                else
                    SetVehicleExtra(vehicle, extraId, 1)
                end
            else
                SetVehicleExtra(vehicle, extraId, toggle)
            end
        end
    end

    if props.plate then
        SetVehicleNumberPlateText(vehicle, props.plate)
    end

    if props.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
    end

    if props.bodyHealth then
        SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
    end

    if props.engineHealth then
        SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0)
    end

    if props.tankHealth then
        SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0)
    end

    if props.fuelLevel then
        SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
    end

    if props.oilLevel then
        SetVehicleOilLevel(vehicle, props.oilLevel + 0.0)
    end

    if props.dirtLevel then
        SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0)
    end

    if props.color1 then
        if type(props.color1) == "number" then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleModColor_1(vehicle, props.paintType1 or 0, props.color1, pearlescentColor)
            SetVehicleColours(vehicle, props.color1, type(props.color2) == "number" and props.color2 or colorSecondary)
        else
            if props.paintType1 then
                SetVehicleModColor_1(vehicle, props.paintType1, 0, pearlescentColor)
            end
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])
        end
    end

    if props.color2 then
        if type(props.color2) == "number" then
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleModColor_2(vehicle, props.paintType2 or 0, props.color2)
            SetVehicleColours(vehicle, type(props.color1) == "number" and props.color1 or colorPrimary, props.color2)
            if type(props.color1) ~= "number" then
                SetVehicleModColor_1(vehicle, props.paintType1 or 0, 0, pearlescentColor)
            end
        else
            if props.paintType2 then
                SetVehicleModColor_2(vehicle, props.paintType2, 0)
            end
            SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3])
        end
    end

    if props.pearlescentColor or props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor or wheelColor)
    end

    if props.interiorColor then
        SetVehicleInteriorColor(vehicle, props.interiorColor)
    end

    if props.dashboardColor then
        SetVehicleDashboardColor(vehicle, props.dashboardColor)
    end

    if props.wheels then
        SetVehicleWheelType(vehicle, props.wheels)
    end

    if props.wheelSize then
        SetVehicleWheelSize(vehicle, props.wheelSize)
    end

    if props.wheelWidth then
        SetVehicleWheelWidth(vehicle, props.wheelWidth)
    end

    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end

    if props.neonEnabled then
        for k, v in pairs(props.neonEnabled) do
            SetVehicleNeonLightEnabled(vehicle, tonumber(k), v)
        end
    end

    -- ── Windows ──────────────────────────────────────────────────────────
    -- Each framework stores broken/intact with different meaning:
    --   esx:     { [index] = boolean } true means broken
    --   qbcore:  { [index] = boolean } true means intact (false = broken)
    --   qbox:    array of window ids that ARE broken
    if props.windowsBroken then
        for index, broken in pairs(props.windowsBroken) do
            if broken then
                RemoveVehicleWindow(vehicle, tonumber(index))
            end
        end
    elseif props.windowStatus then
        for index, intact in pairs(props.windowStatus) do
            if not intact then
                RemoveVehicleWindow(vehicle, tonumber(index))
            end
        end
    elseif props.windows then
        for _, windowId in pairs(props.windows) do
            RemoveVehicleWindow(vehicle, windowId)
        end
    end

    -- ── Doors ────────────────────────────────────────────────────────────
    --   esx:     { [index] = boolean } true means broken
    --   qbcore:  { [index] = boolean } true means broken
    --   qbox:    array of door ids that ARE broken
    if props.doorsBroken then
        for index, broken in pairs(props.doorsBroken) do
            if broken then
                SetVehicleDoorBroken(vehicle, tonumber(index), true)
            end
        end
    elseif props.doorStatus then
        for index, broken in pairs(props.doorStatus) do
            if broken then
                SetVehicleDoorBroken(vehicle, tonumber(index), true)
            end
        end
    elseif props.doors then
        for _, doorId in pairs(props.doors) do
            SetVehicleDoorBroken(vehicle, doorId, true)
        end
    end

    -- ── Tyres ────────────────────────────────────────────────────────────
    --   esx:     { [index] = boolean } true means burst
    --   qbcore:  tireBurstState (boolean) + tireBurstCompletely (boolean)
    --   qbox:    { [wheelIndex] = 1|2|3 } burst / burst+missing / broken off
    if props.tyreBurst then
        for index, burst in pairs(props.tyreBurst) do
            if burst then
                SetVehicleTyreBurst(vehicle, tonumber(index), true, 1000.0)
            end
        end
    elseif props.tireBurstState then
        for index, burst in pairs(props.tireBurstState) do
            if burst then
                local completely = props.tireBurstCompletely and props.tireBurstCompletely[index]
                SetVehicleTyreBurst(vehicle, index, completely or false, 1000.0)
            end
        end
    elseif props.tyres then
        for index, state in pairs(props.tyres) do
            SetVehicleTyreBurst(vehicle, tonumber(index), state == 2 or state == 3, 1000.0)
        end
    end

    -- Per-wheel health — qbcore only
    if props.tireHealth then
        for wheelIndex, health in pairs(props.tireHealth) do
            SetVehicleWheelHealth(vehicle, tonumber(wheelIndex) or wheelIndex, health)
        end
    end

    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end

    if props.modSmokeEnabled ~= nil then
        ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled)
    end

    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end

    if props.modSpoilers then SetVehicleMod(vehicle, 0, props.modSpoilers, false) end
    if props.modFrontBumper then SetVehicleMod(vehicle, 1, props.modFrontBumper, false) end
    if props.modRearBumper then SetVehicleMod(vehicle, 2, props.modRearBumper, false) end
    if props.modSideSkirt then SetVehicleMod(vehicle, 3, props.modSideSkirt, false) end
    if props.modExhaust then SetVehicleMod(vehicle, 4, props.modExhaust, false) end
    if props.modFrame then SetVehicleMod(vehicle, 5, props.modFrame, false) end
    if props.modGrille then SetVehicleMod(vehicle, 6, props.modGrille, false) end
    if props.modHood then SetVehicleMod(vehicle, 7, props.modHood, false) end
    if props.modFender then SetVehicleMod(vehicle, 8, props.modFender, false) end
    if props.modRightFender then SetVehicleMod(vehicle, 9, props.modRightFender, false) end
    if props.modRoof then SetVehicleMod(vehicle, 10, props.modRoof, false) end
    if props.modEngine then SetVehicleMod(vehicle, 11, props.modEngine, false) end
    if props.modBrakes then SetVehicleMod(vehicle, 12, props.modBrakes, false) end
    if props.modTransmission then SetVehicleMod(vehicle, 13, props.modTransmission, false) end
    if props.modHorns then SetVehicleMod(vehicle, 14, props.modHorns, false) end
    if props.modSuspension then SetVehicleMod(vehicle, 15, props.modSuspension, false) end
    if props.modArmor then SetVehicleMod(vehicle, 16, props.modArmor, false) end
    if props.modNitrous then SetVehicleMod(vehicle, 17, props.modNitrous, false) end

    if props.modTurbo ~= nil then
        ToggleVehicleMod(vehicle, 18, props.modTurbo)
    end

    if props.modSubwoofer ~= nil then
        ToggleVehicleMod(vehicle, 19, props.modSubwoofer)
    end

    if props.modHydraulics ~= nil then
        ToggleVehicleMod(vehicle, 21, props.modHydraulics)
    end

    if props.modXenon ~= nil then
        ToggleVehicleMod(vehicle, 22, props.modXenon)
    end

    if props.xenonColor then
        if type(props.xenonColor) == "table" then
            props.customXenon = {props.xenonColor[1], props.xenonColor[2], props.xenonColor[3]}
            SetVehicleXenonLightsCustomColor(vehicle, props.customXenon[1], props.customXenon[2], props.customXenon[3])
        else
            ClearVehicleXenonLightsCustomColor(vehicle)
            SetVehicleXenonLightsColor(vehicle, props.xenonColor)
        end
    end

    -- Custom xenon RGB — accept our key or esx's customXenonColor
    local customXenonData = props.customXenon or props.customXenonColor
    if customXenonData ~= nil then
        SetVehicleXenonLightsCustomColor(vehicle, customXenonData[1], customXenonData[2], customXenonData[3])
    end

    if props.modFrontWheels then
        SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF or props.modCustomFrontWheels)
    end

    if props.modBackWheels then
        SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR or props.modCustomBackWheels)
    end

    if props.modPlateHolder then SetVehicleMod(vehicle, 25, props.modPlateHolder, false) end
    if props.modVanityPlate then SetVehicleMod(vehicle, 26, props.modVanityPlate, false) end
    if props.modTrimA then SetVehicleMod(vehicle, 27, props.modTrimA, false) end
    if props.modOrnaments then SetVehicleMod(vehicle, 28, props.modOrnaments, false) end
    if props.modDashboard then SetVehicleMod(vehicle, 29, props.modDashboard, false) end
    if props.modDial then SetVehicleMod(vehicle, 30, props.modDial, false) end
    if props.modDoorSpeaker then SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false) end
    if props.modSeats then SetVehicleMod(vehicle, 32, props.modSeats, false) end
    if props.modSteeringWheel then SetVehicleMod(vehicle, 33, props.modSteeringWheel, false) end
    if props.modShifterLeavers then SetVehicleMod(vehicle, 34, props.modShifterLeavers, false) end
    if props.modAPlate then SetVehicleMod(vehicle, 35, props.modAPlate, false) end
    if props.modSpeakers then SetVehicleMod(vehicle, 36, props.modSpeakers, false) end
    if props.modTrunk then SetVehicleMod(vehicle, 37, props.modTrunk, false) end
    if props.modHydrolic then SetVehicleMod(vehicle, 38, props.modHydrolic, false) end
    if props.modEngineBlock then SetVehicleMod(vehicle, 39, props.modEngineBlock, false) end
    if props.modAirFilter then SetVehicleMod(vehicle, 40, props.modAirFilter, false) end
    if props.modStruts then SetVehicleMod(vehicle, 41, props.modStruts, false) end
    if props.modArchCover then SetVehicleMod(vehicle, 42, props.modArchCover, false) end
    if props.modAerials then SetVehicleMod(vehicle, 43, props.modAerials, false) end
    if props.modTrimB then SetVehicleMod(vehicle, 44, props.modTrimB, false) end
    if props.modTank then SetVehicleMod(vehicle, 45, props.modTank, false) end
    if props.modWindows then SetVehicleMod(vehicle, 46, props.modWindows, false) end
    if props.modDoorR then SetVehicleMod(vehicle, 47, props.modDoorR, false) end

    if props.modLivery then
        SetVehicleMod(vehicle, 48, props.modLivery, false)
        SetVehicleLivery(vehicle, props.modLivery)
    end

    if props.livery then
        SetVehicleLivery(vehicle, props.modLivery)
    end

    -- Roof livery — accept our key or QBCore's liveryRoof
    local roofLiveryData = props.modRoofLivery or props.liveryRoof
    if roofLiveryData then
        SetVehicleRoofLivery(vehicle, roofLiveryData)
    end

    if props.modLightbar then
        SetVehicleMod(vehicle, 49, props.modLightbar, false)
    end

    -- Bulletproof tyres — accept our/qbx key or esx's tyresCanBurst
    local bulletProofData = props.bulletProofTyres
    if bulletProofData == nil then
        bulletProofData = props.tyresCanBurst
    end

    if bulletProofData ~= nil then
        SetVehicleTyresCanBurst(vehicle, bulletProofData)
    end

    if gameBuild >= 2372 and props.driftTyres ~= nil then
        SetDriftTyresEnabled(vehicle, props.driftTyres)
        if type(props.driftTyres) == "boolean" and props.driftTyres == true or props.driftTyres == 1 then
            SetReduceDriftVehicleSuspension(vehicle, true)
        else
            SetReduceDriftVehicleSuspension(vehicle, false)
        end
    end
end

--- State bag change handler — applies props on whichever client owns the vehicle
AddStateBagChangeHandler("t1ger_mechanic:setVehicleProps", nil, function(bagName, key, value, _unused, replicated)
    Wait(0)

    if replicated then return end
    if not value then return end

    local net     = tonumber(bagName:gsub("entity:", ""), 10)
    local vehicle = net and NetworkGetEntityFromNetworkId(net)

    if DoesEntityExist(vehicle) then
        ApplyVehicleProperties(vehicle, value)
    end
end)