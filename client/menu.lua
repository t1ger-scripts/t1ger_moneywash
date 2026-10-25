--- Menus and dialogs (client). Every ox_lib context menu, input dialog and alert dialog of the script is here.
--- The other client files hold the logic: they call the Ask/Confirm/Choose functions below and get the
--- answer back, so this file can be restyled freely. Whatever is returned, the server checks it again.

---@return table<string, string> Icons from Config.HandlerNPC.MenuIcons
local function getIcons()
    return Config.HandlerNPC.MenuIcons or {}
end

---@param seconds number
---@return string duration e.g. "2m 5s"
local function formatDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))

    return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
end

--- Shows an alert dialog with a confirm and a cancel button.
---@param header string
---@param content string
---@return boolean confirmed
local function confirmDialog(header, content)
    local answer = lib.alertDialog({
        header   = header,
        content  = content,
        centered = true,
        cancel   = true,
    })

    return answer == "confirm"
end

--- Gets the live status of a business from the server. Shows the error and returns nil if it can't be had.
---@param businessId integer
---@return table|nil status
local function getStatus(businessId)
    local status = ServerRequest("t1ger_moneywash:server:getBusinessStatus", businessId)

    if status.success == false then
        NotifyError(status.reason)
        return nil
    end

    return status
end

--- The Review Books row of the main menu.
---@param businessId integer
---@param status table From getBusinessStatus
---@return table option
local function buildReviewOption(businessId, status)
    if status.reviewActive then
        return {
            title       = locale("menu.handler.review_cancel"),
            icon        = "fa-solid fa-ban",
            description = locale("menu.handler.review_cancel_desc"),
            onSelect    = function()
                CancelReview()
            end,
        }
    end

    local icon = getIcons().reviewBooks or "fa-solid fa-folder-open"

    if (status.reviewCooldown or 0) > 0 then
        local minutes = string.format(locale("menu.handler.review_cooldown_minutes"), math.ceil(status.reviewCooldown / 60))

        return {
            title       = locale("menu.handler.review_books"),
            icon        = icon,
            description = string.format(locale("menu.handler.review_cooldown"), minutes),
            disabled    = true,
        }
    end

    return {
        title       = locale("menu.handler.review_books"),
        icon        = icon,
        description = locale("menu.handler.review_books_desc"),
        onSelect    = function()
            OpenBooksReview(businessId)
        end,
    }
end

--- Opens the Handler NPC main menu of an owned business.
---@param businessId integer
function OpenHandlerMenu(businessId)
    local status = getStatus(businessId)
    if not status then return end

    local icons = getIcons()

    local suspicionEntry = { label = locale("menu.handler.suspicion"), value = status.suspicionLabel }

    if Config.Suspicion.ShowExactValue and status.suspicion then
        suspicionEntry.value = ("%s (%d)"):format(status.suspicionLabel, math.floor(status.suspicion))
        suspicionEntry.progress = status.suspicion
        suspicionEntry.colorScheme = status.suspicionColor
    end

    local safeEmpty = (status.safeCovered + status.safeExposed) <= 0

    local options = {
        {
            title       = locale("menu.handler.overview"),
            icon        = icons.overview or "fa-solid fa-chart-line",
            description = locale("menu.handler.overview_desc"),
            metadata    = {
                { label = locale("menu.handler.total_cash"), value = FormatMoney(status.safeCovered + status.safeExposed) },
                { label = locale("menu.handler.stock"),      value = status.stock .. " " .. locale("menu.handler.units") },
                suspicionEntry,
                { label = locale("menu.handler.cycle_progress"), value = FormatMoney(status.cycleLaundered) .. " / " .. FormatMoney(status.expectedRevenue) },
            },
        },
        {
            title       = locale("menu.handler.launder"),
            icon        = icons.launder or "fa-solid fa-money-bill-wave",
            description = locale("menu.handler.launder_desc"),
            onSelect    = function()
                StartCashOperation(businessId, "launder")
            end,
        },
        {
            title       = locale("menu.handler.stock"),
            icon        = icons.stock or "fa-solid fa-boxes-stacked",
            description = locale("menu.handler.stock_desc"),
            onSelect    = function()
                OpenStockMenu(businessId)
            end,
        },
        {
            title       = locale("menu.handler.safe"),
            icon        = icons.safe or "fa-solid fa-lock",
            description = safeEmpty and locale("menu.handler.no_safe_balance") or locale("menu.handler.safe_desc"),
            disabled    = safeEmpty,
            onSelect    = function()
                OpenSafeMenu(businessId)
            end,
        },
    }

    if Config.Review and Config.Review.Enable then
        options[#options + 1] = buildReviewOption(businessId, status)
    end

    options[#options + 1] = {
        title       = locale("menu.handler.manage"),
        icon        = icons.manage or "fa-solid fa-gear",
        description = locale("menu.handler.manage_desc"),
        onSelect    = function()
            OpenManageBusinessMenu(businessId)
        end,
    }

    lib.registerContext({
        id      = "moneywash:handler:main",
        title   = locale("menu.handler.title"),
        options = options,
    })

    lib.showContext("moneywash:handler:main")
end

--- Opens the stock menu: stored units, cycle readiness (if Config.Stock.ShowCycleReadiness) and the
--- order or cancel action.
---@param businessId integer
function OpenStockMenu(businessId)
    local status = getStatus(businessId)
    if not status then return end

    local icons = getIcons()
    local stockCfg = Config.Stock
    local capacity = status.stockCapacity
    local storagePercent = capacity > 0 and math.floor((status.stock / capacity) * 100) or 0

    local remaining = math.max(0, status.expectedRevenue - status.cycleLaundered)
    local stockNeeded = math.ceil(remaining / stockCfg.LaunderDollarsPerUnit)
    local capReached = stockNeeded <= 0
    local coverage = capReached and 100 or math.floor(math.min(1, status.stock / stockNeeded) * 100)

    local coverageColor = "green"
    if capReached or coverage <= 30 then
        coverageColor = "red"
    elseif coverage <= 60 then
        coverageColor = "orange"
    end

    local options = {
        {
            title       = ("%s: %d / %d %s"):format(locale("menu.handler.view_stock"), status.stock, capacity, locale("menu.handler.units")),
            icon        = icons.viewStock or "fa-solid fa-warehouse",
            description = locale("menu.handler.view_stock_desc"),
            progress    = storagePercent,
            colorScheme = "blue",
        },
    }

    if stockCfg.ShowCycleReadiness then
        options[#options + 1] = {
            title       = capReached and locale("menu.handler.cycle_cap_reached")
                or ("%s: %d%%"):format(locale("menu.handler.cycle_readiness"), coverage),
            icon        = icons.cycleReadiness or "fa-solid fa-gauge-high",
            description = locale(capReached and "menu.handler.cycle_cap_reached_desc" or "menu.handler.cycle_readiness_desc"),
            progress    = coverage,
            colorScheme = coverageColor,
        }
    end

    if IsStockMissionActive() then
        local refund = GetStockCancelRefund()

        options[#options + 1] = {
            title       = locale("menu.handler.cancel_order"),
            icon        = icons.cancelOrder or "fa-solid fa-ban",
            description = string.format(locale("menu.handler.cancel_order_desc"), FormatMoney(refund or 0), stockCfg.Mission.CancelCooldown),
            onSelect    = function()
                RequestStockCancel()
                OpenStockMenu(businessId)
            end,
        }
    else
        local stockFull = status.stock >= capacity

        options[#options + 1] = {
            title       = locale("menu.handler.order_stock"),
            icon        = icons.orderStock or "fa-solid fa-box",
            description = locale(stockFull and "menu.handler.stock_full_desc" or "menu.handler.order_stock_desc"),
            disabled    = stockFull,
            onSelect    = function()
                if not PlaceStockOrder(businessId, status) then OpenStockMenu(businessId) end
            end,
        }
    end

    lib.registerContext({
        id      = "moneywash:handler:stock",
        title   = locale("menu.handler.stock"),
        menu    = "moneywash:handler:main",
        options = options,
    })

    lib.showContext("moneywash:handler:stock")
end

--- Opens the Safe menu: covered and exposed balance, and the cash withdrawal.
---@param businessId integer
function OpenSafeMenu(businessId)
    local status = getStatus(businessId)
    if not status then return end

    local icons = getIcons()
    local empty = (status.safeCovered + status.safeExposed) <= 0

    lib.registerContext({
        id      = "moneywash:handler:safe",
        title   = locale("menu.handler.safe"),
        menu    = "moneywash:handler:main",
        options = {
            {
                title       = ("%s: %s"):format(locale("menu.handler.safe_covered"), FormatMoney(status.safeCovered)),
                icon        = icons.safeCovered or "fa-solid fa-shield-halved",
                description = locale("menu.handler.safe_covered_desc"),
            },
            {
                title       = ("%s: %s"):format(locale("menu.handler.safe_exposed"), FormatMoney(status.safeExposed)),
                icon        = icons.safeExposed or "fa-solid fa-triangle-exclamation",
                description = locale("menu.handler.safe_exposed_desc"),
            },
            {
                title       = locale("menu.handler.withdraw"),
                icon        = icons.withdraw or "fa-solid fa-building-columns",
                description = locale(empty and "menu.handler.no_safe_balance" or "menu.handler.withdraw_desc"),
                disabled    = empty,
                onSelect    = function()
                    StartCashOperation(businessId, "withdraw")
                end,
            },
        },
    })

    lib.showContext("moneywash:handler:safe")
end

--- Asks how much to launder or withdraw.
---@param operation "launder"|"withdraw"
---@param limits { max: integer, exposed?: integer, covered?: integer } What the server allows right now
---@return integer|nil amount Whole number, nil if the dialog was closed
function AskCashAmount(operation, limits)
    local title, label, description

    if operation == "launder" then
        title = locale("menu.launder.title")
        label = locale("menu.launder.amount_label")
        description = string.format(locale("menu.launder.amount_desc"), FormatMoney(limits.max))
    else
        title = locale("menu.withdraw.title")
        label = string.format(locale("menu.withdraw.amount_label"), FormatMoney(limits.max))
        description = string.format(locale("menu.withdraw.exposed_desc"), FormatMoney(limits.exposed), FormatMoney(limits.covered))
    end

    local input = lib.inputDialog(title, {
        {
            type        = "number",
            label       = label,
            description = description,
            min         = 1,
            max         = limits.max,
            precision   = 0,
            required    = true,
        },
    })

    if not input or not input[1] then return nil end

    local amount = tonumber(input[1])
    if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > limits.max then
        NotifyError("invalid_amount")
        return nil
    end

    return amount
end

--- Asks how many stock units to order.
---@param limits { min: integer, max: integer, unitPrice: integer }
---@return integer|nil units Nil if the dialog was closed
function AskStockUnits(limits)
    local input = lib.inputDialog(locale("menu.stock.title"), {
        {
            type        = "number",
            label       = string.format(locale("menu.stock.amount_label"), limits.min, limits.max),
            description = string.format(locale("menu.stock.price_desc"), FormatMoney(limits.unitPrice)),
            min         = limits.min,
            max         = limits.max,
            required    = true,
        },
    })

    if not input or not tonumber(input[1]) then return nil end

    return math.floor(tonumber(input[1]))
end

--- Asks the player to confirm a stock order. The cost is taken from the bank straight away.
---@param units integer
---@param cost integer
---@return boolean confirmed
function ConfirmStockOrder(units, cost)
    return confirmDialog(locale("menu.stock.confirm_title"), string.format(locale("menu.stock.confirm_body"), units, FormatMoney(cost)))
end

--- Asks the player to confirm cancelling the stock order.
---@param refund integer Paid back
---@param lost integer Kept as the penalty
---@return boolean confirmed
function ConfirmStockCancel(refund, lost)
    return confirmDialog(
        locale("menu.stock.cancel_title"),
        string.format(locale("menu.stock.cancel_body"), FormatMoney(refund), FormatMoney(lost), Config.Stock.Mission.CancelCooldown)
    )
end

--- Asks the player to confirm dropping the sealed review folder.
---@param penalty number Percent of the fee that is lost
---@return boolean confirmed
function ConfirmReviewCancel(penalty)
    return confirmDialog(locale("menu.review.cancel_title"), string.format(locale("menu.review.cancel_body"), penalty))
end

--- Lets the player choose one of their cash bags.
---@param bags { id: integer, amount: integer, label: string }[]
---@return integer|nil bagId Nil if the menu was closed
function ChooseCashBag(bags)
    local choice = promise.new()
    local done = false

    local function finish(bagId)
        if done then return end
        done = true
        choice:resolve(bagId)
    end

    local options = {}

    for _, bag in ipairs(bags) do
        options[#options + 1] = {
            title       = FormatMoney(bag.amount),
            description = string.format(locale("menu.deposit.bag_from"), bag.label),
            icon        = "fa-solid fa-sack-dollar",
            onSelect    = function()
                finish(bag.id)
            end,
        }
    end

    lib.registerContext({
        id      = "moneywash:cashbag:choose",
        title   = locale("menu.deposit.bag_title"),
        options = options,
        onExit  = function()
            SetTimeout(150, function()
                finish(nil)
            end)
        end, -- A selection arrives first
    })

    lib.showContext("moneywash:cashbag:choose")

    return Citizen.Await(choice)
end

--- Opens the Manage Business menu: transfer or abandon.
---@param businessId integer
function OpenManageBusinessMenu(businessId)
    local icons = getIcons()

    lib.registerContext({
        id      = "moneywash:handler:manage",
        title   = locale("menu.manage.title"),
        menu    = "moneywash:handler:main",
        options = {
            {
                title       = locale("menu.manage.transfer"),
                icon        = icons.transfer or "fa-solid fa-right-left",
                description = locale("menu.manage.transfer_desc"),
                onSelect    = function()
                    OpenTransferDialog(businessId)
                end,
            },
            {
                title       = locale("menu.manage.abandon"),
                icon        = icons.abandon or "fa-solid fa-door-open",
                description = locale("menu.manage.abandon_desc"),
                onSelect    = function()
                    ConfirmAbandonBusiness(businessId)
                end,
            },
        },
    })

    lib.showContext("moneywash:handler:manage")
end

--- Display names of the nearby players, in one request.
---@param players table[] ox_lib nearby player objects
---@return table<integer, string> names By server id
local function getNearbyPlayerNames(players)
    local serverIds = {}

    for i = 1, #players do
        serverIds[i] = GetPlayerServerId(players[i].id)
    end

    return ServerRequest("t1ger_moneywash:server:getPlayerNames", serverIds)
end

--- Lets the player pick a nearby player and confirm, then transfers the business.
--- Closing the dialog returns to the Manage Business menu.
---@param businessId integer
function OpenTransferDialog(businessId)
    local nearbyPlayers = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), Config.HandlerNPC.TransferDistance or 10.0, Config.Debug == true)

    if #nearbyPlayers == 0 then
        _API.ShowNotification(locale("menu.transfer.no_players_nearby"), "inform")
        return OpenManageBusinessMenu(businessId)
    end

    local names = getNearbyPlayerNames(nearbyPlayers)
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

    if not input or not input[1] or not input[2] then return OpenManageBusinessMenu(businessId) end

    local result = ServerRequest("t1ger_moneywash:server:transferBusiness", tonumber(input[1]), businessId)

    if result.success then
        _API.ShowNotification(locale("menu.transfer.success"), "success")
    else
        NotifyError(result.reason)
    end
end

--- Asks the player to confirm abandoning the business, then abandons it. Nothing is refunded.
---@param businessId integer
function ConfirmAbandonBusiness(businessId)
    if not confirmDialog(locale("menu.abandon.confirm_title"), locale("menu.abandon.confirm_body")) then return end

    local result = ServerRequest("t1ger_moneywash:server:abandonBusiness", businessId)

    if result.success then
        _API.ShowNotification(locale("menu.abandon.success"), "success")
    else
        NotifyError(result.reason)
    end
end

--- Opens the list of flagged deposits at the ATM the officer is standing at.
---@param deposits { ref: integer, amount: integer, name?: string, business?: string, remainingSeconds: number }[]
function OpenPoliceATMMenu(deposits)
    local options = {}

    for _, deposit in ipairs(deposits) do
        options[#options + 1] = {
            title    = string.format(locale("menu.police.deposit_entry"), FormatMoney(deposit.amount)),
            icon     = "fa-solid fa-money-bill",
            metadata = {
                { label = locale("menu.police.depositor"), value = deposit.name or locale("menu.police.unknown") },
                { label = locale("menu.police.business"),  value = deposit.business or locale("menu.police.unknown") },
                { label = locale("menu.police.clears_in"), value = formatDuration(deposit.remainingSeconds) },
            },
            onSelect = function()
                ConfiscateDeposit(deposit)
            end,
        }
    end

    lib.registerContext({
        id      = "moneywash:police:atm",
        title   = locale("menu.police.atm_title"),
        options = options,
    })

    lib.showContext("moneywash:police:atm")
end

--- Asks the officer to confirm confiscating a deposit.
---@param deposit table One entry of the list given to OpenPoliceATMMenu
---@return boolean confirmed
function ConfirmConfiscate(deposit)
    return confirmDialog(
        locale("menu.police.confiscate_title"),
        string.format(
            locale("menu.police.confiscate_body"),
            deposit.name or locale("menu.police.unknown"),
            deposit.business or locale("menu.police.unknown"),
            FormatMoney(deposit.amount),
            formatDuration(deposit.remainingSeconds)
        )
    )
end