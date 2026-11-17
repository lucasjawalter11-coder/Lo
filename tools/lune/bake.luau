-- Bakes the world into the place file.
--   1. `rojo build` produces build/base.rbxl (scripts only).
--   2. This script loads it, runs the game's own world builders against real Roblox instances,
--      and writes HalcyonClash.rbxl plus a scene dump for the preview renderer.
local Harness = require("./harness")

local game = Harness.loadPlace("build/base.rbxl")
local requireModule = Harness.loader(Harness.globals(game))
local server = game:GetService("ServerScriptService"):FindFirstChild("HalcyonServer")

local World = requireModule(server:FindFirstChild("World"))
local started = os.clock()
World.build(game)

local workspace = game:GetService("Workspace")
local counts = { parts = 0, lights = 0, emitters = 0, guis = 0 }
for _, inst in game:GetDescendants() do
	if inst:IsA("BasePart") then
		counts.parts += 1
	elseif inst:IsA("Light") then
		counts.lights += 1
	elseif inst:IsA("ParticleEmitter") then
		counts.emitters += 1
	elseif inst:IsA("SurfaceGui") then
		counts.guis += 1
	end
end
print(string.format("world built in %.2fs: %d parts, %d lights, %d particle emitters, %d surface guis", os.clock() - started, counts.parts, counts.lights, counts.emitters, counts.guis))

Harness.savePlace(game, "HalcyonClash.rbxl")
Harness.writeJson("build/scene.json", Harness.dumpScene({ workspace }))
print("wrote HalcyonClash.rbxl and build/scene.json")
