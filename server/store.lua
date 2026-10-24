--- Business store: every owned business in memory, loaded from and saved to the database.
--- Other files read and write businesses only through these functions.

local COORDINATE_TOLERANCE = 0.25 -- metres a location may drift from its purchased position

local businesses = {} -- keyed by database id
local storeReady = false
local saving = {} -- business ids with a save in progress
local cycleStartedAt = os.time()

--- Returns whether the business load on startup has finished.
---@return boolean
function IsBusinessStoreReady()
    return storeReady
end

--- Returns a business by its database id.
---@param id number
---@return table|nil
function GetBusiness(id)
    return businesses[id]
end

--- Returns a business by its type and location id.
---@param businessType string
---@param locationId number
---@return table|nil
function GetBusinessByLocation(businessType, locationId)
    for _, business in pairs(businesses) do
        if business.type == businessType and business.locationId == locationId then
            return business
        end
    end

    return nil
end

--- Returns all businesses owned by a player.
---@param identifier string
---@return table[]
function GetPlayerBusinesses(identifier)
    local result = {}

    for _, business in pairs(businesses) do
        if business.identifier == identifier then
            result[#result + 1] = business
        end
    end

    return result
end

--- Returns every business, keyed by id. Iterate only, never modify.
---@return table<number, table>
function GetAllBusinesses()
    return businesses
end

--- Returns whether any player owns the location.
---@param businessType string
---@param locationId number
---@return boolean
function IsLocationOwned(businessType, locationId)
    return GetBusinessByLocation(businessType, locationId) ~= nil
end

--- Returns whether a player owns a business.
---@param identifier string
---@return boolean
function PlayerOwnsBusiness(identifier)
    for _, business in pairs(businesses) do
        if business.identifier == identifier then return true end
    end

    return false
end

--- Adds a business to the store.
---@param id number Database id
---@param data table Database row, or the same fields
function AddToStore(id, data)
    businesses[id] = {
        id             = id,
        identifier     = data.identifier,
        type           = data.business_type,
        locationId     = data.location_id,
        stock          = data.stock or 0,
        safeCovered    = data.safe_covered or 0,
        safeExposed    = data.safe_exposed or 0,
        suspicion      = data.suspicion or 0,
        totalLaundered = data.total_laundered or 0, -- lifetime, saved
        cycleLaundered = 0, -- this cycle only, never saved
        purchasedAt    = data.purchased_at or os.time(),
    }
end

--- Removes a business from the store.
---@param id number
function RemoveFromStore(id)
    businesses[id] = nil
end

--- Every owned location, for spawning the Handler NPCs. Never includes the owner.
---@return { id: number, type: string, locationId: number }[]
function GetPublicBusinessLocations()
    local list = {}

    for _, business in pairs(businesses) do
        list[#list + 1] = { id = business.id, type = business.type, locationId = business.locationId }
    end

    return list
end

--- Sends the public location list to one player, or to everyone.
---@param target number|nil Player source (nil = everyone)
function BroadcastBusinessLocations(target)
    TriggerClientEvent("t1ger_moneywash:client:syncLocations", target or -1, GetPublicBusinessLocations())
end

--- Sets one field on a business in memory. SaveBusiness writes it to the database.
---@param id number
---@param key string
---@param value any
function UpdateBusiness(id, key, value)
    if not businesses[id] then return end

    businesses[id][key] = value
end

--- Sets several fields on a business in memory. SaveBusiness writes them to the database.
---@param id number
---@param data table
function UpdateBusinessFields(id, data)
    if not businesses[id] then return end

    for key, value in pairs(data) do
        businesses[id][key] = value
    end
end

--- Checks that a saved business still sits where it was bought.
---@param row table Database row
---@return string|nil problem
local function checkLocation(row)
    local name = ("Business #%s (%s #%s)"):format(row.id, row.business_type, row.location_id)

    local location = GetLocationConfig(row.business_type, tonumber(row.location_id))
    if not location or not location.coords then
        return name .. " references a location that no longer exists in the config."
    end

    local sx, sy, sz = tonumber(row.location_x), tonumber(row.location_y), tonumber(row.location_z)
    if not sx or not sy or not sz then
        return name .. " has no saved location coordinates."
    end

    local c = location.coords
    local distance = math.sqrt((c.x - sx) ^ 2 + (c.y - sy) ^ 2 + (c.z - sz) ^ 2)

    if distance > COORDINATE_TOLERANCE then
        return ("%s moved %.2f m since it was bought. Saved: %.2f, %.2f, %.2f | Config: %.2f, %.2f, %.2f"):format(
            name, distance, sx, sy, sz, c.x, c.y, c.z
        )
    end

    return nil
end

--- Loads every business from the database. Stops if any location no longer matches the config.
---@return boolean success
function LoadBusinesses()
    local rows = MySQL.query.await("SELECT * FROM moneywash_businesses")

    if not rows then
        print("^1[MoneyWash] Failed to load businesses. The portal will stay unavailable.^7")
        return false
    end

    local failed = false

    for _, row in ipairs(rows) do
        local problem = checkLocation(row)

        if problem then
            failed = true
            print("^1[MoneyWash] " .. problem .. "^7")
        end
    end

    if failed then
        print("^1[MoneyWash] Business loading stopped: fix the locations above or restore the config.^7")
        return false
    end

    for _, row in ipairs(rows) do
        AddToStore(row.id, row)
    end

    storeReady = true

    if Config.Debug then
        print(("[MoneyWash] Loaded %d businesses"):format(#rows))
    end

    return true
end

--- Returns whether a business is being written to the database right now.
---@param id number
---@return boolean
function IsBusinessSaveInProgress(id)
    return saving[id] == true
end

--- Saves one business to the database.
--- Skipped while a cash operation holds it, unless force is set.
---@param id number
---@param force boolean|nil
---@return boolean saved
function SaveBusiness(id, force)
    if not force and IsCashOperationSaveBlocked(id) then return false end

    while saving[id] do Wait(10) end

    if not force and IsCashOperationSaveBlocked(id) then return false end

    local business = GetBusiness(id)
    if not business then return false end

    saving[id] = true

    local ok, affected = pcall(
        MySQL.update.await,
        "UPDATE moneywash_businesses SET " ..
        "stock = ?, safe_covered = ?, safe_exposed = ?, suspicion = ?, total_laundered = ? " ..
        "WHERE id = ? AND identifier = ?",
        {
            business.stock,
            business.safeCovered,
            business.safeExposed,
            business.suspicion,
            business.totalLaundered,
            business.id,
            business.identifier,
        }
    )

    local saved = ok and type(affected) == "number" and affected > 0

    -- 0 changed rows can just mean nothing changed: check the row still exists
    if ok and affected == 0 then
        local found, existingId = pcall(
            MySQL.scalar.await,
            "SELECT id FROM moneywash_businesses WHERE id = ? AND identifier = ? LIMIT 1",
            { id, business.identifier }
        )

        saved = found and existingId ~= nil and existingId ~= false
    end

    saving[id] = nil

    if not saved then
        print(("[MoneyWash] Business #%s save failed: %s"):format(
            id, ok and "no valid result from the database" or tostring(affected)
        ))
    end

    return saved
end

--- Saves every business.
function SaveAllBusinesses()
    for id in pairs(businesses) do
        SaveBusiness(id)
    end

    if Config.Debug then
        print("[MoneyWash] All businesses saved")
    end
end

--- Starts a new cycle when the current one has run its course: resets cycleLaundered for every business.
function CheckGlobalCycle()
    local now = os.time()

    if now - cycleStartedAt < Config.Business.CycleDuration * 60 then return end

    cycleStartedAt = now

    for _, business in pairs(businesses) do
        business.cycleLaundered = 0
    end

    if Config.Debug then
        print("[MoneyWash] New cycle started, cycleLaundered reset for all businesses")
    end
end

--- Live status of the player's business, for the Handler menu header. Nil if it isn't theirs.
lib.callback.register("t1ger_moneywash:server:getBusinessStatus", function(source, businessId)
    local identifier = _API.Player.GetIdentifier(source)
    local business = GetBusiness(businessId)

    if not business or business.identifier ~= identifier then return nil end

    if IsBusinessRaided(businessId) then return { raided = true } end

    local tier = GetTierByType(business.type)
    local label = GetSuspicionLabel(business.suspicion)

    return {
        type            = business.type,
        locationId      = business.locationId,
        stock           = business.stock,
        safeCovered     = business.safeCovered,
        safeExposed     = business.safeExposed,
        suspicion       = Config.Suspicion.ShowExactValue and business.suspicion or nil,
        suspicionLabel  = label.name,
        suspicionColor  = label.color,
        cycleLaundered  = business.cycleLaundered,
        expectedRevenue = tier and tier.expectedRevenue or 0,
        unitPrice       = GetUnitPrice(business.type),
        minOrder        = GetMinOrder(business.type),
        maxOrder        = GetMaxOrder(business.type),
        reviewActive    = IsBusinessInReview(businessId),
        reviewCooldown  = GetReviewCooldownRemaining(businessId),
    }
end)