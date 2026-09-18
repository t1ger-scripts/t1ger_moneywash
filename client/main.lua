--- ============================================================================
--- Client Main
--- Player lifecycle, Accountant NPC creation and global client state.
--- ============================================================================

--- Accountant NPC and blip handles
local accountantNPC  = nil
local accountantBlip = nil

--- -------------------------------------------------------------------------
--- PLAYER LIFECYCLE
--- -------------------------------------------------------------------------

RegisterNetEvent("t1ger_moneywash:client:playerLoaded", function()
    -- Notify server player is ready
    TriggerServerEvent("t1ger_moneywash:server:playerLoaded")

    -- Wait for reputation statebags to populate
    while not LocalPlayer.state["t1ger_moneywash:reputationPoints"] do
        Wait(100)
    end

    if Config.Debug then
        local rep = GetReputationData()
        print(("[MoneyWash] Player loaded | %s | %d points"):format(rep.title, rep.points))
    end
end)
