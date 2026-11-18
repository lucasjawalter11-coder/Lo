--!nonstrict
-- Hub: the screen you see when you join. Start Game, Customize, and the school picker.
-- Works with mouse, touch and controller (D-pad / stick to move between buttons, A to press, B to go back).
-- In game, the MENU button (or M / D-pad up) opens the hub again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Looks = require(Shared:WaitForChild("Looks"))

local Hub = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild(Config.RemotesName)
local MenuRemote: RemoteFunction = remotes:WaitForChild("Menu")

local INK = Color3.fromRGB(10, 13, 26)
local PANEL = Color3.fromRGB(16, 21, 40)
local LUMEN = Color3.fromRGB(111, 230, 255)
local GOLD = Color3.fromRGB(255, 201, 74)
local WHITE = Color3.fromRGB(240, 244, 252)
local DIM = Color3.fromRGB(150, 160, 190)

local state = {
	profile = nil,
	look = Looks.default(),
	screen = "closed", -- closed | main | schools | customize
	playing = false,
	focusSchool = nil,
}

local gui: ScreenGui
local screens = {}
local menuButton: TextButton
local cameraConn: RBXScriptConnection? = nil
local orbit = 0

-- ---------------------------------------------------------------------------------------------
-- Small UI helpers
-- ---------------------------------------------------------------------------------------------
local function make(className: string, props: { [string]: any }, parent: Instance?)
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	return make("UIStroke", { Color = color, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function label(parent: Instance, text: string, props: { [string]: any }?)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	return l
end

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last.Name:find("Gamepad") ~= nil
end

local function focusButton(button: GuiObject?)
	if button and usingGamepad() then
		GuiService.SelectedObject = button
	end
end

local function playClick()
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.Click.id
	s.Volume = Config.Sounds.Click.volume
	s.Parent = gui
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

--- A big menu button. `onPress` runs on click, tap, or controller A.
local function button(parent: Instance, text: string, accent: Color3, onPress: () -> (), props: { [string]: any }?)
	local b = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = WHITE,
		Selectable = true,
	}, parent)
	corner(b, 12)
	local st = stroke(b, accent, 2)
	make("UIPadding", { PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, b)
	local function hot(on: boolean)
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = if on then accent else PANEL, TextColor3 = if on then INK else WHITE }):Play()
		st.Thickness = if on then 3 else 2
	end
	b.MouseEnter:Connect(function()
		hot(true)
	end)
	b.MouseLeave:Connect(function()
		hot(false)
	end)
	b.SelectionGained:Connect(function()
		hot(true)
	end)
	b.SelectionLost:Connect(function()
		hot(false)
	end)
	b.Activated:Connect(function()
		playClick()
		onPress()
	end)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	return b
end

-- ---------------------------------------------------------------------------------------------
-- Menu camera: a slow orbit around the Register spire, or a fly-by of the school being looked at
-- ---------------------------------------------------------------------------------------------
local function towerPosition(schoolId: string): Vector3
	local a = math.rad(Config.Academies[schoolId].angle)
	local r = Config.Map.SchoolRing + Config.Map.CampusGate + Config.Map.TowerDepth
	return Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
end

local function startCamera()
	if cameraConn then
		return
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local current = camera.CFrame
	cameraConn = RunService.RenderStepped:Connect(function(dt)
		orbit += dt * 0.05
		local target: CFrame
		if state.screen == "schools" and state.focusSchool then
			local tower = towerPosition(state.focusSchool)
			local dir = Vector3.new(tower.X, 0, tower.Z).Unit
			local eye = tower - dir * 520 + Vector3.new(math.sin(orbit * 3) * 40, 160, 0)
			target = CFrame.lookAt(eye, tower + Vector3.new(0, 170, 0))
		else
			local spire = Config.Map.Spire
			local eye = spire + Vector3.new(math.sin(orbit) * 900, 60, math.cos(orbit) * 900)
			target = CFrame.lookAt(eye, spire + Vector3.new(0, 60, 0))
		end
		current = current:Lerp(target, math.clamp(dt * 1.6, 0, 1))
		camera.CFrame = current
	end)
end

local function stopCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function setControls(enabled: boolean)
	local ok, controls = pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		return module:GetControls()
	end)
	if ok and controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Screens
-- ---------------------------------------------------------------------------------------------
local show: (name: string) -> ()

local function startGame(schoolId: string?)
	local ok, result = pcall(function()
		return MenuRemote:InvokeServer("start", { school = schoolId })
	end)
	if not (ok and result) then
		return
	end
	if schoolId then
		state.profile.school = schoolId
	end
	state.playing = true
	show("closed")
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("Humanoid", 10)
	stopCamera()
	setControls(true)
end

local function buildMain()
	local f = make("Frame", { Name = "Main", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	-- a dark band down the left side so the title reads over the world
	local band = make("Frame", { BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.new(0.42, 0, 1, 0) }, f)
	make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, band)
	local col = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.06, 0.14), Size = UDim2.fromScale(0.32, 0.74) }, f)
	make("UISizeConstraint", { MinSize = Vector2.new(260, 300), MaxSize = Vector2.new(520, 640) }, col)
	label(col, "HALCYON", { Size = UDim2.fromScale(1, 0.16), TextColor3 = LUMEN, Font = Enum.Font.GothamBlack })
	label(col, "CLASH", { Position = UDim2.fromScale(0, 0.15), Size = UDim2.fromScale(1, 0.16), Font = Enum.Font.GothamBlack })
	label(col, "Four academies. One Register. Climb to Seat I.", { Position = UDim2.fromScale(0, 0.33), Size = UDim2.fromScale(1, 0.06), TextColor3 = DIM, Font = Enum.Font.GothamMedium })
	local schoolLine = label(col, "", { Name = "School", Position = UDim2.fromScale(0, 0.42), Size = UDim2.fromScale(1, 0.055), Font = Enum.Font.GothamBold })
	local start = button(col, "START GAME", LUMEN, function()
		if state.profile and state.profile.school then
			startGame(nil)
		else
			show("schools")
		end
	end, { Name = "Start", Position = UDim2.fromScale(0, 0.52), Size = UDim2.fromScale(1, 0.13) })
	local custom = button(col, "CUSTOMIZE", GOLD, function()
		show("customize")
	end, { Name = "Customize", Position = UDim2.fromScale(0, 0.69), Size = UDim2.fromScale(1, 0.11) })
	local change = button(col, "CHANGE SCHOOL", DIM, function()
		show("schools")
	end, { Name = "ChangeSchool", Position = UDim2.fromScale(0, 0.84), Size = UDim2.fromScale(1, 0.09) })
	start.NextSelectionDown = custom
	custom.NextSelectionUp = start
	custom.NextSelectionDown = change
	change.NextSelectionUp = custom
	label(f, "Mouse, touch or controller  ·  v" .. Config.Version, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -10), Size = UDim2.new(0.4, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = DIM, Font = Enum.Font.Gotham })
	screens.main = {
		frame = f,
		first = start,
		refresh = function()
			local school = state.profile and state.profile.school
			local academy = school and Config.Academies[school]
			if academy then
				schoolLine.Text = "Student of " .. academy.name
				schoolLine.TextColor3 = academy.accent
				change.Visible = true
			else
				schoolLine.Text = "Not enrolled yet: pick a school to begin"
				schoolLine.TextColor3 = GOLD
				change.Visible = false
			end
			start.Text = if state.playing then "RESUME" elseif academy then "START GAME" else "CHOOSE A SCHOOL"
		end,
	}
end

local function buildSchools()
	local f = make("Frame", { Name = "Schools", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	make("Frame", { BackgroundColor3 = INK, BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.52), Size = UDim2.fromScale(1, 0.48) }, f)
	label(f, "CHOOSE YOUR SCHOOL", { Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.fromScale(0.6, 0.07), Font = Enum.Font.GothamBlack })
	local hint = label(f, "Each school has its own campus, tower and Register. Beat a seat-holder to take their rank.", { Position = UDim2.fromScale(0.04, 0.125), Size = UDim2.fromScale(0.7, 0.035), TextColor3 = DIM, Font = Enum.Font.GothamMedium })
	local row = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.55), Size = UDim2.fromScale(0.94, 0.36) }, f)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.015, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center }, row)
	local cards = {}
	for i, id in Config.AcademyOrder do
		local a = Config.Academies[id]
		local card = make("TextButton", {
			Name = id,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.05,
			Size = UDim2.fromScale(0.235, 1),
			LayoutOrder = i,
			Selectable = true,
		}, row)
		corner(card, 14)
		local st = stroke(card, a.accent, 2)
		make("Frame", { BackgroundColor3 = a.accent, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 6) }, card)
		label(card, string.upper(a.short), { Position = UDim2.fromScale(0.07, 0.08), Size = UDim2.fromScale(0.86, 0.16), TextColor3 = a.accent, Font = Enum.Font.GothamBlack })
		label(card, a.motto, { Position = UDim2.fromScale(0.07, 0.26), Size = UDim2.fromScale(0.86, 0.09), TextColor3 = WHITE, Font = Enum.Font.GothamBold })
		label(card, a.blurb, { Position = UDim2.fromScale(0.07, 0.38), Size = UDim2.fromScale(0.86, 0.3), TextScaled = false, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = DIM, Font = Enum.Font.Gotham })
		label(card, a.tower, { Position = UDim2.fromScale(0.07, 0.7), Size = UDim2.fromScale(0.86, 0.08), TextColor3 = a.accent, Font = Enum.Font.GothamMedium })
		local join = label(card, "JOIN ▸", { Position = UDim2.fromScale(0.07, 0.83), Size = UDim2.fromScale(0.86, 0.1), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack })
		local function focus(on: boolean)
			if on then
				state.focusSchool = id
			end
			TweenService:Create(card, TweenInfo.new(0.12), { BackgroundColor3 = if on then Color3.fromRGB(26, 33, 60) else PANEL }):Play()
			st.Thickness = if on then 4 else 2
			join.TextColor3 = if on then a.accent else WHITE
		end
		card.MouseEnter:Connect(function()
			focus(true)
		end)
		card.MouseLeave:Connect(function()
			focus(false)
		end)
		card.SelectionGained:Connect(function()
			focus(true)
		end)
		card.SelectionLost:Connect(function()
			focus(false)
		end)
		card.Activated:Connect(function()
			playClick()
			state.focusSchool = id
			startGame(id)
		end)
		cards[i] = card
	end
	for i, card in cards do
		card.NextSelectionLeft = cards[i - 1] or card
		card.NextSelectionRight = cards[i + 1] or card
	end
	local back = button(f, "BACK", DIM, function()
		show("main")
	end, { Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 140, 0, 50) })
	for _, card in cards do
		card.NextSelectionUp = back
	end
	back.NextSelectionDown = cards[1]
	local _ = hint
	screens.schools = {
		frame = f,
		first = cards[1],
		refresh = function()
			state.focusSchool = (state.profile and state.profile.school) or Config.AcademyOrder[1]
		end,
	}
end

-- ---------------------------------------------------------------------------------------------
-- Customize: the character creator lives in its own module
-- ---------------------------------------------------------------------------------------------
local CustomizeUi = require(script.Parent:WaitForChild("CustomizeUi"))

local function buildCustomize()
	screens.customize = CustomizeUi.build(gui, {
		state = state,
		remote = MenuRemote,
		click = playClick,
		viewSize = function()
			return Workspace.CurrentCamera.ViewportSize
		end,
		onDone = function()
			show("main")
		end,
	})
end

show = function(name: string)
	if state.screen == "customize" and name ~= "customize" and screens.customize then
		screens.customize.close()
	end
	state.screen = name
	if Hub.onOpenChanged then
		Hub.onOpenChanged(name ~= "closed")
	end
	for key, s in screens do
		s.frame.Visible = key == name
	end
	ContextActionService:UnbindAction("HalcyonHubBack")
	if name == "closed" then
		gui.Enabled = true
		menuButton.Visible = state.playing
		GuiService.SelectedObject = nil
		return
	end
	menuButton.Visible = false
	setControls(false)
	startCamera()
	local s = screens[name]
	if s.refresh then
		s.refresh()
	end
	focusButton(s.first)
	if name ~= "main" then
		ContextActionService:BindActionAtPriority("HalcyonHubBack", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				if name == "customize" then
					state.look = table.clone(state.profile.look)
				end
				show("main")
			end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	end
end

function Hub.open()
	show("main")
end

function Hub.init(playerGui: PlayerGui)
	gui = make("ScreenGui", { Name = "HalcyonHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	buildMain()
	buildSchools()
	buildCustomize()

	-- in-game button that brings the hub back
	menuButton = button(gui, "≡ MENU", LUMEN, function()
		Hub.open()
	end, { Name = "MenuButton", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 130, 0, 40), Visible = false })
	ContextActionService:BindAction("HalcyonOpenHub", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and state.playing and state.screen == "closed" then
			Hub.open()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M, Enum.KeyCode.DPadUp)
	gui.Parent = playerGui

	local profile
	for _ = 1, 10 do
		local ok, result = pcall(function()
			return MenuRemote:InvokeServer("profile")
		end)
		if ok and result then
			profile = result
			break
		end
		task.wait(0.5)
	end
	state.profile = profile or { school = nil, look = Looks.default() }
	state.look = table.clone(state.profile.look)
	-- someone who reconnects mid-session already has a character: treat the hub as a pause screen
	state.playing = player.Character ~= nil
	Hub.open()
	-- the avatar preview model arrives a moment later; refresh the preview when it does
	local previews = ReplicatedStorage:WaitForChild(Config.PreviewsName, 10)
	if previews then
		previews.ChildAdded:Connect(function(child)
			if child.Name == tostring(player.UserId) and screens.customize then
				screens.customize.previewArrived()
			end
		end)
	end
end

return Hub
