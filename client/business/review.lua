--- ============================================================================
--- Accountant Review (Review Books) Client
--- Opens the desk UI, relays its actions to the server, then runs the delivery
--- mission: carry the folder to the accountant and pay the fee.
--- The client never decides anything - every result comes from the server.
--- ============================================================================

local SERVER = "t1ger_moneywash:server:review:"

local NUI = {
    prepare = "t1ger_moneywash:review:prepare",
    stamp   = "t1ger_moneywash:review:stamp",
    cancel  = "t1ger_moneywash:review:cancel",
    close   = "t1ger_moneywash:review:close",
}

local MSG = {
    open  = "t1ger_moneywash:review:open",
    close = "t1ger_moneywash:review:close",
}

--- Locale keys used by this file. Rename here if your locale file differs.
local KEYS = {
    errorPrefix = "notification.error_",
    errorUnknown = "notification.error_unknown",
    started   = "notification.review_prepared",
    completed = "notification.review_completed", -- %s suspicion before, %s after, %s fee
    cancelled = "notification.review_cancelled",
    timeout   = "notification.review_cancel_timeout",
    died      = "notification.review_cancel_dead",
    target    = "target.accountant",
}

local ui = { open = false, sealed = false, businessId = nil, result = nil }

---@type table|nil { businessId, location, prop, blip, ped, point, busy, result }
local mission = nil

local TARGET_NAME = "t1ger_moneywash:accountant"

--- ---------------------------------------------------------------------------
--- HELPERS
--- ---------------------------------------------------------------------------

--- Server reasons that reuse an existing error key.
local REASON_ALIASES = {
    not_enough_money     = "insufficient_funds",
    business_raided      = "raid_in_progress",
    busy                 = "business_busy",
    pending_cash_counter = "business_busy",
    request_failed       = "unknown",
}

--- Translates a server failure reason into a readable message.
local function reasonText(reason)
    local key = KEYS.errorPrefix .. tostring(REASON_ALIASES[reason] or reason)
    local text = locale(key)

    if not text or text == key then
        return locale(KEYS.errorUnknown)
    end

    return text
end

--- Formats a locale string safely (a wrong placeholder never errors).
local function formatLocale(key, ...)
    local text = locale(key)
    local ok, result = pcall(string.format, text, ...)
    return ok and result or text
end

local function formatSuspicion(value)
    return ("%.1f"):format(tonumber(value) or 0)
end

local function notifyError(reason)
    _API.ShowNotification(reasonText(reason), "error")
end

local function request(name, ...)
    local ok, response = pcall(lib.callback.await, SERVER .. name, false, ...)
    if not ok or type(response) ~= "table" then
        return { success = false, reason = "request_failed" }
    end
    return response
end

local function closeUi(notifyNui)
    if notifyNui then SendNUIMessage({ action = MSG.close }) end
    CloseMoneywashUi("review")
    ui = { open = false, sealed = false }
end

--- ---------------------------------------------------------------------------
--- CARRY (folder prop + animation)
--- ---------------------------------------------------------------------------

local function startCarryAnimation()
    local anim = Config.Review.Folder.Animation
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(
        PlayerPedId(), anim.dict, anim.name,
        anim.blendIn or 8.0, anim.blendOut or -8.0, anim.duration or -1,
        anim.flag or 49, 0, false, false, false
    )
    RemoveAnimDict(anim.dict)
end

local function stopCarryAnimation()
    local anim = Config.Review.Folder.Animation
    local ped = PlayerPedId()

    if IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
        StopAnimTask(ped, anim.dict, anim.name, anim.blendOut or -8.0)
    end
end

local function createFolderProp()
    local cfg = Config.Review.Folder.Prop
    local ped = PlayerPedId()

    if not IsModelInCdimage(GetHashKey(cfg.model)) then
        print(("^1[MoneyWash] Invalid review folder prop model '%s'. Check Config.Review.Folder.Prop.model.^7"):format(cfg.model))
        return nil
    end

    lib.requestModel(cfg.model)
    local prop = CreateObject(GetHashKey(cfg.model), 0.0, 0.0, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(GetHashKey(cfg.model))

    AttachEntityToEntity(
        prop, ped, GetPedBoneIndex(ped, cfg.bone),
        cfg.pos.x, cfg.pos.y, cfg.pos.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z,
        true, true, false, true, 1, true
    )

    return prop
end

--- Single watchdog while a mission runs: hides the folder in vehicles and
--- restores the carry animation if something interrupted it.
CreateThread(function()
    while true do
        Wait(500)

        if mission and mission.prop and DoesEntityExist(mission.prop) then
            local ped = PlayerPedId()

            if IsPedInAnyVehicle(ped, false) then
                SetEntityVisible(mission.prop, false, false)
                stopCarryAnimation()
            else
                SetEntityVisible(mission.prop, true, false)

                local anim = Config.Review.Folder.Animation
                if not IsPedRagdoll(ped) and not IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
                    startCarryAnimation()
                end
            end
        end
    end
end)

--- ---------------------------------------------------------------------------
--- MISSION
--- ---------------------------------------------------------------------------

local function removeAccountantPed()
    if not mission or not mission.ped then return end

    _API.Target.RemoveLocalEntity(mission.ped, {
        names  = { TARGET_NAME },
        labels = { locale(KEYS.target) },
    })

    DeletePed(mission.ped)
    mission.ped = nil
end

--- Tears down the mission, whatever stage it was at.
local function resetMission()
    if not mission then return end

    stopCarryAnimation()
    removeAccountantPed()

    if mission.point then mission.point:remove() end
    if mission.blip and DoesBlipExist(mission.blip) then RemoveBlip(mission.blip) end

    if mission.prop and DoesEntityExist(mission.prop) then
        DetachEntity(mission.prop, true, true)
        DeleteEntity(mission.prop)
    end

    mission = nil
end

--- Pay the fee and hand over the folder.
local function deliverFolder()
    if not mission or mission.busy then return end
    mission.busy = true

    local result = mission.result

    local confirmed = lib.alertDialog({
        header   = locale("menu.review.pay_title"),
        content  = formatLocale(
            "menu.review.pay_body",
            result.rows,
            formatSuspicion(result.suspicionBefore),
            formatSuspicion(result.suspicionAfter),
            FormatMoney(result.fee)
        ),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then
        if mission then mission.busy = false end
        return
    end

    local response = request("deliver")

    -- The server may have cancelled the review while the dialog was open.
    if not mission then return end

    if not response.success then
        mission.busy = false

        if response.reason == "no_review" then
            resetMission()
        end

        notifyError(response.reason)
        return
    end

    resetMission()
    _API.ShowNotification(
        formatLocale(
            KEYS.completed,
            formatSuspicion(response.suspicionBefore),
            formatSuspicion(response.suspicionAfter),
            FormatMoney(response.fee)
        ),
        "success"
    )
end

local function spawnAccountant()
    if not mission or mission.ped then return end

    local cfg = Config.Review.Accountant

    if not IsModelInCdimage(GetHashKey(cfg.Model)) then
        print(("^1[MoneyWash] Invalid accountant ped model '%s'. Check Config.Review.Accountant.Model.^7"):format(cfg.Model))
        return
    end

    local ped = SpawnStaticPed(cfg.Model, mission.location, cfg.Scenario)
    mission.ped = ped

    while not _Target do Wait(100) end
    if not mission or mission.ped ~= ped then return end

    _API.Target.AddLocalEntity(ped, {
        {
            name        = TARGET_NAME,
            icon        = cfg.TargetIcon,
            label       = locale(KEYS.target),
            distance    = cfg.TargetDistance,
            canInteract = function()
                return mission ~= nil and not mission.busy
            end,
            onSelect    = deliverFolder,
        },
    })
end

--- Starts the delivery after the stamp: folder in hand, blip on the office.
local function startMission(businessId, result)
    local cfg = Config.Review.Accountant
    local location = cfg.Location

    if not location then
        request("cancel")
        notifyError("no_accountant_locations")
        return
    end

    mission = {
        businessId = businessId,
        location   = location,
        result     = result,
        prop       = createFolderProp(),
    }

    startCarryAnimation()

    local blipCfg = cfg.Blip
    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, blipCfg.Sprite)
    SetBlipDisplay(blip, blipCfg.Display)
    SetBlipScale(blip, blipCfg.Scale)
    SetBlipColour(blip, blipCfg.Color)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(blipCfg.Label)
    EndTextCommandSetBlipName(blip)

    if blipCfg.Route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, blipCfg.RouteColor or blipCfg.Color)
    end

    mission.blip = blip

    mission.point = lib.points.new({
        coords   = vec3(location.x, location.y, location.z),
        distance = cfg.SpawnDistance,
        onEnter  = spawnAccountant,
        onExit   = removeAccountantPed,
    })

    _API.ShowNotification(locale(KEYS.started), "inform")
end

--- ---------------------------------------------------------------------------
--- DESK UI
--- ---------------------------------------------------------------------------

--- Opens the Review Books desk for an owned business.
---@param businessId number
function OpenBooksReview(businessId)
    local cfg = Config.Review
    if not cfg or not cfg.Enable then return notifyError("review_disabled") end

    if not cfg.Accountant.Location then
        return notifyError("no_accountant_locations")
    end

    if not BeginMoneywashUi("review") then return end

    local response = request("open", businessId)

    if not response.success or not response.data then
        CloseMoneywashUi("review")
        return notifyError(response.reason)
    end

    ui = { open = true, sealed = false, businessId = businessId }
    ShowMoneywashUi("review", MSG.open, response.data)
end

--- "Prepare books": the server returns the shuffled worksheet.
RegisterNUICallback(NUI.prepare, function(body, cb)
    if not ui.open or ui.sealed then return cb({ success = false, reason = "no_review" }) end

    local ids = type(body) == "table" and body.ids or nil
    local response = request("prepare", ui.businessId, ids)

    if not response.success then response.message = reasonText(response.reason) end
    cb(response)
end)

--- Stamp: the server grades the answers and locks the result.
RegisterNUICallback(NUI.stamp, function(body, cb)
    if not ui.open or ui.sealed then return cb({ success = false, reason = "no_review" }) end

    local rows = type(body) == "table" and body.rows or nil
    local response = request("stamp", rows)

    if response.success then
        ui.sealed = true
        ui.result = response.result
    else
        response.message = reasonText(response.reason)
    end

    cb(response)
end)

--- Back button / ESC before the stamp: discard everything.
RegisterNUICallback(NUI.cancel, function(_, cb)
    if ui.open and not ui.sealed then request("cancel") end
    closeUi(false)
    cb({ success = true })
end)

--- UI finished (after the filing animation): close it and start the mission.
RegisterNUICallback(NUI.close, function(_, cb)
    local wasSealed, businessId, result = ui.sealed, ui.businessId, ui.result

    if ui.open and not wasSealed then request("cancel") end
    closeUi(false)
    cb({ success = true })

    if wasSealed and result then startMission(businessId, result) end
end)

--- ---------------------------------------------------------------------------
--- MENU + CANCEL
--- ---------------------------------------------------------------------------

--- Cancels a sealed review voluntarily (free, no cooldown).
local function cancelReview()
    local confirmed = lib.alertDialog({
        header   = locale("menu.review.cancel_title"),
        content  = locale("menu.review.cancel_body"),
        centered = true,
        cancel   = true,
    })

    if confirmed ~= "confirm" then return end

    local response = request("cancel")

    if not response.success then
        return notifyError(response.reason)
    end

    resetMission()
    _API.ShowNotification(locale(KEYS.cancelled), "inform")
end

--- Returns the Review Books row for the handler menu.
---@param businessId number
---@param status table result of getBusinessStatus
---@param menuIcons table
---@return table
function BuildReviewMenuOption(businessId, status, menuIcons)
    if status.reviewActive then
        return {
            title       = locale("menu.handler.review_cancel"),
            icon        = "fa-solid fa-ban",
            description = locale("menu.handler.review_cancel_desc"),
            onSelect    = cancelReview,
        }
    end

    if (status.reviewCooldown or 0) > 0 then
        return {
            title       = locale("menu.handler.review_books"),
            icon        = menuIcons.reviewBooks or "fa-solid fa-folder-open",
            description = formatLocale(
                "menu.handler.review_cooldown",
                formatLocale("menu.handler.review_cooldown_minutes", math.ceil(status.reviewCooldown / 60))
            ),
            disabled    = true,
        }
    end

    return {
        title       = locale("menu.handler.review_books"),
        icon        = menuIcons.reviewBooks or "fa-solid fa-folder-open",
        description = locale("menu.handler.review_books_desc"),
        onSelect    = function()
            OpenBooksReview(businessId)
        end,
    }
end

--- ---------------------------------------------------------------------------
--- SERVER EVENTS + CLEANUP
--- ---------------------------------------------------------------------------

--- The server ended the review (timeout, death, cancelled elsewhere).
RegisterNetEvent("t1ger_moneywash:client:reviewCancelled", function(reason)
    if ui.open then closeUi(true) end
    resetMission()

    local key = ({
        review_timeout = KEYS.timeout,
        review_died    = KEYS.died,
    })[reason] or KEYS.cancelled

    _API.ShowNotification(locale(key), "inform")
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    resetMission()
end)