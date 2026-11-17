--!nonstrict
-- Weapons: the six Lumen weapons, their stats and their models.
-- A weapon model's "Handle" sits in the fist; the blade (or shaft, or barrel) runs along the hand's -Y axis,
-- which is the line of the forearm. Posing the arm therefore aims the weapon directly.
local Config = require(script.Parent.Config)
local hex = Config.hex

local Weapons = {}

Weapons.Order = { "saber", "lance", "maul", "pistols", "scythe", "discs" }

Weapons.List = {
	saber = {
		id = "saber", name = "Lumen Saber", style = "Balanced", color = hex(0x6fe6ff),
		desc = "Fast four-hit chains, a dash that cuts straight through, and a slash wave for range.",
		hp = 1000, speed = 1.0, power = 1.0, hands = "right",
	},
	lance = {
		id = "lance", name = "Solar Lance", style = "Reach", color = hex(0xffb62e),
		desc = "The longest reach. Keep rivals at the tip, then vault in when they close the gap.",
		hp = 960, speed = 0.97, power = 1.02, hands = "right",
	},
	maul = {
		id = "maul", name = "Ember Maul", style = "Power", color = hex(0xff5a2a),
		desc = "Slow, armoured swings that shrug off hits. Ground shockwaves and crushing slams.",
		hp = 1150, speed = 0.88, power = 1.18, hands = "right",
	},
	pistols = {
		id = "pistols", name = "Twin Pistols", style = "Ranged", color = hex(0xe14bff),
		desc = "Pressure from range with fans of bolts, a piercing charge shot and a beam ultimate.",
		hp = 900, speed = 1.06, power = 0.92, hands = "both",
	},
	scythe = {
		id = "scythe", name = "Eclipse Scythe", style = "Unique: Control", color = hex(0xb06bff),
		desc = "Wide sweeping arcs, a hook that drags rivals in, and a blink that lands behind them.",
		hp = 1000, speed = 0.96, power = 1.06, hands = "right", unique = true,
	},
	discs = {
		id = "discs", name = "Orbit Discs", style = "Unique: Tricks", color = hex(0x7dff7a),
		desc = "Twin ring blades you throw and recall. Boomerangs, an orbiting shield and a snaring zone.",
		hp = 940, speed = 1.04, power = 0.97, hands = "both", unique = true,
	},
}

--- The weapon a student of each academy starts with.
Weapons.SchoolDefault = { northwind = "saber", solcrest = "lance", arcline = "pistols", ironreach = "maul" }

local M = Enum.Material
local METAL = hex(0x3a3f50)
local SILVER = hex(0xc9d0dc)

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: string?)
	local p = Instance.new("Part")
	p.Name = name
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
	return p
end

-- Cylinders in Roblox run along X; this turns one to run along Y.
local UP = CFrame.Angles(0, 0, math.rad(90))

--- Builds one hand's model in local space: Handle at the origin, weapon along -Y.
--- Returns the model and the two trail points (base and tip) for swing trails.
local function buildModel(id: string, glow: Color3, hand: string): (Model, Vector3, Vector3)
	local m = Instance.new("Model")
	m.Name = id .. "_" .. hand
	local handle = part(m, "Handle", Vector3.new(0.3, 1.0, 0.3), CFrame.new(), METAL, M.Metal)
	m.PrimaryPart = handle
	local base, tip = Vector3.new(0, -0.8, 0), Vector3.new(0, -4.8, 0)
	if id == "saber" then
		part(m, "Pommel", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.55, 0), SILVER, M.Metal, "Ball")
		part(m, "Guard", Vector3.new(1.1, 0.18, 0.36), CFrame.new(0, -0.55, 0), SILVER, M.Metal)
		part(m, "GuardGem", Vector3.new(0.26, 0.26, 0.4), CFrame.new(0, -0.55, 0), glow, M.Neon)
		part(m, "Blade", Vector3.new(0.14, 4.0, 0.42), CFrame.new(0, -2.7, 0), glow, M.Neon)
		part(m, "BladeGlass", Vector3.new(0.22, 4.1, 0.6), CFrame.new(0, -2.72, 0), hex(0xe9fbff), M.Glass).Transparency = 0.55
		local tipPart = Instance.new("WedgePart")
		tipPart.Name = "Tip"
		tipPart.Size = Vector3.new(0.14, 0.6, 0.42)
		tipPart.CFrame = CFrame.new(0, -5.0, 0) * CFrame.Angles(math.rad(180), 0, 0)
		tipPart.Color = glow
		tipPart.Material = M.Neon
		tipPart.CanCollide, tipPart.CanTouch, tipPart.CanQuery, tipPart.Massless, tipPart.CastShadow = false, false, false, true, false
		tipPart.Parent = m
		base, tip = Vector3.new(0, -0.9, 0), Vector3.new(0, -5.1, 0)
	elseif id == "lance" then
		part(m, "Shaft", Vector3.new(7.6, 0.24, 0.24), CFrame.new(0, -1.6, 0) * UP, SILVER, M.Metal, "Cylinder")
		part(m, "Butt", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 2.25, 0), glow, M.Neon, "Ball")
		part(m, "Collar", Vector3.new(0.3, 0.45, 0.45), CFrame.new(0, -5.3, 0) * UP, glow, M.Neon, "Cylinder")
		part(m, "Head", Vector3.new(0.18, 2.6, 0.7), CFrame.new(0, -6.7, 0), glow, M.Neon)
		part(m, "HeadGlass", Vector3.new(0.26, 2.0, 1.1), CFrame.new(0, -6.3, 0), hex(0xfff3d6), M.Glass).Transparency = 0.5
		for _, sx in { -1, 1 } do
			part(m, "Fin", Vector3.new(0.1, 0.9, 0.5), CFrame.new(0, -5.6, sx * 0.45) * CFrame.Angles(math.rad(sx * 25), 0, 0), glow, M.Neon)
		end
		base, tip = Vector3.new(0, -5.4, 0), Vector3.new(0, -8.0, 0)
	elseif id == "maul" then
		part(m, "Shaft", Vector3.new(4.6, 0.3, 0.3), CFrame.new(0, -1.0, 0) * UP, METAL, M.Metal, "Cylinder")
		part(m, "Grip", Vector3.new(1.2, 0.36, 0.36), CFrame.new(0, 0.6, 0) * UP, hex(0x2a2a30), M.Fabric, "Cylinder")
		part(m, "Head", Vector3.new(2.4, 1.6, 1.6), CFrame.new(0, -3.9, 0), hex(0x4a4f5e), M.Metal)
		part(m, "Core", Vector3.new(2.5, 0.5, 1.7), CFrame.new(0, -3.9, 0), glow, M.Neon)
		for _, sx in { -1, 1 } do
			part(m, "Face", Vector3.new(0.3, 1.9, 1.9), CFrame.new(sx * 1.3, -3.9, 0), METAL, M.Metal)
			part(m, "Rune", Vector3.new(0.05, 0.9, 0.9), CFrame.new(sx * 1.47, -3.9, 0) * CFrame.Angles(math.rad(45), 0, 0), glow, M.Neon)
		end
		part(m, "Spike", Vector3.new(0.5, 0.9, 0.5), CFrame.new(0, -5.1, 0), SILVER, M.Metal)
		base, tip = Vector3.new(0, -3.2, 0), Vector3.new(0, -4.8, 0)
	elseif id == "pistols" then
		-- barrel along -Y, grip up the forearm
		part(m, "Body", Vector3.new(0.42, 1.7, 0.75), CFrame.new(0, -1.0, 0.05), hex(0x2b2f45), M.Metal)
		part(m, "Barrel", Vector3.new(0.9, 0.3, 0.3), CFrame.new(0, -2.1, -0.08) * UP, SILVER, M.Metal, "Cylinder")
		part(m, "Muzzle", Vector3.new(0.2, 0.36, 0.36), CFrame.new(0, -2.6, -0.08) * UP, glow, M.Neon, "Cylinder")
		part(m, "Strip", Vector3.new(0.44, 1.4, 0.1), CFrame.new(0, -1.0, -0.33), glow, M.Neon)
		part(m, "Cell", Vector3.new(0.3, 0.5, 0.3), CFrame.new(0, -0.5, 0.42), glow, M.Neon)
		base, tip = Vector3.new(0, -1.6, 0), Vector3.new(0, -2.7, 0)
	elseif id == "scythe" then
		part(m, "Shaft", Vector3.new(6.4, 0.24, 0.24), CFrame.new(0, -1.6, 0) * UP, hex(0x1d1b2a), M.Metal, "Cylinder")
		part(m, "Butt", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.7, 0), glow, M.Neon, "Ball")
		part(m, "Socket", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, -4.8, 0), SILVER, M.Metal)
		-- the crescent: five segments curving out to the side and back down
		local pts = { Vector3.new(0, -4.9, 0), Vector3.new(0, -5.3, -1.3), Vector3.new(0, -5.2, -2.6), Vector3.new(0, -4.6, -3.7), Vector3.new(0, -3.6, -4.4), Vector3.new(0, -2.4, -4.6) }
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local cf = CFrame.lookAt((a + b) / 2, b)
			local w = 0.9 - i * 0.13
			part(m, "Crescent", Vector3.new(0.14, w, (b - a).Magnitude + 0.1), cf * CFrame.new(0, -w * 0.3, 0), glow, M.Neon)
			part(m, "CrescentGlass", Vector3.new(0.2, w + 0.3, (b - a).Magnitude + 0.1), cf * CFrame.new(0, -w * 0.2, 0), hex(0xece0ff), M.Glass).Transparency = 0.55
		end
		base, tip = Vector3.new(0, -5.0, -0.4), Vector3.new(0, -3.0, -4.6)
	elseif id == "discs" then
		-- a ring blade held flat in the fist
		local centre = Vector3.new(0, -1.5, 0)
		for i = 0, 9 do
			local a = math.rad(i * 36)
			local pos = centre + Vector3.new(math.sin(a) * 1.25, 0, math.cos(a) * 1.25)
			part(m, "Ring", Vector3.new(0.82, 0.2, 0.34), CFrame.new(pos) * CFrame.Angles(0, a + math.rad(90), 0), SILVER, M.Metal)
			part(m, "Edge", Vector3.new(0.84, 0.08, 0.1), CFrame.new(centre + Vector3.new(math.sin(a) * 1.45, 0, math.cos(a) * 1.45)) * CFrame.Angles(0, a + math.rad(90), 0), glow, M.Neon)
		end
		part(m, "Core", Vector3.new(0.12, 0.7, 0.7), CFrame.new(centre) * UP, glow, M.Neon, "Cylinder")
		part(m, "Bar", Vector3.new(0.2, 0.2, 2.4), CFrame.new(centre), METAL, M.Metal)
		base, tip = centre + Vector3.new(0, 0, -1.4), centre + Vector3.new(0, 0, 1.4)
	end
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end
	return m, base, tip
end

--- A copy of the weapon model for one hand, positioned at the origin (used for previews and racks).
function Weapons.model(id: string, hand: string?): Model
	local def = Weapons.List[id] or Weapons.List.saber
	local m = buildModel(def.id, def.color, hand or "right")
	return m
end

--- Puts weapon `id` in the character's hands, replacing whatever was there.
--- Returns the folder holding the weapon (each hand's model has TrailBase / TrailTip attachments).
function Weapons.attach(character: Model, id: string): Folder?
	local def = Weapons.List[id] or Weapons.List.saber
	local old = character:FindFirstChild("HalcyonWeapon")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "HalcyonWeapon"
	local hands = if def.hands == "both" then { "Right", "Left" } else { "Right" }
	for _, side in hands do
		local hand = character:FindFirstChild(side .. "Hand")
		if hand and hand:IsA("BasePart") then
			local m, base, tip = buildModel(def.id, def.color, string.lower(side))
			local handle = m.PrimaryPart
			-- grip slightly below the centre of the hand, weapon along the forearm line
			local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.25, 0)
			m:PivotTo(grip)
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = hand.Anchored
				end
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = handle
			weld.Parent = handle
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailBase"
			a0.Position = base
			a0.Parent = handle
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailTip"
			a1.Position = tip
			a1.Parent = handle
			m.Parent = folder
		end
	end
	folder:SetAttribute("Weapon", def.id)
	folder.Parent = character
	character:SetAttribute("Weapon", def.id)
	return folder
end

return Weapons
