--[[
	============================================================
	 FLING RIG  -  ONE FILE, CLIENT SIDE ONLY
	 No RemoteEvents. No server Scripts. Paste once and play.
	 Physics: pure client-side ANGULAR-VELOCITY COLLISION FLING
	          (we only ever touch the LOCAL character; the target
	           gets launched by Roblox's own collision solver)
	 Install:  StarterPlayer > StarterPlayerScripts > script.lua
	============================================================
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")

local PLR  = Players.LocalPlayer
local PGUI = PLR:WaitForChild("PlayerGui")

--============================================================
-- 1. CONFIG
--============================================================
local CFG = {
	Hotkey      = Enum.KeyCode.F,   -- show / hide the mini window

	ApproachTime = 0.12,            -- split second to line up before pass 1
	StandOff     = 15,              -- how far behind them we set up each pass

	RamPasses    = 9,               -- number of straight-line rams
	RamStep      = 0.17,            -- seconds of pure velocity per pass
	RamSpeed     = 1500,            -- studs/s on the first pass
	RamGrowth    = 320,             -- added per pass
	MaxRamSpeed  = 3000,            -- hard cap (higher = tunnelling risk)
	RamUpBias    = 0.30,            -- upward lean so they arc out of the map
	PuntFrom     = 6,               -- passes from here on, launch skyward
	PuntUpBias   = 1.30,

	SpinOmega    = 999999,          -- rad/s on our own root (limb sweep)
	SpinDir      = 0,               -- 0 = randomise per attempt, +1 / -1 = fixed
	Jitter       = 40,              -- subtle fluctuating linear speed

	StuckFactor  = 0.35,            -- speed under this % of command = we hit a wall
	StuckFrames  = 5,               -- ...for this many frames -> cut the pass short

	ReturnTime   = 0.70,            -- minimum return time
	ReturnDiv    = 260,             -- return time scales with distance flown
	ReturnMax    = 2.60,
	NavHeight    = 40,              -- height used while flying back

	MaxAttempts  = 3,               -- "try" count before giving up
	SuccessSpeed = 260,
	SuccessDist  = 70,
	NewWindow    = 20,              -- seconds a joiner shows as NEW
	Ghost        = true,            -- hide own limbs while flinging
}

local CLR = {
	bg      = Color3.fromRGB(13, 15, 21),
	panel   = Color3.fromRGB(21, 24, 32),
	card    = Color3.fromRGB(30, 34, 44),
	cardSel = Color3.fromRGB(37, 60, 86),
	cardOut = Color3.fromRGB(23, 25, 32),
	line    = Color3.fromRGB(48, 54, 66),
	txt     = Color3.fromRGB(227, 232, 240),
	dim     = Color3.fromRGB(138, 148, 165),
	acc     = Color3.fromRGB(0, 200, 255),
	good    = Color3.fromRGB(60, 220, 130),
	warn    = Color3.fromRGB(255, 196, 60),
	bad     = Color3.fromRGB(255, 90, 90),
}

--============================================================
-- 2. TINY UI HELPERS
--============================================================
local function mk(class, props, parent, kids)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	for _, c in ipairs(kids or {}) do c.Parent = o end
	return o
end

local function round(o, r)
	mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end

local function outline(o, c, t)
	mk("UIStroke", {
		Color = c or CLR.line, Thickness = t or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function label(parent, pos, size, text, tsize, col, font, align)
	return mk("TextLabel", {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = pos, Size = size, Text = text or "",
		TextSize = tsize or 13, TextColor3 = col or CLR.txt,
		Font = font or Enum.Font.GothamMedium,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

--============================================================
-- 3. STATE + FORWARD DECLARATIONS
--============================================================
local Registry = {}   -- [userId] = { name, userId, player, joinedAt, leftAt }
local selUserId, selPlayer = nil, nil

local F = {
	active   = false,
	target   = nil,
	tgtChar  = nil,
	tgtRoot  = nil,
	pt       = 0,        -- time inside current stage
	attempt  = 0,
	dir      = Vector3.new(1, 0, 0),
	ang      = 0,
	spinSign = 1,
	spinAngle = 0,      -- self-driven body rotation for the blender
	pass     = 0,       -- which ram pass we are on
	setup    = true,    -- next RAM frame does the setup teleport
	stuck    = 0,       -- consecutive slow frames (we hit geometry)
	lastPos  = nil,     -- last frame position, for the stuck check
	ramDir   = Vector3.new(1, 0, 0),
	ramFlat  = Vector3.new(1, 0, 0),
	ramSpeed = 0,
	retT     = CFG.ReturnTime,
	origin   = nil,      -- the spot we let go from (we come back here)
	seedPos  = nil,
	ms, md   = 0, 0,     -- last measured target speed / distance
}

local selfChar, selfRoot, selfHum, selfParts = nil, nil, nil, {}
local savedParts, savedHum, savedRoot = {}, nil, nil

local W   = {}        -- gui widgets + gui functions
local rows = {}       -- built row widgets, keyed by userId

local ago, sortedRecords, selectPlayer, snapshotSelf, abortFling, startFling

--============================================================
-- 4. GUI  (mini, draggable, collapsible)
--============================================================
local function buildGUI()
	local screen = mk("ScreenGui", {
		Name = "FlingRigGui", ResetOnSpawn = false, DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, PGUI)

	local main = mk("Frame", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 392),
		BackgroundColor3 = CLR.bg, BorderSizePixel = 0, Active = true,
	}, screen)
	round(main, 12); outline(main, CLR.line, 1)
	W.screen, W.main = screen, main

	---------------- title bar ----------------
	local bar = mk("Frame", { BackgroundColor3 = CLR.panel, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34), Active = true }, main)

	label(bar, UDim2.fromOffset(11, 0), UDim2.new(1, -86, 1, 0),
		"FLING RIG", 13, CLR.acc, Enum.Font.GothamBold)

	local function iconBtn(char, xoff, fn)
		local b = mk("TextButton", {
			BackgroundColor3 = CLR.card, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xoff, 0.5, 0),
			Size = UDim2.fromOffset(24, 22), Text = char, TextSize = 13,
			TextColor3 = CLR.dim, Font = Enum.Font.GothamBold,
		}, bar)
		round(b, 6)
		b.MouseButton1Click:Connect(fn)
		return b
	end
	iconBtn("-", -32, function() main.Size = UDim2.fromOffset(300, 34) end)
	iconBtn("x", -6,  function() screen.Enabled = not screen.Enabled end)

	---------------- body ----------------
	local body = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34) }, main)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, body)
	mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, body)

	local status = label(body, UDim2.new(), UDim2.new(1, 0, 0, 16),
		"Ready", 11, CLR.dim, Enum.Font.Gotham)
	status.LayoutOrder = 0
	W.status = status

	local head = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14) }, body)
	head.LayoutOrder = 1
	label(head, UDim2.new(), UDim2.fromScale(0.6, 1), "SERVER PLAYERS", 10,
		CLR.dim, Enum.Font.GothamBold)
	local countL = label(head, UDim2.new(), UDim2.fromScale(0.4, 1), "0 online", 10,
		CLR.acc, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	W.count = countL

	local list = mk("ScrollingFrame", {
		BackgroundColor3 = CLR.panel, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 190), ScrollBarThickness = 3,
		ScrollBarImageColor3 = CLR.line, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(),
	}, body)
	round(list, 8); outline(list, CLR.line, 1)
	list.LayoutOrder = 2
	mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, list)
	mk("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, list)
	W.list = list

	---------------- option toggles ----------------
	local optRow = mk("Frame", { BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22) }, body)
	optRow.LayoutOrder = 3
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center }, optRow)

	local function toggle(text, order)
		local on = true
		local b = mk("TextButton", {
			BackgroundColor3 = CLR.card, BorderSizePixel = 0, Size = UDim2.fromOffset(64, 22),
			Text = text, TextSize = 10, Font = Enum.Font.GothamBold,
			TextColor3 = CLR.good, AutoButtonColor = false,
		}, optRow)
		b.LayoutOrder = order
		round(b, 6)
		b.MouseButton1Click:Connect(function()
			on = not on
			b.TextColor3 = on and CLR.good or CLR.dim
		end)
		return function() return on end
	end
	W.fRam    = toggle("RAM", 0)
	W.fLaunch = toggle("LAUNCH", 1)
	W.fAll    = toggle("ALL PTS", 2)
	W.fReturn = toggle("RETURN", 3)

	---------------- action row ----------------
	local act = mk("Frame", { BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30) }, body)
	act.LayoutOrder = 4
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center }, act)

	local function smallBtn(text, order, col)
		local b = mk("TextButton", {
			BackgroundColor3 = CLR.card, BorderSizePixel = 0, Size = UDim2.fromOffset(58, 30),
			Text = text, TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = col,
		}, act)
		round(b, 8); outline(b, CLR.line, 1)
		b.LayoutOrder = order
		return b
	end
	local rnd  = smallBtn("RAND", 0, CLR.txt)
	local stop = smallBtn("STOP", 1, CLR.bad)

	local fling = mk("TextButton", {
		BackgroundColor3 = CLR.acc, BorderSizePixel = 0,
		Size = UDim2.new(1, -122, 1, 0), Text = "FLING", TextSize = 14,
		Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(6, 20, 28),
	}, act)
	round(fling, 8)
	fling.LayoutOrder = 2
	W.fling = fling

	---------------- drag ----------------
	local drag, dragStart, startPos = false, nil, nil
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			drag = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if not drag then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			                          startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function() drag = false end)

	UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == CFG.Hotkey then screen.Enabled = not screen.Enabled end
	end)

	---------------- row factory ----------------
	local function buildRow(rec)
		local b = mk("TextButton", {
			BackgroundColor3 = CLR.card, BorderSizePixel = 0,
			Size = UDim2.new(1, -6, 0, 30), Text = "", LayoutOrder = 0,
		}, list)
		round(b, 6)

		local name = label(b, UDim2.fromOffset(9, 1), UDim2.new(1, -108, 0, 15),
			rec.name, 13, CLR.txt, Enum.Font.GothamSemibold)
		local dist = label(b, UDim2.fromOffset(9, 16), UDim2.new(1, -108, 0, 13), "",
			10, CLR.dim, Enum.Font.Gotham)
		local badge = mk("TextLabel", {
			BackgroundTransparency = 1, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(40, 16), Text = "", TextSize = 9,
			Font = Enum.Font.GothamBold, TextColor3 = CLR.good,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, b)

		b.MouseButton1Click:Connect(function() selectPlayer(rec.userId) end)
		return { button = b, name = name, dist = dist, badge = badge }
	end

	function W.rebuildList()
		if W.emptyLbl then W.emptyLbl:Destroy(); W.emptyLbl = nil end
		for _, r in pairs(rows) do r.button:Destroy() end
		rows = {}
		local sorted = sortedRecords()
		local online = 0
		for i, rec in ipairs(sorted) do
			local picked = rec.userId == selUserId
			local r = buildRow(rec)
			r.button.LayoutOrder = i
			r.button.BackgroundColor3 = picked and CLR.cardSel
				or (rec.leftAt and CLR.cardOut or CLR.card)
			if picked then outline(r.button, CLR.acc, 1) end
			rows[rec.userId] = r
			if not rec.leftAt then online = online + 1 end
		end
		W.count.Text = online .. " online"
		if #sorted == 0 then
			W.emptyLbl = label(list, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 24),
				"empty server", 11, CLR.dim, Enum.Font.Gotham, Enum.TextXAlignment.Center)
		end
	end

	function W.paintRows()
		for uid, r in pairs(rows) do
			local rec = Registry[uid]
			if rec then
				if rec.leftAt then
					r.badge.Text = "OUT"
					r.badge.TextColor3 = CLR.bad
					r.name.TextColor3 = CLR.dim
					r.dist.Text = "left " .. ago(rec.leftAt)
				else
					if os.clock() - rec.joinedAt < CFG.NewWindow then
						r.badge.Text = "NEW"
						r.badge.TextColor3 = CLR.warn
					else
						r.badge.Text = "IN"
						r.badge.TextColor3 = CLR.good
					end
					r.name.TextColor3 = CLR.txt
					local root = rec.player and rec.player.Character
						and rec.player.Character:FindFirstChild("HumanoidRootPart")
					if root and selfRoot then
						r.dist.Text = string.format("%d studs",
							(root.Position - selfRoot.Position).Magnitude)
					else
						r.dist.Text = "no character"
					end
				end
			end
		end
	end

	function W.say(msg, col)
		W.status.Text = msg
		W.status.TextColor3 = col or CLR.dim
	end

	function W.busy(on)
		W.fling.Text = on and "BUSY" or "FLING"
		if on then
			W.fling.BackgroundColor3 = CLR.card
			W.fling.TextColor3 = CLR.dim
		else
			W.fling.BackgroundColor3 = CLR.acc
			W.fling.TextColor3 = Color3.fromRGB(6, 20, 28)
		end
	end

	rnd.MouseButton1Click:Connect(function()
		local pool = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= PLR and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				table.insert(pool, p)
			end
		end
		if #pool > 0 then
			selectPlayer(pool[math.random(1, #pool)].UserId)
		else
			W.say("nobody to fling", CLR.warn)
		end
	end)
	stop.MouseButton1Click:Connect(function() abortFling("stopped") end)
	fling.MouseButton1Click:Connect(function() startFling() end)
end

--============================================================
-- 5. PLAYER REGISTRY  (who is new / in / out)
--============================================================
ago = function(t)
	local s = math.max(0, math.floor(os.clock() - t))
	if s < 60 then return s .. "s ago" end
	return string.format("%dm ago", math.floor(s / 60))
end

sortedRecords = function()
	local out = {}
	for _, rec in pairs(Registry) do table.insert(out, rec) end
	table.sort(out, function(a, b)
		local ao = a.leftAt and 1 or 0
		local bo = b.leftAt and 1 or 0
		if ao ~= bo then return ao < bo end
		return a.joinedAt > b.joinedAt
	end)
	return out
end

local function scanPlayers()
	for _, p in ipairs(Players:GetPlayers()) do
		local rec = Registry[p.UserId]
		if not rec then
			Registry[p.UserId] = {
				name = p.Name, userId = p.UserId, player = p,
				joinedAt = os.clock(), leftAt = nil,
			}
		else
			rec.player = p
			rec.leftAt = nil
		end
	end
	W.rebuildList()
end

Players.PlayerAdded:Connect(function(p)
	Registry[p.UserId] = {
		name = p.Name, userId = p.UserId, player = p,
		joinedAt = os.clock(), leftAt = nil,
	}
	W.rebuildList()
	W.say(p.DisplayName .. " joined", CLR.warn)
end)

Players.PlayerRemoving:Connect(function(p)
	local rec = Registry[p.UserId]
	if rec then
		rec.leftAt = os.clock()
		rec.player = nil
		if F.target == p then abortFling("target left") end
		if selUserId == p.UserId then selUserId, selPlayer = nil, nil end
	end
	W.rebuildList()
	W.say(p.DisplayName .. " left", CLR.bad)
end)

PLR.CharacterAdded:Connect(function() snapshotSelf() end)

selectPlayer = function(uid)
	selUserId = uid
	local rec = Registry[uid]
	if rec and rec.leftAt then
		selPlayer = nil
		W.rebuildList()
		return W.say((rec.name or "player") .. " already left", CLR.bad)
	end
	selPlayer = rec and rec.player or nil
	W.rebuildList()
	W.say(selPlayer and ("target: " .. selPlayer.DisplayName) or "pick a player",
		selPlayer and CLR.txt or CLR.dim)
end

--============================================================
-- 6. LOCAL-ONLY PHYSICS HELPERS
--    Nothing in this section ever writes to another player's
--    character - we only ever move OUR OWN assembly and let
--    Roblox's collision solver do the launching.
--============================================================
local function partsOf(char)
	local t = {}
	if not char then return t end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(t, d) end
	end
	return t
end

local function freezeHumanoid(hum, on)
	if not hum or hum.Parent == nil then return end
	if on then
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
		hum.PlatformStand = true
		hum.AutoRotate = false
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	else
		hum.WalkSpeed = 16
		hum.JumpPower = 50
		hum.UseJumpPower = true
		hum.JumpHeight = 7.2
		hum.AutoRotate = true
		hum.PlatformStand = false
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	end
end

snapshotSelf = function()
	selfChar  = PLR.Character
	selfRoot  = selfChar and selfChar:FindFirstChild("HumanoidRootPart")
	selfHum   = selfChar and selfChar:FindFirstChildOfClass("Humanoid")
	selfParts = partsOf(selfChar)
	savedParts, savedHum, savedRoot = {}, nil, nil
	if selfHum then
		savedHum = {
			WalkSpeed = selfHum.WalkSpeed, JumpPower = selfHum.JumpPower,
			JumpHeight = selfHum.JumpHeight, UseJumpPower = selfHum.UseJumpPower,
			AutoRotate = selfHum.AutoRotate, MaxHealth = selfHum.MaxHealth,
			Health = selfHum.Health, PlatformStand = selfHum.PlatformStand,
		}
	end
	if selfRoot then savedRoot = { Transparency = selfRoot.Transparency } end
	for _, p in ipairs(selfParts) do
		if not p:IsA("HumanoidRootPart") then
			savedParts[p] = {
				CanCollide = p.CanCollide, Massless = p.Massless,
				Transparency = p.Transparency,
			}
		end
	end
end

-- Teleport helper. Only ever used BETWEEN rams (when we are far away and
-- touching nothing) or on the way home - never during a contact, because a
-- CFrame write is a teleport and teleports transfer no momentum.
local function place(part, pos, lookDir)
	if lookDir and lookDir.Magnitude > 0.001 then
		part.CFrame = CFrame.lookAt(pos, pos + lookDir)
	else
		local cf = part.CFrame
		part.CFrame = CFrame.new(pos) * (cf - cf.Position)
	end
end

-- subtle fluctuating linear velocity
local function jitter()
	return Vector3.new(
		(math.random() * 2 - 1) * CFG.Jitter,
		(math.random() * 2 - 1) * CFG.Jitter * 0.35,
		(math.random() * 2 - 1) * CFG.Jitter)
end

-- Our body is the projectile. Every limb is welded to the root, so this one
-- assignment spins the whole body and the limb tips sweep at omega * radius.
local function spinSelf(omega)
	local root = selfRoot
	if not root or not root.Parent then return end
	pcall(function() root.AssemblyAngularVelocity = Vector3.new(0, omega, 0) end)
	if W.fAll() then
		for _, p in ipairs(selfParts) do
			if p ~= root and p.Parent then
				pcall(function() p.AssemblyAngularVelocity = Vector3.new(0, omega, 0) end)
			end
		end
	end
end

local function stopSpin()
	local root = selfRoot
	if not root or not root.Parent then return end
	pcall(function()
		root.AssemblyAngularVelocity = Vector3.zero
		root.AssemblyLinearVelocity = Vector3.zero
	end)
end

-- our body becomes the blender: solid, heavy, optionally invisible
local function prepareSelf(on)
	if not selfRoot then return end
	if on then
		for _, p in ipairs(selfParts) do
			pcall(function()
				p.CanCollide = true
				p.CanTouch = false
				p.Massless = false
				if CFG.Ghost and not p:IsA("HumanoidRootPart") then p.Transparency = 1 end
			end)
		end
		if selfHum then
			selfHum.MaxHealth = math.huge
			selfHum.Health = math.huge
			freezeHumanoid(selfHum, true)
		end
		stopSpin()
	else
		stopSpin()
		for _, p in ipairs(selfParts) do
			local s = savedParts[p]
			pcall(function()
				p.CanCollide = s and s.CanCollide or false
				p.Massless = s and s.Massless or true
				p.Transparency = s and s.Transparency or 0
			end)
		end
		if selfHum and savedHum then
			selfHum.MaxHealth = savedHum.MaxHealth
			selfHum.Health = math.min(savedHum.Health, savedHum.MaxHealth)
			freezeHumanoid(selfHum, false)
		end
	end
end

local STAGE = { WINDUP = 0, RAM = 1, LAUNCH = 2, RETURN = 3, VERIFY = 4 }
local stage = STAGE.WINDUP

local function setStage(s)
	stage = s
	F.pt = 0
end

-- read-only measurement of how far the target actually got thrown
local function targetMetrics()
	local r = F.tgtRoot
	if not r or not r.Parent then return 0, 0 end
	return r.AssemblyLinearVelocity.Magnitude, (r.Position - F.seedPos).Magnitude
end

abortFling = function(reason)
	if not F.active then return end
	F.active = false
	stopSpin()
	prepareSelf(false)
	snapshotSelf()
	F.target, F.tgtChar, F.tgtRoot = nil, nil, nil
	stage = STAGE.WINDUP
	setStage(STAGE.WINDUP)
	W.busy(false)
	W.say(reason, CLR.dim)
end

startFling = function()
	if F.active then return W.say("already flinging", CLR.warn) end
	if not selfRoot or not selfRoot.Parent then snapshotSelf() end
	if not selfRoot then return W.say("no character", CLR.bad) end
	if not selPlayer or not selPlayer.Parent then
		return W.say("select a player first", CLR.warn)
	end
	if selPlayer == PLR then return W.say("cannot fling yourself", CLR.bad) end

	local char = selPlayer.Character
	local root  = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return W.say("target has no body", CLR.bad) end

	F.active  = true
	F.target  = selPlayer
	F.tgtChar = char
	F.tgtRoot = root
	F.origin  = selfRoot.CFrame
	F.seedPos = selfRoot.Position
	F.ang     = math.random() * math.pi * 2
	F.dir     = Vector3.new(math.cos(F.ang), 0, math.sin(F.ang))
	F.ramFlat = F.dir
	F.spinSign = (CFG.SpinDir ~= 0) and CFG.SpinDir or (math.random() < 0.5 and -1 or 1)
	F.spinAngle = 0
	F.pass, F.stuck, F.ramSpeed = 0, 0, 0
	F.setup, F.lastPos = true, nil
	F.retT = CFG.ReturnTime
	F.attempt = 1
	F.ms, F.md = 0, 0
	prepareSelf(true)
	setStage(STAGE.WINDUP)
	W.busy(true)
	W.say("ramming " .. selPlayer.DisplayName .. " ...", CLR.acc)
end

--============================================================
-- 7. FLING STATE MACHINE  (local assembly only)
--============================================================
local function flingStep(dt)
	if not F.active then return end
	local root = selfRoot
	if not root or not root.Parent then return abortFling("character reset") end
	if not F.target or not F.target.Parent then return abortFling("target left") end
	F.pt = F.pt + dt

	-- follow the target across respawns (read only - never modified)
	local tr = F.tgtRoot
	if not tr or not tr.Parent then
		local c = F.target.Character
		local r2 = c and c:FindFirstChild("HumanoidRootPart")
		if not r2 then return abortFling("target respawning") end
		F.tgtChar, F.tgtRoot, tr = c, r2, r2
	end

	------------------------------------------------- WINDUP (split second)
	if stage == STAGE.WINDUP then
		if not W.fRam() then return setStage(STAGE.LAUNCH) end
		-- jump in behind them so pass 1 connects almost immediately
		local away = F.ramFlat
		place(root, tr.Position - away * CFG.StandOff + Vector3.new(0, 1.5, 0), away)
		root.AssemblyLinearVelocity = Vector3.zero
		spinSelf(F.spinSign * CFG.SpinOmega)
		if F.pt >= CFG.ApproachTime then setStage(STAGE.RAM) end

	------------------------------------------------- RAM (real momentum rams)
	elseif stage == STAGE.RAM then
		if F.setup then
			F.setup  = false
			F.pass   = F.pass + 1
			if W.fAll() then
				for _, p in ipairs(selfParts) do
					pcall(function() p.CanCollide = true; p.Massless = false end)
				end
			end
			-- aim: always straight at where they are NOW
			local aim = tr.Position - root.Position
			local flat = Vector3.new(aim.X, 0, aim.Z)
			if flat.Magnitude < 0.5 then flat = F.dir end
			F.ramFlat = flat.Unit
			-- later passes are skyward punts so they leave the map
			local up = (F.pass >= CFG.PuntFrom) and CFG.PuntUpBias or CFG.RamUpBias
			F.ramDir = (F.ramFlat + Vector3.new(0, up, 0)).Unit
			F.ramSpeed = math.min(CFG.RamSpeed + (F.pass - 1) * CFG.RamGrowth,
				CFG.MaxRamSpeed)
			-- SETUP TELEPORT: we are StandOff studs away touching nothing,
			-- so this transfers no momentum and costs us nothing
			place(root, tr.Position - F.ramFlat * CFG.StandOff + Vector3.new(0, 1.5, 0),
				F.ramFlat)
			root.AssemblyLinearVelocity = Vector3.zero
			F.lastPos = root.Position
			F.stuck = 0
			W.say(string.format("ramming %s  %d/%d  @ %d studs/s",
				F.target.DisplayName, F.pass, CFG.RamPasses, F.ramSpeed), CLR.acc)
		else
			-- >>> THE RAM: no CFrame writes at all, velocity only <<<
			-- re-pinning the velocity every frame is what keeps us at full
			-- speed, and a sustained real velocity is what the solver turns
			-- into a real impulse on the target.
			root.AssemblyLinearVelocity = F.ramDir * F.ramSpeed + jitter()
			spinSelf(F.spinSign * CFG.SpinOmega)

			-- did we actually travel, or did we slam into geometry?
			if F.lastPos then
				local moved = (root.Position - F.lastPos).Magnitude
				if moved < F.ramSpeed * dt * CFG.StuckFactor then
					F.stuck = F.stuck + 1
				else
					F.stuck = 0
				end
			end
			F.lastPos = root.Position
		end

		-- next pass, or wrap up
		if F.pt >= CFG.RamStep or F.stuck >= CFG.StuckFrames then
			F.stuck = 0
			if F.pass >= CFG.RamPasses then
				stopSpin()
				local far = (root.Position - F.origin.Position).Magnitude
				F.retT = math.clamp(far / CFG.ReturnDiv, CFG.ReturnTime, CFG.ReturnMax)
				setStage(STAGE.RETURN)
			else
				setStage(STAGE.RAM)   -- resets F.pt -> new setup teleport
				F.setup = true
			end
		end

	------------------------------------------------- LAUNCH (final skyward punt)
	elseif stage == STAGE.LAUNCH then
		-- RAM was switched off, so deliver one clean straight ram instead
		local k = math.min(F.pt / 0.30, 1)
		local up = (F.pass >= CFG.PuntFrom) and CFG.PuntUpBias or CFG.RamUpBias
		F.ramDir = (F.ramFlat + Vector3.new(0, up, 0)).Unit
		root.AssemblyLinearVelocity = F.ramDir * (CFG.RamSpeed * 2.4) + jitter()
		spinSelf(F.spinSign * CFG.SpinOmega)
		if k >= 1 then
			stopSpin()
			local far = (root.Position - F.origin.Position).Magnitude
			F.retT = math.clamp(far / CFG.ReturnDiv, CFG.ReturnTime, CFG.ReturnMax)
			setStage(STAGE.RETURN)
		end

	------------------------------------------------- RETURN (back to the spot)
	elseif stage == STAGE.RETURN then
		stopSpin()
		if W.fReturn() and F.origin then
			local k = math.min(F.pt / F.retT, 1)
			local goal = F.origin.Position + Vector3.new(0, CFG.NavHeight, 0) * k
			place(root, root.Position:Lerp(goal, math.min(dt * 14, 1)), nil)
			if k >= 1 then
				root.CFrame = F.origin
				F.ms, F.md = targetMetrics()
				setStage(STAGE.VERIFY)
			end
		else
			F.ms, F.md = targetMetrics()
			setStage(STAGE.VERIFY)
		end

	------------------------------------------------- VERIFY (try again if weak)
	elseif stage == STAGE.VERIFY then
		local _, d2 = targetMetrics()
		local sp = math.max(F.ms, d2)
		local name = F.target and F.target.DisplayName or "target"
		if sp >= CFG.SuccessSpeed or d2 >= CFG.SuccessDist then
			return abortFling(string.format("%s launched - %d studs @ %d studs/s",
				name, math.floor(math.max(d2, F.md)), math.floor(sp)))
		end
		if F.attempt >= CFG.MaxAttempts then
			return abortFling(string.format("weak result on %s (%d studs)", name, math.floor(d2)))
		end
		F.attempt = F.attempt + 1
		F.ang = F.ang + 0.9
		F.dir = Vector3.new(math.cos(F.ang), 0, math.sin(F.ang))
		if CFG.SpinDir == 0 then
			F.spinSign = math.random() < 0.5 and -1 or 1
		end
		F.spinAngle = 0
		F.pass, F.stuck = 0, 0
		F.setup, F.lastPos = true, nil
		F.ramFlat = F.dir
		W.say(string.format("retry %d/%d on %s", F.attempt, CFG.MaxAttempts, name), CLR.warn)
		setStage(STAGE.WINDUP)
	end
end

--============================================================
-- 8. BOOT + LOOPS
--============================================================
snapshotSelf()
buildGUI()
scanPlayers()
W.say(string.format("Ready - %d player(s) online", #Players:GetPlayers()), CLR.dim)

PLR.CharacterRemoving:Connect(function()
	if F.active then abortFling("character reset") end
end)

RunService.Heartbeat:Connect(flingStep)

local paintAt = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - paintAt < 0.2 then return end
	paintAt = now
	W.paintRows()
end)
