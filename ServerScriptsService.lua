-- NovaFarm
-- FarmSystem.lua
-- Помести обычный Script в ServerScriptService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local SAVE_STORE = DataStoreService:GetDataStore("NovaFarm_PlayerData_v1")

local START_MONEY = 100
local START_SEEDS = 5
local GROW_TIME = 30
local BASE_REWARD = 25
local SEED_PRICE = 10
local MAX_SEEDS_PER_PURCHASE = 50
local MAX_UPGRADE_LEVEL = 10
local MAX_CROPS = 40

local remotesFolder = ReplicatedStorage:FindFirstChild("FarmRemotes")

if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "FarmRemotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function getRemote(name)
    local remote = remotesFolder:FindFirstChild(name)

    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = remotesFolder
    end

    return remote
end

local PlantRemote = getRemote("Plant")
local HarvestRemote = getRemote("Harvest")
local BuySeedsRemote = getRemote("BuySeeds")
local UpgradeRemote = getRemote("UpgradeFarm")
local NotifyRemote = getRemote("Notify")

local farmsFolder = workspace:FindFirstChild("NovaFarms")

if not farmsFolder then
    farmsFolder = Instance.new("Folder")
    farmsFolder.Name = "NovaFarms"
    farmsFolder.Parent = workspace
end

local playerData = {}
local playerFarms = {}
local playerCrops = {}
local actionTimes = {}

local function notify(player, message)
    if player and player.Parent == Players then
        NotifyRemote:FireClient(player, message)
    end
end

local function createPart(name, size, position, color, parent)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = position
    part.Anchored = true
    part.Color = color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent

    return part
end

local function createFarm(player)
    local oldFarm = playerFarms[player]

    if oldFarm then
        oldFarm:Destroy()
    end

    local index = 1

    for _, farm in ipairs(farmsFolder:GetChildren()) do
        if farm:GetAttribute("OwnerUserId") then
            index += 1
        end
    end

    local farm = Instance.new("Model")
    farm.Name = "Farm_" .. player.UserId
    farm:SetAttribute("OwnerUserId", player.UserId)
    farm.Parent = farmsFolder

    local x = ((index - 1) % 4) * 90
    local z = math.floor((index - 1) / 4) * 90

    local ground = createPart(
        "Ground",
        Vector3.new(70, 1, 70),
        Vector3.new(x, 0, z),
        Color3.fromRGB(90, 170, 80),
        farm
    )

    ground:SetAttribute("OwnerUserId", player.UserId)

    local sign = createPart(
        "FarmSign",
        Vector3.new(12, 5, 1),
        Vector3.new(x, 4, z - 33),
        Color3.fromRGB(120, 75, 40),
        farm
    )

    sign.CanCollide = false

    local signGui = Instance.new("BillboardGui")
    signGui.Size = UDim2.fromOffset(200, 50)
    signGui.StudsOffset = Vector3.new(0, 4, 0)
    signGui.AlwaysOnTop = true
    signGui.Parent = sign

    local signText = Instance.new("TextLabel")
    signText.Size = UDim2.fromScale(1, 1)
    signText.BackgroundTransparency = 1
    signText.TextColor3 = Color3.new(1, 1, 1)
    signText.TextScaled = true
    signText.Text = player.Name .. "'s Farm"
    signText.Parent = signGui

    playerFarms[player] = farm
    playerCrops[player] = {}

    return farm
end

local function createStats(player, data)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local money = Instance.new("IntValue")
    money.Name = "Money"
    money.Value = data.Money
    money.Parent = leaderstats

    local seeds = Instance.new("IntValue")
    seeds.Name = "Seeds"
    seeds.Value = data.Seeds
    seeds.Parent = leaderstats

    local level = Instance.new("IntValue")
    level.Name = "FarmLevel"
    level.Value = data.FarmLevel
    level.Parent = leaderstats
end

local function syncStats(player)
    local data = playerData[player]
    local stats = player:FindFirstChild("leaderstats")

    if not data or not stats then
        return
    end

    stats.Money.Value = data.Money
    stats.Seeds.Value = data.Seeds
    stats.FarmLevel.Value = data.FarmLevel
end

local function loadData(player)
    local data = {
        Money = START_MONEY,
        Seeds = START_SEEDS,
        FarmLevel = 1,
    }

    local success, saved = pcall(function()
        return SAVE_STORE:GetAsync("Player_" .. player.UserId)
    end)

    if success and type(saved) == "table" then
        data.Money = math.max(0, math.floor(tonumber(saved.Money) or START_MONEY))
        data.Seeds = math.clamp(math.floor(tonumber(saved.Seeds) or START_SEEDS), 0, 100000)
        data.FarmLevel = math.clamp(math.floor(tonumber(saved.FarmLevel) or 1), 1, MAX_UPGRADE_LEVEL)
    elseif not success then
        warn("NovaFarm: could not load data for " .. player.Name)
    end

    return data
end

local function saveData(player)
    local data = playerData[player]

    if not data then
        return
    end

    local snapshot = {
        Money = data.Money,
        Seeds = data.Seeds,
        FarmLevel = data.FarmLevel,
    }

    local success, err = pcall(function()
        SAVE_STORE:UpdateAsync("Player_" .. player.UserId, function()
            return snapshot
        end)
    end)

    if not success then
        warn("NovaFarm: save failed for " .. player.Name .. ": " .. tostring(err))
    end
end

local function isRateLimited(player, action, cooldown)
    local now = os.clock()
    actionTimes[player] = actionTimes[player] or {}

    local previous = actionTimes[player][action] or 0

    if now - previous < cooldown then
        return true
    end

    actionTimes[player][action] = now
    return false
end

local function getOwnedFarm(player)
    local farm = playerFarms[player]

    if not farm or farm:GetAttribute("OwnerUserId") ~= player.UserId then
        return nil
    end

    return farm
end

local function getPlantPosition(player, requestedPosition)
    if typeof(requestedPosition) ~= "Vector3" then
        return nil
    end

    local farm = getOwnedFarm(player)

    if not farm then
        return nil
    end

    local ground = farm:FindFirstChild("Ground")

    if not ground then
        return nil
    end

    local localPosition = ground.CFrame:PointToObjectSpace(requestedPosition)

    -- Проверяем, что точка находится внутри собственной фермы.
    if math.abs(localPosition.X) > ground.Size.X / 2 - 2 then
        return nil
    end

    if math.abs(localPosition.Z) > ground.Size.Z / 2 - 2 then
        return nil
    end

    -- Растения появляются на поверхности земли.
    return Vector3.new(
        requestedPosition.X,
        ground.Position.Y + ground.Size.Y / 2 + 0.5,
        requestedPosition.Z
    )
end

local function isPositionFree(player, position)
    for _, crop in ipairs(playerCrops[player] or {}) do
        if crop.Part and crop.Part.Parent then
            local distance = (crop.Part.Position - position).Magnitude

            if distance < 4 then
                return false
            end
        end
    end

    return true
end

local function updateCropAppearance(crop)
    if not crop.Part or not crop.Part.Parent then
        return
    end

    if os.time() >= crop.ReadyAt then
        crop.Part.Size = Vector3.new(3, 4, 3)
        crop.Part.Position = crop.Position + Vector3.new(0, 1.5, 0)
        crop.Part.Color = Color3.fromRGB(255, 210, 60)
        crop.Part.Name = "RipeCrop"
        crop.Part:SetAttribute("Ripe", true)
    end
end

PlantRemote.OnServerEvent:Connect(function(player, requestedPosition)
    if isRateLimited(player, "Plant", 0.25) then
        return
    end

    local data = playerData[player]

    if not data then
        return
    end

    if data.Seeds < 1 then
        notify(player, "Недостаточно семян!")
        return
    end

    local crops = playerCrops[player] or {}

    if #crops >= math.min(MAX_CROPS, 4 + data.FarmLevel * 3) then
        notify(player, "На ферме уже много растений!")
        return
    end

    local position = getPlantPosition(player, requestedPosition)

    if not position then
        notify(player, "Сажать можно только на своей ферме!")
        return
    end

    if not isPositionFree(player, position) then
        notify(player, "Здесь уже что-то растёт!")
        return
    end

    data.Seeds -= 1
    syncStats(player)

    local farm = getOwnedFarm(player)

    local plant = createPart(
        "GrowingCrop",
        Vector3.new(1, 1, 1),
        position,
        Color3.fromRGB(60, 190, 70),
        farm
    )

    plant.Shape = Enum.PartType.Ball
    plant.CanCollide = false
    plant:SetAttribute("OwnerUserId", player.UserId)
    plant:SetAttribute("Ripe", false)

    local growTime = math.max(5, GROW_TIME - (data.FarmLevel - 1) * 2)

    local crop = {
        Part = plant,
        Position = position,
        ReadyAt = os.time() + growTime,
    }

    table.insert(crops, crop)
    playerCrops[player] = crops

    notify(player, "Семя посажено! Урожай вырастет через " .. growTime .. " сек.")

    task.delay(growTime, function()
        if player.Parent == Players and plant.Parent then
            updateCropAppearance(crop)
        end
    end)
end)

HarvestRemote.OnServerEvent:Connect(function(player, target)
    if isRateLimited(player, "Harvest", 0.25) then
        return
    end

    local data = playerData[player]

    if not data or typeof(target) ~= "Instance" then
        return
    end

    local farm = getOwnedFarm(player)

    if not farm or not target:IsA("BasePart") or not target:IsDescendantOf(farm) then
        notify(player, "Это не твой урожай!")
        return
    end

    if target:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end

    local foundIndex

    for index, crop in ipairs(playerCrops[player] or {}) do
        if crop.Part == target then
            foundIndex = index
            break
        end
    end

    if not foundIndex then
        return
    end

    local crop = playerCrops[player][foundIndex]

    if os.time() < crop.ReadyAt then
        notify(player, "Растение ещё растёт!")
        return
    end

    table.remove(playerCrops[player], foundIndex)

    local reward = BASE_REWARD + (data.FarmLevel - 1) * 10
    data.Money += reward

    target:Destroy()

    syncStats(player)
    notify(player, "Урожай собран! +" .. reward .. " монет")
end)

BuySeedsRemote.OnServerEvent:Connect(function(player, amount)
    if isRateLimited(player, "BuySeeds", 0.3) then
        return
    end

    local data = playerData[player]

    if not data then
        return
    end

    amount = tonumber(amount)

    if not amount or amount ~= math.floor(amount) then
        return
    end

    amount = math.clamp(amount, 1, MAX_SEEDS_PER_PURCHASE)

    local cost = amount * SEED_PRICE

    if data.Money < cost then
        notify(player, "Недостаточно денег!")
        return
    end

    data.Money -= cost
    data.Seeds += amount

    syncStats(player)
    notify(player, "Куплено семян: " .. amount)
end)

UpgradeRemote.OnServerEvent:Connect(function(player)
    if isRateLimited(player, "Upgrade", 0.5) then
        return
    end

    local data = playerData[player]

    if not data then
        return
    end

    if data.FarmLevel >= MAX_UPGRADE_LEVEL then
        notify(player, "Достигнут максимальный уровень!")
        return
    end

    local cost = data.FarmLevel * 150

    if data.Money < cost then
        notify(player, "Для улучшения нужно " .. cost .. " монет!")
        return
    end

    data.Money -= cost
    data.FarmLevel += 1

    syncStats(player)
    notify(player, "Ферма улучшена до уровня " .. data.FarmLevel .. "!")
end)

local function setupPlayer(player)
    if playerData[player] then
        return
    end

    local data = loadData(player)

    if player.Parent ~= Players then
        return
    end

    playerData[player] = data

    createStats(player, data)
    createFarm(player)

    player.CharacterAdded:Connect(function(character)
        local farm = getOwnedFarm(player)

        if not farm then
            return
        end

        local ground = farm:FindFirstChild("Ground")

        if ground then
            local root = character:WaitForChild("HumanoidRootPart", 10)

            if root then
                root.CFrame = ground.CFrame * CFrame.new(0, 5, 0)
            end
        end
    end)

    if player.Character then
        task.defer(function()
            local character = player.Character
            local farm = getOwnedFarm(player)
            local ground = farm and farm:FindFirstChild("Ground")
            local root = character and character:FindFirstChild("HumanoidRootPart")

            if root and ground then
                root.CFrame = ground.CFrame * CFrame.new(0, 5, 0)
            end
        end)
    end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
    saveData(player)

    if playerFarms[player] then
        playerFarms[player]:Destroy()
    end

    playerData[player] = nil
    playerFarms[player] = nil
    playerCrops[player] = nil
    actionTimes[player] = nil
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        saveData(player)
    end
end)

print("NovaFarm server system loaded!")
