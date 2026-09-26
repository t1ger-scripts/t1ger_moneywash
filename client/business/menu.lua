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
        _API.ShowNotification(locale("menu.handler.not_found"), "error")
        return
    end

    local isClosed = status.isClosed
    local menuIcons = Config.Business.MenuIcons or {}

    -- Overview row - a single hover-metadata row showing totals only.
    -- Breakdown of each figure lives one level deeper, in Stock/Safe.
    local suspicionEntry = { label = locale("menu.handler.suspicion"), value = status.suspicionLabel }

    if Config.Suspicion.ShowExactValue and status.suspicion then
        suspicionEntry.value = ("%s (%d)"):format(status.suspicionLabel, status.suspicion)
        suspicionEntry.progress = status.suspicion
        suspicionEntry.colorScheme = status.suspicionColor
    end

    local overviewMetadata = {
        { label = locale("menu.handler.total_cash"),     value = FormatMoney(status.safeCovered + status.safeExposed) },
        { label = locale("menu.handler.stock"),           value = status.stock .. " " .. locale("menu.handler.units") },
        suspicionEntry,
        { label = locale("menu.handler.cycle_progress"), value = FormatMoney(status.totalLaundered) .. " / " .. FormatMoney(status.expectedRevenue) },
    }

    -- Launder Money
    local launderDisabled = isClosed
    local launderDesc = isClosed
        and locale("menu.handler.closed_reason")
        or locale("menu.handler.launder_desc")

    -- Stock submenu
    local stockDisabled = isClosed
    local stockDesc = isClosed
        and locale("menu.handler.closed_reason")
        or locale("menu.handler.stock_desc")

    -- Safe submenu
    local safeDisabled = isClosed or (status.safeCovered + status.safeExposed) <= 0
    local safeDesc
    if isClosed then
        safeDesc = locale("menu.handler.closed_reason")
    elseif (status.safeCovered + status.safeExposed) <= 0 then
        safeDesc = locale("menu.handler.no_safe_balance")
    else
        safeDesc = locale("menu.handler.safe_desc")
    end

    -- Review Books
    local receipts = lib.callback.await("t1ger_moneywash:server:getBusinessReceipts", false, businessId)
    local receiptCount = receipts and #receipts or 0
    local reviewMeta = {
        { label = locale("menu.handler.review_receipts"), value = receiptCount },
    }

    lib.registerContext({
        id      = "moneywash:handler:main",
        title   = locale("menu.handler.title"),
        options = {
            {
                title       = locale("menu.handler.overview"),
                icon        = menuIcons.overview or "fa-solid fa-chart-line",
                description = locale("menu.handler.overview_desc"),
                metadata    = overviewMetadata,
            },
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
                title       = locale("menu.handler.stock"),
                icon        = menuIcons.stock or "fa-solid fa-boxes-stacked",
                description = stockDesc,
                disabled    = stockDisabled,
                onSelect    = function()
                    OpenStockMenu(businessId, status)
                end,
            },
            {
                title       = locale("menu.handler.safe"),
                icon        = menuIcons.safe or "fa-solid fa-lock",
                description = safeDesc,
                disabled    = safeDisabled,
                onSelect    = function()
                    OpenSafeMenu(businessId, status)
                end,
            },
            {
                title       = locale("menu.handler.review_books"),
                icon        = menuIcons.reviewBooks or "fa-solid fa-book",
                description = locale("menu.handler.review_books_desc"),
                metadata    = reviewMeta,
                onSelect    = function()
                    OpenReviewBooksMenu(businessId, receipts)
                end,
            },
            {
                title       = locale("menu.handler.manage"),
                icon        = menuIcons.manage or "fa-solid fa-gear",
                description = locale("menu.handler.manage_desc"),
                onSelect    = function()
                    OpenManageBusinessMenu(businessId, status)
                end,
            },
        },
    })

    lib.showContext("moneywash:handler:main")
end

--- Stock submenu - shows current stock (units, value, coverage) and
--- lets the player place a new order.
--- @param businessId number
--- @param status table
function OpenStockMenu(businessId, status)
    local menuIcons = Config.Business.MenuIcons or {}

    local unitPrice = math.floor(status.expectedRevenue * Config.Business.Stock.costRatio)
    local stockValue = status.stock * unitPrice

    local remaining = math.max(0, status.expectedRevenue - status.totalLaundered)
    local stockNeeded = math.ceil(remaining * Config.Business.Stock.consumptionRatio)
    local coverage = stockNeeded <= 0 and 100
        or math.floor(math.min(1, status.stock / stockNeeded) * 100)

    local isClosed = status.isClosed
    local stockDisabled = isClosed
    local stockDesc = isClosed
        and locale("menu.handler.closed_reason")
        or locale("menu.handler.order_stock_desc")

    lib.registerContext({
        id      = "moneywash:handler:stock",
        title   = locale("menu.handler.stock"),
        menu    = "moneywash:handler:main",
        options = {
            {
                title       = ("%s: %d %s (%s)"):format(
                    locale("menu.handler.view_stock"),
                    status.stock,
                    locale("menu.handler.units"),
                    FormatMoney(stockValue)
                ),
                icon        = menuIcons.viewStock or "fa-solid fa-warehouse",
                description = locale("menu.handler.stock_coverage_desc"),
                progress    = coverage,
                disabled    = true,
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
        },
    })

    lib.showContext("moneywash:handler:stock")
end

--- Safe submenu - shows the covered/exposed balance breakdown and
--- lets the player make a bank deposit.
--- @param businessId number
--- @param status table
function OpenSafeMenu(businessId, status)
    local menuIcons = Config.Business.MenuIcons or {}
    local isClosed = status.isClosed

    local depositDisabled = isClosed or (status.safeCovered + status.safeExposed) <= 0
    local depositDesc
    if isClosed then
        depositDesc = locale("menu.handler.closed_reason")
    elseif (status.safeCovered + status.safeExposed) <= 0 then
        depositDesc = locale("menu.handler.no_safe_balance")
    else
        depositDesc = locale("menu.handler.bank_deposit_desc")
    end

    lib.registerContext({
        id      = "moneywash:handler:safe",
        title   = locale("menu.handler.safe"),
        menu    = "moneywash:handler:main",
        options = {
            {
                title       = ("%s: %s"):format(locale("menu.handler.safe_covered"), FormatMoney(status.safeCovered)),
                icon        = menuIcons.safeCovered or "fa-solid fa-shield-halved",
                description = locale("menu.handler.safe_covered_desc"),
                disabled    = true,
            },
            {
                title       = ("%s: %s"):format(locale("menu.handler.safe_exposed"), FormatMoney(status.safeExposed)),
                icon        = menuIcons.safeExposed or "fa-solid fa-triangle-exclamation",
                description = locale("menu.handler.safe_exposed_desc"),
                disabled    = true,
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
        },
    })

    lib.showContext("moneywash:handler:safe")
end

--- ============================================================================
--- LAUNDER DIALOG
--- ============================================================================

--- @param businessId number
--- @param status table live business status
function OpenLaunderDialog(businessId, status)
    local dirtyMoney = _API.Player:GetDirtyMoney()

    if dirtyMoney <= 0 then
        _API.ShowNotification(locale("menu.launder.no_dirty_cash"), "error", {})
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
        _API.ShowNotification(locale("menu.stock.invalid_units"), "error", {})
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
        _API.ShowNotification(locale("menu.review.no_receipts"), "error", {})
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
        _API.ShowNotification(locale("menu.review.estimate_failed"), "error", {})
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

--- Returns display names for a list of ox_lib nearby player objects —
--- character names when available, otherwise game names, resolved in
--- a single round-trip regardless of list size.
--- @param players table  Array of ox_lib nearby player objects { id, ... }
--- @return table  [serverId] = name
local function GetNearbyPlayerNames(players)
    local serverIds = {}

    for i = 1, #players do
        serverIds[i] = GetPlayerServerId(players[i].id)
    end

    return lib.callback.await("t1ger_moneywash:server:getPlayerNames", false, serverIds) or {}
end

--- Transfer dialog — lets the player pick a nearby online player from a
--- searchable dropdown and confirm via checkbox, all in one dialog.
--- Cancelling, or submitting without checking the box, returns to the
--- Manage Business menu rather than closing outright.
--- @param businessId number
function OpenTransferDialog(businessId)
    local transferDistance = Config.Business.TransferDistance or 10.0
    local coords = GetEntityCoords(PlayerPedId())

    local nearbyPlayers = lib.getNearbyPlayers(coords, transferDistance, Config.Debug and true or false)
    local players = {}

    if #nearbyPlayers == 0 then
        _API.ShowNotification(locale("menu.transfer.no_players_nearby"), "inform", {})
        return lib.showContext("moneywash:handler:manage")
    end

    local names = GetNearbyPlayerNames(nearbyPlayers)
    local playerOptions = {}

    for i = 1, #nearbyPlayers do
        local targetId = GetPlayerServerId(nearbyPlayers[i].id)
        local targetName = names[targetId] or GetPlayerName(nearbyPlayers[i].id)

        playerOptions[#playerOptions + 1] = {
            value = targetId,
            label = ("[%d] %s"):format(targetId, targetName),
        }
    end

    local input = lib.inputDialog(locale("menu.transfer.title"), {
        {
            type       = "select",
            label      = locale("menu.transfer.select_label"),
            options    = playerOptions,
            required   = true,
            searchable = true,
        },
        {
            type  = "checkbox",
            label = locale("menu.transfer.confirm_body"),
            required = true,
        },
    })

    if not input or not input[1] or not input[2] then
        return lib.showContext("moneywash:handler:manage")
    end

    local targetId = tonumber(input[1])

    local result = lib.callback.await("t1ger_moneywash:server:transferBusiness", false, targetId, businessId)

    if result.success then
        _API.ShowNotification(locale("menu.transfer.success"), "success", {})
    else
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error", {})
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
        _API.ShowNotification(locale("menu.abandon.success"), "success", {})
    else
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error", {})
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
        _API.ShowNotification(locale("menu.police.no_flagged_deposits"), "inform", {})
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
        _API.ShowNotification(locale("menu.police.confiscate_success"), "success", {})
    else
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error", {})
    end
end
