-- Dev helper: renders moves as a contact sheet. Each row is one move sampled at several moments.
-- Usage: lune run tools/lune/pose-sheet.luau <weapon> [moves comma separated]
local Harness = require("./harness")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local game = Harness.loadPlace("build/base.rbxl")
local requireModule = Harness.loader(Harness.globals(game))
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("HalcyonShared")
local Rig = requireModule(shared:FindFirstChild("Rig"))
local Moves = requireModule(shared:FindFirstChild("Moves"))
local Weapons = requireModule(shared:FindFirstChild("Weapons"))
local Appearance = requireModule(shared:FindFirstChild("Appearance"))

local weapon = process.args[1] or "saber"
local list = {}
for id in string.gmatch(process.args[2] or "l1,l2,l3,l4,heavy,launch,s1,ult", "[^,]+") do
	table.insert(list, weapon .. "_" .. id)
end
local ws = game:GetService("Workspace")
local FRAMES = 6
for row, id in list do
	local move = Moves.get(id)
	assert(move, "no move " .. id)
	for f = 0, FRAMES - 1 do
		local t = move.dur * f / (FRAMES - 1)
		local rig = Rig.build(id .. f, roblox.CFrame.new(f * 9, 0, row * 12) * roblox.CFrame.Angles(0, math.rad(150), 0))
		Rig.applyPose(rig, Moves.sample(move, t))
		Appearance.apply(rig, { outfit = 1, hair = 1, hairColor = 5, eye = 1, skin = 2 }, "northwind")
		Weapons.attach(rig, weapon)
		rig.Parent = ws
	end
	print(row, id, move.name)
end
Harness.writeJson("build/poses.json", Harness.dumpScene({ ws }))
