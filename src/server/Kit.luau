--!nonstrict
-- Kit: helpers for building the world, the arena, NPCs and weapons out of plain parts.
-- Everything here only creates instances and sets properties, so the same code runs inside Roblox
-- and in the offline bake (tools/lune/bake.luau) that produces the place file.

local Kit = {}

local M = Enum.Material
Kit.Mat = M

function Kit.hex(n: number): Color3
	return Color3.fromRGB(bit32.band(bit32.rshift(n, 16), 255), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end

function Kit.mix(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

function Kit.shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

--- Create an instance, set properties, then parent it (parenting last is cheaper for replication).
function Kit.new(className: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			(inst :: any)[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

export type PartOpts = {
	name: string?,
	trans: number?,
	refl: number?,
	decor: boolean?, -- no collision, no shadow: pure decoration
	collide: boolean?,
	shadow: boolean?,
	rot: CFrame?, -- extra local rotation about the part's centre
	anchored: boolean?,
	massless: boolean?,
}

local function finishPart(p: BasePart, parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, o: PartOpts?)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o then
		if o.name then
			p.Name = o.name
		end
		if o.trans then
			p.Transparency = o.trans
		end
		if o.refl then
			p.Reflectance = o.refl
		end
		if o.decor or o.collide == false then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
		if o.decor or o.shadow == false then
			p.CastShadow = false
		end
		if o.anchored == false then
			p.Anchored = false
		end
		if o.massless then
			p.Massless = true
		end
	end
	p.Parent = parent
	return p
end

--- A free-standing part with an explicit CFrame. shape: "Block" | "Ball" | "Cylinder" | "Wedge".
function Kit.part(parent: Instance, shape: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	if shape == "Wedge" then
		return finishPart(Instance.new("WedgePart"), parent, size, cf, color, mat, o)
	end
	local p = Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	return finishPart(p, parent, size, cf, color, mat, o)
end

-- ---------------------------------------------------------------------------------------------
-- Builder: places primitives relative to a moving local frame, so a building can be written once
-- and stamped anywhere at any heading. Boxes and cylinders are positioned by their BOTTOM centre.
-- ---------------------------------------------------------------------------------------------
local Builder = {}
Builder.__index = Builder
export type Builder = typeof(setmetatable({} :: { parent: Instance, cf: CFrame }, Builder))

function Kit.at(parent: Instance, cf: CFrame?): Builder
	return setmetatable({ parent = parent, cf = cf or CFrame.new() }, Builder)
end

--- A child Model with its own local frame.
function Builder.group(self: Builder, name: string, x: number?, y: number?, z: number?, yawDeg: number?): Builder
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = self.parent
	local cf = self.cf * CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
	return setmetatable({ parent = m, cf = cf }, Builder)
end

--- Same parent, shifted frame.
function Builder.shift(self: Builder, x: number, y: number, z: number, yawDeg: number?): Builder
	local cf = self.cf * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
	return setmetatable({ parent = self.parent, cf = cf }, Builder)
end

function Builder.world(self: Builder, x: number, y: number, z: number): Vector3
	return self.cf * Vector3.new(x, y, z)
end

function Builder.box(self: Builder, x: number, y0: number, z: number, sx: number, sy: number, sz: number, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	local cf = self.cf * CFrame.new(x, y0 + sy / 2, z)
	if o and o.rot then
		cf = cf * o.rot
	end
	return finishPart(Instance.new("Part"), self.parent, Vector3.new(sx, sy, sz), cf, color, mat, o)
end

--- Upright cylinder standing on (x, y0, z).
function Builder.cyl(self: Builder, x: number, y0: number, z: number, radius: number, height: number, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	local cf = self.cf * CFrame.new(x, y0 + height / 2, z)
	if o and o.rot then
		cf = cf * o.rot
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	return finishPart(p, self.parent, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, o)
end

--- Cylinder lying along the local X axis ("x") or Z axis ("z"), centred on (x, y, z).
function Builder.rod(self: Builder, axis: string, x: number, y: number, z: number, radius: number, length: number, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	local cf = self.cf * CFrame.new(x, y, z)
	if axis == "z" then
		cf = cf * CFrame.Angles(0, math.rad(90), 0)
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	return finishPart(p, self.parent, Vector3.new(length, radius * 2, radius * 2), cf, color, mat, o)
end

function Builder.ball(self: Builder, x: number, y: number, z: number, radius: number, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	return finishPart(p, self.parent, Vector3.new(radius * 2, radius * 2, radius * 2), self.cf * CFrame.new(x, y, z), color, mat, o)
end

--- Wedge standing on y0. With yaw 0 the tall face is at +Z and the slope falls toward -Z.
function Builder.wedge(self: Builder, x: number, y0: number, z: number, sx: number, sy: number, sz: number, yawDeg: number, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	local cf = self.cf * CFrame.new(x, y0 + sy / 2, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	if o and o.rot then
		cf = cf * o.rot
	end
	return finishPart(Instance.new("WedgePart"), self.parent, Vector3.new(sx, sy, sz), cf, color, mat, o)
end

--- A straight bar between two local points (cables, struts, sloped rails).
function Builder.bar(self: Builder, a: Vector3, b: Vector3, thick: number, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	local wa, wb = self.cf * a, self.cf * b
	local len = (wb - wa).Magnitude
	local up = if math.abs((wb - wa).Unit.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt((wa + wb) / 2, wb, up)
	return finishPart(Instance.new("Part"), self.parent, Vector3.new(thick, thick, len), cf, color, mat, o)
end

--- Any part by centre with a full local CFrame (for tilted or rolled pieces).
function Builder.piece(self: Builder, shape: string, localCf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, o: PartOpts?): BasePart
	--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit.part(self.parent, shape, size, self.cf * localCf, color, mat, o)
end

--- Blocks arranged in a circle (rings, colonnades, rails). `each(b, i, angle)` gets a frame at the rim
--- whose -Z points at the centre.
function Builder.ring(self: Builder, x: number, y: number, z: number, radius: number, count: number, each: (b: Builder, i: number, angle: number) -> (), startDeg: number?, sweepDeg: number?)
	local start = math.rad(startDeg or 0)
	local sweep = math.rad(sweepDeg or 360)
	local steps = if (sweepDeg or 360) >= 360 then count else math.max(count - 1, 1)
	for i = 0, count - 1 do
		local a = start + sweep * (i / steps)
		local px, pz = x + math.sin(a) * radius, z + math.cos(a) * radius
		-- frame at the rim, facing the centre (its -Z looks inward)
		local cf = self.cf * CFrame.new(px, y, pz) * CFrame.Angles(0, a, 0)
		each(setmetatable({ parent = self.parent, cf = cf }, Builder), i, a)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Lights, signs and effects
-- ---------------------------------------------------------------------------------------------
function Kit.glow(part: Instance, range: number, brightness: number, color: Color3, shadows: boolean?): PointLight
	--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit.new("PointLight", { Range = range, Brightness = brightness, Color = color, Shadows = shadows == true }, part)
end

function Kit.spot(part: Instance, face: Enum.NormalId, range: number, brightness: number, color: Color3, angle: number?): SpotLight
	--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit.new("SpotLight", { Face = face, Range = range, Brightness = brightness, Color = color, Angle = angle or 70, Shadows = false }, part)
end

export type LabelOpts = {
	color: Color3?,
	font: Enum.Font?,
	bg: Color3?,
	bgTrans: number?,
	glow: boolean?, -- true: ignore world lighting (holographic)
	pps: number?,
	stroke: Color3?,
	name: string?,
	sizeY: number?, -- fraction of the face height used by the text
	posY: number?,
}

--- Text on one face of a part.
function Kit.label(part: BasePart, face: Enum.NormalId, text: string, o: LabelOpts?): TextLabel
	local opts: LabelOpts = o or {}
	local gui = Kit.new("SurfaceGui", {
		Name = opts.name or "Label",
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = opts.pps or 24,
		LightInfluence = if opts.glow == false then 1 else 0,
		Brightness = if opts.glow == false then 1 else 1.6,
		ResetOnSpawn = false,
	}, part)
	if opts.bg then
		Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = opts.bg, BackgroundTransparency = opts.bgTrans or 0, BorderSizePixel = 0 }, gui)
	end
	--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit.new("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(0.94, opts.sizeY or 0.8),
		Position = UDim2.fromScale(0.5, opts.posY or 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		FontFace = Font.fromEnum(opts.font or Enum.Font.Michroma),
		TextColor3 = opts.color or Color3.new(1, 1, 1),
		TextStrokeColor3 = opts.stroke or Color3.new(0, 0, 0),
		TextStrokeTransparency = if opts.stroke then 0.2 else 1,
	}, gui)
end

--- Rigid joint that keeps `part` where it currently is relative to `to`.
function Kit.weld(to: BasePart, part: BasePart): Weld
	--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit.new("Weld", { Name = "Fix", Part0 = to, Part1 = part, C0 = to.CFrame:ToObjectSpace(part.CFrame) }, part)
end

function Kit.attachment(part: BasePart, name: string, pos: Vector3): Attachment
	--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit.new("Attachment", { Name = name, Position = pos }, part)
end

function Kit.sparkles(part: Instance, color: Color3, rate: number, o: { [string]: any }?): ParticleEmitter
	local props: { [string]: any } = {
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Rate = rate,
		Lifetime = NumberRange.new(1.2, 2.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	}
	if o then
		for k, v in o do
			props[k] = v
		end
	end
	--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit.new("ParticleEmitter", props, part)
end

--- Scales a built model about `origin` (parts, lights, attachments and surface text all keep their look).
function Kit.scale(model: Instance, s: number, origin: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(rel.Position * s) * rel.Rotation)
		elseif d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * s)
		elseif d:IsA("SurfaceGui") then
			d.PixelsPerStud = d.PixelsPerStud / s
		end
	end
end

return Kit
