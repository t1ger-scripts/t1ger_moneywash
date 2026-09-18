---@class PlayerReputation
---@field points integer  -- Total reputation points
---@field level string    -- Current reputation level title

reputationPoints = LocalPlayer.state["t1ger_moneywash:reputationPoints"] or 0

--- Returns the player's current reputation points.
--- @return integer points # The player's reputation points (0 if none)
function GetPlayerReputationPoints()
    return LocalPlayer.state["t1ger_moneywash:reputationPoints"] or 0
end
exports("GetPlayerReputationPoints", GetPlayerReputationPoints)

--- Get the player's reputation points and level title.
--- @return PlayerReputation
function GetPlayerReputation()
    local points = GetPlayerReputationPoints() or 0
    local currentLevel = "None"

    local levels = {}
    for pts, title in pairs(Config.Reputation.Levels) do
        table.insert(levels, { points = pts, title = title })
    end
    table.sort(levels, function(a, b) return a.points < b.points end)

    for _, level in ipairs(levels) do
        if points >= level.points then
            currentLevel = level.title
        end
    end

    return {
        points = points,
        level = currentLevel
    }
end
exports("GetPlayerReputation", GetPlayerReputation)

--- Returns the player's reputation progress data.
--- @return { points: integer, levelPoints: integer, nextPoints: integer?, title: string, progress: integer, color: string }
function GetReputationData()
    local points = GetPlayerReputationPoints() or 0
    local currentLevelPoints = 0
    local currentTitle = "Unranked"
    local nextLevelPoints = nil

    local levels = {}
    for pts, title in pairs(Config.Reputation.Levels) do
        table.insert(levels, { points = pts, title = title })
    end
    table.sort(levels, function(a, b) return a.points < b.points end)

    for _, level in ipairs(levels) do
        if points >= level.points then
            currentLevelPoints = level.points
            currentTitle = level.title
        elseif not nextLevelPoints then
            nextLevelPoints = level.points
        end
    end

    local progress = 100
    if nextLevelPoints then
        progress = math.floor(((points - currentLevelPoints) / (nextLevelPoints - currentLevelPoints)) * 100)
    end

    -- Determine color scheme based on progress
    local color = "#16a34a" -- fallback color
    for _, entry in ipairs(Config.Reputation.ProgressColors) do
        if progress >= entry.threshold then
            color = entry.color
        else
            break
        end
    end

    return {
        points = points,
        levelPoints = currentLevelPoints,
        nextPoints = nextLevelPoints,
        title = currentTitle,
        progress = progress,
        color = color
    }
end

AddStateBagChangeHandler("t1ger_moneywash:reputationPoints", nil, function(bagName, key, value)
    local expectedBag = ("player:%s"):format(GetPlayerServerId(PlayerId()))
    if bagName == expectedBag then
        reputationPoints = value
        if Config.Debug then
            print("[MoneyWash] Updated local reputation points to:", reputationPoints)
        end
    end
end)
===
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