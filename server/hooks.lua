--- ============================================================================
--- Server Hooks
--- OPEN FILE - safe to edit without touching core logic.
--- Hook functions called by the business system at key moments.
--- Replace these with your own dispatch system, logging, or integrations.
--- ============================================================================

--- Called when a business is successfully purchased
--- @param identifier string new owner identifier
--- @param businessType string
--- @param locationId number
--- @param price number amount paid
function OnBusinessPurchased(identifier, businessType, locationId, price)
end

--- Called when a business is abandoned (zero refund, all progress forfeited)
--- @param identifier string former owner identifier
--- @param businessId number
--- @param businessType string
--- @param locationId number
function OnBusinessAbandoned(identifier, businessId, businessType, locationId)
end

--- Called when a business is successfully transferred to another player
--- @param fromIdentifier string previous owner
--- @param toIdentifier string new owner
--- @param businessId number
--- @param businessType string
--- @param locationId number
function OnBusinessTransferred(fromIdentifier, toIdentifier, businessId, businessType, locationId)
end

--- Called when a stock delivery mission completes successfully
--- @param identifier string business owner
--- @param businessId number
--- @param businessType string
--- @param unitsOrdered number units originally paid for
--- @param unitsDelivered number actual units delivered, after any cargo damage
--- @param cost number amount paid for the order
function OnStockOrderCompleted(identifier, businessId, businessType, unitsOrdered, unitsDelivered, cost)
end