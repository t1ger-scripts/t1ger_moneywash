_API.JobAccount = {}

--- Retrieves the shared job account for a given job.
--- @param jobName string The name of the job whose account is being retrieved.
--- @return table|nil account The job account object, or nil if not found.
function _API.JobAccount.Get(jobName)
    --- Validate job existence before retrieving an account
    local job = _API.GetJob(jobName)
    if not job then
        error(("[_API.JobAccount.Get] ERROR: Job '%s' not found"):format(jobName))
    end

    --- Retrieve the job account based on the configured banking system
    if _JobAccount == "esx_addonaccount" then
        return exports["esx_addonaccount"]:GetSharedAccount("society_"..jobName)
    elseif _JobAccount == "qb-banking" then
        return exports["qb-banking"]:GetAccount(jobName)
    elseif _JobAccount == "qb-management" then
        return exports["qb-management"]:GetAccount(jobName)
    elseif _JobAccount == "Renewed-Banking" then
        return exports["Renewed-Banking"]:GetJobAccount(jobName)
    elseif _JobAccount == "tgg-banking" then
        return exports["tgg-banking"]:GetSocietyAccount(jobName)
    elseif _JobAccount == "okokBanking" then
        return exports["okokBanking"]:GetAccount(jobName)
    elseif _JobAccount == "wasabi_banking" then
        return exports["wasabi_banking"]:GetAccount(jobName)
    elseif _JobAccount == "fd_banking" then
        return exports["fd_banking"]:GetAccount(jobName)
    elseif _JobAccount == "crm-banking" then
        return exports["crm-banking"]:crm_get_money(jobName)
    elseif _JobAccount == "snipe-banking" then
        return exports["snipe-banking"]:GetAccountBalance(jobName)
    elseif _JobAccount == "RxBanking" then
        return exports["RxBanking"]:GetSocietyAccount(jobName)
    elseif _JobAccount == "custom" then
        --- Custom banking system support (to be implemented)
        return nil
    else
        error(("[_API.JobAccount.Get] ERROR: Unsupported JobAccount configuration '%s'"):format(_JobAccount))
    end
end

--- Retrieves the balance of a shared job account.
---@param jobName string The name of the job whose balance is being retrieved.
---@return number balance The current balance of the job account, or throws an error if unavailable.
function _API.JobAccount.GetBalance(jobName)
    --- Retrieve the job account based on job name
    local account = _API.JobAccount.Get(jobName)
    if not account then
        error(("[_API.JobAccount.GetBalance] ERROR: Account not found for job: '%s'"):format(jobName))
    end

    --- Return the account money based on the banking system
    if _JobAccount == "esx_addonaccount" then
        return account.money or 0
    elseif _JobAccount == "qb-banking" then
        return account.account_balance or 0
    elseif _JobAccount == "qb-management" then
        return account -- qb-management stores the amount directly
    elseif _JobAccount == "Renewed-Banking" then
        return account.amount or 0
    elseif _JobAccount == "tgg-banking" then
        return account.balance or 0
    elseif _JobAccount == "okokBanking" then
        return account -- okokBanking returns amount directly
    elseif _JobAccount == "wasabi_banking" then
        return exports["wasabi_banking"]:GetAccountBalance(jobName) or 0
    elseif _JobAccount == "fd_banking" then
        return account -- fd_banking stores the amount directly
    elseif _JobAccount == "crm-banking" then
        return account -- crm-banking stores the amount directly
    elseif _JobAccount == "snipe-banking" then
        return account -- snipe-banking stores the amount directly
    elseif _JobAccount == "RxBanking" then
        return account.balance or 0
    elseif _JobAccount == "custom" then
        --- Custom banking system support (to be implemented)
        return 0
    else
        error(("[_API.JobAccount.GetBalance] ERROR: Unsupported JobAccount configuration '%s'"):format(_JobAccount))
    end
end

--- Adds money to a shared job account.
---@param jobName string The name of the job whose account will receive money.
---@param amount number The amount of money to add.
function _API.JobAccount.AddMoney(jobName, amount)
    --- Retrieve the job account based on job name
    local account = _API.JobAccount.Get(jobName)
    if not account then
        error(("[_API.JobAccount.AddMoney] ERROR: Account not found for job: '%s'"):format(jobName))
    end

    --- Ensure amount is a valid number
    if type(amount) ~= "number" then 
        error("[_API.JobAccount.AddMoney] ERROR: Amount must be a number")
    end

    --- Ensure amount is positive
    if amount <= 0 then
        error("[_API.JobAccount.AddMoney] ERROR: Amount must be greater than zero")
    end

    --- Add money based on the job account system
    if _JobAccount == "esx_addonaccount" then
        TriggerEvent("esx_addonaccount:getSharedAccount", "society_"..jobName, function(account)
            if account then
                account.addMoney(amount)
            else
                error(("[_API.JobAccount.AddMoney] ERROR: Failed to retrieve ESX shared account for job: '%s'"):format(jobName))
            end
        end)
    elseif _JobAccount == "qb-banking" or _JobAccount == "qb-management" then
        exports[_JobAccount]:AddMoney(jobName, amount)
    elseif _JobAccount == "Renewed-Banking" then
        exports["Renewed-Banking"]:addAccountMoney(jobName, amount)
    elseif _JobAccount == "tgg-banking" then
        exports["tgg-banking"]:AddSocietyMoney(jobName, amount)
    elseif _JobAccount == "okokBanking" then
        exports["okokBanking"]:AddMoney(jobName, amount)
    elseif _JobAccount == "wasabi_banking" then
        exports["wasabi_banking"]:AddMoney(jobName, amount)
    elseif _JobAccount == "fd_banking" then
        exports["fd_banking"]:AddMoney(jobName, amount)
    elseif _JobAccount == "crm-banking" then
        exports["crm-banking"]:crm_add_money(jobName, amount)
    elseif _JobAccount == "snipe-banking" then
        return exports["snipe-banking"]:AddMoneyToAccount(jobName, amount)
    elseif _JobAccount == "RxBanking" then
        return exports["RxBanking"]:AddSocietyMoney(jobName, amount)
    elseif _JobAccount == "custom" then
        --- Custom implementation (to be implemented)
        return
    else
        error(("[_API.JobAccount.AddMoney] ERROR: Unsupported JobAccount configuration '%s'"):format(_JobAccount))
    end
end

--- Removes money from a shared job account.
---@param jobName string The name of the job whose account will be debited.
---@param amount number The amount of money to remove.
function _API.JobAccount.RemoveMoney(jobName, amount)
    --- Retrieve the job account based on job name
    local account = _API.JobAccount.Get(jobName)
    if not account then
        error(("[_API.JobAccount.RemoveMoney] ERROR: Account not found for job: '%s'"):format(jobName))
    end

    --- Ensure amount is a valid number
    if type(amount) ~= "number" then 
        error("[_API.JobAccount.RemoveMoney] ERROR: Amount must be a number")
    end

    --- Ensure amount is positive
    if amount <= 0 then
        error("[_API.JobAccount.RemoveMoney] ERROR: Amount must be greater than zero")
    end

    if _JobAccount == "esx_addonaccount" then
        TriggerEvent("esx_addonaccount:getSharedAccount", "society_"..jobName, function(account)
            if account then
                account.removeMoney(amount)
            else
                error(("[_API.JobAccount.RemoveMoney] ERROR: Failed to retrieve ESX shared account for job: '%s'"):format(jobName))
            end
        end)
    elseif _JobAccount == "qb-banking" or _JobAccount == "qb-management" then
        exports[tostring(_JobAccount)]:RemoveMoney(jobName, amount)
    elseif _JobAccount == "Renewed-Banking" then
        exports["Renewed-Banking"]:removeAccountMoney(jobName, amount)
    elseif _JobAccount == "tgg-banking" then
        exports["tgg-banking"]:RemoveSocietyMoney(jobName, amount)
    elseif _JobAccount == "okokBanking" then
        exports["okokBanking"]:RemoveMoney(jobName, amount)
    elseif _JobAccount == "wasabi_banking" then
        exports["wasabi_banking"]:RemoveMoney(jobName, amount)
    elseif _JobAccount == "fd_banking" then
        exports["fd_banking"]:RemoveMoney(jobName, amount)
    elseif _JobAccount == "crm-banking" then
        exports["crm-banking"]:crm_remove_money(jobName, amount)
    elseif _JobAccount == "snipe-banking" then
        return exports["snipe-banking"]:RemoveMoneyFromAccount(jobName, amount)
    elseif _JobAccount == "RxBanking" then
        return exports["RxBanking"]:RemoveSocietyMoney(jobName, amount)
    elseif _JobAccount == "custom" then
        --- Custom implementation (to be implemented)
        return
    else
        error(("[_API.JobAccount.RemoveMoney] ERROR: Unsupported JobAccount configuration '%s'"):format(_JobAccount))
    end
end

--- Sets a specific balance for a shared job account.
---@param jobName string The name of the job whose account balance will be set.
---@param amount number The new balance to be set for the job account.
function _API.JobAccount.SetMoney(jobName, amount)
    --- Retrieve the job account based on job name
    local account = _API.JobAccount.Get(jobName)
    if not account then
        error(("[_API.JobAccount.SetMoney] ERROR: Account not found for job: '%s'"):format(jobName))
    end

    --- Ensure amount is a valid number
    if type(amount) ~= "number" then 
        error("[_API.JobAccount.SetMoney] ERROR: Amount must be a number")
    end

    --- Ensure amount is not negative (allowing zero)
    if amount < 0 then
        error("[_API.JobAccount.SetMoney] ERROR: Amount cannot be negative")
    end

    if _JobAccount == "esx_addonaccount" then
        TriggerEvent("esx_addonaccount:getSharedAccount", "society_"..jobName, function(account)
            if account then
                account.setMoney(amount)
            else
                error(("[_API.JobAccount.SetMoney] ERROR: Failed to retrieve ESX shared account for job: '%s'"):format(jobName))
            end
        end)
    elseif _JobAccount == "qb-banking" or _JobAccount == "qb-management" or _JobAccount == "Renewed-Banking" or _JobAccount == "tgg-banking" or _JobAccount == "okokBanking" or _JobAccount == "wasabi_banking" or _JobAccount == "snipe-banking" or _JobAccount == "RxBanking" then
        local balance = _API.JobAccount.GetBalance(jobName)
        --- Remove current balance only if necessary
        if balance > 0 then
            _API.JobAccount.RemoveMoney(jobName, math.max(balance, 0))
            Wait(100)
        end
        _API.JobAccount.AddMoney(jobName, amount)
    elseif _JobAccount == "crm-banking" then
        exports["crm-banking"]:crm_set_money(jobName, amount)
    elseif _JobAccount == "custom" then
        --- Custom implementation (to be implemented)
        return
    else
        error(("[_API.JobAccount.SetMoney] ERROR: Unsupported JobAccount configuration '%s'"):format(_JobAccount))
    end
end

--- Creates a new shared job account with a starting balance.
--- @param jobName string The name of the job/society for which the account will be created.
--- @param startBalance number The initial balance of the newly created job account.
--- @return boolean Returns `true` if the account was created successfully, `false` otherwise.
function _API.JobAccount.Create(jobName, startBalance)
    --- Check if the account already exists
    if _API.JobAccount.Get(jobName) then 
        return true
    end

    --- Validate job existence before creating an account
    local job = _API.GetJob(jobName)
    if not job then
        error(("[_API.JobAccount.Create] ERROR: Job '%s' not found"):format(jobName))
    end

    local success = false

    --- Create the account based on the selected job account system
    if _JobAccount == "esx_addonaccount" then
        success = exports["esx_addonaccount"]:AddSharedAccount({name = "society_"..job.name, label = job.label}, startBalance)
    elseif _JobAccount == "qb-banking" then
        success = exports["qb-banking"]:CreateJobAccount(jobName, startBalance)
    elseif _JobAccount == "qb-management" then
        success = exports["qb-management"]:CreateManagementAccount(jobName, startBalance)
    elseif _JobAccount == "Renewed-Banking" then
        success = exports["Renewed-Banking"]:CreateJobAccount({name = jobName, label = job.label}, startBalance)
    elseif _JobAccount == "tgg-banking" then
        success = exports["tgg-banking"]:CreateBusinessAccount(jobName, startBalance, job.label)
    elseif _JobAccount == "okokBanking" then
        TriggerEvent("okokBanking:CreateSocietyAccount", jobName, job.label, startBalance, "OK"..jobName)
    elseif _JobAccount == "wasabi_banking" then
        error("[_API.JobAccount.Create] wasabi_banking does not support runtime account creation. You must use an existing job when creating shop!")
    elseif _JobAccount == "fd_banking" then
        error("[_API.JobAccount.Create] fd_banking does not support runtime account creation. You must use an existing job when creating shop!")
    elseif _JobAccount == "crm-banking" then
        exports["crm-banking"]:crm_create_society(jobName, job.label, startBalance)
        success = true
    elseif _JobAccount == "snipe-banking" then
        return exports["snipe-banking"]:CreateJobGangAccount(jobName, job.label, startBalance, true)
    elseif _JobAccount == "RxBanking" then
        error("[_API.JobAccount.Create] RxBanking does not support runtime account creation. You must use an existing job when creating shop!")
    elseif _JobAccount == "custom" then
        --- Placeholder for custom implementation
        return false
    else
        error(("[_API.JobAccount.Create] ERROR: Unsupported job account system '%s'"):format(_JobAccount))
    end

    --- Return whether the account creation was successful
    return success and true or false
end