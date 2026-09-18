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

    -- Spawn accountant NPC
    CreateAccountantNPC()

    -- Wait for reputation statebags to populate
    while not LocalPlayer.state["t1ger_moneywash:reputationPoints"] do
        Wait(100)
    end

    if Config.Debug then
        local rep = GetReputationData()
        print(("[MoneyWash] Player loaded | %s | %d points"):format(rep.title, rep.points))
    end
end)

--- -------------------------------------------------------------------------
--- ACCOUNTANT NPC
--- -------------------------------------------------------------------------

--- Creates the Accountant NPC at the configured location
--- Uses shared SpawnStaticPed and CreateMapBlip helpers from client/functions.lua
function CreateAccountantNPC()
    if accountantNPC and DoesEntityExist(accountantNPC) then return end

    local cfg = Config.Accountant

    -- Validate model before requesting to avoid crashing on invalid hashes
    if not IsModelValid(GetHashKey(cfg.Model)) then
        if Config.Debug then
            print(("[MoneyWash] WARNING: Invalid ped model '%s' — falling back to '%s'"):format(
                model, "a_m_m_business_01"))
        end
        cfg.Model = "a_m_m_business_01"
    end

    -- Spawn ped using shared helper
    accountantNPC = SpawnStaticPed(cfg.Model, cfg.Coords, cfg.Scenario)

    -- Create blip if enabled
    if cfg.Blip and cfg.Blip.enable then
        RemoveMapBlip(accountantBlip)
        accountantBlip = CreateMapBlip(
            cfg.Coords,
            cfg.Blip.sprite,
            cfg.Blip.display,
            cfg.Blip.scale,
            cfg.Blip.color,
            cfg.Blip.name
        )
    end

    -- Wait for target system to be ready
    while not _Target do Wait(100) end

    -- Register target option
    _API.Target.AddLocalEntity(accountantNPC, {
        {
            name        = "t1ger_moneywash:accountant:ped",
            icon        = cfg.TargetIcon,
            label       = locale("target.accountant_npc"),
            distance    = 2.0,
            canInteract = CanInteractWithAccountantNPC,
            onSelect    = function()
                OpenAccountantMenu()
            end,
        },
    })

    if Config.Debug then
        print("[MoneyWash] Accountant NPC created")
    end
end