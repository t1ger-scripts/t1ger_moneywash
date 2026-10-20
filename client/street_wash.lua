--- ============================================================================
--- Street Wash Client
--- Payphone targets, the amount input, the meeting spot (blip + contact ped),
--- the handover, and the betrayal chase with the dropped bag.
--- The client never decides anything - every outcome comes from the server.
--- ============================================================================

local SERVER = "t1ger_moneywash:server:streetWash:"

local TARGET_PAYPHONE = "t1ger_moneywash:payphone"
local TARGET_CANCEL   = "t1ger_moneywash:payphone_cancel"
local TARGET_CONTACT  = "t1ger_moneywash:streetwash_contact"
local TARGET_BAG      = "t1ger_moneywash:streetwash_bag"

--- Locale keys used by this file. Rename here if your locale file differs.
local KEYS = {
    errorPrefix    = "notification.error_",
    errorUnknown   = "notification.error_unknown",
    started        = "notification.street_wash_started",         -- %d minutes
    completed      = "notification.street_wash_completed",       -- %s amount, %s cut, %s payout
    betrayedFlee   = "notification.street_wash_betrayed_flee",
    betrayedAttack = "notification.street_wash_betrayed_attack",
    recovered      = "notification.street_wash_recovered",
    lost           = "notification.street_wash_lost",
    cancelled      = "notification.street_wash_cancelled",
    timeout        = "notification.street_wash_cancel_timeout",
    dead           = "notification.street_wash_cancel_dead",
}

--- The current run, before the handover.
---@type table|nil { amount, spot, blip, point, ped, busy }
local run = nil

--- The betrayal chase, after the handover.
---@type table|nil { ped, bag, kind, dropped, busy }
local chase = nil

local starting = false


--- ---------------------------------------------------------------------------
--- HELPERS
--- ---------------------------------------------------------------------------

--- Server reasons that reuse an existing error key.
local REASON_ALIASES = {
    busy           = "business_busy",
    request_failed = "unknown",
}

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

local function removeEntityTargets(entity)
    _API.Target.RemoveLocalEntity(entity, {
        names  = { TARGET_CONTACT, TARGET_BAG },
        labels = { locale("target.street_wash_contact"), locale("target.street_wash_bag") },
    })
end

local function deleteBag(bag)
    if bag and DoesEntityExist(bag) then
        DetachEntity(bag, true, true)
        DeleteEntity(bag)
    end
end

--- Creates the money bag prop, or nil if the model is invalid.
local function createBag(x, y, z)
    local cfg = Config.StreetWash.Betrayal.Bag

    if not IsModelInCdimage(GetHashKey(cfg.Model)) then
        print(("^1[MoneyWash] Invalid street wash bag model '%s'. Check Config.StreetWash.Betrayal.Bag.Model.^7"):format(cfg.Model))
        return nil
    end

    lib.requestModel(cfg.Model)
    local bag = CreateObject(GetHashKey(cfg.Model), x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(GetHashKey(cfg.Model))

    return bag
end


--- ---------------------------------------------------------------------------
--- RUN (before the handover)
--- ---------------------------------------------------------------------------

--- Removes the run and returns its contact ped without deleting it.
local function detachRun()
    if not run then return nil end

    local ped = run.ped

    if run.point then run.point:remove() end
    if run.blip and DoesBlipExist(run.blip) then RemoveBlip(run.blip) end

    run = nil
    return ped
end

--- Removes the run and its contact.
local function resetRun()
    local ped = detachRun()

    if ped then
        removeEntityTargets(ped)
        DeletePed(ped)
    end
end

--- Lets an honest contact walk away, then removes him.
local function dismissContact(ped)
    if not ped or not DoesEntityExist(ped) then return end

    removeEntityTargets(ped)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    TaskWanderStandard(ped, 10.0, 10)

    CreateThread(function()
        Wait(8000)
        DeletePed(ped)
    end)
end


--- ---------------------------------------------------------------------------
--- CHASE (after a betrayal)
--- ---------------------------------------------------------------------------

--- Ends the chase and removes the contact and the bag.
local function cleanupChase()
    if not chase then return end

    if chase.ped and DoesEntityExist(chase.ped) then
        removeEntityTargets(chase.ped)
        DeletePed(chase.ped)
    end

    if chase.bag and DoesEntityExist(chase.bag) then
        removeEntityTargets(chase.bag)
        deleteBag(chase.bag)
    end

    chase = nil
end

--- Takes the bag back: the server returns the dirty cash.
local function claimBag()
    if not chase or chase.busy then return end
    chase.busy = true

    local response = request("claim")

    if not chase then return end

    if not response.success then
        chase.busy = false
        return notifyError(response.reason)
    end

    cleanupChase()
    _API.ShowNotification(locale(KEYS.recovered), "success")
end

--- The contact is down: drop the bag where he fell and make it targetable.
local function dropBag()
    local current = chase
    if not current or current.dropped then return end

    current.dropped = true

    local coords = GetEntityCoords(current.ped)

    deleteBag(current.bag)
    current.bag = createBag(coords.x, coords.y, coords.z)

    local target = current.ped

    if current.bag then
        PlaceObjectOnGroundProperly(current.bag)
        target = current.bag
    end

    if chase ~= current then return end

    local cfg = Config.StreetWash.Betrayal.Bag

    _API.Target.AddLocalEntity(target, {
        {
            name        = TARGET_BAG,
            icon        = cfg.TargetIcon,
            label       = locale("target.street_wash_bag"),
            distance    = cfg.TargetDistance,
            canInteract = function()
                return chase ~= nil and not chase.busy
            end,
            onSelect    = claimBag,
        },
    })
end

--- Turns the contact on the player after the handover.
local function beginChase(ped, kind)
    local cfg = Config.StreetWash.Betrayal

    chase = { ped = ped, kind = kind, dropped = false }
    local current = chase

    if not ped or not DoesEntityExist(ped) then
        -- The contact was not there (model problem): the server still holds the outcome.
        return
    end

    removeEntityTargets(ped)

    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCanRagdoll(ped, true)
    SetEntityHealth(ped, cfg.Health)
    SetPedArmour(ped, cfg.Armour)

    -- He carries the bag until he goes down.
    local pedCoords = GetEntityCoords(ped)
    local bag = createBag(pedCoords.x, pedCoords.y, pedCoords.z)

    if bag then
        local bagCfg = cfg.Bag

        AttachEntityToEntity(
            bag, ped, GetPedBoneIndex(ped, bagCfg.Bone),
            bagCfg.Pos.x, bagCfg.Pos.y, bagCfg.Pos.z,
            bagCfg.Rot.x, bagCfg.Rot.y, bagCfg.Rot.z,
            true, true, false, true, 1, true
        )
    end

    current.bag = bag

    local playerPed = PlayerPedId()

    if kind == "flee" then
        SetPedFleeAttributes(ped, 0, false)
        TaskSmartFleePed(ped, playerPed, 1000.0, -1, false, false)
    else
        local weapon = GetHashKey(cfg.Weapon)

        GiveWeaponToPed(ped, weapon, 100, false, true)
        SetCurrentPedWeapon(ped, weapon, true)
        SetPedCombatAttributes(ped, 5, true)
        SetPedCombatAttributes(ped, 46, true)
        TaskCombatPed(ped, playerPed, 0, 16)
    end

    SetPedKeepTask(ped, true)

    _API.ShowNotification(
        locale(kind == "flee" and KEYS.betrayedFlee or KEYS.betrayedAttack),
        "inform"
    )

    -- Watch him: down = drop the bag, far away = escaped.
    CreateThread(function()
        while chase == current and not current.dropped do
            Wait(300)

            if chase ~= current then break end

            if not DoesEntityExist(ped) then
                request("escaped")
                cleanupChase()
                _API.ShowNotification(locale(KEYS.lost), "error")
                break
            end

            if IsPedInjured(ped) then
                dropBag()
                break
            end

            if kind == "flee" then
                local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped))

                if distance > cfg.EscapeDistance then
                    request("escaped")
                    cleanupChase()
                    _API.ShowNotification(locale(KEYS.lost), "error")
                    break
                end
            end
        end
    end)
end


--- ---------------------------------------------------------------------------
--- HANDOVER
--- ---------------------------------------------------------------------------

local function handover()
    if not run or run.busy then return end
    run.busy = true

    local response = request("handover")

    -- The server may have ended the run while we waited.
    if not run then return end

    if not response.success then
        run.busy = false

        if response.reason == "street_wash_no_run" then
            resetRun()
        end

        return notifyError(response.reason)
    end

    local ped = detachRun()

    if response.outcome == "completed" then
        dismissContact(ped)

        _API.ShowNotification(
            formatLocale(
                KEYS.completed,
                FormatMoney(response.amount),
                FormatMoney(response.cut),
                FormatMoney(response.payout)
            ),
            "success"
        )

        return
    end

    beginChase(ped, response.kind)
end

local function spawnContact()
    if not run or run.ped then return end

    local cfg = Config.StreetWash.Contact

    if not IsModelInCdimage(GetHashKey(cfg.Model)) then
        print(("^1[MoneyWash] Invalid street wash contact model '%s'. Check Config.StreetWash.Contact.Model.^7"):format(cfg.Model))
        return
    end

    local current = run
    local ped = SpawnStaticPed(cfg.Model, current.spot, cfg.Scenario)
    current.ped = ped

    if run ~= current or current.ped ~= ped then return end

    _API.Target.AddLocalEntity(ped, {
        {
            name        = TARGET_CONTACT,
            icon        = cfg.TargetIcon,
            label       = locale("target.street_wash_contact"),
            distance    = cfg.TargetDistance,
            canInteract = function()
                return run ~= nil and not run.busy
            end,
            onSelect    = handover,
        },
    })
end

local function removeContact()
    if not run or not run.ped then return end

    removeEntityTargets(run.ped)
    DeletePed(run.ped)
    run.ped = nil
end


--- ---------------------------------------------------------------------------
--- PAYPHONE
--- ---------------------------------------------------------------------------

--- Asks the server, shows the amount input, then starts the run.
local function startRun()
    if starting or run or chase then return end
    starting = true

    local info = request("info")

    if not info.success then
        starting = false
        return notifyError(info.reason)
    end

    local input = lib.inputDialog(locale("menu.street_wash.title"), {
        {
            type        = "number",
            label       = formatLocale("menu.street_wash.amount_label", FormatMoney(info.min), FormatMoney(info.max)),
            description = formatLocale("menu.street_wash.amount_desc", info.cutPercent, FormatMoney(info.dirty)),
            min         = info.min,
            max         = info.max,
            precision   = 0,
            required    = true,
        },
    })

    if not input or not input[1] then
        starting = false
        return
    end

    local response = request("start", math.floor(tonumber(input[1]) or 0))
    starting = false

    if not response.success then
        return notifyError(response.reason)
    end

    local spot = response.spot
    local blipCfg = Config.StreetWash.Blip

    local blip = AddBlipForCoord(spot.x, spot.y, spot.z)
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

    run = {
        amount = math.floor(tonumber(input[1]) or 0),
        spot   = vector4(spot.x, spot.y, spot.z, spot.w),
        blip   = blip,
    }

    run.point = lib.points.new({
        coords   = vec3(spot.x, spot.y, spot.z),
        distance = Config.StreetWash.Contact.SpawnDistance,
        onEnter  = spawnContact,
        onExit   = removeContact,
    })

    _API.ShowNotification(formatLocale(KEYS.started, response.maxTime), "inform")
end

--- Calls the meeting off (only before the handover).
local function cancelRun()
    if not run or run.busy then return end

    local response = request("cancel")

    if not response.success then
        return notifyError(response.reason)
    end

    resetRun()
    _API.ShowNotification(locale(KEYS.cancelled), "inform")
end

CreateThread(function()
    local cfg = Config.StreetWash

    if not cfg or not cfg.Enable or type(cfg.Payphone.Models) ~= "table" or #cfg.Payphone.Models == 0 then
        return
    end

    _API.Target.AddModel(cfg.Payphone.Models, {
        {
            name        = TARGET_PAYPHONE,
            icon        = cfg.Payphone.TargetIcon,
            label       = locale("target.payphone"),
            distance    = cfg.Payphone.TargetDistance,
            canInteract = function()
                return not run and not chase and not starting
            end,
            onSelect    = startRun,
        },
        {
            name        = TARGET_CANCEL,
            icon        = "fa-solid fa-phone-slash",
            label       = locale("target.payphone_cancel"),
            distance    = cfg.Payphone.TargetDistance,
            canInteract = function()
                return run ~= nil and not run.busy
            end,
            onSelect    = cancelRun,
        },
    })
end)


--- ---------------------------------------------------------------------------
--- SERVER EVENTS + CLEANUP
--- ---------------------------------------------------------------------------

--- The server ended the run or the chase (timeout, death, cash lost).
RegisterNetEvent("t1ger_moneywash:client:streetWashEnded", function(reason)
    resetRun()
    cleanupChase()

    local key = ({
        timeout = KEYS.timeout,
        dead    = KEYS.dead,
        lost    = KEYS.lost,
    })[reason] or KEYS.cancelled

    _API.ShowNotification(locale(key), reason == "lost" and "error" or "inform")
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    resetRun()
    cleanupChase()

    local cfg = Config.StreetWash

    if cfg and cfg.Payphone and type(cfg.Payphone.Models) == "table" then
        pcall(_API.Target.RemoveModel, cfg.Payphone.Models, {
            names  = { TARGET_PAYPHONE, TARGET_CANCEL },
            labels = { locale("target.payphone"), locale("target.payphone_cancel") },
        })
    end
end)