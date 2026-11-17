--!nonstrict
-- Fx: every combat visual, drawn locally on each client: slash arcs, sparks, damage numbers, shockwaves,
-- beams, projectiles, auras and ultimate effects. Nothing here affects the game; the server decides hits.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))

local Fx = {}

local player = Players.LocalPlayer
local folder: Folder
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 201, 74)
local shake = { amount = 0, until_ = 0 }
local projectiles = {}

local function part(props): BasePart
	local p = Instance.new(props.shape == "Wedge" and "WedgePart" or "Part")
	if props.shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif props.shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = props.material or Enum.Material.Neon
	p.Color = props.color or WHITE
	p.Size = props.size or Vector3.new(1, 1, 1)
	p.CFrame = props.cf or CFrame.new()
	p.Transparency = props.trans or 0
	p.Parent = folder
	return p
end

local function fade(p: BasePart, time: number, grow: Vector3?, delay: number?)
	local goal = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	local tween = TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), goal)
	tween:Play()
	Debris:AddItem(p, time + (delay or 0) + 0.05)
end

local function sound(name: string, at: Vector3?, pitch: number?)
	local def = Config.Sounds[name]
	if not def or def.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume
	s.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
	s.RollOffMaxDistance = 220
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = Workspace.Terrain
		s.Parent = a
		Debris:AddItem(a, 3)
	else
		s.Parent = folder
		Debris:AddItem(s, 3)
	end
	s:Play()
end
Fx.sound = sound

local function nearMe(pos: Vector3, range: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - pos).Magnitude < range
end

function Fx.shake(amount: number, duration: number)
	if amount > shake.amount or os.clock() > shake.until_ then
		shake.amount = amount
		shake.until_ = os.clock() + duration
	end
end

local function sparks(pos: Vector3, color: Color3, count: number, speed: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(WHITE, color)
	e.LightEmission = 1
	e.Lifetime = NumberRange.new(0.15, 0.4)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 1)
end

local function number(pos: Vector3, text: string, color: Color3, big: boolean?)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos + Vector3.new((math.random() - 0.5) * 2, 1.5, 0)
	a.Parent = Workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if big then 180 else 120, if big then 60 else 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Parent = a
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(a, 0.8)
end

--- Flat expanding ring on the ground (or in any plane).
local function ring(cf: CFrame, radius: number, color: Color3, time: number, thickness: number?)
	local segs = 18
	for i = 0, segs - 1 do
		local a = (i / segs) * math.pi * 2
		local len = 2 * math.pi * 1 / segs + 0.05
		local p = part({ cf = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1), size = Vector3.new(len, thickness or 0.3, 0.4), color = color })
		local endCf = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		local endLen = 2 * math.pi * radius / segs + 0.1
		TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = endCf, Size = Vector3.new(endLen, (thickness or 0.3) * 0.5, 0.4), Transparency = 1 }):Play()
		Debris:AddItem(p, time + 0.05)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Swings
-- ---------------------------------------------------------------------------------------------
--- A crescent slash arc around a fighter. `def` is a move's slash entry.
function Fx.slash(rootCf: CFrame, def)
	local color = def.color or WHITE
	local centre = rootCf * CFrame.new(0, (def.y or 0.6), 0) * CFrame.Angles(0, 0, math.rad(def.tilt or 0))
	local a0, a1 = def.a0 or 0, def.a1 or 0
	local span = a1 - a0
	local segs = math.clamp(math.floor(math.abs(span) / 14), 6, 60)
	local r = def.r or 6
	local dur = def.dur or 0.1
	for i = 0, segs - 1 do
		local f0 = i / segs
		local angle = math.rad(a0 + span * (f0 + 0.5 / segs))
		local segLen = 2 * math.pi * r * math.abs(span) / 360 / segs + 0.15
		-- thicker in the middle of the swing, thin at the ends
		local w = 0.25 + 1.1 * math.sin(math.pi * (i + 0.5) / segs)
		local cf = centre * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, -r)
		local p = part({ cf = cf, size = Vector3.new(segLen, w, 0.12), color = color, trans = 0.05 })
		local inner = part({ cf = cf * CFrame.new(0, 0, 0.3), size = Vector3.new(segLen, w * 0.5, 0.08), color = WHITE, trans = 0.1 })
		p.Transparency = 1
		inner.Transparency = 1
		local delay = dur * f0
		task.delay(delay, function()
			p.Transparency = 0.05
			inner.Transparency = 0.1
			fade(p, 0.22, Vector3.new(segLen, w * 0.2, 0.12))
			fade(inner, 0.16)
		end)
	end
end

--- Ghost copies of a character, left behind for a dash.
function Fx.afterimage(model: Model, color: Color3)
	for k = 0, 2 do
		task.delay(k * 0.05, function()
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 0.9 and p.Name ~= "HumanoidRootPart" and p.Size.Magnitude > 0.6 then
					local g = part({ cf = p.CFrame, size = p.Size, color = color, trans = 0.55, material = Enum.Material.ForceField })
					if p:IsA("Part") then
						g.Shape = p.Shape
					end
					fade(g, 0.35)
				end
			end
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Move effects (from a move's fx list)
-- ---------------------------------------------------------------------------------------------
function Fx.moveFx(model: Model, def)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cf = root.CFrame
	local flat = CFrame.lookAt(cf.Position, cf.Position + cf.LookVector * Vector3.new(1, 0, 1))
	local feet = flat * CFrame.new(0, -2.8, 0)
	local color = def.color or WHITE
	local kind = def.kind
	if kind == "quake" then
		ring(feet, def.r or 10, color, 0.45, 0.6)
		ring(feet, (def.r or 10) * 0.6, WHITE, 0.3, 0.3)
		for _ = 1, 8 do
			local a = math.random() * math.pi * 2
			local d = math.random() * (def.r or 10)
			local rock = part({ cf = feet * CFrame.new(math.cos(a) * d, 0.5, math.sin(a) * d) * CFrame.Angles(math.random(), math.random(), math.random()), size = Vector3.new(1, 1, 1) * (0.8 + math.random()), color = Color3.fromRGB(110, 115, 130), material = Enum.Material.Slate })
			TweenService:Create(rock, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rock.CFrame + Vector3.new(0, 3 + math.random() * 3, 0), Transparency = 1 }):Play()
			Debris:AddItem(rock, 0.55)
		end
		if nearMe(cf.Position, 60) then
			Fx.shake(0.6, 0.3)
		end
		sound("Heavy", cf.Position, 0.8)
	elseif kind == "pierce" or kind == "streak" then
		local len = def.len or 12
		local p = part({ cf = flat * CFrame.new(0, 0.6, -len / 2), size = Vector3.new(0.5, 0.5, len), color = color })
		fade(p, 0.3, Vector3.new(0.05, 0.05, len * 1.2))
		local w = part({ cf = flat * CFrame.new(0, 0.6, -len / 2), size = Vector3.new(1.4, 1.4, len), color = color, trans = 0.6, material = Enum.Material.ForceField })
		fade(w, 0.25)
	elseif kind == "afterimage" then
		Fx.afterimage(model, color)
	elseif kind == "pillar" then
		local p = part({ cf = feet * CFrame.new(0, 10, -3), size = Vector3.new(20, 3, 3), color = color, shape = "Cylinder" })
		p.CFrame = feet * CFrame.new(0, 10, -3) * CFrame.Angles(0, 0, math.rad(90))
		fade(p, 0.4, Vector3.new(26, 0.2, 0.2))
		sparks(cf.Position + cf.LookVector * 3, color, 18, 30)
	elseif kind == "aura" then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.Rate = 40
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = root
		Debris:AddItem(e, def.dur or 1)
		local h = Instance.new("Highlight")
		h.FillColor = color
		h.FillTransparency = 0.75
		h.OutlineColor = color
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
		Debris:AddItem(h, def.dur or 1)
	elseif kind == "charge" then
		for i = 1, 10 do
			task.delay((def.dur or 0.3) * i / 10, function()
				local off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * 6
				local spot = root.Position + root.CFrame.LookVector * 3
				local p = part({ cf = CFrame.new(spot + off), size = Vector3.new(0.4, 0.4, 0.4), color = color, shape = "Ball" })
				TweenService:Create(p, TweenInfo.new(0.2), { CFrame = CFrame.new(spot), Transparency = 0.6 }):Play()
				Debris:AddItem(p, 0.22)
			end)
		end
	elseif kind == "beam" then
		local len, width, dur = def.len or 60, def.width or 3, def.dur or 0.3
		local start = tick()
		local core = part({ size = Vector3.new(len, width, width), color = WHITE, shape = "Cylinder" })
		local glow = part({ size = Vector3.new(len, width * 1.8, width * 1.8), color = color, shape = "Cylinder", trans = 0.4 })
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = tick() - start
			if t > dur or not root.Parent then
				conn:Disconnect()
				fade(core, 0.15)
				fade(glow, 0.2)
				return
			end
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local base = root.Position + Vector3.new(0, 0.6, 0) + look.Unit * 2
			local mid = CFrame.lookAt(base + look.Unit * len / 2, base + look.Unit * len) * CFrame.Angles(0, math.rad(90), 0)
			local pulse = 1 + math.sin(t * 40) * 0.12
			core.CFrame = mid
			glow.CFrame = mid
			glow.Size = Vector3.new(len, width * 1.8 * pulse, width * 1.8 * pulse)
		end)
		if nearMe(cf.Position, 120) then
			Fx.shake(0.4, dur)
		end
	elseif kind == "storm" then
		local dur = def.dur or 1
		local n = math.floor(dur / 0.06)
		for i = 1, n do
			task.delay(i * 0.06, function()
				local target = root.CFrame * CFrame.Angles(0, math.random() * math.pi * 2, 0)
				Fx.slash(target, { a0 = -90, a1 = 90, tilt = math.random(-80, 80), r = 6 + math.random() * 6, dur = 0.05, color = color })
			end)
		end
	elseif kind == "rain" then
		-- the server sends each spear as its own event; this is the glowing sky above
		local sky = part({ cf = flat * CFrame.new(0, 30, -8) * CFrame.Angles(0, 0, math.rad(90)), size = Vector3.new(0.6, (def.r or 18) * 2, (def.r or 18) * 2), color = color, shape = "Cylinder", trans = 0.5 })
		fade(sky, def.dur or 1)
	elseif kind == "dome" then
		local d = part({ cf = CFrame.new(cf.Position), size = Vector3.new(2, 2, 2), color = color, shape = "Ball", trans = 0.5, material = Enum.Material.ForceField })
		TweenService:Create(d, TweenInfo.new(0.3), { Size = Vector3.new(1, 1, 1) * (def.r or 20) * 2 }):Play()
		fade(d, 0.4, nil, def.dur or 1.5)
	elseif kind == "ring" then
		ring(feet * CFrame.new(0, 2.8, 0), def.r or 20, color, def.dur or 0.6, 1.2)
		ring(feet * CFrame.new(0, 2.8, 0), (def.r or 20) * 0.7, WHITE, (def.dur or 0.6) * 0.8, 0.6)
	elseif kind == "orbit" then
		local discs = {}
		for k = 1, 2 do
			discs[k] = part({ size = Vector3.new(0.3, 2.6, 2.6), color = color, shape = "Cylinder" })
		end
		local start = tick()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = tick() - start
			if t > (def.dur or 4) or not root.Parent then
				conn:Disconnect()
				for _, d in discs do
					fade(d, 0.2)
				end
				return
			end
			for k, d in discs do
				local a = t * 9 + k * math.pi
				d.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * (def.r or 7), 0.4, math.sin(a) * (def.r or 7))) * CFrame.Angles(0, 0, math.rad(90))
			end
		end)
	elseif kind == "snare" then
		local spot = flat * CFrame.new(0, -2.7, -(def.at or 16))
		local disc = part({ cf = spot * CFrame.Angles(0, 0, math.rad(90)), size = Vector3.new(0.2, (def.r or 10) * 2, (def.r or 10) * 2), color = color, shape = "Cylinder", trans = 0.45 })
		fade(disc, 0.3, nil, def.dur or 2.5)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local bar = part({ cf = spot * CFrame.new(math.cos(a) * (def.r or 10), 3, math.sin(a) * (def.r or 10)), size = Vector3.new(0.3, 6, 0.3), color = color })
			fade(bar, 0.3, nil, def.dur or 2.5)
		end
	elseif kind == "spray" then
		local dur = def.dur or 0.6
		for i = 1, 24 do
			task.delay(dur * i / 24, function()
				local a = math.random() * math.pi * 2
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local len = def.r or 24
				local p = part({ cf = CFrame.lookAt(root.Position + dir * len / 2, root.Position + dir * len), size = Vector3.new(0.25, 0.25, len), color = color })
				fade(p, 0.12)
			end)
		end
	elseif kind == "vanish" then
		sparks(root.Position, color, 26, 20)
		local puff = part({ cf = CFrame.new(root.Position), size = Vector3.new(4, 4, 4), color = color, shape = "Ball", trans = 0.4, material = Enum.Material.ForceField })
		fade(puff, 0.3, Vector3.new(9, 9, 9))
	elseif kind == "blast" then
		local p = part({ cf = flat * CFrame.new(0, 0.5, -(def.r or 7) / 2), size = Vector3.new(4, 4, def.r or 7), color = color, trans = 0.2 })
		fade(p, 0.2, Vector3.new(8, 8, (def.r or 7) * 1.2))
		sparks(cf.Position + cf.LookVector * 4, color, 20, 40)
	elseif kind == "ultStart" then
		sound("Ult", cf.Position)
		local flash = part({ cf = CFrame.new(cf.Position), size = Vector3.new(3, 3, 3), color = color, shape = "Ball", trans = 0.2 })
		fade(flash, 0.5, Vector3.new(40, 40, 40))
		ring(feet, 30, color, 0.7, 1)
		if model == player.Character then
			Fx.ultCamera(color)
		end
	end
end

--- Local player's ultimate: a colour wash and a field-of-view punch.
function Fx.ultCamera(color: Color3)
	local camera = Workspace.CurrentCamera
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = color:Lerp(WHITE, 0.6)
	cc.Saturation = 0.3
	cc.Contrast = 0.2
	cc.Parent = camera
	TweenService:Create(cc, TweenInfo.new(1.4), { TintColor = WHITE, Saturation = 0, Contrast = 0 }):Play()
	Debris:AddItem(cc, 1.5)
	local fov = camera.FieldOfView
	camera.FieldOfView = fov + 14
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
end

-- ---------------------------------------------------------------------------------------------
-- Server events: hits, guards, projectiles
-- ---------------------------------------------------------------------------------------------
local PROJ_SHAPES = {}
function PROJ_SHAPES.bolt(color, radius)
	local p = part({ size = Vector3.new(0.45, 0.45, 3.2), color = color })
	return p
end
function PROJ_SHAPES.orb(color, radius)
	return part({ size = Vector3.new(1, 1, 1) * (radius or 2) * 1.3, color = color, shape = "Ball" })
end
function PROJ_SHAPES.wave(color, radius)
	local m = Instance.new("Model")
	for i = -4, 4 do
		local a = math.rad(i * 15)
		local p = part({ cf = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2.5), size = Vector3.new(1.4, 0.25 + (4 - math.abs(i)) * 0.3, 0.3), color = color })
		p.Parent = m
	end
	m.Parent = folder
	return m
end
function PROJ_SHAPES.hook(color, radius)
	return PROJ_SHAPES.wave(color, radius)
end
function PROJ_SHAPES.disc(color, radius)
	local p = part({ size = Vector3.new(0.3, 3, 3), color = color, shape = "Cylinder" })
	return p
end
function PROJ_SHAPES.quakeline(color, radius)
	return part({ size = Vector3.new(4, 1.5, 4), color = color, trans = 0.3 })
end

local function place(obj, cf: CFrame)
	if obj:IsA("Model") then
		obj:PivotTo(cf)
	else
		obj.CFrame = cf
	end
end

local function onProjectile(d)
	local make = PROJ_SHAPES[d.shape] or PROJ_SHAPES.bolt
	local obj = make(d.color or WHITE, d.radius)
	local proj = { obj = obj, pos = d.pos, dir = d.dir, speed = d.speed, range = d.range, travelled = 0, boomerang = d.boomerang, owner = d.owner, returning = false, shape = d.shape, color = d.color, spin = 0 }
	projectiles[d.id] = proj
	sound(if d.shape == "bolt" or d.shape == "orb" then "Shot" else "Swing", d.pos)
end

local function endProjectile(id, pos: Vector3?)
	local proj = projectiles[id]
	if not proj then
		return
	end
	projectiles[id] = nil
	if proj.obj then
		proj.obj:Destroy()
	end
	if pos then
		sparks(pos, proj.color or WHITE, 8, 20)
	end
end

local function stepProjectiles(dt: number)
	for id, proj in projectiles do
		local step = proj.speed * dt
		if proj.returning then
			local owner = proj.owner
			local root = owner and owner:FindFirstChild("HumanoidRootPart")
			if root then
				local back = root.Position - proj.pos
				if back.Magnitude < step + 2 then
					endProjectile(id)
					continue
				end
				proj.dir = back.Unit
			end
		end
		proj.pos += proj.dir * step
		proj.travelled += step
		if proj.travelled > proj.range then
			if proj.boomerang and not proj.returning then
				proj.returning = true
			elseif not proj.boomerang then
				endProjectile(id)
				continue
			end
		end
		proj.spin += dt * 25
		local cf = CFrame.lookAt(proj.pos, proj.pos + proj.dir)
		if proj.shape == "disc" then
			cf = CFrame.new(proj.pos) * CFrame.Angles(0, proj.spin, math.rad(90))
		elseif proj.shape == "quakeline" then
			if math.random() < 0.5 then
				local rock = part({ cf = CFrame.new(proj.pos) * CFrame.Angles(math.random(), math.random(), math.random()), size = Vector3.new(1.5, 1.5, 1.5) * (0.7 + math.random()), color = Color3.fromRGB(110, 110, 125), material = Enum.Material.Slate })
				fade(rock, 0.6, nil, 0.2)
			end
		end
		place(proj.obj, cf)
		if proj.travelled > 400 then
			endProjectile(id)
		end
	end
end

function Fx.onServer(d)
	local kind = d.kind
	if kind == "hit" then
		local heavy = d.heavy
		local color = d.color or WHITE
		sparks(d.pos, color, if heavy then 30 else 14, if heavy then 50 else 30)
		local flash = part({ cf = CFrame.new(d.pos), size = Vector3.new(1, 1, 1) * (if heavy then 3 else 1.8), color = WHITE, shape = "Ball" })
		fade(flash, 0.14, Vector3.new(1, 1, 1) * (if heavy then 7 else 4))
		local streak = part({ cf = CFrame.new(d.pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), size = Vector3.new(0.25, 0.25, if heavy then 9 else 5), color = color })
		fade(streak, 0.12)
		number(d.pos, tostring(d.dmg) .. (if d.crit then "!" else ""), if d.crit then GOLD else WHITE, heavy or d.crit)
		sound(if heavy then "Heavy" else "Hit", d.pos)
		local me = player.Character
		if d.attacker == me or d.victim == me then
			Fx.shake(if heavy then 0.55 else 0.25, if heavy then 0.18 else 0.1)
		end
		if Fx.onHitStop then
			Fx.onHitStop(d.attacker, d.victim, d.stop or 0.06)
		end
	elseif kind == "guard" then
		sparks(d.pos, Color3.fromRGB(150, 210, 255), 10, 25)
		local shield = part({ cf = CFrame.new(d.pos), size = Vector3.new(4, 4, 4), color = Color3.fromRGB(150, 210, 255), shape = "Ball", trans = 0.5, material = Enum.Material.ForceField })
		fade(shield, 0.2, Vector3.new(6, 6, 6))
		number(d.pos, tostring(d.dmg), Color3.fromRGB(150, 180, 220))
		sound("Guard", d.pos)
	elseif kind == "perfect" or kind == "parry" then
		sparks(d.pos, WHITE, 40, 60)
		ring(CFrame.new(d.pos), 8, WHITE, 0.3, 0.4)
		number(d.pos + Vector3.new(0, 1.5, 0), if kind == "perfect" then "PERFECT" else "COUNTER", GOLD, true)
		sound("Perfect", d.pos)
		if nearMe(d.pos, 30) then
			Fx.shake(0.3, 0.12)
		end
	elseif kind == "miss" then
		number(d.pos, "DODGE", Color3.fromRGB(180, 200, 255))
	elseif kind == "guardbreak" then
		number(d.pos, "GUARD BREAK", Color3.fromRGB(255, 120, 90), true)
		sparks(d.pos, Color3.fromRGB(255, 120, 90), 30, 40)
	elseif kind == "burst" then
		ring(CFrame.new(d.pos), 10, d.color or WHITE, 0.35, 0.6)
		number(d.pos + Vector3.new(0, 3, 0), "BREAK AWAY", d.color or WHITE, true)
	elseif kind == "ko" then
		local flash = part({ cf = CFrame.new(d.pos), size = Vector3.new(4, 4, 4), color = GOLD, shape = "Ball" })
		fade(flash, 0.5, Vector3.new(30, 30, 30))
		ring(CFrame.new(d.pos - Vector3.new(0, 2.5, 0)), 24, GOLD, 0.6, 1)
		sound("Ko", d.pos)
		if nearMe(d.pos, 80) then
			Fx.shake(0.8, 0.4)
		end
	elseif kind == "spear" then
		local spear = part({ cf = CFrame.new(d.pos + Vector3.new(0, 45, 0)), size = Vector3.new(0.6, 9, 0.6), color = d.color or GOLD })
		TweenService:Create(spear, TweenInfo.new(0.12, Enum.EasingStyle.Linear), { CFrame = CFrame.new(d.pos + Vector3.new(0, 2, 0)) }):Play()
		task.delay(0.12, function()
			ring(CFrame.new(d.pos - Vector3.new(0, 2.5, 0)), 7, d.color or GOLD, 0.3, 0.4)
			fade(spear, 0.25)
		end)
	elseif kind == "proj" then
		onProjectile(d)
	elseif kind == "projReturn" then
		local proj = projectiles[d.id]
		if proj then
			proj.returning = true
		end
	elseif kind == "projEnd" then
		endProjectile(d.id, d.pos)
	end
end

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "HalcyonFx"
	folder.Parent = Workspace
	local camera = Workspace.CurrentCamera
	RunService.RenderStepped:Connect(function(dt)
		stepProjectiles(dt)
		if os.clock() < shake.until_ then
			local a = shake.amount * (shake.until_ - os.clock()) / 0.3
			camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
		end
	end)
end

return Fx
