--!nonstrict
-- DialogueUi: the talk box at the bottom of the screen.
-- Advance with a click or tap on the box, Enter / Space / E on a keyboard, or A on a controller.
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local DialogueUi = {}

local gui, frame, nameLabel, titleLabel, textLabel, hint, accentBar, choices, challengeButton, leaveButton
local current = nil
local queue: { string } = {}
local index = 0
local typing = false
local fullText = ""
local ADVANCE = "HalcyonDialogueAdvance"

local function setMovement(enabled: boolean)
	local character = Players.LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = if enabled then 20 else 0
		hum.JumpPower = if enabled then 50 else 0
	end
end

local function close()
	choices.Visible = false
	if DialogueUi.onOpenChanged then
		DialogueUi.onOpenChanged(false)
	end
	ContextActionService:UnbindAction(ADVANCE)
	TweenService:Create(frame, TweenInfo.new(0.18), { Position = UDim2.new(0.5, 0, 1.3, 0) }):Play()
	task.delay(0.2, function()
		if index > #queue then
			gui.Enabled = false
		end
	end)
	setMovement(true)
end

local function typeLine(line: string)
	fullText = line
	typing = true
	textLabel.Text = ""
	task.spawn(function()
		for i = 1, #line do
			if not typing or fullText ~= line then
				return
			end
			textLabel.Text = string.sub(line, 1, i)
			task.wait(0.018)
		end
		typing = false
	end)
end

local function advance()
	if typing then
		typing = false
		textLabel.Text = fullText
		return
	end
	if choices.Visible then
		return -- waiting for Challenge or Leave
	end
	index += 1
	if index > #queue then
		if current and current.challenge then
			-- offer the duel
			index = #queue
			choices.Visible = true
			hint.Text = ""
			ContextActionService:UnbindAction(ADVANCE) -- let the buttons take clicks, taps and controller A
			local GuiService = game:GetService("GuiService")
			if game:GetService("UserInputService"):GetLastInputType().Name:find("Gamepad") then
				GuiService.SelectedObject = challengeButton
			end
			return
		end
		close()
		return
	end
	typeLine(queue[index])
	hint.Text = if index == #queue and not (current and current.challenge) then "CLOSE ▸" else "NEXT ▸"
end

function DialogueUi.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "HalcyonDialogue"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 20

	frame = Instance.new("TextButton")
	frame.Name = "Box"
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Size = UDim2.new(0.62, 0, 0.22, 0)
	frame.Position = UDim2.new(0.5, 0, 1.3, 0)
	frame.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(320, 130)
	size.MaxSize = Vector2.new(980, 220)
	size.Parent = frame
	Instance.new("UICorner").Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(111, 230, 255)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(0, 6, 1, -24)
	accentBar.Position = UDim2.new(0, 12, 0, 12)
	accentBar.BorderSizePixel = 0
	accentBar.Parent = frame

	nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 30, 0, 10)
	nameLabel.Size = UDim2.new(1, -60, 0, 30)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Parent = frame

	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 30, 0, 40)
	titleLabel.Size = UDim2.new(1, -60, 0, 18)
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.new(0, 30, 0, 64)
	textLabel.Size = UDim2.new(1, -60, 1, -94)
	textLabel.Font = Enum.Font.Gotham
	textLabel.TextSize = 20
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextColor3 = Color3.fromRGB(226, 232, 248)
	textLabel.Parent = frame

	hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Position = UDim2.new(1, -16, 1, -8)
	hint.Size = UDim2.new(0, 120, 0, 22)
	hint.Font = Enum.Font.GothamBold
	hint.TextScaled = true
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextColor3 = Color3.fromRGB(111, 230, 255)
	hint.Parent = frame

	frame.Activated:Connect(advance) -- mouse click, touch tap, or controller select

	choices = Instance.new("Frame")
	choices.BackgroundTransparency = 1
	choices.AnchorPoint = Vector2.new(1, 1)
	choices.Position = UDim2.new(1, -16, 1, -10)
	choices.Size = UDim2.new(0, 300, 0, 44)
	choices.Visible = false
	choices.Parent = frame
	local function choice(text: string, x: number, color: Color3, onPress)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.48, 0, 1, 0)
		b.Position = UDim2.new(x, 0, 0, 0)
		b.BackgroundColor3 = color
		b.Text = text
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = Color3.fromRGB(10, 13, 26)
		Instance.new("UICorner").Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.2, 0)
		pad.PaddingBottom = UDim.new(0.2, 0)
		pad.Parent = b
		b.Activated:Connect(onPress)
		b.Parent = choices
		return b
	end
	challengeButton = choice("CHALLENGE", 0, Color3.fromRGB(255, 201, 74), function()
		local id = current and current.id
		close()
		if id and DialogueUi.onChallenge then
			DialogueUi.onChallenge(id)
		end
	end)
	leaveButton = choice("LEAVE", 0.52, Color3.fromRGB(150, 160, 190), function()
		close()
	end)
	challengeButton.NextSelectionRight = leaveButton
	leaveButton.NextSelectionLeft = challengeButton
	gui.Parent = playerGui
end

function DialogueUi.show(data)
	current = data
	choices.Visible = false
	if DialogueUi.onOpenChanged then
		DialogueUi.onOpenChanged(true)
	end
	queue = data.lines or {}
	index = 0
	nameLabel.Text = data.name or ""
	titleLabel.Text = data.title or ""
	local accent = data.accent or Color3.fromRGB(111, 230, 255)
	titleLabel.TextColor3 = accent
	accentBar.BackgroundColor3 = accent
	gui.Enabled = true
	setMovement(false)
	TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.97, 0) }):Play()
	ContextActionService:BindActionAtPriority(ADVANCE, function(_, state)
		if state == Enum.UserInputState.Begin then
			advance()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonX)
	advance()
end

return DialogueUi
