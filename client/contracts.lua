--- Launder contracts (client): the payphone target and the start of a contract.
--- The server owns every contract, this file only asks and shows.

--- Starts a contract. Temporary: the server side comes in the next step.
---@param contractId string Id from Config.Contracts.List
function StartContract(contractId)
    _API.ShowNotification(string.format(locale("notification.contract_selected"), contractId), "inform")
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
