--!nonstrict
-- Ai: how NPC duelists fight. Each brain thinks a few times a second: keep the right distance for its
-- weapon, read the rival's swings (guard, perfect-guard or dash away), run combos with cancels, use
-- skills when they are ready, and save the ultimate for a good moment.
-- Level 0 is a nervous first-year; level 3 is a seat-holder near the top of the Register.
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Moves = require(Shared:WaitForChild("Moves"))

local Ai = {}

local RANGED = { pistols = true, discs = true }
local PROFILE = {
	[0] = { think = 0.34, guard = 0.12, perfect = 0.0, dash = 0.08, chain = 2, skill = 0.15, aggro = 0.55 },
	[1] = { think = 0.26, guard = 0.28, perfect = 0.05, dash = 0.15, chain = 3, skill = 0.3, aggro = 0.65 },
	[2] = { think = 0.2, guard = 0.42, perfect = 0.14, dash = 0.22, chain = 4, skill = 0.45, aggro = 0.75 },
	[3] = { think = 0.15, guard = 0.55, perfect = 0.28, dash = 0.3, chain = 4, skill = 0.6, aggro = 0.85 },
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

--- Runs a brain for fighter `f` against `target` until `alive()` returns false.
function Ai.run(Combat, f, target, level: number, alive: () -> boolean)
	local p = PROFILE[math.clamp(level, 0, 3)]
	local weapon = f.weapon
	local ranged = RANGED[weapon] == true
	local reach = (Moves.get(weapon .. "_l1").hits and Moves.get(weapon .. "_l1").hits[1].reach) or 8
	local chainStep = 0
	local nextChainAt = 0
	local strafe = if math.random() < 0.5 then 1 else -1
	local strafeFlip = now() + 2

	local function act(id: string, charge: number?): boolean
		return Combat.startMove(f, id, { charge = charge, target = target })
	end

	local function readyFor(id: string): boolean
		local move = Moves.get(id)
		if not move then
			return false
		end
		local cd = f.cooldowns[id]
		return (not move.cost or f.lumen >= move.cost) and (not cd or now() >= cd)
	end

	while alive() do
		task.wait(p.think * (0.8 + math.random() * 0.4))
		if not alive() then
			break
		end
		local t = now()
		local hum = f.humanoid
		local busy = f.state == "move" and f.move and t - f.moveStart < f.move.cancel
		if f.state == "stun" and f.comboHits >= 3 and f.lumen >= 25 and math.random() < p.dash + 0.15 then
			-- Break Away out of a long combo
			local away = f.root.Position - target.root.Position
			away = Vector3.new(away.X, 0, away.Z)
			Combat.dash(f, if away.Magnitude > 0.1 then away.Unit else nil)
			continue
		end
		if f.state == "stun" or f.state == "down" or f.state == "ko" or target.state == "ko" then
			chainStep = 0
			if hum then
				hum:Move(Vector3.zero)
			end
			continue
		end
		local offset = target.root.Position - f.root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local dist = flat.Magnitude
		local dir = if dist > 0.1 then flat.Unit else Vector3.new(0, 0, -1)

		-- answer a perfect guard with the counter
		if t < f.counterUntil then
			act(weapon .. "_counter")
			continue
		end

		-- read the rival's attack
		local threat = target.state == "move" and target.move and dist < 16 and (t - target.moveStart) < 0.3
		if threat and not busy then
			local roll = math.random()
			if roll < p.perfect then
				Combat.setGuard(f, true)
				task.delay(0.35, function()
					Combat.setGuard(f, false)
				end)
				continue
			elseif roll < p.perfect + p.guard then
				Combat.setGuard(f, true)
				task.delay(0.5 + math.random() * 0.4, function()
					Combat.setGuard(f, false)
				end)
				continue
			elseif roll < p.perfect + p.guard + p.dash then
				local side = dir:Cross(Vector3.new(0, 1, 0)) * strafe
				Combat.dash(f, (side - dir * 0.6).Unit)
				continue
			end
		end
		if f.guarding or busy then
			continue
		end

		-- ultimate: when full and close enough to land it
		if f.lumen >= 100 and dist < 16 and math.random() < p.skill then
			if act(weapon .. "_ult") then
				chainStep = 0
				continue
			end
		end
		-- skills
		if math.random() < p.skill * 0.5 then
			local order = { 1, 2, 3 }
			for i = #order, 2, -1 do
				local j = math.random(i)
				order[i], order[j] = order[j], order[i]
			end
			local used = false
			for _, slot in order do
				local id = weapon .. "_s" .. slot
				local move = Moves.get(id)
				local fits = ranged or (move and (move.proj or move.blink or move.zone or move.orbit or dist < reach + 6))
				if move and fits and readyFor(id) and dist < 45 then
					if act(id) then
						used = true
						chainStep = 0
						break
					end
				end
			end
			if used then
				continue
			end
		end

		-- melee fighters close long gaps with a dash instead of walking into fire
		if not ranged and dist > reach + 7 and dist < 45 and t - f.lastDash > 1.1 and math.random() < 0.45 + level * 0.12 then
			Combat.dash(f, dir)
			continue
		end
		-- spacing
		local want = if ranged then 16 else reach - 1.5
		if hum then
			if dist > want + 3 then
				hum:Move(dir)
			elseif ranged and dist < want - 6 then
				hum:Move(-dir + dir:Cross(Vector3.new(0, 1, 0)) * strafe * 0.5)
			else
				if t > strafeFlip then
					strafe = -strafe
					strafeFlip = t + 1.5 + math.random() * 2
				end
				hum:Move(dir:Cross(Vector3.new(0, 1, 0)) * strafe * 0.35)
			end
			-- face the rival
			f.root.CFrame = CFrame.lookAt(f.root.Position, f.root.Position + dir)
		end

		-- attack
		local inRange = if ranged then dist < 40 else dist < reach + 1.5
		if inRange and t >= nextChainAt and math.random() < p.aggro then
			chainStep += 1
			local id
			if chainStep > p.chain then
				chainStep = 0
				id = if math.random() < 0.5 then weapon .. "_heavy" else weapon .. "_launch"
			else
				id = weapon .. "_l" .. math.min(chainStep, 4)
			end
			if act(id, math.random() * 0.6) then
				local move = Moves.get(id)
				nextChainAt = t + (move and move.cancel or 0.3)
				if chainStep == 0 then
					nextChainAt += 0.5 + (3 - level) * 0.25
				end
			else
				chainStep = 0
			end
		elseif not inRange then
			chainStep = 0
		end
	end
	if f.humanoid then
		f.humanoid:Move(Vector3.zero)
	end
end

return Ai
