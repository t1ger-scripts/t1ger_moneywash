--- ============================================================================
--- Business Missions
--- Client-side flows for stock delivery, bank deposit and accountant review.
--- Called by menu.lua after the player confirms an action.
--- All server validation happens server-side — client only handles the
--- physical interaction, props, animations and waypoints.
--- ============================================================================

--- Active mission state flags — prevent overlapping missions
local StockMissionActive   = false
local DepositMissionActive = false
local ReviewMissionActive  = false

--- Globally accessible pending deposit (synced from server on login)
ActivePendingDeposit = ActivePendingDeposit or nil

--- ============================================================================
--- LAUNDER FLOW
--- Simple: progress bar + animation at the Handler NPC, no travel required
--- ============================================================================

--- @param businessId number
--- @param amount number gross dirty cash to launder
function StartLaunderFlow(businessId, amount)
    -- Progress bar at the Handler NPC
    local anim = GetLaunderAnimation()
    lib.requestAnimDict(anim.dict)

    local playerPed = PlayerPedId()
    TaskPlayAnim(playerPed, anim.dict, anim.clip, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)

    local completed = ProgressBar({
        duration = anim.duration,
        label    = locale("progress.laundering"),
        useWhileDead = false,
        canCancel    = false,
        disable = {move = true, car = true, combat = true},
        anim = {dict = anim.dict, clip = anim.clip, flag = anim.flag},
    })

    StopAnimTask(playerPed, anim.dict, anim.clip, 1.0)

    if not completed then return end

    local result = lib.callback.await("t1ger_moneywash:server:launderMoney", false, businessId, amount)

    if not result.success then
        _API.ShowNotification({
            title = locale("notification.error_" .. (result.reason or "unknown")),
            type  = "error",
        })
        return
    end

    local r = result.result
    _API.ShowNotification({
        title       = locale("notification.launder_success"),
        description = string.format(locale("notification.launder_detail"),
            FormatMoney(r.cleanCovered + r.cleanExposed),
            FormatMoney(r.fee),
            r.newLabel.name
        ),
        type = "success",
    })
end

--- ============================================================================
--- BANK DEPOSIT MISSION
--- Flow: receive cash bag → drive to bank → interact with teller → pending
--- ============================================================================

--- @param businessId number
--- @param amount number
function StartDepositMission(businessId, amount)
    if DepositMissionActive then
        _API.ShowNotification({title = locale("notification.mission_already_active"), type = "error"})
        return
    end

    local result = lib.callback.await("t1ger_moneywash:server:initiateBankDeposit", false, businessId, amount)

    if not result.success then
        _API.ShowNotification({
            title = locale("notification.error_" .. (result.reason or "unknown")),
            type  = "error",
        })
        return
    end

    DepositMissionActive = true
    local depositData = result.depositData

    -- Spawn cash bag prop on player
    local cashBag = SpawnProp(GetCashBagModel(), GetEntityCoords(PlayerPedId()), true, 28422)

    -- Set waypoint to assigned bank
    local bank = depositData.bankLocation
    SetNewWaypoint(bank.x, bank.y)

    _API.ShowNotification({title = locale("notification.deposit_started"), type = "inform"})
    lib.showTextUI(locale("textui.drive_to_bank"), {icon = "fa-solid fa-building-columns"})

    -- Wait for player to arrive at the bank
    CreateThread(function()
        while DepositMissionActive do
            Wait(500)
            if IsNearCoords(bank, 20.0) then
                lib.hideTextUI()
                lib.showTextUI(locale("textui.interact_teller"), {icon = "fa-solid fa-hand"})

                -- Register teller target at this bank location
                -- (bank teller targets are global — registered in client/main.lua)
                -- Player interacts with teller which calls CompleteBankDeposit below
                break
            end
        end
    end)

    -- Store cash bag reference so it can be cleaned up
    ActiveCashBag = cashBag
end

--- Called when player interacts with the bank teller target during a deposit mission
function CompleteBankDepositAtTeller()
    if not DepositMissionActive then return end

    lib.hideTextUI()

    local anim = GetDepositAnimation()
    lib.requestAnimDict(anim.dict)
    local playerPed = PlayerPedId()

    TaskPlayAnim(playerPed, anim.dict, anim.clip, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)

    local completed = ProgressBar({
        duration     = anim.duration,
        label        = locale("progress.depositing"),
        useWhileDead = false,
        canCancel    = false,
        disable      = {move = true, car = true, combat = true},
        anim         = {dict = anim.dict, clip = anim.clip, flag = anim.flag},
    })

    StopAnimTask(playerPed, anim.dict, anim.clip, 1.0)

    if not completed then return end

    -- Remove cash bag
    if ActiveCashBag then
        DeleteProp(ActiveCashBag)
        ActiveCashBag = nil
    end

    DepositMissionActive = false
    ClearWaypoint()

    _API.ShowNotification({
        title       = locale("notification.deposit_processing"),
        description = string.format(locale("notification.deposit_processing_desc"),
            Config.BankDeposit.ProcessingTime),
        type = "inform",
    })
end

--- Handle disconnect during deposit — money returns to Safe automatically (server-side)
--- Client just cleans up the prop
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ActiveCashBag then DeleteProp(ActiveCashBag) end
end)

--- ============================================================================
--- ACCOUNTANT REVIEW MISSION
--- Flow: drive to assigned office → animation → submit receipts → reduction applied
--- ============================================================================

--- @param businessId number
--- @param selectedReceiptIds table
function StartReviewMission(businessId, selectedReceiptIds)
    if ReviewMissionActive then
        _API.ShowNotification({title = locale("notification.mission_already_active"), type = "error"})
        return
    end

    ReviewMissionActive = true

    -- Pick random accountant office from config pool
    local offices = require("shared/accountantoffices")
    local office  = offices[math.random(1, #offices)]

    SetNewWaypoint(office.x, office.y)
    _API.ShowNotification({title = locale("notification.review_drive_to_office"), type = "inform"})
    lib.showTextUI(locale("textui.drive_to_office"), {icon = "fa-solid fa-briefcase"})

    -- Wait for player to arrive at office
    CreateThread(function()
        while ReviewMissionActive do
            Wait(500)
            if IsNearCoords(office, 10.0) then
                lib.hideTextUI()
                ExecuteReviewAtOffice(businessId, selectedReceiptIds, office)
                break
            end
        end
    end)
end

--- Player has arrived at the office — play animation and submit review
--- @param businessId number
--- @param selectedReceiptIds table
--- @param office vector4
function ExecuteReviewAtOffice(businessId, selectedReceiptIds, office)
    local anim = GetReviewAnimation()
    lib.requestAnimDict(anim.dict)
    local playerPed = PlayerPedId()

    TaskPlayAnim(playerPed, anim.dict, anim.clip, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)

    local completed = ProgressBar({
        duration     = anim.duration,
        label        = locale("progress.reviewing_books"),
        useWhileDead = false,
        canCancel    = false,
        disable      = {move = true, car = true, combat = true},
        anim         = {dict = anim.dict, clip = anim.clip, flag = anim.flag},
    })

    StopAnimTask(playerPed, anim.dict, anim.clip, 1.0)

    if not completed then
        ReviewMissionActive = false
        return
    end

    -- Submit review to server
    -- CurrentCycle is tracked server-side; we pass 0 and server uses its own cycle counter
    local result = lib.callback.await("t1ger_moneywash:server:executeReview", false,
        businessId, selectedReceiptIds, 0)

    ReviewMissionActive = false
    ClearWaypoint()

    if not result.success then
        _API.ShowNotification({
            title = locale("notification.error_" .. (result.reason or "unknown")),
            type  = "error",
        })
        return
    end

    local r = result.result
    _API.ShowNotification({
        title       = locale("notification.review_success"),
        description = string.format(locale("notification.review_detail"),
            r.effectiveness,
            r.reduction,
            FormatMoney(r.fee)
        ),
        type = "success",
    })
end