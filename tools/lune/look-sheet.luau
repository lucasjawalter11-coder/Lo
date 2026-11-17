-- Dev helper: dresses a row of stand-in bodies in different looks and schools, for a preview render.
local Harness = require("./harness")
local roblox = require("@lune/roblox")

local game = Harness.loadPlace("build/base.rbxl")
local requireModule = Harness.loader(Harness.globals(game))
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("HalcyonShared")
local Appearance = requireModule(shared:FindFirstChild("Appearance"))
local Looks = requireModule(shared:FindFirstChild("Looks"))

local ws = game:GetService("Workspace")
local schools = { "northwind", "solcrest", "arcline", "ironreach", nil }
local i = 0
for hair = 1, #Looks.HairStyles do
	i += 1
	local m = Appearance.mannequin()
	local look = { outfit = 1 + (i - 1) % 4, hair = hair, hairColor = 1 + (i * 5) % 12, eye = 1 + i % 8, skin = 1 + (i * 3) % 8, avatar = false }
	Appearance.apply(m, look, schools[1 + (i - 1) % 4])
	m:PivotTo(roblox.CFrame.new((i - 4.5) * 4.2, 0, 0) * roblox.CFrame.Angles(0, math.rad(180), 0))
	m.Parent = ws
end
local m = Appearance.mannequin()
Appearance.apply(m, { avatar = true }, "solcrest")
m:PivotTo(roblox.CFrame.new(4.5 * 4.2, 0, 0) * roblox.CFrame.Angles(0, math.rad(180), 0))
m.Parent = ws
print("sanitize junk:", Looks.sanitize({ outfit = 99, hair = -3, hairColor = "x", eye = 0 / 0, skin = 2.7, avatar = "yes" }).outfit)
Harness.writeJson("build/looks.json", Harness.dumpScene({ ws }))
