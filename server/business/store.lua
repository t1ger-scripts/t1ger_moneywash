--- ============================================================
--- Business Store
--- The single source of truth for all owned business state.
--- All other server files read and write through these functions.
--- Never require or depend on other business files directly.
--- ============================================================

local Businesses = {} -- keyed by business DB id (integer)

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

--- Returns all businesses owned by a given identifier
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

--- Returns all businesses currently in memory
--- @return table
function GetAllBusinesses()
    return Businesses
end

--- Adds a business record to the in-memory store
--- @param id number DB primary key
--- @param data table
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

--- Updates a single field on a business in memory only (no DB write)
--- Use SaveBusiness() to persist to DB
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

--- Returns whether a given location is currently owned by any player
--- @param businessType string
--- @param locationId number
--- @return boolean
function IsLocationOwned(businessType, locationId)
    return GetBusinessByLocation(businessType, locationId) ~= nil
end