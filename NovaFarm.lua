-- NovixFarm - FarmSystem
-- Place in ServerScriptService in Roblox Studio

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local plantEvent = getRemote("Plant")
local harvestEvent = getRemote("Harvest")
local buyEvent = getRemote("BuySeeds")

local cropsFolder = workspace:FindFirstChild("Crops")
if not cropsFolder then
    cropsFolder = Instance.new("Folder")
    cropsFolder.Name = "Crops"
    cropsFolder.Parent = workspace
end

local SEED_COST = 10
local SELL_PRICE = 25
local GROW_TIME = 20

local planted = {}
local lastAction = {}

local function setupPlayer(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local money = Instance.new("IntValue")
    money.Name = "Money"
    money.Value = 100
    money.Parent = leaderstats

    local seeds = Instance.new("IntValue")
    seeds.Name = "Seeds"
    seeds.Value = 5
    seeds.Parent = player
end

Players.PlayerAdded:Connect(setupPlayer)

local function canAct(player)
    local now = os.clock()
    if lastAction[player] and now - lastAction[player] < 0.3 then
        return false
    end
    lastAction[player] = now
    return true
end

buyEvent.OnServerEvent:Connect(function(player)
    if not canAct(player) then return end

    local money = player:FindFirstChild("leaderstats")
        and player.leaderstats:FindFirstChild("Money")
    local seeds = player:FindFirstChild("Seeds")

    if money and seeds and money.Value >= SEED_COST then
        money.Value -= SEED_COST
        seeds.Value += 1
    end
end)

plantEvent.OnServerEvent:Connect(function(player, position)
    if not canAct(player) then return end
    if typeof(position) ~= "Vector3" then return end

    local seeds = player:FindFirstChild("Seeds")
    if not seeds or seeds.Value <= 0 then return end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or (root.Position - position).Magnitude > 25 then
        return
    end

    if math.abs(position.X) > 200 or math.abs(position.Z) > 200 then
        return
    end

    seeds.Value -= 1

    local crop = Instance.new("Part")
    crop.Name = "Crop"
    crop.Shape = Enum.PartType.Ball
    crop.Size = Vector3.new(1, 1, 1)
    crop.Position = position + Vector3.new(0, 0.5, 0)
    crop.Anchored = true
    crop.CanCollide = false
    crop.Color = Color3.fromRGB(70, 180, 60)
    crop.Parent = cropsFolder

    planted[crop] = {
        owner = player,
        readyAt = os.clock() + GROW_TIME
    }

    task.delay(GROW_TIME, function()
        if crop.Parent and planted[crop] then
            crop.Size = Vector3.new(2, 2, 2)
            crop.Color = Color3.fromRGB(255, 200, 40)
        end
    end)
end)

harvestEvent.OnServerEvent:Connect(function(player, crop)
    if not canAct(player) then return end
    if typeof(crop) ~= "Instance" then return end
    if not crop:IsDescendantOf(cropsFolder) then return end

    local data = planted[crop]
    if not data or data.owner ~= player then return end
    if os.clock() < data.readyAt then return end

    local money = player:FindFirstChild("leaderstats")
        and player.leaderstats:FindFirstChild("Money")

    if money then
        money.Value += SELL_PRICE
    end

    planted[crop] = nil
    crop:Destroy()
end)

Players.PlayerRemoving:Connect(function(player)
    lastAction[player] = nil

    for crop, data in pairs(planted) do
        if data.owner == player then
            planted[crop] = nil
            crop:Destroy()
        end
    end
end)
