-- Dev helper: stands every NPC in a row and dumps the scene for tools/preview (a character contact sheet).
local Harness = require("./harness")
local roblox = require("@lune/roblox")

local game = Harness.loadPlace("build/base.rbxl")
local requireModule = Harness.loader(Harness.globals(game))
local server = game:GetService("ServerScriptService"):FindFirstChild("HalcyonServer")
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("HalcyonShared")
local Npcs = requireModule(server:FindFirstChild("Npcs"))
local Roster = requireModule(shared:FindFirstChild("Roster"))

local ws = game:GetService("Workspace")
local list = {}
for _, group in { Roster.Seats, Roster.Aces, Roster.Staff, Roster.Talkers } do
	for _, npc in group do
		table.insert(list, npc)
	end
end
local perRow = 12
for i, npc in list do
	local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
	local cf = roblox.CFrame.new((col - (perRow - 1) / 2) * 5, 0, row * 14) * roblox.CFrame.Angles(0, math.rad(180), 0)
	Npcs.rig(npc, cf).Parent = ws
end
local floor = roblox.Instance.new("Part")
floor.Anchored = true
floor.Size = roblox.Vector3.new(80, 1, 60)
floor.CFrame = roblox.CFrame.new(0, -0.5, 14)
floor.Color = roblox.Color3.fromRGB(60, 66, 90)
floor.Parent = ws
Harness.writeJson("build/npcs.json", Harness.dumpScene({ ws }))
print(#list, "npcs")
