-- Offline test: two AI duelists fight through the real Combat and Ai modules (no Roblox physics).
-- Usage: lune run tools/lune/sim-duel.luau [weaponA] [weaponB] [levelA] [levelB] [seconds]
local Harness = require("./harness")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local luneTask = require("@lune/task")

local realGame = Harness.loadPlace("build/base.rbxl")
local clock0 = os.clock()
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.clock() - clock0
end)
local moveDir = {}
roblox.implementMethod("Humanoid", "Move", function(self, dir)
	moveDir[self] = dir
end)
local stub = { Connect = function() return { Disconnect = function() end } end }
local fakeGame = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				if name == "RunService" then
					return { Heartbeat = stub, Stepped = stub }
				elseif name == "Players" then
					return { PlayerRemoving = stub, PlayerAdded = stub, GetPlayers = function() return {} end }
				end
				return realGame:GetService(name)
			end
		end
		return realGame[key]
	end,
})
local requireModule = Harness.loader(Harness.globals(realGame, { game = fakeGame }))
local server = realGame:GetService("ServerScriptService"):FindFirstChild("HalcyonServer")
local shared = realGame:GetService("ReplicatedStorage"):FindFirstChild("HalcyonShared")
local Combat = requireModule(server:FindFirstChild("Combat"))
local Ai = requireModule(server:FindFirstChild("Ai"))
local Rig = requireModule(shared:FindFirstChild("Rig"))
local Weapons = requireModule(shared:FindFirstChild("Weapons"))

local wa, wb = process.args[1] or "saber", process.args[2] or "maul"
local la, lb = tonumber(process.args[3]) or 3, tonumber(process.args[4]) or 3
local seconds = tonumber(process.args[5]) or 40
local ws = realGame:GetService("Workspace")

local function make(name, weapon, x)
	local m = Rig.build(name, roblox.CFrame.new(x, 0, 0) * roblox.CFrame.Angles(0, math.rad(if x > 0 then 90 else -90), 0))
	Weapons.attach(m, weapon)
	m.Parent = ws
	local root = m:FindFirstChild("HumanoidRootPart")
	root.Position = root.CFrame.Position -- Lune keeps Position separately from CFrame
	return Combat.register(m, { kind = "npc", name = name, weapon = weapon })
end
local a = make("A-" .. wa, wa, -12)
local b = make("B-" .. wb, wb, 12)
local duel = {}
a.duel, b.duel, a.team, b.team = duel, duel, "a", "b"

local stats = { hit = 0, guard = 0, perfect = 0, parry = 0, miss = 0, proj = 0, guardbreak = 0, spear = 0 }
local moveCount = {}
Combat.onFx = function(d)
	stats[d.kind] = (stats[d.kind] or 0) + 1
end
local over, winner = false, nil
Combat.onKo = function(victim)
	over = true
	winner = if victim == a then b.name else a.name
end
local origStart = Combat.startMove
Combat.startMove = function(f, id, opts)
	local ok = origStart(f, id, opts)
	if ok then
		moveCount[id] = (moveCount[id] or 0) + 1
	end
	return ok
end

local function alive()
	return not over
end
luneTask.spawn(Ai.run, Combat, a, b, la, alive)
luneTask.spawn(Ai.run, Combat, b, a, lb, alive)

local t0 = os.clock()
local last = os.clock()
while not over and os.clock() - t0 < seconds do
	luneTask.wait(1 / 30)
	local dt = os.clock() - last
	last = os.clock()
	for _, f in { a, b } do
		local hum, root = f.humanoid, f.root
		local dir = moveDir[hum]
		local v = roblox.Vector3.new(0, 0, 0)
		if dir and f.state ~= "stun" and f.state ~= "down" and f.state ~= "move" then
			v = dir * 18
		end
		for _, c in root:GetChildren() do
			if c.ClassName == "LinearVelocity" then
				v = c.VectorVelocity * roblox.Vector3.new(1, 0, 1)
			end
		end
		local pos = root.CFrame.Position + v * dt
		pos = roblox.Vector3.new(math.clamp(pos.X, -40, 40), 3, math.clamp(pos.Z, -40, 40))
		root.CFrame = roblox.CFrame.new(pos) * root.CFrame.Rotation
		root.Position = pos
	end
	Combat.step(dt)
end
over = true
print(string.format("%.1fs  winner: %s", os.clock() - t0, tostring(winner)))
print(string.format("%s hp %d/%d lumen %d   %s hp %d/%d lumen %d", a.name, a.hp, a.maxHp, a.lumen, b.name, b.hp, b.maxHp, b.lumen))
local parts = {}
for k, v in stats do
	if v > 0 then
		table.insert(parts, k .. "=" .. v)
	end
end
table.sort(parts)
print("events: " .. table.concat(parts, " "))
local mv = {}
for k, v in moveCount do
	table.insert(mv, k .. "=" .. v)
end
table.sort(mv)
print("moves: " .. table.concat(mv, " "))
process.exit(0)
