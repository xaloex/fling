-- // LocalScript (StarterPlayerScripts / StarterGui / Executor) // --

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = (gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

-- // Настройки интерфейса // --
local TOGGLE_KEY = Enum.KeyCode.RightShift -- Клавиша открытия/закрытия GUI
local TITLE_TEXT = "ExampleFling"

-- Создаем основу ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExampleFlingGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- Главное окно
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

-- Отображение выбранного игрока
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

-- Индикатор текущего статуса
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

-- Функция-помощник для создания кнопок
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

-- // Логика Dragging (Перетаскивание) // --
local dragging = false
local dragInput, dragStart, startPos

local function updateInput(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateInput(input)
    end
end)

-- // Открытие и закрытие по кнопке и клавише // --
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

--------------------------------------------------------------------------------
-- // ЯДРО: ЛОГИКА ORBIT FLING (EXAMPLE) // --
--------------------------------------------------------------------------------
getgenv().__exampleFlinging = false
local activeMode = "None"     -- "Select", "All", "None"
local targetPlayer = nil
local flingHeartbeat = nil
local activeThread = nil

-- Очистка скорости персонажа
local function resetVelocity(root)
    if root and root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

-- Полная остановка процесса
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

-- Функция вращения по орбите (Orbit Fling) вокруг цели
local function orbitFling(target, duration, returnCFrame)
    if not target or target == LocalPlayer then return false end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum or myHum.Health <= 0 then return false end

    local targetChar = target.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum  = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum or targetHum.Health <= 0 then return false end

    duration = duration or 2.5
    local originCFrame = returnCFrame or myRoot.CFrame
    local startTime = os.clock()
    getgenv().__exampleFlinging = true

    -- Отключаем коллизию своего тела, чтобы не застревать
    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    local orbitRadius = 1.8   -- Радиус орбиты (близкий контакт)
    local orbitSpeed = 24     -- Скорость вращения по орбите

    if flingHeartbeat then
        flingHeartbeat:Disconnect()
    end

    flingHeartbeat = RunService.Heartbeat:Connect(function()
        if activeMode == "None" or not getgenv().__exampleFlinging then
            if flingHeartbeat then flingHeartbeat:Disconnect() end
            return
        end

        local isTimeout = (os.clock() - startTime) > duration
        local isTargetDead = not targetHum or targetHum.Health <= 0
        local isTargetGone = not targetRoot or not targetRoot.Parent

        if isTimeout or isTargetDead or isTargetGone then
            if flingHeartbeat then flingHeartbeat:Disconnect() end
            return
        end

        -- Вычисление точки на орбите вокруг цели
        local angle = os.clock() * orbitSpeed
        local offset = Vector3.new(
            math.cos(angle) * orbitRadius,
            math.sin(angle * 1.5) * 0.8, -- легкое покачивание по высоте
            math.sin(angle) * orbitRadius
        )

        -- Установка позиции на орбите лицом к центру цели
        myRoot.CFrame = CFrame.new(targetRoot.Position + offset, targetRoot.Position)

        -- Передача экстремального физического импульса
        myRoot.AssemblyLinearVelocity = Vector3.new(45000, 45000, 45000)
        myRoot.AssemblyAngularVelocity = Vector3.new(45000, 45000, 45000)
    end)

    -- Ожидание окончания фазы флинга
    while flingHeartbeat and flingHeartbeat.Connected do
        task.wait()
    end

    -- Сброс скорости
    resetVelocity(myRoot)

    -- Возврат на исходную позицию
    if originCFrame and myRoot and myRoot.Parent then
        task.wait(0.05)
        myRoot.CFrame = originCFrame
        resetVelocity(myRoot)
    end

    return true
end

--------------------------------------------------------------------------------
-- // ОБНОВЛЕНИЕ И ВЫБОР ИГРОКОВ В СПИСКЕ // --
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

    -- Аватарка
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

    -- Имя
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
-- // ОБРАБОТЧИКИ КНОПОК УПРАВЛЕНИЯ // --
--------------------------------------------------------------------------------

-- 1. Fling Select (Флинг только выбранного игрока по орбите)
btnSelect.MouseButton1Click:Connect(function()
    if not targetPlayer then
        statusLabel.Text = "Статус: Ошибка (выберите игрока)"
        return
    end

    stopFling()
    activeMode = "Select"
    statusLabel.Text = "Статус: Orbit Fling -> " .. targetPlayer.DisplayName

    activeThread = task.spawn(function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local returnCF = myRoot and myRoot.CFrame

        orbitFling(targetPlayer, 3.0, returnCF)

        if activeMode == "Select" then
            activeMode = "None"
            getgenv().__exampleFlinging = false
            statusLabel.Text = "Статус: Завершено (Select)"
        end
    end)
end)

-- 2. Fling All (Поочередный Orbit Fling по всем игрокам)
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
                statusLabel.Text = "Статус: Orbit -> " .. p.DisplayName
                -- Флингуем игрока 1.8 секунды, затем переходим к следующему
                orbitFling(p, 1.8, nil)
                task.wait(0.1)
            end
        end

        -- Возвращаемся на место, где стояли до начала Fling All
        if globalOrigin and myRoot and myRoot.Parent then
            myRoot.CFrame = globalOrigin
            resetVelocity(myRoot)
        end

        if activeMode == "All" then
            activeMode = "None"
            getgenv().__exampleFlinging = false
            statusLabel.Text = "Статус: Fling All завершен"
        end
    end)
end)

-- 3. Stop (Моментальная остановка и возврат на место)
btnStop.MouseButton1Click:Connect(function()
    stopFling()
end)

print("[ExampleFling] GUI & Orbit Fling загружены успешно!")
