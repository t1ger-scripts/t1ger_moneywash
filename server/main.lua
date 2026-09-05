-- Event for player loaded:
RegisterNetEvent("t1ger_moneywash:server:playerLoaded", function()
    local src = source
    local player = _API.Player.GetFromId(src)

    LoadReputation(src)

    if Config.Debug then
        print("playerId: "..src.." loaded", player)
    end
end)