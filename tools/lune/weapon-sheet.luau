-- Dev helper: the six weapons, each fighter caught mid-attack, for a preview render.
local Harness = require("./harness")
local roblox = require("@lune/roblox")

local game = Harness.loadPlace("build/base.rbxl")
local requireModule = Harness.loader(Harness.globals(game))
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("HalcyonShared")
local Rig = requireModule(shared:FindFirstChild("Rig"))
local Moves = requireModule(shared:FindFirstChild("Moves"))
local Weapons = requireModule(shared:FindFirstChild("Weapons"))
local Appearance = requireModule(shared:FindFirstChild("Appearance"))

local ws = game:GetService("Workspace")
local picks = {
	{ "saber", "saber_l1", 0.12, "northwind", { hair = 1, hairColor = 5, eye = 1, skin = 2, outfit = 1 } },
	{ "lance", "lance_heavy", 0.3, "solcrest", { hair = 5, hairColor = 1, eye = 2, skin = 4, outfit = 2 } },
	{ "maul", "maul_l4", 0.14, "ironreach", { hair = 3, hairColor = 11, eye = 4, skin = 6, outfit = 4 } },
	{ "pistols", "pistols_l3", 0.1, "arcline", { hair = 4, hairColor = 8, eye = 3, skin = 1, outfit = 3 } },
	{ "scythe", "scythe_l1", 0.1, "northwind", { hair = 6, hairColor = 6, eye = 6, skin = 3, outfit = 1 } },
	{ "discs", "discs_l3", 0.08, "solcrest", { hair = 7, hairColor = 10, eye = 5, skin = 7, outfit = 3 } },
}
for i, p in picks do
	local rig = Rig.build(p[1], roblox.CFrame.new((i - 3.5) * 9, 0, 0) * roblox.CFrame.Angles(0, math.rad(180), 0))
	Rig.applyPose(rig, Moves.sample(Moves.get(p[2]), p[3]))
	Appearance.apply(rig, p[5], p[4])
	Weapons.attach(rig, p[1])
	rig.Parent = ws
end
local floor = roblox.Instance.new("Part")
floor.Anchored = true
floor.Size = roblox.Vector3.new(80, 1, 30)
floor.CFrame = roblox.CFrame.new(0, -0.5, 0)
floor.Color = roblox.Color3.fromRGB(38, 44, 64)
floor.Parent = ws
Harness.writeJson("build/weapons.json", Harness.dumpScene({ ws }))
