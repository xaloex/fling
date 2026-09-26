--[[═══════════════════════════════════════════════════════════════════════
    FLING GUI v2 — спин-флинг игроком (Delta / Solara / Wave)
    ─────────────────────────────────────────────────────────────────────────
    • Мини-окно: перетаскивается мышкой/пальцем, кнопка _ сворачивает
    • Список игроков ЖИВОЙ: сам добавляет кто зашёл, сам убирает кто вышел
    • Кнопка FLING: современный спин-флинг —
        – удерживает твой HumanoidRootPart внутри хитбокса цели (Stepped + jitter)
        – CanCollide = true, Massless = false на все части тела
        – AssemblyAngularVelocity = 999999 (гигантское вращение)
        – AssemblyLinearVelocity — хаотичный подброс
      Работает под FilteringEnabled, старые BodyVelocity не используются
    • После флинга тебя возвращает на место, откуда ты его пинал
    • Вставить в Delta → Execute
    ═══════════════════════════════════════════════════════════════════════]]

--════════════════════ СЕРВИСЫ ════════════════════
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInput     = game:GetService("UserInputService")
local GuiParent     = (gethui and gethui()) or game:GetService("CoreGui") or game:GetService("StarterGui")

local LP = Players.LocalPlayer

--════════════════════ НАСТРОЙКИ ══════════════════
local CONFIG = {
    SPIN_SPEED   = 999999,                          -- угловая скорость вращения (Y-ось)
    BOUNCE_POWER = 100,                             -- вертикальный подброс + хаотичный разброс
    JITTER       = 2,                               -- радиус микро-сдвига внутри хитбокса (студы)
    FLING_TIME   = 2.2,                             -- сколько секунд длится флинг
    GUI_SIZE     = UDim2.new(0, 210, 0, 250),
}

--════════════════════ GUI ════════════════════════
-- уничтожаем старое окно при повторном экзекуте
if GuiParent:FindFirstChild("FlingGuiV1") then
    GuiParent.FlingGuiV1:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FlingGuiV1"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = GuiParent

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = CONFIG.GUI_SIZE
Main.Position = UDim2.new(0, 120, 0, 150)
Main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(90, 60, 200)
MainStroke.Thickness = 1.5
MainStroke.Parent = Main

--── шапка (тянуть за неё) ──
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -34, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ FLING GUI"
Title.TextColor3 = Color3.fromRGB(200, 180, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
CloseBtn.Text = "_"
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

--── список игроков ──
local ListHolder = Instance.new("ScrollingFrame")
ListHolder.Size = UDim2.new(1, -12, 1, -96)
ListHolder.Position = UDim2.new(0, 6, 0, 38)
ListHolder.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
ListHolder.BorderSizePixel = 0
ListHolder.ScrollBarThickness = 4
ListHolder.ScrollBarImageColor3 = Color3.fromRGB(120, 90, 220)
ListHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
ListHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
ListHolder.Parent = Main

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = ListHolder

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 3)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ListHolder

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 4)
ListPadding.PaddingBottom = UDim.new(0, 4)
ListPadding.PaddingLeft = UDim.new(0, 4)
ListPadding.PaddingRight = UDim.new(0, 4)
ListPadding.Parent = ListHolder

--── статус выбранного ──
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -12, 0, 16)
StatusLabel.Position = UDim2.new(0, 6, 1, -58)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Игрок не выбран"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

--── кнопка FLING ──
local FlingBtn = Instance.new("TextButton")
FlingBtn.Size = UDim2.new(1, -12, 0, 34)
FlingBtn.Position = UDim2.new(0, 6, 1, -40)
FlingBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 200)
FlingBtn.Text = "💥 FLING"
FlingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlingBtn.TextSize = 16
FlingBtn.Font = Enum.Font.GothamBold
FlingBtn.Parent = Main

local FlingCorner = Instance.new("UICorner")
FlingCorner.CornerRadius = UDim.new(0, 6)
FlingCorner.Parent = FlingBtn

--════════════════════ ЛОГИКА: ВЫБОР ИГРОКА ════════════════════
local selectedPlayer = nil
local playerButtons = {}   -- [Player] = кнопка

local function markSelection()
    for plr, btn in pairs(playerButtons) do
        if plr == selectedPlayer and plr.Parent then
            btn.BackgroundColor3 = Color3.fromRGB(90, 40, 140)
            btn.Text = "▶ " .. plr.Name
        else
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
            btn.Text = plr.Name
        end
    end
end

local function updateStatus()
    if selectedPlayer and selectedPlayer.Parent then
        StatusLabel.Text = "Цель: " .. selectedPlayer.Name
        StatusLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
    else
        StatusLabel.Text = "Игрок не выбран"
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
        selectedPlayer = nil
    end
end

local function addPlayerButton(plr)
    if playerButtons[plr] then return end
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 22)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.TextSize = 12
    btn.Font = Enum.Font.Gotham
    btn.Text = plr.Name
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = ListHolder

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.Parent = btn

    btn.MouseButton1Click:Connect(function()
        selectedPlayer = plr
        markSelection()
        updateStatus()
    end)

    playerButtons[plr] = btn
end

local function removePlayerButton(plr)
    local btn = playerButtons[plr]
    if btn then
        btn:Destroy()
        playerButtons[plr] = nil
    end
    if selectedPlayer == plr then
        selectedPlayer = nil
        updateStatus()
    end
end

-- живой список: текущие + кто зашёл/вышел
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LP then addPlayerButton(plr) end
end
Players.PlayerAdded:Connect(function(plr)
    if plr ~= LP then addPlayerButton(plr) end
end)
Players.PlayerRemoving:Connect(function(plr)
    removePlayerButton(plr)
end)

--════════════════════ ПЕРЕТАСКИВАНИЕ ОКНА ════════════════════
do
    local dragging, dragStart, startPos = false, nil, nil

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInput.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- свернуть/развернуть
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

--════════════════════ ФЛИНГ (SPIN-FLING) ════════════════════
local flinging = false

local function getRootChar()
    local char = LP.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then
        return char, hrp, hum
    end
    return nil
end

FlingBtn.MouseButton1Click:Connect(function()
    if flinging then return end
    if not (selectedPlayer and selectedPlayer.Parent) then
        StatusLabel.Text = "Сначала выбери игрока!"
        return
    end
    local char, hrp, hum = getRootChar()
    if not char then return end

    flinging = true
    local oldText = FlingBtn.Text
    FlingBtn.Text = "⏳ ФЛИНГУЮ..."

    -- точка, откуда кидаем (вернёмся сюда)
    local startPos = hrp.CFrame

    -- целевой игрок (следим за ним в реальном времени)
    local target = selectedPlayer

    -- 1) отключаем контроль персонажа, чтобы движок не мешал вращению
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    hum.PlatformStand = true

    -- 2) включаем коллизии на ВСЕХ частях тела (сохраняем исходные значения)
    local savedParts = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            savedParts[p] = { canCollide = p.CanCollide, massless = p.Massless }
            p.CanCollide = true
            p.Massless = false
        end
    end

    -- 3) спин-флинг: держим себя внутри хитбокса цели + гигантское вращение
    local conn
    conn = RunService.Stepped:Connect(function()
        -- персонаж умер/исчез — ничего не делаем
        if not hrp.Parent or hum.Health <= 0 then return end

        -- живая цель: телепортируем себя в её хитбокс с микро-сдвигом (jitter),
        -- чтобы не залипнуть в коллизии
        local tChar = target and target.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if tRoot and target.Parent then
            local j = CONFIG.JITTER
            local offset = Vector3.new(
                (math.random() - 0.5) * 2 * j,
                (math.random() - 0.5) * 2 * j,
                (math.random() - 0.5) * 2 * j
            )
            hrp.CFrame = tRoot.CFrame * CFrame.new(offset)
        end

        -- гигантская угловая скорость вращения
        hrp.AssemblyAngularVelocity = Vector3.new(0, CONFIG.SPIN_SPEED, 0)

        -- хаотичная линейная скорость: подброс вверх + разброс по осям
        hrp.AssemblyLinearVelocity = Vector3.new(
            math.random(-CONFIG.BOUNCE_POWER, CONFIG.BOUNCE_POWER),
            CONFIG.BOUNCE_POWER,
            math.random(-CONFIG.BOUNCE_POWER, CONFIG.BOUNCE_POWER)
        )
    end)

    task.wait(CONFIG.FLING_TIME)

    -- 4) полная остановка: сброс скоростей
    if conn then conn:Disconnect() end
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.AssemblyLinearVelocity = Vector3.zero

    -- восстанавливаем исходные коллизии и Massless
    for p, saved in pairs(savedParts) do
        if p and p.Parent then
            p.CanCollide = saved.canCollide
            p.Massless = saved.massless
        end
    end

    -- если за время флинга персонаж умер — просто сбрасываем состояние
    if not hrp.Parent or not char.Parent or hum.Health <= 0 then
        flinging = false
        FlingBtn.Text = oldText
        return
    end

    -- телепорт обратно на точку флинга
    hrp.Anchored = true
    hrp.CFrame = startPos
    task.wait(0.05)
    hrp.Anchored = false

    hum.PlatformStand = false
    hum:ChangeState(Enum.HumanoidStateType.GettingUp)

    flinging = false
    FlingBtn.Text = oldText
    updateStatus()
end)

--════════════════════ ЗАЩИТА ОТ СМЕРТИ ════════════════════
-- если тебя всё-таки убило твоим же флингом — авто-респавн не даёт списку сломаться
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    updateStatus()
end)

print("[FlingGui v2] Загружен. Выбери игрока и жми FLING 💥")
