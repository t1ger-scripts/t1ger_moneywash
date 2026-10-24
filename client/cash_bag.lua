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
                return IsPoliceJobWithGrade(Config.Police.ATM.MinGrade)
            end,
            onSelect    = function()
                OpenPoliceATMMenu()
            end,
        },
    })
end)

-- ox_inventory only shows metadata that is registered. Other inventories show it their own way.
CreateThread(function()
    while not _Inventory do Wait(100) end
    if _Inventory ~= "ox_inventory" then return end

    _API.Inventory.DisplayMetadata()

    exports[_Inventory]:displayMetadata({
        { "amount", locale("general.cash_bag_amount") },
        { "bagId",  locale("general.cash_bag_id") },
    })
end)