--- ============================================================================
--- Business Menu
--- All ox_lib context menus for the Handler NPC.
--- Calls into server callbacks for live data before opening each menu.
--- ============================================================================

--- Opens the Handler NPC main menu for an owned business
--- Fetches live business status from server before opening
--- @param businessId number
function OpenHandlerMenu(businessId)
    local status = lib.callback.await("t1ger_moneywash:server:getBusinessStatus", false, businessId)
    if not status then
        _API.ShowNotification({ title = locale("menu.handler.not_found"), type = "error" })
        return
    end

    local isClosed = status.isClosed

    -- Build header metadata showing live business state
    local headerMetadata = {
        { label = locale("menu.handler.safe_covered"),   value = FormatMoney(status.safeCovered) },
        { label = locale("menu.handler.safe_exposed"),   value = FormatMoney(status.safeExposed) },
        { label = locale("menu.handler.stock"),          value = status.stock .. " " .. locale("menu.handler.units") },
        { label = locale("menu.handler.suspicion"),      value = status.suspicionLabel },
        { label = locale("menu.handler.cycle_progress"), value = FormatMoney(status.totalLaundered) .. " / " .. FormatMoney(status.expectedRevenue) },
    }

    -- Launder Money
    local launderDisabled = isClosed
    local launderDesc = isClosed and locale("menu.handler.closed_reason") or nil

    -- Order Stock
    local stockDisabled = isClosed
    local stockDesc = isClosed and locale("menu.handler.closed_reason") or nil

    -- Bank Deposit
    local depositDisabled = isClosed or (status.safeCovered + status.safeExposed) <= 0
    local depositDesc = nil
    if isClosed then
        depositDesc = locale("menu.handler.closed_reason")
    elseif (status.safeCovered + status.safeExposed) <= 0 then
        depositDesc = locale("menu.handler.no_safe_balance")
    end

    -- Review Books
    local reviewDisabled = false
    local reviewDesc = nil
    -- Effectiveness estimate shown in metadata
    local receipts = lib.callback.await("t1ger_moneywash:server:getBusinessReceipts", false, businessId)
    local receiptCount = receipts and #receipts or 0
    local reviewMeta = {
        { label = locale("menu.handler.review_receipts"), value = receiptCount },
    }

    local menuIcons = Config.Business.MenuIcons or {}

    lib.registerContext({
        id       = "moneywash:handler:main",
        title    = locale("menu.handler.title"),
        metadata = headerMetadata,
        options  = {
            {
                title       = locale("menu.handler.launder"),
                icon        = menuIcons.launder or "fa-solid fa-money-bill-wave",
                description = launderDesc,
                disabled    = launderDisabled,
                onSelect    = function()
                    OpenLaunderDialog(businessId, status)
                end,
            },
            {
                title       = locale("menu.handler.order_stock"),
                icon        = menuIcons.orderStock or "fa-solid fa-box",
                description = stockDesc,
                disabled    = stockDisabled,
                onSelect    = function()
                    OpenStockOrderDialog(businessId, status)
                end,
            },
            {
                title       = locale("menu.handler.bank_deposit"),
                icon        = menuIcons.bankDeposit or "fa-solid fa-building-columns",
                description = depositDesc,
                disabled    = depositDisabled,
                onSelect    = function()
                    OpenBankDepositDialog(businessId, status)
                end,
            },
            {
                title       = locale("menu.handler.review_books"),
                icon        = menuIcons.reviewBooks or "fa-solid fa-book",
                description = reviewDesc,
                disabled    = reviewDisabled,
                metadata    = reviewMeta,
                onSelect    = function()
                    OpenReviewBooksMenu(businessId, receipts)
                end,
            },
            {
                title    = locale("menu.handler.manage"),
                icon     = menuIcons.manage or "fa-solid fa-gear",
                onSelect = function()
                    OpenManageBusinessMenu(businessId, status)
                end,
            },
        },
    })

    lib.showContext("moneywash:handler:main")
end

--- ============================================================================
--- LAUNDER DIALOG
--- ============================================================================

--- @param businessId number
--- @param status table live business status
function OpenLaunderDialog(businessId, status)
    local dirtyMoney = _API.Player:GetDirtyMoney()

    if dirtyMoney <= 0 then
        _API.ShowNotification({ title = locale("menu.launder.no_dirty_cash"), type = "error" })
        return
    end

    local input = lib.inputDialog(locale("menu.launder.title"), {
        {
            type        = "number",
            label       = string.format(locale("menu.launder.amount_label"),
                FormatMoney(dirtyMoney)),
            description = string.format(locale("menu.launder.amount_desc"),
                FormatMoney(math.floor(status.expectedRevenue - status.totalLaundered))),
            min         = 1,
            max         = dirtyMoney,
            required    = true,
        },
    })

    if not input or not input[1] then return end

    local amount = math.floor(tonumber(input[1]) or 0)
    if amount <= 0 then return end

    -- Trigger launder mission flow in missions.lua
    StartLaunderFlow(businessId, amount)
end

--- ============================================================================
--- STOCK ORDER DIALOG
--- ============================================================================

--- @param businessId number
--- @param status table
function OpenStockOrderDialog(businessId, status)
    local minOrder = status.minOrder
    local maxOrder = status.maxOrder
    local unitPrice = status.unitPrice

    local input = lib.inputDialog(locale("menu.stock.title"), {
        {
            type        = "number",
            label       = string.format(locale("menu.stock.amount_label"), minOrder, maxOrder),
            description = string.format(locale("menu.stock.price_desc"), FormatMoney(unitPrice)),
            min         = minOrder,
            max         = maxOrder,
            required    = true,
        },
    })

    if not input or not input[1] then return end

    local units = math.floor(tonumber(input[1]) or 0)
    if units < minOrder or units > maxOrder then
        _API.ShowNotification({ title = locale("menu.stock.invalid_units"), type = "error" })
        return
    end

    local totalCost = units * unitPrice

    local confirmed = lib.alertDialog({
        header   = locale("menu.stock.confirm_title"),
        content  = string.format(locale("menu.stock.confirm_body"), units, FormatMoney(totalCost)),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then return end

    -- Trigger stock mission flow in missions.lua
    StartStockMission(businessId, units)
end

--- ============================================================================
--- BANK DEPOSIT DIALOG
--- ============================================================================

--- @param businessId number
--- @param status table
function OpenBankDepositDialog(businessId, status)
    local totalSafe = status.safeCovered + status.safeExposed

    local input = lib.inputDialog(locale("menu.deposit.title"), {
        {
            type        = "number",
            label       = string.format(locale("menu.deposit.amount_label"), FormatMoney(totalSafe)),
            description = string.format(locale("menu.deposit.exposed_desc"),
                FormatMoney(status.safeExposed), FormatMoney(status.safeCovered)),
            min         = 1,
            max         = totalSafe,
            required    = true,
        },
    })

    if not input or not input[1] then return end

    local amount = math.floor(tonumber(input[1]) or 0)
    if amount <= 0 or amount > totalSafe then return end

    -- Trigger deposit mission flow in missions.lua
    StartDepositMission(businessId, amount)
end

--- ============================================================================
--- REVIEW BOOKS MENU
--- ============================================================================

--- @param businessId number
--- @param receipts table available receipts from server
function OpenReviewBooksMenu(businessId, receipts)
    if not receipts or #receipts == 0 then
        _API.ShowNotification({ title = locale("menu.review.no_receipts"), type = "error" })
        return
    end

    -- Build multi-select options from available receipts
    local options = {}
    for _, receipt in ipairs(receipts) do
        options[#options + 1] = {
            label = string.format("%s — %s units — %s",
                os.date("%d/%m %H:%M", receipt.created_at),
                receipt.units,
                FormatMoney(receipt.total_amount)
            ),
            value = receipt.id,
        }
    end

    local selected = lib.inputDialog(locale("menu.review.title"), {
        {
            type     = "multi-select",
            label    = locale("menu.review.select_label"),
            options  = options,
            required = true,
        },
    })

    if not selected or not selected[1] or #selected[1] == 0 then return end

    local selectedIds = selected[1]

    -- Fetch live effectiveness estimate from server
    local estimate = lib.callback.await(
        "t1ger_moneywash:server:estimateReviewEffectiveness", false,
        businessId, selectedIds
    )

    if not estimate then
        _API.ShowNotification({ title = locale("menu.review.estimate_failed"), type = "error" })
        return
    end

    -- Show effectiveness and confirm
    local confirmed = lib.alertDialog({
        header   = locale("menu.review.confirm_title"),
        content  = string.format(locale("menu.review.confirm_body"),
            estimate.label, estimate.reduction),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then return end

    -- Trigger review flow in missions.lua
    StartReviewMission(businessId, selectedIds)
end

--- ============================================================================
--- MANAGE BUSINESS SUBMENU
--- ============================================================================

--- @param businessId number
--- @param status table
function OpenManageBusinessMenu(businessId, status)
    local menuIcons = Config.Business.MenuIcons or {}

    lib.registerContext({
        id      = "moneywash:handler:manage",
        title   = locale("menu.manage.title"),
        menu    = "moneywash:handler:main",
        options = {
            {
                title       = locale("menu.manage.transfer"),
                icon        = menuIcons.transfer or "fa-solid fa-right-left",
                description = locale("menu.manage.transfer_desc"),
                onSelect    = function()
                    OpenTransferDialog(businessId)
                end,
            },
            {
                title       = locale("menu.manage.abandon"),
                icon        = menuIcons.abandon or "fa-solid fa-door-open",
                description = locale("menu.manage.abandon_desc"),
                onSelect    = function()
                    ConfirmAbandonBusiness(businessId)
                end,
            },
        },
    })

    lib.showContext("moneywash:handler:manage")
end

--- Transfer dialog — target player must be online and nearby.
--- @param businessId number
function OpenTransferDialog(businessId)
    local input = lib.inputDialog(locale("menu.transfer.title"), {
        {
            type        = "number",
            label       = locale("menu.transfer.player_id_label"),
            description = locale("menu.transfer.player_id_desc"),
            required    = true,
            min         = 1,
        },
    })

    if not input or not input[1] then
        return
    end

    local targetId = tonumber(input[1])
    if not targetId then
        return
    end

    local confirmed = lib.alertDialog({
        header   = locale("menu.transfer.confirm_title"),
        content  = string.format(
            locale("menu.transfer.confirm_body"),
            targetId
        ),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then
        return
    end

    local result = lib.callback.await(
        "t1ger_moneywash:server:transferBusiness",
        false,
        targetId,
        businessId
    )

    if result.success then
        _API.ShowNotification({
            title = locale("menu.transfer.success"),
            type = "success",
        })
    else
        _API.ShowNotification({
            title = locale(
                "notification.error_" .. (result.reason or "unknown")
            ),
            type = "error",
        })
    end
end

--- Abandon confirmation — warns about zero refund
--- @param businessId number
function ConfirmAbandonBusiness(businessId)
    local confirmed = lib.alertDialog({
        header   = locale("menu.abandon.confirm_title"),
        content  = locale("menu.abandon.confirm_body"),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then return end

    local result = lib.callback.await("t1ger_moneywash:server:abandonBusiness", false, businessId)

    if result.success then
        _API.ShowNotification({ title = locale("menu.abandon.success"), type = "success" })
    else
        _API.ShowNotification({
            title = locale("notification.error_" .. (result.reason or "unknown")),
            type  = "error",
        })
    end
end

--- ============================================================================
--- POLICE BANK TELLER MENU
--- ============================================================================

--- Called by the bank teller target when a police officer interacts
--- @param bankCoords vector4
function OpenPoliceTellerMenu(bankCoords)
    local deposits = lib.callback.await("t1ger_moneywash:server:getFlaggedDeposits", false, bankCoords)

    if not deposits or #deposits == 0 then
        _API.ShowNotification({ title = locale("menu.police.no_flagged_deposits"), type = "inform" })
        return
    end

    local options = {}

    for _, deposit in ipairs(deposits) do
        local timeRemaining = math.max(0, deposit.clearsAt - os.time())
        local minutes = math.floor(timeRemaining / 60)
        local seconds = timeRemaining % 60

        options[#options + 1] = {
            title    = string.format(locale("menu.police.deposit_entry"),
                FormatMoney(deposit.totalAmount)),
            icon     = "fa-solid fa-money-bill",
            metadata = {
                {
                    label = locale("menu.police.clears_in"),
                    value = string.format("%dm %ds", minutes, seconds)
                },
            },
            onSelect = function()
                ConfirmConfiscateDeposit(deposit.identifier, deposit.totalAmount)
            end,
        }
    end

    lib.registerContext({
        id      = "moneywash:police:teller",
        title   = locale("menu.police.teller_title"),
        options = options,
    })

    lib.showContext("moneywash:police:teller")
end

--- Confiscation confirmation for police
--- @param targetIdentifier string
--- @param amount number
function ConfirmConfiscateDeposit(targetIdentifier, amount)
    local confirmed = lib.alertDialog({
        header   = locale("menu.police.confiscate_title"),
        content  = string.format(locale("menu.police.confiscate_body"), FormatMoney(amount)),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then return end

    local result = lib.callback.await("t1ger_moneywash:server:confiscateDeposit", false, targetIdentifier)

    if result.success then
        _API.ShowNotification({ title = locale("menu.police.confiscate_success"), type = "success" })
    else
        _API.ShowNotification({
            title = locale("notification.error_" .. (result.reason or "unknown")),
            type  = "error",
        })
    end
end
