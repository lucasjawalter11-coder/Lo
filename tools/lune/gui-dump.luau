-- Dev helper: builds a menu screen offline, lays it out like Roblox does (scale + offset sizes, padding,
-- list and grid layouts, size constraints) and writes draw commands for tools/preview/gui.html.
-- Usage: lune run tools/lune/gui-dump.luau <width> <height> <tab 1-4> <out.json>
local Harness = require("./harness")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local fs = require("@lune/fs")

local W, H = tonumber(process.args[1]) or 1280, tonumber(process.args[2]) or 720
local TAB = tonumber(process.args[3]) or 1
local OUT = process.args[4] or "build/gui.json"

local realGame = Harness.loadPlace("build/base.rbxl")
local stubSignal = { Connect = function() return { Disconnect = function() end } end, Once = function() end }
for _, ev in { "Activated", "MouseEnter", "MouseLeave", "SelectionGained", "SelectionLost", "InputBegan", "InputEnded" } do
	pcall(function()
		roblox.implementProperty("GuiObject", ev, function() return stubSignal end)
	end)
end
local services = {
	ContextActionService = { BindActionAtPriority = function() end, UnbindAction = function() end, BindAction = function() end },
	GuiService = {},
	RunService = { RenderStepped = stubSignal, Heartbeat = stubSignal },
	UserInputService = { InputChanged = stubSignal, InputEnded = stubSignal, InputBegan = stubSignal, GetLastInputType = function() return { Name = "MouseButton1" } end, TouchEnabled = false },
	Players = { LocalPlayer = nil },
	TweenService = { Create = function() return { Play = function() end } end },
}
local fakeGame = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, name) return services[name] or realGame:GetService(name) end
	end
	return realGame[k]
end })
local requireModule = Harness.loader(Harness.globals(realGame, { game = fakeGame }))
local client = realGame:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("HalcyonClient")
local CustomizeUi = requireModule(client:FindFirstChild("CustomizeUi"))

local gui = roblox.Instance.new("ScreenGui")
local state = { profile = { school = "solcrest", look = { outfit = 2, hair = 5, hairColor = 4, eye = 2, skin = 3, avatar = false } }, look = {} }
local screen = CustomizeUi.build(gui, { state = state, remote = nil, click = function() end, onDone = function() end, viewSize = function() return roblox.Vector2.new(W, H) end })
screen.refresh()
screen.frame.Visible = true
-- open the requested tab by pressing its button's handler: simulate by toggling pages
local ui = screen.ui
ui.tab = TAB
ui.refresh()

-- ---------------------------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------------------------
local ops = {}
local function c3(c) return { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } end
local function udim(u, total) return u.Scale * total + u.Offset end
local function child(inst, cls) return inst:FindFirstChildOfClass(cls) end

local function constrain(inst, w, h)
	local sc = child(inst, "UISizeConstraint")
	if sc then
		w = math.clamp(w, sc.MinSize.X, sc.MaxSize.X)
		h = math.clamp(h, sc.MinSize.Y, sc.MaxSize.Y)
	end
	return w, h
end

local layout -- forward

local function contentHeight(inst, w)
	-- for AutomaticSize Y: lay children out in a probe and measure
	local probe = {}
	local saved = ops
	ops = probe
	local bottom = layout(inst, 0, 0, w, 100000, true)
	ops = saved
	return bottom
end

local function sorted(inst)
	local kids = {}
	for _, k in inst:GetChildren() do
		if k:IsA("GuiObject") and k.Visible then
			table.insert(kids, k)
		end
	end
	table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	return kids
end

local function draw(inst, x, y, w, h)
	local corner = child(inst, "UICorner")
	local radius = if corner then math.min(corner.CornerRadius.Offset + corner.CornerRadius.Scale * math.min(w, h), math.min(w, h) / 2) else 0
	local stroke = child(inst, "UIStroke")
	local grad = child(inst, "UIGradient")
	if inst.BackgroundTransparency < 1 or stroke then
		table.insert(ops, {
			k = "rect", x = x, y = y, w = w, h = h, c = c3(inst.BackgroundColor3), t = inst.BackgroundTransparency, r = radius,
			s = if stroke then { c = c3(stroke.Color), w = stroke.Thickness, t = stroke.Transparency } else nil,
			g = if grad then { c3(grad.Color.Keypoints[1].Value), c3(grad.Color.Keypoints[#grad.Color.Keypoints].Value), grad.Rotation } else nil,
		})
	end
	if inst:IsA("ViewportFrame") then
		table.insert(ops, { k = "viewport", x = x, y = y, w = w, h = h })
	end
	if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text ~= "" then
		local p = child(inst, "UIPadding")
		local tx, ty, tw, th = x, y, w, h
		if p then
			tx += udim(p.PaddingLeft, w); tw -= udim(p.PaddingLeft, w) + udim(p.PaddingRight, w)
			ty += udim(p.PaddingTop, h); th -= udim(p.PaddingTop, h) + udim(p.PaddingBottom, h)
		end
		table.insert(ops, {
			k = "text", x = tx, y = ty, w = tw, h = th, text = inst.Text, c = c3(inst.TextColor3), t = inst.TextTransparency,
			align = inst.TextXAlignment.Name, scaled = inst.TextScaled, size = inst.TextSize, font = inst.Font.Name,
		})
	end
end

layout = function(inst, px, py, pw, ph, measuring)
	-- inner box after padding
	local p = child(inst, "UIPadding")
	local ix, iy, iw, ih = px, py, pw, ph
	if p then
		ix += udim(p.PaddingLeft, pw); iw -= udim(p.PaddingLeft, pw) + udim(p.PaddingRight, pw)
		iy += udim(p.PaddingTop, ph); ih -= udim(p.PaddingTop, ph) + udim(p.PaddingBottom, ph)
	end
	local list = child(inst, "UIListLayout")
	local grid = child(inst, "UIGridLayout")
	local bottom = iy
	local cursor = 0
	local col, rowY, rowH = 0, iy, 0
	for _, k in sorted(inst) do
		local w = udim(k.Size.X, iw)
		local h = udim(k.Size.Y, ih)
		if grid then
			w = udim(grid.CellSize.X, iw)
			h = udim(grid.CellSize.Y, ih)
		end
		w, h = constrain(k, w, h)
		if k.AutomaticSize == roblox.Enum.AutomaticSize.Y then
			h = math.max(h, contentHeight(k, w) - 0)
		end
		local x, y
		if grid then
			local gap = udim(grid.CellPadding.X, iw)
			local cellW = udim(grid.CellSize.X, iw)
			local perRow = math.max(1, math.floor((iw + gap) / (cellW + gap)))
			if col >= perRow then
				col = 0
				rowY += rowH + udim(grid.CellPadding.Y, ih)
				rowH = 0
			end
			x = ix + col * (cellW + gap)
			y = rowY
			-- a tile may be smaller than its cell (round swatches)
			local ow, oh = udim(k.Size.X, iw), udim(k.Size.Y, ih)
			if ow > 0 and ow < w then w = ow end
			if oh > 0 and oh < h then h = oh end
			col += 1
			rowH = math.max(rowH, udim(grid.CellSize.Y, ih))
		elseif list then
			local gap = list.Padding.Offset + list.Padding.Scale * (if list.FillDirection == roblox.Enum.FillDirection.Horizontal then iw else ih)
			if list.FillDirection == roblox.Enum.FillDirection.Horizontal then
				x, y = ix + cursor, iy
				cursor += w + gap
			else
				x, y = ix, iy + cursor
				cursor += h + gap
			end
		else
			x = ix + udim(k.Position.X, iw) - w * k.AnchorPoint.X
			y = iy + udim(k.Position.Y, ih) - h * k.AnchorPoint.Y
		end
		draw(k, x, y, w, h)
		local clips = k:IsA("ScrollingFrame")
		if clips then
			table.insert(ops, { k = "clip", x = x, y = y, w = w, h = h })
		end
		layout(k, x, y, w, h, measuring)
		if clips then
			table.insert(ops, { k = "unclip" })
		end
		bottom = math.max(bottom, y + h)
	end
	if grid then
		bottom = math.max(bottom, rowY + rowH)
	end
	if p then
		bottom += udim(p.PaddingBottom, ph)
	end
	return bottom - py
end

layout(gui, 0, 0, W, H)
fs.writeFile(OUT, serde.encode("json", { w = W, h = H, ops = ops }))
print("ops", #ops)

-- the preview model, for the 3D renderer
local p = ui.preview
if p.model then
	Harness.writeJson("build/gui-model.json", Harness.dumpScene({ p.world }))
end
