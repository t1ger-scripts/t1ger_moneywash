--- Police raid (client): asks the server to start a raid, shows the evidence screen and
--- reports back. The server owns everything that matters: the amount, the seizure and the
--- cancellation (death, distance, timeout).

---@type number|nil Amount the server reported as seized, shown when the screen closes
local seized = nil

---@type table<string, string> Locale key for each reason the server cancels a raid with
local cancelMessages = {
    timeout = "notification.raid_cancel_timeout",
    too_far = "notification.raid_cancel_too_far",
    dead    = "notification.raid_cancel_dead",
}

--- Opens the evidence screen.
---@param exposed number Exposed Safe cash at the start of the raid (> 0)
---@return boolean opened false if another screen owns the UI
local function openRaidUi(exposed)
    if not BeginMoneywashUi("raid") then return false end

    ShowMoneywashUi("raid", "t1ger_moneywash:raid:open", {
        currency   = Config.Currency,
        stackCount = Config.Police.Raid.StackCount,
        exposed    = exposed,
    })

    return true
end

--- Closes the evidence screen.
local function closeRaidUi()
    SendNUIMessage({ action = "t1ger_moneywash:raid:close" })
    CloseMoneywashUi("raid")
end

--- Starts a raid on a business. Police only; the server decides if it is allowed.
---@param businessId number
---@return boolean started
function StartRaid(businessId)
    if GetMoneywashUiScreen() then return false end

    local response = ServerRequest("t1ger_moneywash:server:raid:start", businessId)

    if not response.success then
        NotifyError(response.reason)
        return false
    end

    seized = nil

    if not openRaidUi(response.data.exposed) then
        -- Another screen took the UI in the meantime: release the business again
        ServerRequest("t1ger_moneywash:server:raid:cancel")
        return false
    end

    return true
end

--- The server called the raid off (timeout, died, moved away): close the screen and say why.
RegisterNetEvent("t1ger_moneywash:client:raidCancelled", function(reason)
    if GetMoneywashUiScreen() == "raid" then closeRaidUi() end

    seized = nil

    _API.ShowNotification(locale(cancelMessages[reason] or "notification.raid_cancelled"), "error")
end)

--- NUI: the officer bagged everything and sealed the bag. The server answers with the amount it really seized.
RegisterNUICallback("t1ger_moneywash:raid:finish", function(_, cb)
    if GetMoneywashUiScreen() ~= "raid" then
        cb(ErrorResponse("no_raid"))
        return
    end

    local response = ServerRequest("t1ger_moneywash:server:raid:finish")

    if response.success and response.data then seized = response.data.seized end

    cb(response)
end)

--- NUI: the screen closed, after finishing or because the officer pressed ESC.
RegisterNUICallback("t1ger_moneywash:raid:close", function(_, cb)
    closeRaidUi()
    cb({ success = true })

    if seized then
        _API.ShowNotification(string.format(locale("notification.raid_seized"), FormatMoney(seized)), "success")
        seized = nil
        return
    end

    -- Closed before finishing: the raid is called off
    ServerRequest("t1ger_moneywash:server:raid:cancel")
end)