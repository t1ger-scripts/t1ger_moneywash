--- Accountant review (client). Opens the desk UI and passes its steps to the server, then runs the
--- delivery: carry the folder to the accountant. The client decides nothing, every result comes from the server.
--- The accountant ped is local and shown to every player near the office, like the Handler NPCs.

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

local TARGET_NAME = "t1ger_moneywash:accountant"

---@type { open: boolean, sealed: boolean, businessId?: integer, result?: table } State of the desk UI
local ui = { open = false, sealed = false }

---@type { businessId: integer, result: table, prop?: integer, blip?: integer, busy?: boolean }|nil
local mission = nil

---@type integer|nil Accountant ped, only while the player is near the office
local accountantPed = nil

--- Closes the desk UI.
---@param notifyNui boolean True if the UI is still open and must be told to close
local function closeUi(notifyNui)
    if notifyNui then SendNUIMessage({ action = MSG.close }) end
    CloseMoneywashUi("review")
    ui = { open = false, sealed = false }
end

--- Starts the folder carry animation.
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

--- Stops the folder carry animation.
local function stopCarryAnimation()
    local anim = Config.Review.Folder.Animation
    local ped = PlayerPedId()

    if IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
        StopAnimTask(ped, anim.dict, anim.name, anim.blendOut or -8.0)
    end
end

--- Creates the folder and attaches it to the player's hand.
---@return integer|nil prop Nil if the model is invalid
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

--- Hides the folder in vehicles and restores the carry animation if something interrupted it.
--- Runs until the mission ends.
---@param current table The mission to watch
local function watchFolder(current)
    CreateThread(function()
        while mission == current do
            Wait(500)

            if mission == current and current.prop and DoesEntityExist(current.prop) then
                local ped = PlayerPedId()

                if IsPedInAnyVehicle(ped, false) then
                    SetEntityVisible(current.prop, false, false)
                    stopCarryAnimation()
                else
                    SetEntityVisible(current.prop, true, false)

                    local anim = Config.Review.Folder.Animation
                    if not IsPedRagdoll(ped) and not IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
                        startCarryAnimation()
                    end
                end
            end
        end
    end)
end

--- Ends the delivery mission, whatever stage it was at. The accountant ped stays.
local function resetMission()
    if not mission then return end

    local current = mission
    mission = nil

    stopCarryAnimation()

    if current.blip and DoesBlipExist(current.blip) then RemoveBlip(current.blip) end

    if current.prop and DoesEntityExist(current.prop) then
        DetachEntity(current.prop, true, true)
        DeleteEntity(current.prop)
    end
end

--- Hands the folder to the accountant. The server applies the result.
local function deliverFolder()
    if not mission or mission.busy then return end
    mission.busy = true

    local response = ServerRequest(SERVER .. "deliver")

    -- The server may have ended the review while the request was running
    if not mission then return end

    if not response.success then
        mission.busy = false

        if response.reason == "no_review" then resetMission() end

        return NotifyError(response.reason)
    end

    local reactions = Config.PedReactions
    if reactions and reactions.Enable and accountantPed then
        ReactPed(accountantPed, reactions.AccountantThanks, Config.Review.Accountant.Scenario, reactions.FaceDuration)
    end

    resetMission()
    _API.ShowNotification(string.format(locale("notification.review_completed"), ("%.1f"):format(response.suspicionBefore), ("%.1f"):format(response.suspicionAfter), FormatMoney(response.fee)), "success")
end

--- Spawns the accountant ped and registers its target option.
local function spawnAccountant()
    if accountantPed and DoesEntityExist(accountantPed) then return end

    local cfg = Config.Review.Accountant

    if not IsModelInCdimage(GetHashKey(cfg.Model)) then
        print(("^1[MoneyWash] Invalid accountant ped model '%s'. Check Config.Review.Accountant.Model.^7"):format(cfg.Model))
        return
    end

    local ped = SpawnStaticPed(cfg.Model, cfg.Location, cfg.Scenario)
    accountantPed = ped

    while not _Target do Wait(100) end

    if accountantPed ~= ped then return end

    _API.Target.AddLocalEntity(ped, {
        {
            name        = TARGET_NAME,
            icon        = cfg.TargetIcon,
            label       = locale("target.accountant"),
            distance    = cfg.TargetDistance,
            canInteract = function()
                return mission ~= nil and not mission.busy
            end,
            onSelect    = deliverFolder,
        },
    })
end

--- Removes the accountant ped and its target option.
local function removeAccountant()
    local ped = accountantPed
    if not ped then return end

    accountantPed = nil

    _API.Target.RemoveLocalEntity(ped, {
        names  = { TARGET_NAME },
        labels = { locale("target.accountant") },
    })
    DeletePed(ped)
end

--- The accountant is shown to every player near the office, with or without a mission.
--- A small margin on the way out stops the ped flickering at the edge.
CreateThread(function()
    local cfg = Config.Review
    if not cfg or not cfg.Enable or not cfg.Accountant.Location then return end

    local location = cfg.Accountant.Location
    local coords = vec3(location.x, location.y, location.z)
    local margin = 5.0
    local near = false

    while true do
        local range = cfg.Accountant.SpawnDistance
        local distance = #(GetEntityCoords(PlayerPedId()) - coords)
        local isNear = distance <= (near and (range + margin) or range)

        if isNear and not near then
            near = true
            CreateThread(function()
                spawnAccountant()
                if not near then removeAccountant() end
            end)
        elseif not isNear and near then
            near = false
            removeAccountant()
        end

        Wait(1000)
    end
end)

--- Starts the delivery after the stamp: folder in hand, route to the office.
---@param businessId integer
---@param result table Result of the stamp
local function startMission(businessId, result)
    local cfg = Config.Review.Accountant
    local location = cfg.Location

    mission = { businessId = businessId, result = result, prop = createFolderProp() }
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
    watchFolder(mission)

    _API.ShowNotification(locale("notification.review_prepared"), "inform")
end

--- Opens the Review Books desk for an owned business.
---@param businessId integer
function OpenBooksReview(businessId)
    local cfg = Config.Review
    if not cfg or not cfg.Enable then return NotifyError("review_disabled") end
    if not cfg.Accountant.Location then return NotifyError("no_accountant_location") end
    if not BeginMoneywashUi("review") then return end

    local response = ServerRequest(SERVER .. "open", businessId)

    if not response.success or not response.data then
        CloseMoneywashUi("review")
        return NotifyError(response.reason)
    end

    ui = { open = true, sealed = false, businessId = businessId }
    ShowMoneywashUi("review", MSG.open, response.data)
end

--- True while the player carries a sealed folder.
---@return boolean
function IsReviewMissionActive()
    return mission ~= nil
end

--- Drops the sealed folder after a confirmation. The server refunds the fee minus the penalty.
function CancelReview()
    if not ConfirmReviewCancel(Config.Review.CancelPenaltyPercent or 0) then return end

    local response = ServerRequest(SERVER .. "cancelMission")
    if not response.success then return NotifyError(response.reason) end

    resetMission()
    _API.ShowNotification(string.format(locale("notification.review_refunded"), FormatMoney(response.refund)), "inform")
end

--- NUI: the player picked receipts. The server returns the shuffled worksheet.
RegisterNUICallback(NUI.prepare, function(body, cb)
    if not ui.open or ui.sealed then return cb(ErrorResponse("no_review")) end

    local ids = type(body) == "table" and body.ids or nil

    cb(ServerRequest(SERVER .. "prepare", ui.businessId, ids))
end)

--- NUI: the stamp. The server grades the answers, takes the fee and locks the result.
RegisterNUICallback(NUI.stamp, function(body, cb)
    if not ui.open or ui.sealed then return cb(ErrorResponse("no_review")) end

    local rows = type(body) == "table" and body.rows or nil
    local response = ServerRequest(SERVER .. "stamp", rows)

    if response.success then
        ui.sealed = true
        ui.result = response.result
    end

    cb(response)
end)

--- NUI: Back or ESC before the stamp. Nothing was paid.
RegisterNUICallback(NUI.cancel, function(_, cb)
    if ui.open and not ui.sealed then ServerRequest(SERVER .. "cancel") end

    closeUi(false)
    cb({ success = true })
end)

--- NUI: the UI is done (after the filing animation). A stamped review starts the delivery.
RegisterNUICallback(NUI.close, function(_, cb)
    local wasSealed, businessId, result = ui.sealed, ui.businessId, ui.result

    if ui.open and not wasSealed then ServerRequest(SERVER .. "cancel") end

    closeUi(false)
    cb({ success = true })

    if wasSealed and result then startMission(businessId, result) end
end)

--- The server ended the review. Only a timeout, a death and an expired desk need a message here,
--- a refund is announced by the server.
RegisterNetEvent("t1ger_moneywash:client:reviewCancelled", function(reason)
    if ui.open then closeUi(true) end
    resetMission()

    local key = ({
        review_timeout      = "notification.review_cancel_timeout",
        review_died         = "notification.review_cancel_dead",
        review_desk_timeout = "notification.review_cancelled",
    })[reason]

    if key then _API.ShowNotification(locale(key), "inform") end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    resetMission()
    removeAccountant()
end)