_API = {Player = {}}

--- Fetch the player object from the source ID.
--- @param src number Player ID
--- @return table|nil Player object or nil if not found.
function _API.Player.GetFromId(src)
    if not src or type(src) ~= "number" then
        return error("[_API.Player.GetFromId] Invalid source provided")
    end

    if Framework == "esx" then
        return _FW[Framework].GetPlayerFromId(src)
    elseif Framework == "qbcore" then
        return _FW[Framework].Functions.GetPlayer(src)
    elseif Framework == "qbox" then
        return _FW[Framework]:GetPlayer(src)
    else
        return error(("[_API.Player.GetFromId] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Fetch the player object from the identifier.
--- @param identifier string Player identifier
--- @return table|nil Player object or nil if not found.
function _API.Player.GetFromIdentifier(identifier)
    if not identifier or type(identifier) ~= "string" then
        return error("[_API.Player.GetFromIdentifier] Invalid identifier provided")
    end

    if Framework == "esx" then
        return _FW[Framework].GetPlayerFromIdentifier(identifier)
    elseif Framework == "qbcore" then
        return _FW[Framework].Functions.GetPlayerByCitizenId(identifier)
    elseif Framework == "qbox" then
        return _FW[Framework]:GetPlayerByCitizenId(identifier)
    else
        return error(("[API.Player.GetFromIdentifier] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end

    return nil
end

--- Get player's unique identifier (license, citizen ID, or state ID)
--- @param src number Player ID
--- @return string|nil Identifier or nil if not found.
function _API.Player.GetIdentifier(src)
    local player = _API.Player.GetFromId(src)
    if not player then return nil end

    if Framework == "esx" then
        return player.identifier
    elseif Framework == "qbcore" or Framework == "qbox" then
        return player.PlayerData.citizenid
    else
        return error(("[_API.Player.GetIdentifier] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end

    return nil
end

--- Get player's ID (source) from identifier
--- @param identifier string Player ID
--- @return interger source or 0 if not found.
function _API.Player.GetSource(identifier)
    if not identifier or type(identifier) ~= "string" then
        return error("[_API.Player.GetSource] Invalid identifier provided")
    end

    if Framework == "esx" then
        local player = _API.Player.GetFromIdentifier(identifier)
        if player then 
            return player.source
        end
    elseif Framework == "qbcore" then 
        return _FW[Framework].Functions.GetSource(identifier)
    elseif Framework == "qbox" then
        local player = _API.Player.GetFromIdentifier(identifier)
        if player then
            return player.PlayerData.source
        end
    else
        return error(("[_API.Player.GetSource] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end

    return 0
end

--- Get player's full name (first + last)
--- @param src number|string Player ID or identifier
--- @return string|nil Full name or nil if not found.
function _API.Player.GetCharacterName(src)
    local player = nil
    if type(src) == "number" then
        player = _API.Player.GetFromId(src)
    elseif type(src) == "string" then
        player = _API.Player.GetFromIdentifier(src)
    else
        return error("[_API.Player.GetCharacterName] src type must be player id (number) or identifier (string)")
    end

    if not player then return nil end

    if Framework == "esx" then
        return ("%s %s"):format(player.variables.firstName, player.variables.lastName)
    elseif Framework == "qbcore" or Framework == "qbox" then
        return ("%s %s"):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
    else
        return error(("[_API.Player.GetCharacterName] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end

    return nil
end

--- Get player's job data (job name, grade, label).
--- @param src number Player ID
--- @return table|nil Job data { name, grade, label }
function _API.Player.GetJob(src)
    local player = _API.Player.GetFromId(src)
    if not player then return nil end

    if Framework == "esx" then
        return {
            name = player.job.name,
            grade = player.job.grade,
            label = player.job.label,
            onDuty = player.job.onDuty
        }
    elseif Framework == "qbcore" or Framework == "qbox" then
        return {
            name = player.PlayerData.job.name,
            grade = player.PlayerData.job.grade.level,
            label = player.PlayerData.job.label,
            onDuty = player.PlayerData.job.onduty
        }
    else
        return error(("[_API.Player.GetJob] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Set player's job and grade.
--- @param src number Player ID
--- @param jobName string Job name (e.g., 'mechanic')
--- @param grade number Job grade level
function _API.Player.SetJob(src, jobName, grade)
    local player = _API.Player.GetFromId(src)
    if not player then return end

    if Framework == "esx" then
        player.setJob(jobName, grade)
    elseif Framework == "qbcore" then
        player.Functions.SetJob(jobName, grade)
    elseif Framework == "qbox" then
        _FW[Framework]:SetJob(src, jobName, grade)
    else
        return error(("[_API.Player.SetJob] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Sets an offline player's job and grade by identifier 
--- @param identifier string The player identifier
--- @param jobName string Job name (e.g., 'mechanic')
--- @param grade integer The job grade
function _API.Player.SetJobOffline(identifier, jobName, grade)
    if type(identifier) ~= "string" or not identifier:match("%S") then return end

    if Framework == "esx" then
        MySQL.update.await("UPDATE users SET `job` = ?, `job_grade` = ? WHERE identifier = ?", {jobName, grade, identifier})
    elseif Framework == "qbcore" or Framework == "qbox" then
        local jobData = _API.GetJob(jobName)
        if not jobData then return end

        -- get grade data
        local gradeData = Framework == "qbcore" and jobData.grades[tostring(grade)] or Framework == "qbox" and jobData.grades[tonumber(grade)]
        if not gradeData then return end

        local bankAuth = nil
        if Framework == "qbox" then -- delete from player_groups on qbox
            MySQL.update.await("UPDATE player_groups SET `grade` = ? WHERE `citizenid` = ? AND `type` = ? AND `group` = ?", {tonumber(grade), identifier, "job", jobName})
            bankAuth = gradeData.bankAuth or nil
        end

        -- update player job in players table
        MySQL.update.await("UPDATE players SET `job` = ? WHERE `citizenid` = ?", {
            json.encode({
                name = jobName,
                label = jobData.label,
                onduty = true,
                payment = gradeData.payment,
                grade = {level = tonumber(grade), name = gradeData.name},
                isboss = gradeData.isboss or nil,
                bankAuth = bankAuth,
            }),
            identifier
        })
    else
        return error(("[_API.Player.SetJobOffline] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Removes a player from a job
--- @param src number Player ID
--- @param jobName string Job name (e.g., 'mechanic')
function _API.Player.RemoveFromJob(src, jobName)
    local player = _API.Player.GetFromId(src)
    if not player then return end
    
    if Framework == "qbox" then
        _FW[Framework]:RemovePlayerFromJob(player.PlayerData.citizenid, jobName)
    elseif Framework == "esx" or Framework == "qbcore" then
        _API.Player.SetJob(src, "unemployed", 0)
    else
        return error(("[_API.Player.RemoveFromJob] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Sets an offline player's job and grade by identifier 
--- @param identifier string The player identifier
--- @param jobName string Job name (e.g., 'mechanic')
function _API.Player.RemoveFromJobOffline(identifier, jobName)
    if type(identifier) ~= "string" or not identifier:match("%S") then return end

    if Framework == "esx" then
        MySQL.update.await("UPDATE users SET `job` = ?, `job_grade` = ? WHERE identifier = ?", {"unemployed", 0, identifier})
    elseif Framework == "qbcore" or Framework == "qbox" then
        local jobData = _API.GetJob("unemployed")
        if not jobData then return end

        -- get grade data
        local gradeData = Framework == "qbcore" and jobData.grades['0'] or Framework == "qbox" and jobData.grades[0]
        if not gradeData then return end

        if Framework == "qbox" then -- delete from player_groups on qbox
            MySQL.update.await("DELETE FROM player_groups WHERE citizenid = ? AND type = ? AND `group` = ?", {identifier, "job", jobName})
        end

        -- update player job in players table
        MySQL.update.await("UPDATE players SET `job` = ? WHERE citizenid = ?", {
            json.encode({
                name = "unemployed",
                label = jobData.label,
                onduty = true,
                payment = gradeData.payment,
                grade = {level = 0, name = gradeData.name}
            }),
            identifier
        })
    else
        return error(("[_API.Player.RemoveFromJobOffline] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Converts the given money account type based on the active framework.
--- @param account string|nil The requested account type (e.g., "cash", "money"). Can be nil.
--- @return string The correct money account type based on the framework.
local function ConvertMoneyType(account)
    if account and type(account) == "string" then
        if account == "cash" and Framework == "esx" then 
            return "money" -- ESX uses "money" instead of "cash"
        elseif account == "money" and (Framework == "qbcore" or Framework == "qbox") then 
            return "cash" -- QB-Core and QBOX use 'cash' instead of 'money'
        end
        return account -- If it's a valid custom account type, return as is
    else
        -- Default to framework-specific cash/money type
        if Framework == "esx" then 
            return "money"
        elseif Framework == "qbcore" or Framework == "qbox" then 
            return "cash"
        end
        return "cash" -- Default failsafe
    end
end

--- Checks if a player is an admin based on ACE permissions or their framework group.
--- @param src number The player's server ID.
--- @return boolean Returns `true` if the player has admin permissions, otherwise `false`.
function _API.Player.IsAdmin(src)
    local player = _API.Player.GetFromId(src)
    if not player then
        return error(("[_API.Player.IsAdmin] Invalid player from provided src: %s"):format(tostring(src)))
    end

    -- Check ACE permissions first
    if IsPlayerAceAllowed(src, "command") then
        return true
    end

    -- Check admin permissions based on the framework
    if Framework == "esx" then
        if player.getGroup() == "admin" or player.getGroup() == "superadmin" then
            return true
        end
    elseif Framework == "qbcore" then
        if _FW[Framework].Functions.HasPermission(src, "god") or _FW[Framework].Functions.HasPermission(src, "admin") then
            return true
        end
    elseif Framework == "qbox" then
        if _FW[Framework]:HasPermission(src, "god") or _FW[Framework]:HasPermission(src, "admin") or _FW[Framework]:HasPermission(src, "mod") then
            return true
        end
    else
        return error(("[_API.Player.IsAdmin] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end

    return false
end

--- Retrieves the player's money balance from the specified account.
--- @param src number Player's source ID.
--- @param account string|nil (Optional) The account type (e.g., 'bank', 'cash', 'crypto', 'black_money', 'money').
--- @return number Returns the player's balance or 0 if unavailable.
function _API.Player.GetMoney(src, account)
    local player = _API.Player.GetFromId(src)
    if not player then 
        return error(("[_API.Player.GetMoney] Invalid player from provided src: %s"):format(tostring(src)))
    end

    local _type = ConvertMoneyType(account)

    if Framework == "esx" then
        local acc = player.getAccount(_type)
        return acc and acc.money or 0 
    elseif Framework == "qbcore" then
        return player.Functions.GetMoney(_type) or 0
    elseif Framework == "qbox" then
        return _FW[Framework]:GetMoney(src, _type) or 0
    else
        return error(("[_API.Player.GetMoney] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end

    return 0
end

--- Adds money to the player's account.
--- @param src number Player's source ID.
--- @param amount number Amount to add.
--- @param account string|nil (Optional) The account type (e.g., 'bank', 'cash', 'crypto').
function _API.Player.AddMoney(src, amount, account)
    if not amount or type(amount) ~= "number" then return end
    local player = _API.Player.GetFromId(src)
    if not player then return end

    local _type = ConvertMoneyType(account)

    if Framework == "esx" then
        player.addAccountMoney(_type, amount)
    elseif Framework == "qbcore" then
        player.Functions.AddMoney(_type, amount)
    elseif Framework == "qbox" then
        _FW[Framework]:AddMoney(src, _type, amount)
    else
        return error(("[_API.Player.AddMoney] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Removes money from the player's account.
--- @param src number Player's source ID.
--- @param amount number Amount to remove.
--- @param account string|nil (Optional) The account type (e.g., 'bank', 'cash', 'crypto').
function _API.Player.RemoveMoney(src, amount, account)
    if not amount or type(amount) ~= "number" then return end
    local player = _API.Player.GetFromId(src)
    if not player then return end

    local _type = ConvertMoneyType(account)

    if Framework == "esx" then
        player.removeAccountMoney(_type, amount)
    elseif Framework == "qbcore" then
        player.Functions.RemoveMoney(_type, amount)
    elseif Framework == "qbox" then
        _FW[Framework]:RemoveMoney(src, _type, amount)
    else
        return error(("[_API.Player.RemoveMoney] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Sets the player's money balance for the specified account.
--- @param src integer Player's source ID.
--- @param amount number The new balance to set.
--- @param account string|nil (Optional) The account type (e.g., 'bank', 'cash', 'crypto').
function _API.Player.SetMoney(src, amount, account)
    if type(amount) ~= "number" then return end
    local player = _API.Player.GetFromId(src)
    if not player then return end

    local _type = ConvertMoneyType(account)

    if Framework == "esx" then
        player.setAccountMoney(_type, amount)
    elseif Framework == "qbcore" then
        player.Functions.SetMoney(_type, amount)
    elseif Framework == "qbox" then
        _FW[Framework]:SetMoney(src, _type, amount)
    else
        return error(("[_API.Player.SetMoney] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Function to return quantity of an item in the player data inventory
--- @param src integer Player's source ID.
--- @param item string The item to check/return quantity of
--- @return number count quantity of specified item
function _API.Player.GetItemCount(src, item)
    if type(item) ~= "string" or item == "" then
        return error("[_API.Player.GetItemCount] Invalid item type. Must be a non-empty string for the item name")
    end

    local player = _API.Player.GetFromId(src)
    if not player then return 0 end

    if Framework == "esx" then
        local itemData = player.getInventoryItem(item)
        if type(itemData) ~= "table" then return 0 end 
        return itemData.count or itemData.amount or 0
    elseif Framework == "qbcore" then
        local itemData = player.GetItemByName(item)
        if type(itemData) ~= "table" then return 0 end 
        return itemData.amount or itemData.count or 0
    elseif Framework == "qbox" then
        return exports["ox_inventory"]:Search(src, "count", item) or 0
    else
        return error(("[_API.Player.GetItemCount] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Function to checks if the player can carry a specified item and amount.
--- @param src integer Player's source ID..
--- @param item string The item name.
--- @param count number The quantity to check.
--- @return boolean canCarry `true` if the player can carry the item and count, `false` otherwise.
function _API.Player.CanCarryItem(src, item, count)
    if type(item) ~= "string" or item == "" then
        return error("[_API.Player.CanCarryItem] Invalid item type. Must be a non-empty string for the item name")
    end
    
    if type(count) ~= "number" then
        return error("[_API.Player.CanCarryItem] Invalid count type. Must be a number")
    end

    local player = _API.Player.GetFromId(src)
    if not player then return false end

    if Framework == "esx" then
        if player.canCarryItem(item, count) then 
            return true
        end
        return false
    elseif Framework == "qbcore" then
        return exports["qb-inventory"]:CanAddItem(src, item, count)
    elseif Framework == "qbox" then
        return exports["ox_inventory"]:CanCarryItem(src, item, count)
    else
        return error(("[_API.Player.CanCarryItem] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Function to add an item to the player's inventory.
--- @param src integer Player's source ID..
--- @param item string The item name.
--- @param count number The amount to add.
--- @param metadata table|nil (optional) Additional item metadata, such as custom properties.
function _API.Player.AddItem(src, item, count, metadata)
    if type(src) ~= "number" then
        return error("[_API.Player.AddItem] Invalid source type. Must be a number equivalent to player ID")
    end
    
    if type(item) ~= "string" or item == "" then
        return error("[_API.Player.AddItem] Invalid item type. Must be a non-empty string for the item name")
    end
    
    if type(count) ~= "number" then
        return error("[_API.Player.AddItem] Invalid count type. Must be a number")
    end

    local player = _API.Player.GetFromId(src)
    if not player then return false end

    if Framework == "esx" then
        player.addInventoryItem(item, count)
    elseif Framework == "qbcore" then
        player.Functions.AddItem(item, count, false, metadata or false)
        TriggerClientEvent("inventory:client:ItemBox", src, _FW[Framework].Shared.Items[item], "add", count)
    elseif Framework == "qbox" then
        exports["ox_inventory"]:AddItem(src, item, count, metadata or false)
    else
        return error(("[_API.Player.AddItem] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Function to remove an item from the player's inventory.
--- @param src integer Player's source ID..
--- @param item string The item name.
--- @param count number The amount to remove.
function _API.Player.RemoveItem(src, item, count, metadata)
    if type(src) ~= "number" then
        return error("[_API.Player.RemoveItem] Invalid source type. Must be a number equivalent to player ID")
    end
    
    if type(item) ~= "string" or item == "" then
        return error("[_API.Player.RemoveItem] Invalid item type. Must be a non-empty string for the item name")
    end
    
    if type(count) ~= "number" then
        return error("[_API.Player.RemoveItem] Invalid count type. Must be a number")
    end

    local player = _API.Player.GetFromId(src)
    if not player then return false end

    if Framework == "esx" then
        player.removeInventoryItem(item, count)
    elseif Framework == "qbcore" then
        player.Functions.RemoveItem(item, count)
        TriggerClientEvent("inventory:client:ItemBox", src, _FW[Framework].Shared.Items[item], "remove", count)
    elseif Framework == "qbox" then
        exports["ox_inventory"]:RemoveItem(src, item, count, metadata or false)
    else
        return error(("[_API.Player.RemoveItem] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Function to return item label for a specified item
--- @param item string Name of the item
--- @return table itemLabel label of the specifield item
function _API.GetItemLabel(item)
    if type(item) ~= "string" or item == "" then 
        return error("[_API.GetItemLabel] Invalid item type. Expected a non-empty string!")
    end

    if Framework == "esx" then
        local itemInfo = _FW[Framework].Items[item]
        if not itemInfo then return end
        return itemInfo.label
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

--- Checks if a job exists in the current framework.
--- @param jobName string The name of the job to check.
--- @return boolean exists True if the job exists, false otherwise.
function _API.DoesJobExist(jobName)
    if type(jobName) ~= "string" or jobName == "" then
        error("[_API.DoesJobExist] Invalid Parameter: jobName must be a non-empty string")
        return false
    end

    if Framework == "esx" then
        return _FW[Framework].DoesJobExist(jobName, 0)
    elseif Framework == "qbcore" then
        return _FW[Framework].Shared.Jobs[jobName] ~= nil
    elseif Framework == "qbox" then
        return _FW[Framework]:GetJob(jobName) ~= nil
    else
        return error(("[_API.DoesJobExist] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Function to get all jobs from the current framework.
--- @return table|nil jobs A table containing all jobs, or nil if the framework is unsupported.
function _API.GetJobs()
    if Framework == "esx" or Framework == "qbox" then
        return _FW[Framework].GetJobs() -- Returns all jobs from ESX/Qbox's built-in GetJobs() function
    elseif Framework == "qbcore" then
        return _FW[Framework].Shared.Jobs -- Returns all jobs from QBCore's job system
    else
        return error(("[_API.GetJobs] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Retrieves job data by its name from the current framework.
--- @param jobName string The name of the job to retrieve.
--- @return table|nil job A table containing job data, or nil if the job does not exist.
function _API.GetJob(jobName)
    -- Validate input
    if not jobName or type(jobName) ~= "string" then 
        return error("[_API.GetJob] Invalid job name parameter")
    end

    -- Check if the job exists
    if not _API.DoesJobExist(jobName) then
        return nil
    end

    -- Retrieve job data based on framework
    if Framework == "esx" then
        _FW[Framework].Jobs = _API.GetJobs()
        return _FW[Framework].Jobs[jobName]
    elseif Framework == "qbcore" then
        return _FW[Framework].Shared.Jobs[jobName]
    elseif Framework == "qbox" then
        return _FW[Framework]:GetJob(jobName)
    else
        return error(("[_API.GetJob] Unsupported framework detected in GetJob (Framework: %s)"):format(tostring(Framework)))
    end

    return nil -- Failsafe return in case something unexpected happens
end

--- Creates a new job in the selected framework.
--- @param jobName string The internal name (identifier) of the job.
--- @param jobLabel string The display name (label) of the job.
--- @param jobGrades table A table defining the job grades and permissions.
--- @param defaultDuty boolean|nil Whether employees start on duty by default (QBCore & Qbox only).
--- @param offDutyPay boolean|nil Whether employees receive off-duty pay (QBCore & Qbox only).
--- @return boolean Returns `true` if the job was created successfully.
function _API.CreateJob(jobName, jobLabel, jobGrades, defaultDuty, offDutyPay)
    --- Validate job name
    if type(jobName) ~= "string" or jobName == "" then
        error("[_API.CreateJob] Invalid job name!")
    end

    --- Validate job label
    if type(jobLabel) ~= "string" or jobLabel == "" then
        error("[_API.CreateJob] Invalid job label!")
    end

    --- Validate job grades
    if type(jobGrades) ~= "table" or not next(jobGrades) then
        error("[_API.CreateJob] Job grades missing or invalid!")
    end

    --- Create job based on framework
    if Framework == "esx" then
        local success = _FW[Framework].CreateJob(jobName, jobLabel, jobGrades)
        if success then 
            print(("^2[SUCCESS] _API.CreateJob: Created job for: %s (%s)!^7"):format(jobLabel, jobName))
            return true
        else
            return error(("[_API.CreateJob] Failed to create job for: %s (%s)!"):format(jobLabel, jobName))
        end
    elseif Framework == "qbcore" then
        local success, err = _FW[Framework].Functions.AddJob(jobName, {
            label = jobLabel,
            defaultDuty = defaultDuty or true,
            offDutyPay = offDutyPay or false,
            grades = jobGrades
        })
        if success then 
            print(("^2[SUCCESS] _API.CreateJob: Created job for: %s (%s)!^7"):format(jobLabel, jobName))
            return true
        else
            return error(("[_API.CreateJob] ERROR: %s for job: %s (%s)!"):format(err, jobLabel, jobName))
        end
    elseif Framework == "qbox" then
        _FW[Framework]:CreateJob(jobName, {
            label = jobLabel,
            defaultDuty = defaultDuty or true,
            offDutyPay = offDutyPay or false,
            grades = jobGrades
        })
        print(("^2[SUCCESS] _API.CreateJob: Created job for: %s (%s)!^7"):format(jobLabel, jobName))
        return true
    else
        return error(("[_API.CreateJob] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

--- Registers a useable item
--- @param item string item name
--- @param cb func callback function
function _API.RegisterUseableItem(item, cb)
    if Framework == "esx" then
        _FW[Framework].RegisterUsableItem(item, function(source)
            cb(source, item)
        end)
    elseif Framework == "qbcore" then
        _FW[Framework].Functions.CreateUseableItem(item, function(source, item)
            cb(source, item)
        end)
    elseif Framework == "qbox" then
        _FW[Framework]:CreateUseableItem(item, function(source)
            cb(source, item)
        end)
    else
        return error(("[_API.RegisterUseableItem] Unsupported framework detected (Framework: %s)"):format(tostring(Framework)))
    end
end

function _API.GetOnlinePlayers()
    local players = {}

    for _, playerId in ipairs(GetPlayers()) do
        local player = _API.Player.GetFromId(tonumber(playerId))
        if player then
            players[#players+1] = {
                source = tonumber(playerId),
                identifier = _API.Player.GetIdentifier(tonumber(playerId)),
                name = _API.Player.GetCharacterName(tonumber(playerId)),
                job = _API.Player.GetJob(tonumber(playerId))
            }
        end
    end

    return players
end


--- Get character name by identifier (offline-safe)
--- @param identifier string
--- @return string|nil
function _API.GetCharacterNameByIdentifier(identifier)
    if type(identifier) ~= "string" then
        return error("[_API.GetCharacterNameByIdentifier] identifier type must be a string")
    end

    if Framework == "esx" then
        local result = MySQL.single.await("SELECT firstname, lastname FROM users WHERE identifier = ?", { identifier })
        if result then
            return ("%s %s"):format(result.firstname, result.lastname)
        end
    elseif Framework == "qbcore" or Framework == "qbox" then
        local result = MySQL.single.await("SELECT charinfo FROM players WHERE citizenid = ?", { identifier })
        if result and result.charinfo then
            local charinfo = json.decode(result.charinfo)
            return ("%s %s"):format(charinfo.firstname, charinfo.lastname)
        end
    else
        return error(("[_API.GetCharacterNameByIdentifier] Unsupported framework (Framework: %s)"):format(tostring(Framework)))
    end

    return nil
end

-- ## CALLBACKS ## --

--- Checks to see if player is admin
lib.callback.register("t1ger_mechanic:server:isAdmin", function(source)
    local src = source
    if _API.Player.IsAdmin(src) then 
        return true 
    else
        return false 
    end
end)

-- ## EVENTS ## --

CreateThread(function()
    while Framework == nil or _FW[Framework] == nil do
        Wait(500)
    end
    if Framework == "esx" then 
        RegisterNetEvent("esx:jobCreated", function(jobName, jobData)
            if not jobName or type(jobName) ~= "string" then
                return 
            end
            if not jobData or type(jobData) ~= "table" then 
                return 
            end
            _FW[Framework].Jobs[jobName] = jobData
        end)
    elseif Framework == "qbcore" then 
        RegisterNetEvent("QBCore:Server:UpdateObject", function()
            if source ~= "" then return false end
            _FW[Framework] = exports['qb-core']:GetCoreObject()
        end)
    elseif Framework == "qbox" then
    end
end)