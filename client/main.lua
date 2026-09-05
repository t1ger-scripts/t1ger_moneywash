accountantNPC, accountantBlip = nil, nil

player, coords = nil, {}
CreateThread(function()
    while true do
        player = PlayerPedId()
        coords = GetEntityCoords(player)
        Wait(500)
    end
end)

--- Event for player loaded:
RegisterNetEvent("t1ger_moneywash:client:playerLoaded", function()
    TriggerServerEvent("t1ger_moneywash:server:playerLoaded")

    CreateAccountantNPC() -- creates the accountant npc

    while not LocalPlayer.state["t1ger_moneywash:reputationPoints"] do
        Wait(100)
    end
    reputationPoints = LocalPlayer.state["t1ger_moneywash:reputationPoints"]
    local reputationTitle = LocalPlayer.state["t1ger_moneywash:reputationTitle"]

    if Config.Debug then
        print("Player Loaded:", json.encode(_API.Player:GetJob(), {indent = true}))
        print("Reputation Points:", reputationPoints)
        print("Reputation Title:", reputationTitle)
    end
end)

--- Creates the "Accountant" NPC
function CreateAccountantNPC()
    if accountantNPC and DoesEntityExist(accountantNPC) then return end

    local cfg = Config.Accountant

    -- request model and create ped
    lib.requestModel(cfg.Model)
    accountantNPC = CreatePed(6, cfg.Model, cfg.Coords.x, cfg.Coords.y, cfg.Coords.z - 1.0, cfg.Coords.w, false, true)

    -- ped settings
    SetEntityAsMissionEntity(accountantNPC, true, true)
    SetEntityInvincible(accountantNPC, true)
    SetBlockingOfNonTemporaryEvents(accountantNPC, true)
    FreezeEntityPosition(accountantNPC, true)

    -- start scenario if enabled
    if cfg.Scenario then
        TaskStartScenarioInPlace(accountantNPC, cfg.Scenario, 0, true)
    end

    -- create blip if enabled
    if cfg.Blip and cfg.Blip.enable then
        if accountantBlip and DoesBlipExist(accountantBlip) then
            RemoveBlip(accountantBlip)
        end
        accountantBlip = CreateMapBlip(cfg.Coords, cfg.Blip.sprite, cfg.Blip.display, cfg.Blip.scale, cfg.Blip.color, cfg.Blip.name)
    end

    -- create target interact
    while not _Target do Wait(100) end -- wait for target to initialize
    _API.Target.AddLocalEntity(accountantNPC, {
        {
            name = "t1ger_moneywash:accountant:ped",
            icon = Config.Accountant.TargetIcon,
            label = locale("target.accountant_npc"),
            canInteract = CanInteractWithAccountantNPC,
            distance = 2.0,
            onSelect = function(entity)
                OpenAccountantMenu()
            end
        }
    })
end