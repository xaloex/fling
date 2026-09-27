-- STREAMING_CHUNK:Initializing services and global variables...
-- // LocalScript (StarterPlayerScripts / StarterGui / Executor) // --

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Безопасное получение глобального окружения
local genv = (getgenv and getgenv()) or _G
genv.__flingActive = false
if not genv.FPDH then
genv.FPDH = workspace.FallenPartsDestroyHeight
end

-- // Настройки интерфейса // --
local TOGGLE_KEY = Enum.KeyCode.RightShift
local TITLE_TEXT = "RAPID RAM FLING"

-- Создаем основу ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonochromeGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- STREAMING_CHUNK:Creating main GUI frame and header...

-- 1. ГЛАВНОЕ ОКНО (Черно-белый стиль)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 520, 0, 330)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -165)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 45, 45)
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

-- Верхняя панель (Header)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topBarLine = Instance.new("Frame")
topBarLine.Size = UDim2.new(1, 0, 0, 1)
topBarLine.Position = UDim2.new(0, 0, 1, -1)
topBarLine.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
topBarLine.BorderSizePixel = 0
topBarLine.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "    " .. TITLE_TEXT
titleLabel.Size = UDim2.new(1, -45, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- Кнопка закрытия
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.Position = UDim2.new(1, -36, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
closeButton.TextSize = 13
closeButton.Font = Enum.Font.GothamBold
closeButton.AutoButtonColor = false
closeButton.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- STREAMING_CHUNK:Creating content panels and player list container...
-- Контейнер содержимого
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -24, 1, -56)
contentFrame.Position = UDim2.new(0, 12, 0, 48)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Левая панель: Список игроков
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0.5, -6, 1, 0)
leftPanel.Position = UDim2.new(0, 0, 0, 0)
leftPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
leftPanel.BorderSizePixel = 0
leftPanel.Parent = contentFrame

local leftCorner = Instance.new("UICorner")
leftCorner.CornerRadius = UDim.new(0, 8)
leftCorner.Parent = leftPanel

local leftStroke = Instance.new("UIStroke")
leftStroke.Color = Color3.fromRGB(35, 35, 35)
leftStroke.Thickness = 1
leftStroke.Parent = leftPanel

local playerScroll = Instance.new("ScrollingFrame")
playerScroll.Size = UDim2.new(1, -10, 1, -10)
playerScroll.Position = UDim2.new(0, 5, 0, 5)
playerScroll.BackgroundTransparency = 1
playerScroll.ScrollBarThickness = 3
playerScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
playerScroll.BorderSizePixel = 0
playerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
playerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerScroll.Parent = leftPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = playerScroll

-- STREAMING_CHUNK:Creating right panel, target stats and control buttons...
-- Правая панель: Действия и информация
local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0.5, -6, 1, 0)
rightPanel.Position = UDim2.new(0.5, 6, 0, 0)
rightPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
rightPanel.BorderSizePixel = 0
rightPanel.Parent = contentFrame

local rightCorner = Instance.new("UICorner")
rightCorner.CornerRadius = UDim.new(0, 8)
rightCorner.Parent = rightPanel

local rightStroke = Instance.new("UIStroke")
rightStroke.Color = Color3.fromRGB(35, 35, 35)
rightStroke.Thickness = 1
rightStroke.Parent = rightPanel

-- Выбранный игрок
local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1, -20, 0, 24)
selectedLabel.Position = UDim2.new(0, 10, 0, 12)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text = "TARGET: NONE"
selectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
selectedLabel.Font = Enum.Font.GothamBold
selectedLabel.TextSize = 12
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.Parent = rightPanel

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 36)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "STATUS: IDLE"
statusLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = rightPanel

-- Помощник создания стилизованных кнопок
local function createButton(text, yPos, isPrimary)
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 42)
btn.Position = UDim2.new(0, 10, 0, yPos)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 12
btn.Text = text
btn.AutoButtonColor = false
btn.Parent = rightPanel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = btn

local stroke = Instance.new("UIStroke")
stroke.Parent = btn

if isPrimary then
    btn.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
    btn.TextColor3 = Color3.fromRGB(15, 15, 15)
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
else
    btn.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    stroke.Color = Color3.fromRGB(50, 50, 50)
    stroke.Thickness = 1
end

btn.MouseEnter:Connect(function()
    TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
end)
btn.MouseLeave:Connect(function()
    TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
end)

return btn



end

local btnSelect = createButton("RAM SELECT", 70, true)
local btnAll    = createButton("RAM ALL", 122, false)
local btnStop   = createButton("STOP", 174, false)

-- STREAMING_CHUNK:Configuring mobile toggle button and interactions...

-- 2. ПЛАВАЮЩАЯ КНОПКА ДЛЯ ТЕЛЕФОНОВ И ПЛАНШЕТОВ

local mobileToggle = Instance.new("TextButton")
mobileToggle.Name = "MobileToggle"
mobileToggle.Size = UDim2.new(0, 52, 0, 52)
mobileToggle.Position = UDim2.new(0, 20, 0.5, -26)
mobileToggle.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
mobileToggle.Text = "MENU"
mobileToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
mobileToggle.Font = Enum.Font.GothamBold
mobileToggle.TextSize = 10
mobileToggle.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = mobileToggle

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(65, 65, 65)
toggleStroke.Thickness = 1.5
toggleStroke.Parent = mobileToggle

local isDraggingMobile = false
local mobileDragStart = nil
local mobileStartPos = nil
local mobileMoved = false

mobileToggle.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
isDraggingMobile = true
mobileMoved = false
mobileDragStart = input.Position
mobileStartPos = mobileToggle.Position

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            isDraggingMobile = false
        end
    end)
end



end)

UserInputService.InputChanged:Connect(function(input)
if isDraggingMobile and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
local delta = input.Position - mobileDragStart
if delta.Magnitude > 6 then
mobileMoved = true
end
mobileToggle.Position = UDim2.new(
mobileStartPos.X.Scale,
mobileStartPos.X.Offset + delta.X,
mobileStartPos.Y.Scale,
mobileStartPos.Y.Offset + delta.Y
)
end
end)

-- STREAMING_CHUNK:Implementing window dragging mechanics...

-- 3. ПЕРЕТАСКИВАНИЕ ОКНА (DRAGGING PC/TOUCH)

local draggingMain = false
local mainDragStart, mainStartPos, mainDragInput

topBar.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
draggingMain = true
mainDragStart = input.Position
mainStartPos = mainFrame.Position

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            draggingMain = false
        end
    end)
end



end)

topBar.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
mainDragInput = input
end
end)

UserInputService.InputChanged:Connect(function(input)
if input == mainDragInput and draggingMain then
local delta = input.Position - mainDragStart
mainFrame.Position = UDim2.new(
mainStartPos.X.Scale,
mainStartPos.X.Offset + delta.X,
mainStartPos.Y.Scale,
mainStartPos.Y.Offset + delta.Y
)
end
end)

-- STREAMING_CHUNK:Configuring menu toggling shortcuts and visibility...

-- 4. ОТКРЫТИЕ / ЗАКРЫТИЕ МЕНЮ

local isGuiOpen = true

local function toggleMenu()
isGuiOpen = not isGuiOpen
mainFrame.Visible = isGuiOpen
end

closeButton.MouseButton1Click:Connect(toggleMenu)

mobileToggle.Activated:Connect(function()
if not mobileMoved then
toggleMenu()
end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
if not gameProcessed and input.KeyCode == TOGGLE_KEY then
toggleMenu()
end
end)

-- STREAMING_CHUNK:Implementing dynamic player list cards...

-- 5. ДИНАМИЧЕСКИЙ СПИСОК ИГРОКОВ С КРУГЛЫМИ АВАТАРАМИ

local selectedTarget = nil

local function createPlayerCard(player)
if player == LocalPlayer then return end

local card = Instance.new("TextButton")
card.Name = player.Name
card.Size = UDim2.new(1, 0, 0, 44)
card.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
card.Text = ""
card.AutoButtonColor = false
card.Parent = playerScroll

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 8)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(38, 38, 38)
cardStroke.Thickness = 1
cardStroke.Parent = card

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.new(0, 32, 0, 32)
avatar.Position = UDim2.new(0, 6, 0.5, -16)
avatar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
avatar.Parent = card

local avatarCorner = Instance.new("UICorner")
avatarCorner.CornerRadius = UDim.new(1, 0)
avatarCorner.Parent = avatar

task.spawn(function()
    local content, isReady = Players:GetUserThumbnailAsync(
        player.UserId,
        Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size48x48
    )
    if isReady then
        avatar.Image = content
    end
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -50, 1, 0)
nameLabel.Position = UDim2.new(0, 46, 0, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = player.DisplayName .. " <font color='rgb(120,120,120)'>@" .. player.Name .. "</font>"
nameLabel.RichText = true
nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
nameLabel.Font = Enum.Font.GothamMedium
nameLabel.TextSize = 12
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Parent = card

card.MouseButton1Click:Connect(function()
    selectedTarget = player
    selectedLabel.Text = "TARGET: " .. string.upper(player.DisplayName)
    
    for _, otherCard in ipairs(playerScroll:GetChildren()) do
        if otherCard:IsA("TextButton") then
            otherCard.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
        end
    end
    card.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
end)



end

local function refreshList()
for _, child in ipairs(playerScroll:GetChildren()) do
if child:IsA("TextButton") then
child:Destroy()
end
end
for _, p in ipairs(Players:GetPlayers()) do
createPlayerCard(p)
end
end

Players.PlayerAdded:Connect(createPlayerCard)
Players.PlayerRemoving:Connect(function(player)
local card = playerScroll:FindFirstChild(player.Name)
if card then card:Destroy() end
if selectedTarget == player then
selectedTarget = nil
selectedLabel.Text = "TARGET: NONE"
end
end)

refreshList()

-- STREAMING_CHUNK:Implementing Rapid Ram / Skid Fling physics engine...

-- 6. ЯДРО: ЛОГИКА RAPID RAM FLING (SKID FLING)

local activeMode = "None"     -- "Select", "All", "None"
local activeThread = nil

local function stopFling()
activeMode = "None"
genv.__flingActive = false

if activeThread then
    task.cancel(activeThread)
    activeThread = nil
end

local myChar = LocalPlayer.Character
local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
local myRoot = myHum and myHum.RootPart

if myHum then
    myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
end
if myRoot then
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
end

workspace.CurrentCamera.CameraSubject = myHum
if genv.FPDH then
    workspace.FallenPartsDestroyHeight = genv.FPDH
end

statusLabel.Text = "STATUS: STOPPED"



end

local function rapidRamFling(TargetPlayer, maxDuration)
maxDuration = maxDuration or 2.5
local Character = LocalPlayer.Character
local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
local RootPart = Humanoid and Humanoid.RootPart

if not Character or not Humanoid or not RootPart then
    statusLabel.Text = "STATUS: CHAR NOT READY"
    return false
end

local TCharacter = TargetPlayer and TargetPlayer.Character
if not TCharacter then
    statusLabel.Text = "STATUS: NO TARGET CHAR"
    return false
end

local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
local TRootPart = THumanoid and THumanoid.RootPart
local THead = TCharacter:FindFirstChild("Head")
local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
local Handle = Accessory and Accessory:FindFirstChild("Handle")

if THumanoid and THumanoid.Sit then
    statusLabel.Text = "STATUS: TARGET IS SITTING"
    return false
end

-- Сохраняем исходную позицию
if RootPart.AssemblyLinearVelocity.Magnitude < 50 then
    genv.OldPos = RootPart.CFrame
end

-- Наведение камеры на цель
if THead then
    workspace.CurrentCamera.CameraSubject = THead
elseif Handle then
    workspace.CurrentCamera.CameraSubject = Handle
elseif THumanoid and TRootPart then
    workspace.CurrentCamera.CameraSubject = THumanoid
end

local TargetBasePart = TRootPart or THead or Handle
if not TargetBasePart then
    statusLabel.Text = "STATUS: NO VALID TARGET PART"
    return false
end

genv.__flingActive = true

-- Отключаем коллизию своего персонажа
for _, part in ipairs(Character:GetDescendants()) do
    if part:IsA("BasePart") then
        part.CanCollide = false
    end
end

-- Настройка силового импульса
workspace.FallenPartsDestroyHeight = 0/0
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

local BV = Instance.new("BodyVelocity")
BV.Parent = RootPart
BV.Velocity = Vector3.zero
BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

-- Вспомогательная функция позиционирования с безумной скоростью
local FPos = function(BasePart, Pos, Ang)
    if not RootPart or not RootPart.Parent then return end
    RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
    Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
    RootPart.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
    RootPart.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
end

local startTime = tick()
local Angle = 0

-- Главный таранный цикл (Rapid Ram Loop)
repeat
    if not RootPart or not THumanoid or THumanoid.Health <= 0 then break end

    if BasePart and BasePart.Parent then
        if BasePart.AssemblyLinearVelocity.Magnitude < 50 then
            Angle = Angle + 100
            FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.AssemblyLinearVelocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
            task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.AssemblyLinearVelocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
            task.wait()
            FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
            task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
            task.wait()
        else
            FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
            task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
            task.wait()
            FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
            task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
            task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
            task.wait()
        end
    else
        break
    end
until (tick() - startTime) > maxDuration or not genv.__flingActive or activeMode == "None"

-- Завершение и очистка
if BV then BV:Destroy() end
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
workspace.CurrentCamera.CameraSubject = Humanoid

-- Безопасное возвращение персонажа на прежнее место
if genv.OldPos and RootPart and RootPart.Parent then
    local returnTime = tick()
    repeat
        RootPart.CFrame = genv.OldPos * CFrame.new(0, 0.5, 0)
        Character:SetPrimaryPartCFrame(genv.OldPos * CFrame.new(0, 0.5, 0))
        Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

        for _, part in ipairs(Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        task.wait()
    until (RootPart.Position - genv.OldPos.Position).Magnitude < 25 or (tick() - returnTime) > 1.5
end

if genv.FPDH then
    workspace.FallenPartsDestroyHeight = genv.FPDH
end

return true



end

-- STREAMING_CHUNK:Connecting GUI button action handlers...

-- 7. ОБРАБОТЧИКИ КНОПОК ДЕЙСТВИЙ

btnSelect.MouseButton1Click:Connect(function()
if not selectedTarget then
statusLabel.Text = "STATUS: NO TARGET"
return
end

stopFling()
activeMode = "Select"
statusLabel.Text = "RAMMING: " .. string.upper(selectedTarget.DisplayName)

activeThread = task.spawn(function()
    rapidRamFling(selectedTarget, 3.0)

    if activeMode == "Select" then
        statusLabel.Text = "STATUS: RAM COMPLETED"
        activeMode = "None"
    end
end)



end)

btnAll.MouseButton1Click:Connect(function()
stopFling()
activeMode = "All"
statusLabel.Text = "STATUS: RAMMING ALL..."

activeThread = task.spawn(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if activeMode ~= "All" then break end
        if plr ~= LocalPlayer then
            statusLabel.Text = "RAM ALL -> " .. string.upper(plr.DisplayName)
            rapidRamFling(plr, 1.8)
            task.wait(0.1)
        end
    end

    if activeMode == "All" then
        statusLabel.Text = "STATUS: ALL RAMMED"
        activeMode = "None"
    end
end)



end)

btnStop.MouseButton1Click:Connect(function()
stopFling()
end)

print("

$$Rapid Ram Fling$$

 Мощный Skid Fling успешно загружен!")
