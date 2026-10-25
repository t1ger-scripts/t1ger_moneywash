--- Cash bag deposit (client): the ATM targets. A player carrying a cash bag can deposit it,
--- police can inspect flagged deposits. The server owns all state, this file only asks.

local busy = false -- True while the bag menu, the progress bar or a request is running

local hasBag, checkedAt = false, 0

--- True if the player carries a cash bag. Targets ask every frame, so the inventory is read once a second.
---@return boolean
local function carriesBag()
    local now = GetGameTimer()

    if now - checkedAt > 1000 then
        checkedAt = now
        hasBag = _API.Inventory.HasItem(Config.Withdraw.Item, 1) == true
    end

    return hasBag
end

--- Lets the player choose between their bags. A single bag is used without asking.
---@param bags { id: integer, amount: integer, label: string }[]
---@return integer|nil bagId nil if the menu was closed
local function chooseBag(bags)
    if #bags == 1 then return bags[1].id end

    return ChooseCashBag(bags)
end

--- Asks the server for the player's bags, lets them choose one and deposits it.
---@param atm number ATM entity handle
local function deposit(atm)
    local bags = ServerRequest("t1ger_moneywash:server:getCashBags")
    if not bags.success then return NotifyError(bags.reason) end

    local bagId = chooseBag(bags.data)
    if not bagId then return end

    local coords = GetEntityCoords(atm)
    local model = GetEntityModel(atm)

    local completed = ProgressBar({
        duration     = Config.Deposit.SubmitDuration,
        label        = locale("progress.atm_deposit"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
        anim         = Config.Deposit.Animation,
    })
    if not completed then return end

    -- On success the server notifies the player itself
    local result = ServerRequest("t1ger_moneywash:server:depositCashBag", bagId, { x = coords.x, y = coords.y, z = coords.z }, model)

    if not result.success then NotifyError(result.reason) end
end

---@param atm number ATM entity handle
local function startDeposit(atm)
    if busy or IsPedInAnyVehicle(PlayerPedId(), false) then return end

    busy = true
    local ok, err = pcall(deposit, atm)
    busy = false

    if not ok then DebugPrint("cash_bag", "deposit failed:", err) end
end

--- Shows a progress bar at the ATM, with the officer's animation.
---@param duration integer Ms
---@param label string
---@return boolean completed
local function atmProgress(duration, label)
    return ProgressBar({
        duration     = duration,
        label        = label,
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
        anim         = Config.Police.ATM.Animation,
    })
end

--- Pulls the flagged transfers at this ATM from the server and opens the list.
local function inspectATM()
    if busy then return end

    busy = true
    local completed = atmProgress(Config.Police.ATM.InspectDuration, locale("progress.atm_inspect"))
    local deposits = completed and ServerRequest("t1ger_moneywash:server:getFlaggedDeposits")
    busy = false

    if not completed then return end
    if deposits.success == false then return NotifyError(deposits.reason) end

    if #deposits == 0 then
        return _API.ShowNotification(locale("menu.police.no_flagged_deposits"), "inform")
    end

    OpenPoliceATMMenu(deposits)
end

--- Seizes a flagged transfer after the officer confirms. The money vanishes.
---@param deposit table One entry of the list given to OpenPoliceATMMenu
function ConfiscateDeposit(deposit)
    if busy or not ConfirmConfiscate(deposit) then return end

    busy = true
    local completed = atmProgress(Config.Police.ATM.SeizeDuration, locale("progress.atm_seize"))
    local result = completed and ServerRequest("t1ger_moneywash:server:confiscateDeposit", deposit.ref)
    busy = false

    if not completed then return end

    if result.success then
        _API.ShowNotification(locale("menu.police.confiscate_success"), "success")
    else
        NotifyError(result.reason)
    end
end

CreateThread(function()
    while not _Target do Wait(100) end

    _API.Target.AddModel(Config.Deposit.Models, {
        {
            name        = "t1ger_moneywash:atm:deposit",
            icon        = Config.Deposit.Target.icon,
            label       = locale("target.atm_deposit"),
            distance    = Config.Deposit.Target.distance,
            canInteract = function()
                return not busy and carriesBag()
            end,
            onSelect    = startDeposit,
        },
        {
            name        = "t1ger_moneywash:atm:review",
            icon        = Config.Police.ATM.Target.icon,
            label       = locale("target.atm_review"),
            distance    = Config.Police.ATM.Target.distance,
            canInteract = function()
                return IsPoliceJobWithGrade(Config.Police.ATM.MinGrade, Config.Police.ATM.RequireDuty)
            end,
            onSelect    = inspectATM,
        },
    })
end)

-- Tells the inventory which bag metadata to show in the tooltip. Some inventories forget it when they restart.
local function registerMetadata()
    _API.Inventory.DisplayMetadata({
        { "amount", locale("general.cash_bag_amount") },
        { "serial", locale("general.cash_bag_serial") },
    })
end

CreateThread(function()
    while not _Inventory do Wait(100) end
    registerMetadata()
end)

AddEventHandler("onClientResourceStart", function(name)
    if _Inventory and name == _Inventory then registerMetadata() end
end)