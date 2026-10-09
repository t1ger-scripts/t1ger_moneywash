--- ============================================================================
--- Business Persistence
--- Loads businesses from the database on startup and saves them back.
--- ============================================================================

local BUSINESS_LOCATION_COORDINATE_TOLERANCE = 0.25

--- Validates that a stored location ID still references the physical
--- location that was recorded when the business was purchased.
---@param row table
---@return boolean valid
---@return string|nil errorMessage
local function validateBusinessLocationSnapshot(row)
    local locationId = tonumber(row.location_id)
    local location = locationId
        and GetLocationConfig(row.business_type, locationId)
        or nil

    if not location or not location.coords then
        return false, (
            "[MoneyWash] Business #%s references missing location %s #%s."
        ):format(
            tostring(row.id),
            tostring(row.business_type),
            tostring(row.location_id)
        )
    end

    local configuredX = tonumber(location.coords.x)
    local configuredY = tonumber(location.coords.y)
    local configuredZ = tonumber(location.coords.z)

    if not configuredX or not configuredY or not configuredZ then
        return false, (
            "[MoneyWash] Configured coordinates are invalid for %s #%s."
        ):format(
            tostring(row.business_type),
            tostring(row.location_id)
        )
    end

    local storedX = tonumber(row.location_x)
    local storedY = tonumber(row.location_y)
    local storedZ = tonumber(row.location_z)

    -- One-time migration for businesses created before coordinate snapshots
    -- were introduced. The current configuration becomes the baseline.
    if not storedX or not storedY or not storedZ then
        local updateSucceeded, updateResult = pcall(
            MySQL.update.await,
            "UPDATE moneywash_businesses " ..
            "SET location_x = ?, location_y = ?, location_z = ? " ..
            "WHERE id = ?",
            {
                configuredX,
                configuredY,
                configuredZ,
                row.id,
            }
        )

        if not updateSucceeded or updateResult == nil then
            return false, (
                "[MoneyWash] Failed to create the location snapshot for business #%s: %s"
            ):format(
                tostring(row.id),
                tostring(updateResult)
            )
        end

        row.location_x = configuredX
        row.location_y = configuredY
        row.location_z = configuredZ

        storedX = configuredX
        storedY = configuredY
        storedZ = configuredZ

        if Config.Debug then
            print((
                "[MoneyWash] Created location snapshot for business #%s (%s #%s)."
            ):format(
                tostring(row.id),
                tostring(row.business_type),
                tostring(row.location_id)
            ))
        end
    end

    local differenceX = configuredX - storedX
    local differenceY = configuredY - storedY
    local differenceZ = configuredZ - storedZ

    local distance = math.sqrt(
        differenceX * differenceX
        + differenceY * differenceY
        + differenceZ * differenceZ
    )

    if distance > BUSINESS_LOCATION_COORDINATE_TOLERANCE then
        return false, ([[
[MoneyWash] Business location validation failed.
Business ID: %s
Type: %s
Location ID: %s
Stored coordinates: %.6f, %.6f, %.6f
Configured coordinates: %.6f, %.6f, %.6f
Distance changed: %.3f metres
The location ID appears to have been moved or reassigned.]]):format(
            tostring(row.id),
            tostring(row.business_type),
            tostring(row.location_id),
            storedX,
            storedY,
            storedZ,
            configuredX,
            configuredY,
            configuredZ,
            distance
        )
    end

    return true
end

--- Loads and validates every persisted business, then marks the store ready.
--- @return boolean success
function LoadBusinesses()
    local results = MySQL.query.await("SELECT * FROM moneywash_businesses")

    if not results then
        print(
            "[MoneyWash] Failed to load businesses. " ..
            "The business portal will remain unavailable."
        )
        return false
    end

    local validationFailed = false

    for _, row in ipairs(results) do
        local valid, errorMessage = validateBusinessLocationSnapshot(row)

        if not valid then
            validationFailed = true
            print(errorMessage)
        end
    end

    if validationFailed then
        print(
            "[MoneyWash] Business initialization stopped because one or " ..
            "more persisted locations no longer match the configuration."
        )
        return false
    end

    for _, row in ipairs(results) do
        AddToStore(row.id, row)
    end

    SetBusinessStoreReady(true)

    if Config.Debug then
        print(("[MoneyWash] Loaded %d businesses on startup"):format(#results))
    end

    return true
end

local BusinessSaves = {}
function IsBusinessSaveInProgress(id) return BusinessSaves[id] == true end

function SaveBusiness(id, force)
    if not force and IsCashCounterSaveBlocked(id) then
        return false
    end

    while BusinessSaves[id] do
        Wait(10)
    end

    if not force and IsCashCounterSaveBlocked(id) then
        return false
    end

    local business = GetBusiness(id)
    if not business then
        return false
    end

    local identifier = business.identifier

    BusinessSaves[id] = true

    local ok, affectedRows = pcall(
        MySQL.update.await,
        "UPDATE moneywash_businesses SET " ..
        "stock = ?, safe_covered = ?, safe_exposed = ?, suspicion = ?, " ..
        "total_laundered = ? " ..
        "WHERE id = ? AND identifier = ?",
        {
            business.stock,
            business.safeCovered,
            business.safeExposed,
            business.suspicion,
            business.totalLaundered,
            business.id,
            identifier,
        }
    )

    local saved = ok
        and type(affectedRows) == "number"
        and affectedRows > 0

    -- Zero changed rows can mean the values were already saved.
    -- Verify that the expected business/owner still exists.
    if ok and affectedRows == 0 then
        local found, existingId = pcall(
            MySQL.scalar.await,
            "SELECT id FROM moneywash_businesses " ..
            "WHERE id = ? AND identifier = ? LIMIT 1",
            { id, identifier }
        )

        saved = found and existingId ~= nil and existingId ~= false
    end

    BusinessSaves[id] = nil

    if not saved then
        print((
            "[MoneyWash] Business #%s save failed: %s"
        ):format(
            tostring(id),
            ok
            and "No valid save result for the expected business owner."
            or tostring(affectedRows)
        ))
    end

    return saved
end

function SaveAllBusinesses()
    for id in pairs(GetAllBusinesses()) do
        SaveBusiness(id)
    end
    if Config.Debug then
        print("[MoneyWash] All businesses saved")
    end
end