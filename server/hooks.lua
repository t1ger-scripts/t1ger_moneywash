--- Server Hooks

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

--- Called when dirty cash has been laundered into a business's Safe. Never fires on a failed or retried save
--- @param identifier string business owner
--- @param businessId number
--- @param businessType string
--- @param amount number gross dirty cash amount laundered
--- @param coveredAmount number portion that landed as covered (stock-backed, raid-safe)
--- @param exposedAmount number portion that landed as exposed (raid-seizable)
function OnMoneyLaundered(identifier, businessId, businessType, amount, coveredAmount, exposedAmount)
end

--- Called when the cash counter finishes and a cash bag is given to the owner.
--- @param ownerIdentifier string
--- @param bagId number
--- @param businessId number
--- @param amount number gross amount taken from the Safe
--- @param exposed number part of the amount that was exposed cash (decides the flag chance)
function OnCashBagCreated(ownerIdentifier, bagId, businessId, amount, exposed)
end

--- Called when a cash bag clears into the depositor's personal bank.
--- @param depositorIdentifier string who deposited the bag and got the money
--- @param ownerIdentifier string who withdrew the bag from the business (the same player unless it was stolen)
--- @param businessId number
--- @param gross number amount taken from the Safe
--- @param net number amount paid into the bank after tax
--- @param bagId number
function OnCashBagDeposited(depositorIdentifier, ownerIdentifier, businessId, gross, net, bagId)
end

--- Called when police confiscate a flagged cash bag deposit. The money is gone;
--- this is only a notification point (e.g. reward the officer, log to Discord).
--- @param officerIdentifier string
--- @param depositorIdentifier string the player who made the deposit
--- @param ownerIdentifier string who withdrew the bag from the business
--- @param businessId number
--- @param amount number gross amount that was seized
--- @param bagId number
function OnCashBagConfiscated(officerIdentifier, depositorIdentifier, ownerIdentifier, businessId, amount, bagId)
end

--- Called for each cash bag that was still being deposited when the server restarted. The bag is gone
--- and the money was not paid out. The row stays in moneywash_cashbags with state 'lost',
--- so you can log it or refund the depositor yourself.
--- @param depositorIdentifier string who deposited the bag
--- @param ownerIdentifier string who withdrew it from the business
--- @param businessId number
--- @param amount number gross amount
--- @param bagId number
function OnCashBagLost(depositorIdentifier, ownerIdentifier, businessId, amount, bagId)
end

--- Called when a raid finishes and the exposed Safe cash is seized. The money
--- is gone; this is only a notification point (e.g. reward the officer, log to Discord).
--- @param officerIdentifier string
--- @param ownerIdentifier string the business owner
--- @param businessId number
--- @param seizedAmount number exposed cash that was seized
function OnBusinessRaided(officerIdentifier, ownerIdentifier, businessId, seizedAmount)
end

--- Called when an owner delivers a prepared review folder and the accountant applies it.
--- Only fires on a completed delivery, never on a cancel or timeout.
--- @param identifier string business owner
--- @param businessId number
--- @param reduction number suspicion points removed
--- @param fee number fee paid from the bank
--- @param suspicionBefore number
--- @param suspicionAfter number
--- @param receiptsUsed number how many receipts were consumed
function OnBusinessBooksReviewed(identifier, businessId, reduction, fee, suspicionBefore, suspicionAfter, receiptsUsed)
end

--- Called when a launder contract shift ends, for any reason.
--- @param identifier string player identifier
--- @param contractId string contract id from Config.Contracts.List
--- @param reason string "player" (chose to end), "died", "dropped" (disconnected) or "stopped" (resource stop)
--- @param handovers number completed handovers
--- @param cleaned number dirty cash handed over
--- @param paid number clean money paid out
function OnContractShiftEnded(identifier, contractId, reason, handovers, cleaned, paid)
end