local Players = game:GetService("Players")

local STARTING_COINS = 100

Players.PlayerAdded:Connect(function(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = STARTING_COINS
    coins.Parent = leaderstats

    print(player.Name .. " joined NovixFarm!")
end)
