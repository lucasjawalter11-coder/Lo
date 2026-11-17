--!nonstrict
-- Animator: drives every fighter's joints on this client from the shared move data. It layers on top of
-- Roblox's own walk and idle animations: moves, guards and hit reactions take the whole body; the weapon
-- stance only takes the arms and torso so walking still looks natural.
-- The local player's moves start instantly (predicted); everyone else's start from replicated attributes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Moves = require(Shared:WaitForChild("Moves"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Config = require(Shared:WaitForChild("Config"))

local Animator = {}

local player = Players.LocalPlayer
local Fx
local records: { [Model]: any } = {}

local REACTION = {
	stun = "stun", launched = "launched", down = "down", ko = "down", getup = "getup", guardbreak = "guardBreak", victory = "victory",
}
local UPPER = { Waist = true, Neck = true, RightShoulder = true, RightElbow = true, LeftShoulder = true, LeftElbow = true }

local function motorsOf(model: Model)
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	return motors
end

local function ensureTrails(rec)
	local weaponFolder = rec.model:FindFirstChild("HalcyonWeapon")
	if weaponFolder == rec.weaponFolder then
		return
	end
	rec.weaponFolder = weaponFolder
	rec.trails = {}
	if not weaponFolder then
		return
	end
	local def = Weapons.List[weaponFolder:GetAttribute("Weapon") or "saber"] or Weapons.List.saber
	for _, m in weaponFolder:GetChildren() do
		local handle = m:IsA("Model") and m.PrimaryPart
		local a0 = handle and handle:FindFirstChild("TrailBase")
		local a1 = handle and handle:FindFirstChild("TrailTip")
		if a0 and a1 then
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.16
			trail.MinLength = 0.05
			trail.LightEmission = 1
			trail.Color = ColorSequence.new(Color3.new(1, 1, 1), def.color)
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
			trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
			trail.Enabled = false
			trail.Parent = handle
			table.insert(rec.trails, trail)
		end
	end
end

local function track(model: Model)
	if records[model] or not model:FindFirstChild("HumanoidRootPart") then
		return
	end
	local rec = {
		model = model, motors = motorsOf(model), current = {}, weight = 0, move = nil, t = 0, serial = model:GetAttribute("MoveSerial") or 0,
		fired = {}, stopUntil = 0, localGuard = nil, dashUntil = 0, walk = 0,
		hasAnimate = model:FindFirstChild("Animate") ~= nil, trails = {}, weaponFolder = nil, localStart = 0,
	}
	records[model] = rec
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			records[model] = nil
		end
	end)
end

local function startMove(rec, move, elapsed: number)
	rec.move = move
	rec.t = math.max(0, elapsed)
	rec.fired = {}
	ensureTrails(rec)
	if move.sfx then
		Fx.sound(move.sfx, rec.model:FindFirstChild("HumanoidRootPart") and rec.model.HumanoidRootPart.Position)
	end
end

--- Plays a move on the local player's character straight away (the server confirms it moments later).
function Animator.play(model: Model, moveId: string)
	track(model)
	local rec = records[model]
	local move = Moves.get(moveId)
	if rec and move then
		startMove(rec, move, 0)
		rec.localStart = os.clock()
	end
end

function Animator.stop(model: Model)
	local rec = records[model]
	if rec then
		rec.move = nil
	end
end

function Animator.setGuard(model: Model, on: boolean?)
	track(model)
	local rec = records[model]
	if rec then
		rec.localGuard = on
	end
end

function Animator.dash(model: Model)
	track(model)
	local rec = records[model]
	if rec then
		rec.move = nil
		rec.dashUntil = os.clock() + Config.Combat.DashTime
	end
end

function Animator.current(model: Model)
	local rec = records[model]
	return rec and rec.move, rec and rec.t or 0
end

local function poll()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, child in Workspace:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Duel_" then
			for _, d in child:GetChildren() do
				if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
					table.insert(list, d)
				end
			end
		end
	end
	for _, m in list do
		if m:GetAttribute("Fighter") then
			track(m)
		end
	end
end

local function step(dt: number)
	local nowClock = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	for model, rec in records do
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		if not next(rec.motors) then
			rec.motors = motorsOf(model)
		end
		-- a move started on the server (or confirmed for our own prediction)
		local serial = model:GetAttribute("MoveSerial") or 0
		if serial ~= rec.serial then
			rec.serial = serial
			local id = model:GetAttribute("MoveId")
			local move = id and Moves.get(id)
			local mine = model == player.Character
			if move and not (mine and rec.move == move and nowClock - rec.localStart < 0.6) then
				startMove(rec, move, math.clamp(serverNow - (model:GetAttribute("MoveT") or serverNow), 0, 0.25))
			end
		end
		-- advance the move clock, frozen during hit-stop
		if rec.move and nowClock >= rec.stopUntil then
			rec.t += dt
		end
		local move = rec.move
		if move and rec.t > move.dur + 0.15 then
			rec.move = nil
			move = nil
		end
		local state = model:GetAttribute("State")
		if move and (state == "stun" or state == "down" or state == "launched" or state == "ko" or state == "guardbreak") then
			rec.move = nil
			move = nil
		end
		-- slashes, effects and trails along the move's timeline
		local trailsOn = false
		if move then
			for i, s in move.slash or {} do
				if not rec.fired["s" .. i] and rec.t >= s.t then
					rec.fired["s" .. i] = true
					Fx.slash(root.CFrame, s)
				end
				if rec.t >= s.t - 0.06 and rec.t <= s.t + (s.dur or 0.1) + 0.06 then
					trailsOn = true
				end
			end
			for i, h in move.hits or {} do
				if rec.t >= h.t - 0.1 and rec.t <= h.t + 0.08 then
					trailsOn = true
				end
				local _ = i
			end
			for i, e in move.fx or {} do
				if not rec.fired["f" .. i] and rec.t >= e.t then
					rec.fired["f" .. i] = true
					Fx.moveFx(model, e)
				end
			end
		end
		ensureTrails(rec)
		for _, trail in rec.trails do
			trail.Enabled = trailsOn
		end

		-- choose the pose for this frame
		local family = Moves.Family[model:GetAttribute("Weapon") or "saber"] or Moves.Family.saber
		local guard = if rec.localGuard ~= nil and model == player.Character then rec.localGuard else model:GetAttribute("Guard")
		local target, weight, upperOnly
		local reaction = state and REACTION[state]
		if reaction then
			target, weight = Moves.Reactions[reaction], 1
		elseif nowClock < rec.dashUntil or state == "dash" then
			target, weight = Moves.Reactions.dash, 1
		elseif move then
			target = Moves.sample(move, rec.t)
			weight = if rec.t > move.dur then math.max(0, 1 - (rec.t - move.dur) / 0.15) else 1
		elseif guard then
			target, weight = family.guard, 1
		else
			local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			target = family.ready
			weight = if speed > 3 then 0.45 else 0.8
			upperOnly = rec.hasAnimate or speed > 3
		end
		local follow = 1 - math.exp(-dt * 28)
		for joint, cf in target do
			local motor = rec.motors[joint]
			if motor and (not upperOnly or UPPER[joint]) then
				local cur = rec.current[joint] or cf
				cur = cur:Lerp(cf, follow)
				rec.current[joint] = cur
				motor.Transform = motor.Transform:Lerp(cur, weight)
			end
		end
		-- NPC duelists have no walk animation of their own: swing the legs while they move
		if not rec.hasAnimate and upperOnly then
			local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			rec.walk += dt * speed * 0.55
			local s = math.sin(rec.walk)
			local legs = {
				RightHip = CFrame.Angles(math.rad(-35 * s), 0, 0), LeftHip = CFrame.Angles(math.rad(35 * s), 0, 0),
				RightKnee = CFrame.Angles(math.rad(-25 - 20 * math.max(0, s)), 0, 0), LeftKnee = CFrame.Angles(math.rad(-25 - 20 * math.max(0, -s)), 0, 0),
			}
			for joint, cf in legs do
				local motor = rec.motors[joint]
				if motor then
					motor.Transform = cf
				end
			end
		end
	end
end

function Animator.init(fx)
	Fx = fx
	Fx.onHitStop = function(attacker, victim, stop)
		for _, m in { attacker, victim } do
			local rec = m and records[m]
			if rec then
				rec.stopUntil = os.clock() + stop
			end
		end
	end
	local event = RunService.PreSimulation
	event:Connect(step)
	task.spawn(function()
		while true do
			poll()
			task.wait(0.5)
		end
	end)
end

return Animator
