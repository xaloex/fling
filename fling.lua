--[[
	============================================================
	 FLING RIG  -  ONE FILE, CLIENT SIDE ONLY
	 No RemoteEvents. No server Scripts. Paste once and play.
	 Physics: Humanoid Physics state + glued CFrame + 3-AXIS
	          tumble (AssemblyAngularVelocity on X/Y/Z) with a
	          small upward push. The target is launched purely by
	          Roblox's collision solver hitting our own limbs.
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

	ApproachTime = 0.05,            -- split second to line up before a punch
	StandOff     = 3,               -- start the pass ALREADY touching them
	Punches      = 7,               -- ram passes per fling
	PunchStep    = 0.11,            -- seconds of ram per pass
	ReleaseTime  = 0.05,            -- one frame to deliver the kick
	RamSpeed     = 2000,            -- drive speed straight through them
	RamRamp      = 400,             -- added per punch
	MaxRamSpeed  = 4200,            -- hard cap on the ram
	RamUp        = 220,             -- lift while passing through
	PopUp        = 1700,            -- upward kick on the release frame
	KickOut      = 0.8,             -- fraction of ram speed kept on the kick
	Leash        = 300,             -- let go once they are this far from the start

	-- 3-AXIS tumble. Single-axis spin just parts them aside; all three
	-- axes at once grinds the body into the target from every angle.
	TumbleX      = 16000,
	TumbleY      = 15999,
	TumbleZ      = -15999,
	SpinDir      = 0,               -- 0 = randomise per attempt, +1 / -1 = fixed

	AllDelay     = 0.70,            -- seconds between players in FLING ALL
	DetachDist   = 10,              -- how far to jump clear of the target on stop

	-- NOCLIP. The root can never be stopped or wedged by terrain, and if a
	-- wall does block the ram we phase straight through it. Our LIMBS stay
	-- collidable - that is the only way we can still launch anybody.
	Noclip       = true,
	PhaseStep    = 12,              -- studs teleported per phase-through

	-- INERTIA. Invisible heavy parts welded to our root. Making our own
	-- assembly ~100x heavier means the reaction from every single hit has
	-- nowhere to go except into the target, so we are the one thing in this
	-- script that cannot be knocked across the map.
	Ballast      = 8,               -- number of welded mass blocks
	BallastSize  = 10,              -- 10^3 studs each -> ~700 mass apiece

	VoidY        = -150,            -- below this WE fell out: go home immediately
	ReturnSnap   = 140,             -- further than this from home -> teleport
	ReturnTime   = 0.50,
	NavHeight    = 40,              -- height used while coming home

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
	active    = false,
	target    = nil,
	tgtChar   = nil,
	tgtRoot   = nil,
	pt        = 0,       -- time inside current stage
	attempt   = 0,
	punch     = 0,       -- which glued pass we are on
	kicked    = false,   -- has this pass had its kick frame yet
	lastPos   = nil,     -- last frame position, for the noclip phase check
	dir       = Vector3.new(1, 0, 0),   -- throw direction (horizontal)
	ang       = 0,
	spinSign  = 1,
	origin    = nil,     -- where the throw started (we come back here)
	seedPos   = nil,
	retSnap   = true,    -- first RETURN frame decides snap vs fly home
	ms, md    = 0, 0,
}

local selfChar, selfRoot, selfHum, selfParts = nil, nil, nil, {}
local savedParts, savedHum, savedRoot = {}, nil, nil
local ballast = {}   -- our welded mass blocks, destroyed when the fling ends

local W   = {}        -- gui widgets + gui functions
local rows = {}       -- built row widgets, keyed by userId

local ago, sortedRecords, selectPlayer, snapshotSelf, abortFling, startFling
local queueOn, queueStart, queueStep

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
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 428),
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
			BackgroundColor3 = CLR.card, BorderSizePixel = 0, Size = UDim2.fromOffset(52, 22),
			Text = text, TextSize = 9, Font = Enum.Font.GothamBold,
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
	W.fNoclip = toggle("CLIP", 0)
	W.fRam    = toggle("RAM", 1)
	W.fLaunch = toggle("LAUNCH", 2)
	W.fAll    = toggle("PARTS", 3)
	W.fReturn = toggle("RETURN", 4)

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

	local act2 = mk("Frame", { BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30) }, body)
	act2.LayoutOrder = 5

	local flingAll = mk("TextButton", {
		BackgroundColor3 = CLR.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
		Text = "FLING ALL", TextSize = 13, Font = Enum.Font.GothamBold,
		TextColor3 = CLR.warn,
	}, act2)
	round(flingAll, 8)
	outline(flingAll, CLR.line, 1)
	W.flingAll = flingAll

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
	stop.MouseButton1Click:Connect(function()
		queueOn = false
		abortFling("stopped")
	end)
	fling.MouseButton1Click:Connect(function()
		queueOn = false
		startFling()
	end)
	flingAll.MouseButton1Click:Connect(function() queueStart() end)
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
--    Nothing here ever writes to another player's character.
--============================================================
local function partsOf(char)
	local t = {}
	if not char then return t end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(t, d) end
	end
	return t
end

-- HumanoidStateType.Physics: "the Humanoid doesn't apply any force on its
-- own" -> we get clean, exclusive control of our own assembly.
-- (StrafingNoPhysics CANNOT be set via ChangeState, so it is not used here.)
local function controlSelf(on)
	local hum = selfHum
	if not hum or hum.Parent == nil then return end
	if on then
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
		hum.PlatformStand = true
		hum.AutoRotate = false
	else
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
		hum.PlatformStand = false
		hum.AutoRotate = true
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
			BreakJointsOnDeath = selfHum.BreakJointsOnDeath,
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

-- place our root without clobbering the rotation the physics gave us,
-- so the tumble stays visible while we stay glued to the target
local function pinTo(part, pos)
	local cf = part.CFrame
	part.CFrame = CFrame.new(pos) * (cf - cf.Position)
end

-- same, but for free placement (teleports between stages / coming home)
local function place(part, pos)
	local cf = part.CFrame
	part.CFrame = CFrame.new(pos) * (cf - cf.Position)
end

-- THE FLING. Three-axis tumble on our own assembly: every limb is welded
-- to the root, so this spins the whole body and the limb tips sweep at
-- omega * radius straight through the target.
local function tumbleSelf(sign)
	local root = selfRoot
	if not root or not root.Parent then return end
	local av = Vector3.new(CFG.TumbleX, CFG.TumbleY, CFG.TumbleZ) * sign
	pcall(function() root.AssemblyAngularVelocity = av end)
	if W.fAll() then
		for _, p in ipairs(selfParts) do
			if p ~= root and p.Parent then
				pcall(function() p.AssemblyAngularVelocity = av end)
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

-- never die, and stay put
local function keepAlive()
	local hum = selfHum
	if hum and hum.Parent then
		hum.MaxHealth = 1e9
		if hum.Health < 1e8 then hum.Health = 1e9 end
		hum.BreakJointsOnDeath = false
	end
end

--============================================================
-- INERTIA / NOCLIP ballast
-- Mass does not depend on collision, so these blocks are invisible and
-- non-colliding - they only add weight. Welded to the root they merge into
-- one assembly, and the heavier it is the less any impulse can move us.
--============================================================
local function clearBallast()
	for _, p in ipairs(ballast) do
		if p and p.Parent then p:Destroy() end
	end
	ballast = {}
end

local function addBallast()
	clearBallast()
	local root = selfRoot
	if not root or not root.Parent then return end
	for _ = 1, CFG.Ballast do
		local ok, p = pcall(function()
			local q = Instance.new("Part")
			q.Name = "FlingMass"
			q.Size = Vector3.new(CFG.BallastSize, CFG.BallastSize, CFG.BallastSize)
			q.Anchored = false
			q.CanCollide = false
			q.CanTouch = false
			q.CanQuery = false
			q.Massless = false
			q.Transparency = 1
			q.Material = Enum.Material.SmoothPlastic
			q.CFrame = root.CFrame
			q.Parent = workspace
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = q
			w.Parent = q
			pcall(function() q:SetNetworkOwner(PLR) end)
			return q
		end)
		if ok and p then table.insert(ballast, p) end
	end
	-- make sure we still own our own body after welding new mass to it
	pcall(function() root:SetNetworkOwner(PLR) end)
end

-- our body is the projectile: solid, heavy, optionally invisible
local function prepareSelf(on)
	if not selfRoot then return end
	if on then
		-- LIMBS stay collidable - that is the only thing that can launch
		-- anybody. The ROOT goes non-colliding so terrain can never wedge
		-- or stop us (noclip).
		for _, p in ipairs(selfParts) do
			pcall(function()
				p.CanCollide = not p:IsA("HumanoidRootPart")
				p.CanTouch = false
				p.CanQuery = not p:IsA("HumanoidRootPart")
				p.Massless = false
				if CFG.Ghost and not p:IsA("HumanoidRootPart") then p.Transparency = 1 end
			end)
		end
		if selfHum then
			selfHum.MaxHealth = 1e9
			selfHum.Health = 1e9
			selfHum.BreakJointsOnDeath = false
		end
		controlSelf(true)
		stopSpin()
		-- heavy invisible mass: every impact goes into the target, not us
		addBallast()
	else
		stopSpin()
		controlSelf(false)
		clearBallast()
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
			selfHum.BreakJointsOnDeath = savedHum.BreakJointsOnDeath
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

-- Get OUT of their body before we stop driving. If we just zero the
-- velocities while still deeply overlapped, the solver resolves all that
-- penetration in one go and bats the target away on its own - that is the
-- "I pressed STOP and it flung him anyway" bug. Teleporting out removes the
-- overlap instead, so there is nothing left to resolve.
local function detachFromTarget()
	local root = selfRoot
	if not root or not root.Parent then return end
	stopSpin()
	local tr = F.tgtRoot
	if tr and tr.Parent then
		local away = root.Position - tr.Position
		if away.Magnitude < 0.01 then away = F.dir end
		place(root, tr.Position + away.Unit * CFG.DetachDist + Vector3.new(0, 1, 0))
	end
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

local function goHome()
	stopSpin()
	F.retSnap = true
	setStage(STAGE.RETURN)
end

--============================================================
-- FLING ALL - queue every other player, one after another
--============================================================
local queue, queueAt = {}, 0

queueStart = function()
	if F.active then return W.say("busy - stop first", CLR.warn) end
	queue = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= PLR and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(queue, p.UserId)
		end
	end
	if #queue == 0 then return W.say("nobody to fling", CLR.warn) end
	queueOn = true
	queueAt = 0
	W.say(string.format("fling all: %d queued", #queue), CLR.warn)
end

queueStep = function()
	if not queueOn or F.active then return end
	if #queue == 0 then
		queueOn = false
		W.say("fling all done", CLR.good)
		return
	end
	if os.clock() < queueAt then return end

	-- pull the next player who is still here with a body
	local uid
	while #queue > 0 do
		local u = table.remove(queue, 1)
		local rec = Registry[u]
		if rec and rec.player and rec.player.Parent and rec.player.Character
			and rec.player.Character:FindFirstChild("HumanoidRootPart") then
			uid = u
			break
		end
	end
	if not uid then
		queueOn = false
		return W.say("fling all done", CLR.good)
	end

	selectPlayer(uid)
	startFling()
	queueAt = os.clock() + CFG.AllDelay
end

abortFling = function(reason)
	if not F.active then return end
	F.active = false
	detachFromTarget()
	prepareSelf(false)
	clearBallast()
	snapshotSelf()
	F.target, F.tgtChar, F.tgtRoot = nil, nil, nil
	stage = STAGE.WINDUP
	setStage(STAGE.WINDUP)
	W.busy(false)
	W.say(reason, CLR.dim)
	-- FLING ALL: keep going with the next one
	if queueOn then queueAt = os.clock() + CFG.AllDelay end
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

	F.active   = true
	F.target   = selPlayer
	F.tgtChar  = char
	F.tgtRoot  = root
	F.origin   = selfRoot.CFrame
	F.seedPos  = selfRoot.Position
	F.ang      = math.random() * math.pi * 2
	F.dir      = Vector3.new(math.cos(F.ang), 0, math.sin(F.ang))
	F.spinSign = (CFG.SpinDir ~= 0) and CFG.SpinDir or (math.random() < 0.5 and -1 or 1)
	F.punch = 0
	F.retSnap  = true
	F.attempt  = 1
	F.ms, F.md = 0, 0
	prepareSelf(true)
	setStage(STAGE.WINDUP)
	W.busy(true)
	W.say("flinging " .. selPlayer.DisplayName .. " ...", CLR.acc)
end

--============================================================
-- 7. FLING STATE MACHINE
--============================================================
local function flingStep(dt)
	if not F.active then return end
	local root = selfRoot
	if not root or not root.Parent then return abortFling("character reset") end
	if not F.target or not F.target.Parent then return abortFling("target left") end
	F.pt = F.pt + dt

	keepAlive()

	-- if we ourselves fell out of the world, go home immediately
	if root.Position.Y < CFG.VoidY then return goHome() end

	-- follow the target across respawns (read only - never modified)
	local tr = F.tgtRoot
	if not tr or not tr.Parent then
		local c = F.target.Character
		local r2 = c and c:FindFirstChild("HumanoidRootPart")
		if not r2 then return abortFling("target respawning") end
		F.tgtChar, F.tgtRoot, tr = c, r2, r2
	end

	------------------------------------------------- WINDUP (line up touching)
	if stage == STAGE.WINDUP then
		if not W.fRam() then return setStage(STAGE.LAUNCH) end
		controlSelf(true)
		F.punch = F.punch + 1
		F.kicked = false
		-- aim at where they are NOW, then stand off just close enough that
		-- our limbs are already brushing them
		local aim = tr.Position - root.Position
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude < 0.5 then flat = F.dir end
		F.dir = flat.Unit
		place(root, tr.Position - F.dir * CFG.StandOff + Vector3.new(0, 0.5, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.CanCollide = false      -- noclip while flinging
		tumbleSelf(F.spinSign)
		F.lastPos = root.Position
		W.say(string.format("punching %s  %d/%d", F.target.DisplayName,
			F.punch, CFG.Punches), CLR.acc)
		if F.pt >= CFG.ApproachTime then setStage(STAGE.RAM) end

	------------------------------------------------- RAM (drive THROUGH them)
	elseif stage == STAGE.RAM then
		controlSelf(true)
		root.CanCollide = false
		-- NO position pinning. Pinning let the solver push us out every
		-- frame, so the overlap never got deep and the impulse stayed weak.
		tumbleSelf(F.spinSign)
		local speed = math.min(CFG.RamSpeed + (F.punch - 1) * CFG.RamRamp,
			CFG.MaxRamSpeed)
		root.AssemblyLinearVelocity = F.dir * speed + Vector3.new(0, CFG.RamUp, 0)

		-- NOCLIP: if terrain ate our travel we phase straight through it
		if W.fNoclip() and F.lastPos then
			local want = speed * dt
			local got = (root.Position - F.lastPos).Magnitude
			if got < want * 0.4 then
				place(root, root.Position + F.dir * CFG.PhaseStep)
			end
			F.lastPos = root.Position
		else
			F.lastPos = root.Position
		end

		if F.pt >= CFG.PunchStep then setStage(STAGE.LAUNCH) end

	------------------------------------------------- LAUNCH (the kick frame)
	elseif stage == STAGE.LAUNCH then
		controlSelf(true)
		root.CanCollide = false
		if not F.kicked then
			F.kicked = true
			tumbleSelf(F.spinSign)
			root.AssemblyLinearVelocity = F.dir * (CFG.RamSpeed * CFG.KickOut)
				+ Vector3.new(0, CFG.PopUp, 0)
		else
			-- kick delivered: clear out and stop
			stopSpin()
			detachFromTarget()
			if (tr.Position - F.seedPos).Magnitude > CFG.Leash then
				return goHome()
			end
			if W.fLaunch() and F.punch < CFG.Punches then
				F.retSnap = true
				return setStage(STAGE.WINDUP)
			end
			goHome()
		end

	------------------------------------------------- RETURN
	elseif stage == STAGE.RETURN then
		stopSpin()
		controlSelf(false)
		if W.fReturn() and F.origin then
			local home = F.origin.Position
			-- first frame: get clear of the target cleanly, and if we are too
			-- far out to fly home (terrain / void on the way) just teleport
			if F.retSnap then
				F.retSnap = false
				detachFromTarget()
				if (root.Position - home).Magnitude > CFG.ReturnSnap then
					place(root, home + Vector3.new(0, CFG.NavHeight, 0))
					pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
				end
			end

			local k = math.min(F.pt / CFG.ReturnTime, 1)
			local goal = home + Vector3.new(0, CFG.NavHeight, 0) * k
			place(root, root.Position:Lerp(goal, math.min(dt * 14, 1)))
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
		F.punch = 0
		F.retSnap = true
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
	clearBallast()
	if F.active then abortFling("character reset") end
end)

RunService.Heartbeat:Connect(flingStep)

local paintAt = 0
RunService.RenderStepped:Connect(function()
	queueStep()
	local now = os.clock()
	if now - paintAt < 0.2 then return end
	paintAt = now
	W.paintRows()
end)
