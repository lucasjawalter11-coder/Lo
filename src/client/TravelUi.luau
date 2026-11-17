--!nonstrict
-- TravelUi: the transit gate menu. Pick any district and the gate sends you there.
-- Mouse, touch and controller (D-pad / stick to choose, A to go, B to close).
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local TravelUi = {}

local gui, list, remote

local function close()
	gui.Enabled = false
	GuiService.SelectedObject = nil
	ContextActionService:UnbindAction("HalcyonTravelClose")
	if TravelUi.onOpenChanged then
		TravelUi.onOpenChanged(false)
	end
end

function TravelUi.show(data)
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local first
	for i, d in data.destinations do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(1, 0, 0, 44)
		b.BackgroundColor3 = Color3.fromRGB(16, 21, 40)
		b.AutoButtonColor = true
		b.Text = (if d.here then "●  " else "") .. d.name .. "   ·   " .. d.kind
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextColor3 = d.color
		b.TextXAlignment = Enum.TextXAlignment.Left
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingTop = UDim.new(0.22, 0)
		pad.PaddingBottom = UDim.new(0.22, 0)
		pad.Parent = b
		Instance.new("UICorner").Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Color = d.color
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		b.Activated:Connect(function()
			close()
			remote:FireServer("go", d.tag)
		end)
		b.Parent = list
		first = first or b
	end
	gui.Enabled = true
	if TravelUi.onOpenChanged then
		TravelUi.onOpenChanged(true)
	end
	if UserInputService:GetLastInputType().Name:find("Gamepad") then
		GuiService.SelectedObject = first
	end
	ContextActionService:BindActionAtPriority("HalcyonTravelClose", function(_, state)
		if state == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape, Enum.KeyCode.Backspace)
end

function TravelUi.init(playerGui, travelRemote)
	remote = travelRemote
	gui = Instance.new("ScreenGui")
	gui.Name = "HalcyonTravel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 25
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.42, 0, 0.78, 0)
	panel.BackgroundColor3 = Color3.fromRGB(10, 13, 26)
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(320, 380)
	size.MaxSize = Vector2.new(560, 640)
	size.Parent = panel
	Instance.new("UICorner").Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(111, 230, 255)
	stroke.Thickness = 2
	stroke.Parent = panel
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 18, 0, 12)
	title.Size = UDim2.new(1, -36, 0, 34)
	title.Text = "TRANSIT GATE"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(111, 230, 255)
	title.Parent = panel
	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 18, 0, 56)
	list.Size = UDim2.new(1, -36, 1, -120)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 4
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	closeButton.Position = UDim2.new(0.5, 0, 1, -12)
	closeButton.Size = UDim2.new(0.5, 0, 0, 42)
	closeButton.BackgroundColor3 = Color3.fromRGB(150, 160, 190)
	closeButton.Text = "CLOSE"
	closeButton.Font = Enum.Font.GothamBlack
	closeButton.TextScaled = true
	closeButton.TextColor3 = Color3.fromRGB(10, 13, 26)
	Instance.new("UICorner").Parent = closeButton
	closeButton.Activated:Connect(close)
	closeButton.Parent = panel
	gui.Parent = playerGui
end

return TravelUi
