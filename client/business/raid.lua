-- Police raid, client side.
-- StartRaid asks the server to start a raid, then opens the evidence UI.
-- The server owns everything that matters: the amounts, the seizure and the
-- cancellation (death, distance, timeout).

local seized = nil -- amount the server reported as seized; shown once the UI closes

--- Opens the raid UI.
---@param exposed number Exposed Safe cash at the start of the raid (> 0)
---@return boolean opened
local function OpenRaidUi(exposed)
    if not BeginMoneywashUi("raid") then return false end

    ShowMoneywashUi("raid", "t1ger_moneywash:raid:open", {
        currency   = Config.Currency,
        stackCount = Config.Police.Raid.StackCount,
        exposed    = exposed,
    })

    return true
end

--- Starts a raid on a business. Police only; the server decides if it is allowed.
---@param businessId number
---@return boolean started
function StartRaid(businessId)
    if GetMoneywashUiScreen() then return false end

    local response = lib.callback.await("t1ger_moneywash:server:raid:start", false, businessId)

    if not response or not response.success then
        NotifyError(response and response.reason)
        return false
    end

    seized = nil

    if not OpenRaidUi(response.data.exposed) then
        -- The UI was taken by something else in the meantime: release the business again.
        lib.callback.await("t1ger_moneywash:server:raid:cancel", false)
        return false
    end

    return true
end

--- The server called the raid off (timeout, died, moved away): close the UI and say why.
RegisterNetEvent("t1ger_moneywash:client:raidCancelled", function(reason)
    if GetMoneywashUiScreen() == "raid" then
        SendNUIMessage({ action = "t1ger_moneywash:raid:close" })
        CloseMoneywashUi("raid")
    end

    seized = nil

    local key = "notification.raid_cancel_" .. tostring(reason)
    local text = locale(key)
    if text == key then text = locale("notification.raid_cancelled") end

    _API.ShowNotification(text, "error", {})
end)

--- NUI: the officer bagged everything and sealed the bag.
--- The server answers with the amount it really seized.
RegisterNUICallback("t1ger_moneywash:raid:finish", function(_, cb)
    if GetMoneywashUiScreen() ~= "raid" then
        cb(ErrorResponse("no_raid"))
        return
    end

    local ok, response = pcall(lib.callback.await, "t1ger_moneywash:server:raid:finish", false)

    if not ok or type(response) ~= "table" then
        response = ErrorResponse("request_failed")
    elseif response.success and response.data then
        seized = response.data.seized
    elseif not response.success then
        response.message = GetErrorMessage(response.reason)
    end

    cb(response)
end)

--- NUI: the screen closed - after finishing, or because the officer pressed ESC.
RegisterNUICallback("t1ger_moneywash:raid:close", function(_, cb)
    SendNUIMessage({ action = "t1ger_moneywash:raid:close" })
    CloseMoneywashUi("raid")
    cb({ success = true })

    if seized then
        _API.ShowNotification(
            string.format(locale("notification.raid_seized"), FormatMoney(seized)), "success", {})
        seized = nil
    else
        -- Closed before finishing: the raid is called off.
        lib.callback.await("t1ger_moneywash:server:raid:cancel", false)
    end
end)