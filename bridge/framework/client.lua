_API = {}

-- Player Class: Handles all player-related functions dynamically across frameworks.
Player = {}
Player.__index = Player
PlayerLoaded = false

function _API.GetPlayerData()
    if Framework == "esx" or Framework == "qbox" then
        return _FW[Framework]:GetPlayerData()
    elseif Framework == "qbcore" then
        return _FW[Framework].Functions.GetPlayerData()
    end
end

--- Function to return item label for a specified item
---@param item string Name of the item
---@return table itemLabel label of the specifield item
function _API.GetItemLabel(item)
    if type(item) ~= "string" or item == "" then 
        return error("[_API.GetItemLabel] Invalid item type. Expected a non-empty string!")
    end

    if Framework == "esx" then
        local inventory = Player:GetInventory() -- ESX does not have a way to check items on clients, so checking user inventory
        if not inventory or not inventory[item] then return end
        return inventory[item].label
    elseif Framework == "qbox" then
        local itemInfo = exports["ox_inventory"]:Items(item)
        if not itemInfo then return end
        return itemInfo.label
    elseif Framework == "qbcore" then
        local itemInfo = _FW[Framework].Shared.Items[item]
        if not itemInfo then return end
        return itemInfo.label
    end
end

--- Function to get player inventory & check for specified amount of item
---@param item string Name of the item
---@param count number Amount to check for
---@return boolean hasItem `true` if has specified amount of item. `false` otherwise
function _API.HasItem(item, count)
    if type(item) ~= "string" or item == "" then 
        return error("[API.HasItem] Invalid item type. Expected a non-empty string!")
    end

    if type(count) ~= "number" then 
        return error("[API.HasItem] Invalid count type. Expected a number!")
    end

    local inventory = Player:GetInventory()
    if not inventory[item] then return false end 
    return inventory[item].count >= count
end

--- Constructor: Initializes a Player object
function Player.new()
    local self = setmetatable({}, Player)
    self.data = {}       -- Stores full player data from the framework
    self.job = {}        -- Stores a standardized job table
    self.charId = nil    -- Stores character ID (citizenid, steam ID, etc.)
    self.charName = ""   -- Stores player character name
    self.isAdmin = false -- Stores whether player is admin or not
    return self
end

--- Function to fetch player data dynamically
function Player:GetPlayerData()
    while Framework == nil or _FW[Framework] == nil do 
        Wait(10)
    end
    while not _API.GetPlayerData() or not _API.GetPlayerData().job do 
        Wait(10)
    end
    self.data = _API.GetPlayerData()
    self.isAdmin = lib.callback.await("t1ger_moneywash:server:isAdmin", false)
    -- Update player properties
    self:UpdatePlayerData(self.data)
end

--- Function to standardize and update player data across all frameworks
function Player:UpdatePlayerData(data)
    if not data then return end

    self.data = data

    if Framework == "esx" then
        self.charId = data.identifier
        self.charName = ('%s %s'):format(data.firstName, data.lastName)
    elseif Framework == "qbcore" or Framework == "qbox" then
        self.charId = data.citizenid
        self.charName = ('%s %s'):format(data.charinfo.firstname, data.charinfo.lastname)
    end

    -- Standardize Job Data
    self:UpdateJob(data.job or {})
end

--- Function to update job data into a standardized format
function Player:UpdateJob(jobData, lastJob)
    -- Extract job information
    local grade, gradeLabel, onDuty = 0, "None", nil

    if Framework == "esx" then
        grade = tonumber(jobData.grade)
        gradeLabel = jobData.grade_label
        onDuty = jobData.onDuty or nil
    elseif Framework == "qbcore" or Framework == "qbox" then
        grade = tonumber(jobData.grade.level)
        gradeLabel = jobData.grade.name
        onDuty = jobData.onduty
    end

    -- Store standardized job data
    self.job = {
        name = jobData.name,
        label = jobData.label,
        grade = grade,
        gradeLabel = gradeLabel,
        onDuty = onDuty
    }
end

--- Function to get the player's job
function Player:GetJob()
    return self.job
end

-- Function to get the player's inventory/items
function Player:GetInventory()
    local playerData = _API.GetPlayerData()
    while not playerData.job do Wait(10) end 

    local items, inventory = {}, {}

    if Framework == "esx" then
        items = playerData.inventory
    elseif Framework == "qbox" or Framework == "qbcore" then 
        items = playerData.items
    end

    for _,itemData in pairs(items) do
        inventory[itemData.name] = {
            name = itemData.name, 
            label = itemData.label, 
            count = itemData.amount or itemData.count or 0,
            info = itemData.info or itemData.metadata or false
        }
    end

    self.inventory = inventory

    return inventory
end

-- Initialize Player Class Instance
_API.Player = Player.new()

--- Function called when a player fully loads into the game
local function OnPlayerLoaded()
    _API.Player:GetPlayerData() -- Fetch updated player data
    if _API.Player.data and next(_API.Player.data) then
        PlayerLoaded = true
        TriggerEvent("t1ger_moneywash:client:playerLoaded")
    else
        error("[OnPlayerLoaded] Player data failed to load!")
    end
end

--- Function called when a player logs out/unloads
local function OnPlayerUnload()
    PlayerLoaded = false
    _API.Player = Player.new() -- Reset player object
end

--- Function called when a player’s job is updated
---@param job table Job information from framework
local function OnJobUpdate(job, lastJob)
    _API.Player:UpdateJob(job, lastJob)

    -- Wait
    Wait(1000)

    -- Trigger job update event
    TriggerEvent('t1ger_moneywash:client:onJobUpdate', _API.Player:GetJob())
end

--- Function called when a framework updates the player’s data
---@param data table Updated player data from framework
local function OnPlayerDataUpdate(data)
    if not data or next(data) == nil then 
        _API.Player:GetPlayerData()
    else
        _API.Player:UpdatePlayerData(data)
    end
end

--- Function to handle resource restarts (checks if player is already loaded)
local function OnResourceStart(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    while Framework == nil or _FW[Framework] == nil do 
        Wait(500)
    end
    Wait(1000) -- Allow time for framework to initialize
    _API.Player:GetPlayerData()
    if _API.Player.data and next(_API.Player.data) then
        PlayerLoaded = true
        TriggerEvent("t1ger_moneywash:client:playerLoaded")
    else
        error("[OnResourceStart] Player data failed to load!")
    end
end

-- ## EVENTS ## --

RegisterNetEvent("esx:playerLoaded", function(xPlayer)
    OnPlayerLoaded()
end)

RegisterNetEvent("esx:onPlayerLogout", function()
    OnPlayerUnload()
end)

RegisterNetEvent("esx:setJob", function(job, lastJob)
    OnJobUpdate(job, lastJob)
end)

RegisterNetEvent("esx:setPlayerData", function(key, value)
    if _API.Player.data and key then
        _API.Player.data[key] = value
        _API.Player:UpdatePlayerData(_API.Player.data)
    else
        OnPlayerDataUpdate()
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    OnPlayerLoaded()
end)

RegisterNetEvent("qbx_core:client:playerLoggedOut", function()
    OnPlayerUnload()
end)

RegisterNetEvent("QBCore:Client:OnJobUpdate", function(job)
    OnJobUpdate(job)
end)

RegisterNetEvent("QBCore:Player:SetPlayerData", function(val)
    OnPlayerDataUpdate(val)
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    OnPlayerUnload()
end)

RegisterNetEvent("QBCore:Client:UpdateObject", function()
    _FW[Framework] = exports["qb-core"]:GetCoreObject()
end)

--- event handler on resource start:
AddEventHandler("onResourceStart", function(resourceName)
    OnResourceStart(resourceName)
end)
