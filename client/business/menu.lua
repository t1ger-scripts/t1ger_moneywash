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

    local menuIcons = Config.Business.MenuIcons or {}

    -- Overview row - a single hover-metadata row showing totals only.
    -- Breakdown of each figure lives one level deeper, in Stock/Safe.
    local suspicionEntry = { label = locale("menu.handler.suspicion"), value = status.suspicionLabel }

    if Config.Suspicion.ShowExactValue and status.suspicion then
        suspicionEntry.value = ("%s (%d)"):format(status.suspicionLabel, math.floor(status.suspicion))
        suspicionEntry.progress = status.suspicion
        suspicionEntry.colorScheme = status.suspicionColor
    end

    local overviewMetadata = {
        { label = locale("menu.handler.total_cash"), value = FormatMoney(status.safeCovered + status.safeExposed) },
        { label = locale("menu.handler.stock"),      value = status.stock .. " " .. locale("menu.handler.units") },
        suspicionEntry,
        { label = locale("menu.handler.cycle_progress"), value = FormatMoney(status.cycleLaundered) .. " / " .. FormatMoney(status.expectedRevenue) },
    }

    -- Safe submenu
    local safeDisabled = (status.safeCovered + status.safeExposed) <= 0
    local safeDesc = safeDisabled and locale("menu.handler.no_safe_balance") or locale("menu.handler.safe_desc")

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
                description = locale("menu.handler.launder_desc"),
                onSelect    = function()
                    StartLaunderFlow(businessId)
                end,
            },
            {
                title       = locale("menu.handler.stock"),
                icon        = menuIcons.stock or "fa-solid fa-boxes-stacked",
                description = locale("menu.handler.stock_desc"),
                onSelect    = function()
                    OpenStockMenu(businessId)
                end,
            },
            {
                title       = locale("menu.handler.safe"),
                icon        = menuIcons.safe or "fa-solid fa-lock",
                description = safeDesc,
                disabled    = safeDisabled,
                onSelect    = function()
                    OpenSafeMenu(businessId)
                end,
            },
            {
                title       = locale("menu.handler.manage"),
                icon        = menuIcons.manage or "fa-solid fa-gear",
                description = locale("menu.handler.manage_desc"),
                onSelect    = function()
                    OpenManageBusinessMenu(businessId)
                end,
            },
        },
    })

    lib.showContext("moneywash:handler:main")
end

--- Stock submenu - separate rows for storage (units held vs. capacity) and
--- cycle readiness (whether stock can fully cover the rest of this cycle's
--- laundering), plus the order action. Cycle Readiness can be hidden
--- entirely via Config.Business.Stock.ShowCycleReadiness for servers that
--- don't want to hint at this to players.
--- @param businessId number
function OpenStockMenu(businessId)
    local status = lib.callback.await("t1ger_moneywash:server:getBusinessStatus", false, businessId)
    if not status then
        _API.ShowNotification(locale("menu.handler.not_found"), "error")
        return
    end

    local menuIcons = Config.Business.MenuIcons or {}
    local stockCfg = Config.Business.Stock

    local unitPrice = math.floor(stockCfg.LaunderDollarsPerUnit * (stockCfg.UnitPricePercent / 100))

    local unitsPerCycle = status.expectedRevenue / stockCfg.LaunderDollarsPerUnit
    local capacity = math.floor(unitsPerCycle * stockCfg.maxCapacityCycles)
    local storagePercent = capacity > 0 and math.floor((status.stock / capacity) * 100) or 0

    local remaining = math.max(0, status.expectedRevenue - status.cycleLaundered)
    local stockNeeded = math.ceil(remaining / stockCfg.LaunderDollarsPerUnit)
    local capReached = stockNeeded <= 0
    local coverage = capReached and 100
        or math.floor(math.min(1, status.stock / stockNeeded) * 100)

    local coverageColor
    if capReached then
        coverageColor = "red"
    elseif coverage <= 30 then
        coverageColor = "red"
    elseif coverage <= 60 then
        coverageColor = "orange"
    else
        coverageColor = "green"
    end

    local missionActive = IsStockMissionActive()
    local stockFull = status.stock >= capacity
    local stockDisabled = missionActive or stockFull
    local stockDesc
    if missionActive then
        stockDesc = string.format(locale("menu.handler.order_in_progress"), Config.Business.StockMission.CancelCommand)
    elseif stockFull then
        stockDesc = locale("menu.handler.stock_full_desc")
    else
        stockDesc = locale("menu.handler.order_stock_desc")
    end

    local options = {
        {
            title       = ("%s: %d / %d %s"):format(
                locale("menu.handler.view_stock"),
                status.stock,
                capacity,
                locale("menu.handler.units")
            ),
            icon        = menuIcons.viewStock or "fa-solid fa-warehouse",
            description = locale("menu.handler.view_stock_desc"),
            progress    = storagePercent,
            colorScheme = "blue",
        },
    }

    if stockCfg.ShowCycleReadiness then
        options[#options + 1] = capReached and {
            title       = locale("menu.handler.cycle_cap_reached"),
            icon        = menuIcons.cycleReadiness or "fa-solid fa-gauge-high",
            description = locale("menu.handler.cycle_cap_reached_desc"),
            progress    = coverage,
            colorScheme = coverageColor,
        } or {
            title       = ("%s: %d%%"):format(
                locale("menu.handler.cycle_readiness"),
                coverage
            ),
            icon        = menuIcons.cycleReadiness or "fa-solid fa-gauge-high",
            description = locale("menu.handler.cycle_readiness_desc"),
            progress    = coverage,
            colorScheme = coverageColor,
        }
    end

    options[#options + 1] = {
        title       = locale("menu.handler.order_stock"),
        icon        = menuIcons.orderStock or "fa-solid fa-box",
        description = stockDesc,
        disabled    = stockDisabled,
        onSelect    = function()
            OpenStockOrderDialog(businessId, status)
        end,
    }

    lib.registerContext({
        id      = "moneywash:handler:stock",
        title   = locale("menu.handler.stock"),
        menu    = "moneywash:handler:main",
        options = options,
    })

    lib.showContext("moneywash:handler:stock")
end

--- Safe submenu - shows the covered/exposed balance breakdown and
--- lets the player make a bank deposit.
--- @param businessId number
function OpenSafeMenu(businessId)
    local status = lib.callback.await("t1ger_moneywash:server:getBusinessStatus", false, businessId)
    if not status then
        _API.ShowNotification(locale("menu.handler.not_found"), "error")
        return
    end

    local menuIcons = Config.Business.MenuIcons or {}
    local depositDisabled = (status.safeCovered + status.safeExposed) <= 0
    local depositDesc
    if depositDisabled then
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
            },
            {
                title       = ("%s: %s"):format(locale("menu.handler.safe_exposed"), FormatMoney(status.safeExposed)),
                icon        = menuIcons.safeExposed or "fa-solid fa-triangle-exclamation",
                description = locale("menu.handler.safe_exposed_desc"),
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
--- LAUNDER FLOW
--- ============================================================================

--- @param businessId number
function StartLaunderFlow(businessId)
    local dirtyMoney = lib.callback.await("t1ger_moneywash:server:getDirtyMoney", false) or 0

    if dirtyMoney <= 0 then
        _API.ShowNotification(locale("menu.launder.no_dirty_cash"), "error", {})
        return OpenHandlerMenu(businessId)
    end

    local maximum = math.min(math.floor(dirtyMoney), Config.CashCounter.MaxAmount)

    local input = lib.inputDialog(
        locale("menu.launder.title"),
        {
            {
                type = "number",
                label = locale("cashCounter.amount"),
                description = string.format(
                    locale("cashCounter.amountAvailable"),
                    FormatMoney(maximum)
                ),
                min = 1,
                max = maximum,
                precision = 0,
                required = true,
            },
        }
    )

    if not input then return end

    local amount = tonumber(input[1])

    if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
        _API.ShowNotification(locale("cashCounter.errors.invalid_amount"), "error", {})
        return
    end

    OpenCashCounter(businessId, amount, "inject")
end

--- ============================================================================
--- STOCK ORDER DIALOG
--- ============================================================================

--- @param businessId number
--- @param status table
function OpenStockOrderDialog(businessId, status)
    if IsStockMissionActive() then
        _API.ShowNotification(locale("notification.mission_already_active"), "error")
        return OpenStockMenu(businessId)
    end

    local eligibility = lib.callback.await("t1ger_moneywash:server:canPlaceStockOrder", false)

    if not eligibility.eligible then
        _API.ShowNotification(
            string.format(locale("menu.stock.order_on_cooldown"), eligibility.cooldownRemaining or 0),
            "error"
        )
        return OpenStockMenu(businessId)
    end

    local stockCfg = Config.Business.Stock
    local capacity = math.floor((status.expectedRevenue / stockCfg.LaunderDollarsPerUnit) * stockCfg.maxCapacityCycles)
    local maxOrder = math.min(status.maxOrder, capacity - status.stock)
    local minOrder = math.min(status.minOrder, maxOrder)
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
        return OpenStockMenu(businessId)
    end

    local totalCost = units * unitPrice

    local confirmed = lib.alertDialog({
        header   = locale("menu.stock.confirm_title"),
        content  = string.format(locale("menu.stock.confirm_body"), units, FormatMoney(totalCost)),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then
        return OpenStockMenu(businessId)
    end

    local result = lib.callback.await("t1ger_moneywash:server:orderStock", false, businessId, units)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return OpenStockMenu(businessId)
    end

    StartStockMission(businessId, result.missionData)
end

--- ============================================================================
--- BANK DEPOSIT DIALOG
--- ============================================================================

--- @param businessId number
--- @param status table
function OpenBankDepositDialog(businessId, status)
    local totalSafe = status.safeCovered + status.safeExposed
    local maximum = math.min(totalSafe, Config.CashCounter.MaxAmount)

    local input = lib.inputDialog(locale("menu.deposit.title"), {
        {
            type        = "number",
            label       = string.format(locale("menu.deposit.amount_label"), FormatMoney(maximum)),
            description = string.format(locale("menu.deposit.exposed_desc"), FormatMoney(status.safeExposed), FormatMoney(status.safeCovered)),
            min         = 1,
            max         = maximum,
            precision   = 0,
            required    = true,
        },
    })

    if not input or not input[1] then return end

    local amount = tonumber(input[1])
    if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
        _API.ShowNotification(locale("cashCounter.errors.invalid_amount"), "error", {})
        return
    end

    -- Money leaves the Safe only when the cash counter completes
    OpenCashCounter(businessId, amount, "withdraw")
end

--- ============================================================================
--- MANAGE BUSINESS SUBMENU
--- ============================================================================

--- @param businessId number
function OpenManageBusinessMenu(businessId)
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
        return OpenManageBusinessMenu(businessId)
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
            type     = "checkbox",
            label    = locale("menu.transfer.confirm_body"),
            required = true,
        },
    })

    if not input or not input[1] or not input[2] then
        return OpenManageBusinessMenu(businessId)
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
--- POLICE ATM MENU
--- ============================================================================

--- Called by the ATM target when an officer interacts. The server decides which
--- flagged deposits are at this ATM, based on the officer's position.
function OpenPoliceATMMenu()
    local deposits = lib.callback.await("t1ger_moneywash:server:getFlaggedDeposits", false)

    if not deposits or #deposits == 0 then
        _API.ShowNotification(locale("menu.police.no_flagged_deposits"), "inform", {})
        return
    end

    local options = {}

    for _, deposit in ipairs(deposits) do
        local minutes = math.floor(deposit.remainingSeconds / 60)
        local seconds = deposit.remainingSeconds % 60

        options[#options + 1] = {
            title    = string.format(locale("menu.police.deposit_entry"), FormatMoney(deposit.amount)),
            icon     = "fa-solid fa-money-bill",
            metadata = {
                { label = locale("menu.police.clears_in"), value = string.format("%dm %ds", minutes, seconds) },
            },
            onSelect = function()
                ConfirmConfiscateDeposit(deposit.ref, deposit.amount)
            end,
        }
    end

    lib.registerContext({
        id      = "moneywash:police:atm",
        title   = locale("menu.police.teller_title"),
        options = options,
    })

    lib.showContext("moneywash:police:atm")
end

--- Confiscation confirmation for police
--- @param ref number Deposit reference from the server
--- @param amount number
function ConfirmConfiscateDeposit(ref, amount)
    local confirmed = lib.alertDialog({
        header   = locale("menu.police.confiscate_title"),
        content  = string.format(locale("menu.police.confiscate_body"), FormatMoney(amount)),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then return end

    local result = lib.callback.await("t1ger_moneywash:server:confiscateDeposit", false, ref)

    if result and result.success then
        _API.ShowNotification(locale("menu.police.confiscate_success"), "success", {})
    else
        _API.ShowNotification(locale("notification.error_" .. ((result and result.reason) or "unknown")), "error", {})
    end
end