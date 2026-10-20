--- ============================================================================
--- Accountant Review (Review Books) Server
--- Server-authoritative: generates the worksheet, keeps the solution, grades
--- the player's answers, locks the result at the stamp and applies it only
--- when the folder is delivered to the accountant and the fee is paid.
--- ============================================================================

local CLIENT_EVENTS = {
    cancelled = "t1ger_moneywash:client:reviewCancelled",
}

--- Worksheets waiting for the player to finish (before the stamp)
---@type table<number, table> src -> { businessId, receipts, solution, expiresAt }
local Prepared = {}

--- Sealed reviews waiting for delivery (after the stamp)
---@type table<number, table> businessId -> review
local Sealed = {}

--- src -> businessId for sealed reviews
local SealedBySource = {}

--- businessId -> os.time() when the cooldown ends
local Cooldowns = {}

--- Per-player guard against double-click interleaving
local Busy = {}

--- ---------------------------------------------------------------------------
--- HELPERS
--- ---------------------------------------------------------------------------

--- Releases everything a player holds, without cost and without cooldown.
---@param src number
---@param reason string|nil if set, the client is told the review was cancelled
local function releasePlayer(src, reason)
    local hadSomething = Prepared[src] ~= nil

    Prepared[src] = nil
    Busy[src] = nil

    local businessId = SealedBySource[src]
    if businessId then
        hadSomething = true
        Sealed[businessId] = nil
        SealedBySource[src] = nil
    end

    if reason and hadSomething and GetPlayerName(src) then
        TriggerClientEvent(CLIENT_EVENTS.cancelled, src, reason)
    end
end

--- Is a review running (prepared or sealed) for this business?
---@param businessId number
---@return boolean
function IsBusinessInReview(businessId)
    if Sealed[businessId] then return true end

    for _, prepared in pairs(Prepared) do
        if prepared.businessId == businessId then return true end
    end

    return false
end
exports("IsBusinessInReview", IsBusinessInReview)

--- Returns the active sealed review of a player (used by the client mission)
---@param src number
---@return table|nil
function GetActiveReview(src)
    local businessId = SealedBySource[src]
    return businessId and Sealed[businessId] or nil
end

--- Seconds left on the cooldown of a business (0 when none).
---@param businessId number
---@return number
function GetReviewCooldownRemaining(businessId)
    local endsAt = Cooldowns[businessId]
    if not endsAt then return 0 end

    local remaining = endsAt - os.time()
    if remaining <= 0 then
        Cooldowns[businessId] = nil
        return 0
    end

    return remaining
end

--- Common checks before starting a review. Returns the business on success.
---@param src number
---@param businessId number
---@return table|nil business
---@return string|nil reason
local function validateStart(src, businessId)
    local cfg = Config.Review
    if not cfg or not cfg.Enable then return nil, "review_disabled" end

    local identifier = _API.Player.GetIdentifier(src)
    local business = tonumber(businessId) and GetBusiness(tonumber(businessId))

    if not identifier or not business or business.identifier ~= identifier then
        return nil, "not_owner"
    end

    if (business.suspicion or 0) <= 0 then return nil, "nothing_to_review" end
    if GetReviewCooldownRemaining(business.id) > 0 then return nil, "review_cooldown" end
    if IsBusinessInReview(business.id) then return nil, "review_active" end

    if IsBusinessRaided and IsBusinessRaided(business.id) then
        return nil, "business_raided"
    end

    if HasPendingCashCounter and HasPendingCashCounter(business.id) then
        return nil, "pending_cash_counter"
    end

    return business
end

--- Loads the player's receipts for a business, newest first.
---@param businessId number
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

--- Receipts that are not reserved by a sealed review.
---@param businessId number
---@return table[]
local function loadFreeReceipts(businessId)
    local reserved = Sealed[businessId] and Sealed[businessId].receiptSet or {}
    local free = {}

    for _, receipt in ipairs(loadReceipts(businessId)) do
        if not reserved[receipt.id] then free[#free + 1] = receipt end
    end

    return free
end

--- Reduction math shared by open (settings), prepare and seal.
---@param business table
---@param selectedUnits number
---@param quality number
---@return number base
---@return number final
---@return number fee
local function calculate(business, selectedUnits, quality)
    local cfg = Config.Review
    local tier = GetTierByType(business.type)
    local expectedRevenue = tier and tier.expectedRevenue or 0
    local unitsPerCycle = math.max(1, expectedRevenue / Config.Business.Stock.LaunderDollarsPerUnit)

    local reductionPerUnit = cfg.MaxReduction / cfg.CyclesForMax / unitsPerCycle
    local base = math.min(selectedUnits * reductionPerUnit, cfg.MaxReduction, business.suspicion)
    local final = math.min(base, math.floor(base * quality * 100 + 0.5) / 100)
    local fee = math.floor(expectedRevenue * cfg.FeePercent / 100 + 0.5)

    return base, final, fee
end

--- Changes a number by roughly `percentage`, never below `minimum`.
local function changeNumber(value, percentage, minimum)
    local difference = math.max(1, math.floor(value * percentage + 0.5))
    local candidate = value + (math.random() < 0.5 and -difference or difference)

    return candidate >= minimum and candidate or (value + difference)
end

--- Shuffles a list in place.
local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

--- Runs a callback body under the per-player busy guard. Whatever happens
--- (even an error), the guard is released and the player gets a clean reply.
local function guarded(source, fn)
    if Busy[source] then return { success = false, reason = "busy" } end
    Busy[source] = true

    local ok, response = pcall(fn)
    Busy[source] = nil

    if not ok then
        print(("^1[MoneyWash] Review error: %s^7"):format(tostring(response)))
        return { success = false, reason = "unknown" }
    end

    return response
end


--- Loads the locale file for the UI, falling back to "en".
---@return string localeName
---@return table messages
local function loadLocalization()
    local resource = GetCurrentResourceName()
    local name = (Config.BusinessPortal or {}).Locale or GetConvar("ox:locale", "en")
    if type(name) ~= "string" or not name:match("^[%w_-]+$") then name = "en" end

    local raw = LoadResourceFile(resource, "locales/" .. name .. ".json")
    if not raw then
        name = "en"
        raw = LoadResourceFile(resource, "locales/en.json")
    end

    local ok, messages = pcall(json.decode, raw or "{}")
    return name, ok and messages or {}
end

--- ---------------------------------------------------------------------------
--- CALLBACKS
--- ---------------------------------------------------------------------------

--- Opens the desk: returns everything the UI needs.
lib.callback.register("t1ger_moneywash:server:review:open", function(source, businessId)
    local business, reason = validateStart(source, businessId)
    if not business then return { success = false, reason = reason } end

    local receipts = loadFreeReceipts(business.id)
    if #receipts == 0 then return { success = false, reason = "nothing_to_review" } end

    local location = GetLocationConfig(business.type, business.locationId)
    if not location
        or not IsPlayerNearCoords(source, location.coords, (Config.Business.HandlerTargetDistance or 2.0) + 4.0)
    then
        return { success = false, reason = "business_too_far" }
    end

    local tier = GetTierByType(business.type)
    local cfg = Config.Review
    local localeName, messages = loadLocalization()

    return {
        success = true,
        data = {
            locale                = localeName,
            messages              = messages,
            currency              = Config.Currency,
            businessName          = GetBusinessLabel(business),
            maxReceipts           = cfg.MaxReceiptsPerReview,
            suspicion             = business.suspicion,
            expectedRevenue       = tier and tier.expectedRevenue or 0,
            launderDollarsPerUnit = Config.Business.Stock.LaunderDollarsPerUnit,
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

--- "Prepare books": validates the selection and returns the shuffled worksheet.
lib.callback.register("t1ger_moneywash:server:review:prepare", function(source, businessId, ids)
    return guarded(source, function()
        -- A second prepare (e.g. after Back) simply replaces the first sheet.
        Prepared[source] = nil

        local business, reason = validateStart(source, businessId)
        if not business then return { success = false, reason = reason } end

        if type(ids) ~= "table" or #ids == 0 or #ids > Config.Review.MaxReceiptsPerReview then
            return { success = false, reason = "invalid_selection" }
        end

        local free = {}
        for _, receipt in ipairs(loadFreeReceipts(business.id)) do free[receipt.id] = receipt end

        local seen, selected, selectedUnits = {}, {}, 0
        for _, rawId in ipairs(ids) do
            local id = tonumber(rawId)
            local receipt = id and free[id]

            if not receipt or seen[id] then
                return { success = false, reason = "invalid_selection" }
            end

            seen[id] = true
            selected[#selected + 1] = receipt
            selectedUnits = selectedUnits + receipt.units
        end

        local base = calculate(business, selectedUnits, 1.0)
        if base < Config.Review.MinReduction then
            return { success = false, reason = "below_minimum" }
        end

        -- One fault per row: either the units or the total is wrong.
        local rows, solution = {}, {}
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
            solution[receipt.id] = receipt
        end

        shuffle(rows)

        Prepared[source] = {
            businessId = business.id,
            receipts   = selected,
            solution   = solution,
            units      = selectedUnits,
            expiresAt  = os.time() + Config.Review.PrepareTimeout * 60,
        }

        return { success = true, rows = rows }
    end)
end)

--- Stamp: grade the answers, lock the result and reserve the receipts.
lib.callback.register("t1ger_moneywash:server:review:stamp", function(source, answers)
    return guarded(source, function()
        local prepared = Prepared[source]
        if not prepared then return { success = false, reason = "not_prepared" } end

        if os.time() > prepared.expiresAt then
            Prepared[source] = nil
            return { success = false, reason = "not_prepared" }
        end

        local business = GetBusiness(prepared.businessId)
        local identifier = _API.Player.GetIdentifier(source)

        if not business or business.identifier ~= identifier or type(answers) ~= "table" then
            Prepared[source] = nil
            return { success = false, reason = "not_prepared" }
        end

        -- Rules may have changed while the player was at the desk.
        if Sealed[business.id] or (business.suspicion or 0) <= 0
            or (IsBusinessRaided and IsBusinessRaided(business.id))
            or (HasPendingCashCounter and HasPendingCashCounter(business.id))
        then
            Prepared[source] = nil
            return { success = false, reason = "review_active" }
        end

        local answered = {}
        for _, answer in ipairs(answers) do
            if type(answer) == "table" and tonumber(answer.id) then
                answered[tonumber(answer.id)] = answer
            end
        end

        local mistakes = 0
        for _, receipt in ipairs(prepared.receipts) do
            local answer = answered[receipt.id]

            local correct = answer
                and tonumber(answer.matchedReceiptId) == receipt.id
                and tonumber(answer.units) == receipt.units
                and tonumber(answer.totalAmount) == receipt.totalAmount

            if not correct then mistakes = mistakes + 1 end
        end

        local rowCount = #prepared.receipts
        local quality = math.max(1 - Config.Review.SkillImpact / 100, 1 - mistakes / rowCount)
        local _, reduction, fee = calculate(business, prepared.units, quality)

        local receiptIds, receiptSet = {}, {}
        for _, receipt in ipairs(prepared.receipts) do
            receiptIds[#receiptIds + 1] = receipt.id
            receiptSet[receipt.id] = true
        end

        Prepared[source] = nil

        local review = {
            src             = source,
            identifier      = identifier,
            businessId      = business.id,
            receiptIds      = receiptIds,
            receiptSet      = receiptSet,
            reduction       = reduction,
            fee             = fee,
            suspicionBefore = business.suspicion,
            expiresAt       = os.time() + Config.Review.MaxTime * 60,
        }

        Sealed[business.id] = review
        SealedBySource[source] = business.id

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

--- Cancel (Back button, ESC, mission abandoned): free everything, no cost.
lib.callback.register("t1ger_moneywash:server:review:cancel", function(source)
    if Busy[source] then return { success = false, reason = "busy" } end
    releasePlayer(source, nil)
    return { success = true }
end)

--- Delivery at the accountant: pay the fee, consume receipts, apply the result.
lib.callback.register("t1ger_moneywash:server:review:deliver", function(source)
    return guarded(source, function()
        local review = GetActiveReview(source)
        if not review then return { success = false, reason = "no_review" } end

        local cfg = Config.Review
        local office = cfg.Accountant.Location
        local nearOffice = office ~= nil
            and IsPlayerNearCoords(source, office, cfg.Accountant.TargetDistance + 3.0)

        if not nearOffice then return { success = false, reason = "accountant_too_far" } end

        local business = GetBusiness(review.businessId)
        if not business or business.identifier ~= review.identifier then
            releasePlayer(source, "review_cancelled")
            return { success = false, reason = "no_review" }
        end

        if _API.Player.GetMoney(source, "bank") < review.fee then
            return { success = false, reason = "not_enough_money", fee = review.fee }
        end

        -- Receipts are consumed whole. Delete first: if they changed behind
        -- our back, nothing is charged.
        local placeholders = string.rep("?,", #review.receiptIds):sub(1, -2)
        local deleted = MySQL.update.await(
            ("DELETE FROM moneywash_receipts WHERE business_id = ? AND id IN (%s)"):format(placeholders),
            { business.id, table.unpack(review.receiptIds) }
        )

        if deleted ~= #review.receiptIds then
            releasePlayer(source, "review_cancelled")
            return { success = false, reason = "no_review" }
        end

        _API.Player.RemoveMoney(source, review.fee, "bank")

        local before = business.suspicion
        local after = math.max(0, before - review.reduction)

        UpdateBusiness(business.id, "suspicion", after)
        SaveBusiness(business.id, true)

        local reward = Config.Reputation.Enable
            and Config.Reputation.Rewards.accountantReview
        if reward and reward.enable then
            AwardReputationPoints(source, review.identifier, reward.points)
        end

        Cooldowns[business.id] = os.time() + cfg.Cooldown * 60

        Sealed[business.id] = nil
        SealedBySource[source] = nil

        RunHook(
            "OnBusinessBooksReviewed",
            review.identifier, business.id, review.reduction, review.fee,
            before, after, #review.receiptIds
        )

        return {
            success = true,
            reduction = review.reduction,
            fee = review.fee,
            suspicionBefore = before,
            suspicionAfter = after,
        }
    end)
end)

--- ---------------------------------------------------------------------------
--- CLEANUP
--- ---------------------------------------------------------------------------

--- Timeouts (prepare sheet and mission) and dead players.
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()

        for src, prepared in pairs(Prepared) do
            if now > prepared.expiresAt then releasePlayer(src, "review_timeout") end
        end

        for _, review in pairs(Sealed) do
            if now > review.expiresAt then
                releasePlayer(review.src, "review_timeout")
            elseif GetPlayerName(review.src) and GetEntityHealth(GetPlayerPed(review.src)) <= 0 then
                releasePlayer(review.src, "review_died")
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    releasePlayer(source, nil)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Prepared, Sealed, SealedBySource = {}, {}, {}
end)