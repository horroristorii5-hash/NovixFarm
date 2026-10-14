-- NovaFarm
-- FarmClient.lua
-- Помести LocalScript в StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("FarmRemotes")
local PlantRemote = remotes:WaitForChild("Plant")
local HarvestRemote = remotes:WaitForChild("Harvest")
local BuySeedsRemote = remotes:WaitForChild("BuySeeds")
local UpgradeRemote = remotes:WaitForChild("UpgradeFarm")
local NotifyRemote = remotes:WaitForChild("Notify")

local selectedAction = "Plant"

local oldGui = playerGui:FindFirstChild("NovaFarmGUI")

if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "NovaFarmGUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 230, 0, 290)
main.Position = UDim2.new(0, 10, 0.5, -145)
main.BackgroundColor3 = Color3.fromRGB(35, 45, 35)
main.BackgroundTransparency = 0.1
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 0, 35)
title.Position = UDim2.new(0, 5, 0, 5)
title.BackgroundTransparency = 1
title.Text = "🌾 NOVAFARM"
title.TextColor3 = Color3.fromRGB(255, 230, 120)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = main

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -10, 0, 35)
status.Position = UDim2.new(0, 5, 0, 42)
status.BackgroundTransparency = 1
status.Text = "Выбери действие"
status.TextColor3 = Color3.new(1, 1, 1)
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.Parent = main

local buttons = {}

local function makeButton(name, text, y, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(1, -20, 0, 38)
    button.Position = UDim2.new(0, 10, 0, y)
    button.BackgroundColor3 = Color3.fromRGB(75, 130, 70)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.Parent = main

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button

    button.Activated:Connect(callback)

    table.insert(buttons, button)

    return button
end

local function setAction(action)
    selectedAction = action

    if action == "Plant" then
        status.Text = "Посадка: нажми на землю"
    elseif action == "Harvest" then
        status.Text = "Сбор: нажми на растение"
    end
end

makeButton("PlantButton", "🌱 Посадить", 82, function()
    setAction("Plant")
end)

makeButton("HarvestButton", "🧺 Собрать", 126, function()
    setAction("Harvest")
end)

makeButton("ShopButton", "🛒 Купить 5 семян — 50 монет", 170, function()
    BuySeedsRemote:FireServer(5)
end)

makeButton("UpgradeButton", "⬆️ Улучшить ферму", 214, function()
    UpgradeRemote:FireServer()
end)

local function getTargetFromScreen(screenPosition)
    local camera = Workspace.CurrentCamera

    if not camera then
        return nil
    end

    local ray = camera:ViewportPointToRay(
        screenPosition.X,
        screenPosition.Y
    )

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    if player.Character then
        params.FilterDescendantsInstances = {player.Character}
    end

    return Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end

local function handleWorldTap(screenPosition)
    local result = getTargetFromScreen(screenPosition)

    if not result or not result.Instance then
        return
    end

    local target = result.Instance

    if selectedAction == "Plant" then
        if target.Name == "Ground"
            and target:GetAttribute("OwnerUserId") == player.UserId then

            PlantRemote:FireServer(result.Position)
        else
            status.Text = "Выбери землю своей фермы"
        end

    elseif selectedAction == "Harvest" then
        if target:GetAttribute("OwnerUserId") == player.UserId
            and target:GetAttribute("Ripe") == true then

            HarvestRemote:FireServer(target)
        else
            status.Text = "Выбери созревшее растение"
        end
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        local position = input.Position

        -- Не выполняем действие при нажатии на интерфейс.
        local objects = playerGui:GetGuiObjectsAtPosition(
            position.X,
            position.Y
        )

        for _, object in ipairs(objects) do
            if object:IsDescendantOf(main) then
                return
            end
        end

        handleWorldTap(position)
    end
end)

NotifyRemote.OnClientEvent:Connect(function(message)
    status.Text = tostring(message)

    task.delay(3, function()
        if status and status.Parent and selectedAction == "Plant" then
            status.Text = "Посадка: нажми на землю"
        elseif status and status.Parent then
            status.Text = "Сбор: нажми на растение"
        end
    end)
end)

print("NovaFarm client system loaded!")
