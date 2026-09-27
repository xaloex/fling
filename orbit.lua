-- // LocalScript (StarterPlayerScripts / StarterGui / Executor) // --

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = (gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

-- // Настройки интерфейса // --
local TOGGLE_KEY = Enum.KeyCode.RightShift -- Клавиша открытия/закрытия на ПК
local TITLE_TEXT = "ExampleFling"

-- Создаем основу ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExampleFlingGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

--------------------------------------------------------------------------------
-- // ПЛАВАЮЩАЯ КНОПКА ДЛЯ ТЕЛЕФОНОВ / ПЛАНШЕТОВ // --
--------------------------------------------------------------------------------
local mobileToggle = Instance.new("TextButton")
mobileToggle.Name = "MobileToggleBtn"
mobileToggle.Size = UDim2.new(0, 48, 0, 48)
mobileToggle.Position = UDim2.new(0, 15, 0.4, 0)
mobileToggle.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
mobileToggle.BorderSizePixel = 0
mobileToggle.Text = "EF"
mobileToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
mobileToggle.Font = Enum.Font.GothamBold
mobileToggle.TextSize = 15
mobileToggle.AutoButtonColor = false
mobileToggle.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0) -- Делаем круглую форму
toggleCorner.Parent = mobileToggle

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(70, 75, 95)
toggleStroke.Thickness = 1.6
toggleStroke.Parent = mobileToggle

--------------------------------------------------------------------------------
-- // ГЛАВНОЕ ОКНО // --
--------------------------------------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 520, 0, 320)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(55, 60, 72)
mainStroke.Thickness = 1.2
mainStroke.Parent = mainFrame

-- Верхняя панель (Header)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "  " .. TITLE_TEXT
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- Кнопка закрытия (крестик)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -33, 0, 3)
closeButton.BackgroundTransparency = 1
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(160, 160, 160)
closeButton.TextSize = 14
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = topBar

-- Контейнер для содержимого
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -50)
contentFrame.Position = UDim2.new(0, 10, 0, 42)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- ЛЕВАЯ ЧАСТЬ: Список игроков
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0.5, -5, 1, 0)
leftPanel.Position = UDim2.new(0, 0, 0, 0)
leftPanel.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
leftPanel.BorderSizePixel = 0
leftPanel.Parent = contentFrame

local leftCorner = Instance.new("UICorner")
leftCorner.CornerRadius = UDim.new(0, 8)
leftCorner.Parent = leftPanel

local playerScroll = Instance.new("ScrollingFrame")
playerScroll.Size = UDim2.new(1, -8, 1, -8)
playerScroll.Position = UDim2.new(0, 4, 0, 4)
playerScroll.BackgroundTransparency = 1
playerScroll.ScrollBarThickness = 3
playerScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 95, 110)
playerScroll.BorderSizePixel = 0
playerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
playerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerScroll.Parent = leftPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = playerScroll

-- ПРАВАЯ ЧАСТЬ: Управление и кнопки
local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0.5, -5, 1, 0)
rightPanel.Position = UDim2.new(0.5, 5, 0, 0)
rightPanel.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
rightPanel.BorderSizePixel = 0
rightPanel.Parent = contentFrame

local rightCorner = Instance.new("UICorner")
rightCorner.CornerRadius = UDim.new(0, 8)
rightCorner.Parent = rightPanel

local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1, -20, 0, 30)
selectedLabel.Position = UDim2.new(0, 10, 0, 10)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text = "Выбран: [никто]"
selectedLabel.TextColor3 = Color3.fromRGB(200, 205, 215)
selectedLabel.Font = Enum.Font.GothamMedium
selectedLabel.TextSize = 13
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.Parent = rightPanel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 40)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Статус: Ожидание"
statusLabel.TextColor3 = Color3.fromRGB(120, 130, 145)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = rightPanel

local function createButton(text, yPos, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.Parent = rightPanel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    return btn
end

local btnSelect = createButton("Fling Select", 70, Color3.fromRGB(60, 110, 210))
local btnAll    = createButton("Fling All", 120, Color3.fromRGB(70, 75, 180))
local btnStop   = createButton("Stop", 170, Color3.fromRGB(180, 50, 60))

--------------------------------------------------------------------------------
-- // ЛОГИКА ОТКРЫТИЯ / ПЕРЕТАСКИВАНИЯ КНОПКИ И ОКНА // --
--------------------------------------------------------------------------------
local isVisible = true
local function toggleGui()
    isVisible = not isVisible
    mainFrame.Visible = isVisible
end

closeButton.MouseButton1Click:Connect(toggleGui)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == TOGGLE_KEY then
        toggleGui()
    end
end)

-- Перетаскивание мобильной кнопки (Drag + Tap)
local btnDragging = false
local btnDragStart = nil
local btnStartPos = nil
local btnMoved = false

mobileToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        btnDragging = true
        btnDragStart = input.Position
        btnStartPos = mobileToggle.Position
        btnMoved = false

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                btnDragging = false
                -- Если палец почти не двигался, это клик/тап -> открываем или закрываем GUI
                if not btnMoved then
                    toggleGui()
                end
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and btnDragging then
        local delta = input.Position - btnDragStart
        if delta.Magnitude > 6 then
            btnMoved = true
        end
        mobileToggle.Position = UDim2.new(
            btnStartPos.X.Scale,
            btnStartPos.X.Offset + delta.X,
            btnStartPos.Y.Scale,
            btnStartPos.Y.Offset + delta.Y
        )
    end
end)

-- Перетаскивание главного окна за TopBar
local frameDragging = false
local frameDragStart, frameStartPos

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        frameDragging = true
        frameDragStart = input.Position
        frameStartPos = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                frameDragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and frameDragging then
        local delta = input.Position - frameDragStart
        mainFrame.Position = UDim2.new(
            frameStartPos.X.Scale,
            frameStartPos.X.Offset + delta.X,
            frameStartPos.Y.Scale,
            frameStartPos.Y.Offset + delta.Y
        )
    end
end)

--------------------------------------------------------------------------------
-- // ЯДРО: МОМЕНТАЛЬНЫЙ FLING // --
--------------------------------------------------------------------------------
getgenv().__exampleFlinging = false
local activeMode = "None"
local targetPlayer = nil
local flingHeartbeat = nil
local activeThread = nil

local function resetVelocity(root)
    if root and root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function stopFling()
    activeMode = "None"
    getgenv().__exampleFlinging = false

    if flingHeartbeat then
        flingHeartbeat:Disconnect()
        flingHeartbeat = nil
    end

    if activeThread then
        task.cancel(activeThread)
        activeThread = nil
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    resetVelocity(myRoot)

    statusLabel.Text = "Статус: Остановлено (Stop)"
end

-- Моментальный флинг в цель
local function instantFling(target, maxDuration, returnCFrame)
    if not target or target == LocalPlayer then return false end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum or myHum.Health <= 0 then return false end

    local targetChar = target.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum  = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum or targetHum.Health <= 0 then return false end

    maxDuration = maxDuration or 1.2
    local originCFrame = returnCFrame or myRoot.CFrame
    local startTime = os.clock()
    getgenv().__exampleFlinging = true

    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    if flingHeartbeat then
        flingHeartbeat:Disconnect()
    end

    flingHeartbeat = RunService.Heartbeat:Connect(function()
        if activeMode == "None" or not getgenv().__exampleFlinging then
            if flingHeartbeat then flingHeartbeat:Disconnect() end
            return
        end

        local isTimeout = (os.clock() - startTime) > maxDuration
        local isTargetDead = not targetHum or targetHum.Health <= 0
        local isTargetGone = not targetRoot or not targetRoot.Parent
        local isFlung = targetRoot and targetRoot.AssemblyLinearVelocity.Magnitude > 150

        if isTimeout or isTargetDead or isTargetGone or isFlung then
            if flingHeartbeat then flingHeartbeat:Disconnect() end
            return
        end

        local targetPos = targetRoot.Position
        local targetVel = targetRoot.AssemblyLinearVelocity

        local microOffset = Vector3.new(
            math.random(-25, 25) / 100,
            math.random(-15, 30) / 100,
            math.random(-25, 25) / 100
        )

        local randomAngle = CFrame.Angles(
            math.rad(math.random(0, 360)),
            math.rad(math.random(0, 360)),
            math.rad(math.random(0, 360))
        )

        myRoot.CFrame = CFrame.new(targetPos + (targetVel * 0.03) + microOffset) * randomAngle
        myRoot.AssemblyLinearVelocity = Vector3.new(9000000, 9000000, 9000000)
        myRoot.AssemblyAngularVelocity = Vector3.new(9000000, 9000000, 9000000)
    end)

    while flingHeartbeat and flingHeartbeat.Connected do
        task.wait()
    end

    resetVelocity(myRoot)

    if originCFrame and myRoot and myRoot.Parent then
        task.wait(0.03)
        myRoot.CFrame = originCFrame
        resetVelocity(myRoot)
    end

    return true
end

--------------------------------------------------------------------------------
-- // СПИСОК ИГРОКОВ // --
--------------------------------------------------------------------------------
local function selectPlayer(player)
    targetPlayer = player
    selectedLabel.Text = "Выбран: " .. player.DisplayName .. " (@" .. player.Name .. ")"
end

local function createPlayerEntry(player)
    if player == LocalPlayer then return end

    local entry = Instance.new("TextButton")
    entry.Name = player.Name
    entry.Size = UDim2.new(1, 0, 0, 42)
    entry.BackgroundColor3 = Color3.fromRGB(40, 43, 52)
    entry.Text = ""
    entry.AutoButtonColor = false
    entry.Parent = playerScroll

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 6)
    entryCorner.Parent = entry

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 32, 0, 32)
    avatar.Position = UDim2.new(0, 5, 0.5, -16)
    avatar.BackgroundTransparency = 1
    avatar.Parent = entry

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(1, 0)
    avatarCorner.Parent = avatar

    task.spawn(function()
        local thumbType = Enum.ThumbnailType.HeadShot
        local thumbSize = Enum.ThumbnailSize.Size48x48
        local content, isReady = Players:GetUserThumbnailAsync(player.UserId, thumbType, thumbSize)
        if isReady then
            avatar.Image = content
        end
    end)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -48, 1, 0)
    nameLabel.Position = UDim2.new(0, 44, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName .. "\n<font size='10' color='rgb(140,140,150)'>@" .. player.Name .. "</font>"
    nameLabel.RichText = true
    nameLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.TextSize = 12
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = entry

    entry.MouseButton1Click:Connect(function()
        selectPlayer(player)
    end)
end

local function refreshPlayerList()
    for _, child in ipairs(playerScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        createPlayerEntry(p)
    end
end

Players.PlayerAdded:Connect(createPlayerEntry)
Players.PlayerRemoving:Connect(function(player)
    local entry = playerScroll:FindFirstChild(player.Name)
    if entry then entry:Destroy() end
    if targetPlayer == player then
        targetPlayer = nil
        selectedLabel.Text = "Выбран: [никто]"
    end
end)

refreshPlayerList()

--------------------------------------------------------------------------------
-- // КНОПКИ УПРАВЛЕНИЯ // --
--------------------------------------------------------------------------------

btnSelect.MouseButton1Click:Connect(function()
    if not targetPlayer then
        statusLabel.Text = "Статус: Ошибка (выберите игрока)"
        return
    end

    stopFling()
    activeMode = "Select"
    statusLabel.Text = "Статус: Запуск -> " .. targetPlayer.DisplayName

    activeThread = task.spawn(function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local returnCF = myRoot and myRoot.CFrame

        instantFling(targetPlayer, 1.2, returnCF)

        if activeMode == "Select" then
            activeMode = "None"
            getgenv().__exampleFlinging = false
            statusLabel.Text = "Статус: Готово (Select)"
        end
    end)
end)

btnAll.MouseButton1Click:Connect(function()
    stopFling()
    activeMode = "All"
    statusLabel.Text = "Статус: Fling All (старт...)"

    activeThread = task.spawn(function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local globalOrigin = myRoot and myRoot.CFrame

        local playerList = Players:GetPlayers()
        for _, p in ipairs(playerList) do
            if activeMode ~= "All" then break end

            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                statusLabel.Text = "Статус: Выбивание -> " .. p.DisplayName
                instantFling(p, 0.75, nil)
                task.wait(0.04)
            end
        end

        if globalOrigin and myRoot and myRoot.Parent then
            myRoot.CFrame = globalOrigin
            resetVelocity(myRoot)
        end

        if activeMode == "All" then
            activeMode = "None"
            getgenv().__exampleFlinging = false
            statusLabel.Text = "Статус: Все игроки выбиты!"
        end
    end)
end)

btnStop.MouseButton1Click:Connect(function()
    stopFling()
end)

print("[ExampleFling] Загружено! Мобильная кнопка активна.")
