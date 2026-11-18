--!nonstrict
-- CustomizeUi: the character creator. A large live preview on the left (drag, swipe or right stick to turn
-- it), category tabs on the right with tiles you click directly, and Random / Reset / Back / Save below.
-- Controller: D-pad or stick between tiles, A to pick, LB / RB to change tab, B to go back.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Looks = require(Shared:WaitForChild("Looks"))
local Appearance = require(Shared:WaitForChild("Appearance"))

local CustomizeUi = {}

local INK = Color3.fromRGB(9, 12, 24)
local PANEL = Color3.fromRGB(17, 22, 41)
local TILE = Color3.fromRGB(26, 32, 56)
local LINE = Color3.fromRGB(46, 55, 88)
local WHITE = Color3.fromRGB(240, 244, 252)
local DIM = Color3.fromRGB(146, 156, 188)
local GOLD = Color3.fromRGB(255, 201, 74)

local TABS = {
	{ id = "uniform", label = "UNIFORM", focus = "body" },
	{ id = "hair", label = "HAIR", focus = "face" },
	{ id = "eyes", label = "EYES", focus = "face" },
	{ id = "skin", label = "SKIN", focus = "body" },
}

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

local function corner(parent, r: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, parent)
end

local function stroke(parent, color: Color3, thickness: number?, transparency: number?)
	return make("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function pad(parent, px: number)
	return make("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) }, parent)
end

local function text(parent, value: string, props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1, Text = value, Font = Enum.Font.GothamBold, TextColor3 = WHITE,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end

--- Builds the Customize screen inside `gui`. deps: { state, remote, onDone(saved), click() }
function CustomizeUi.build(gui: ScreenGui, deps)
	local state = deps.state
	local ui = { tab = 1, tiles = {}, preview = {}, dragging = false, lastDrag = 0, spin = 0, spinTarget = 0 }
	local accent = Config.hex(0x6fe6ff)

	local root = make("Frame", { Name = "Customize", BackgroundColor3 = INK, BackgroundTransparency = 0.15, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(14, 20, 44), INK),
		Rotation = 90,
	}, root)
	-- the screen starts below Roblox's own top bar, and switches to a compact layout on phones
	local view = if deps.viewSize then deps.viewSize() else Vector2.new(1280, 720)
	local compact = view.Y < 520
	local topBar = if compact then 44 else 64
	local frame = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, topBar), Size = UDim2.new(1, if compact then -32 else -72, 1, -topBar - (if compact then 10 else 28)) }, root)
	make("UISizeConstraint", { MaxSize = Vector2.new(1320, 760) }, frame)
	local headH = if compact then 30 else 70 -- space taken by the title row
	local footH = if compact then 50 else 64 -- space taken by the button row
	local tileScale = if compact then 0.72 else 1

	-- header
	local title = text(frame, "CUSTOMIZE", { Size = UDim2.new(0.4, 0, 0, if compact then 24 else 38), Font = Enum.Font.GothamBlack })
	local subtitle = text(frame, "Saved to your profile. Your school sets the uniform colours.", { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(0.6, 0, 0, 15), TextColor3 = DIM, Font = Enum.Font.GothamMedium, Visible = not compact })
	local schoolChip = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, if compact then 0 else 4), Size = UDim2.new(0, if compact then 190 else 230, 0, if compact then 24 else 32), BackgroundColor3 = PANEL }, frame)
	corner(schoolChip, 16)
	local schoolStroke = stroke(schoolChip, accent, 1.5)
	local schoolDot = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(0, 10, 0, 10), BackgroundColor3 = accent }, schoolChip)
	corner(schoolDot, 5)
	local schoolName = text(schoolChip, "", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 30, 0.5, 0), Size = UDim2.new(1, -42, 0.56, 0), Font = Enum.Font.GothamBold })

	-- preview card
	local card = make("Frame", { Position = UDim2.new(0, 0, 0, headH), Size = UDim2.new(0.4, 0, 1, -headH - footH), BackgroundColor3 = PANEL }, frame)
	corner(card, 18)
	stroke(card, LINE, 1)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(30, 40, 78), Color3.fromRGB(14, 18, 34)), Rotation = 90 }, card)
	local vp = make("ViewportFrame", {
		Name = "Preview", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(150, 155, 180), LightColor = Color3.fromRGB(255, 244, 230), LightDirection = Vector3.new(-0.5, -1, -0.7),
	}, card)
	local world = make("WorldModel", {}, vp)
	local cam = make("Camera", { FieldOfView = 30 }, vp)
	vp.CurrentCamera = cam
	local hint = text(card, "Drag to turn", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0.6, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = DIM, Font = Enum.Font.GothamMedium })
	ui.preview = { vp = vp, world = world, cam = cam }

	-- options panel
	local panel = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, headH), Size = UDim2.new(0.575, 0, 1, -headH - footH), BackgroundColor3 = PANEL }, frame)
	corner(panel, 18)
	stroke(panel, LINE, 1)
	pad(panel, if compact then 10 else 18)
	local tabH = if compact then 32 else 40
	local tabBar = make("Frame", { Size = UDim2.new(1, 0, 0, tabH), BackgroundColor3 = INK }, panel)
	corner(tabBar, 20)
	pad(tabBar, 4)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
	local tabButtons = {}
	local pages = {}
	local content = make("Frame", { Position = UDim2.new(0, 0, 0, tabH + 12), Size = UDim2.new(1, 0, 1, -tabH - 12), BackgroundTransparency = 1 }, panel)

	local selectTab -- forward
	for i, tab in TABS do
		local b = make("TextButton", {
			Name = tab.id, LayoutOrder = i, Size = UDim2.new(0.25, -3, 1, 0), AutoButtonColor = false,
			BackgroundColor3 = PANEL, BackgroundTransparency = 1, Text = tab.label, Font = Enum.Font.GothamBlack,
			TextScaled = true, TextColor3 = DIM, Selectable = true,
		}, tabBar)
		corner(b, 16)
		make("UIPadding", { PaddingTop = UDim.new(0.26, 0), PaddingBottom = UDim.new(0.26, 0) }, b)
		b.Activated:Connect(function()
			deps.click()
			selectTab(i)
		end)
		tabButtons[i] = b
		pages[i] = make("ScrollingFrame", {
			Name = tab.id .. "Page", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, ScrollBarImageColor3 = LINE, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = i == 1,
		}, content)
		make("UIListLayout", { Padding = UDim.new(0, if compact then 8 else 14), SortOrder = Enum.SortOrder.LayoutOrder }, pages[i])
		make("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, pages[i])
	end

	local function section(page, order: number, label: string)
		text(page, label, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 14), TextColor3 = DIM, Font = Enum.Font.GothamBold })
	end

	--- A grid of tiles for one look field. kind: "card" (name tiles) or "swatch" (colour circles).
	local function grid(page, order: number, field: string, list, kind: string, columns: number, height: number)
		height = math.floor(height * tileScale)
		local holder = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, page)
		make("UIGridLayout", {
			-- swatches are round and fixed-size; name cards share the row evenly
			CellSize = if kind == "swatch" then UDim2.new(0, height, 0, height) else UDim2.new(1 / columns, -10, 0, height),
			CellPadding = UDim2.new(0, if kind == "swatch" then 14 else 10, 0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, holder)
		for i, opt in list do
			local tile = make("TextButton", {
				Name = field .. i, LayoutOrder = i, AutoButtonColor = false, Text = "", BackgroundColor3 = TILE, Selectable = true,
			}, holder)
			corner(tile, if kind == "swatch" then height else 12)
			local ring = stroke(tile, LINE, 1.5)
			if kind == "swatch" then
				local dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, height - 14, 0, height - 14), BackgroundColor3 = opt.color }, tile)
				corner(dot, height)
				if opt.tip then
					local tipDot = make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, (height - 14) / 2, 0.5, (height - 14) / 2), Size = UDim2.new(0, (height - 14) * 0.42, 0, (height - 14) * 0.42), BackgroundColor3 = opt.tip }, tile)
					corner(tipDot, height)
					stroke(tipDot, TILE, 2)
				end
			else
				text(tile, opt.name, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0, math.min(18, height * 0.36)), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold })
			end
			local check = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = GOLD, Visible = false }, tile)
			corner(check, 7)
			tile.Activated:Connect(function()
				deps.click()
				state.look[field] = i
				if field ~= "avatar" then
					state.look.avatar = false
				end
				ui.refresh()
				ui.rebuildPreview()
			end)
			tile.MouseEnter:Connect(function()
				if state.look[field] ~= i then
					ring.Color = DIM
				end
			end)
			tile.MouseLeave:Connect(function()
				ui.refresh()
			end)
			tile.SelectionGained:Connect(function()
				ring.Color = WHITE
			end)
			tile.SelectionLost:Connect(function()
				ui.refresh()
			end)
			table.insert(ui.tiles, { field = field, index = i, ring = ring, check = check, tile = tile, page = page })
		end
		return holder
	end

	-- UNIFORM page
	section(pages[1], 1, "UNIFORM STYLE")
	grid(pages[1], 2, "outfit", Looks.Outfits, "card", 2, 62)
	section(pages[1], 3, "OR")
	local avatarRow = make("TextButton", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, if compact then 46 else 58), BackgroundColor3 = TILE, AutoButtonColor = false, Text = "", Selectable = true }, pages[1])
	corner(avatarRow, 12)
	local avatarStroke = stroke(avatarRow, LINE, 1.5)
	text(avatarRow, "Wear my Roblox avatar", { Position = UDim2.new(0, 16, 0.16, 0), Size = UDim2.new(1, -96, 0.34, 0), Font = Enum.Font.GothamBold })
	text(avatarRow, "Keep your own outfit and add a school sash", { Position = UDim2.new(0, 16, 0.56, 0), Size = UDim2.new(1, -96, 0.24, 0), TextColor3 = DIM, Font = Enum.Font.Gotham })
	local switch = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.new(0, 52, 0, 28), BackgroundColor3 = LINE }, avatarRow)
	corner(switch, 14)
	local knob = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = WHITE }, switch)
	corner(knob, 10)
	avatarRow.Activated:Connect(function()
		deps.click()
		state.look.avatar = not state.look.avatar
		ui.refresh()
		ui.rebuildPreview()
	end)

	-- HAIR page
	section(pages[2], 1, "STYLE")
	grid(pages[2], 2, "hair", Looks.HairStyles, "card", 4, 48)
	section(pages[2], 3, "COLOUR")
	grid(pages[2], 4, "hairColor", Looks.HairColors, "swatch", 6, 50)
	-- EYES page
	section(pages[3], 1, "EYE COLOUR")
	grid(pages[3], 2, "eye", Looks.EyeColors, "swatch", 4, 62)
	-- SKIN page
	section(pages[4], 1, "SKIN TONE")
	grid(pages[4], 2, "skin", Looks.Skin, "swatch", 4, 62)

	-- footer
	local footer = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, footH - 8), BackgroundTransparency = 1 }, frame)
	local function footButton(label: string, x: UDim, w: number, primary: boolean, onPress)
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(x.Scale, x.Offset, 1, 0), Size = UDim2.new(0, w, 1, 0),
			BackgroundColor3 = if primary then GOLD else PANEL, AutoButtonColor = true, Text = label, Font = Enum.Font.GothamBlack,
			TextScaled = true, TextColor3 = if primary then INK else WHITE, Selectable = true,
		}, footer)
		corner(b, 24)
		if not primary then
			stroke(b, LINE, 1.5)
		end
		make("UIPadding", { PaddingTop = UDim.new(0.3, 0), PaddingBottom = UDim.new(0.3, 0) }, b)
		b.Activated:Connect(function()
			deps.click()
			onPress()
		end)
		return b
	end
	local random = footButton("RANDOM", UDim.new(0, 0), 140, false, function()
		local rnd = Random.new()
		state.look = {
			outfit = rnd:NextInteger(1, #Looks.Outfits), hair = rnd:NextInteger(1, #Looks.HairStyles),
			hairColor = rnd:NextInteger(1, #Looks.HairColors), eye = rnd:NextInteger(1, #Looks.EyeColors),
			skin = rnd:NextInteger(1, #Looks.Skin), avatar = false,
		}
		ui.refresh()
		ui.rebuildPreview()
	end)
	local reset = footButton("RESET", UDim.new(0, 152), 120, false, function()
		state.look = table.clone(state.profile.look)
		ui.refresh()
		ui.rebuildPreview()
	end)
	local back = footButton("BACK", UDim.new(1, -332), 140, false, function()
		state.look = table.clone(state.profile.look)
		deps.onDone(false)
	end)
	local save = footButton("SAVE", UDim.new(1, -180), 180, true, function()
		local ok, saved = pcall(function()
			return deps.remote:InvokeServer("look", state.look)
		end)
		if ok and saved then
			state.look = saved
			state.profile.look = saved
			state.profile.customised = true
		end
		deps.onDone(true)
	end)
	random.NextSelectionRight = reset
	reset.NextSelectionLeft = random
	reset.NextSelectionRight = back
	back.NextSelectionLeft = reset
	back.NextSelectionRight = save
	save.NextSelectionLeft = back

	-- ---------------------------------------------------------------------------------------------
	-- Behaviour
	-- ---------------------------------------------------------------------------------------------
	selectTab = function(i: number)
		ui.tab = i
		for k, b in tabButtons do
			local on = k == i
			b.BackgroundTransparency = if on then 0 else 1
			b.BackgroundColor3 = if on then accent else PANEL
			b.TextColor3 = if on then INK else DIM
			pages[k].Visible = on
		end
		ui.focus = TABS[i].focus
		if UserInputService:GetLastInputType().Name:find("Gamepad") then
			for _, t in ui.tiles do
				if t.page == pages[i] then
					GuiService.SelectedObject = t.tile
					break
				end
			end
		end
	end

	function ui.refresh()
		local school = state.profile and state.profile.school
		local academy = school and Config.Academies[school]
		accent = if academy then academy.accent else Config.hex(0x6fe6ff)
		schoolName.Text = if academy then academy.name else "Visitor colours (no school yet)"
		schoolDot.BackgroundColor3 = accent
		schoolStroke.Color = accent
		for _, t in ui.tiles do
			local on = state.look[t.field] == t.index and not state.look.avatar
			t.ring.Color = if on then accent else LINE
			t.ring.Thickness = if on then 3 else 1.5
			t.check.Visible = on
			t.check.BackgroundColor3 = accent
			t.tile.BackgroundColor3 = if on then Color3.fromRGB(32, 40, 70) else TILE
		end
		local av = state.look.avatar == true
		avatarStroke.Color = if av then accent else LINE
		avatarStroke.Thickness = if av then 3 else 1.5
		switch.BackgroundColor3 = if av then accent else LINE
		knob.Position = if av then UDim2.new(1, -24, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
		selectTab(ui.tab)
	end

	function ui.rebuildPreview()
		local p = ui.preview
		if p.model then
			p.model:Destroy()
			p.model = nil
		end
		local model
		local folder = ReplicatedStorage:FindFirstChild(Config.PreviewsName)
		local source = folder and Players.LocalPlayer and folder:FindFirstChild(tostring(Players.LocalPlayer.UserId))
		if source then
			model = source:Clone()
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
		else
			model = Appearance.mannequin()
		end
		Appearance.apply(model, state.look, state.profile and state.profile.school)
		model.Parent = p.world
		local cf, size = model:GetBoundingBox()
		p.model = model
		p.centre = cf.Position
		p.height = size.Y
		p.base = model:GetPivot()
		local head = model:FindFirstChild("Head")
		p.face = if head and head:IsA("BasePart") then head.CFrame.Position else cf.Position + Vector3.new(0, size.Y * 0.38, 0)
		-- a glowing ring under the feet
		if not p.ring then
			p.ring = make("Part", { Anchored = true, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Size = Vector3.new(0.1, 5, 5) }, p.world)
			p.disc = make("Part", { Anchored = true, Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(28, 34, 60), Size = Vector3.new(0.12, 4.6, 4.6) }, p.world)
		end
		local feet = cf.Position - Vector3.new(0, size.Y / 2, 0)
		p.ring.CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.rad(90))
		p.disc.CFrame = CFrame.new(feet + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.ring.Color = accent
	end

	-- turning the preview: drag with mouse or finger, or the right stick
	vp.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ui.dragging = true
			ui.dragX = input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if ui.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			ui.spinTarget += (input.Position.X - ui.dragX) * 0.012
			ui.dragX = input.Position.X
			ui.lastDrag = os.clock()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and root.Visible then
			ui.stick = input.Position.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ui.dragging = false
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local p = ui.preview
		if not root.Visible or not p.model then
			return
		end
		if ui.stick and math.abs(ui.stick) > 0.15 then
			ui.spinTarget += ui.stick * dt * 3
			ui.lastDrag = os.clock()
		elseif not ui.dragging and os.clock() - ui.lastDrag > 2.5 then
			ui.spinTarget += dt * 0.35 -- idle turn
		end
		ui.spin += (ui.spinTarget - ui.spin) * math.min(1, dt * 10)
		local c = p.centre
		p.model:PivotTo(CFrame.new(c) * CFrame.Angles(0, ui.spin, 0) * CFrame.new(-c) * p.base)
		-- frame the whole body, or zoom to the face for hair and eyes
		local wantFace = ui.focus == "face" and not state.look.avatar
		local target = if wantFace then p.face else c
		local dist = if wantFace then p.height * 0.75 else p.height * 2.15
		local goal = CFrame.lookAt(target + Vector3.new(0, p.height * 0.04, -dist), target)
		ui.camCf = if ui.camCf then ui.camCf:Lerp(goal, math.min(1, dt * 6)) else goal
		cam.CFrame = ui.camCf
	end)

	local screen = {}
	screen.frame = root
	screen.first = tabButtons[1]
	function screen.refresh()
		state.look = table.clone(state.profile.look)
		ui.tab = 1
		ui.spin, ui.spinTarget = 0, 0
		ui.camCf = nil
		ui.refresh()
		ui.rebuildPreview()
		-- LB / RB change tab while this screen is open
		ContextActionService:BindActionAtPriority("HalcyonCustomizeTabs", function(_, inputState, input)
			if inputState == Enum.UserInputState.Begin and root.Visible then
				local step = if input.KeyCode == Enum.KeyCode.ButtonR1 then 1 else -1
				selectTab((ui.tab - 1 + step) % #TABS + 1)
			end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	end
	function screen.close()
		ContextActionService:UnbindAction("HalcyonCustomizeTabs")
	end
	function screen.previewArrived()
		if root.Visible then
			ui.rebuildPreview()
		end
	end
	screen.ui = ui
	local _ = title
	local _s = subtitle
	local _h = hint
	return screen
end

return CustomizeUi
