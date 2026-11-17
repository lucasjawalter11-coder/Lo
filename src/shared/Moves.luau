--!nonstrict
-- Moves: every attack, skill and ultimate, shared by the server (timing, hitboxes, damage) and the client
-- (procedural animation, slash arcs, effects). Times are in seconds from the start of the move.
--
-- Poses are built from a few readable numbers per limb:
--   arm = { yaw, pitch, bend, twist }  yaw: + swings the arm out to its own side, - across the body
--                                      pitch: -90 hanging, 0 straight ahead, +90 straight up
--                                      bend: elbow bend (forearm forward)
--   waist = { lean, turn, tilt }      lean: + back, - forward;  turn: + toward the left
--   legs = a preset name from LEGS
-- Weapons run along the forearm, so the arm aims the weapon.
local Config = require(script.Parent.Config)
local hex = Config.hex

local Moves = {}

local rad = math.rad
local function rot(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

Moves.Joints = { "Root", "Waist", "Neck", "RightShoulder", "RightElbow", "LeftShoulder", "LeftElbow", "RightHip", "RightKnee", "LeftHip", "LeftKnee" }
Moves.ArmJoints = { RightShoulder = true, RightElbow = true, LeftShoulder = true, LeftElbow = true, Waist = true, Neck = true }

local LEGS = {
	stance = { rh = { -6, 0, 4 }, rk = -10, lh = { 14, 0, -4 }, lk = -18, dy = -0.15 },
	wide = { rh = { -14, 0, 12 }, rk = -22, lh = { 24, 0, -12 }, lk = -32, dy = -0.5 },
	lunge = { rh = { -32, 0, 4 }, rk = -8, lh = { 50, 0, -4 }, lk = -52, dy = -0.75 },
	crouch = { rh = { 30, 0, 10 }, rk = -62, lh = { 42, 0, -10 }, lk = -72, dy = -1.15 },
	air = { rh = { 52, 0, 8 }, rk = -92, lh = { 70, 0, -8 }, lk = -104, dy = 0 },
	rise = { rh = { 8, 0, 4 }, rk = -18, lh = { 62, 0, -4 }, lk = -92, dy = 0.15 },
	run = { rh = { -40, 0, 0 }, rk = -30, lh = { 55, 0, 0 }, lk = -60, dy = -0.4 },
	down = { rh = { 10, 0, 6 }, rk = -10, lh = { 30, 0, -6 }, lk = -40, dy = 0 },
}

local function arm(side: string, a): (CFrame, CFrame)
	local yaw, pitch, bend, twist = a[1] or 0, a[2] or -90, a[3] or 0, a[4] or 0
	local s = if side == "R" then -1 else 1
	local shoulder = CFrame.Angles(0, rad(yaw * s), 0) * CFrame.Angles(rad(90 + pitch), 0, 0) * CFrame.Angles(0, rad(twist * s), 0)
	return shoulder, CFrame.Angles(rad(bend), 0, 0)
end

--- Builds a pose (joint name -> CFrame) from a readable spec.
function Moves.pose(spec): { [string]: CFrame }
	local p = {}
	local r = spec.r or { 10, -80, 10 }
	local l = spec.l
	if l == "two" then
		-- the left hand follows the right one onto the shaft
		l = { -(r[1] or 0) - 18, (r[2] or -90) - 8, (r[3] or 0) + 38 }
	end
	l = l or { 10, -80, 10 }
	p.RightShoulder, p.RightElbow = arm("R", r)
	p.LeftShoulder, p.LeftElbow = arm("L", l)
	local w = spec.waist or { 0, 0, 0 }
	p.Waist = rot(w[1], w[2], w[3])
	local n = spec.neck or { 0, -(w[2] or 0) * 0.6, 0 }
	p.Neck = rot(n[1], n[2], n[3])
	local legs = if type(spec.legs) == "table" then spec.legs else LEGS[spec.legs or "stance"]
	p.RightHip = rot(legs.rh[1], legs.rh[2], legs.rh[3])
	p.RightKnee = rot(legs.rk)
	p.LeftHip = rot(legs.lh[1], legs.lh[2], legs.lh[3])
	p.LeftKnee = rot(legs.lk)
	local root = spec.root or { 0, 0, 0 }
	p.Root = CFrame.new(0, (legs.dy or 0) + (root[4] or 0), 0) * rot(root[1], root[2], root[3])
	return p
end

local P = Moves.pose

-- ---------------------------------------------------------------------------------------------
-- Pose families
-- ---------------------------------------------------------------------------------------------
local FAM = {}

FAM.blade = {
	ready = P({ r = { 25, -38, 78 }, l = { 12, -58, 40 }, waist = { 0, -14, 0 }, legs = "stance" }),
	windR = P({ r = { 100, 4, 26 }, l = { -12, -42, 64 }, waist = { 0, -42, 0 }, legs = "stance" }),
	cutL = P({ r = { -78, -6, 8 }, l = { 34, -52, 28 }, waist = { 0, 40, 0 }, legs = "lunge" }),
	windL = P({ r = { -84, 16, 52 }, l = { 22, -46, 40 }, waist = { 0, 42, 0 }, legs = "stance" }),
	cutR = P({ r = { 98, -12, 6 }, l = { 12, -58, 30 }, waist = { 0, -40, 0 }, legs = "lunge" }),
	low = P({ r = { 42, -78, 8 }, l = { -12, -40, 52 }, waist = { -22, -26, 0 }, legs = "crouch" }),
	high = P({ r = { -18, 74, 4 }, l = { 22, -22, 40 }, waist = { 14, 26, 0 }, legs = "rise" }),
	up = P({ r = { 10, 150, 40 }, l = { 4, 118, 64 }, waist = { 16, 0, 0 }, legs = "stance" }),
	slam = P({ r = { 6, -58, 0 }, l = { -10, -62, 22 }, waist = { -30, 0, 0 }, legs = "lunge" }),
	thrustWind = P({ r = { 42, 0, 132 }, l = { -22, -20, 82 }, waist = { 0, -48, 0 }, legs = "wide" }),
	thrust = P({ r = { 0, 0, 0 }, l = { 62, -30, 20 }, waist = { -6, 16, 0 }, legs = "lunge" }),
	guard = P({ r = { -40, 20, 100, 30 }, l = { 30, -30, 92 }, waist = { -6, -10, 0 }, legs = "wide" }),
}
FAM.pole = {
	ready = P({ r = { 18, -22, 58 }, l = "two", waist = { 0, -26, 0 }, legs = "wide" }),
	windR = P({ r = { 112, 0, 42 }, l = "two", waist = { 0, -56, 0 }, legs = "wide" }),
	cutL = P({ r = { -82, -10, 14 }, l = "two", waist = { 0, 52, 0 }, legs = "lunge" }),
	windL = P({ r = { -72, 12, 52 }, l = "two", waist = { 0, 46, 0 }, legs = "wide" }),
	cutR = P({ r = { 102, -14, 14 }, l = "two", waist = { 0, -48, 0 }, legs = "lunge" }),
	low = P({ r = { 32, -72, 20 }, l = "two", waist = { -20, -20, 0 }, legs = "crouch" }),
	high = P({ r = { 0, 82, 8 }, l = "two", waist = { 14, 18, 0 }, legs = "rise" }),
	up = P({ r = { 0, 160, 30 }, l = "two", waist = { 18, 0, 0 }, legs = "wide" }),
	slam = P({ r = { 0, -42, 0 }, l = "two", waist = { -32, 0, 0 }, legs = "lunge" }),
	thrustWind = P({ r = { 32, -6, 122 }, l = "two", waist = { 0, -52, 0 }, legs = "wide" }),
	thrust = P({ r = { 4, -2, 0 }, l = "two", waist = { -4, 10, 0 }, legs = "lunge" }),
	guard = P({ r = { -30, 30, 90, 40 }, l = { 30, 20, 90 }, waist = { -4, -6, 0 }, legs = "wide" }),
}
FAM.heavy = {
	ready = P({ r = { 30, -40, 70 }, l = "two", waist = { 0, -30, 0 }, legs = "wide" }),
	windR = P({ r = { 130, 18, 40 }, l = "two", waist = { 6, -72, 0 }, legs = "wide" }),
	cutL = P({ r = { -88, -14, 10 }, l = "two", waist = { -10, 60, 0 }, legs = "lunge" }),
	windL = P({ r = { -86, 20, 60 }, l = "two", waist = { 4, 58, 0 }, legs = "wide" }),
	cutR = P({ r = { 110, -18, 12 }, l = "two", waist = { -10, -62, 0 }, legs = "lunge" }),
	low = P({ r = { 40, -80, 30 }, l = "two", waist = { -26, -30, 0 }, legs = "crouch" }),
	high = P({ r = { 0, 90, 10 }, l = "two", waist = { 18, 20, 0 }, legs = "rise" }),
	up = P({ r = { 0, 172, 36 }, l = "two", waist = { 24, 0, 0 }, legs = "wide" }),
	slam = P({ r = { 0, -70, 0 }, l = "two", waist = { -38, 0, 0 }, legs = "crouch" }),
	thrustWind = P({ r = { 60, -10, 120 }, l = "two", waist = { 0, -62, 0 }, legs = "wide" }),
	thrust = P({ r = { 6, -6, 4 }, l = "two", waist = { -10, 14, 0 }, legs = "lunge" }),
	guard = P({ r = { -20, 20, 70, 60 }, l = { 30, 10, 90 }, waist = { -8, -8, 0 }, legs = "wide" }),
}
FAM.guns = {
	ready = P({ r = { 22, -28, 30 }, l = { 22, -28, 30 }, waist = { 0, 0, 0 }, legs = "stance" }),
	aimR = P({ r = { -4, 0, 0 }, l = { 30, -46, 52 }, waist = { 0, -12, 0 }, legs = "stance" }),
	aimL = P({ l = { -4, 0, 0 }, r = { 30, -46, 52 }, waist = { 0, 12, 0 }, legs = "stance" }),
	aimBoth = P({ r = { -6, 2, 0 }, l = { -6, 2, 0 }, waist = { -4, 0, 0 }, legs = "wide" }),
	spread = P({ r = { 55, 0, 0 }, l = { 55, 0, 0 }, waist = { 6, 0, 0 }, legs = "wide" }),
	upward = P({ r = { -4, 70, 0 }, l = { -4, 70, 0 }, waist = { 16, 0, 0 }, legs = "rise" }),
	downward = P({ r = { -4, -55, 0 }, l = { -4, -55, 0 }, waist = { -20, 0, 0 }, legs = "air" }),
	behind = P({ r = { 160, 0, 0 }, l = { 160, 0, 0 }, waist = { 0, 0, 0 }, legs = "stance" }),
	guard = P({ r = { -44, 6, 96 }, l = { -44, 6, 96 }, waist = { -8, 0, 0 }, legs = "wide" }),
}
FAM.discs = {
	ready = P({ r = { 46, -32, 44 }, l = { 46, -32, 44 }, waist = { 0, 0, 0 }, legs = "stance" }),
	windR = P({ r = { 116, 10, 86 }, l = { 20, -40, 50 }, waist = { 0, -46, 0 }, legs = "stance" }),
	throwR = P({ r = { -34, 2, 0 }, l = { 30, -46, 40 }, waist = { 0, 36, 0 }, legs = "lunge" }),
	windL = P({ l = { 116, 10, 86 }, r = { 20, -40, 50 }, waist = { 0, 46, 0 }, legs = "stance" }),
	throwL = P({ l = { -34, 2, 0 }, r = { 30, -46, 40 }, waist = { 0, -36, 0 }, legs = "lunge" }),
	windBoth = P({ r = { 100, 20, 90 }, l = { 100, 20, 90 }, waist = { 10, 0, 0 }, legs = "wide" }),
	throwBoth = P({ r = { 6, 0, 0 }, l = { 6, 0, 0 }, waist = { -10, 0, 0 }, legs = "lunge" }),
	spin = P({ r = { 88, -4, 0 }, l = { 88, -4, 0 }, waist = { 0, 0, 0 }, legs = "wide" }),
	up = P({ r = { 30, 120, 10 }, l = { 30, 120, 10 }, waist = { 12, 0, 0 }, legs = "rise" }),
	guard = P({ r = { -36, 10, 96 }, l = { -36, 10, 96 }, waist = { -8, 0, 0 }, legs = "wide" }),
}

-- Shared reaction poses
Moves.Reactions = {
	stun = P({ r = { 40, -50, 24 }, l = { 40, -50, 24 }, waist = { 22, 8, 0 }, neck = { 24, 0, 0 }, legs = "stance" }),
	stunAlt = P({ r = { 30, -40, 40 }, l = { 50, -60, 10 }, waist = { 18, -14, 6 }, neck = { 18, 10, 0 }, legs = "wide" }),
	launched = P({ r = { 60, 40, 30 }, l = { 60, 40, 30 }, waist = { 30, 0, 0 }, neck = { 30, 0, 0 }, legs = "air" }),
	down = P({ r = { 70, -10, 20 }, l = { 70, -10, 20 }, waist = { 10, 0, 0 }, legs = "down", root = { 80, 0, 0, -2.3 } }),
	getup = P({ r = { 20, -80, 10 }, l = { 20, -80, 10 }, waist = { -30, 0, 0 }, legs = "crouch" }),
	dash = P({ r = { 6, -128, 10 }, l = { 6, -128, 10 }, waist = { -26, 0, 0 }, neck = { -10, 0, 0 }, legs = "run" }),
	guardBreak = P({ r = { 70, 60, 20 }, l = { 70, 60, 20 }, waist = { 26, 0, 0 }, neck = { 20, 0, 0 }, legs = "wide" }),
	victory = P({ r = { 10, 150, 10 }, l = { 30, -60, 40 }, waist = { 8, 0, 0 }, neck = { 10, 0, 0 }, legs = "stance" }),
}

-- ---------------------------------------------------------------------------------------------
-- Move building helpers
-- ---------------------------------------------------------------------------------------------
local function lights(F, prefix: string, k, color: Color3)
	-- k: { reach, dmg, speed, arc, family } tuning for a melee weapon's basic chain
	local s = 1 / k.speed
	local function t(x: number): number
		return x * s
	end
	local out = {}
	out[prefix .. "_l1"] = {
		kind = "light", chain = 1, name = "First Cut", dur = t(0.4), cancel = t(0.22),
		keys = { { 0, F.ready }, { t(0.07), F.windR }, { t(0.17), F.cutL }, { t(0.3), F.cutL }, { t(0.4), F.ready } },
		hits = { { t = t(0.13), reach = k.reach, arc = k.arc, dmg = k.dmg, stun = 0.38, kb = 8 } },
		motion = { { t0 = t(0.05), t1 = t(0.17), fwd = 26 } },
		slash = { { t = t(0.09), dur = t(0.1), a0 = 80, a1 = -95, tilt = 8, r = k.reach * 0.75, color = color } },
		sfx = "Swing",
	}
	out[prefix .. "_l2"] = {
		kind = "light", chain = 2, name = "Return Cut", dur = t(0.4), cancel = t(0.22),
		keys = { { 0, F.cutL }, { t(0.07), F.windL }, { t(0.17), F.cutR }, { t(0.3), F.cutR }, { t(0.4), F.ready } },
		hits = { { t = t(0.13), reach = k.reach, arc = k.arc, dmg = k.dmg * 1.05, stun = 0.38, kb = 8 } },
		motion = { { t0 = t(0.05), t1 = t(0.17), fwd = 24 } },
		slash = { { t = t(0.09), dur = t(0.1), a0 = -80, a1 = 95, tilt = -14, r = k.reach * 0.75, color = color } },
		sfx = "Swing",
	}
	out[prefix .. "_l3"] = {
		kind = "light", chain = 3, name = "Rising Edge", dur = t(0.44), cancel = t(0.26),
		keys = { { 0, F.cutR }, { t(0.08), F.low }, { t(0.19), F.high }, { t(0.32), F.high }, { t(0.44), F.ready } },
		hits = { { t = t(0.15), reach = k.reach, arc = 100, dmg = k.dmg * 1.1, stun = 0.5, kb = 6, up = 22 } },
		motion = { { t0 = t(0.06), t1 = t(0.18), fwd = 20 } },
		slash = { { t = t(0.11), dur = t(0.1), a0 = -70, a1 = 80, tilt = 70, r = k.reach * 0.7, color = color } },
		sfx = "Swing",
	}
	out[prefix .. "_l4"] = {
		kind = "light", chain = 4, name = "Breaker", dur = t(0.62), cancel = t(0.42),
		keys = { { 0, F.high }, { t(0.12), F.up }, { t(0.24), F.slam }, { t(0.46), F.slam }, { t(0.62), F.ready } },
		hits = { { t = t(0.22), reach = k.reach + 1, arc = 100, dmg = k.dmg * 1.7, stun = 0.7, kb = 40, down = true, heavy = true } },
		motion = { { t0 = t(0.12), t1 = t(0.24), fwd = 34 } },
		slash = { { t = t(0.16), dur = t(0.1), a0 = 150, a1 = -40, tilt = 90, r = k.reach * 0.8, color = color } },
		fx = { { t = t(0.23), kind = "quake", r = 9, color = color } },
		sfx = "Heavy",
	}
	out[prefix .. "_heavy"] = {
		kind = "heavy", name = "Piercing Charge", dur = t(0.62), cancel = t(0.44), charge = true,
		keys = { { 0, F.thrustWind }, { t(0.14), F.thrustWind }, { t(0.22), F.thrust }, { t(0.48), F.thrust }, { t(0.62), F.ready } },
		hits = { { t = t(0.2), reach = k.reach + 3, arc = 50, dmg = k.dmg * 1.6, stun = 0.6, kb = 34, heavy = true, chargeDmg = 0.9, chargeBreak = 0.9 } },
		motion = { { t0 = t(0.15), t1 = t(0.3), fwd = 52 } },
		fx = { { t = t(0.2), kind = "pierce", len = k.reach + 4, color = color } },
		sfx = "Lunge",
	}
	out[prefix .. "_launch"] = {
		kind = "launcher", name = "Skyward", dur = t(0.5), cancel = t(0.3),
		keys = { { 0, F.low }, { t(0.1), F.low }, { t(0.2), F.high }, { t(0.38), F.high }, { t(0.5), F.ready } },
		hits = { { t = t(0.17), reach = k.reach, arc = 110, dmg = k.dmg * 1.2, stun = 1.1, launch = 58, kb = 4 } },
		slash = { { t = t(0.13), dur = t(0.1), a0 = -60, a1 = 120, tilt = 90, r = k.reach * 0.75, color = color } },
		fx = { { t = t(0.18), kind = "pillar", color = color } },
		sfx = "Swing",
	}
	out[prefix .. "_dash"] = {
		kind = "dashAttack", name = "Flash Cut", dur = t(0.42), cancel = t(0.26),
		keys = { { 0, F.thrustWind }, { t(0.06), F.thrust }, { t(0.28), F.thrust }, { t(0.42), F.ready } },
		hits = { { t = t(0.1), reach = k.reach + 2, arc = 70, dmg = k.dmg * 1.25, stun = 0.5, kb = 22 } },
		motion = { { t0 = 0, t1 = t(0.2), fwd = 64 } },
		fx = { { t = 0.02, kind = "afterimage", color = color } },
		sfx = "Lunge",
	}
	local airLegs = function(pose)
		local copy = table.clone(pose)
		local air = P({ legs = "air" })
		for _, j in { "RightHip", "RightKnee", "LeftHip", "LeftKnee", "Root" } do
			copy[j] = air[j]
		end
		return copy
	end
	out[prefix .. "_a1"] = {
		kind = "air", chain = 1, name = "Sky Cut", dur = t(0.36), cancel = t(0.2), hover = true,
		keys = { { 0, airLegs(F.ready) }, { t(0.06), airLegs(F.windR) }, { t(0.15), airLegs(F.cutL) }, { t(0.36), airLegs(F.cutL) } },
		hits = { { t = t(0.12), reach = k.reach, arc = 150, dmg = k.dmg * 0.9, stun = 0.6, kb = 4, float = true } },
		slash = { { t = t(0.08), dur = t(0.1), a0 = 80, a1 = -95, tilt = 20, r = k.reach * 0.75, color = color } },
		sfx = "Swing",
	}
	out[prefix .. "_a2"] = {
		kind = "air", chain = 2, name = "Sky Return", dur = t(0.36), cancel = t(0.2), hover = true,
		keys = { { 0, airLegs(F.cutL) }, { t(0.06), airLegs(F.windL) }, { t(0.15), airLegs(F.cutR) }, { t(0.36), airLegs(F.cutR) } },
		hits = { { t = t(0.12), reach = k.reach, arc = 150, dmg = k.dmg * 0.95, stun = 0.6, kb = 4, float = true } },
		slash = { { t = t(0.08), dur = t(0.1), a0 = -80, a1 = 95, tilt = -20, r = k.reach * 0.75, color = color } },
		sfx = "Swing",
	}
	out[prefix .. "_a3"] = {
		kind = "air", chain = 3, name = "Meteor Spike", dur = t(0.5), cancel = t(0.34), hover = true,
		keys = { { 0, airLegs(F.high) }, { t(0.1), airLegs(F.up) }, { t(0.2), airLegs(F.slam) }, { t(0.5), airLegs(F.slam) } },
		hits = { { t = t(0.18), reach = k.reach + 1, arc = 110, dmg = k.dmg * 1.5, stun = 0.8, kb = 10, up = -80, down = true, heavy = true } },
		slash = { { t = t(0.13), dur = t(0.1), a0 = 150, a1 = -60, tilt = 90, r = k.reach * 0.8, color = color } },
		sfx = "Heavy",
	}
	out[prefix .. "_plunge"] = {
		kind = "airHeavy", name = "Plunge", dur = t(0.6), cancel = t(0.46),
		keys = { { 0, airLegs(F.up) }, { t(0.12), airLegs(F.up) }, { t(0.3), F.slam }, { t(0.6), F.ready } },
		hits = { { t = t(0.3), reach = 10, arc = 360, dmg = k.dmg * 1.5, stun = 0.7, kb = 26, up = 18, heavy = true } },
		motion = { { t0 = t(0.1), t1 = t(0.3), fwd = 10, up = -110 } },
		fx = { { t = t(0.3), kind = "quake", r = 11, color = color } },
		sfx = "Heavy",
	}
	out[prefix .. "_counter"] = {
		kind = "counter", name = "Riposte", dur = t(0.52), cancel = t(0.36), invuln = { 0, t(0.3) },
		keys = {
			{ 0, F.windR },
			{ t(0.1), Moves.with(F.cutL, { Root = CFrame.new(0, -0.6, 0) * rot(0, -120, 0) }) },
			{ t(0.2), Moves.with(F.cutL, { Root = CFrame.new(0, -0.6, 0) * rot(0, -240, 0) }) },
			{ t(0.3), Moves.with(F.cutL, { Root = CFrame.new(0, -0.6, 0) * rot(0, -359, 0) }) },
			{ t(0.52), F.ready },
		},
		hits = { { t = t(0.14), reach = 9, arc = 360, dmg = k.dmg * 1.2, stun = 0.6, kb = 10, crit = true }, { t = t(0.27), reach = 9, arc = 360, dmg = k.dmg * 1.2, stun = 0.6, kb = 30, crit = true } },
		slash = { { t = t(0.06), dur = t(0.26), a0 = 0, a1 = 360, tilt = 0, r = 8, color = color } },
		sfx = "Swing",
	}
	return out
end

--- Copy of a pose with some joints replaced.
function Moves.with(pose, overrides)
	local copy = table.clone(pose)
	for k, v in overrides do
		copy[k] = v
	end
	return copy
end

--- Keys for `turns` full spins between t0 and t1, in 120-degree steps so blending never turns back.
local function spinKeys(pose, t0: number, t1: number, turns: number, dy: number?)
	local keys = {}
	local steps = turns * 3
	for i = 1, steps do
		local angle = -120 * i
		if i % 3 == 0 then
			angle = -359.9 + (i / 3 - 1) * 0 -- a full turn lands back facing forward
		end
		local t = t0 + (t1 - t0) * i / steps
		table.insert(keys, { t, Moves.with(pose, { Root = CFrame.new(0, dy or -0.4, 0) * rot(0, angle % -360, 0) }) })
	end
	return keys
end
Moves.spinKeys = spinKeys

local function concat(...)
	local out = {}
	for _, list in { ... } do
		for _, v in list do
			table.insert(out, v)
		end
	end
	return out
end

local function merge(into, from)
	for k, v in from do
		into[k] = v
	end
end

-- ---------------------------------------------------------------------------------------------
-- The move list
-- ---------------------------------------------------------------------------------------------
local L = {}

-- ===== Lumen Saber =====
do
	local F, c = FAM.blade, hex(0x6fe6ff)
	merge(L, lights(F, "saber", { reach = 7.5, dmg = 40, speed = 1.12, arc = 150 }, c))
	L.saber_s1 = {
		kind = "skill", slot = 1, name = "Comet Step", cost = 20, cd = 5, dur = 0.55, cancel = 0.42, invuln = { 0, 0.34 },
		desc = "Dash straight through your rival, cutting as you pass.",
		keys = { { 0, F.thrustWind }, { 0.08, F.cutL }, { 0.4, F.cutL }, { 0.55, F.ready } },
		motion = { { t0 = 0.06, t1 = 0.3, fwd = 120 } },
		hits = { { t = 0.16, reach = 9, arc = 360, dmg = 95, stun = 0.7, kb = 10, up = 14 } },
		fx = { { t = 0.05, kind = "afterimage", color = c }, { t = 0.06, kind = "streak", len = 34, color = c } },
		sfx = "Dash",
	}
	L.saber_s2 = {
		kind = "skill", slot = 2, name = "Frost Crescent", cost = 25, cd = 6, dur = 0.5, cancel = 0.34,
		desc = "Send a crescent of frost-light flying forward.",
		keys = { { 0, F.ready }, { 0.08, F.windR }, { 0.18, F.cutL }, { 0.5, F.ready } },
		proj = { { t = 0.16, kind = "wave", speed = 120, range = 80, radius = 4.5, dmg = 75, stun = 0.6, kb = 18, pierce = true } },
		slash = { { t = 0.11, dur = 0.1, a0 = 80, a1 = -95, tilt = 8, r = 6, color = c } },
		sfx = "Swing",
	}
	L.saber_s3 = {
		kind = "skill", slot = 3, name = "Glacier Parry", cost = 15, cd = 8, dur = 0.8, cancel = 0.8,
		desc = "A counter stance. Anything that hits you in the next moment is answered with a flurry.",
		keys = { { 0, F.guard }, { 0.75, F.guard }, { 0.8, F.ready } },
		stance = { t0 = 0.04, t1 = 0.75, counter = "saber_s3x" },
		fx = { { t = 0.02, kind = "aura", color = c, dur = 0.75 } },
		sfx = "Draw",
	}
	L.saber_s3x = {
		kind = "followup", name = "Glacier Flurry", dur = 0.9, cancel = 0.7, invuln = { 0, 0.8 },
		keys = { { 0, F.windR }, { 0.1, F.cutL }, { 0.2, F.windL }, { 0.3, F.cutR }, { 0.42, F.low }, { 0.55, F.high }, { 0.9, F.ready } },
		hits = {
			{ t = 0.1, reach = 9, arc = 200, dmg = 30, stun = 0.5, kb = 2, crit = true },
			{ t = 0.28, reach = 9, arc = 200, dmg = 30, stun = 0.5, kb = 2, crit = true },
			{ t = 0.52, reach = 9, arc = 200, dmg = 60, stun = 1.0, launch = 50, crit = true },
		},
		slash = { { t = 0.05, dur = 0.1, a0 = 80, a1 = -95, tilt = 8, r = 6, color = c }, { t = 0.24, dur = 0.1, a0 = -80, a1 = 95, tilt = -14, r = 6, color = c }, { t = 0.46, dur = 0.1, a0 = -60, a1 = 120, tilt = 90, r = 6, color = c } },
		sfx = "Swing",
	}
	L.saber_ult = {
		kind = "ult", name = "Skyfall Requiem", cost = 100, cd = 1, dur = 2.1, cancel = 2.0, invuln = { 0, 2.0 },
		desc = "Vanish into a storm of cuts from every angle, then fall like a blade from the sky.",
		keys = { { 0, F.up }, { 0.2, F.up }, { 0.35, F.cutL }, { 0.6, F.cutR }, { 0.85, F.cutL }, { 1.1, F.cutR }, { 1.35, F.up }, { 1.6, F.slam }, { 2.1, F.ready } },
		hits = {
			{ t = 0.4, reach = 12, arc = 360, dmg = 28, stun = 0.8, float = true },
			{ t = 0.6, reach = 12, arc = 360, dmg = 28, stun = 0.8, float = true },
			{ t = 0.8, reach = 12, arc = 360, dmg = 28, stun = 0.8, float = true },
			{ t = 1.0, reach = 12, arc = 360, dmg = 28, stun = 0.8, float = true },
			{ t = 1.2, reach = 12, arc = 360, dmg = 28, stun = 0.8, float = true },
			{ t = 1.62, reach = 14, arc = 360, dmg = 170, stun = 1.2, kb = 50, down = true, heavy = true, crit = true },
		},
		fx = { { t = 0, kind = "ultStart", color = c }, { t = 0.35, kind = "storm", dur = 1.0, color = c }, { t = 1.62, kind = "quake", r = 16, color = c } },
		sfx = "Ult",
	}
end

-- ===== Solar Lance =====
do
	local F, c = FAM.pole, hex(0xffb62e)
	merge(L, lights(F, "lance", { reach = 10.5, dmg = 41, speed = 1.0, arc = 120 }, c))
	L.lance_s1 = {
		kind = "skill", slot = 1, name = "Sunpiercer", cost = 20, cd = 5, dur = 0.7, cancel = 0.5,
		desc = "A long charging lunge that breaks through any guard.",
		keys = { { 0, F.thrustWind }, { 0.16, F.thrustWind }, { 0.24, F.thrust }, { 0.55, F.thrust }, { 0.7, F.ready } },
		motion = { { t0 = 0.18, t1 = 0.4, fwd = 95 } },
		hits = { { t = 0.3, reach = 13, arc = 50, dmg = 105, stun = 0.8, kb = 40, guardBreak = true, heavy = true } },
		fx = { { t = 0.18, kind = "streak", len = 30, color = c }, { t = 0.3, kind = "pierce", len = 16, color = c } },
		sfx = "Lunge",
	}
	L.lance_s2 = {
		kind = "skill", slot = 2, name = "Wheel of Dawn", cost = 25, cd = 7, dur = 0.8, cancel = 0.6,
		desc = "Spin the lance around you twice, sweeping everyone close.",
		keys = concat({ { 0, F.windR } }, spinKeys(F.cutL, 0, 0.6, 2, -0.5), { { 0.8, F.ready } }),
		hits = { { t = 0.2, reach = 12, arc = 360, dmg = 45, stun = 0.6, kb = 6 }, { t = 0.5, reach = 12, arc = 360, dmg = 55, stun = 0.7, kb = 30 } },
		slash = { { t = 0.08, dur = 0.5, a0 = 0, a1 = 720, tilt = 0, r = 11, color = c } },
		sfx = "Swing",
	}
	L.lance_s3 = {
		kind = "skill", slot = 3, name = "Pole Vault", cost = 25, cd = 8, dur = 0.95, cancel = 0.75, invuln = { 0.05, 0.45 },
		desc = "Vault high over your rival and come down lance-first.",
		keys = { { 0, F.low }, { 0.15, P({ r = { 0, 170, 20 }, l = "two", waist = { 20, 0, 0 }, legs = "air" }) }, { 0.5, P({ r = { 0, 170, 20 }, l = "two", legs = "air" }) }, { 0.62, F.slam }, { 0.95, F.ready } },
		motion = { { t0 = 0.08, t1 = 0.45, fwd = 30, up = 70 }, { t0 = 0.5, t1 = 0.62, fwd = 20, up = -150 } },
		hits = { { t = 0.62, reach = 11, arc = 360, dmg = 110, stun = 0.9, kb = 30, up = 20, heavy = true } },
		fx = { { t = 0.62, kind = "quake", r = 12, color = c } },
		sfx = "Heavy",
	}
	L.lance_ult = {
		kind = "ult", name = "Helios Rain", cost = 100, cd = 1, dur = 2.2, cancel = 2.1, invuln = { 0, 2.1 },
		desc = "Leap above the ring and call down a rain of sun-spears.",
		keys = { { 0, F.low }, { 0.25, P({ r = { 0, 170, 0 }, l = { 0, 170, 0 }, legs = "air" }) }, { 1.6, P({ r = { 0, 170, 0 }, l = { 0, 170, 0 }, legs = "air" }) }, { 1.85, F.slam }, { 2.2, F.ready } },
		motion = { { t0 = 0.05, t1 = 0.3, up = 90 }, { t0 = 0.3, t1 = 1.6, hoverHold = true }, { t0 = 1.6, t1 = 1.85, up = -160 } },
		rain = { t0 = 0.45, t1 = 1.55, every = 0.1, radius = 18, dmg = 22, stun = 0.6 },
		hits = { { t = 1.85, reach = 16, arc = 360, dmg = 150, stun = 1.2, kb = 45, down = true, heavy = true, crit = true } },
		fx = { { t = 0, kind = "ultStart", color = c }, { t = 0.45, kind = "rain", dur = 1.1, r = 18, color = c }, { t = 1.85, kind = "quake", r = 18, color = c } },
		sfx = "Ult",
	}
end

-- ===== Ember Maul =====
do
	local F, c = FAM.heavy, hex(0xff5a2a)
	merge(L, lights(F, "maul", { reach = 8.5, dmg = 56, speed = 0.82, arc = 140 }, c))
	for _, id in { "maul_l1", "maul_l2", "maul_l3", "maul_l4", "maul_heavy" } do
		L[id].armor = { 0.05, L[id].hits[1].t } -- the maul does not flinch mid-swing
	end
	L.maul_s1 = {
		kind = "skill", slot = 1, name = "Faultline", cost = 20, cd = 6, dur = 0.8, cancel = 0.6, armor = { 0, 0.4 },
		desc = "Split the floor: a shockwave races along the ground ahead of you.",
		keys = { { 0, F.ready }, { 0.18, F.up }, { 0.34, F.slam }, { 0.8, F.ready } },
		proj = { { t = 0.34, kind = "quakeline", speed = 90, range = 60, radius = 6, dmg = 90, stun = 0.8, up = 34, pierce = true, ground = true } },
		fx = { { t = 0.34, kind = "quake", r = 8, color = c } },
		sfx = "Heavy",
	}
	L.maul_s2 = {
		kind = "skill", slot = 2, name = "Iron Will", cost = 25, cd = 10, dur = 0.6, cancel = 0.6, armor = { 0, 0.6 },
		desc = "Brace yourself: for four seconds nothing makes you flinch, and you hit 25% harder.",
		keys = { { 0, F.ready }, { 0.2, P({ r = { 60, 30, 100 }, l = { 60, 30, 100 }, waist = { 10, 0, 0 }, legs = "wide" }) }, { 0.6, F.ready } },
		buff = { armor = 4, power = 1.25, dur = 4 },
		fx = { { t = 0.1, kind = "aura", color = c, dur = 4 } },
		sfx = "Draw",
	}
	L.maul_s3 = {
		kind = "skill", slot = 3, name = "Comet Drop", cost = 30, cd = 9, dur = 1.0, cancel = 0.8, armor = { 0, 1.0 },
		desc = "Leap up and crash down on your rival's head.",
		keys = { { 0, F.low }, { 0.2, Moves.with(F.up, P({ legs = "air" })) }, { 0.6, Moves.with(F.up, P({ legs = "air" })) }, { 0.7, F.slam }, { 1.0, F.ready } },
		motion = { { t0 = 0.1, t1 = 0.5, fwd = 40, up = 80, seek = true }, { t0 = 0.55, t1 = 0.7, up = -170 } },
		hits = { { t = 0.7, reach = 14, arc = 360, dmg = 130, stun = 1.0, kb = 30, up = 30, heavy = true, guardBreak = true } },
		fx = { { t = 0.7, kind = "quake", r = 15, color = c } },
		sfx = "Heavy",
	}
	L.maul_ult = {
		kind = "ult", name = "Meteor Verdict", cost = 100, cd = 1, dur = 2.0, cancel = 1.9, invuln = { 0, 1.9 },
		desc = "Rise on a pillar of fire and bring the maul down like a falling star.",
		keys = { { 0, F.low }, { 0.3, Moves.with(F.up, P({ legs = "air" })) }, { 1.2, Moves.with(F.up, P({ legs = "air" })) }, { 1.45, F.slam }, { 2.0, F.ready } },
		motion = { { t0 = 0.1, t1 = 0.6, up = 70, seek = true }, { t0 = 0.6, t1 = 1.2, hoverHold = true }, { t0 = 1.25, t1 = 1.45, up = -200 } },
		hits = {
			{ t = 0.25, reach = 10, arc = 360, dmg = 40, stun = 1.0, launch = 50 },
			{ t = 1.45, reach = 20, arc = 360, dmg = 220, stun = 1.4, kb = 60, down = true, heavy = true, crit = true },
		},
		fx = { { t = 0, kind = "ultStart", color = c }, { t = 0.1, kind = "pillar", color = c }, { t = 1.45, kind = "quake", r = 22, color = c } },
		sfx = "Ult",
	}
end

-- ===== Twin Pistols =====
do
	local F, c = FAM.guns, hex(0xe14bff)
	local function shot(t, from, dmg, extra)
		local s = { t = t, kind = "bolt", speed = 190, range = 110, radius = 1.8, dmg = dmg, stun = 0.15, kb = 2, from = from }
		if extra then
			for k, v in extra do
				s[k] = v
			end
		end
		return s
	end
	L.pistols_l1 = { kind = "light", chain = 1, name = "Quick Draw", dur = 0.34, cancel = 0.2, keys = { { 0, F.ready }, { 0.05, F.aimR }, { 0.2, F.aimR }, { 0.28, F.ready } }, proj = { shot(0.06, "R", 24) }, sfx = "Shot" }
	L.pistols_l2 = { kind = "light", chain = 2, name = "Off Hand", dur = 0.34, cancel = 0.2, keys = { { 0, F.aimR }, { 0.05, F.aimL }, { 0.2, F.aimL }, { 0.28, F.ready } }, proj = { shot(0.06, "L", 24) }, sfx = "Shot" }
	L.pistols_l3 = { kind = "light", chain = 3, name = "Double Tap", dur = 0.38, cancel = 0.22, keys = { { 0, F.aimL }, { 0.05, F.aimBoth }, { 0.24, F.aimBoth }, { 0.32, F.ready } }, proj = { shot(0.06, "R", 18), shot(0.12, "L", 18) }, sfx = "Shot" }
	L.pistols_l4 = {
		kind = "light", chain = 4, name = "Point Blank", dur = 0.5, cancel = 0.32,
		keys = { { 0, F.aimBoth }, { 0.08, F.aimBoth }, { 0.2, F.spread }, { 0.5, F.ready } },
		hits = { { t = 0.1, reach = 9, arc = 90, dmg = 60, stun = 0.6, kb = 36, down = true, heavy = true } },
		motion = { { t0 = 0.1, t1 = 0.25, fwd = -40 } },
		fx = { { t = 0.1, kind = "blast", r = 7, color = c } },
		sfx = "Heavy",
	}
	L.pistols_heavy = {
		kind = "heavy", name = "Charge Shot", dur = 0.5, cancel = 0.3, charge = true,
		keys = { { 0, F.aimBoth }, { 0.12, F.aimBoth }, { 0.2, Moves.with(F.aimBoth, { Waist = rot(14, 0, 0) }) }, { 0.5, F.ready } },
		proj = { shot(0.12, "R", 70, { kind = "orb", speed = 150, radius = 3.2, pierce = true, stun = 0.7, kb = 30, heavy = true, chargeDmg = 1.0, chargeBreak = 0.9 }) },
		sfx = "Shot",
	}
	L.pistols_launch = {
		kind = "launcher", name = "Uppercut Blast", dur = 0.48, cancel = 0.3,
		keys = { { 0, F.aimBoth }, { 0.08, F.downward }, { 0.18, F.upward }, { 0.48, F.ready } },
		hits = { { t = 0.16, reach = 9, arc = 100, dmg = 44, stun = 1.1, launch = 58 } },
		fx = { { t = 0.16, kind = "pillar", color = c } },
		sfx = "Shot",
	}
	L.pistols_dash = {
		kind = "dashAttack", name = "Slide Fire", dur = 0.42, cancel = 0.26,
		keys = { { 0, Moves.with(F.aimBoth, P({ legs = "run" })) }, { 0.3, Moves.with(F.aimBoth, P({ legs = "run" })) }, { 0.42, F.ready } },
		motion = { { t0 = 0, t1 = 0.25, fwd = 50 } },
		proj = { shot(0.05, "R", 18, { spread = 8 }), shot(0.12, "L", 18, { spread = -8 }), shot(0.19, "R", 18) },
		sfx = "Shot",
	}
	L.pistols_a1 = { kind = "air", chain = 1, name = "Sky Shot", dur = 0.3, cancel = 0.15, hover = true, keys = { { 0, Moves.with(F.aimR, P({ legs = "air" })) }, { 0.3, Moves.with(F.aimR, P({ legs = "air" })) } }, proj = { shot(0.05, "R", 22, { pitch = -12 }) }, sfx = "Shot" }
	L.pistols_a2 = { kind = "air", chain = 2, name = "Sky Shot", dur = 0.3, cancel = 0.15, hover = true, keys = { { 0, Moves.with(F.aimL, P({ legs = "air" })) }, { 0.3, Moves.with(F.aimL, P({ legs = "air" })) } }, proj = { shot(0.05, "L", 22, { pitch = -12 }) }, sfx = "Shot" }
	L.pistols_a3 = {
		kind = "air", chain = 3, name = "Downpour", dur = 0.45, cancel = 0.3, hover = true,
		keys = { { 0, F.downward }, { 0.45, F.downward } },
		proj = { shot(0.06, "R", 20, { pitch = -45, spread = 10 }), shot(0.1, "L", 20, { pitch = -45, spread = -10 }), shot(0.16, "R", 26, { pitch = -50, down = true, kb = 10, up = -60 }) },
		sfx = "Shot",
	}
	L.pistols_plunge = {
		kind = "airHeavy", name = "Rain of Bolts", dur = 0.6, cancel = 0.45, hover = true,
		keys = { { 0, F.downward }, { 0.6, F.downward } },
		proj = { shot(0.08, "R", 16, { pitch = -70, spread = 20 }), shot(0.12, "L", 16, { pitch = -70, spread = -20 }), shot(0.16, "R", 16, { pitch = -70, spread = 0 }), shot(0.2, "L", 16, { pitch = -70, spread = 40 }), shot(0.24, "R", 16, { pitch = -70, spread = -40 }) },
		sfx = "Shot",
	}
	L.pistols_counter = {
		kind = "counter", name = "Mirror Shot", dur = 0.45, cancel = 0.3, invuln = { 0, 0.25 },
		keys = { { 0, F.aimBoth }, { 0.08, F.spread }, { 0.45, F.ready } },
		hits = { { t = 0.08, reach = 9, arc = 360, dmg = 70, stun = 0.8, kb = 34, crit = true } },
		fx = { { t = 0.08, kind = "blast", r = 9, color = c } },
		sfx = "Heavy",
	}
	L.pistols_s1 = {
		kind = "skill", slot = 1, name = "Scatter Vault", cost = 20, cd = 5, dur = 0.7, cancel = 0.5, invuln = { 0, 0.35 },
		desc = "Backflip out of reach and answer with a fan of five bolts.",
		keys = { { 0, F.ready }, { 0.12, Moves.with(F.spread, { Root = CFrame.new(0, 1, 0) * rot(-180, 0, 0) }) }, { 0.28, Moves.with(F.aimBoth, { Root = CFrame.new(0, 0.5, 0) * rot(-359, 0, 0) }) }, { 0.7, F.ready } },
		motion = { { t0 = 0, t1 = 0.28, fwd = -60, up = 40 } },
		proj = { shot(0.3, "R", 26, { spread = -24 }), shot(0.3, "L", 26, { spread = -12 }), shot(0.3, "R", 26, { spread = 0 }), shot(0.3, "L", 26, { spread = 12 }), shot(0.3, "R", 26, { spread = 24 }) },
		sfx = "Shot",
	}
	L.pistols_s2 = {
		kind = "skill", slot = 2, name = "Railspike", cost = 25, cd = 7, dur = 0.8, cancel = 0.6,
		desc = "Brace and fire one piercing rail of light straight through everything.",
		keys = { { 0, F.aimBoth }, { 0.3, F.aimBoth }, { 0.38, Moves.with(F.aimBoth, { Waist = rot(18, 0, 0) }) }, { 0.8, F.ready } },
		beam = { t = 0.32, len = 90, width = 3.5, ticks = 1, every = 0, dmg = 120, stun = 0.9, kb = 40, guardBreak = true },
		fx = { { t = 0.05, kind = "charge", dur = 0.27, color = c }, { t = 0.32, kind = "beam", len = 90, width = 3, dur = 0.25, color = c } },
		sfx = "Shot",
	}
	L.pistols_s3 = {
		kind = "skill", slot = 3, name = "Bullet Dance", cost = 30, cd = 8, dur = 1.0, cancel = 0.8,
		desc = "Spin on the spot firing in every direction.",
		keys = {
			{ 0, F.spread },
			{ 0.2, Moves.with(F.spread, { Root = CFrame.new(0, -0.3, 0) * rot(0, -120, 0) }) },
			{ 0.4, Moves.with(F.spread, { Root = CFrame.new(0, -0.3, 0) * rot(0, -240, 0) }) },
			{ 0.6, Moves.with(F.spread, { Root = CFrame.new(0, -0.3, 0) * rot(0, -359, 0) }) },
			{ 1.0, F.ready },
		},
		hits = { { t = 0.15, reach = 26, arc = 360, dmg = 24, stun = 0.5, kb = 4 }, { t = 0.35, reach = 26, arc = 360, dmg = 24, stun = 0.5, kb = 4 }, { t = 0.55, reach = 26, arc = 360, dmg = 34, stun = 0.7, kb = 20 } },
		fx = { { t = 0.05, kind = "spray", dur = 0.6, r = 26, color = c } },
		sfx = "Shot",
	}
	L.pistols_ult = {
		kind = "ult", name = "Starline Overdrive", cost = 100, cd = 1, dur = 2.2, cancel = 2.1, invuln = { 0, 2.1 },
		desc = "Lock both pistols together and pour out a beam that tears through the ring.",
		keys = { { 0, F.aimBoth }, { 0.5, Moves.with(F.aimBoth, { Waist = rot(10, 0, 0) }) }, { 1.9, Moves.with(F.aimBoth, { Waist = rot(16, 0, 0) }) }, { 2.2, F.ready } },
		beam = { t = 0.5, len = 110, width = 7, ticks = 12, every = 0.11, dmg = 24, stun = 0.4, kb = 4, finalKb = 50 },
		fx = { { t = 0, kind = "ultStart", color = c }, { t = 0.05, kind = "charge", dur = 0.45, color = c }, { t = 0.5, kind = "beam", len = 110, width = 7, dur = 1.35, color = c } },
		sfx = "Ult",
	}
end

-- ===== Eclipse Scythe (unique) =====
do
	local F, c = FAM.pole, hex(0xb06bff)
	merge(L, lights(F, "scythe", { reach = 9.5, dmg = 44, speed = 0.96, arc = 200 }, c))
	L.scythe_s1 = {
		kind = "skill", slot = 1, name = "Reaping Hook", cost = 20, cd = 6, dur = 0.7, cancel = 0.5,
		desc = "Fling a hooked arc of shadow that drags your rival right up to you.",
		keys = { { 0, F.windR }, { 0.14, F.cutL }, { 0.5, F.cutL }, { 0.7, F.ready } },
		proj = { { t = 0.16, kind = "hook", speed = 110, range = 55, radius = 3.5, dmg = 50, stun = 1.0, pull = true } },
		slash = { { t = 0.1, dur = 0.1, a0 = 100, a1 = -100, tilt = 8, r = 9, color = c } },
		sfx = "Swing",
	}
	L.scythe_s2 = {
		kind = "skill", slot = 2, name = "Moon Cyclone", cost = 25, cd = 7, dur = 1.1, cancel = 0.85, armor = { 0, 0.9 },
		desc = "Become a spinning crescent and drift forward, cutting four times.",
		keys = concat({ { 0, F.windR } }, spinKeys(F.cutL, 0.05, 0.85, 3, -0.4), { { 1.1, F.ready } }),
		motion = { { t0 = 0.1, t1 = 0.85, fwd = 24 } },
		hits = {
			{ t = 0.2, reach = 11, arc = 360, dmg = 30, stun = 0.5, kb = 2 }, { t = 0.4, reach = 11, arc = 360, dmg = 30, stun = 0.5, kb = 2 },
			{ t = 0.6, reach = 11, arc = 360, dmg = 30, stun = 0.5, kb = 2 }, { t = 0.8, reach = 11, arc = 360, dmg = 45, stun = 0.8, kb = 30 },
		},
		slash = { { t = 0.1, dur = 0.75, a0 = 0, a1 = 1080, tilt = 6, r = 10, color = c } },
		sfx = "Swing",
	}
	L.scythe_s3 = {
		kind = "skill", slot = 3, name = "Phase Step", cost = 30, cd = 9, dur = 0.7, cancel = 0.5, invuln = { 0, 0.3 },
		desc = "Slip through the shadows and appear behind your rival, scythe already swinging.",
		keys = { { 0, F.ready }, { 0.18, F.windR }, { 0.3, F.cutL }, { 0.7, F.ready } },
		blink = { t = 0.16, behind = true, range = 40 },
		hits = { { t = 0.3, reach = 10, arc = 200, dmg = 95, stun = 0.8, kb = 24, crit = true } },
		slash = { { t = 0.22, dur = 0.1, a0 = 100, a1 = -100, tilt = 8, r = 9, color = c } },
		fx = { { t = 0.05, kind = "vanish", color = c }, { t = 0.17, kind = "vanish", color = c } },
		sfx = "Dash",
	}
	L.scythe_ult = {
		kind = "ult", name = "Black Eclipse", cost = 100, cd = 1, dur = 2.3, cancel = 2.2, invuln = { 0, 2.2 },
		desc = "Raise a dome of night around you. Inside it, the scythe cuts from everywhere at once.",
		keys = { { 0, F.up }, { 0.4, F.up }, { 0.6, F.cutL }, { 0.9, F.cutR }, { 1.2, F.cutL }, { 1.5, F.cutR }, { 1.8, F.slam }, { 2.3, F.ready } },
		hits = {
			{ t = 0.6, reach = 20, arc = 360, dmg = 30, stun = 0.9 }, { t = 0.85, reach = 20, arc = 360, dmg = 30, stun = 0.9 },
			{ t = 1.1, reach = 20, arc = 360, dmg = 30, stun = 0.9 }, { t = 1.35, reach = 20, arc = 360, dmg = 30, stun = 0.9 },
			{ t = 1.85, reach = 20, arc = 360, dmg = 160, stun = 1.3, kb = 45, down = true, heavy = true, crit = true },
		},
		fx = { { t = 0, kind = "ultStart", color = c }, { t = 0.4, kind = "dome", r = 20, dur = 1.6, color = c }, { t = 0.6, kind = "storm", dur = 1.2, color = c } },
		sfx = "Ult",
	}
end

-- ===== Orbit Discs (unique) =====
do
	local F, c = FAM.discs, hex(0x7dff7a)
	local function disc(t, from, dmg, extra)
		local s = { t = t, kind = "disc", speed = 110, range = 30, radius = 2.6, dmg = dmg, stun = 0.4, kb = 4, from = from, boomerang = true, pierce = true }
		if extra then
			for k, v in extra do
				s[k] = v
			end
		end
		return s
	end
	L.discs_l1 = { kind = "light", chain = 1, name = "Toss", dur = 0.34, cancel = 0.18, keys = { { 0, F.ready }, { 0.06, F.windR }, { 0.14, F.throwR }, { 0.34, F.ready } }, proj = { disc(0.12, "R", 22) }, sfx = "Swing" }
	L.discs_l2 = { kind = "light", chain = 2, name = "Return Toss", dur = 0.34, cancel = 0.18, keys = { { 0, F.throwR }, { 0.06, F.windL }, { 0.14, F.throwL }, { 0.34, F.ready } }, proj = { disc(0.12, "L", 22) }, sfx = "Swing" }
	L.discs_l3 = { kind = "light", chain = 3, name = "Cross Toss", dur = 0.4, cancel = 0.22, keys = { { 0, F.throwL }, { 0.08, F.windBoth }, { 0.18, F.throwBoth }, { 0.4, F.ready } }, proj = { disc(0.16, "R", 18, { spread = 14 }), disc(0.16, "L", 18, { spread = -14 }) }, sfx = "Swing" }
	L.discs_l4 = {
		kind = "light", chain = 4, name = "Ring Spin", dur = 0.55, cancel = 0.36,
		keys = concat({ { 0, F.spin } }, spinKeys(F.spin, 0, 0.27, 1, -0.4), { { 0.55, F.ready } }),
		hits = { { t = 0.2, reach = 9, arc = 360, dmg = 64, stun = 0.7, kb = 34, down = true, heavy = true } },
		slash = { { t = 0.05, dur = 0.22, a0 = 0, a1 = 360, tilt = 0, r = 8, color = c } },
		sfx = "Heavy",
	}
	L.discs_heavy = {
		kind = "heavy", name = "Full Orbit", dur = 0.55, cancel = 0.35, charge = true,
		keys = { { 0, F.windBoth }, { 0.14, F.windBoth }, { 0.22, F.throwBoth }, { 0.55, F.ready } },
		proj = { disc(0.2, "R", 55, { range = 44, radius = 4, stun = 0.7, kb = 26, heavy = true, chargeDmg = 0.9 }) },
		sfx = "Swing",
	}
	L.discs_launch = {
		kind = "launcher", name = "Updraft", dur = 0.5, cancel = 0.3,
		keys = concat({ { 0, F.spin } }, spinKeys(F.spin, 0, 0.18, 1, 0), { { 0.3, F.up }, { 0.5, F.ready } }),
		hits = { { t = 0.18, reach = 9, arc = 360, dmg = 44, stun = 1.1, launch = 58 } },
		fx = { { t = 0.18, kind = "pillar", color = c } },
		sfx = "Swing",
	}
	L.discs_dash = {
		kind = "dashAttack", name = "Skid Throw", dur = 0.42, cancel = 0.26,
		keys = { { 0, Moves.with(F.windR, P({ legs = "run" })) }, { 0.1, Moves.with(F.throwR, P({ legs = "run" })) }, { 0.42, F.ready } },
		motion = { { t0 = 0, t1 = 0.22, fwd = 55 } },
		proj = { disc(0.1, "R", 30, { range = 36 }) },
		sfx = "Swing",
	}
	L.discs_a1 = { kind = "air", chain = 1, name = "Sky Toss", dur = 0.34, cancel = 0.18, hover = true, keys = { { 0, Moves.with(F.windR, P({ legs = "air" })) }, { 0.12, Moves.with(F.throwR, P({ legs = "air" })) }, { 0.34, Moves.with(F.throwR, P({ legs = "air" })) } }, proj = { disc(0.1, "R", 20, { pitch = -15 }) }, sfx = "Swing" }
	L.discs_a2 = { kind = "air", chain = 2, name = "Sky Toss", dur = 0.34, cancel = 0.18, hover = true, keys = { { 0, Moves.with(F.windL, P({ legs = "air" })) }, { 0.12, Moves.with(F.throwL, P({ legs = "air" })) }, { 0.34, Moves.with(F.throwL, P({ legs = "air" })) } }, proj = { disc(0.1, "L", 20, { pitch = -15 }) }, sfx = "Swing" }
	L.discs_a3 = {
		kind = "air", chain = 3, name = "Halo Drop", dur = 0.5, cancel = 0.34, hover = true,
		keys = concat({ { 0, Moves.with(F.spin, P({ legs = "air" })) } }, spinKeys(Moves.with(F.spin, P({ legs = "air" })), 0, 0.24, 1, 0), { { 0.5, F.spin } }),
		hits = { { t = 0.18, reach = 9, arc = 360, dmg = 50, stun = 0.8, kb = 8, up = -80, down = true, heavy = true } },
		slash = { { t = 0.05, dur = 0.2, a0 = 0, a1 = 360, tilt = 0, r = 8, color = c } },
		sfx = "Heavy",
	}
	L.discs_plunge = {
		kind = "airHeavy", name = "Saturn Fall", dur = 0.6, cancel = 0.46,
		keys = { { 0, Moves.with(F.up, P({ legs = "air" })) }, { 0.3, F.spin }, { 0.6, F.ready } },
		motion = { { t0 = 0.1, t1 = 0.3, up = -110 } },
		hits = { { t = 0.3, reach = 11, arc = 360, dmg = 62, stun = 0.7, kb = 26, up = 18, heavy = true } },
		fx = { { t = 0.3, kind = "ring", r = 12, color = c } },
		sfx = "Heavy",
	}
	L.discs_counter = {
		kind = "counter", name = "Deflection", dur = 0.5, cancel = 0.34, invuln = { 0, 0.3 },
		keys = concat({ { 0, F.spin } }, spinKeys(F.spin, 0, 0.27, 1, -0.4), { { 0.5, F.ready } }),
		hits = { { t = 0.12, reach = 9, arc = 360, dmg = 70, stun = 0.8, kb = 32, crit = true } },
		slash = { { t = 0.03, dur = 0.22, a0 = 0, a1 = 360, tilt = 0, r = 8, color = c } },
		sfx = "Swing",
	}
	L.discs_s1 = {
		kind = "skill", slot = 1, name = "Ricochet", cost = 20, cd = 5, dur = 0.6, cancel = 0.4,
		desc = "A disc that flies far, hits on the way out and again on the way back.",
		keys = { { 0, F.windR }, { 0.14, F.throwR }, { 0.6, F.ready } },
		proj = { disc(0.12, "R", 45, { range = 60, speed = 130, radius = 3.2, stun = 0.7, kb = 10 }) },
		sfx = "Swing",
	}
	L.discs_s2 = {
		kind = "skill", slot = 2, name = "Orbit Shield", cost = 25, cd = 9, dur = 0.4, cancel = 0.4,
		desc = "Your discs circle you for four seconds, cutting anyone who comes close.",
		keys = { { 0, F.ready }, { 0.15, F.spread or F.spin }, { 0.4, F.ready } },
		orbit = { t0 = 0.15, dur = 4, radius = 7, every = 0.4, dmg = 18, stun = 0.35, kb = 8 },
		fx = { { t = 0.15, kind = "orbit", r = 7, dur = 4, color = c } },
		sfx = "Draw",
	}
	L.discs_s3 = {
		kind = "skill", slot = 3, name = "Twin Snare", cost = 30, cd = 10, dur = 0.6, cancel = 0.45,
		desc = "Pin the floor ahead with both discs. Anyone inside is held in place for a moment.",
		keys = { { 0, F.windBoth }, { 0.18, F.throwBoth }, { 0.6, F.ready } },
		zone = { t = 0.3, at = 16, radius = 10, dur = 2.5, every = 0.5, dmg = 12, stun = 0.55 },
		fx = { { t = 0.3, kind = "snare", at = 16, r = 10, dur = 2.5, color = c } },
		sfx = "Swing",
	}
	L.discs_ult = {
		kind = "ult", name = "Saturn Ring", cost = 100, cd = 1, dur = 2.0, cancel = 1.9, invuln = { 0, 1.9 },
		desc = "Spin both discs into a giant ring of light that sweeps the whole ring.",
		keys = concat({ { 0, F.up }, { 0.4, F.spin } }, spinKeys(F.spin, 0.4, 1.6, 4, -0.4), { { 2.0, F.ready } }),
		hits = {
			{ t = 0.5, reach = 24, arc = 360, dmg = 30, stun = 0.9, float = true }, { t = 0.8, reach = 24, arc = 360, dmg = 30, stun = 0.9, float = true },
			{ t = 1.1, reach = 24, arc = 360, dmg = 30, stun = 0.9, float = true }, { t = 1.6, reach = 26, arc = 360, dmg = 150, stun = 1.3, launch = 60, heavy = true, crit = true },
		},
		fx = { { t = 0, kind = "ultStart", color = c }, { t = 0.4, kind = "ring", r = 24, dur = 1.2, color = c }, { t = 1.6, kind = "ring", r = 30, color = c } },
		sfx = "Ult",
	}
end

for id, move in L do
	move.id = id
	move.weapon = string.match(id, "^(%a+)_")
end
Moves.List = L

--- The move id a fighter with `weapon` uses for a given role ("l1", "heavy", "s2", "ult", ...).
function Moves.idFor(weapon: string, role: string): string
	return weapon .. "_" .. role
end

function Moves.get(id: string)
	return L[id]
end

--- The family of idle/guard poses a weapon uses.
Moves.Family = { saber = FAM.blade, lance = FAM.pole, maul = FAM.heavy, pistols = FAM.guns, scythe = FAM.pole, discs = FAM.discs }

--- Pose of `move` at time t (seconds), blending between keys with smoothstep easing.
function Moves.sample(move, t: number): { [string]: CFrame }
	local keys = move.keys
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 1, #keys - 1 do
		local k0, k1 = keys[i], keys[i + 1]
		if t <= k1[1] then
			local span = k1[1] - k0[1]
			local a = if span > 0 then (t - k0[1]) / span else 1
			a = a * a * (3 - 2 * a)
			local out = {}
			for joint, cf in k0[2] do
				local other = k1[2][joint]
				out[joint] = if other then cf:Lerp(other, a) else cf
			end
			for joint, cf in k1[2] do
				if not out[joint] then
					out[joint] = cf
				end
			end
			return out
		end
	end
	return keys[#keys][2]
end

-- Skill slots each weapon shows on the HUD
function Moves.skillsOf(weapon: string)
	return { L[weapon .. "_s1"], L[weapon .. "_s2"], L[weapon .. "_s3"], L[weapon .. "_ult"] }
end

return Moves
