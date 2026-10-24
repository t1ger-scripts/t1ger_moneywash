--- Accountant review (server). The server makes the worksheet, keeps the answers, grades them at the
--- stamp and applies the result when the folder is delivered.
--- The fee is paid at the stamp. A cancel refunds it minus the penalty, a disconnect is refunded when
--- the player is back, admin removal and a resource stop refund it in full, a timeout or death does not.
--- Everything lives in memory only. A server restart loses cooldowns and unpaid refunds.

local CLIENT_EVENT = "t1ger_moneywash:client:reviewCancelled"

---@class ReviewWorksheet
---@field businessId integer
---@field receipts table[] Receipts the player picked
---@field units integer Units on those receipts
---@field expiresAt integer os.time() the desk is discarded

---@class SealedReview
---@field src integer
---@field identifier string
---@field businessId integer
---@field receiptIds integer[]
---@field reduction number Suspicion removed on delivery
---@field fee integer Paid at the stamp
---@field expiresAt integer os.time() the delivery runs out

---@type table<integer, ReviewWorksheet> Open desks by player source
local Worksheets = {}

---@type table<integer, SealedReview> Paid reviews by business id
local Reviews = {}

---@type table<integer, integer> Business id of the player's paid review, by source
local ReviewBySource = {}

---@type table<integer, integer> os.time() a business can be reviewed again, by business id
local Cooldowns = {}

---@type table<string, integer> Refunds for players who disconnected, by identifier
local PendingRefunds = {}

---@type table<integer, boolean> Players inside a callback, stops double clicks
local Busy = {}

--- Removes a paid review from memory. Money is not touched here.
---@param review SealedReview
local function finishReview(review)
    Reviews[review.businessId] = nil
    ReviewBySource[review.src] = nil
end

--- Tells the client its review is over, so it closes the desk and removes the folder.
---@param src integer
---@param reason string
local function notifyClient(src, reason)
    if GetPlayerName(src) then TriggerClientEvent(CLIENT_EVENT, src, reason) end
end

--- Refunds the fee of a review in full and tells the player.
---@param review SealedReview
local function refundInFull(review)
    _API.Player.AddMoney(review.src, review.fee, "bank")
    _API.SendNotification(review.src, string.format(locale("notification.review_refunded"), FormatMoney(review.fee)), "inform")
end

--- True if the business has a desk open or a paid review running.
---@param businessId integer
---@return boolean
function IsBusinessInReview(businessId)
    if Reviews[businessId] then return true end

    for _, worksheet in pairs(Worksheets) do
        if worksheet.businessId == businessId then return true end
    end

    return false
end
exports("IsBusinessInReview", IsBusinessInReview)

--- Seconds until a business can be reviewed again.
---@param businessId integer
---@return integer seconds 0 when it can be reviewed
function GetReviewCooldownRemaining(businessId)
    local remaining = (Cooldowns[businessId] or 0) - os.time()
    if remaining > 0 then return remaining end

    Cooldowns[businessId] = nil

    return 0
end

--- Ends the review of a business that is being removed, and refunds it in full.
---@param businessId integer
function EndReviewForBusiness(businessId)
    local review = Reviews[businessId]
    if review then
        refundInFull(review)
        finishReview(review)
        notifyClient(review.src, "review_removed")
    end

    for src, worksheet in pairs(Worksheets) do
        if worksheet.businessId == businessId then
            Worksheets[src] = nil
            notifyClient(src, "review_removed")
        end
    end
end

--- A player disconnected: the review ends and the refund waits until they are back.
--- The refund can't be paid now, the framework has already unloaded the player.
---@param src integer
local function handlePlayerDropped(src)
    Worksheets[src] = nil
    Busy[src] = nil

    local businessId = ReviewBySource[src]
    local review = businessId and Reviews[businessId]
    if not review then return end

    PendingRefunds[review.identifier] = (PendingRefunds[review.identifier] or 0) + review.fee
    finishReview(review)
end

--- A player loaded in: pays the refund of a review they left behind when they disconnected.
---@param src integer
function PayPendingReviewRefund(src)
    local identifier = _API.Player.GetIdentifier(src)
    if not identifier then return end

    -- The old connection may not have dropped yet (client crash and a quick reconnect)
    for _, review in pairs(Reviews) do
        if review.src ~= src and review.identifier == identifier then handlePlayerDropped(review.src) end
    end

    local amount = PendingRefunds[identifier]
    if not amount then return end

    PendingRefunds[identifier] = nil
    _API.Player.AddMoney(src, amount, "bank")
    _API.SendNotification(src, string.format(locale("notification.review_refunded"), FormatMoney(amount)), "inform")
end

--- Checks the player may start a review. Returns the business on success.
---@param src integer
---@param businessId any
---@return table|nil business
---@return string|nil reason
local function validateStart(src, businessId)
    local cfg = Config.Review
    if not cfg or not cfg.Enable then return nil, "review_disabled" end

    local identifier = _API.Player.GetIdentifier(src)
    local business = tonumber(businessId) and GetBusiness(tonumber(businessId))

    if not identifier or not business or business.identifier ~= identifier then return nil, "not_owner" end
    if (business.suspicion or 0) <= 0 then return nil, "nothing_to_review" end
    if GetReviewCooldownRemaining(business.id) > 0 then return nil, "review_cooldown" end
    if IsBusinessInReview(business.id) then return nil, "review_active" end
    if IsBusinessRaided(business.id) then return nil, "raid_in_progress" end
    if HasPendingCashOperation(business.id) then return nil, "business_busy" end

    return business
end

--- Receipts of a business, newest first.
---@param businessId integer
---@return table[]
local function loadReceipts(businessId)
    local rows = MySQL.query.await(
        "SELECT id, units, unit_price, total_amount, created_at FROM moneywash_receipts WHERE business_id = ? ORDER BY id DESC",
        { businessId }
    ) or {}

    local receipts = {}
    for _, row in ipairs(rows) do
        receipts[#receipts + 1] = {
            id          = row.id,
            units       = row.units,
            unitPrice   = row.unit_price,
            totalAmount = row.total_amount,
            createdAt   = row.created_at,
        }
    end

    return receipts
end

--- The fee of a review. It depends on the business type only.
---@param business table
---@return integer
local function getFee(business)
    local tier = GetTierByType(business.type)

    return math.floor((tier and tier.expectedRevenue or 0) * Config.Review.FeePercent / 100 + 0.5)
end

--- Suspicion a review removes before the quality of the paperwork is applied.
---@param business table
---@param units integer Units on the selected receipts
---@return number
local function getBaseReduction(business, units)
    local cfg = Config.Review
    local tier = GetTierByType(business.type)
    local unitsPerCycle = math.max(1, (tier and tier.expectedRevenue or 0) / Config.Stock.LaunderDollarsPerUnit)
    local perUnit = cfg.MaxReduction / cfg.CyclesForMax / unitsPerCycle

    return math.min(units * perUnit, cfg.MaxReduction, business.suspicion)
end

--- Changes a number by about `percentage`, never below `minimum`.
---@param value number
---@param percentage number 0.15 = 15%
---@param minimum number
---@return number
local function changeNumber(value, percentage, minimum)
    local difference = math.max(1, math.floor(value * percentage + 0.5))
    local candidate = value + (math.random() < 0.5 and -difference or difference)

    return candidate >= minimum and candidate or (value + difference)
end

--- Shuffles a list in place.
---@param list any[]
local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

--- Runs a callback body once per player at a time. An error gives a clean reply and frees the guard.
---@param src integer
---@param fn fun(): table
---@return table
local function guarded(src, fn)
    if Busy[src] then return { success = false, reason = "business_busy" } end
    Busy[src] = true

    local ok, response = pcall(fn)
    Busy[src] = nil

    if not ok then
        print(("^1[MoneyWash] Review error: %s^7"):format(tostring(response)))
        return { success = false, reason = "unknown" }
    end

    return response
end

--- Callback: opens the desk and returns what the UI needs.
---@param src integer
---@param businessId integer
lib.callback.register("t1ger_moneywash:server:review:open", function(src, businessId)
    local business, reason = validateStart(src, businessId)
    if not business then return { success = false, reason = reason } end

    local fee = getFee(business)
    if _API.Player.GetMoney(src, "bank") < fee then return { success = false, reason = "insufficient_funds" } end

    local receipts = loadReceipts(business.id)
    if #receipts == 0 then return { success = false, reason = "nothing_to_review" } end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location
        or not IsPlayerNearCoords(src, location.coords, (Config.HandlerNPC.Target.distance or 2.0) + 4.0)
    then
        return { success = false, reason = "business_too_far" }
    end

    local tier = GetTierByType(business.type)
    local cfg = Config.Review

    return {
        success = true,
        data = {
            currency              = Config.Currency,
            businessName          = GetBusinessLabel(business),
            maxReceipts           = cfg.MaxReceiptsPerReview,
            suspicion             = business.suspicion,
            expectedRevenue       = tier and tier.expectedRevenue or 0,
            launderDollarsPerUnit = Config.Stock.LaunderDollarsPerUnit,
            fee                   = fee,
            settings = {
                maxReduction = cfg.MaxReduction,
                cyclesForMax = cfg.CyclesForMax,
                minReduction = cfg.MinReduction,
                feePercent   = cfg.FeePercent,
                skillImpact  = cfg.SkillImpact,
            },
            receipts = receipts,
        },
    }
end)

--- Callback: checks the selected receipts and returns the shuffled worksheet.
---@param src integer
---@param businessId integer
---@param ids integer[] Receipt ids
lib.callback.register("t1ger_moneywash:server:review:prepare", function(src, businessId, ids)
    return guarded(src, function()
        -- A second prepare (e.g. after Back) replaces the first sheet
        Worksheets[src] = nil

        local business, reason = validateStart(src, businessId)
        if not business then return { success = false, reason = reason } end

        if type(ids) ~= "table" or #ids == 0 or #ids > Config.Review.MaxReceiptsPerReview then
            return { success = false, reason = "invalid_selection" }
        end

        local owned = {}
        for _, receipt in ipairs(loadReceipts(business.id)) do owned[receipt.id] = receipt end

        local seen, selected, units = {}, {}, 0
        for _, rawId in ipairs(ids) do
            local id = tonumber(rawId)
            local receipt = id and owned[id]

            if not receipt or seen[id] then return { success = false, reason = "invalid_selection" } end

            seen[id] = true
            selected[#selected + 1] = receipt
            units = units + receipt.units
        end

        if getBaseReduction(business, units) < Config.Review.MinReduction then
            return { success = false, reason = "below_minimum" }
        end

        -- One fault per row: either the units or the total is wrong
        local rows = {}
        for _, receipt in ipairs(selected) do
            local row = {
                id          = receipt.id,
                createdAt   = receipt.createdAt,
                units       = receipt.units,
                totalAmount = receipt.totalAmount,
            }

            if math.random() < 0.5 then
                row.units = changeNumber(receipt.units, 0.15, 1)
            else
                row.totalAmount = changeNumber(receipt.totalAmount, 0.10, 0)
            end

            rows[#rows + 1] = row
        end

        shuffle(rows)

        Worksheets[src] = {
            businessId = business.id,
            receipts   = selected,
            units      = units,
            expiresAt  = os.time() + Config.Review.PrepareTimeout * 60,
        }

        return { success = true, rows = rows }
    end)
end)

--- Callback: the stamp. Grades the answers, takes the fee and seals the review.
---@param src integer
---@param answers table[] { id, matchedReceiptId, units, totalAmount }
lib.callback.register("t1ger_moneywash:server:review:stamp", function(src, answers)
    return guarded(src, function()
        local worksheet = Worksheets[src]
        if not worksheet then return { success = false, reason = "not_prepared" } end

        if os.time() > worksheet.expiresAt then
            Worksheets[src] = nil
            return { success = false, reason = "not_prepared" }
        end

        local business = GetBusiness(worksheet.businessId)
        local identifier = _API.Player.GetIdentifier(src)

        if not business or business.identifier ~= identifier or type(answers) ~= "table" then
            Worksheets[src] = nil
            return { success = false, reason = "not_prepared" }
        end

        -- The rules may have changed while the player was at the desk
        if Reviews[business.id] or (business.suspicion or 0) <= 0
            or IsBusinessRaided(business.id) or HasPendingCashOperation(business.id)
        then
            Worksheets[src] = nil
            return { success = false, reason = "review_active" }
        end

        local fee = getFee(business)
        local bank = _API.Player.GetMoney(src, "bank")
        if bank < fee then return { success = false, reason = "insufficient_funds" } end

        local answered = {}
        for _, answer in ipairs(answers) do
            if type(answer) == "table" and tonumber(answer.id) then answered[tonumber(answer.id)] = answer end
        end

        local mistakes = 0
        for _, receipt in ipairs(worksheet.receipts) do
            local answer = answered[receipt.id]

            local correct = answer
                and tonumber(answer.matchedReceiptId) == receipt.id
                and tonumber(answer.units) == receipt.units
                and tonumber(answer.totalAmount) == receipt.totalAmount

            if not correct then mistakes = mistakes + 1 end
        end

        local rowCount = #worksheet.receipts
        local quality = math.max(1 - Config.Review.SkillImpact / 100, 1 - mistakes / rowCount)
        local reduction = math.floor(getBaseReduction(business, worksheet.units) * quality * 100 + 0.5) / 100

        _API.Player.RemoveMoney(src, fee, "bank")
        if _API.Player.GetMoney(src, "bank") > bank - fee then return { success = false, reason = "request_failed" } end

        local receiptIds = {}
        for _, receipt in ipairs(worksheet.receipts) do receiptIds[#receiptIds + 1] = receipt.id end

        Worksheets[src] = nil

        Reviews[business.id] = {
            src        = src,
            identifier = identifier,
            businessId = business.id,
            receiptIds = receiptIds,
            reduction  = reduction,
            fee        = fee,
            expiresAt  = os.time() + Config.Review.MaxTime * 60,
        }
        ReviewBySource[src] = business.id

        return {
            success = true,
            result = {
                mistakes        = mistakes,
                quality         = quality,
                rows            = rowCount,
                reduction       = reduction,
                fee             = fee,
                suspicionBefore = business.suspicion,
                suspicionAfter  = math.max(0, business.suspicion - reduction),
            },
        }
    end)
end)

--- Callback: the desk is closed before the stamp (Back, ESC). Nothing was paid.
---@param src integer
lib.callback.register("t1ger_moneywash:server:review:cancel", function(src)
    if Busy[src] then return { success = false, reason = "business_busy" } end

    Worksheets[src] = nil

    return { success = true }
end)

--- Callback: the player drops the sealed folder. The fee is refunded minus the penalty.
---@param src integer
lib.callback.register("t1ger_moneywash:server:review:cancelMission", function(src)
    return guarded(src, function()
        local businessId = ReviewBySource[src]
        local review = businessId and Reviews[businessId]
        if not review then return { success = false, reason = "no_review" } end

        local penalty = Config.Review.CancelPenaltyPercent or 0
        local refund = math.floor(review.fee * (1 - penalty / 100))

        _API.Player.AddMoney(src, refund, "bank")
        finishReview(review)

        return { success = true, refund = refund }
    end)
end)

--- Callback: delivery at the accountant. Consumes the receipts and applies the result.
---@param src integer
lib.callback.register("t1ger_moneywash:server:review:deliver", function(src)
    return guarded(src, function()
        local businessId = ReviewBySource[src]
        local review = businessId and Reviews[businessId]
        if not review then return { success = false, reason = "no_review" } end

        local cfg = Config.Review.Accountant
        if not IsPlayerNearCoords(src, cfg.Location, cfg.TargetDistance + 3.0) then
            return { success = false, reason = "accountant_too_far" }
        end

        -- Receipts are consumed whole. If they changed behind our back, the fee is refunded.
        local placeholders = string.rep("?,", #review.receiptIds):sub(1, -2)
        local deleted = MySQL.update.await(
            ("DELETE FROM moneywash_receipts WHERE business_id = ? AND id IN (%s)"):format(placeholders),
            { review.businessId, table.unpack(review.receiptIds) }
        )

        -- Read after the database call, other systems may have changed the suspicion meanwhile
        local business = GetBusiness(review.businessId)

        if deleted ~= #review.receiptIds or not business or business.identifier ~= review.identifier then
            refundInFull(review)
            finishReview(review)
            notifyClient(src, "review_invalid")
            return { success = false, reason = "no_review" }
        end

        local before = business.suspicion
        local after = math.max(0, before - review.reduction)

        UpdateBusiness(business.id, "suspicion", after)
        SaveBusiness(business.id, true)

        local reward = Config.Reputation.Enable and Config.Reputation.Rewards.accountantReview
        if reward and reward.enable then AwardReputationPoints(src, review.identifier, reward.points) end

        Cooldowns[business.id] = os.time() + Config.Review.Cooldown * 60
        finishReview(review)

        RunHook(
            "OnBusinessBooksReviewed",
            review.identifier, business.id, review.reduction, review.fee,
            before, after, #review.receiptIds
        )

        return { success = true, suspicionBefore = before, suspicionAfter = after, fee = review.fee }
    end)
end)

--- Ends desks and deliveries that ran out of time, or whose owner died. A late delivery is not refunded.
CreateThread(function()
    while true do
        Wait((next(Worksheets) or next(Reviews)) and 5000 or 10000)

        local now = os.time()

        for src, worksheet in pairs(Worksheets) do
            if now > worksheet.expiresAt then
                Worksheets[src] = nil
                notifyClient(src, "review_desk_timeout")
            end
        end

        for _, review in pairs(Reviews) do
            if now > review.expiresAt then
                finishReview(review)
                notifyClient(review.src, "review_timeout")
            elseif GetPlayerName(review.src) and GetEntityHealth(GetPlayerPed(review.src)) <= 0 then
                finishReview(review)
                notifyClient(review.src, "review_died")
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    handlePlayerDropped(source)
end)

--- Refunds every paid review when the resource stops, in full. Players are still online here.
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, review in pairs(Reviews) do
        _API.Player.AddMoney(review.src, review.fee, "bank")
        finishReview(review)
    end

    Worksheets = {}
end)