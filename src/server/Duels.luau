--!nonstrict
-- Duels: sanctioned one-on-one fights against NPC duelists. Every duel gets its own copy of the arena, far
-- out over the lake, so any number of players can duel at once without meeting each other.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Roster = require(Shared:WaitForChild("Roster"))
local Rig = require(Shared:WaitForChild("Rig"))
local Appearance = require(Shared:WaitForChild("Appearance"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local Duels = {}

local Combat, Ai, Profiles, DuelRemote, anchorsFolder
local active: { [Player]: any } = {}
local slots: { [number]: boolean } = {}

local NPC_WEAPON = { saber = "saber", lance = "lance", maul = "maul", pistols = "pistols", spear = "lance", hammer = "maul", pistol = "pistols", scythe = "scythe", orbit = "discs", discs = "discs" }

local function slotPosition(slot: number): Vector3
	return Vector3.new(9000 + (slot % 8) * 520, 0, 9000 + math.floor(slot / 8) * 520)
end

local function claimSlot(): number
	local i = 0
	while slots[i] do
		i += 1
	end
	slots[i] = true
	return i
end

--- Builds an NPC duelist's body: a standard R15 rig wearing the NPC's designed look and weapon.
local function buildDuelist(npc, cf: CFrame): Model
	local model = Rig.build(npc.name, cf)
	local academy = Config.Academies[npc.academy]
	Appearance.dress(model, {
		skin = npc.look.skin, hair = npc.look.hair, hairTip = npc.look.hairTip, hairStyle = npc.look.hairStyle,
		eye = npc.look.eye, outfit = npc.look.outfit, accent = npc.look.accent,
		uniform = if academy then academy.uniform else { jacket = Color3.fromRGB(43, 47, 69), trim = npc.look.accent, dark = Color3.fromRGB(27, 30, 44), pants = Color3.fromRGB(27, 30, 44), boots = Color3.fromRGB(17, 19, 32), glove = Color3.fromRGB(27, 30, 44) },
		school = npc.academy,
	})
	Weapons.attach(model, NPC_WEAPON[npc.weapon] or "saber")
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = npc.name
	hum.WalkSpeed = 18
	return model
end

local function returnPoint(npcId: string): CFrame
	local a = anchorsFolder:FindFirstChild("Return_" .. npcId) or anchorsFolder:FindFirstChild("Return_Default")
	return if a then a.CFrame + Vector3.new(0, 3, 0) else CFrame.new(0, 8, 360)
end

local function finish(duel, winner: string)
	if duel.over then
		return
	end
	duel.over = true
	local player = duel.player
	local won = winner == "player"
	local npc = duel.npc
	local profile = Profiles.get(player)
	local coins = if won then Config.Rewards.WinCoinsBase + Config.Rewards.WinCoinsPerLevel * (npc.level or 1) else Config.Rewards.LoseCoins
	if profile then
		profile.coins = (profile.coins or 0) + coins
		profile.wins = (profile.wins or 0) + (if won then 1 else 0)
		Profiles.markDirty(player)
	end
	DuelRemote:FireClient(player, "result", {
		won = won, name = npc.name, line = if won then npc.lose else npc.win, coins = coins,
		total = profile and profile.coins or coins,
	})
	if duel.npcFighter then
		duel.npcFighter.model:SetAttribute("State", if won then "ko" else "victory")
	end
	task.delay(4.5, function()
		Duels.cleanup(player, true)
	end)
end

function Duels.cleanup(player: Player, teleportBack: boolean?)
	local duel = active[player]
	if not duel then
		return
	end
	active[player] = nil
	duel.over = true
	if duel.npcFighter then
		Combat.unregister(duel.npcFighter.model)
	end
	if duel.npcModel then
		duel.npcModel:Destroy()
	end
	if duel.arena then
		duel.arena:Destroy()
	end
	slots[duel.slot] = nil
	local character = player.Character
	local f = character and Combat.get(character)
	if f then
		f.duel = nil
		f.team = nil
		Combat.heal(f, true)
	end
	if teleportBack and character and character.Parent then
		local target = returnPoint(duel.npc.id)
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 5)
		end)
		character:PivotTo(target)
	end
	DuelRemote:FireClient(player, "ended", {})
end

--- Starts a duel between `player` and the NPC with id `npcId`.
function Duels.challenge(player: Player, npcId: string): boolean
	if active[player] then
		return false
	end
	local npc = Roster.get(npcId)
	if not npc or not npc.weapon then
		return false
	end
	local character = player.Character
	local f = character and Combat.get(character)
	if not f or f.state == "ko" then
		return false
	end
	local template = ServerStorage:FindFirstChild(Config.ArenaTemplateName)
	if not template then
		return false
	end
	local slot = claimSlot()
	local base = slotPosition(slot)
	local arena = template:Clone()
	arena.Name = "Duel_" .. player.UserId
	arena:PivotTo(CFrame.new(base) * arena:GetPivot())
	arena.Parent = Workspace
	local spawnA = arena:FindFirstChild("SpawnA").CFrame
	local spawnB = arena:FindFirstChild("SpawnB").CFrame
	local duel = { player = player, npc = npc, arena = arena, slot = slot, over = false }
	active[player] = duel

	-- the opponent
	local model = buildDuelist(npc, spawnB - Vector3.new(0, 3, 0))
	model.Parent = arena
	local npcF = Combat.register(model, {
		kind = "npc", name = npc.name, weapon = NPC_WEAPON[npc.weapon] or "saber",
		hpScale = 0.75 + 0.03 * (npc.level or 1), power = 0.7 + 0.025 * (npc.level or 1), team = "b",
	})
	duel.npcModel = model
	duel.npcFighter = npcF
	npcF.duel = duel

	-- the challenger
	Combat.heal(f, true)
	f.lumen = 0
	f.duel = duel
	f.team = "a"
	pcall(function()
		player:RequestStreamAroundAsync(spawnA.Position, 5)
	end)
	character:PivotTo(spawnA)

	DuelRemote:FireClient(player, "intro", {
		name = npc.name, epithet = npc.epithet, line = npc.taunt, accent = npc.look.accent,
		school = npc.academy, level = npc.level, opponent = model, time = Config.Combat.IntroTime,
	})
	task.delay(Config.Combat.IntroTime, function()
		if duel.over then
			return
		end
		duel.started = os.clock()
		DuelRemote:FireClient(player, "fight", { time = Config.Combat.RoundTime })
		task.spawn(Ai.run, Combat, npcF, f, npc.ai or 1, function()
			return not duel.over and active[player] == duel
		end)
		-- the round timer: when it runs out, the healthier duelist wins
		task.delay(Config.Combat.RoundTime, function()
			if not duel.over then
				finish(duel, if f.hp / f.maxHp >= npcF.hp / npcF.maxHp then "player" else "npc")
			end
		end)
	end)
	return true
end

function Duels.isDueling(player: Player): boolean
	return active[player] ~= nil
end

function Duels.start(deps)
	Combat, Ai, Profiles, anchorsFolder = deps.Combat, deps.Ai, deps.Profiles, deps.anchors
	DuelRemote = deps.remote
	Combat.onKo = function(victim, attacker)
		for _, duel in active do
			if victim.duel == duel then
				finish(duel, if victim == duel.npcFighter then "player" else "npc")
			end
		end
		local _ = attacker
	end
	Players.PlayerRemoving:Connect(function(player)
		Duels.cleanup(player, false)
	end)
end

return Duels
