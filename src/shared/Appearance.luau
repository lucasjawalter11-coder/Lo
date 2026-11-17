--!nonstrict
-- Appearance: dresses a character in a player's chosen look and their school's uniform.
-- Works on a real R15 player character (server) and on preview models in the Customize screen (client).
-- Everything it adds goes into a "HalcyonLook" folder, welded to the body, so applying again replaces it.
local Config = require(script.Parent.Config)
local Looks = require(script.Parent.Looks)
local hex = Config.hex

local Appearance = {}

local M = Enum.Material
local LIMBS = {
	"UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local CLOTHING = { Accessory = true, Shirt = true, Pants = true, ShirtGraphic = true }

local function mix(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function colours(schoolId: string?)
	local academy = schoolId and Config.Academies[schoolId]
	if academy then
		return academy.uniform, academy.accent
	end
	return Looks.VisitorUniform, Looks.VisitorAccent
end

--- Adds a part at a world CFrame, welded to `to`.
local function attach(folder: Instance, to: BasePart, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, shape: string?, name: string?)
	local p = Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Name = name or "Piece"
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
	p.CastShadow = true
	p.Anchored = to.Anchored
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

--- A box that wraps a body part slightly larger than the part itself (a sleeve, a trouser leg, a jacket).
local function shell(folder: Instance, part: BasePart?, color: Color3, pad: number?, mat: Enum.Material?, extra: Vector3?, offset: Vector3?)
	if not part then
		return nil
	end
	local size = part.Size + Vector3.new(1, 1, 1) * (pad or 0.08) + (extra or Vector3.zero)
	return attach(folder, part, part.CFrame * CFrame.new(offset or Vector3.zero), size, color, mat, nil, "Shell")
end

--- The visible size of a head (classic heads are 2 x 1 x 1 with a mesh; R15 heads are about 1.2 cubed).
local function headSize(head: BasePart): number
	return math.min(head.Size.X, head.Size.Y * 1.25, head.Size.Z * 1.25)
end

local function hair(folder: Instance, head: BasePart, styleId: string, color: Color3, tip: Color3, accent: Color3)
	local s = headSize(head)
	local function tuft(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3?, rot: CFrame?, shape: string?)
		local cf = head.CFrame * CFrame.new(x * s, y * s, z * s) * (rot or CFrame.new())
		attach(folder, head, cf, Vector3.new(sx * s, sy * s, sz * s), c or color, M.SmoothPlastic, shape, "Hair")
	end
	tuft(0, 0.38, 0.03, 1.12, 0.36, 1.14)
	tuft(0, 0.05, 0.36, 1.14, 0.78, 0.42)
	tuft(0, 0.3, -0.53, 1.06, 0.26, 0.14, mix(color, tip, 0.25))
	if styleId == "spiky" then
		for i = -2, 2 do
			tuft(i * 0.22, 0.62, 0.05, 0.24, 0.5, 0.24, if i % 2 == 0 then tip else color, CFrame.Angles(math.rad(-18), 0, math.rad(i * 14)))
		end
		tuft(0, 0.45, 0.55, 0.36, 0.42, 0.28, tip, CFrame.Angles(math.rad(-40), 0, 0))
	elseif styleId == "short" then
		tuft(0, 0.5, 0, 1.0, 0.16, 1.0, mix(color, tip, 0.2))
	elseif styleId == "slick" then
		tuft(0, 0.48, 0.12, 1.1, 0.18, 0.92, mix(color, tip, 0.2), CFrame.Angles(math.rad(-6), 0, 0))
	elseif styleId == "bob" then
		for _, sx in { -1, 1 } do
			tuft(sx * 0.58, -0.05, 0, 0.2, 0.92, 1.04, mix(color, tip, 0.35))
		end
	elseif styleId == "ponytail" then
		tuft(0, -0.3, 0.72, 0.3, 1.05, 0.3, mix(color, tip, 0.5), CFrame.Angles(math.rad(14), 0, 0))
		tuft(0, 0.2, 0.6, 0.26, 0.2, 0.2, accent)
	elseif styleId == "long" then
		tuft(0, -0.75, 0.42, 1.14, 1.55, 0.28, mix(color, tip, 0.35))
		for _, sx in { -1, 1 } do
			tuft(sx * 0.58, -0.32, -0.08, 0.18, 1.25, 0.6, mix(color, tip, 0.2))
		end
	elseif styleId == "twin" then
		for _, sx in { -1, 1 } do
			tuft(sx * 0.76, -0.35, 0.15, 0.28, 1.1, 0.28, mix(color, tip, 0.45), CFrame.Angles(0, 0, math.rad(sx * -12)))
			tuft(sx * 0.6, 0.35, 0.15, 0.2, 0.2, 0.2, accent, nil, "Ball")
		end
	elseif styleId == "bun" then
		tuft(0, 0.6, 0.38, 0.62, 0.62, 0.62, color, nil, "Ball")
		tuft(0, 0.62, 0.38, 0.75, 0.08, 0.08, accent)
	end
end

local function face(folder: Instance, head: BasePart, eye: Color3, browColor: Color3)
	local s = headSize(head)
	local front = -s / 2
	local function bit(x: number, y: number, dz: number, sx: number, sy: number, c: Color3, mat: Enum.Material?, rot: CFrame?)
		local cf = head.CFrame * CFrame.new(x * s, y * s, front - dz) * (rot or CFrame.new())
		attach(folder, head, cf, Vector3.new(sx * s, sy * s, 0.03), c, mat or M.SmoothPlastic, nil, "Face")
	end
	for _, sx in { -0.22, 0.22 } do
		bit(sx, 0.02, 0.01, 0.2, 0.27, Color3.new(1, 1, 1))
		bit(sx, 0.04, 0.025, 0.15, 0.22, eye, M.Neon)
		bit(sx, 0.08, 0.04, 0.07, 0.08, hex(0x10121a))
		bit(sx, 0.22, 0.015, 0.24, 0.045, browColor, nil, CFrame.Angles(0, 0, math.rad(sx * 25)))
	end
	bit(0, -0.24, 0.01, 0.16, 0.035, hex(0x8a4a44))
end

--- Dress `character` in `look` (a Looks.Look) and the uniform of `schoolId` (nil = visitor colours).
function Appearance.apply(character: Model, look, schoolId: string?)
	look = Looks.sanitize(look)
	local old = character:FindFirstChild("HalcyonLook")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "HalcyonLook"

	local uniform, accent = colours(schoolId)
	local skin = Looks.Skin[look.skin].color
	local hairInfo = Looks.HairColors[look.hairColor]
	local outfit = Looks.Outfits[look.outfit].id
	local get = function(name: string): BasePart?
		local p = character:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	local head = get("Head")
	local upper, lower = get("UpperTorso"), get("LowerTorso")

	if not look.avatar then
		-- Replace the Roblox avatar's clothes and accessories with the school uniform.
		for _, child in character:GetChildren() do
			if CLOTHING[child.ClassName] then
				child:Destroy()
			end
		end
		if head then
			local decal = head:FindFirstChild("face")
			if decal then
				decal:Destroy()
			end
			head.Color = skin
		end
		for _, name in LIMBS do
			local part = get(name)
			if part then
				part.Color = skin
			end
		end
		local bodyColors = character:FindFirstChildOfClass("BodyColors")
		if bodyColors then
			bodyColors.HeadColor3 = skin
			bodyColors.TorsoColor3 = skin
			bodyColors.LeftArmColor3 = skin
			bodyColors.RightArmColor3 = skin
			bodyColors.LeftLegColor3 = skin
			bodyColors.RightLegColor3 = skin
		end

		local armour = outfit == "armor"
		local legColor = if outfit == "skirt" then mix(skin, uniform.dark, 0.75) else uniform.pants
		shell(folder, upper, uniform.jacket, 0.1)
		shell(folder, lower, uniform.dark, 0.1)
		for _, side in { "Left", "Right" } do
			shell(folder, get(side .. "UpperArm"), if armour then skin else uniform.jacket, 0.08)
			shell(folder, get(side .. "LowerArm"), if armour then hex(0x8b8f9a) else uniform.jacket, 0.08, if armour then M.Metal else nil)
			shell(folder, get(side .. "Hand"), uniform.glove, 0.04)
			shell(folder, get(side .. "UpperLeg"), legColor, 0.08)
			shell(folder, get(side .. "LowerLeg"), uniform.boots, 0.1)
			shell(folder, get(side .. "Foot"), uniform.boots, 0.12)
			local lowerArm = get(side .. "LowerArm")
			if lowerArm and not armour then
				attach(folder, lowerArm, lowerArm.CFrame * CFrame.new(0, lowerArm.Size.Y * 0.3, 0), Vector3.new(lowerArm.Size.X + 0.14, 0.1, lowerArm.Size.Z + 0.14), accent, M.Neon, nil, "Cuff")
			end
			local upperArm = get(side .. "UpperArm")
			if upperArm and armour then
				attach(folder, upperArm, upperArm.CFrame * CFrame.new(0, upperArm.Size.Y * 0.35, 0), upperArm.Size * Vector3.new(1.35, 0.5, 1.35), hex(0x8b8f9a), M.Metal, nil, "Pauldron")
			end
		end
		if upper then
			local u = upper.Size
			-- placket and trim down the front of the jacket
			attach(folder, upper, upper.CFrame * CFrame.new(0, 0, -u.Z / 2 - 0.07), Vector3.new(0.18, u.Y * 0.9, 0.04), accent, M.Neon, nil, "Trim")
			attach(folder, upper, upper.CFrame * CFrame.new(u.X * 0.26, u.Y * 0.2, -u.Z / 2 - 0.08), Vector3.new(0.28, 0.28, 0.04) , accent, M.Neon, nil, "Badge")
			if outfit == "hoodie" then
				attach(folder, upper, upper.CFrame * CFrame.new(0, u.Y * 0.32, u.Z * 0.62), Vector3.new(u.X * 0.75, u.Y * 0.45, u.Z * 0.35), uniform.jacket, M.Fabric, nil, "Hood")
			elseif armour then
				attach(folder, upper, upper.CFrame * CFrame.new(0, u.Y * 0.05, -0.04), u + Vector3.new(0.3, -u.Y * 0.25, 0.3), hex(0x8b8f9a), M.Metal, nil, "Breastplate")
				attach(folder, upper, upper.CFrame * CFrame.new(0, u.Y * 0.1, -u.Z / 2 - 0.2), Vector3.new(u.X * 0.5, 0.12, 0.04), accent, M.Neon, nil, "Trim")
			end
		end
		if lower then
			local l = lower.Size
			if outfit == "skirt" then
				attach(folder, lower, lower.CFrame * CFrame.new(0, -l.Y * 0.9, 0), Vector3.new(l.X + 0.5, l.Y * 1.6, l.Z + 0.45), uniform.dark, M.Fabric, nil, "Skirt")
				attach(folder, lower, lower.CFrame * CFrame.new(0, -l.Y * 1.62, -l.Z / 2 - 0.24), Vector3.new(l.X + 0.5, 0.08, 0.03), accent, M.Neon, nil, "Trim")
			elseif outfit == "coat" then
				attach(folder, lower, lower.CFrame * CFrame.new(0, -l.Y * 1.4, l.Z * 0.28), Vector3.new(l.X + 0.3, l.Y * 2.6, l.Z * 0.5), uniform.jacket, M.Fabric, nil, "CoatTail")
				attach(folder, lower, lower.CFrame * CFrame.new(0, -l.Y * 2.6, l.Z * 0.55), Vector3.new(l.X + 0.3, 0.1, 0.03), accent, M.Neon, nil, "Trim")
			end
			attach(folder, lower, lower.CFrame * CFrame.new(0, l.Y * 0.38, 0), Vector3.new(l.X + 0.2, 0.2, l.Z + 0.2), uniform.dark, M.SmoothPlastic, nil, "Belt")
		end
		if head then
			face(folder, head, Looks.EyeColors[look.eye].color, mix(hairInfo.color, Color3.new(0, 0, 0), 0.3))
			hair(folder, head, Looks.HairStyles[look.hair].id, hairInfo.color, hairInfo.tip, accent)
		end
	else
		-- Keep the player's own avatar and add a school armband and sash.
		local arm = get("LeftUpperArm")
		if arm then
			attach(folder, arm, arm.CFrame, arm.Size + Vector3.new(0.12, -arm.Size.Y * 0.7, 0.12), accent, M.Neon, nil, "Armband")
		end
		if upper then
			local u = upper.Size
			attach(folder, upper, upper.CFrame * CFrame.Angles(0, 0, math.rad(35)), Vector3.new(0.35, u.Y * 1.25, u.Z + 0.12), accent, M.Fabric, nil, "Sash")
		end
	end

	folder.Parent = character
	character:SetAttribute("HalcyonSchool", schoolId or "")
	return folder
end

--- A plain R15-shaped stand-in (feet on the origin, facing -Z) for previews when no avatar model is available.
function Appearance.mannequin(): Model
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local parts = {
		{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5.45, 0) },
		{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 4.0, 0) },
		{ "LowerTorso", Vector3.new(2, 0.6, 1), Vector3.new(0, 2.9, 0) },
		{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 4.2, 0) },
		{ "LeftLowerArm", Vector3.new(1, 1.0, 1), Vector3.new(-1.5, 3.1, 0) },
		{ "LeftHand", Vector3.new(1, 0.5, 1), Vector3.new(-1.5, 2.35, 0) },
		{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 4.2, 0) },
		{ "RightLowerArm", Vector3.new(1, 1.0, 1), Vector3.new(1.5, 3.1, 0) },
		{ "RightHand", Vector3.new(1, 0.5, 1), Vector3.new(1.5, 2.35, 0) },
		{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, 2.0, 0) },
		{ "LeftLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(-0.5, 0.95, 0) },
		{ "LeftFoot", Vector3.new(1, 0.4, 1.1), Vector3.new(-0.5, 0.2, 0) },
		{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, 2.0, 0) },
		{ "RightLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(0.5, 0.95, 0) },
		{ "RightFoot", Vector3.new(1, 0.4, 1.1), Vector3.new(0.5, 0.2, 0) },
	}
	for _, def in parts do
		local p = Instance.new("Part")
		p.Name = def[1]
		p.Size = def[2]
		p.CFrame = CFrame.new(def[3])
		p.Anchored = true
		p.Color = Looks.Skin[2].color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("LowerTorso")
	return model
end

return Appearance
