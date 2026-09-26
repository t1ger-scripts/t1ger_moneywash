-- ============================================================================
-- STOCK DELIVERY MISSION (client)
-- ============================================================================

local StockMissionActive = false
local ActiveMissionBusinessId = nil
local GroundBoxProp = nil
local CarriedBoxProp = nil
local PickupBlip = nil

--- @return boolean
function IsStockMissionActive()
    return StockMissionActive
end

--- Spawns an object and settles it properly onto the ground/surface below
--- using the native placement helper, rather than trusting an exact Z.
--- @param model string
--- @param coords vector3|vector4
--- @return number
local function SpawnGroundObject(model, coords)
    lib.requestModel(model)
    local obj = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z, true, true, true)
    PlaceObjectOnGroundOrObjectProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(GetHashKey(model))
    return obj
end

--- @return boolean
local function IsCarryingStockBox()
    return CarriedBoxProp ~= nil
end

--- Starts a stock order: requests the mission from the server, then walks
--- the player through pickup -> load/unload -> deliver.
--- @param businessId number
--- @param units number
function StartStockMission(businessId, units)
    if StockMissionActive then
        _API.ShowNotification(locale("notification.mission_already_active"), "error")
        return
    end

    local result = lib.callback.await("t1ger_moneywash:server:orderStock", false, businessId, units)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    StockMissionActive = true
    ActiveMissionBusinessId = businessId

    _API.ShowNotification(locale("notification.stock_order_placed"), "inform")

    local pickup = result.missionData.pickupLocation
    local cfg = Config.Business.StockMission
    local blipCfg = cfg.PickupBlip

    PickupBlip = CreateMapBlip(pickup, blipCfg.Sprite, blipCfg.Display, blipCfg.Scale, blipCfg.Color, blipCfg.Label)

    if blipCfg.Route then
        SetBlipRoute(PickupBlip, true)
        SetBlipRouteColour(PickupBlip, blipCfg.RouteColor)
    end

    CreateThread(function()
        while StockMissionActive and not GroundBoxProp do
            Wait(500)

            if IsNearCoords(pickup, cfg.PickupDistance) then
                GroundBoxProp = SpawnGroundObject(cfg.PickupObject.model, pickup)
                _API.ShowNotification(locale("notification.stock_box_ready"), "inform")
                _API.Target.AddLocalEntity(GroundBoxProp, {
                    {
                        name     = "moneywash:stock:pickup",
                        icon     = "fa-solid fa-hand",
                        label    = locale("target.pickup_box"),
                        distance = cfg.PickupTargetDistance,
                        canInteract = function()
                            return StockMissionActive and not IsCarryingStockBox()
                        end,
                        onSelect = function()
                            RequestStockPickup(businessId)
                        end,
                    },
                })
            end
        end
    end)
end

--- Cancels the active mission voluntarily via command.
function CancelStockMission()
    if not StockMissionActive then return end

    local result = lib.callback.await("t1ger_moneywash:server:cancelStockMission", false)

    if not result.success then
        _API.ShowNotification(locale("notification.error_" .. (result.reason or "unknown")), "error")
        return
    end

    RemoveCarriedProp()
    if GroundBoxProp and DoesEntityExist(GroundBoxProp) then
        DeleteProp(GroundBoxProp)
    end

    GroundBoxProp = nil
    StockMissionActive = false
    ActiveMissionBusinessId = nil
    CurrentVehicleNetId = nil
    ClearWaypoint()
    lib.hideTextUI()

    _API.ShowNotification(locale("notification.stock_cancelled"), "inform")
end

RegisterCommand(Config.Business.StockMission.CancelCommand or "cancelstock", function()
    CancelStockMission()
end, false)