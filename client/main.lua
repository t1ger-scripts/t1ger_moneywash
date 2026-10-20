RegisterNetEvent("t1ger_moneywash:client:playerLoaded", function()
    -- Notify server player is ready
    TriggerServerEvent("t1ger_moneywash:server:playerLoaded")
end)