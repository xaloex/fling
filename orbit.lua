-- // LocalScript (StarterPlayerScripts / StarterGui / Executor) // --

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

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
local TITLE_TEXT = "RAPID RAM FLING [DEVFORUM PHYSICS]"

-- Создаем основу ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonochromeGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- // Менеджер ESP подсветки // --
local targetHighlight = Instance.new("Highlight")
targetHighlight.Name = "TargetSelectionESP"
targetHighlight.FillColor = Color3.fromRGB(50, 255, 50)       -- Зеленый цвет заливки
targetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)   -- Белый контур
targetHighlight.FillTransparency = 0.55
targetHighlight.OutlineTransparency = 0.1
targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Видимость сквозь стены
targetHighlight.Enabled = false

local charAddedConnection = nil

local function setHighlightTarget(player)
    if charAddedConnection then
        charAddedConnection:Disconnect()
        charAddedConnection = nil
    end

    if not player then
        targetHighlight.Enabled = false
        targetHighlight.Adornee = nil
        targetHighlight.Parent = nil
        return
    end

    local function attach(character)
        if character then
            targetHighlight.Adornee = character
            targetHighlight.Parent = character
            targetHighlight.Enabled = true
        end
    end

    attach(player.Character)
    charAddedConnection = player.CharacterAdded:Connect(attach)
end

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

local mainScale = Instance.new("UIScale")
mainScale.Scale = 1
mainScale.Parent = mainFrame

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

local closeScale = Instance.new("UIScale")
closeScale.Parent = closeButton

closeButton.MouseEnter:Connect(function()
    TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(180, 40, 40)}):Play()
    TweenService:Create(closeScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.08}):Play()
end)

closeButton.MouseLeave:Connect(function()
    TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(28, 28, 28)}):Play()
    TweenService:Create(closeScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
end)

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

local function updateStatus(text, color)
    color = color or Color3.fromRGB(150, 150, 150)
    TweenService:Create(statusLabel, TweenInfo.new(0.12), {TextTransparency = 0.6}):Play()
    task.delay(0.12, function()
        statusLabel.Text = text
        statusLabel.TextColor3 = color
        TweenService:Create(statusLabel, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
    end)
end

-- Помощник создания кнопок
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

    local btnScale = Instance.new("UIScale")
    btnScale.Parent = btn

    local defaultBg, hoverBg, defaultStroke, hoverStroke

    if isPrimary then
        defaultBg = Color3.fromRGB(245, 245, 245)
        hoverBg = Color3.fromRGB(255, 255, 255)
        defaultStroke = Color3.fromRGB(200, 200, 200)
        hoverStroke = Color3.fromRGB(255, 255, 255)
        btn.TextColor3 = Color3.fromRGB(15, 15, 15)
    else
        defaultBg = Color3.fromRGB(26, 26, 26)
        hoverBg = Color3.fromRGB(36, 36, 36)
        defaultStroke = Color3.fromRGB(50, 50, 50)
        hoverStroke = Color3.fromRGB(90, 90, 90)
        btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    end

    btn.BackgroundColor3 = defaultBg
    stroke.Color = defaultStroke
    stroke.Thickness = 1

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.18), {BackgroundColor3 = hoverBg}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.18), {Color = hoverStroke, Thickness = 1.4}):Play()
        TweenService:Create(btnScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.02}):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.18), {BackgroundColor3 = defaultBg}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.18), {Color = defaultStroke, Thickness = 1}):Play()
        TweenService:Create(btnScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end)

    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btnScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.95}):Play()
    end)

    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btnScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.02}):Play()
    end)

    return btn
end

local btnSelect = createButton("RAM SELECT", 70, true)
local btnAll    = createButton("RAM ALL", 122, false)
local btnStop   = createButton("STOP", 174, false)

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
mobileToggle.AutoButtonColor = false
mobileToggle.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = mobileToggle

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(65, 65, 65)
toggleStroke.Thickness = 1.5
toggleStroke.Parent = mobileToggle

local mobileScale = Instance.new("UIScale")
mobileScale.Parent = mobileToggle

mobileToggle.MouseButton1Down:Connect(function()
    TweenService:Create(mobileScale, TweenInfo.new(0.1), {Scale = 0.9}):Play()
end)

mobileToggle.MouseButton1Up:Connect(function()
    TweenService:Create(mobileScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end)

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

-- 3. ПЕРЕТАСКИВАНИЕ ОКНА

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

-- 4. ОТКРЫТИЕ / ЗАКРЫТИЕ МЕНЮ

local isGuiOpen = true
local isTweening = false

local function toggleMenu()
    if isTweening then return end
    isTweening = true
    isGuiOpen = not isGuiOpen

    if isGuiOpen then
        mainFrame.Visible = true
        mainScale.Scale = 0.8
        local tween = TweenService:Create(mainScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
        tween:Play()
        tween.Completed:Connect(function()
            isTweening = false
        end)
    else
        local tween = TweenService:Create(mainScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.8})
        tween:Play()
        tween.Completed:Connect(function()
            mainFrame.Visible = false
            isTweening = false
        end)
    end
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

-- 5. ДИНАМИЧЕСКИЙ СПИСОК ИГРОКОВ С ВЫБОРОМ И ПОДСВЕТКОЙ

local selectedTarget = nil

local function resetCardStyles()
    for _, otherCard in ipairs(playerScroll:GetChildren()) do
        if otherCard:IsA("TextButton") then
            local stroke = otherCard:FindFirstChildOfClass("UIStroke")
            TweenService:Create(otherCard, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26, 26, 26)}):Play()
            if stroke then
                TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(38, 38, 38)}):Play()
            end
        end
    end
end

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

    card.MouseEnter:Connect(function()
        if selectedTarget ~= player then
            TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(34, 34, 34)}):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(60, 60, 60)}):Play()
        end
    end)

    card.MouseLeave:Connect(function()
        if selectedTarget ~= player then
            TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26, 26, 26)}):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(38, 38, 38)}):Play()
        end
    end)

    -- Клик: выбор или снятие выбора
    card.MouseButton1Click:Connect(function()
        if selectedTarget == player then
            selectedTarget = nil
            selectedLabel.Text = "TARGET: NONE"
            resetCardStyles()
            setHighlightTarget(nil)
            return
        end

        selectedTarget = player
        selectedLabel.Text = "TARGET: " .. string.upper(player.DisplayName)

        resetCardStyles()
        TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(44, 44, 44)}):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(150, 150, 150)}):Play()

        setHighlightTarget(player)
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
        setHighlightTarget(nil)
    end
end)

refreshList()

-- 6. ЯДРО: ЛОГИКА RAPID RAM FLING (DEVFORUM KINEMATIC ENGINE)

local activeMode = "None"
local activeThread = nil
local noclipConnection = nil
local heartbeatConnection = nil

local function cleanupFlingConnections()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

local function stopFling()
    activeMode = "None"
    genv.__flingActive = false

    cleanupFlingConnections()

    if activeThread then
        task.cancel(activeThread)
        activeThread = nil
    end

    local myChar = LocalPlayer.Character
    local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myHum and myHum.RootPart

    if myHum then
        myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end

    if myRoot then
        myRoot.Anchored = true
        task.wait(0.03)
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
        myRoot.Anchored = false
    end

    if myChar then
        for _, part in ipairs(myChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
                if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" then
                    part.CanCollide = true
                end
            end
        end
    end

    workspace.CurrentCamera.CameraSubject = myHum
    if genv.FPDH then
        workspace.FallenPartsDestroyHeight = genv.FPDH
    end

    updateStatus("STATUS: STOPPED", Color3.fromRGB(200, 70, 70))
end

-- Получение задержки пинга для идеального расчета траектории на сервере
local function getNetworkPing()
    local network = Stats and Stats:FindFirstChild("Network")
    local serverStats = network and network:FindFirstChild("ServerStatsItem")
    local pingStat = serverStats and serverStats:FindFirstChild("Data Ping")
    if pingStat then
        return (pingStat:GetValue() / 1000)
    end
    return 0.05
end

local function rapidRamFling(TargetPlayer, maxDuration)
    maxDuration = maxDuration or 2.5
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart

    if not Character or not Humanoid or not RootPart then
        updateStatus("STATUS: CHAR NOT READY", Color3.fromRGB(220, 100, 100))
        return false
    end

    local TCharacter = TargetPlayer and TargetPlayer.Character
    if not TCharacter then
        updateStatus("STATUS: NO TARGET CHAR", Color3.fromRGB(220, 100, 100))
        return false
    end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")

    if THumanoid and THumanoid.Sit then
        updateStatus("STATUS: TARGET IS SITTING", Color3.fromRGB(220, 180, 80))
        return false
    end

    local TargetBasePart = TRootPart or THead or Handle
    if not TargetBasePart then
        updateStatus("STATUS: NO VALID TARGET PART", Color3.fromRGB(220, 100, 100))
        return false
    end

    if RootPart.AssemblyLinearVelocity.Magnitude < 50 then
        genv.OldPos = RootPart.CFrame
    end

    if THead then
        workspace.CurrentCamera.CameraSubject = THead
    elseif THumanoid then
        workspace.CurrentCamera.CameraSubject = THumanoid
    end

    genv.__flingActive = true
    cleanupFlingConnections()

    -- 1. Сверхточный Noclip через Stepped перед фазой обсчета физики
    noclipConnection = RunService.Stepped:Connect(function()
        if Character and Character.Parent then
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)

    workspace.FallenPartsDestroyHeight = 0/0
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart
    BV.Velocity = Vector3.zero
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    local startTime = tick()
    local angle = 0
    local lastVel = TargetBasePart.AssemblyLinearVelocity

    -- 2. Кинематика 2-го порядка (Учитывает Скорость + Ускорение + Сетевой Пинг)
    heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        if not genv.__flingActive or activeMode == "None" or not RootPart or not TargetBasePart or not TargetBasePart.Parent or (THumanoid and THumanoid.Health <= 0) then
            return
        end

        angle = (angle + 120) % 360

        local currentPos = TargetBasePart.Position
        local currentVel = TargetBasePart.AssemblyLinearVelocity
        
        -- Расчет ускорения: A = (V_now - V_last) / dt
        local accel = Vector3.zero
        if dt > 0 then
            accel = (currentVel - lastVel) / dt
        end
        lastVel = currentVel

        -- Итоговое время предсказания (Пинг + оффсет кадров)
        local ping = getNetworkPing()
        local predTime = math.clamp(ping + 0.12, 0.08, 0.35)

        -- Формула движения: P_predicted = P_0 + V*t + 0.5*A*t^2
        local predictedPos = currentPos + (currentVel * predTime) + (0.5 * accel * (predTime ^ 2))

        -- Трёхмерное спиральное вращение вокруг кинематической точки
        local rad = math.rad(angle)
        local orbitRadius = 1.4
        local subOffset = Vector3.new(
            math.cos(rad) * orbitRadius,
            math.sin(rad * 2) * 1.2,
            math.sin(rad) * orbitRadius
        )

        local finalPos = predictedPos + subOffset

        -- Импульсный вектор столкновения
        RootPart.CFrame = CFrame.new(finalPos) * CFrame.Angles(math.rad(angle), math.rad(angle * 3), math.rad(angle * 1.5))
        RootPart.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
    end)

    repeat
        task.wait()
    until (tick() - startTime) > maxDuration 
       or not genv.__flingActive 
       or activeMode == "None" 
       or not TargetBasePart 
       or not TargetBasePart.Parent 
       or (THumanoid and THumanoid.Health <= 0)

    cleanupFlingConnections()
    if BV then BV:Destroy() end

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid

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

-- 7. ОБРАБОТЧИКИ КНОПОК ДЕЙСТВИЙ

btnSelect.MouseButton1Click:Connect(function()
    if not selectedTarget then
        updateStatus("STATUS: NO TARGET", Color3.fromRGB(220, 100, 100))
        return
    end

    stopFling()
    activeMode = "Select"
    updateStatus("RAMMING: " .. string.upper(selectedTarget.DisplayName), Color3.fromRGB(100, 220, 100))

    activeThread = task.spawn(function()
        rapidRamFling(selectedTarget, 3.0)

        if activeMode == "Select" then
            updateStatus("STATUS: COMPLETED", Color3.fromRGB(150, 150, 150))
            activeMode = "None"
        end
    end)
end)

btnAll.MouseButton1Click:Connect(function()
    stopFling()
    activeMode = "All"
    updateStatus("STATUS: RAMMING ALL...", Color3.fromRGB(220, 180, 80))

    activeThread = task.spawn(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if activeMode ~= "All" then break end
            if plr ~= LocalPlayer then
                updateStatus("RAM ALL -> " .. string.upper(plr.DisplayName), Color3.fromRGB(220, 180, 80))
                rapidRamFling(plr, 1.8)
                task.wait(0.1)
            end
        end

        if activeMode == "All" then
            updateStatus("STATUS: ALL RAMMED", Color3.fromRGB(150, 150, 150))
            activeMode = "None"
        end
    end)
end)

btnStop.MouseButton1Click:Connect(function()
    stopFling()
end)

print("[Monochrome GUI] Меню с физическим кинематическим движком загружено!")
