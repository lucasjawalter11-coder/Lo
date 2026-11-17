--!nonstrict
-- CombatClient: the player's side of fighting. Reads keyboard/mouse, controller and touch input, picks the
-- right move (chains, launchers, air attacks, dash attacks, counters), plays it instantly, moves the
-- character, and draws the combat HUD and duel screens.
--
--   PC:          left click light · R heavy (hold to charge) · Q dash · F guard (hold)
--                1 / 2 / 3 skills · G ultimate · Space jump (right after a launcher: pursuit jump)
--   Controller:  X light · Y heavy · B dash · RB guard · RT / LT / LB skills · R3 ultimate · A jump
--   Touch:       on-screen buttons
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local CombatClient = {}

local C = Config.Combat
local player = Players.LocalPlayer
local Animator, Fx
local remotes, CombatRemote, DuelRemote

local st = {
	chain = 0, lastLightEnd = 0, airChain = 0, lastDash = 0, airDashes = 0,
	stunUntil = 0, counterUntil = 0, heavyHeld = nil, guarding = false,
	cooldowns = {}, buffered = nil, launchedAt = 0, frozenUntil = 0, inMenu = false,
	hover = nil, pushes = {}, lastMove = nil, moveStart = 0,
}

local function now(): number
	return os.clock()
end

local function character()
	local c = player.Character
	if c and c:GetAttribute("Fighter") then
		return c
	end
	return nil
end

local function rootOf(c: Model?)
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(c: Model?)
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function weapon(): string
	local c = character()
	return (c and c:GetAttribute("Weapon")) or "saber"
end

local function inAir(): boolean
	local hum = humanoidOf(character())
	return hum ~= nil and hum.FloorMaterial == Enum.Material.Air
end

-- ---------------------------------------------------------------------------------------------
-- Moving the character (the client owns its own physics)
-- ---------------------------------------------------------------------------------------------
local function velocity(v: Vector3, duration: number, keepY: boolean?)
	local root = rootOf(character())
	if not root then
		return
	end
	local att = root:FindFirstChild("HalcyonMotion") or Instance.new("Attachment")
	att.Name = "HalcyonMotion"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	if keepY then
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		lv.PlaneVelocity = Vector2.new(v.X, v.Z)
		lv.MaxForce = 4e5
	else
		lv.VectorVelocity = v
		lv.MaxForce = 1e6
	end
	lv.Parent = root
	task.delay(duration, function()
		lv:Destroy()
	end)
end

--- Turns to face the nearest rival in front of the camera (soft lock-on).
local function faceTarget(range: number)
	local c = character()
	local root = rootOf(c)
	if not root then
		return nil
	end
	local camLook = Workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local best, bestScore = nil, math.huge
	local function consider(m: Model)
		if m == c or not m:GetAttribute("Fighter") then
			return
		end
		local r = m:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local d = (r.Position - root.Position) * Vector3.new(1, 0, 1)
		local dist = d.Magnitude
		if dist > range or dist < 0.5 then
			return
		end
		local facing = if camLook.Magnitude > 0.01 then camLook.Unit:Dot(d.Unit) else 0
		local score = dist * (1.6 - facing)
		if score < bestScore then
			best, bestScore = r, score
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			consider(p.Character)
		end
	end
	for _, child in Workspace:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Duel_" then
			for _, m in child:GetChildren() do
				if m:IsA("Model") then
					consider(m)
				end
			end
		end
	end
	local world = Workspace:FindFirstChild(Config.WorldName)
	if world and not best then
		for _, d in world:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Dummy") then
				local r = d.PrimaryPart
				if r and (r.Position - root.Position).Magnitude < range then
					best = r
					break
				end
			end
		end
	end
	if best then
		local d = (best.Position - root.Position) * Vector3.new(1, 0, 1)
		if d.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + d)
		end
	elseif camLook.Magnitude > 0.01 and not UserInputService.TouchEnabled then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + camLook)
	end
	return best
end

-- ---------------------------------------------------------------------------------------------
-- Starting moves
-- ---------------------------------------------------------------------------------------------
local function busyUntil(): number
	local move = st.lastMove
	if not move then
		return 0
	end
	return st.moveStart + move.cancel
end

local function canAct(): boolean
	local c = character()
	if not c or st.inMenu or now() < st.frozenUntil then
		return false
	end
	local state = c:GetAttribute("State")
	if state == "down" or state == "ko" or state == "getup" then
		return false
	end
	if now() < st.stunUntil then
		return false
	end
	return now() >= busyUntil()
end

local function lumen(): number
	local c = character()
	return (c and c:GetAttribute("Lumen")) or 0
end

local function doMove(id: string, charge: number?): boolean
	local move = Moves.get(id)
	local c = character()
	if not move or not c then
		return false
	end
	if move.cost and lumen() + 0.5 < move.cost then
		return false
	end
	local cd = st.cooldowns[id]
	if cd and now() < cd then
		return false
	end
	faceTarget(if move.proj or move.beam then 60 else 22)
	st.lastMove = move
	st.moveStart = now()
	if move.cd then
		st.cooldowns[id] = now() + move.cd
	end
	if st.guarding then
		st.guarding = false
		Animator.setGuard(c, false)
		CombatRemote:FireServer("guard", false)
	end
	Animator.play(c, id)
	CombatRemote:FireServer("move", id, charge or 0)
	-- the move's own movement
	local root = rootOf(c)
	for _, m in move.motion or {} do
		task.delay(m.t0, function()
			if st.lastMove ~= move or not root.Parent then
				return
			end
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
			local fwd = m.fwd or 0
			if m.seek then
				local target = faceTarget(50)
				if target then
					local d = (target.Position - root.Position) * Vector3.new(1, 0, 1)
					fwd = math.min(fwd, d.Magnitude / math.max(0.05, m.t1 - m.t0))
				end
			end
			if m.hoverHold then
				st.hover = { until_ = now() + (m.t1 - m.t0) }
			else
				velocity(look * fwd + Vector3.new(0, m.up or 0, 0), math.max(0.05, m.t1 - m.t0), m.up == nil)
			end
		end)
	end
	if move.hover and inAir() then
		st.hover = { until_ = now() + move.dur }
	end
	if move.kind == "launcher" then
		st.launchedAt = now()
	end
	return true
end

local function lightPressed()
	if not canAct() then
		st.buffered = { kind = "light", at = now() }
		return
	end
	local w = weapon()
	local t = now()
	if t < st.counterUntil then
		st.counterUntil = 0
		doMove(w .. "_counter")
		return
	end
	if inAir() then
		st.airChain = (st.airChain % 3) + 1
		doMove(w .. "_a" .. st.airChain)
		return
	end
	if t - st.lastDash < 0.3 then
		doMove(w .. "_dash")
		return
	end
	if t - st.lastLightEnd > 0.7 or st.chain >= 4 then
		st.chain = 0
	end
	st.chain += 1
	if doMove(w .. "_l" .. st.chain) then
		st.lastLightEnd = t + (st.lastMove and st.lastMove.dur or 0.4)
	end
end

local function heavyReleased(held: number)
	if not canAct() then
		st.buffered = { kind = "heavy", at = now(), held = held }
		return
	end
	local w = weapon()
	local t = now()
	if st.chain >= 2 and t - st.lastLightEnd < 0.5 then
		st.chain = 0
		doMove(w .. "_launch")
	elseif inAir() then
		doMove(w .. "_plunge")
	else
		st.chain = 0
		doMove(w .. "_heavy", math.clamp(held / 0.8, 0, 1))
	end
end

local function skill(slot: number)
	if not canAct() then
		st.buffered = { kind = "skill", slot = slot, at = now() }
		return
	end
	local w = weapon()
	doMove(if slot == 4 then w .. "_ult" else w .. "_s" .. slot)
end

local function dash()
	local c = character()
	local root, hum = rootOf(c), humanoidOf(c)
	if not root or not hum or st.inMenu or now() < st.frozenUntil then
		return
	end
	local state = c:GetAttribute("State")
	if state == "down" or state == "ko" then
		return
	end
	local stunned = now() < st.stunUntil
	if stunned and lumen() < C.BreakAwayCost then
		return
	end
	if now() - st.lastDash < C.DashCooldown * 0.45 then
		return
	end
	if not stunned and st.lastMove and now() < st.moveStart + st.lastMove.cancel * 0.6 then
		return
	end
	if inAir() then
		if st.airDashes >= 1 then
			return
		end
		st.airDashes += 1
	end
	local dir = hum.MoveDirection * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	dir = dir.Unit
	st.lastDash = now()
	st.lastMove = nil
	st.stunUntil = 0
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	Animator.dash(c)
	velocity(dir * C.DashSpeed + Vector3.new(0, if inAir() then 4 else 0, 0), C.DashTime)
	Fx.afterimage(c, (Weapons.List[weapon()] or Weapons.List.saber).color)
	Fx.sound("Dash", root.Position)
	CombatRemote:FireServer("dash", dir)
end

local function setGuard(on: boolean)
	local c = character()
	if not c or st.inMenu then
		return
	end
	if on and (now() < st.stunUntil or (st.lastMove and now() < busyUntil())) then
		st.wantGuard = true
		return
	end
	st.wantGuard = false
	st.guarding = on
	if on then
		st.lastMove = nil
		Animator.stop(c)
	end
	Animator.setGuard(c, on)
	CombatRemote:FireServer("guard", on)
end

local function pursuitJump()
	local root = rootOf(character())
	if root and now() - st.launchedAt < 0.9 then
		st.launchedAt = 0
		local target = faceTarget(30)
		local fwd = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if target then
			local d = (target.Position - root.Position) * Vector3.new(1, 0, 1)
			fwd = if d.Magnitude > 0.1 then d.Unit * math.min(30, d.Magnitude * 3) else Vector3.zero
		end
		velocity(fwd + Vector3.new(0, 62, 0), 0.22)
		st.airChain = 0
	end
end

-- ---------------------------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------------------------
local KEY = {
	[Enum.UserInputType.MouseButton1] = "light", [Enum.KeyCode.ButtonX] = "light",
	[Enum.KeyCode.R] = "heavy", [Enum.KeyCode.ButtonY] = "heavy",
	[Enum.KeyCode.Q] = "dash", [Enum.KeyCode.ButtonB] = "dash",
	[Enum.KeyCode.F] = "guard", [Enum.KeyCode.ButtonR1] = "guard",
	[Enum.KeyCode.One] = "s1", [Enum.KeyCode.ButtonR2] = "s1",
	[Enum.KeyCode.Two] = "s2", [Enum.KeyCode.ButtonL2] = "s2",
	[Enum.KeyCode.Three] = "s3", [Enum.KeyCode.ButtonL1] = "s3",
	[Enum.KeyCode.G] = "ult", [Enum.KeyCode.ButtonR3] = "ult",
	[Enum.KeyCode.Space] = "jump", [Enum.KeyCode.ButtonA] = "jump",
}

local function press(action: string)
	if action == "light" then
		lightPressed()
	elseif action == "heavy" then
		st.heavyHeld = now()
		local c = character()
		if c then
			c:SetAttribute("Charging", true)
		end
	elseif action == "dash" then
		dash()
	elseif action == "guard" then
		setGuard(true)
	elseif action == "s1" then
		skill(1)
	elseif action == "s2" then
		skill(2)
	elseif action == "s3" then
		skill(3)
	elseif action == "ult" then
		skill(4)
	elseif action == "jump" then
		pursuitJump()
	end
end

local function release(action: string)
	if action == "heavy" and st.heavyHeld then
		local held = now() - st.heavyHeld
		st.heavyHeld = nil
		heavyReleased(held)
	elseif action == "guard" then
		st.wantGuard = false
		if st.guarding then
			setGuard(false)
		end
	end
end

local function inputKey(input: InputObject)
	return KEY[input.KeyCode] or KEY[input.UserInputType]
end

-- ---------------------------------------------------------------------------------------------
-- HUD
-- ---------------------------------------------------------------------------------------------
local hud = {}

local function make(className: string, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function bar(parent, pos: UDim2, size: UDim2, color: Color3)
	local back = make("Frame", { Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(14, 18, 34), BackgroundTransparency = 0.15, BorderSizePixel = 0 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, back)
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, fill)
	local lag = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 0 }, back)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, lag)
	return { back = back, fill = fill, lag = lag, shown = 1, lagged = 1 }
end

local function setBar(b, frac: number, dt: number)
	frac = math.clamp(frac, 0, 1)
	b.shown += (frac - b.shown) * math.min(1, dt * 18)
	b.lagged = if frac > b.lagged then frac else b.lagged + (frac - b.lagged) * math.min(1, dt * 2.5)
	b.fill.Size = UDim2.fromScale(b.shown, 1)
	b.lag.Size = UDim2.fromScale(b.lagged, 1)
end

local function label(parent, text: string, props)
	local l = make("TextLabel", { BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(240, 244, 252), TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end

local function buildHud(playerGui)
	local gui = make("ScreenGui", { Name = "HalcyonCombat", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Enabled = false }, playerGui)
	hud.gui = gui
	local panel = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0.44, 0, 0, 120), BackgroundTransparency = 1 }, gui)
	make("UISizeConstraint", { MinSize = Vector2.new(320, 110), MaxSize = Vector2.new(640, 130) }, panel)
	hud.name = label(panel, "", { Size = UDim2.new(0.6, 0, 0, 20) })
	hud.hpText = label(panel, "", { Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamMedium })
	hud.hp = bar(panel, UDim2.new(0, 0, 0, 22), UDim2.new(1, 0, 0, 16), Color3.fromRGB(110, 235, 140))
	hud.lumen = bar(panel, UDim2.new(0, 0, 0, 42), UDim2.new(1, 0, 0, 9), Color3.fromRGB(111, 230, 255))
	for k = 1, 3 do
		make("Frame", { Position = UDim2.new(k * 0.25, -1, 0, 42), Size = UDim2.new(0, 2, 0, 9), BackgroundColor3 = Color3.fromRGB(10, 13, 26), BorderSizePixel = 0, ZIndex = 3 }, panel)
	end
	hud.guard = bar(panel, UDim2.new(0, 0, 0, 55), UDim2.new(0.5, 0, 0, 4), Color3.fromRGB(150, 180, 255))
	local row = make("Frame", { Position = UDim2.new(0, 0, 0, 66), Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, panel)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.015, 0) }, row)
	hud.slots = {}
	local keys = { "1", "2", "3", "G" }
	for i = 1, 4 do
		local slot = make("Frame", { Size = UDim2.new(0.2375, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(16, 21, 40), BackgroundTransparency = 0.1, LayoutOrder = i }, row)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, slot)
		local stroke = make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(111, 230, 255), Transparency = 0.5 }, slot)
		local key = label(slot, keys[i], { Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(0, 18, 0, 16), TextColor3 = Color3.fromRGB(255, 201, 74), Font = Enum.Font.GothamBlack })
		local name = label(slot, "", { Position = UDim2.new(0, 6, 0, 22), Size = UDim2.new(1, -12, 0, 16), Font = Enum.Font.GothamBold })
		local cost = label(slot, "", { Position = UDim2.new(0, 6, 1, -14), Size = UDim2.new(1, -12, 0, 11), TextColor3 = Color3.fromRGB(150, 160, 190), Font = Enum.Font.Gotham })
		local cover = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0 }, slot)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, cover)
		hud.slots[i] = { frame = slot, stroke = stroke, key = key, name = name, cost = cost, cover = cover }
	end
	-- combo counter
	hud.combo = label(gui, "", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -30, 0.42, 0), Size = UDim2.new(0, 220, 0, 64), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 201, 74), TextTransparency = 1, TextStrokeTransparency = 1 })
	-- rival bar (whoever you hit last)
	local rival = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.new(0.34, 0, 0, 40), BackgroundTransparency = 1, Visible = false }, gui)
	hud.rival = rival
	hud.rivalName = label(rival, "", { Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
	hud.rivalHp = bar(rival, UDim2.new(0, 0, 0, 20), UDim2.new(1, 0, 0, 12), Color3.fromRGB(255, 110, 110))
	-- control hint
	hud.hint = label(gui, "", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12), Size = UDim2.new(0.3, 0, 0, 14), TextColor3 = Color3.fromRGB(150, 160, 190), Font = Enum.Font.Gotham })
	-- duel overlays
	hud.banner = label(gui, "", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.7, 0, 0, 90), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextTransparency = 1, TextStrokeTransparency = 1 })
	hud.sub = label(gui, "", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.6, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamMedium, TextTransparency = 1 })
	hud.timer = label(gui, "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 120, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, Visible = false })
end

local function banner(text: string, sub: string?, color: Color3?, hold: number?)
	hud.banner.Text = text
	hud.banner.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	hud.banner.TextTransparency = 0
	hud.banner.TextStrokeTransparency = 0.3
	hud.banner.Size = UDim2.new(0.9, 0, 0, 110)
	TweenService:Create(hud.banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0.7, 0, 0, 90) }):Play()
	hud.sub.Text = sub or ""
	hud.sub.TextTransparency = if sub then 0 else 1
	task.delay(hold or 1.2, function()
		if hud.banner.Text == text then
			TweenService:Create(hud.banner, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(hud.sub, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	end)
end

local lastCombo, comboShownAt = 0, 0
local rivalModel = nil

local function updateHud(dt: number)
	local c = character()
	hud.gui.Enabled = c ~= nil and not st.inMenu
	if not c then
		return
	end
	local hp, maxHp = c:GetAttribute("HP") or 0, c:GetAttribute("MaxHP") or 1
	hud.name.Text = player.DisplayName .. "  ·  " .. ((Weapons.List[weapon()] or Weapons.List.saber).name)
	hud.hpText.Text = string.format("%d / %d", hp, maxHp)
	setBar(hud.hp, hp / maxHp, dt)
	local lum = c:GetAttribute("Lumen") or 0
	setBar(hud.lumen, lum / C.LumenMax, dt)
	setBar(hud.guard, (c:GetAttribute("GuardMeter") or 100) / 100, dt)
	local skills = Moves.skillsOf(weapon())
	for i, slot in hud.slots do
		local move = skills[i]
		if move then
			slot.name.Text = move.name
			slot.cost.Text = if i == 4 then "Full Lumen" else (tostring(move.cost) .. " Lumen")
			local cd = st.cooldowns[move.id]
			local left = if cd then math.max(0, cd - now()) else 0
			slot.cover.Size = UDim2.fromScale(1, if move.cd and move.cd > 0 then left / move.cd else 0)
			local ready = left <= 0 and lum + 0.5 >= (move.cost or 0)
			slot.stroke.Transparency = if ready then 0 else 0.7
			slot.stroke.Color = if i == 4 and ready then Color3.fromRGB(255, 201, 74) else Color3.fromRGB(111, 230, 255)
		end
	end
	local combo = c:GetAttribute("Combo") or 0
	if combo ~= lastCombo then
		lastCombo = combo
		if combo >= 2 then
			hud.combo.Text = combo .. " HITS"
			hud.combo.TextTransparency = 0
			hud.combo.TextStrokeTransparency = 0.4
			comboShownAt = now()
		end
	end
	if now() - comboShownAt > 1.4 then
		hud.combo.TextTransparency = math.min(1, hud.combo.TextTransparency + dt * 3)
		hud.combo.TextStrokeTransparency = hud.combo.TextTransparency
	end
	if rivalModel and rivalModel.Parent then
		hud.rival.Visible = true
		hud.rivalName.Text = rivalModel:GetAttribute("FighterName") or rivalModel.Name
		setBar(hud.rivalHp, (rivalModel:GetAttribute("HP") or 0) / (rivalModel:GetAttribute("MaxHP") or 1), dt)
	else
		hud.rival.Visible = false
	end
	local gamepad = UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
	hud.slots[1].key.Text = if gamepad then "RT" else "1"
	hud.slots[2].key.Text = if gamepad then "LT" else "2"
	hud.slots[3].key.Text = if gamepad then "LB" else "3"
	hud.slots[4].key.Text = if gamepad then "R3" else "G"
	hud.hint.Text = if gamepad then "X light · Y heavy · B dash · RB guard"
		elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then ""
		else "Click light · R heavy · Q dash · F guard"
end

-- ---------------------------------------------------------------------------------------------
-- Touch buttons
-- ---------------------------------------------------------------------------------------------
local function buildTouch(playerGui)
	if not UserInputService.TouchEnabled then
		return
	end
	local gui = make("ScreenGui", { Name = "HalcyonTouch", ResetOnSpawn = false, DisplayOrder = 6 }, playerGui)
	hud.touch = gui
	local function tb(text: string, action: string, pos: UDim2, size: number, color: Color3)
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), Text = text,
			Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(240, 244, 252),
			BackgroundColor3 = Color3.fromRGB(16, 21, 40), BackgroundTransparency = 0.25, AutoButtonColor = true,
		}, gui)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
		make("UIStroke", { Color = color, Thickness = 2 }, b)
		make("UIPadding", { PaddingTop = UDim.new(0.28, 0), PaddingBottom = UDim.new(0.28, 0), PaddingLeft = UDim.new(0.12, 0), PaddingRight = UDim.new(0.12, 0) }, b)
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				press(action)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				release(action)
			end
		end)
		return b
	end
	local cyan, gold, red = Color3.fromRGB(111, 230, 255), Color3.fromRGB(255, 201, 74), Color3.fromRGB(255, 120, 110)
	tb("ATK", "light", UDim2.new(1, -95, 1, -150), 92, cyan)
	tb("HVY", "heavy", UDim2.new(1, -195, 1, -110), 64, cyan)
	tb("DASH", "dash", UDim2.new(1, -60, 1, -250), 60, cyan)
	tb("GRD", "guard", UDim2.new(1, -175, 1, -205), 60, cyan)
	tb("1", "s1", UDim2.new(1, -255, 1, -190), 50, gold)
	tb("2", "s2", UDim2.new(1, -255, 1, -250), 50, gold)
	tb("3", "s3", UDim2.new(1, -195, 1, -290), 50, gold)
	tb("ULT", "ult", UDim2.new(1, -125, 1, -320), 56, red)
end

-- ---------------------------------------------------------------------------------------------
-- Messages from the server
-- ---------------------------------------------------------------------------------------------
local function onCombat(kind: string, d)
	local c = character()
	local root, hum = rootOf(c), humanoidOf(c)
	if kind == "push" and root then
		velocity(d.v, d.d)
		if d.float then
			st.hover = { until_ = now() + math.min(1.2, d.d + 0.6) }
		end
	elseif kind == "hit" then
		st.stunUntil = now() + (d.stun or 0.35)
		st.lastMove = nil
		st.chain = 0
		if st.guarding then
			st.guarding = false
			Animator.setGuard(c, false)
		end
		if hum and d.float then
			st.hover = { until_ = now() + (d.stun or 0.6) }
		end
	elseif kind == "stagger" then
		st.stunUntil = now() + (d.d or 0.7)
		st.lastMove = nil
		if c then
			Animator.stop(c)
		end
	elseif kind == "perfect" then
		st.counterUntil = now() + 0.9
		banner("PERFECT GUARD", "Attack now to counter!", Color3.fromRGB(255, 201, 74), 0.8)
	elseif kind == "blink" and c then
		c:PivotTo(d.cf)
	elseif kind == "reject" then
		-- the server refused (cooldown, Lumen, stun): stop the predicted animation
		if c and st.lastMove and st.lastMove.id == d.move then
			Animator.stop(c)
			st.lastMove = nil
		end
	end
end

local function onFx(d)
	Fx.onServer(d)
	if d.kind == "hit" and d.attacker == player.Character and d.victim then
		rivalModel = d.victim
	end
end

local function onDuel(phase: string, d)
	if phase == "intro" then
		st.frozenUntil = now() + (d.time or 3)
		rivalModel = d.opponent
		banner(string.upper(d.name), d.epithet .. "  ·  Level " .. tostring(d.level) .. "\n“" .. d.line .. "”", d.accent, (d.time or 3) - 0.6)
		task.delay((d.time or 3) - 0.6, function()
			banner("READY", nil, Color3.fromRGB(111, 230, 255), 0.5)
		end)
	elseif phase == "fight" then
		st.frozenUntil = 0
		banner("FIGHT!", nil, Color3.fromRGB(255, 201, 74), 0.8)
		Fx.sound("Ult")
		hud.timer.Visible = true
		local ends = now() + (d.time or 99)
		task.spawn(function()
			while hud.timer.Visible do
				hud.timer.Text = tostring(math.max(0, math.ceil(ends - now())))
				task.wait(0.2)
			end
		end)
	elseif phase == "result" then
		hud.timer.Visible = false
		st.frozenUntil = now() + 4.5
		banner(if d.won then "VICTORY" else "DEFEAT", "“" .. (d.line or "") .. "”\n+" .. tostring(d.coins) .. " coins", if d.won then Color3.fromRGB(255, 201, 74) else Color3.fromRGB(255, 120, 110), 4)
		Fx.sound(if d.won then "Win" else "Ko")
	elseif phase == "ended" then
		hud.timer.Visible = false
		st.frozenUntil = 0
		rivalModel = nil
	end
end

-- ---------------------------------------------------------------------------------------------
-- Per-frame upkeep
-- ---------------------------------------------------------------------------------------------
local function frame(dt: number)
	local c = character()
	local root, hum = rootOf(c), humanoidOf(c)
	updateHud(dt)
	if not (c and root and hum) then
		return
	end
	-- landing resets the air chain and air dash
	if hum.FloorMaterial ~= Enum.Material.Air then
		st.airDashes = 0
		st.airChain = 0
	end
	-- hover during air attacks and while juggled
	if st.hover and now() < st.hover.until_ then
		local v = root.AssemblyLinearVelocity
		if v.Y < 1 then
			root.AssemblyLinearVelocity = Vector3.new(v.X, 1.5, v.Z)
		end
	else
		st.hover = nil
	end
	-- buffered input fires as soon as the current move can be cancelled
	local b = st.buffered
	if b and now() - b.at < C.InputBuffer + 0.15 then
		if canAct() then
			st.buffered = nil
			if b.kind == "light" then
				lightPressed()
			elseif b.kind == "heavy" then
				heavyReleased(b.held or 0)
			elseif b.kind == "skill" then
				skill(b.slot)
			end
		end
	else
		st.buffered = nil
	end
	if st.wantGuard and canAct() then
		setGuard(true)
	end
	-- movement speed: frozen while stunned or mid-swing, slow while guarding
	local stunned = now() < st.stunUntil or now() < st.frozenUntil
	local swinging = st.lastMove ~= nil and now() < st.moveStart + st.lastMove.dur * 0.8
	local base = Config.Campus.WalkSpeed
	hum.WalkSpeed = if stunned then 0 elseif swinging then 4 elseif st.guarding then 7 else base
	hum.AutoRotate = not swinging and not stunned
	hum.JumpPower = if stunned or swinging then 0 else 50
end

function CombatClient.setMenuOpen(open: boolean)
	st.inMenu = open
end

function CombatClient.init(playerGui, deps)
	Animator, Fx = deps.Animator, deps.Fx
	remotes = ReplicatedStorage:WaitForChild(Config.RemotesName)
	CombatRemote = remotes:WaitForChild("Combat")
	DuelRemote = remotes:WaitForChild("Duel")
	buildHud(playerGui)
	buildTouch(playerGui)
	CombatRemote.OnClientEvent:Connect(onCombat)
	remotes:WaitForChild("Fx").OnClientEvent:Connect(onFx)
	DuelRemote.OnClientEvent:Connect(onDuel)
	UserInputService.InputBegan:Connect(function(input, processed)
		local action = inputKey(input)
		if not action then
			return
		end
		-- clicks on menus and chat should not swing the sword (gamepad buttons stay live in the world)
		if processed and action ~= "jump" and input.UserInputType ~= Enum.UserInputType.Gamepad1 then
			return
		end
		if not character() then
			return
		end
		press(action)
	end)
	UserInputService.InputEnded:Connect(function(input)
		local action = inputKey(input)
		if action then
			release(action)
		end
	end)
	RunService.RenderStepped:Connect(frame)
	player.CharacterAdded:Connect(function()
		st.lastMove, st.stunUntil, st.guarding, st.hover, st.chain = nil, 0, false, nil, 0
	end)
end

return CombatClient
