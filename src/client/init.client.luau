--!nonstrict
-- Halcyon Clash client entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local DialogueUi = require(script:WaitForChild("DialogueUi"))
local Hub = require(script:WaitForChild("Hub"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild(Config.RemotesName)

DialogueUi.init(playerGui)
remotes:WaitForChild("Dialogue").OnClientEvent:Connect(function(data)
	DialogueUi.show(data)
end)

Hub.init(playerGui)
