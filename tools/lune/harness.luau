-- Offline harness: loads the Rojo-built place in Lune and runs the game's ModuleScripts against real
-- Roblox instances and datatypes (properties and enums are validated by Lune's reflection database).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local luneTask = require("@lune/task")

local Harness = {}

local DATATYPES = {
	"Axes", "BrickColor", "CFrame", "Color3", "ColorSequence", "ColorSequenceKeypoint", "Faces", "Font", "NumberRange",
	"NumberSequence", "NumberSequenceKeypoint", "PhysicalProperties", "Ray", "Rect", "Region3", "Region3int16", "UDim", "UDim2",
	"Vector2", "Vector2int16", "Vector3", "Vector3int16",
}

-- Lune implements instances and properties, but not every method. Fill in the few the builders rely on.
local patched = false
local function patchInstances()
	if patched then
		return
	end
	patched = true
	local function pivotOf(model)
		if model.PrimaryPart then
			return model.PrimaryPart.CFrame
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				return d.CFrame
			end
		end
		return roblox.CFrame.new()
	end
	-- Lune stores a part's placement only in CFrame; read Position from it like Roblox does
	roblox.implementProperty("BasePart", "Position", function(self)
		return self.CFrame.Position
	end, function(self, value)
		self.CFrame = roblox.CFrame.new(value) * self.CFrame.Rotation
	end)
	roblox.implementMethod("Model", "GetPivot", function(self)
		return pivotOf(self)
	end)
	roblox.implementMethod("Model", "PivotTo", function(self, target)
		local delta = target * pivotOf(self):Inverse()
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
	end)
	roblox.implementMethod("Instance", "WaitForChild", function(self, name: string)
		local child = self:FindFirstChild(name)
		assert(child, "WaitForChild: " .. self:GetFullName() .. " has no child named " .. tostring(name))
		return child
	end)
end

function Harness.loadPlace(path: string)
	patchInstances()
	return roblox.deserializePlace(fs.readFile(path))
end

function Harness.savePlace(game, path: string)
	fs.writeFile(path, roblox.serializePlace(game))
end

--- Globals a Roblox script expects. `extra` overrides or adds entries (the simulator passes its own task, etc.).
function Harness.globals(game, extra: { [string]: any }?): { [string]: any }
	local g: { [string]: any } = {}
	for _, name in DATATYPES do
		g[name] = (roblox :: any)[name]
	end
	g.Instance = roblox.Instance
	g.Enum = roblox.Enum
	g.game = game
	g.workspace = game:GetService("Workspace")
	g.task = luneTask
	g.tick = os.clock
	g.time = os.clock
	g.warn = function(...)
		print("[warn]", ...)
	end
	g.Random = {
		new = function(seed: number?)
			local state = (seed or 1) % 2147483647
			if state <= 0 then
				state += 2147483646
			end
			local self = {}
			function self:NextNumber(lo: number?, hi: number?): number
				state = (state * 48271) % 2147483647
				local u = (state - 1) / 2147483646
				return if lo and hi then lo + (hi - lo) * u else u
			end
			function self:NextInteger(lo: number, hi: number): number
				return math.floor(self:NextNumber(lo, hi + 1 - 1e-9))
			end
			return self
		end,
	}
	if extra then
		for k, v in extra do
			g[k] = v
		end
	end
	return g
end

--- A `require` that works on ModuleScript instances, the way Roblox does.
function Harness.loader(globals: { [string]: any })
	local cache: { [string]: { value: any } } = {}
	local loading: { [string]: boolean } = {}
	local function requireModule(module): any
		assert(module ~= nil, "require(nil): a module path is wrong")
		local key = module:GetFullName()
		local hit = cache[key]
		if hit then
			return hit.value
		end
		assert(not loading[key], "circular require: " .. key)
		loading[key] = true
		local env = table.clone(globals)
		env.script = module
		env.require = requireModule
		local chunk = luau.load(module.Source, { debugName = key, environment = env })
		local value = chunk()
		loading[key] = nil
		cache[key] = { value = value }
		return value
	end
	return requireModule
end

-- ---------------------------------------------------------------------------------------------
-- Scene dump for the preview renderer (tools/preview)
-- ---------------------------------------------------------------------------------------------
local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function guiNodes(gui, out, px: number, py: number, pw: number, ph: number)
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") then
			local size, pos, anchor = child.Size, child.Position, child.AnchorPoint
			local w, h = pw * size.X.Scale, ph * size.Y.Scale
			local x = px + pw * pos.X.Scale - w * anchor.X
			local y = py + ph * pos.Y.Scale - h * anchor.Y
			local corner = child:FindFirstChildOfClass("UICorner")
			local node: { [string]: any } = {
				x = round(x), y = round(y), w = round(w), h = round(h),
				c = { round(child.BackgroundColor3.R), round(child.BackgroundColor3.G), round(child.BackgroundColor3.B) },
				t = round(child.BackgroundTransparency),
				rot = round(child.Rotation),
				corner = if corner then round(corner.CornerRadius.Scale) else 0,
			}
			if child:IsA("TextLabel") then
				node.text = child.Text
				node.tc = { round(child.TextColor3.R), round(child.TextColor3.G), round(child.TextColor3.B) }
			end
			table.insert(out, node)
			guiNodes(child, out, x, y, w, h)
		end
	end
end

--- Flatten every BasePart under `roots` into a JSON-friendly list.
function Harness.dumpScene(roots: { any }): { any }
	local parts = {}
	for _, root in roots do
		local list = root:GetDescendants()
		if root:IsA("BasePart") then
			table.insert(list, root)
		end
		for _, inst in list do
			if inst:IsA("BasePart") and inst.Transparency < 0.99 then
				local shape = "Block"
				if inst.ClassName == "WedgePart" then
					shape = "Wedge"
				elseif inst.ClassName == "Part" then
					shape = inst.Shape.Name
				end
				local cf = inst.CFrame
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
				local rec: { [string]: any } = {
					s = shape,
					p = { round(x), round(y), round(z) },
					r = { round(r00), round(r01), round(r02), round(r10), round(r11), round(r12), round(r20), round(r21), round(r22) },
					z = { round(inst.Size.X), round(inst.Size.Y), round(inst.Size.Z) },
					c = { round(inst.Color.R), round(inst.Color.G), round(inst.Color.B) },
					m = inst.Material.Name,
				}
				if inst.Transparency > 0 then
					rec.t = round(inst.Transparency)
				end
				for _, child in inst:GetChildren() do
					if child:IsA("SurfaceGui") then
						local nodes = {}
						guiNodes(child, nodes, 0, 0, 1, 1)
						rec.gui = rec.gui or {}
						table.insert(rec.gui, { face = child.Face.Name, nodes = nodes })
					end
				end
				table.insert(parts, rec)
			end
		end
	end
	return parts
end

function Harness.writeJson(path: string, value: any)
	fs.writeFile(path, serde.encode("json", value))
end

return Harness
