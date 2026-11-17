--!nonstrict
-- Combat: the server's side of every fight. Players and NPCs are "fighters". A fighter asks to start a move;
-- the server checks it is allowed (state, cooldown, Lumen), tells every client to play it, and resolves its
-- hits, projectiles, beams and zones on the moves' own timeline. Damage only lands between fighters that are
-- allowed to fight: duel opponents, training dummies, and anyone standing inside a free-fight zone.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local Combat = {}

local C = Config.Combat
local fighters: { [Model]: any } = {}
local projectiles = {}
local zones = {} -- free-fight zones: { centre: Vector3, radius: number }
local remotes -- set by Combat.start
local Fx: RemoteEvent
local CombatRemote: RemoteEvent

Combat.Fighters = fighters
Combat.onKo = nil -- function(victim, attacker) set by the duel system

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ---------------------------------------------------------------------------------------------
-- Fighters
-- ---------------------------------------------------------------------------------------------
export type Fighter = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	player: Player?,
	kind: string, -- player | npc | dummy
	name: string,
	weapon: string,
	maxHp: number,
	hp: number,
	lumen: number,
	guardMeter: number,
	power: number,
	state: string, -- idle | move | stun | down | dash
	move: any?,
	moveStart: number,
	moveSerial: number,
	stunUntil: number,
	downUntil: number,
	invulnUntil: number,
	armorUntil: number,
	buffUntil: number,
	buffPower: number,
	guarding: boolean,
	guardStart: number,
	counterUntil: number,
	cooldowns: { [string]: number },
	lastDash: number,
	comboHits: number,
	comboUntil: number,
	duel: any?,
	team: string?,
	stance: any?,
	airDashes: number,
}

local function setAttr(f, name: string, value: any)
	if f.model.Parent then
		f.model:SetAttribute(name, value)
	end
end

local function syncBars(f)
	setAttr(f, "HP", math.max(0, math.floor(f.hp + 0.5)))
	setAttr(f, "MaxHP", f.maxHp)
	setAttr(f, "Lumen", math.floor(f.lumen))
	setAttr(f, "GuardMeter", math.floor(f.guardMeter))
end

function Combat.register(model: Model, opts): Fighter?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root then
		return nil
	end
	local weapon = opts.weapon or "saber"
	local def = Weapons.List[weapon] or Weapons.List.saber
	local hp = math.floor((opts.hp or def.hp) * (opts.hpScale or 1))
	local f = {
		model = model, root = root, humanoid = humanoid, player = opts.player, kind = opts.kind or "player",
		name = opts.name or model.Name, weapon = def.id,
		maxHp = hp, hp = hp, lumen = opts.lumen or 0, guardMeter = 100,
		basePower = opts.power or 1, power = (opts.power or 1) * def.power,
		state = "idle", move = nil, moveStart = 0, moveSerial = 0,
		stunUntil = 0, downUntil = 0, invulnUntil = 0, armorUntil = 0, buffUntil = 0, buffPower = 1,
		guarding = false, guardStart = 0, counterUntil = 0, cooldowns = {}, lastDash = 0,
		comboHits = 0, comboUntil = 0, duel = nil, team = opts.team, stance = nil, airDashes = 0,
		dummy = opts.kind == "dummy", ai = opts.ai,
	}
	fighters[model] = f
	model:SetAttribute("Fighter", true)
	model:SetAttribute("Weapon", def.id)
	model:SetAttribute("FighterName", f.name)
	syncBars(f)
	return f
end

function Combat.unregister(model: Model)
	fighters[model] = nil
end

function Combat.get(model: Model?)
	return model and fighters[model]
end

function Combat.setWeapon(f, weapon: string)
	local def = Weapons.List[weapon]
	if not def then
		return
	end
	f.weapon = def.id
	f.power = f.basePower * def.power
	f.model:SetAttribute("Weapon", def.id)
	Weapons.attach(f.model, def.id)
end

function Combat.heal(f, full: boolean?)
	f.hp = if full then f.maxHp else math.min(f.maxHp, f.hp + f.maxHp * 0.3)
	f.guardMeter = 100
	f.state = "idle"
	f.stunUntil, f.downUntil = 0, 0
	setAttr(f, "State", "idle")
	syncBars(f)
end

function Combat.addZone(centre: Vector3, radius: number)
	table.insert(zones, { centre = centre, radius = radius })
end

local function inZone(pos: Vector3): boolean
	for _, z in zones do
		local d = pos - z.centre
		if Vector3.new(d.X, 0, d.Z).Magnitude <= z.radius and math.abs(d.Y) < 40 then
			return true
		end
	end
	return false
end

--- Can `a` hurt `b`?
local function hostile(a, b): boolean
	if a == b or not b.model.Parent then
		return false
	end
	if b.dummy then
		return a.kind == "player" or a.kind == "npc"
	end
	if a.duel or b.duel then
		return a.duel ~= nil and a.duel == b.duel and a.team ~= b.team
	end
	if a.kind == "npc" or b.kind == "npc" then
		return false
	end
	return inZone(a.root.Position) and inZone(b.root.Position)
end
Combat.hostile = hostile

-- ---------------------------------------------------------------------------------------------
-- Effects and messages
-- ---------------------------------------------------------------------------------------------
local function fx(data)
	if Fx then
		Fx:FireAllClients(data)
	end
	if Combat.onFx then
		Combat.onFx(data)
	end
end
Combat.fx = fx

local function tell(f, kind: string, data)
	if f.player and CombatRemote then
		CombatRemote:FireClient(f.player, kind, data)
	end
end

--- Pushes a fighter. Players move their own characters, so their client is told to apply it.
local function push(f, velocity: Vector3, duration: number, float: boolean?)
	if f.dummy then
		return
	end
	if f.player then
		tell(f, "push", { v = velocity, d = duration, float = float })
		return
	end
	local root = f.root
	local att = root:FindFirstChild("PushAttachment") or Instance.new("Attachment")
	att.Name = "PushAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = velocity
	lv.Parent = root
	task.delay(duration, function()
		lv:Destroy()
	end)
end
Combat.push = push

-- ---------------------------------------------------------------------------------------------
-- Damage
-- ---------------------------------------------------------------------------------------------
local function ko(victim, attacker)
	victim.state = "down"
	victim.downUntil = math.huge
	setAttr(victim, "State", "ko")
	fx({ kind = "ko", pos = victim.root.Position, color = Config.hex(0xffc94a) })
	if Combat.onKo then
		task.spawn(Combat.onKo, victim, attacker)
	end
	if not victim.duel and not victim.dummy then
		-- free fights: get back up after a moment with some health
		task.delay(3, function()
			if fighters[victim.model] and victim.state == "down" then
				Combat.heal(victim, false)
			end
		end)
	end
end

--- Applies one hit from `a` to `b`. `h` is the hit definition, `dir` the push direction.
local function applyHit(a, b, h, dir: Vector3, hitPos: Vector3, charge: number?)
	local t = now()
	if t < b.invulnUntil then
		fx({ kind = "miss", pos = b.root.Position + Vector3.new(0, 3, 0) })
		return false
	end
	-- counter stance: answer instead of taking the hit
	if b.stance and t >= b.stance.from and t <= b.stance.to then
		local counter = b.stance.counter
		b.stance = nil
		fx({ kind = "parry", pos = hitPos, color = Config.hex(0x6fe6ff) })
		Combat.startMove(b, counter, { forced = true, target = a })
		a.state = "stun"
		a.stunUntil = t + 0.6
		setAttr(a, "State", "stun")
		return false
	end
	local dmg = h.dmg * a.power * (if t < a.buffUntil then a.buffPower else 1)
	if charge and h.chargeDmg then
		dmg *= 1 + h.chargeDmg * charge
	end
	if h.crit then
		dmg *= 1.15
	end
	-- combo damage falloff, so long juggles stay fair
	if t > b.comboUntil then
		b.comboHits = 0
	end
	dmg *= math.max(C.ComboFloor, 1 - C.ComboScale * b.comboHits)
	local guardBreak = h.guardBreak or (charge and h.chargeBreak and charge >= h.chargeBreak)

	if b.guarding and not guardBreak and b.state ~= "stun" and b.state ~= "down" then
		local facing = b.root.CFrame.LookVector
		local toAttacker = (a.root.Position - b.root.Position) * Vector3.new(1, 0, 1)
		local front = toAttacker.Magnitude < 0.01 or facing:Dot(toAttacker.Unit) > -0.2
		if front then
			if t - b.guardStart <= C.PerfectWindow then
				-- Perfect Guard: no damage, the attacker reels, the defender may counter
				a.state = "stun"
				a.stunUntil = t + C.PerfectStagger
				a.move = nil
				setAttr(a, "State", "stun")
				b.counterUntil = t + 0.9
				b.lumen = math.min(C.LumenMax, b.lumen + 18)
				syncBars(b)
				tell(b, "perfect", { until_ = b.counterUntil })
				tell(a, "stagger", { d = C.PerfectStagger })
				fx({ kind = "perfect", pos = hitPos, color = Config.hex(0xffffff) })
				return false
			end
			local chip = dmg * (if h.heavy then C.HeavyChip else C.GuardChip)
			b.hp -= chip
			b.guardMeter -= dmg * 0.55
			b.lumen = math.min(C.LumenMax, b.lumen + 4)
			fx({ kind = "guard", pos = hitPos, dmg = math.floor(chip), heavy = h.heavy })
			if b.guardMeter <= 0 then
				b.guardMeter = 100
				b.guarding = false
				b.state = "stun"
				b.stunUntil = t + 1.2
				setAttr(b, "Guard", false)
				setAttr(b, "State", "guardbreak")
				fx({ kind = "guardbreak", pos = b.root.Position + Vector3.new(0, 3, 0) })
				tell(b, "stagger", { d = 1.2 })
			end
			syncBars(b)
			push(b, dir * (h.kb or 0) * 0.35, 0.12)
			if b.hp <= 0 then
				ko(b, a)
			end
			return true
		end
	end

	b.hp -= dmg
	b.comboHits += 1
	b.comboUntil = t + 1.2
	a.lumen = math.min(C.LumenMax, a.lumen + 6)
	b.lumen = math.min(C.LumenMax, b.lumen + 3)
	setAttr(a, "Combo", b.comboHits)
	if b.guarding then
		b.guarding = false
		setAttr(b, "Guard", false)
	end
	local armoured = t < b.armorUntil and not guardBreak and not h.launch
	if not armoured and not b.dummy then
		local stun = h.stun or 0.35
		b.move = nil
		if h.down then
			b.state = "down"
			b.downUntil = t + C.DownTime + 0.3
			b.stunUntil = b.downUntil + C.GetupTime
			setAttr(b, "State", "down")
		else
			b.state = "stun"
			b.stunUntil = t + stun
			setAttr(b, "State", if h.launch then "launched" else "stun")
		end
		local v = dir * (h.kb or 0)
		local up = h.launch or h.up or 0
		if h.pull then
			v = (a.root.Position - b.root.Position) * Vector3.new(1, 0, 1)
			v = if v.Magnitude > 4 then v.Unit * math.min(70, v.Magnitude * 6) else Vector3.zero
		end
		push(b, v + Vector3.new(0, up, 0), if h.launch then 0.25 else 0.14, h.float or (h.launch ~= nil))
		tell(b, "hit", { stun = if h.down then C.DownTime + 0.3 + C.GetupTime else stun, down = h.down, launch = h.launch, float = h.float })
	end
	syncBars(a)
	syncBars(b)
	fx({
		kind = "hit", pos = hitPos, dmg = math.floor(dmg), heavy = h.heavy, crit = h.crit, combo = b.comboHits,
		color = (Weapons.List[a.weapon] or Weapons.List.saber).color,
		stop = if h.heavy then 0.11 else 0.06, attacker = a.model, victim = b.model,
	})
	if b.dummy then
		if b.hp <= 0 then
			b.hp = b.maxHp
		end
		syncBars(b)
		return true
	end
	if b.hp <= 0 then
		ko(b, a)
	end
	return true
end
Combat.applyHit = applyHit

-- ---------------------------------------------------------------------------------------------
-- Hit detection
-- ---------------------------------------------------------------------------------------------
local function targetsInArc(a, centre: Vector3, facing: Vector3, reach: number, arc: number, height: number)
	local out = {}
	for _, b in fighters do
		if hostile(a, b) and b.state ~= "ko" then
			local d = b.root.Position - centre
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude <= reach + 2 and math.abs(d.Y) <= height then
				local ok = arc >= 360 or flat.Magnitude < 2.5
				if not ok then
					local cos = facing:Dot(flat.Unit)
					ok = cos >= math.cos(math.rad(arc / 2))
				end
				if ok then
					table.insert(out, b)
				end
			end
		end
	end
	return out
end

local function flatLook(f): Vector3
	local look = f.root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
end

local function resolveMelee(a, h, serial: number, charge: number?)
	if a.moveSerial ~= serial or a.state ~= "move" then
		return
	end
	local facing = flatLook(a)
	local centre = a.root.Position + facing * (h.at or 0)
	for _, b in targetsInArc(a, centre, facing, h.reach, h.arc or 120, h.height or 8) do
		local dir = (b.root.Position - a.root.Position) * Vector3.new(1, 0, 1)
		dir = if dir.Magnitude > 0.01 then dir.Unit else facing
		applyHit(a, b, h, dir, b.root.Position + Vector3.new(0, 1, 0) - dir * 1.2, charge)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Projectiles (simulated on the server, drawn by the clients)
-- ---------------------------------------------------------------------------------------------
local projSerial = 0
local function launchProjectile(a, p, serial: number, charge: number?)
	if a.moveSerial ~= serial or a.state ~= "move" then
		return
	end
	local facing = flatLook(a)
	local yaw = math.rad(p.spread or 0)
	local dir = CFrame.Angles(0, -yaw, 0) * facing
	if p.pitch then
		dir = (dir + Vector3.new(0, math.tan(math.rad(p.pitch)), 0)).Unit
	end
	-- aim at the target's height when one is ahead
	local side = if p.from == "L" then -1.4 elseif p.from == "R" then 1.4 else 0
	local right = facing:Cross(Vector3.new(0, 1, 0))
	local origin = a.root.Position + facing * 2 + right * side + Vector3.new(0, if p.ground then -2.6 else 0.8, 0)
	projSerial += 1
	local proj = {
		id = projSerial, owner = a, def = p, pos = origin, origin = origin, dir = dir, travelled = 0,
		hit = {}, returning = false, charge = charge, born = now(),
	}
	table.insert(projectiles, proj)
	fx({ kind = "proj", id = proj.id, shape = p.kind, pos = origin, dir = dir, speed = p.speed, range = p.range, boomerang = p.boomerang, owner = a.model, color = (Weapons.List[a.weapon] or Weapons.List.saber).color, radius = p.radius })
end

local function stepProjectiles(dt: number)
	for i = #projectiles, 1, -1 do
		local proj = projectiles[i]
		local p = proj.def
		local a = proj.owner
		local stepLen = p.speed * dt
		if proj.returning then
			local back = (a.root.Position + Vector3.new(0, 0.8, 0)) - proj.pos
			if back.Magnitude <= stepLen + 2 then
				table.remove(projectiles, i)
				fx({ kind = "projEnd", id = proj.id })
				continue
			end
			proj.dir = back.Unit
		end
		proj.pos += proj.dir * stepLen
		proj.travelled += stepLen
		local done = false
		for _, b in fighters do
			if hostile(a, b) and not proj.hit[b] then
				local d = b.root.Position - proj.pos
				if d.Magnitude <= p.radius + 2.2 then
					proj.hit[b] = true
					local push = proj.dir * Vector3.new(1, 0, 1)
					push = if push.Magnitude > 0.01 then push.Unit else flatLook(a)
					applyHit(a, b, p, push, proj.pos, proj.charge)
					if not p.pierce then
						done = true
						break
					end
				end
			end
		end
		if not done and proj.travelled >= p.range then
			if p.boomerang and not proj.returning then
				proj.returning = true
				proj.hit = {}
				fx({ kind = "projReturn", id = proj.id })
			else
				done = true
			end
		end
		if done or now() - proj.born > 6 then
			table.remove(projectiles, i)
			fx({ kind = "projEnd", id = proj.id, pos = proj.pos })
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Moves
-- ---------------------------------------------------------------------------------------------
local function nearestTarget(a, range: number)
	local best, bestD = nil, range
	for _, b in fighters do
		if hostile(a, b) and b.state ~= "ko" then
			local d = (b.root.Position - a.root.Position).Magnitude
			if d < bestD then
				best, bestD = b, d
			end
		end
	end
	return best
end
Combat.nearestTarget = nearestTarget

local function canAct(f, move): (boolean, string?)
	local t = now()
	if f.state == "down" or f.state == "ko" then
		return false, "down"
	end
	if f.state == "stun" and t < f.stunUntil then
		return false, "stun"
	end
	if f.move and f.state == "move" then
		local elapsed = t - f.moveStart
		-- generous by the network delay: the client already cancelled on its own clock
		if elapsed < f.move.cancel - 0.12 and elapsed < f.move.dur then
			return false, "busy"
		end
	end
	if move.kind == "counter" and t > f.counterUntil + 0.25 then
		return false, "nocounter"
	end
	if move.cost and f.lumen + 0.5 < move.cost then
		return false, "lumen"
	end
	local cd = f.cooldowns[move.id]
	if cd and t < cd - 0.15 then
		return false, "cooldown"
	end
	return true
end

--- Starts a move for fighter `f`. opts: { charge, forced, target }
function Combat.startMove(f, moveId: string, opts): boolean
	opts = opts or {}
	local move = Moves.get(moveId)
	if not move or (move.weapon ~= f.weapon) then
		return false
	end
	if not opts.forced then
		local ok = canAct(f, move)
		if not ok then
			return false
		end
	end
	local t = now()
	if move.cost then
		f.lumen -= if move.kind == "ult" then f.lumen else move.cost
	end
	if move.cd then
		f.cooldowns[move.id] = t + move.cd
	end
	if move.kind == "counter" then
		f.counterUntil = 0
	end
	f.moveSerial += 1
	local serial = f.moveSerial
	f.move = move
	f.moveStart = t
	f.state = "move"
	f.guarding = false
	setAttr(f, "Guard", false)
	setAttr(f, "State", "move")
	local charge = math.clamp(tonumber(opts.charge) or 0, 0, 1)
	-- tell every client to play it (the attacker's own client already is)
	f.model:SetAttribute("MoveId", move.id)
	f.model:SetAttribute("MoveT", t)
	f.model:SetAttribute("MoveSerial", serial)
	syncBars(f)

	-- face the nearest rival for NPCs (players face themselves on their own client)
	local target = opts.target or nearestTarget(f, 40)
	if not f.player and target then
		local look = (target.root.Position - f.root.Position) * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.1 then
			f.root.CFrame = CFrame.lookAt(f.root.Position, f.root.Position + look)
		end
	end

	if move.invuln then
		f.invulnUntil = t + move.invuln[2]
	end
	if move.armor then
		f.armorUntil = math.max(f.armorUntil, t + move.armor[2])
	end
	if move.buff then
		f.buffUntil = t + move.buff.dur
		f.buffPower = move.buff.power or 1
		f.armorUntil = math.max(f.armorUntil, t + (move.buff.armor or 0))
	end
	if move.stance then
		f.stance = { from = t + move.stance.t0, to = t + move.stance.t1, counter = move.stance.counter }
	end
	local function at(time: number, fn)
		task.delay(time, function()
			if f.moveSerial == serial and fighters[f.model] then
				fn()
			end
		end)
	end
	for _, h in move.hits or {} do
		at(h.t, function()
			resolveMelee(f, h, serial, charge)
		end)
	end
	for _, p in move.proj or {} do
		at(p.t, function()
			launchProjectile(f, p, serial, charge)
		end)
	end
	if move.beam then
		local b = move.beam
		for i = 1, b.ticks do
			at(b.t + (i - 1) * b.every, function()
				local facing = flatLook(f)
				for _, target2 in fighters do
					if hostile(f, target2) then
						local d = target2.root.Position - f.root.Position
						local along = d:Dot(facing)
						local sideways = (d - facing * along) * Vector3.new(1, 0, 1)
						if along > 0 and along < b.len and sideways.Magnitude < b.width + 2 and math.abs(d.Y) < 10 then
							local hit = table.clone(b)
							if i == b.ticks and b.finalKb then
								hit.kb = b.finalKb
								hit.heavy = true
							end
							applyHit(f, target2, hit, facing, target2.root.Position, charge)
						end
					end
				end
			end)
		end
	end
	if move.blink then
		at(move.blink.t, function()
			local target2 = opts.target or nearestTarget(f, move.blink.range or 40)
			if target2 then
				local behind = target2.root.Position - flatLook(target2) * 5
				local cf = CFrame.lookAt(behind, target2.root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, behind.Y, 0))
				if f.player then
					tell(f, "blink", { cf = cf })
				else
					f.model:PivotTo(cf)
				end
			end
		end)
	end
	if move.rain then
		local r = move.rain
		local count = math.floor((r.t1 - r.t0) / r.every)
		for i = 0, count do
			at(r.t0 + i * r.every, function()
				local centreTarget = nearestTarget(f, 60)
				local centre = if centreTarget then centreTarget.root.Position else f.root.Position + flatLook(f) * 12
				local spot = centre + Vector3.new(math.random(-r.radius, r.radius) * 0.6, 0, math.random(-r.radius, r.radius) * 0.6)
				fx({ kind = "spear", pos = spot, color = (Weapons.List[f.weapon]).color })
				for _, target2 in fighters do
					if hostile(f, target2) and (target2.root.Position - spot).Magnitude < 7 then
						applyHit(f, target2, r, Vector3.new(0, 0, 0), spot, nil)
					end
				end
			end)
		end
	end
	if move.orbit then
		local o = move.orbit
		local ticks = math.floor(o.dur / o.every)
		for i = 1, ticks do
			task.delay(o.t0 + i * o.every, function()
				if not fighters[f.model] then
					return
				end
				for _, target2 in fighters do
					if hostile(f, target2) and (target2.root.Position - f.root.Position).Magnitude < o.radius + 2.5 then
						local dir = (target2.root.Position - f.root.Position) * Vector3.new(1, 0, 1)
						applyHit(f, target2, o, if dir.Magnitude > 0.1 then dir.Unit else Vector3.zero, target2.root.Position, nil)
					end
				end
			end)
		end
	end
	if move.zone then
		local z = move.zone
		at(z.t, function()
			local centre = f.root.Position + flatLook(f) * (z.at or 0)
			local ticks = math.floor(z.dur / z.every)
			for i = 0, ticks do
				task.delay(i * z.every, function()
					for _, target2 in fighters do
						if hostile(f, target2) and (target2.root.Position - centre).Magnitude < z.radius + 2 then
							applyHit(f, target2, z, Vector3.zero, target2.root.Position, nil)
						end
					end
				end)
			end
		end)
	end
	-- NPCs move themselves on the server; players move on their own client
	if not f.player then
		for _, m in move.motion or {} do
			at(m.t0, function()
				local facing = flatLook(f)
				local fwd = m.fwd or 0
				if m.seek then
					local target2 = nearestTarget(f, 50)
					if target2 then
						local d = (target2.root.Position - f.root.Position) * Vector3.new(1, 0, 1)
						fwd = math.min(fwd, d.Magnitude / math.max(0.05, m.t1 - m.t0))
					end
				end
				push(f, facing * fwd + Vector3.new(0, m.up or 0, 0), math.max(0.05, m.t1 - m.t0), m.hoverHold)
			end)
		end
	end
	-- the move ends
	task.delay(move.dur, function()
		if f.moveSerial == serial and f.state == "move" then
			f.state = "idle"
			f.move = nil
			setAttr(f, "State", "idle")
		end
	end)
	return true
end

function Combat.dash(f, dir): boolean
	local t = now()
	if f.state == "down" or f.state == "ko" then
		return false
	end
	if f.state == "stun" and t < f.stunUntil then
		-- Break Away: spend Lumen to dash out of a combo
		if f.lumen < C.BreakAwayCost or f.model:GetAttribute("State") == "guardbreak" then
			return false
		end
		f.lumen -= C.BreakAwayCost
		f.stunUntil = t
		f.comboHits = 0
		fx({ kind = "burst", pos = f.root.Position, color = (Weapons.List[f.weapon] or Weapons.List.saber).color })
	end
	if t - f.lastDash < C.DashCooldown * 0.45 then
		return false
	end
	if f.move and f.state == "move" and t - f.moveStart < (f.move.cancel or 0) * 0.6 - 0.1 then
		return false -- dash-cancel only once the swing has landed
	end
	f.lastDash = t
	f.moveSerial += 1 -- cancels pending hits of the current move
	f.move = nil
	f.state = "idle"
	f.invulnUntil = t + C.DashInvuln
	f.guarding = false
	setAttr(f, "Guard", false)
	setAttr(f, "State", "dash")
	f.model:SetAttribute("DashT", t)
	if not f.player then
		local d = if dir and dir.Magnitude > 0.1 then dir.Unit else flatLook(f)
		push(f, d * C.DashSpeed, C.DashTime)
	end
	task.delay(C.DashTime, function()
		if f.model:GetAttribute("State") == "dash" then
			setAttr(f, "State", "idle")
		end
	end)
	return true
end

function Combat.setGuard(f, on: boolean)
	local t = now()
	if on then
		if f.state == "down" or f.state == "ko" or (f.state == "stun" and t < f.stunUntil) then
			return
		end
		if f.state == "move" and f.move and t - f.moveStart < f.move.cancel - 0.1 then
			return
		end
		f.move = nil
		f.state = "idle"
		f.moveSerial += 1
		f.guarding = true
		f.guardStart = t
	else
		f.guarding = false
	end
	setAttr(f, "Guard", f.guarding)
end

-- ---------------------------------------------------------------------------------------------
-- Ticking: recover from stun, regenerate guard
-- ---------------------------------------------------------------------------------------------
local function tick(dt: number)
	local t = now()
	for _, f in fighters do
		if f.state == "stun" and t >= f.stunUntil then
			f.state = "idle"
			setAttr(f, "State", "idle")
		elseif f.state == "down" and t >= f.downUntil and f.downUntil ~= math.huge then
			f.state = "stun"
			f.stunUntil = t + C.GetupTime
			f.invulnUntil = t + C.GetupTime + 0.2
			setAttr(f, "State", "getup")
		end
		if not f.guarding and f.guardMeter < 100 then
			f.guardMeter = math.min(100, f.guardMeter + dt * 14)
		end
		if f.stance and t > f.stance.to then
			f.stance = nil
		end
	end
	stepProjectiles(dt)
end

--- One simulation step (exposed so the offline duel simulation can drive the clock).
Combat.step = tick

-- slow attribute sync for regenerating bars
local function slowSync()
	while true do
		task.wait(0.5)
		for _, f in fighters do
			syncBars(f)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Requests from players
-- ---------------------------------------------------------------------------------------------
local lastRequest: { [Player]: number } = {}

local function onRequest(player: Player, action: any, a1: any, a2: any)
	local character = player.Character
	local f = character and fighters[character]
	if not f then
		return
	end
	local t = os.clock()
	if lastRequest[player] and t - lastRequest[player] < 0.05 then
		return
	end
	lastRequest[player] = t
	if action == "move" and type(a1) == "string" then
		local ok = Combat.startMove(f, a1, { charge = if type(a2) == "number" then a2 else 0 })
		if not ok then
			tell(f, "reject", { move = a1 })
		end
	elseif action == "dash" then
		local argType = typeof(a1)
		Combat.dash(f, if argType == "Vector3" then a1 else nil)
	elseif action == "guard" then
		Combat.setGuard(f, a1 == true)
	end
end

function Combat.start(remoteFolder: Folder)
	remotes = remoteFolder
	local function ensure(className: string, name: string)
		local r = remotes:FindFirstChild(name)
		if not r then
			r = Instance.new(className)
			r.Name = name
			r.Parent = remotes
		end
		return r
	end
	Fx = ensure("RemoteEvent", "Fx")
	CombatRemote = ensure("RemoteEvent", "Combat")
	CombatRemote.OnServerEvent:Connect(onRequest)
	RunService.Heartbeat:Connect(tick)
	task.spawn(slowSync)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Combat
