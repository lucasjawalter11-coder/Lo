--!nonstrict
-- Halcyon Clash client entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local DialogueUi = require(script:WaitForChild("DialogueUi"))
local Hub = require(script:WaitForChild("Hub"))
local Fx = require(script:WaitForChild("Fx"))
local Animator = require(script:WaitForChild("Animator"))
local CombatClient = require(script:WaitForChild("CombatClient"))
local TravelUi = require(script:WaitForChild("TravelUi"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild(Config.RemotesName)

DialogueUi.init(playerGui)
remotes:WaitForChild("Dialogue").OnClientEvent:Connect(function(data)
	DialogueUi.show(data)
end)

Fx.init()
Animator.init(Fx)
CombatClient.init(playerGui, { Animator = Animator, Fx = Fx })
Hub.onOpenChanged = CombatClient.setMenuOpen
DialogueUi.onOpenChanged = CombatClient.setMenuOpen
DialogueUi.onChallenge = function(id)
	remotes:WaitForChild("Dialogue"):FireServer("challenge", id)
end

TravelUi.init(playerGui, remotes:WaitForChild("Travel"))
TravelUi.onOpenChanged = CombatClient.setMenuOpen
remotes:WaitForChild("Travel").OnClientEvent:Connect(function(data)
	TravelUi.show(data)
end)

Hub.init(playerGui)

-- Skylift: a short white flash so the jump between the tower's foot and the Sky Arena reads as a ride
local flash = Instance.new("ScreenGui")
flash.Name = "HalcyonFlash"
flash.IgnoreGuiInset = true
flash.DisplayOrder = 50
flash.ResetOnSpawn = false
local white = Instance.new("Frame")
white.Size = UDim2.fromScale(1, 1)
white.BackgroundColor3 = Color3.fromRGB(220, 246, 255)
white.BackgroundTransparency = 1
white.BorderSizePixel = 0
white.Parent = flash
flash.Parent = playerGui
remotes:WaitForChild("Lift").OnClientEvent:Connect(function()
	white.BackgroundTransparency = 0
	game:GetService("TweenService"):Create(white, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end)
