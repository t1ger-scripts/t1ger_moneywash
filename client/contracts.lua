--- Launder contracts (client): the payphone target and the start of a contract.
--- The server owns every contract, this file only asks and shows.

local SERVER = "t1ger_moneywash:server:contracts:"

---@type string|nil Id of the contract the player is working, nil when off shift
local activeContractId = nil

---@param contractId string
---@return table|nil contract Entry of Config.Contracts.List
local function getContract(contractId)
    for _, contract in ipairs(Config.Contracts.List) do
        if contract.Id == contractId then return contract end
    end
end

--- True while the player is on a shift.
---@return boolean
function IsContractShiftActive()
    return activeContractId ~= nil
end

--- Asks the server to start a shift.
---@param contractId string Id from Config.Contracts.List
function StartContractShift(contractId)
    local response = ServerRequest(SERVER .. "startShift", contractId)

    if not response.success then
        if response.reason == "contract_cooldown" then
            return _API.ShowNotification(string.format(locale("notification.contract_cooldown"), response.remaining or 0), "error")
        end

        return NotifyError(response.reason)
    end

    activeContractId = contractId
    _API.ShowNotification(locale("notification.contract_started"), "success")
end

--- Ends the shift after a confirmation. Used by the payphone menu and the end command.
function EndContractShift()
    local contract = activeContractId and getContract(activeContractId)
    if not contract then return NotifyError("no_contract_shift") end
    if not ConfirmEndShift(contract.Cooldown) then return end

    local response = ServerRequest(SERVER .. "endShift")

    if not response.success then
        if response.reason == "no_contract_shift" then activeContractId = nil end

        return NotifyError(response.reason)
    end

    activeContractId = nil
    _API.ShowNotification(string.format(locale("notification.contract_ended"), response.cooldown or 0), "inform")
end

--- The server ended the shift without the player asking.
RegisterNetEvent("t1ger_moneywash:client:contractShiftEnded", function(reason)
    activeContractId = nil

    if reason == "died" then _API.ShowNotification(locale("notification.contract_ended_died"), "inform") end
end)

if Config.Contracts.EndCommand then
    RegisterCommand(Config.Contracts.EndCommand, EndContractShift, false)
end

CreateThread(function()
    while not _Target do Wait(100) end

    _API.Target.AddModel(Config.Contracts.Models, {
        {
            name        = "t1ger_moneywash:payphone",
            icon        = Config.Contracts.Target.Icon,
            label       = locale("target.payphone"),
            distance    = Config.Contracts.Target.Distance,
            canInteract = function()
                return not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect    = function()
                OpenContractsMenu()
            end,
        },
    })
end)
