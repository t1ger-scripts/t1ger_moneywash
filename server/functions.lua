--- Returns the number of currently on-duty players whose job matches Config.PoliceJobs.
--- @return integer count
function GetOnDutyPoliceCount()
    local count = 0
    local players = _API.GetOnlinePlayers()

    for _, playerData in ipairs(players) do
        local job = playerData.job
        if job and job.onDuty then
            for _, policeJob in ipairs(Config.PoliceJobs) do
                if job.name == policeJob then
                    count = count + 1
                    break
                end
            end
        end
    end

    return count
end

--- Checks whether the given player's coordinates are within range of a target vector.
--- @param src number Player source
--- @param target vector3|vector4 Target coordinates
--- @param maxDistance number Maximum allowed distance
--- @return boolean withinRange
function IsPlayerNearCoords(src, target, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    local dist = #(playerCoords - vector3(target.x, target.y, target.z))

    return dist <= (maxDistance or 5.0)
end

-- ## DIRTY MONEY ABSTRACTION ## --
-- Supports both account-based dirty money (e.g. 'black_money') and item-based (stacked or metadata),
-- driven entirely by Config.DirtyMoney so servers don't need to touch any logic files.

--- Returns the player's current dirty money balance.
--- @param src number
--- @return number amount
function GetDirtyMoney(src)
    if Config.DirtyMoney.useItem then
        return _API.Inventory.GetItemCount(src, Config.DirtyMoney.item.name) or 0
    else
        return _API.Player.GetMoney(src, Config.DirtyMoney.account) or 0
    end
end

--- Checks whether the player holds at least the given amount of dirty money.
--- @param src number
--- @param amount number
--- @return boolean hasEnough
function HasDirtyMoney(src, amount)
    if type(amount) ~= "number" or amount <= 0 then return false end
    return GetDirtyMoney(src) >= amount
end

--- Removes the given amount of dirty money from the player.
--- @param src number
--- @param amount number
--- @return boolean success
function RemoveDirtyMoney(src, amount)
    if type(amount) ~= "number" or amount <= 0 then return false end
    if not HasDirtyMoney(src, amount) then return false end

    if Config.DirtyMoney.useItem then
        _API.Inventory.RemoveItem(src, Config.DirtyMoney.item.name, amount)
    else
        _API.Player.RemoveMoney(src, amount, Config.DirtyMoney.account)
    end

    return true
end

--- Adds the given amount of dirty money to the player.
--- @param src number
--- @param amount number
--- @return boolean success
function AddDirtyMoney(src, amount)
    if type(amount) ~= "number" or amount <= 0 then return false end

    if Config.DirtyMoney.useItem then
        local metadata = nil
        if Config.DirtyMoney.item.metadata and type(Config.DirtyMoney.item.metadataTemplate) == "function" then
            metadata = Config.DirtyMoney.item.metadataTemplate(amount)
        end
        _API.Inventory.AddItem(src, Config.DirtyMoney.item.name, amount, metadata)
    else
        _API.Player.AddMoney(src, amount, Config.DirtyMoney.account)
    end

    return true
end