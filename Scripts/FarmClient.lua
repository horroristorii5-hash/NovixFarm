-- NovaFarm FarmClient
-- Mobile and PC controls

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FarmRemotes")

local Plant = remotes:WaitForChild("Plant")
local Harvest = remotes:WaitForChild("Harvest")
local BuySeeds = remotes:WaitForChild("BuySeeds")
local UpgradeFarm = remotes:WaitForChild("UpgradeFarm")
local Notify = remotes:WaitForChild("Notify")

local gui = Instance.new("ScreenGui")
gui.Name = "NovaFarmUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function createButton(text, position)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 150, 0, 50)
    button.Position = position
    button.Text = text
    button.TextScaled = true
    button.BackgroundColor3 = Color3.fromRGB(50, 150, 70)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button

    return button
end

local plantButton = createButton(
    "🌱 Plant",
    UDim2.new(0, 10, 1, -170)
)

local harvestButton = createButton(
    "🌾 Harvest",
    UDim2.new(0, 10, 1, -110)
)

local buyButton = createButton(
    "🛒 Buy seeds",
    UDim2.new(1, -160, 1, -170)
)

local upgradeButton = createButton(
    "⬆ Upgrade",
    UDim2.new(1, -160, 1, -110)
)

local mode = "Plant"

plantButton.Activated:Connect(function()
    mode = "Plant"
end)

harvestButton.Activated:Connect(function()
    mode = "Harvest"
end)

buyButton.Activated:Connect(function()
    BuySeeds:FireServer()
end)

upgradeButton.Activated:Connect(function()
    UpgradeFarm:FireServer()
end)

local message = Instance.new("TextLabel")
message.Size = UDim2.new(0.8, 0, 0, 40)
message.Position = UDim2.new(0.1, 0, 0, 20)
message.BackgroundTransparency = 0.3
message.TextScaled = true
message.Text = "Welcome to NovaFarm!"
message.Parent = gui

Notify.OnClientEvent:Connect(function(text)
    message.Text = tostring(text)
end)

local mouse = player:GetMouse()

mouse.Button1Down:Connect(function()
    local target = mouse.Target
    if not target then return end

    if mode == "Harvest" then
        if target.Name == "Crop" then
            Harvest:FireServer(target)
        end
    else
        Plant:FireServer(mouse.Hit.Position)
    end
end)

print("NovaFarm controls loaded!")
