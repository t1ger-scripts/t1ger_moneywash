--- ============================================================================
--- Business Store
--- The single source of truth for all owned business state in memory.
--- All other server files read and write exclusively through these functions.
--- Never access the Businesses table directly from outside this file.
--- ============================================================================

local Businesses = {} -- keyed by DB id (integer)

--- -------------------------------------------------------------------------
--- LOOKUP FUNCTIONS
--- -------------------------------------------------------------------------

--- Returns a business by its database id
--- @param id number
--- @return table|nil
function GetBusiness(id)
    return Businesses[id]
end

--- Returns a business by its type and location id
--- @param businessType string
--- @param locationId number
--- @return table|nil
function GetBusinessByLocation(businessType, locationId)
    for _, business in pairs(Businesses) do
        if business.type == businessType and business.locationId == locationId then
            return business
        end
    end
    return nil
end

--- Returns all businesses owned by a given player identifier
--- @param identifier string
--- @return table
function GetPlayerBusinesses(identifier)
    local result = {}
    for _, business in pairs(Businesses) do
        if business.identifier == identifier then
            result[#result + 1] = business
        end
    end
    return result
end

--- Returns the full in-memory businesses table
--- Use for iteration only - do not modify directly
--- @return table
function GetAllBusinesses()
    return Businesses
end

--- Returns whether a given location is currently owned by any player
--- @param businessType string
--- @param locationId number
--- @return boolean
function IsLocationOwned(businessType, locationId)
    return GetBusinessByLocation(businessType, locationId) ~= nil
end

--- Returns the total portfolio weight currently used by a player
--- @param identifier string
--- @return number
function GetPlayerPortfolioWeight(identifier)
    local weight = 0
    for _, business in pairs(Businesses) do
        if business.identifier == identifier then
            local tier = GetTierByType(business.type)
            if tier then
                weight = weight + tier.weight
            end
        end
    end
    return weight
end

--- Returns whether a player already owns a business of the given type
--- @param identifier string
--- @param businessType string
--- @return boolean
function PlayerOwnsType(identifier, businessType)
    for _, business in pairs(Businesses) do
        if business.identifier == identifier and business.type == businessType then
            return true
        end
    end
    return false
end

--- -------------------------------------------------------------------------
--- STORE MUTATIONS
--- -------------------------------------------------------------------------

--- Adds a business record to the in-memory store
--- @param id number DB primary key
--- @param data table raw DB row or equivalent
function AddToStore(id, data)
    Businesses[id] = {
        id              = id,
        identifier      = data.identifier,
        type            = data.business_type,
        locationId      = data.location_id,
        stock           = data.stock or 0,
        safeCovered     = data.safe_covered or 0,
        safeExposed     = data.safe_exposed or 0,
        suspicion       = data.suspicion or 0,
        totalLaundered  = data.total_laundered or 0,
        lastLaunderedAt = data.last_laundered_at or 0,
        isClosed        = (data.is_closed == 1 or data.is_closed == true),
        closedUntil     = data.closed_until or nil,
        purchasedAt     = data.purchased_at or os.time(),
    }
end

--- Removes a business from the in-memory store
--- @param id number
function RemoveFromStore(id)
    Businesses[id] = nil
end

--- Updates a single field on a business in memory only
--- Use SaveBusiness() in server/main.lua to persist to DB
--- @param id number
--- @param key string
--- @param value any
function UpdateBusiness(id, key, value)
    if not Businesses[id] then return end
    Businesses[id][key] = value
end

--- Updates multiple fields on a business in memory only
--- @param id number
--- @param data table key/value pairs to merge
function UpdateBusinessFields(id, data)
    if not Businesses[id] then return end
    for key, value in pairs(data) do
        Businesses[id][key] = value
    end
end

--- -------------------------------------------------------------------------
--- CONFIG HELPERS
--- Convenience lookups into shared config - used across all business files
--- -------------------------------------------------------------------------

--- Returns the tier config table for a given business type
--- @param businessType string
--- @return table|nil
function GetTierByType(businessType)
    for _, tier in pairs(Config.Business.Tiers) do
        if tier.type == businessType then
            return tier
        end
    end
    return nil
end

--- Returns the location config for a given business type and location id
--- @param businessType string
--- @param locationId number
--- @return table|nil
function GetLocationConfig(businessType, locationId)
    local locations = require("shared/business_locations")
    if not locations[businessType] then return nil end
    return locations[businessType][locationId]
end

--- Returns the suspicion label table for a given suspicion value
--- @param value number 0-100
--- @return table {name, color}
function GetSuspicionLabel(value)
    local label = Config.Suspicion.Labels[1]
    for _, entry in ipairs(Config.Suspicion.Labels) do
        if value >= entry.threshold then
            label = entry
        end
    end
    return label
end

--- Returns the derived unit price for a given business type
--- unitPrice = expectedRevenue * Stock.CostRatio
--- @param businessType string
--- @return number|nil
function GetUnitPrice(businessType)
    local tier = GetTierByType(businessType)
    if not tier then return nil end
    return math.floor(tier.expectedRevenue * Config.Business.Stock.CostRatio)
end

--- Returns the minimum order units for a given business type
--- minOrder = expectedRevenue * Stock.MinOrderRatio
--- @param businessType string
--- @return number|nil
function GetMinOrder(businessType)
    local tier = GetTierByType(businessType)
    if not tier then return nil end
    return math.max(1, math.floor(tier.expectedRevenue * Config.Business.Stock.MinOrderRatio))
end

--- Returns the maximum order units for a given business type
--- maxOrder = expectedRevenue * Stock.MaxOrderRatio
--- @param businessType string
--- @return number|nil
function GetMaxOrder(businessType)
    local tier = GetTierByType(businessType)
    if not tier then return nil end
    return math.floor(tier.expectedRevenue * Config.Business.Stock.MaxOrderRatio)
end

--- Returns stock consumed for a given launder amount and business type
--- stockConsumed = amount * Stock.ConsumptionRatio
--- @param amount number
--- @return number
function GetStockConsumed(amount)
    return math.ceil(amount * Config.Business.Stock.ConsumptionRatio)
end
