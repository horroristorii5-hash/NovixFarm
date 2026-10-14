-- NOVIXFARM
-- Main server system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local DataStore = DataStoreService:GetDataStore("NovixFarmData_v1")

local SEED_PRICE = 10
local CROP_PRICE = 25
local GROW_TIME = 20
local UPGRADE_PRICE = 250

local remotes = ReplicatedStorage:FindFirstChild("FarmRemotes")

if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "FarmRemotes"
    remotes.Parent = ReplicatedStorage
end

local function getRemote(name)
    local remote = remotes:FindFirstChild(name)

    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = remotes
    end

    return remote
end

local PlantEvent = getRemote("Plant")
local HarvestEvent = getRemote("Harvest")
local BuyEvent = getRemote("BuySeeds")
local UpgradeEvent = getRemote("UpgradeFarm")
local NotifyEvent = getRemote("Notify")

local plotsFolder = workspace:FindFirstChild("NovixFarms")

if not plotsFolder then
    plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "NovixFarms"
    plotsFolder.Parent = workspace
end

local cropsFolder = workspace:FindFirstChild("NovixCrops")

if not cropsFolder then
    cropsFolder = Instance.new("Folder")
    cropsFolder.Name = "NovixCrops"
    cropsFolder.Parent = workspace
end

local playerData = {}
local playerPlots = {}
local plantedCrops = {}
local cooldowns = {}

local function notify(player, message)
    NotifyEvent:FireClient(player, message)
end

local function createPlot(player)
    local index = 1

    while plotsFolder:FindFirstChild("Farm_" .. index) do
        index += 1
    end

    local plot = Instance.new("Part")

    plot.Name = "Farm_" .. index
    plot.Size = Vector3.new(60, 1, 60)
    plot.Position = Vector3.new((index - 1) * 75, 0, 0)
    plot.Anchored = true
    plot.Color = Color3.fromRGB(115, 175, 75)
    plot.Material = Enum.Material.Grass

    plot:SetAttribute("OwnerUserId", player.UserId)
    plot:SetAttribute("UpgradeLevel", 1)

    plot.Parent = plotsFolder

    playerPlots[player] = plot

    return plot
end

local function canAct(player)
    local now = os.clock()
    local last = cooldowns[player] or 0

    if now - last < 0.25 then
        return false
    end

    cooldowns[player] = now

    return true
end

local function getMoney(player)
    local stats = player:FindFirstChild("leaderstats")

    return stats and stats:FindFirstChild("Money")
end

local function getSeeds(player)
    return player:FindFirstChild("Seeds")
end

local function loadData(player)
    local data = {
        Money = 100,
        Seeds = 5,
        UpgradeLevel = 1
    }

    local success, saved = pcall(function()
        return DataStore:GetAsync("Player_" .. player.UserId)
    end)

    if success and type(saved) == "table" then
        data.Money = math.max(0, tonumber(saved.Money) or 100)
        data.Seeds = math.max(0, tonumber(saved.Seeds) or 5)
        data.UpgradeLevel = math.clamp(
            tonumber(saved.UpgradeLevel) or 1,
            1,
            10
        )
    end

    return data
end

local function saveData(player)
    local data = playerData[player]

    if not data then
        return
    end

    local money = getMoney(player)
    local seeds = getSeeds(player)
    local plot = playerPlots[player]

    local save = {
        Money = money and money.Value or data.Money,
        Seeds = seeds and seeds.Value or data.Seeds,
        UpgradeLevel = plot and
            (plot:GetAttribute("UpgradeLevel") or 1)
            or data.UpgradeLevel
    }

    local success, err = pcall(function()
        DataStore:UpdateAsync("Player_" .. player.UserId, function()
            return save
        end)
    end)

    if not success then
        warn("NovixFarm save failed:", player.UserId, err)
    end
end

local function setupPlayer(player)
    playerData[player] = loadData(player)

    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    stats.Parent = player

    local money = Instance.new("IntValue")
    money.Name = "Money"
    money.Value = playerData[player].Money
    money.Parent = stats

    local seeds = Instance.new("IntValue")
    seeds.Name = "Seeds"
    seeds.Value = playerData[player].Seeds
    seeds.Parent = player

    local plot = createPlot(player)

    plot:SetAttribute(
        "UpgradeLevel",
        playerData[player].UpgradeLevel
    )

    local level = playerData[player].UpgradeLevel

    plot.Size = Vector3.new(60 + (level - 1) * 10, 1, 60 + (level - 1) * 10)

    player.CharacterAdded:Connect(function(character)
        local root = character:WaitForChild("HumanoidRootPart", 10)

        if root and playerPlots[player] then
            local farm = playerPlots[player]

            root.CFrame = CFrame.new(
                farm.Position + Vector3.new(0, 5, 0)
            )
        end
    end)

    if player.Character then
        local root = player.Character:FindFirstChild("HumanoidRootPart")

        if root then
            root.CFrame = CFrame.new(plot.Position + Vector3.new(0, 5, 0))
        end
    end
end

PlantEvent.OnServerEvent:Connect(function(player, position)
    if not canAct(player) then return end
    if typeof(position) ~= "Vector3" then return end

    local plot = playerPlots[player]
    local seeds = getSeeds(player)

    if not plot or not seeds or seeds.Value <= 0 then
        notify(player, "You need seeds!")
        return
    end

    local halfX = plot.Size.X / 2
    local halfZ = plot.Size.Z / 2

    if math.abs(position.X - plot.Position.X) > halfX then return end
    if math.abs(position.Z - plot.Position.Z) > halfZ then return end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root or (root.Position - position).Magnitude > 35 then
        return
    end

    if position.Y < plot.Position.Y - 1 or
       position.Y > plot.Position.Y + 10 then
        return
    end

    for _, crop in ipairs(cropsFolder:GetChildren()) do
        if (crop.Position - position).Magnitude < 3 then
            notify(player, "This spot is occupied!")
            return
        end
    end

    seeds.Value -= 1

    local crop = Instance.new("Part")

    crop.Name = "Crop"
    crop.Shape = Enum.PartType.Ball
    crop.Size = Vector3.new(1, 1, 1)
    crop.Position = Vector3.new(
        position.X,
        plot.Position.Y + 1,
        position.Z
    )

    crop.Anchored = true
    crop.CanCollide = false
    crop.Color = Color3.fromRGB(65, 180, 55)

    crop:SetAttribute("OwnerUserId", player.UserId)
    crop:SetAttribute("Ready", false)

    crop.Parent = cropsFolder

    plantedCrops[crop] = {
        Owner = player,
        ReadyAt = os.clock() + GROW_TIME
    }

    task.delay(GROW_TIME, function()
        if not crop.Parent then return end
        if not plantedCrops[crop] then return end

        crop.Size = Vector3.new(2, 2, 2)
        crop.Color = Color3.fromRGB(255, 205, 45)
        crop:SetAttribute("Ready", true)
    end)

    notify(player, "Seed planted!")
end)

HarvestEvent.OnServerEvent:Connect(function(player, crop)
    if not canAct(player) then return end
    if typeof(crop) ~= "Instance" then return end
    if not crop:IsDescendantOf(cropsFolder) then return end

    local info = plantedCrops[crop]

    if not info or info.Owner ~= player then
        return
    end

    if os.clock() < info.ReadyAt then
        notify(player, "The crop is still growing!")
        return
    end

    local money = getMoney(player)

    if not money then return end

    money.Value += CROP_PRICE

    plantedCrops[crop] = nil
    crop:Destroy()

    notify(player, "+$" .. CROP_PRICE)
end)

BuyEvent.OnServerEvent:Connect(function(player)
    if not canAct(player) then return end

    local money = getMoney(player)
    local seeds = getSeeds(player)

    if not money or not seeds then return end

    if money.Value < SEED_PRICE then
        notify(player, "Not enough money!")
        return
    end

    money.Value -= SEED_PRICE
    seeds.Value += 1

    notify(player, "Bought 1 seed!")
end)

UpgradeEvent.OnServerEvent:Connect(function(player)
    if not canAct(player) then return end

    local money = getMoney(player)
    local plot = playerPlots[player]

    if not money or not plot then return end

    local level = plot:GetAttribute("UpgradeLevel") or 1

    if level >= 10 then
        notify(player, "Farm is at maximum level!")
        return
    end

    local price = UPGRADE_PRICE * level

    if money.Value < price then
        notify(player, "Not enough money! Need $" .. price)
        return
    end

    money.Value -= price

    level += 1

    plot:SetAttribute("UpgradeLevel", level)
    plot.Size = Vector3.new(
        60 + (level - 1) * 10,
        1,
        60 + (level - 1) * 10
    )

    notify(player, "Farm upgraded to level " .. level .. "!")
end)

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    saveData(player)

    local plot = playerPlots[player]

    if plot then
        plot:Destroy()
    end

    for crop, info in pairs(plantedCrops) do
        if info.Owner == player then
            plantedCrops[crop] = nil
            crop:Destroy()
        end
    end

    playerData[player] = nil
    playerPlots[player] = nil
    cooldowns[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, player)
end

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        saveData(player)
    end
end)

print("NovixFarm server system loaded!")
