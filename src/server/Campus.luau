--!nonstrict
-- Campus: the Halcyon Concourse, a floating island shared by the four academies.
--
-- A hexagonal man-made island city (2700 studs across) on a wide lake. Nothing floats.
-- The land between the districts is filled with neighbourhoods, woods, parks, fields and courts.
-- The map is nine islands on a lake, joined by bridges:
--   centre      the Crown Plaza: the Halcyon Spire carrying the Sky Arena, and a monorail loop
--   diagonals   the four school districts (SE Solcrest, NE Northwind, NW Ironreach, SW Arcline). Each is a
--               whole town: a Register plaza with the school's twelve seats, an arrival station, a training
--               hall, a shop street, gardens, city blocks, and the campus and tower on the far side
--   cardinals   four city districts between the schools: downtown grid, shops, plazas, canals
-- Inside a district its local +Z points at the map centre. Within a district (the old single-map layout):
--   centre      the Register Plaza: the spire, the Register boards and the ring of twelve seats
--   south       the Skydock, where students arrive
--   east        the Training Hall
--   north       the Crown Arena and the Crown Gate
--   west        the Market Arcade
--   diagonals   the four school campuses, each on its own walled land 600+ studs out
--               (SE Solcrest, NE Northwind, NW Ironreach, SW Arcline)
--   far west    Halcyon City, down the city road
-- Angles below use: position = (sin a, cos a) * radius, so 0 = south, 90 = east, 180 = north, 270 = west.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Roster = require(Shared:WaitForChild("Roster"))
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)
local Arena = require(script.Parent.Arena)
local Weapons = require(Shared:WaitForChild("Weapons"))

local M = Enum.Material
local Pal = Props.Pal
local hex = Kit.hex

local Campus = {}

Campus.IslandRadius = 520 -- radius of the central hub area
Campus.CampusGate = Config.Map.CampusGate -- distance from a school's plaza to its campus gate
Campus.PlazaRadius = 124
Campus.SkyArenaY = 820 -- height of the Sky Arena floor on top of the central tower
Campus.SkyArenaScale = 1.5 -- the Sky Arena is half again as big as a duel arena

-- Where each default seat-holder stands on the plaza ring (degrees). Rookies stand near the Skydock,
-- the Crownbearer stands in front of the Crown Arena.
local SEAT_ANGLES = { 195, 165, 225, 135, 255, 105, 285, 75, 315, 45, 345, 15 }

local DIAGONALS = { [45] = "solcrest", [135] = "northwind", [225] = "ironreach", [315] = "arcline" }

local function polar(aDeg: number, r: number): (number, number)
	local a = math.rad(aDeg)
	return math.sin(a) * r, math.cos(a) * r
end

-- ---------------------------------------------------------------------------------------------
-- Regions: the nine islands
-- ---------------------------------------------------------------------------------------------
local RING = Config.Map.SchoolRing
local REGIONS = {
	{ tag = "centre", kind = "centre", angle = 0, dist = 0, R = 900, title = "Crown Plaza", accent = Pal.gold, seed = 101 },
}
for _, id in Config.AcademyOrder do
	local a = Config.Academies[id]
	table.insert(REGIONS, { tag = id, kind = "school", school = id, angle = a.angle, dist = RING, R = 1250, title = a.name, accent = a.accent, seed = 300 + #REGIONS * 97 })
end
for _, c in Config.Cities do
	table.insert(REGIONS, { tag = c.id, kind = "city", angle = c.angle, dist = RING, R = 1000, title = c.name, accent = c.accent, seed = 700 + #REGIONS * 53, tilly = c.tilly, cityNpcs = c.npcs })
end
for _, r in REGIONS do
	local a = math.rad(r.angle)
	r.pos = Vector3.new(math.sin(a) * r.dist, 0, math.cos(a) * r.dist)
	-- inside a ring district, local +Z points at the map centre
	r.cf = if r.dist > 0 then CFrame.lookAt(r.pos, r.pos - r.pos.Unit) * CFrame.Angles(0, math.rad(180), 0) else CFrame.new()
	r.top = if r.kind == "city" then -0.15 else 0 -- where islands overlap, their surfaces must not share a height
end
Campus.Regions = REGIONS

local function hexInside(r, x: number, z: number, margin: number): boolean
	local lp = r.cf:PointToObjectSpace(Vector3.new(x, 0, z))
	local limit = r.R - margin
	for k = 0, 2 do
		local a = math.rad(k * 60)
		if math.abs(lp.X * math.sin(a) + lp.Z * math.cos(a)) > limit then
			return false
		end
	end
	return true
end

--- True when (x, z) is on land, at least `margin` studs from the water.
function Campus.inside(x: number, z: number, margin: number?): boolean
	for _, r in REGIONS do
		if hexInside(r, x, z, margin or 0) then
			return true
		end
	end
	return false
end

local function regionAt(x: number, z: number, margin: number?)
	for _, r in REGIONS do
		if hexInside(r, x, z, margin or 0) then
			return r
		end
	end
	return nil
end

--- Distance from a region's centre to its edge, along the world direction `dir`.
local function hexReach(r, dir: Vector3): number
	local d = r.cf:VectorToObjectSpace(dir)
	local best = 0
	for k = 0, 2 do
		local a = math.rad(k * 60)
		best = math.max(best, math.abs(d.X * math.sin(a) + d.Z * math.cos(a)))
	end
	return r.R / best
end

-- Bridges from the centre island to each of the eight ring islands
local BRIDGES = {}
for i = 2, #REGIONS do
	local r = REGIONS[i]
	local dir = r.pos.Unit
	local p0 = dir * (hexReach(REGIONS[1], dir) - 40)
	local p1 = r.pos - dir * (hexReach(r, -dir) - 40)
	table.insert(BRIDGES, { a = p0, b = p1, width = 64, region = r })
end
Campus.Bridges = BRIDGES

local function nearBridgeEnd(p: Vector3, pad: number): boolean
	local flat = Vector3.new(p.X, 0, p.Z)
	for _, b in BRIDGES do
		if (flat - b.a).Magnitude < b.width / 2 + pad or (flat - b.b).Magnitude < b.width / 2 + pad then
			return true
		end
	end
	return false
end

--- Areas inside a district that the city-block filler must leave alone (district-local coordinates).
local function reserved(r, lx: number, lz: number): boolean
	local d = math.sqrt(lx * lx + lz * lz)
	local a = math.deg(math.atan2(lx, lz)) % 360
	if r.kind == "centre" then
		return d < 345
	elseif r.kind == "city" then
		if r.tilly and lx > 360 and lx < 580 and math.abs(lz) < 90 then
			return true -- Tilly's shop street
		end
		return (math.abs(lx) < 310 and math.abs(lz) < 310) or (math.abs(lx) < 30 and lz > 0 and lz < 420)
	end
	if d < 345 then
		return true
	end
	-- arrival station (toward the centre), training hall and shop street
	for _, ca in { 0, 90, 270 } do
		local diff = math.abs(((a - ca + 180) % 360) - 180)
		if d < 540 and diff < 19 then
			return true
		end
	end
	-- the campus, straight away from the centre, and the road out to its gate
	local along, side = -lz, lx
	if along > Campus.CampusGate - 40 and along < Campus.CampusGate + 680 and math.abs(side) < 345 then
		return true
	end
	return along > 300 and along < Campus.CampusGate and math.abs(side) < 40
end

local function build(world: Instance)
	local anchors = Instance.new("Folder")
	anchors.Name = "Anchors"
	anchors.Parent = world

	local function makeCtx(r)
		local root = Kit.at(world, r.cf * CFrame.new(0, r.top, 0)):group(r.tag)
		local ctx = {}
		for k, v in r do
			ctx[k] = v
		end
		ctx.root = root
		ctx.treeKind = if r.school == "solcrest" then "autumn" elseif r.school == "ironreach" or r.school == "northwind" then "pine" elseif r.school then "round" else "blossom"
		--- A frame on the circle of radius d at angle a (district-local). Its -Z looks at the district centre.
		function ctx.spoke(name: string, aDeg: number, d: number)
			local x, z = polar(aDeg, d)
			return root:group(name, x, 0, z, aDeg)
		end
		function ctx.anchor(name: string, frame, x: number, y: number, z: number, yawDeg: number?)
			local cf = frame.cf * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
			return Kit.part(anchors, "Block", Vector3.new(1, 1, 1), cf, Pal.white, M.SmoothPlastic, { name = name, trans = 1, decor = true })
		end
		function ctx.prompt(part: BasePart, open: string, action: string, object: string, distance: number?)
			local p = Kit.new("ProximityPrompt", {
				Name = "HalcyonPrompt",
				ActionText = action,
				ObjectText = object,
				HoldDuration = 0,
				MaxActivationDistance = distance or 18,
				RequiresLineOfSight = false,
				KeyboardKeyCode = Enum.KeyCode.E,
				GamepadKeyCode = Enum.KeyCode.DPadDown,
			}, part)
			p:SetAttribute("Open", open)
			return p
		end
		--- A transit gate: a glowing ring over a pad with a Travel prompt.
		function ctx.transit(frame, x: number, z: number)
			local f = frame:shift(x, 0, z)
			f:cyl(0, 0.2, 0, 8, 0.3, Pal.slate, M.Marble)
			for k = 0, 11 do
				local a = math.rad(k * 30)
				f:piece("Block", CFrame.new(0, 9 + math.cos(a) * 7, math.sin(a) * 7) * CFrame.Angles(-a, 0, 0), Vector3.new(1, 0.8, 3.9), if k % 2 == 0 then Pal.lumen else Pal.white, if k % 2 == 0 then M.Neon else M.SmoothPlastic, { decor = true })
			end
			for _, sx in { -1, 1 } do
				f:box(0, 0, sx * 7.6, 1.6, 9, 1.6, Pal.white, M.SmoothPlastic)
			end
			local core = f:cyl(0, 0.5, 0, 6, 0.25, Pal.lumen, M.Neon, { name = "TransitPad" })
			Kit.glow(core, 24, 1.5, Pal.lumen)
			ctx.prompt(core, "travel:" .. ctx.tag, "Travel", "Transit Gate", 14)
			ctx.anchor("Transit_" .. ctx.tag, f, 0, 3.5, 12, 0)
		end
		return ctx
	end

	-- =========================================================================================
	-- Ground: an island per region, the lake, the bridges, and the far shore
	-- =========================================================================================
	local ground = Kit.at(world, CFrame.new()):group("Ground")
	for _, r in REGIONS do
		local side = r.R * 2 / math.sqrt(3)
		local paving = if r.kind == "city" then hex(0xc4cad6) elseif r.kind == "centre" then hex(0xd8dde7) else Kit.mix(hex(0xc9cfdb), r.accent, 0.06)
		for k = 0, 2 do
			for _, half in { -1, 1 } do
				local cf = CFrame.new(r.pos) * r.cf.Rotation * CFrame.Angles(0, math.rad(k * 60), 0) * CFrame.new(0, r.top - 20, half * r.R / 2)
				ground:piece("Block", cf, Vector3.new(side, 40, r.R), paving, M.Pavement, { name = "Ground" })
			end
		end
		-- sea wall with railing, open where islands meet and where bridges land
		local segs = 9
		for k = 0, 5 do
			local edge = CFrame.new(r.pos) * r.cf.Rotation * CFrame.Angles(0, math.rad(k * 60), 0)
			for s = 0, segs - 1 do
				local lx = -side / 2 + side * (s + 0.5) / segs
				local mid = edge * Vector3.new(lx, 0, r.R)
				local open = nearBridgeEnd(mid, 30)
				for _, other in REGIONS do
					if other ~= r and hexInside(other, mid.X, mid.Z, -12) then
						open = true
					end
				end
				if not open then
					local f = Kit.at(ground.parent, edge * CFrame.new(lx, r.top, r.R))
					f:box(0, 0, -0.5, side / segs + 0.4, 4, 1.2, Pal.glass, M.Glass, { trans = 0.5, shadow = false })
					f:box(0, 4, -0.5, side / segs + 0.4, 0.5, 1.6, r.accent, M.Neon, { decor = true })
					f:box(0, -40, -1, side / segs + 0.4, 2, 2, r.accent, M.Neon, { decor = true })
					f:box(0, 0, 1, side / segs + 0.4, 200, 2, Pal.white, M.SmoothPlastic, { trans = 1, name = "Barrier", shadow = false })
					if s % 2 == 0 then
						Props.lamp(f:shift(0, 0, -6, 0), 0, 0, r.accent, false, 12)
					end
				end
			end
		end
	end
	-- bridges
	for i, b in BRIDGES do
		local len = (b.b - b.a).Magnitude
		local cf = CFrame.lookAt((b.a + b.b) / 2, b.b)
		local f = Kit.at(ground.parent, cf):group("Bridge" .. i)
		f:box(0, -1.2, 0, b.width, 1.4, len, hex(0xe9edf4), M.Concrete, { name = "BridgeDeck" })
		f:box(0, 0.2, 0, b.width - 20, 0.06, len, hex(0x3b4152), M.Asphalt, { decor = true })
		f:box(0, 0.27, 0, 0.8, 0.05, len, Pal.white, M.SmoothPlastic, { decor = true })
		for _, sx in { -1, 1 } do
			f:box(sx * (b.width / 2 - 0.6), 0.2, 0, 1, 4, len - 80, Pal.glass, M.Glass, { trans = 0.5, shadow = false })
			f:box(sx * (b.width / 2 - 0.6), 4.2, 0, 1.4, 0.5, len - 80, b.region.accent, M.Neon, { decor = true })
			f:box(sx * (b.width / 2 + 1), 0, 0, 2, 200, len - 80, Pal.white, M.SmoothPlastic, { trans = 1, name = "Barrier", shadow = false })
			for j = 0, math.floor(len / 70) do
				local z = -len / 2 + 35 + j * 70
				Props.lamp(f:shift(sx * (b.width / 2 - 4), 0, z, sx * 90), 0, 0, b.region.accent, j % 4 == 0, 13)
				if j % 2 == 0 then
					f:box(sx * (b.width / 2 - 8), -16, z, 6, 14, 6, hex(0xe9edf4), M.Concrete, { decor = true })
				end
			end
		end
		-- a gateway arch where the bridge reaches the island: travellers from the centre read the
		-- district's name, people leaving the district read "Crown Plaza"
		local archZ = -(len / 2 - 60)
		local arch = f:box(0, 26, archZ, b.width + 6, 6, 4, Pal.night, M.Metal, { name = "BridgeArch" })
		Kit.label(arch, Enum.NormalId.Back, string.upper(b.region.title), { color = b.region.accent })
		Kit.label(arch, Enum.NormalId.Front, "CROWN PLAZA", { color = Pal.gold })
		for _, sx in { -1, 1 } do
			f:box(sx * (b.width / 2 + 2), 0, archZ, 4, 26, 4, Pal.darkMetal, M.Metal)
		end
	end
	-- the lake
	local water = Kit.at(world, CFrame.new()):group("Lake")
	for gx = -3, 3 do
		for gz = -3, 3 do
			water:box(gx * 2000, -14, gz * 2000, 2000, 2, 2000, hex(0x2b6aa3), M.SmoothPlastic, { name = "LakeWater", refl = 0.25, collide = false, shadow = false })
		end
	end
	-- far shore: hills and mountains across the water
	do
		local rndm = Props.rng(777)
		for i = 0, 71 do
			local a = math.rad(i * 5 + rndm(-2, 2))
			local d = rndm(5900, 6400)
			local radius = rndm(320, 560)
			ground:ball(math.sin(a) * d, -radius * rndm(0.6, 0.8), math.cos(a) * d, radius, Kit.mix(Pal.grass, Pal.grassDark, rndm(0, 1)), M.Grass, { decor = true })
		end
		for i = 0, 39 do
			local a = math.rad(i * 9 + rndm(-4, 4))
			local d = rndm(6900, 7600)
			local w, h = rndm(900, 1400), rndm(700, 1200)
			local f = ground:shift(math.sin(a) * d, 0, math.cos(a) * d, math.deg(a) + 45 + rndm(-10, 10))
			local rock = Kit.mix(hex(0x6b7690), hex(0x8b96ad), rndm(0, 1))
			for _, yaw in { 0, 90 } do
				f:wedge(0, -30, -w * 0.25, w, h, w * 0.5, 180 + yaw, rock, M.Rock, { decor = true, rot = CFrame.Angles(0, math.rad(yaw), 0) })
				f:wedge(0, -30, w * 0.25, w, h, w * 0.5, yaw, Kit.shade(rock, 0.9), M.Rock, { decor = true, rot = CFrame.Angles(0, math.rad(yaw), 0) })
				f:wedge(0, h * 0.68 - 30, -w * 0.08, w * 0.32, h * 0.32, w * 0.16, 180 + yaw, hex(0xf2f6fb), M.Snow, { decor = true, rot = CFrame.Angles(0, math.rad(yaw), 0) })
				f:wedge(0, h * 0.68 - 30, w * 0.08, w * 0.32, h * 0.32, w * 0.16, yaw, hex(0xe4ebf5), M.Snow, { decor = true, rot = CFrame.Angles(0, math.rad(yaw), 0) })
			end
		end
	end

	-- =========================================================================================
	-- District builders (each is a section of the old single-island map, now reused per district)
	-- =========================================================================================
	local function buildPlaza(ctx)
		local root = ctx.root
		local plaza = root:group("Plaza")
		plaza:cyl(0, -0.3, 0, 124, 0.6, Pal.stone, M.Marble, { name = "PlazaFloor" })
		plaza:cyl(0, 0.3, 0, 101, 0.06, Pal.lumen, M.Neon, { decor = true })
		plaza:cyl(0, 0.3, 0, 100, 0.12, Pal.stoneWarm, M.Marble)
		plaza:cyl(0, 0.42, 0, 61, 0.06, Pal.gold, M.Neon, { decor = true })
		plaza:cyl(0, 0.42, 0, 60, 0.12, Pal.slate, M.Marble, { refl = 0.18 })
		plaza:cyl(0, 0.54, 0, 27, 0.06, Pal.lumen, M.Neon, { decor = true })
		plaza:cyl(0, 0.54, 0, 26, 0.12, Pal.stone, M.Marble)
		plaza:ring(0, 0.54, 0, 43.5, 8, function(f)
			f:box(0, 0, 0, 0.7, 0.07, 33, Pal.lumen, M.Neon, { decor = true })
		end)
		plaza:ring(0, 0.42, 0, 80.5, 16, function(f)
			f:box(0, 0, 0, 0.5, 0.07, 39, Pal.gold, M.Neon, { decor = true })
		end, 11.25)

		return plaza
	end

	local function buildSchoolSpire(ctx, plaza)
		local prompt = ctx.prompt
		local spire = plaza:group("SchoolSpire")
		spire:cyl(0, 0.66, 0, 15, 1.4, Pal.slate, M.Marble)
		spire:cyl(0, 2.06, 0, 12.6, 0.3, ctx.accent, M.Neon, { decor = true })
		spire:cyl(0, 2.06, 0, 12, 1.0, Pal.stone, M.Marble)
		spire:cyl(0, 3.06, 0, 3.4, 104, Pal.glass, M.Glass, { trans = 0.5, shadow = false })
		local core = spire:cyl(0, 3.06, 0, 1.4, 108, ctx.accent, M.Neon, { decor = true, name = "SchoolSpireCore" })
		Kit.glow(core, 60, 2.2, ctx.accent)
		for i, h in { 34, 54, 74, 92 } do
			local rr = 15 - i * 2.2
			local seg = 2 * math.pi * rr / 14 + 0.25
			spire:ring(0, h, 0, rr, 14, function(f)
				f:box(0, 0, 0, seg, 1.3, 0.9, if i % 2 == 0 then ctx.accent else Pal.gold, M.Neon, { decor = true })
			end)
		end
		local star = spire:ball(0, 112, 0, 3, Pal.white, M.Neon, { decor = true })
		Kit.glow(star, 60, 3, ctx.accent)
		-- Register boards, one each side of the tower
		for _, yaw in { 90, 270 } do
			local f = spire:shift(0, 0, 0, yaw)
			for _, sx in { -21, 21 } do
				f:box(sx, 0.66, 44, 2.6, 27, 2.6, Pal.darkMetal, M.Metal)
				f:box(sx, 27.66, 44, 3.2, 0.7, 3.2, Pal.lumen, M.Neon, { decor = true })
			end
			f:box(0, 4.3, 44, 40, 0.7, 1.4, Pal.lumen, M.Neon, { decor = true })
			f:box(0, 26, 44, 40, 0.7, 1.4, Pal.lumen, M.Neon, { decor = true })
			local board = f:box(0, 5, 44, 39.4, 21, 0.8, Pal.night, M.Glass, { trans = 0.12, name = "RegisterBoard" })
			Kit.label(board, Enum.NormalId.Back, "THE REGISTER", { color = Pal.lumen, sizeY = 0.3, name = "Baked" })
			prompt(board, "register", "Read", "The Register", 30)
		end

		return spire
	end

	local function buildSeats(ctx, plaza)
		local anchor = ctx.anchor
		-- The ring of seats
		for i, npc in Roster.schoolSeats(ctx.school) do
			local a = SEAT_ANGLES[i]
			local x, z = polar(a, 84)
			local f = plaza:shift(x, 0, z, a)
			f:cyl(0, 0.42, 0, 5.6, 0.22, npc.look.accent, M.Neon, { decor = true })
			f:cyl(0, 0.42, 0, 5.1, 0.9, Pal.slate, M.Marble, { name = "SeatPedestal" })
			f:box(0, 0.42, -7.4, 5.4, 0.3, 2, npc.look.accent, M.Neon, { decor = true, trans = 0.2 })
			anchor("Npc_" .. npc.id, f, 0, 1.32, 0, 0)
			anchor("Return_" .. npc.id, f, 0, 0.6, -12, 180)
		end

	end

	local function buildPlanters(plaza)
		-- Planters and benches between the avenue mouths
		for k = 0, 7 do
			local a = 22.5 + 45 * k
			local x, z = polar(a, 108)
			local f = plaza:shift(x, 0.3, z, a)
			Props.planter(f, 0, 0, 15, if k % 2 == 0 then "blossom" else "round")
			Props.bench(f, -13, -1, 90)
			Props.bench(f, 13, -1, -90)
		end

	end

	local function buildAvenues(ctx)
		local spoke = ctx.spoke
		-- =========================================================================================
		-- Avenues
		-- =========================================================================================
		for k = 0, 7 do
			local a = 45 * k
			local academy = if k % 2 == 1 then ctx.school else nil
			local accent = ctx.accent
			local width = if academy then 24 else 32
			local av = spoke("Avenue" .. k, a, 218)
			av:box(0, -0.2, 0, width, 0.34, 200, hex(0x3b4152), M.Asphalt, { name = "Road" })
			av:box(0, 0.14, 0, 0.8, 0.05, 200, Pal.white, M.SmoothPlastic, { decor = true })
			for _, side in { -1, 1 } do
				av:box(side * (width / 2 - 0.5), 0.14, 0, 0.6, 0.06, 200, accent, M.Neon, { decor = true })
				for j = 0, 4 do
					local lz = -80 + j * 40
					Props.lamp(av:shift(side * (width / 2 + 3.5), 0, lz, side * 90), 0, 0, accent, j == 2 and side > 0)
				end
				for j = 0, 3 do
					local kind = ctx.treeKind
					Props.tree(av, side * (width / 2 + 11), -60 + j * 40, kind, 1.0 + ((j + k) % 3) * 0.12)
				end
			end
			if academy or (ctx.kind == "centre" and k % 2 == 1) then
				Props.banner(av, width / 2 + 5, -96, accent, 28, 0)
				Props.banner(av, -(width / 2 + 5), -96, accent, 28, 180)
			end
		end

	end

	local function buildArrival(ctx)
		local spoke, anchor, transit = ctx.spoke, ctx.anchor, ctx.transit
		-- =========================================================================================
		-- Skydock (south): arrival terrace and spawn
		-- =========================================================================================
		do
			local d = spoke("Arrival", 0, 330)
			d:box(0, -0.2, 76, 124, 0.4, 152, Pal.stone, M.Marble, { name = "Terrace" })
			d:box(0, 0.2, 76, 30, 0.05, 150, Pal.stoneWarm, M.Marble, { decor = true })
			-- welcome arch
			for _, sx in { -21, 21 } do
				d:box(sx, 0, -6, 4, 30, 4, Pal.darkMetal, M.Metal)
				d:box(sx, 3, -6, 4.4, 22, 0.5, Pal.lumen, M.Neon, { decor = true, rot = CFrame.Angles(0, math.rad(90), 0) })
			end
			local beam = d:box(0, 30, -6, 50, 5, 4, Pal.night, M.Metal, { name = "WelcomeArch" })
			Kit.label(beam, Enum.NormalId.Back, string.upper(ctx.title), { color = ctx.accent })
			Kit.label(beam, Enum.NormalId.Front, "ARRIVALS", { color = Pal.gold })
			d:box(0, 35, -6, 52, 0.6, 4.6, Pal.lumen, M.Neon, { decor = true })
			-- spawn pad
			d:cyl(0, 0.2, 44, 9.6, 0.08, Pal.lumen, M.Neon, { decor = true })
			d:cyl(0, 0.2, 44, 9, 0.14, Pal.slate, M.Marble, { refl = 0.2 })
			local spawn = if ctx.tag ~= Config.AcademyOrder[1] then nil else Kit.new("SpawnLocation", {
				Name = "Spawn",
				Anchored = true,
				Size = Vector3.new(14, 1, 14),
				CFrame = d.cf * CFrame.new(0, 0.9, 44),
				Transparency = 1,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				Neutral = true,
				Duration = 0,
				TopSurface = Enum.SurfaceType.Smooth,
			}, anchors)
			if spawn then
				spawn.CastShadow = false
			end
			anchor("Spawn_" .. ctx.tag, d, 0, 3.5, 44, 0)
			anchor("Arrival_" .. ctx.tag, d, 0, 0.6, 30, 0)
			transit(d, 30, 120)
			-- arrival station canopy
			for _, sx in { -40, 40 } do
				d:box(sx, 0, 160, 3, 22, 3, Pal.darkMetal, M.Metal)
			end
			local canopy = d:box(0, 22, 160, 90, 2, 24, Pal.white, M.SmoothPlastic, { name = "StationCanopy" })
			Kit.label(canopy, Enum.NormalId.Back, "ACADEMY STATION", { color = Pal.lumen })
			d:box(0, 21.6, 160, 92, 0.5, 25, Pal.lumen, M.Neon, { decor = true })
			d:box(0, 0, 172, 120, 1.5, 6, Pal.slate, M.Concrete)
			d:box(0, 1.5, 172, 120, 0.12, 0.6, Pal.gold, M.Neon, { decor = true })
			Props.holo(d, 34, 6, 60, 20, 6, "ARRIVALS", Pal.lumen, 90)
			Props.holo(d, -34, 6, 60, 20, 6, "REGISTER  ▲", Pal.gold, 90)
			for i, id in Config.AcademyOrder do
				local sx = if i <= 2 then -58 else 58
				local sz = if i % 2 == 1 then 24 else 92
				Props.banner(d, sx, sz, Config.Academies[id].accent, 30, if sx < 0 then 0 else 180)
			end
			Props.bench(d, -42, 110, -90)
			Props.bench(d, 42, 110, 90)
			Props.planter(d, -44, 62, 13, "blossom")
			Props.planter(d, 44, 62, 13, "blossom")
			-- luggage
			d:box(-30, 0.2, 128, 5, 4, 7, hex(0x7a4b2e), M.Wood)
			d:box(-30, 4.2, 128.5, 4, 3, 5, hex(0x2f6fb5), M.Fabric, { decor = true })
			d:box(-23, 0.2, 131, 4, 3, 4, hex(0xb53a3a), M.Fabric)
			d:box(28, 0.2, 130, 6, 5, 6, Pal.metal, M.DiamondPlate)
			for _, sx in { -60, 60 } do
				Props.lamp(d:shift(sx, 0, 44, if sx > 0 then 90 else -90), 0, 0, Pal.lumen, true)
				Props.lamp(d:shift(sx, 0, 130, if sx > 0 then 90 else -90), 0, 0, Pal.lumen, true)
			end
		end

	end

	local function buildTrainingHall(ctx)
		local spoke, anchor, prompt = ctx.spoke, ctx.anchor, ctx.prompt
		-- =========================================================================================
		-- Training Hall (east)
		-- =========================================================================================
		do
			local t = spoke("TrainingHall", 90, 330)
			local roof = hex(0x27314d)
			t:box(0, -0.2, 76, 124, 0.4, 152, Pal.stoneWarm, M.Marble)
			t:box(0, 0, 5, 44, 0.8, 6, Pal.stoneDark, M.Marble)
			t:box(0, 0, 72, 112, 1.6, 124, hex(0x6d4a32), M.WoodPlanks, { name = "HallFloor" })
			t:cyl(0, 1.6, 66, 23, 0.08, Pal.ember, M.Neon, { decor = true })
			t:cyl(0, 1.6, 66, 22.3, 0.14, Pal.deck, M.SmoothPlastic, { refl = 0.1 })
			for _, sx in { -48, 48 } do
				for j = 0, 3 do
					Props.column(t:shift(0, 1.6, 0), sx, 18 + j * 36, 2.2, 28, hex(0x8a2f3a), M.Wood)
				end
				t:box(sx, 29.6, 72, 5, 2, 124, Pal.woodDark, M.Wood)
			end
			t:box(0, 29.6, 12, 101, 2, 5, Pal.woodDark, M.Wood)
			t:box(0, 29.6, 132, 101, 2, 5, Pal.woodDark, M.Wood)
			t:wedge(-30, 31.6, 72, 136, 17, 60, 90, roof, M.Slate)
			t:wedge(30, 31.6, 72, 136, 17, 60, -90, roof, M.Slate)
			t:box(0, 48.2, 72, 1.6, 1, 138, Pal.ember, M.Neon, { decor = true })
			for _, sx in { -60, 60 } do
				t:box(sx, 31.4, 72, 0.7, 0.7, 136, Pal.ember, M.Neon, { decor = true })
			end
			-- back wall with the weapon rack
			local wall = t:box(0, 1.6, 133, 96, 26, 2, Pal.stoneWarm, M.Marble, { name = "RackWall" })
			Kit.label(wall, Enum.NormalId.Front, "TRAINING HALL", { color = hex(0x8a2f3a), sizeY = 0.22, posY = 0.16, glow = false, font = Enum.Font.Michroma })
			for i, id in Weapons.Order do
				local def = Weapons.List[id]
				local sx = -42.5 + (i - 1) * 17
				t:box(sx, 5.4, 131.2, 8, 0.6, 1.4, Pal.woodDark, M.Wood, { decor = true })
				t:box(sx, 6, 131.4, 1, 3, 0.8, Pal.darkMetal, M.Metal, { decor = true })
				local m = Weapons.model(id, "right")
				-- stand it upright on the rack, blade up
				m:PivotTo(t.cf * CFrame.new(sx, 9.5, 130.6) * CFrame.Angles(math.rad(180), 0, 0))
				for _, part in m:GetDescendants() do
					if part:IsA("BasePart") then
						part.Anchored = true
					end
				end
				m.Name = "Rack_" .. id
				m.Parent = t.parent
				local spot = t:box(sx, 1.6, 126, 8, 10, 4, Pal.white, M.SmoothPlastic, { trans = 1, decor = true, name = "RackSpot" })
				prompt(spot, "equip:" .. id, "Equip", def.name, 10)
				local plate = t:box(sx, 2.4, 131.5, 8, 2.2, 0.4, Pal.night, M.Glass, { decor = true })
				Kit.label(plate, Enum.NormalId.Front, string.upper(def.name), { color = def.color })
			end
			-- training dummies
			for _, p in { { -32, 34 }, { 32, 34 }, { -32, 100 }, { 32, 100 } } do
				local f = t:group("TrainingDummy", p[1], 1.6, p[2])
				f.parent:SetAttribute("Dummy", true)
				local dummyRoot = f:box(0, 0.6, 0, 3, 7, 2.4, Pal.white, M.SmoothPlastic, { name = "HumanoidRootPart", trans = 1, decor = true })
				f.parent.PrimaryPart = dummyRoot
				f:cyl(0, 0, 0, 1.6, 0.6, Pal.darkMetal, M.Metal)
				f:cyl(0, 0.6, 0, 0.6, 7, Pal.wood, M.Wood)
				f:box(0, 3.4, 0, 3, 3.8, 2.2, hex(0xb9a27a), M.Fabric)
				f:box(0, 6, 0, 7, 0.8, 0.8, Pal.wood, M.Wood, { decor = true })
				f:ball(0, 8.9, 0, 1.4, hex(0xb9a27a), M.Fabric, { decor = true })
				f:box(0, 4.8, -1.2, 1.6, 1.6, 0.2, Pal.ember, M.Neon, { decor = true })
			end
			if ctx.tag == "northwind" then
				anchor("Npc_brandt", t, 0, 1.6, 114, 0)
				anchor("Return_brandt", t, 0, 1.9, 96, 180)
			end
			Props.holo(t, 0, 20, 10, 46, 6, "TRAINING HALL", Pal.ember, 0)
			for _, sx in { -58, 58 } do
				local f = t:shift(sx, 0, 6)
				f:cyl(0, 0, 0, 2.4, 4, Pal.darkMetal, M.Metal)
				local fire = f:cyl(0, 4, 0, 2, 1, Pal.ember, M.Neon, { decor = true })
				Kit.glow(fire, 40, 2, Pal.ember)
				Kit.sparkles(fire, Pal.ember, 18, { Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(20, 20), Lifetime = NumberRange.new(0.6, 1.4) })
			end
			Props.tree(t, -70, 40, "autumn", 1.3)
			Props.tree(t, 70, 40, "autumn", 1.3)
			Props.tree(t, -72, 120, "pine", 1.2)
			Props.tree(t, 72, 120, "pine", 1.2)
		end

	end

	local function buildMarket(ctx)
		local spoke, anchor = ctx.spoke, ctx.anchor
		-- =========================================================================================
		-- Market Arcade (west)
		-- =========================================================================================
		do
			local k = spoke("MarketArcade", 270, 330)
			local teal = hex(0x35d6c3)
			k:box(0, -0.2, 76, 124, 0.4, 152, Pal.stoneWarm, M.Marble)
			k:box(0, 0.2, 66, 34, 0.05, 132, hex(0x4a3f5e), M.Marble, { decor = true })
			local stalls = {
				{ "BLADE GLOWS", hex(0xff4fd8) }, { "AURAS", hex(0x7dff7a) }, { "CAPES + WINGS", hex(0xffc94a) },
				{ "TITLES", hex(0x39c9ff) }, { "SKY NOODLES", hex(0xff7a2a) }, { "LUMEN CELLS", hex(0xb06bff) },
			}
			for i, info in stalls do
				local side = if i % 2 == 1 then -1 else 1
				local row = math.floor((i - 1) / 2)
				local f = k:shift(side * 40, 0.2, 30 + row * 40, side * 90)
				local color = info[2]
				f:box(0, 0, 0, 15, 3.8, 4.4, Pal.wood, M.WoodPlanks)
				local shelf = f:box(0, 0, 5.4, 15, 10, 1.2, Pal.woodDark, M.Wood)
				Kit.label(shelf, Enum.NormalId.Front, info[1], { color = color, sizeY = 0.24, posY = 0.2 })
				for _, px in { -7, 7 } do
					f:box(px, 0, -2, 0.6, 11.6, 0.6, Pal.darkMetal, M.Metal, { decor = true })
					f:box(px, 0, 5.4, 0.6, 11.6, 0.6, Pal.darkMetal, M.Metal, { decor = true })
				end
				f:wedge(0, 11.6, 1.4, 16.4, 3, 9.6, 0, color, M.Fabric, { decor = true })
				f:box(0, 11.2, -3.3, 16.4, 0.5, 0.4, color, M.Neon, { decor = true })
				f:ball(-4.5, 5, 0, 1.2, color, M.Neon, { decor = true })
				f:box(0, 3.8, 0, 2.2, 2.2, 2.2, Kit.mix(color, Pal.white, 0.4), M.SmoothPlastic, { decor = true, rot = CFrame.Angles(0, math.rad(30), 0) })
				f:cyl(4.5, 3.8, 0, 1.1, 2.6, Kit.shade(color, 0.7), M.Metal, { decor = true })
				local lightPart = f:box(0, 10.6, 1.6, 12, 0.3, 0.3, Pal.white, M.Neon, { decor = true })
				if row == 1 then
					Kit.glow(lightPart, 30, 1.2, color)
				end
			end
			-- string lights across the lane
			for row = 0, 2 do
				local z = 50 + row * 40
				k:bar(Vector3.new(-33, 14.2, z), Vector3.new(33, 14.2, z), 0.2, Pal.darkMetal, M.Metal, { decor = true })
				for j = 0, 6 do
					k:ball(-30 + j * 10, 13.4, z, 0.8, if j % 2 == 0 then Pal.gold else teal, M.Neon, { decor = true })
				end
			end
			-- Tilly's stall (the shop itself is a menu, opened from the Shop button anywhere)
			local s = k:shift(0, 0.2, 138)
			s:box(0, 0, 0, 22, 3.8, 5, Pal.wood, M.WoodPlanks)
			s:wedge(0, 11, 2, 24, 3, 10, 0, teal, M.Fabric, { decor = true })
			for _, px in { -10, 10 } do
				s:box(px, 0, 4, 0.7, 11, 0.7, Pal.darkMetal, M.Metal, { decor = true })
			end
			local sign = s:box(0, 5.4, 5.4, 18, 4, 0.6, Pal.night, M.Glass, { decor = true, name = "StallSign" })
			Kit.label(sign, Enum.NormalId.Front, "TILLY'S TRINKETS", { color = teal })
			if ctx.tilly then
				anchor("Npc_tilly", s, 0, 0, -4, 0)
				anchor("Return_tilly", s, 0, 0.4, -16, 180)
			end

			Props.holo(k, 0, 20, 8, 46, 6, "MARKET ARCADE", teal, 0)
			for _, sx in { -24, 24 } do
				k:cyl(sx, 0, 8, 1.2, 26, Pal.darkMetal, M.Metal)
			end
			Props.planter(k, -52, 136, 13, "round")
			Props.planter(k, 52, 136, 13, "round")
			k:cyl(-54, 0.2, 14, 2, 4.4, hex(0x7a4b2e), M.Wood)
			k:cyl(-50, 0.2, 17, 2, 4.4, hex(0x7a4b2e), M.Wood)
			k:box(53, 0.2, 14, 5, 5, 5, hex(0x8a6a48), M.WoodPlanks)
			k:box(53, 5.2, 14, 4, 3, 4, hex(0x8a6a48), M.WoodPlanks, { decor = true, rot = CFrame.Angles(0, math.rad(20), 0) })
		end

	end

	local function buildCampus(ctx)
		local spoke, anchor, prompt = ctx.spoke, ctx.anchor, ctx.prompt
		-- =========================================================================================
		-- School campuses (diagonals): each school owns a large walled plot far from the centre
		-- Local frame: the gate is at z = 0, the plot runs to z = 640 and x = +-300.
		-- =========================================================================================
		local function campusGrounds(p, info, gl)
			local W, D = 300, 640
			local rndc = Props.rng(#info.id * 131)
			p:box(0, -0.2, D / 2, W * 2, 0.3, D, gl[1], gl[2], { name = "CampusGround" })
			-- perimeter wall with a gate gap facing the hub
			local wallColor = Kit.mix(gl[1], Pal.slate, 0.55)
			for _, seg in { { -(W + 40) / 2 - 20, 0, W - 40, 2.5 }, { (W + 40) / 2 + 20, 0, W - 40, 2.5 }, { 0, D, W * 2, 2.5 } } do
				p:box(seg[1], 0, seg[2], seg[3], 10, seg[4], wallColor, M.Concrete, { name = "CampusWall" })
				p:box(seg[1], 10, seg[2], seg[3], 0.6, seg[4] + 0.4, info.accent, M.Neon, { decor = true })
			end
			for _, sx in { -W, W } do
				p:box(sx, 0, D / 2, 2.5, 10, D, wallColor, M.Concrete, { name = "CampusWall" })
				p:box(sx, 10, D / 2, 2.9, 0.6, D, info.accent, M.Neon, { decor = true })
			end
			-- gate
			for _, sx in { -44, 44 } do
				p:box(sx, 0, 0, 8, 34, 8, wallColor, M.Concrete)
				p:box(sx, 34, 0, 9, 3, 9, info.accent, M.Neon, { decor = true })
			end
			local arch = p:box(0, 28, 0, 96, 7, 5, Pal.night, M.Metal, { name = "CampusGate" })
			Kit.label(arch, Enum.NormalId.Front, string.upper(info.name), { color = info.accent })
			Kit.label(arch, Enum.NormalId.Back, info.motto, { color = info.accent })
			-- main walk from the gate to the tower
			p:box(0, -0.05, 200, 30, 0.3, 380, Kit.mix(Pal.stone, info.accent, 0.08), M.Marble, { decor = false })
			-- dormitories
			for _, sx in { -190, 190 } do
				local h = 64
				p:box(sx, 0, 300, 80, h, 52, Kit.mix(info.uniform.jacket, Pal.stone, 0.45), M.SmoothPlastic, { name = "Dormitory" })
				for f2 = 0, 4 do
					p:box(sx, 8 + f2 * 11.5, 300, 80.6, 4, 52.6, hex(0xfff0c8), M.Neon, { decor = true, trans = 0.35 })
				end
				p:box(sx, h, 300, 84, 2, 56, info.accent, M.Neon, { decor = true })
				p:box(sx, h + 2, 300, 60, 8, 36, Kit.shade(info.uniform.dark, 1.2), M.Metal, { decor = true })
				local plate = p:box(sx + (if sx < 0 then 40.4 else -40.4), 4, 300, 0.6, 6, 26, Pal.night, M.Glass, { decor = true })
				Kit.label(plate, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left, "DORMITORY", { color = info.accent })
			end
			-- the school's own duel court
			local ring = p:shift(-170, 0, 520)
			ring:cyl(0, 0, 0, 46, 0.12, info.accent, M.Neon, { decor = true })
			ring:cyl(0, 0, 0, 45, 0.9, Pal.deck, M.SmoothPlastic, { name = "SchoolDuelCourt", refl = 0.2 })
			ring:ring(0, 0.9, 0, 45, 16, function(f, i)
				if i % 2 == 0 then
					f:cyl(0, 0, 0, 0.6, 9, Pal.darkMetal, M.Metal, { decor = true })
					f:ball(0, 9.5, 0, 1, info.accent, M.Neon, { decor = true })
				end
			end)
			for _, sz in { -58, 58 } do
				ring:box(0, 0, sz, 80, 4, 10, Kit.mix(info.uniform.jacket, Pal.slate, 0.5), M.Concrete)
				ring:box(0, 4, sz + (if sz > 0 then 3 else -3), 80, 3, 4, Kit.mix(info.uniform.jacket, Pal.slate, 0.5), M.Concrete)
			end
			anchor("Zone_" .. info.id, ring, 0, 1, 0):SetAttribute("Radius", 45)
			local board = ring:box(0, 1, 70, 40, 14, 1, Pal.night, M.Glass, { decor = true, name = "SchoolBoard" })
			Kit.label(board, Enum.NormalId.Front, string.upper(info.short) .. " REGISTER", { color = info.accent, sizeY = 0.35 })
			-- sports lawn and garden
			local lawn = p:shift(170, 0, 520)
			lawn:box(0, -0.05, 0, 110, 0.3, 120, Pal.grass, M.Grass)
			lawn:box(0, 0.25, 0, 100, 0.06, 1, Pal.white, M.SmoothPlastic, { decor = true })
			lawn:cyl(0, 0.25, 0, 12, 0.06, Pal.white, M.SmoothPlastic, { decor = true })
			for _, sz in { -56, 56 } do
				lawn:box(0, 0, sz, 18, 8, 1, Pal.white, M.Metal, { decor = true })
			end
			for i = 1, 8 do
				Props.tree(p, rndc(-270, -230), 60 + i * 66, if i % 2 == 0 then "pine" else "round", rndc(1, 1.4))
				Props.tree(p, rndc(230, 270), 60 + i * 66, if i % 2 == 0 then "pine" else "round", rndc(1, 1.4))
			end
			for _, sx in { -110, 110 } do
				for j = 0, 3 do
					Props.lamp(p:shift(sx * 0.18, 0, 170 + j * 60, if sx > 0 then 90 else -90), 0, 0, info.accent, j % 2 == 0)
				end
			end
			-- classroom wings either side of the main walk
			for _, sx in { -165, 165 } do
				local wing = Kit.mix(info.uniform.jacket, Pal.stone, 0.6)
				p:box(sx, 0, 150, 90, 26, 44, wing, M.SmoothPlastic, { name = "ClassroomWing" })
				p:box(sx, 26, 150, 94, 2, 48, Kit.shade(info.uniform.dark, 1.3), M.Slate)
				for f2 = 0, 1 do
					for wx = -3, 3 do
						p:box(sx + wx * 12, 5 + f2 * 11, 150 + (if sx < 0 then 22.1 else -22.1) * -1, 7, 5, 0.3, hex(0xcfe9ff), M.Glass, { decor = true, trans = 0.3 })
					end
				end
				p:box(sx, 11.5, 150, 90.6, 0.8, 44.6, info.accent, M.Neon, { decor = true })
				local plate = p:box(sx, 18, 127.7, 30, 5, 0.4, Pal.night, M.Glass, { decor = true })
				Kit.label(plate, Enum.NormalId.Front, "CLASSROOMS", { color = info.accent })
			end
			-- tree-lined main walk with benches
			for j = 0, 5 do
				for _, sx in { -60, 60 } do
					Props.tree(p, sx, 40 + j * 44, if j % 2 == 0 then "blossom" else "round", 1.05)
				end
				if j % 2 == 1 then
					Props.bench(p, -54, 40 + j * 44, -90)
					Props.bench(p, 54, 40 + j * 44, 90)
				end
			end
			-- back garden behind the tower
			for i = 0, 5 do
				Props.tree(p, -100 + i * 40, 600, if i % 2 == 0 then "pine" else "round", 1.3)
			end
			Props.fountain(p, -100, 200, 10, info.accent)
			Props.planter(p, 100, 200, 16, "blossom")
			anchor("Return_campus_" .. info.id, p, 0, 0.6, 20, 0)
			anchor("Gate_" .. info.id, p, 0, 3.5, 34, 180)
		end

		local function pavilionBase(academyId: string, a: number)
			local info = Config.Academies[academyId]
			local p = spoke("Campus_" .. info.short, a, Campus.CampusGate)
			p:box(0, -0.2, 56, 96, 0.4, 112, Kit.mix(Pal.stone, info.accent, 0.12), M.Marble)
			p:box(0, 0.2, 30, 20, 0.05, 60, info.accent, M.Neon, { decor = true, trans = 0.55 })
			Props.holo(p, -32, 7, 8, 26, 5, string.upper(info.name), info.accent, 0)
			Props.banner(p, -42, 22, info.accent, 30, 0)
			Props.banner(p, 42, 22, info.accent, 30, 180)
			Props.banner(p, -42, 58, info.accent, 30, 0)
			Props.banner(p, 42, 58, info.accent, 30, 180)
			anchor("Npc_" .. info.ace, p, 0, 0.2, 48, 0)
			anchor("Return_" .. info.ace, p, 0, 0.6, 34, 180)
			for _, sx in { -44, 44 } do
				Props.lamp(p:shift(sx, 0, 90, if sx > 0 then 90 else -90), 0, 0, info.accent, true)
			end
			-- District ground: every school stands on its own kind of land.
			local groundLook = {
				northwind = { hex(0xeef4fb), M.Snow },
				solcrest = { hex(0xe3c58a), M.Sandstone },
				arcline = { hex(0x2a2440), M.SmoothPlastic },
				ironreach = { hex(0x3b3436), M.Basalt },
			}
			local gl = groundLook[academyId]
			campusGrounds(p, info, gl)

			-- The school tower. Each academy is a high-rise campus with its own silhouette.
			local body = Kit.mix(info.uniform.dark, Pal.night, 0.3)
			local tw = p:shift(0, 0, Config.Map.TowerDepth)
			local topY
			if academyId == "northwind" then
				-- twin ice-glass spires joined by sky bridges
				local ice = hex(0xcfeeff)
				tw:box(0, 0, 0, 70, 14, 44, Pal.white, M.Marble, { name = "TowerPodium" })
				for _, sx in { -16, 16 } do
					tw:box(sx, 14, 0, 22, 240, 22, ice, M.Glass, { trans = 0.15, refl = 0.3, name = "SchoolTower" })
					tw:box(sx, 254, 0, 16, 90, 16, ice, M.Glass, { trans = 0.15, refl = 0.3 })
					tw:wedge(sx, 344, -4, 16, 40, 8, 0, Pal.white, M.Marble, { decor = true })
					tw:wedge(sx, 344, 4, 16, 40, 8, 180, Pal.white, M.Marble, { decor = true })
					for i = 0, 10 do
						tw:box(sx, 30 + i * 21, 0, 22.6, 1.4, 22.6, info.accent, M.Neon, { decor = true })
					end
				end
				for _, h in { 90, 170, 250 } do
					tw:box(0, h, 0, 12, 5, 8, ice, M.Glass, { trans = 0.2 })
				end
				topY = 384
			elseif academyId == "solcrest" then
				-- stepped sun tower with a great disc at the crown
				tw:box(0, 0, 0, 76, 16, 52, Pal.stoneWarm, M.Sandstone, { name = "TowerPodium" })
				local w, y = 54, 16
				for i = 1, 5 do
					tw:box(0, y, 0, w, 62, w * 0.72, if i % 2 == 1 then hex(0x24356a) else Pal.stoneWarm, M.SmoothPlastic, { name = "SchoolTower", refl = 0.12 })
					tw:box(0, y + 62, 0, w + 3, 2, w * 0.72 + 3, info.accent, M.Neon, { decor = true })
					y += 64
					w -= 8
				end
				local disc = tw:rod("z", 0, y + 26, 0, 24, 3, info.accent, M.Neon, { decor = true, name = "SunCrown" })
				Kit.glow(disc, 60, 3, info.accent)
				for i = 0, 11 do
					tw:piece("Block", CFrame.new(0, y + 26, 0) * CFrame.Angles(0, 0, math.rad(i * 30)) * CFrame.new(0, 32, 0), Vector3.new(2, 12, 2), info.accent, M.Neon, { decor = true })
				end
				topY = y + 52
			elseif academyId == "arcline" then
				-- round research tower wrapped in floating rings
				tw:cyl(0, 0, 0, 34, 14, Pal.deck, M.Metal, { name = "TowerPodium" })
				tw:cyl(0, 14, 0, 20, 260, hex(0x2d2748), M.SmoothPlastic, { name = "SchoolTower", refl = 0.2 })
				tw:cyl(0, 274, 0, 14, 70, hex(0x6a4fa3), M.Glass, { trans = 0.2, refl = 0.3 })
				tw:ball(0, 356, 0, 16, info.accent, M.Neon, { decor = true, trans = 0.2 })
				for i = 0, 5 do
					tw:cyl(0, 50 + i * 44, 0, 27 - i * 1.5, 2.4, info.accent, M.Neon, { decor = true })
					tw:cyl(0, 62 + i * 44, 0, 20.4, 6, hex(0xfff0c8), M.Neon, { decor = true, trans = 0.3 })
				end
				topY = 372
			else
				-- fortress high-rise with buttress fins and forge stacks
				tw:box(0, 0, 0, 78, 20, 56, hex(0x23262e), M.Concrete, { name = "TowerPodium" })
				tw:box(0, 20, 0, 50, 230, 40, hex(0x34363f), M.Concrete, { name = "SchoolTower" })
				tw:box(0, 250, 0, 58, 12, 48, hex(0x23262e), M.Metal)
				tw:box(0, 262, 0, 38, 70, 30, hex(0x34363f), M.Concrete)
				for _, sx in { -28, 28 } do
					tw:wedge(sx, 20, 0, 40, 150, 12, if sx > 0 then -90 else 90, hex(0x23262e), M.Concrete, { decor = true })
					tw:cyl(sx * 0.5, 332, 0, 5, 44, hex(0x4a3a36), M.Brick, { decor = true })
					local ember = tw:cyl(sx * 0.5, 376, 0, 4.4, 1.2, info.accent, M.Neon, { decor = true })
					Kit.glow(ember, 60, 3, info.accent)
				end
				for i = 0, 8 do
					tw:box(0, 40 + i * 24, -20.2, 30, 5, 0.6, info.accent, M.Neon, { decor = true })
				end
				topY = 378
			end
			tw:cyl(0, topY, 0, 1.6, 44, info.accent, M.Neon, { decor = true })
			local beacon = tw:ball(0, topY + 46, 0, 4, info.accent, M.Neon, { decor = true })
			Kit.glow(beacon, 60, 3, info.accent)
			local crest = tw:box(0, 20, -28.6, 40, 12, 0.6, Pal.night, M.Glass, { decor = true, name = "TowerCrest" })
			Kit.label(crest, Enum.NormalId.Front, string.upper(info.name), { color = info.accent })
			anchor("Npc_guide_" .. academyId, p, 16, 0.2, 20, 0)
			return p, info
		end

		-- Northwind: glass spires
		if ctx.school == "northwind" then
			local p, info = pavilionBase("northwind", 180)
			local ice = hex(0xbfe9ff)
			p:box(0, 0, 104, 76, 3, 72, Pal.white, M.Marble)
			p:box(0, 0, 65, 30, 1.5, 6, Pal.white, M.Marble)
			p:box(0, 3, 106, 22, 96, 22, ice, M.Glass, { trans = 0.25, refl = 0.25 })
			for _, q in { { -11.5, -11.5 }, { 11.5, -11.5 }, { -11.5, 11.5 }, { 11.5, 11.5 } } do
				p:box(q[1], 3, 106 + q[2], 2, 100, 2, Pal.white, M.Marble, { decor = true })
			end
			p:wedge(0, 99, 100.5, 22, 24, 11, 0, Pal.white, M.Marble, { decor = true })
			p:wedge(0, 99, 111.5, 22, 24, 11, 180, Pal.white, M.Marble, { decor = true })
			local tip = p:ball(0, 126, 106, 2.2, info.accent, M.Neon, { decor = true })
			Kit.glow(tip, 60, 2.5, info.accent)
			for _, sx in { -27, 27 } do
				p:box(sx, 3, 112, 14, 60, 14, Pal.white, M.Marble)
				p:box(sx, 9, 104.7, 3, 48, 0.5, info.accent, M.Neon, { decor = true })
				p:wedge(sx, 63, 108.5, 14, 14, 7, 0, ice, M.Glass, { decor = true, trans = 0.2 })
				p:wedge(sx, 63, 115.5, 14, 14, 7, 180, ice, M.Glass, { decor = true, trans = 0.2 })
			end
			p:box(0, 42, 112, 54, 3, 5, ice, M.Glass, { decor = true, trans = 0.3 })
			p:box(0, 3, 94.6, 10, 15, 0.6, info.accent, M.Neon, { decor = true, trans = 0.25 })
			for i = 0, 5 do
				p:box(0, 22 + i * 13, 94.8, 22.4, 0.6, 0.4, info.accent, M.Neon, { decor = true })
			end
			Props.fountain(p, 27, 40, 9, info.accent)
			Props.crystal(p, -27, 40, info.accent, 1.3)
			Props.tree(p, -44, 100, "pine", 1.4)
			Props.tree(p, 46, 122, "pine", 1.2)
			anchor("Npc_s1", p, -16, 0.2, 26, 80)
			anchor("Npc_s2", p, -9, 0.2, 27, -80)
			anchor("Npc_s10", p, 24, 0.2, 62, 150)
		end

		-- Solcrest: sun temple
		if ctx.school == "solcrest" then
			local p, info = pavilionBase("solcrest", 180)
			local navy = hex(0x24356a)
			p:box(0, 0, 106, 88, 1.5, 80, Pal.stoneWarm, M.Marble)
			p:box(0, 1.5, 108, 80, 1.5, 72, Pal.stoneWarm, M.Marble)
			p:box(0, 3, 110, 72, 1.5, 64, Pal.stoneWarm, M.Marble)
			for i = 0, 5 do
				Props.column(p:shift(0, 4.5, 0), -30 + i * 12, 82, 2.2, 30, Pal.white)
			end
			for _, sx in { -32, 32 } do
				for j = 1, 3 do
					Props.column(p:shift(0, 4.5, 0), sx, 82 + j * 17, 2.2, 30, Pal.white)
				end
			end
			p:box(0, 4.5, 114, 52, 28, 46, navy, M.SmoothPlastic)
			p:box(0, 4.5, 90.6, 12, 18, 0.6, info.accent, M.Neon, { decor = true, trans = 0.15 })
			p:box(0, 34.5, 108, 76, 4, 64, Pal.stoneWarm, M.Marble)
			p:box(0, 35.5, 75.8, 76, 1.2, 0.5, info.accent, M.Neon, { decor = true })
			p:wedge(-19, 38.5, 108, 64, 15, 38, 90, navy, M.Slate)
			p:wedge(19, 38.5, 108, 64, 15, 38, -90, navy, M.Slate)
			p:box(0, 53.4, 108, 1.4, 0.8, 66, info.accent, M.Neon, { decor = true })
			-- sun disc on the pediment
			local sun = p:rod("z", 0, 46, 75.4, 6, 1, info.accent, M.Neon, { decor = true, name = "SunDisc" })
			Kit.glow(sun, 50, 2.4, info.accent)
			for i = 0, 7 do
				p:piece("Block", CFrame.new(0, 46, 75.3) * CFrame.Angles(0, 0, math.rad(i * 45)) * CFrame.new(0, 9.4, 0), Vector3.new(0.9, 4.6, 0.5), info.accent, M.Neon, { decor = true })
			end
			for _, sx in { -40, 40 } do
				local f = p:shift(sx, 0, 70)
				f:cyl(0, 0, 0, 2.4, 5, Pal.white, M.Marble)
				local fire = f:cyl(0, 5, 0, 2, 1, info.accent, M.Neon, { decor = true })
				Kit.glow(fire, 40, 2, info.accent)
				Kit.sparkles(fire, info.accent, 16, { Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(20, 20), Lifetime = NumberRange.new(0.6, 1.4) })
			end
			Props.tree(p, -27, 40, "autumn", 1.2)
			Props.tree(p, 27, 40, "autumn", 1.2)
			anchor("Npc_s3", p, 14, 0.2, 24, -70)
			anchor("Npc_s4", p, 21, 0.2, 25, 75)
			anchor("Npc_s9", p, -22, 0.2, 64, -160)
		end

		-- Arcline: laboratory domes
		if ctx.school == "arcline" then
			local p, info = pavilionBase("arcline", 180)
			local violet = hex(0x6a4fa3)
			p:cyl(0, 0, 106, 46, 1.5, Pal.deck, M.SmoothPlastic)
			p:cyl(0, 1.5, 106, 46.6, 0.12, info.accent, M.Neon, { decor = true })
			p:cyl(0, 1.5, 106, 31, 4, Pal.darkMetal, M.Metal)
			p:ball(0, 5, 106, 30, violet, M.Glass, { trans = 0.4, refl = 0.2, name = "MainDome" })
			local reactor = p:ball(0, 14, 106, 9, info.accent, M.Neon, { decor = true })
			Kit.glow(reactor, 60, 2.6, info.accent)
			p:cyl(0, 1.5, 106, 3, 10, Pal.darkMetal, M.Metal, { decor = true })
			for _, q in { { -34, 132, 15 }, { 34, 132, 15 }, { 0, 150, 12 } } do
				p:cyl(q[1], 0, q[2], q[3] + 1, 3, Pal.darkMetal, M.Metal)
				p:ball(q[1], 3, q[2], q[3], violet, M.Glass, { trans = 0.35, refl = 0.2 })
				p:ball(q[1], 7, q[2], q[3] * 0.3, info.accent, M.Neon, { decor = true })
			end
			-- antenna mast
			p:cyl(33, 0, 76, 1.1, 72, Pal.darkMetal, M.Metal)
			for i, h in { 40, 52, 62 } do
				p:cyl(33, h, 76, 7.5 - i * 1.6, 0.5, info.accent, M.Neon, { decor = true })
			end
			local tip = p:ball(33, 73.5, 76, 1.8, info.accent, M.Neon, { decor = true })
			Kit.glow(tip, 60, 2.4, info.accent)
			Props.holo(p, -30, 8, 74, 16, 9, "FIELD TEST 07", info.accent, 35)
			Props.holo(p, 16, 8, 64, 12, 7, "LAB", hex(0xb6fff3), -20)
			p:ring(0, 1.5, 106, 40, 8, function(f)
				f:box(0, 0, 0, 3, 9, 3, Pal.darkMetal, M.Metal)
				f:box(0, 9, 0, 3.4, 1.2, 3.4, info.accent, M.Neon, { decor = true })
			end, 22.5)
			p:rod("x", 0, 1.2, 66, 1.2, 60, Pal.metal, M.Metal, { decor = true })
			p:rod("z", -40, 1.2, 96, 1.2, 60, Pal.metal, M.Metal, { decor = true })
			Props.tree(p, -45, 44, "round", 1.1)
			Props.tree(p, 46, 110, "round", 1.3)
			anchor("Npc_s5", p, -15, 0.2, 28, 75)
			anchor("Npc_s6", p, -8, 0.2, 30, -85)
		end

		-- Ironreach: forge keep
		if ctx.school == "ironreach" then
			local p, info = pavilionBase("ironreach", 180)
			local iron = hex(0x3a3e4a)
			local dark = hex(0x23262e)
			p:box(0, 0, 110, 66, 46, 52, iron, M.Concrete, { name = "Keep" })
			p:box(0, 46, 110, 70, 3, 56, dark, M.Metal)
			for i = -3, 3 do
				p:box(i * 10, 49, 83.5, 6, 5, 3, dark, M.Metal, { decor = true })
				p:box(i * 10, 49, 136.5, 6, 5, 3, dark, M.Metal, { decor = true })
			end
			for _, sz in { 94, 126 } do
				p:wedge(39, 0, sz, 12, 32, 12, -90, dark, M.Concrete)
				p:wedge(-39, 0, sz, 12, 32, 12, 90, dark, M.Concrete)
			end
			p:box(0, 0, 83.6, 20, 26, 1, info.accent, M.Neon, { decor = true, trans = 0.2, name = "ForgeGate" })
			for i = -2, 2 do
				p:box(i * 4, 0, 83, 0.8, 26, 0.8, dark, M.Metal, { decor = true })
			end
			p:box(0, 26, 83.2, 24, 3, 2, dark, M.Metal, { decor = true })
			for _, sx in { -24, 24 } do
				p:box(sx, 14, 83.6, 5, 12, 0.6, info.accent, M.Neon, { decor = true })
				p:box(sx, 32, 83.6, 5, 5, 0.6, info.accent, M.Neon, { decor = true })
			end
			for _, sx in { -20, 20 } do
				p:cyl(sx, 46, 120, 5.4, 36, hex(0x4a3a36), M.Brick)
				local ember = p:cyl(sx, 82, 120, 4.6, 1, info.accent, M.Neon, { decor = true })
				Kit.glow(ember, 60, 2.6, info.accent)
				Kit.sparkles(ember, info.accent, 22, { Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(14, 14), Lifetime = NumberRange.new(1.5, 3) })
				Kit.new("ParticleEmitter", {
					Texture = "rbxasset://textures/particles/smoke_main.dds",
					Color = ColorSequence.new(hex(0x55555f)),
					Rate = 6, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(6, 9),
					SpreadAngle = Vector2.new(12, 12),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 16) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
				}, ember)
			end
			for _, sx in { -30, 30 } do
				local f = p:shift(sx, 0, 68)
				f:cyl(0, 0, 0, 2.6, 4, dark, M.Metal)
				local fire = f:cyl(0, 4, 0, 2.2, 1, info.accent, M.Neon, { decor = true })
				Kit.glow(fire, 40, 2.2, info.accent)
				Kit.sparkles(fire, info.accent, 18, { Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(20, 20), Lifetime = NumberRange.new(0.6, 1.4) })
			end
			-- anvil
			p:box(22, 0.2, 40, 5, 2.4, 3, dark, M.Metal)
			p:box(22, 2.6, 40, 8, 1.6, 3.6, hex(0x555b6a), M.Metal)
			Props.tree(p, -45, 44, "pine", 1.3)
			Props.tree(p, 47, 104, "pine", 1.5)
			anchor("Npc_s7", p, 12, 0.2, 40, 60)
			anchor("Npc_s8", p, -20, 0.2, 60, -150)
		end

		-- the road from the district plaza out to the campus gate
		local len = Campus.CampusGate - 318
		local road = spoke("CampusRoad", 180, 318 + len / 2)
		road:box(0, -0.2, 0, 24, 0.34, len, hex(0x3b4152), M.Asphalt, { name = "Road" })
		road:box(0, 0.14, 0, 0.8, 0.05, len, Pal.white, M.SmoothPlastic, { decor = true })
		for _, sideSign in { -1, 1 } do
			road:box(sideSign * 11.5, 0.14, 0, 0.6, 0.06, len, ctx.accent, M.Neon, { decor = true })
		end
		local _ = prompt
	end

	local function buildGardens(ctx)
		local spoke = ctx.spoke
		-- =========================================================================================
		-- Gardens between the avenues
		-- =========================================================================================
		local function grove(s, rnd, kinds: { string })
			for i = 1, 12 do
				local x, z = rnd(-58, 58), rnd(-44, 44)
				if math.abs(x) > 9 or math.abs(z) > 30 then
					Props.tree(s, x, z, kinds[1 + (i % #kinds)], rnd(0.9, 1.5))
				end
			end
			for i = 0, 6 do
				s:cyl(math.sin(i * 0.9) * 5, 0, -42 + i * 14, 3.2, 0.25, Pal.stoneWarm, M.Marble, { decor = true })
			end
			Props.bench(s, -10, -8, -90)
			Props.bench(s, 10, 12, 90)
			for i = 1, 5 do
				Props.bush(s, rnd(-50, 50), rnd(-40, 40), if i % 2 == 0 then Pal.leafLight else Pal.blossomDeep, rnd(1.6, 2.8))
			end
			Props.bollard(s, -7, -30, Pal.lumen)
			Props.bollard(s, 7, 4, Pal.lumen)
			Props.bollard(s, -7, 34, Pal.lumen)
		end

		local function pond(s, rnd)
			s:cyl(0, 0, 0, 38, 0.1, Pal.stoneDark, M.Slate, { decor = true })
			s:cyl(0, 0.02, 0, 36, 0.14, Pal.water, M.Glass, { trans = 0.25, refl = 0.35, name = "Pond", collide = false })
			s:ring(0, 0, 0, 37, 16, function(f, i)
				f:ball(0, 0.6, 0, 2 + (i % 3) * 0.6, if i % 2 == 0 then Pal.rock else Pal.rockDark, M.Slate, { decor = true })
			end)
			s:cyl(0, 0, 0, 9, 1.1, Pal.grass, M.Grass)
			Props.tree(s:shift(0, 1.1, 0), 0, 0, "blossom", 1.25)
			s:box(-22, 0.9, 0, 30, 0.6, 6.4, Pal.wood, M.WoodPlanks)
			s:box(-39, 0, 0, 5, 0.6, 6.4, Pal.wood, M.WoodPlanks, { rot = CFrame.Angles(0, 0, math.rad(12)) })
			for _, sz in { -3.2, 3.2 } do
				s:box(-22, 1.5, sz, 30, 2, 0.3, Pal.woodDark, M.Wood, { decor = true })
			end
			for i = 1, 7 do
				local a, r = rnd(0, math.pi * 2), rnd(14, 31)
				s:cyl(math.sin(a) * r, 0.16, math.cos(a) * r, rnd(1.2, 2.2), 0.1, Pal.leafLight, M.Grass, { decor = true })
			end
			for i = 0, 3 do
				local a = math.rad(50 + i * 90)
				Props.tree(s, math.sin(a) * 50, math.cos(a) * 46, if i % 2 == 0 then "round" else "blossom", rnd(1, 1.4))
				Props.bollard(s, math.sin(a + 0.7) * 41, math.cos(a + 0.7) * 41, Pal.water)
			end
			Props.bench(s, 0, -44, 0)
		end

		local function court(s, accent: Color3)
			s:cyl(0, 0, 0, 29, 0.14, accent, M.Neon, { decor = true })
			s:cyl(0, 0, 0, 28, 0.22, Pal.stoneWarm, M.Marble)
			Props.crystal(s:shift(0, 0.22, 0), 0, 0, accent, 2.3)
			s:ring(0, 0.22, 0, 22, 6, function(f)
				Props.column(f, 0, 0, 1.5, 17, Pal.stone)
				f:cyl(0, 17, 0, 1.2, 1.2, accent, M.Neon, { decor = true })
			end, 30)
			Props.bench(s, 0, -15, 180)
			Props.bench(s, 0, 15, 0)
			for i = 0, 3 do
				local a = math.rad(45 + i * 90)
				Props.tree(s, math.sin(a) * 44, math.cos(a) * 44, "round", 1.2)
			end
		end

		local function yard(s)
			s:cyl(0, 0, 0, 25, 0.14, Pal.ember, M.Neon, { decor = true })
			s:cyl(0, 0, 0, 24, 0.22, Pal.deck, M.SmoothPlastic)
			for i = 0, 3 do
				local a = math.rad(45 + i * 90)
				local x, z = math.sin(a) * 25, math.cos(a) * 25
				s:cyl(x, 0, z, 0.7, 6, Pal.darkMetal, M.Metal)
				s:ball(x, 6.4, z, 1, Pal.ember, M.Neon, { decor = true })
				local b2 = math.rad(45 + (i + 1) * 90)
				s:bar(Vector3.new(x, 3.2, z), Vector3.new(math.sin(b2) * 25, 3.2, math.cos(b2) * 25), 0.3, Pal.cloth, M.Fabric, { decor = true })
			end
			for _, sx in { -34, 34 } do
				s:cyl(sx, 0, 0, 0.6, 7.4, Pal.wood, M.Wood)
				s:box(sx, 3.2, 0, 3, 3.8, 2.2, hex(0xb9a27a), M.Fabric)
				s:ball(sx, 8.6, 0, 1.4, hex(0xb9a27a), M.Fabric, { decor = true })
			end
			Props.bench(s, 0, -34, 180)
			Props.tree(s, -40, 34, "pine", 1.2)
			Props.tree(s, 40, 34, "pine", 1.2)
			Props.tree(s, -44, -30, "round", 1.1)
			Props.tree(s, 44, -30, "round", 1.1)
		end

		for k = 0, 7 do
			local a = 22.5 + 45 * k
			local s = spoke("Garden" .. k, a, 236)
			local rnd = Props.rng(ctx.seed + k * 77)
			s:cyl(0, -0.05, 0, 64, 0.25, Pal.grass, M.Grass, { name = "Lawn" })
			if k == 0 or k == 7 then
				grove(s, rnd, { "blossom", "round", "blossom" })
			elseif k == 3 then
				grove(s, rnd, { "pine", "round", "pine" })
			elseif k == 1 or k == 4 then
				pond(s, rnd)
			elseif k == 2 then
				court(s, Pal.lumen)
			elseif k == 6 then
				court(s, Pal.gold)
			else
				yard(s)
			end
		end
	end

	local function buildDowntown(ctx)
		local root, anchor, transit = ctx.root, ctx.anchor, ctx.transit
		-- =========================================================================================
		-- Halcyon City (far west, down the city road)
		-- =========================================================================================
		do
			local c = root
			local asphalt, kerb = hex(0x20242f), hex(0x8f97a8)
			local rndc = Props.rng(ctx.seed)
			-- the city: 560 x 560 on the ground, its paving sits just above the grass
			local city = c:shift(0, 0.15, 0)
			local H = 280
			city:box(0, -0.45, 0, 560, 0.45, 560, asphalt, M.Asphalt, { name = "CityGround" })
			for _, e in { { 0, H + 1, 564, 2 }, { 0, -(H + 1), 564, 2 }, { H + 1, 0, 2, 564 }, { -(H + 1), 0, 2, 564 } } do
				city:box(e[1], -0.3, e[2], e[3], 0.9, e[4], kerb, M.Concrete, { decor = true })
			end
			-- streets: a 4 x 4 grid of blocks, 100 studs each with 32-stud roads
			for i = -2, 2 do
				local o = i * 132
				city:box(o, 0, 0, 3, 0.06, 556, hex(0xffe9a0), M.Neon, { decor = true, trans = 0.35 })
				city:box(0, 0, o, 556, 0.06, 3, hex(0xffe9a0), M.Neon, { decor = true, trans = 0.35 })
			end
			local signs = { "RAMEN", "ARCADE", "LUMEN GEAR", "CAFE NOVA", "KARAOKE", "BOOKS", "SKY HOTEL", "CINEMA", "TEA HOUSE", "DUEL WEAR", "BAKERY", "RECORDS" }
			local neon = { hex(0xff4fd8), hex(0x39c9ff), hex(0xffc94a), hex(0x7dff7a), hex(0xb06bff), hex(0xff7a2a) }
			local n = 0
			for bx = 0, 3 do
				for bz = 0, 3 do
					local cx, cz = -198 + bx * 132, -198 + bz * 132
					local centre = (bx == 1 or bx == 2) and (bz == 1 or bz == 2)
					local blk = city:shift(cx, 0, cz)
					blk:box(0, 0, 0, 100, 0.8, 100, kerb, M.Pavement, { name = "Sidewalk" })
					if not centre then
						for q = 0, 3 do
							n += 1
							local qx, qz = (if q % 2 == 0 then -24 else 24), (if q < 2 then -24 else 24)
							local w, d = rndc(34, 44), rndc(34, 44)
							local h = rndc(50, 240)
							local tint = Kit.mix(hex(0x1c2238), hex(0x4a5270), rndc(0, 1))
							local accent = neon[1 + n % #neon]
							local tower = blk:box(qx, 0.8, qz, w, h, d, tint, M.SmoothPlastic, { name = "Building", refl = 0.12 })
							for f2 = 1, math.floor(h / 22) do
								blk:box(qx, 0.8 + f2 * 22 - 8, qz, w + 0.5, 5, d + 0.5, if f2 % 3 == 0 then accent else hex(0xfff0c8), M.Neon, { decor = true, trans = 0.3 })
							end
							blk:box(qx, h + 0.8, qz, w * 0.5, 6, d * 0.5, Pal.darkMetal, M.Metal, { decor = true })
							if n % 2 == 0 then
								-- shop front and sign facing the nearest road
								local face = if qz < 0 then Enum.NormalId.Front else Enum.NormalId.Back
								local sz2 = if qz < 0 then qz - d / 2 - 0.4 else qz + d / 2 + 0.4
								local board = blk:box(qx, 13, sz2, w * 0.8, 6, 0.6, Pal.night, M.Glass, { decor = true, name = "ShopSign" })
								Kit.label(board, face, signs[1 + n % #signs], { color = accent })
								blk:box(qx, 1, sz2, w * 0.8, 11, 0.4, accent, M.Glass, { decor = true, trans = 0.55 })
								local awn = blk:box(qx, 12.2, sz2 + (if qz < 0 then -2 else 2), w * 0.8, 0.5, 4.4, accent, M.Fabric, { decor = true })
								Kit.glow(awn, 26, 1, accent)
							end
							if n % 5 == 0 then
								local bb = blk:box(qx, h + 6.8, qz, w * 0.9, 18, 1, Pal.night, M.Glass, { decor = true, name = "Billboard" })
								Kit.label(bb, Enum.NormalId.Front, "HALCYON CLASH", { color = accent })
								Kit.label(bb, Enum.NormalId.Back, "CROWN TRIALS", { color = accent })
							end
							local _ = tower
						end
					end
					for _, cnr in { { -46, -46 }, { 46, -46 }, { -46, 46 }, { 46, 46 } } do
						Props.lamp(blk:shift(cnr[1], 0.8, cnr[2], if cnr[1] > 0 then 90 else -90), 0, 0, neon[1 + (bx + bz) % #neon], cnr[1] > 0 and cnr[2] > 0, 13)
					end
				end
			end
			-- Central Square: four blocks merged around a fountain and a clock tower
			city:cyl(0, 0.8, 0, 62, 0.2, Pal.stoneWarm, M.Marble, { name = "CitySquare" })
			city:cyl(0, 0.8, 0, 63.5, 0.1, hex(0xff4fd8), M.Neon, { decor = true })
			Props.fountain(city:shift(0, 1, 0), 0, 44, 13, hex(0x39c9ff))
			Props.fountain(city:shift(0, 1, 0), 0, -44, 13, hex(0xff4fd8))
			city:box(0, 1, 0, 16, 120, 16, Pal.stoneWarm, M.Marble, { name = "ClockTower" })
			city:box(0, 121, 0, 20, 4, 20, Pal.gold, M.Metal, { decor = true })
			local clock = city:box(0, 96, 0, 16.6, 16, 16.6, Pal.night, M.Glass, { decor = true, name = "ClockFace" })
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
				Kit.label(clock, face, "XII", { color = Pal.gold })
			end
			city:wedge(0, 125, -5, 20, 22, 10, 0, hex(0x8a2f3a), M.Slate, { decor = true })
			city:wedge(0, 125, 5, 20, 22, 10, 180, hex(0x8a2f3a), M.Slate, { decor = true })
			for i = 0, 7 do
				local a = math.rad(22.5 + i * 45)
				Props.tree(city:shift(0, 1, 0), math.sin(a) * 52, math.cos(a) * 52, if i % 2 == 0 then "blossom" else "round", 1.1)
				Props.bench(city:shift(0, 1, 0), math.sin(a) * 36, math.cos(a) * 36, math.deg(a))
			end
			-- parked hover cars
			for i = 1, 10 do
				local road = (math.floor(rndc(0, 4.99)) - 2) * 132
				local along = rndc(-250, 250)
				local col = neon[1 + i % #neon]
				local car = if i % 2 == 0 then city:shift(road + 9, 1.6, along, 0) else city:shift(along, 1.6, road + 9, 90)
				car:box(0, 0, 0, 7, 2.2, 15, col, M.SmoothPlastic, { refl = 0.3 })
				car:box(0, 2.2, -0.5, 6.2, 2, 8, Pal.night, M.Glass, { decor = true, trans = 0.2 })
				car:box(0, -0.5, 0, 6, 0.4, 13, col, M.Neon, { decor = true })
			end
			for _, spot in ctx.cityNpcs or {} do
				anchor("Npc_" .. spot[1], city, spot[2], 1, spot[3], spot[4])
			end
			transit(city, 0, 120)
		end

	end

	local function buildMonorail(ctx)
		local root = ctx.root
		-- =========================================================================================
		-- The monorail: an elevated loop around the centre, on white pillars
		-- =========================================================================================
		do
			local rail = root:group("Monorail")
			local RR, H = 575, 34
			local seg = 2 * math.pi * RR / 48 + 0.6
			rail:ring(0, H, 0, RR, 48, function(f)
				f:box(0, 0, 0, seg, 3, 9, Pal.white, M.SmoothPlastic, { name = "Track" })
				f:box(0, 3, -3, seg, 0.5, 0.6, Pal.lumen, M.Neon, { decor = true })
				f:box(0, 3, 3, seg, 0.5, 0.6, Pal.lumen, M.Neon, { decor = true })
			end)
			rail:ring(0, 0, 0, RR, 24, function(f)
				f:cyl(0, 0, 0, 2.6, H, Pal.white, M.SmoothPlastic)
				f:box(0, H - 4, 0, 4, 4, 12, Pal.white, M.SmoothPlastic, { decor = true })
			end, 7.5)
			-- two trains, four cars each, curving around the loop
			for t = 0, 1 do
				for c = 0, 3 do
					local a = math.rad(t * 180 + 20 + c * 6.2)
					local pos = Vector3.new(math.sin(a) * RR, H + 3.5, math.cos(a) * RR)
					local fwd = Vector3.new(math.cos(a), 0, -math.sin(a))
					local cf = CFrame.lookAt(pos + Vector3.new(0, 4, 0), pos + Vector3.new(0, 4, 0) + fwd)
					rail:piece("Block", cf, Vector3.new(8, 8, 58), Pal.white, M.SmoothPlastic, { decor = true, name = "TrainCar" })
					rail:piece("Block", cf * CFrame.new(0, 1, 0), Vector3.new(8.3, 2.6, 52), hex(0x2a3a5a), M.Glass, { decor = true, trans = 0.1 })
					rail:piece("Block", cf * CFrame.new(0, -3.2, 0), Vector3.new(8.4, 0.6, 58), if t == 0 then Pal.lumen else Pal.gold, M.Neon, { decor = true })
				end
			end
		end

	end

	local function buildSkyTower(ctx, plaza)
		local anchor, prompt = ctx.anchor, ctx.prompt
		-- The Halcyon Spire: a hexagonal tower in the middle of the city, carrying the Sky Arena where the
		-- tournaments are held. The Skylift at its foot carries students to the top and back.
		local spire = plaza:group("HalcyonSpire")
		local TOP = Campus.SkyArenaY
		local S = Campus.SkyArenaScale
		local white = hex(0xf2f5fb)
		local glassBlue = hex(0x9fd8ff)
		-- base: a stepped hexagonal podium
		for i, r in { 30, 26, 22 } do
			for k = 0, 2 do
				spire:box(0, 0.66 + (i - 1) * 2, 0, r * 2, 2, r * 2 / math.sqrt(3), if i == 2 then Pal.slate else white, M.Marble, { rot = CFrame.Angles(0, math.rad(k * 60), 0) })
			end
		end
		spire:cyl(0, 6.66, 0, 21, 0.2, Pal.lumen, M.Neon, { decor = true })
		-- the shaft: glass hexagon with white ribs at every corner
		local shaftY, shaftH = 6.7, TOP - 142 - 6.7
		for k = 0, 2 do
			spire:box(0, shaftY, 0, 28, shaftH, 28 / math.sqrt(3), glassBlue, M.Glass, { trans = 0.35, refl = 0.25, shadow = false, rot = CFrame.Angles(0, math.rad(k * 60), 0), name = "SpireShaft" })
		end
		local core = spire:cyl(0, shaftY, 0, 3.2, shaftH, Pal.lumen, M.Neon, { decor = true, name = "SpireCore" })
		Kit.glow(core, 60, 2.2, Pal.lumen)
		for k = 0, 5 do
			local a = math.rad(30 + k * 60)
			spire:box(math.sin(a) * 16.2, shaftY, math.cos(a) * 16.2, 2.6, shaftH, 2.6, white, M.SmoothPlastic, { rot = CFrame.Angles(0, a, 0) })
			spire:box(math.sin(a) * 17.6, shaftY, math.cos(a) * 17.6, 0.5, shaftH, 0.5, Pal.lumen, M.Neon, { decor = true })
		end
		-- observation rings up the shaft
		for i, h in { 120, 240, 360 } do
			spire:cyl(0, h, 0, 26 - i * 2, 4, white, M.SmoothPlastic, { decor = true })
			spire:cyl(0, h + 4, 0, 26.5 - i * 2, 0.6, if i % 2 == 0 then Pal.gold else Pal.lumen, M.Neon, { decor = true })
			spire:cyl(0, h - 6, 0, 24 - i * 2, 6, glassBlue, M.Glass, { decor = true, trans = 0.2 })
		end
		-- the crown: six struts flaring out to carry the arena
		local crownY = TOP - 142
		for k = 0, 5 do
			local a = math.rad(k * 60)
			spire:bar(Vector3.new(math.sin(a) * 15, crownY - 90, math.cos(a) * 15), Vector3.new(math.sin(a) * 92, TOP - 70, math.cos(a) * 92), 7, white, M.SmoothPlastic)
			spire:bar(Vector3.new(math.sin(a) * 18, crownY - 86, math.cos(a) * 18), Vector3.new(math.sin(a) * 95, TOP - 66, math.cos(a) * 95), 1, Pal.lumen, M.Neon, { decor = true })
		end
		spire:cyl(0, crownY, 0, 46, 13, white, M.SmoothPlastic)
		spire:cyl(0, crownY + 12, 0, 46.5, 1, Pal.lumen, M.Neon, { decor = true })
		-- the Sky Arena itself
		local skyArena = Arena.build(spire.parent, { name = "SkyArena", skyline = false, shell = hex(0xeef2f8) })
		-- the arena is built around the origin: scale it up, then lift it onto the tower
		-- (its pivot carries the round floor's tilt, so move it by an offset rather than to a fixed CFrame)
		Kit.scale(skyArena, S, CFrame.new())
		skyArena:PivotTo(spire.cf * CFrame.new(0, TOP, 0) * skyArena:GetPivot())
		for _, d in skyArena:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Jumbotron" then
				local text = d:FindFirstChildWhichIsA("TextLabel", true)
				if text then
					text.Text = "SKY ARENA"
				end
			end
		end
		-- the Skylift: a glass lobby at the foot of the tower, and an arrival pad up top
		for _, yaw in { 0, 180 } do
			local f = spire:shift(0, 0, 0, yaw)
			f:box(0, 6.66, 15.2, 12, 16, 3, glassBlue, M.Glass, { trans = 0.3, name = "LiftDoor" })
			f:box(0, 22.66, 15.6, 14, 1, 4, Pal.lumen, M.Neon, { decor = true })
			f:box(0, 0.66, 22, 14, 6.1, 10, white, M.Marble)
			local pad = f:cyl(0, 6.76, 21, 5, 0.3, Pal.lumen, M.Neon, { name = "SkyliftPad" })
			prompt(pad, "lift:up", "Ride the Skylift", "To the Sky Arena", 14)
			local sign = f:box(0, 24, 16, 22, 4, 0.6, Pal.night, M.Glass, { decor = true })
			Kit.label(sign, Enum.NormalId.Back, "SKYLIFT  ▲  SKY ARENA", { color = Pal.lumen })
			anchor("LiftBottom_" .. yaw, f, 0, 9, 30, 0)
		end
		-- stairs up to the lift lobby
		for _, yaw in { 0, 180 } do
			local f = spire:shift(0, 0, 0, yaw)
			for st = 0, 5 do
				f:box(0, 0.66, 27 + st * 1.6, 14, 6 - st, 1.6, white, M.Marble)
			end
		end
		local topPad = spire:cyl(0, TOP + 0.2, 51 * S, 4.5, 0.3, Pal.lumen, M.Neon, { name = "SkyliftTop" })
		prompt(topPad, "lift:down", "Ride the Skylift", "Down to the city", 12)
		anchor("LiftTop", spire, 0, TOP + 3, 51 * S, 180)
		anchor("Npc_isolde", spire, 14, TOP, 54 * S, 180)
		anchor("Return_trials", spire, 0, TOP + 3, 46 * S, 180)
		anchor("Zone_sky", spire, 0, TOP, 0):SetAttribute("Radius", 44 * S)
		Kit.sparkles(core, Pal.lumen, 10, { Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(2, 4) })

		return spire
	end

	-- =========================================================================================
	-- Build every region
	-- =========================================================================================
	for _, r in REGIONS do
		local ctx = makeCtx(r)
		if r.kind == "centre" then
			local plaza = buildPlaza(ctx)
			buildSkyTower(ctx, plaza)
			buildPlanters(plaza)
			buildAvenues(ctx)
			buildGardens(ctx)
			buildMonorail(ctx)
			ctx.transit(plaza, 0, 64)
			ctx.anchor("Npc_maren", plaza, -18, 0.6, 70, 0)
			ctx.anchor("Return_Default", plaza, 0, 3.5, 82, 0)
		elseif r.kind == "school" then
			local plaza = buildPlaza(ctx)
			buildSchoolSpire(ctx, plaza)
			buildSeats(ctx, plaza)
			buildPlanters(plaza)
			buildAvenues(ctx)
			buildArrival(ctx)
			buildTrainingHall(ctx)
			buildMarket(ctx)
			buildCampus(ctx)
			buildGardens(ctx)
		else
			buildDowntown(ctx)
		end
	end
	-- Tilly's stall and its shop street sit in one city, beside its downtown
	for _, r in REGIONS do
		if r.tilly then
			local ctx = makeCtx(r)
			ctx.root = ctx.root:shift(0, 0, 0, 0)
			local s = ctx.spoke
			ctx.spoke = function(name, _, _)
				return s(name, 90, 330 + 60)
			end
			buildMarket(ctx)
		end
	end

	-- =========================================================================================
	-- City blocks: every free 130-stud cell on land gets something. The mix depends on the island:
	-- school districts lean to housing and parks in the school's colours, city districts to towers
	-- and shop streets, the centre to plazas and gardens.
	-- =========================================================================================
	do
		local CELL = 150
		local hood = Kit.at(world, CFrame.new()):group("CityBlocks")
		local counts = {}
		local rnd = Props.rng(424242)
		local function free(x: number, z: number): boolean
			if not Campus.inside(x, z, 70) or nearBridgeEnd(Vector3.new(x, 0, z), 40) then
				return false
			end
			for _, r in REGIONS do
				if hexInside(r, x, z, -5) then
					local lp = r.cf:PointToObjectSpace(Vector3.new(x, 0, z))
					if reserved(r, lp.X, lp.Z) then
						return false
					end
				end
			end
			return true
		end
		local n = math.ceil((RING + 1500) / CELL)
		for ix = -n, n do
			for iz = -n, n do
				local cx, cz = ix * CELL, iz * CELL
				local h = CELL / 2 - 6
				if free(cx, cz) and free(cx - h, cz - h) and free(cx + h, cz - h) and free(cx - h, cz + h) and free(cx + h, cz + h) then
					local r = regionAt(cx, cz, 0)
					local accent = r and r.accent or Pal.lumen
					local top = r and r.top or 0
					local lp = if r then r.cf:PointToObjectSpace(Vector3.new(cx, 0, cz)) else Vector3.zero
					local yaw = (r and math.deg(math.atan2(r.cf.LookVector.X, r.cf.LookVector.Z)) or 0) + (math.floor(((math.deg(math.atan2(lp.X, lp.Z)) % 360) + 45) / 90) % 4) * 90 + 180
					local rc = (Vector3.new(cx, 0, cz)).Magnitude
					local underRail = r and r.kind == "centre" and rc > 515 and rc < 640
					local roll = rnd()
					local w = { highrise = 0.4, shops = 0.14, plaza = 0.14, park = 0.14, canal = 0.1, court = 0.08 }
					if r and r.kind == "school" then
						w = { highrise = 0.36, shops = 0.1, plaza = 0.12, park = 0.22, canal = 0.08, court = 0.12 }
					elseif r and r.kind == "centre" then
						w = { highrise = 0.25, shops = 0.15, plaza = 0.3, park = 0.2, canal = 0.05, court = 0.05 }
					end
					if underRail then
						w.highrise = 0
					end
					local kind
					local acc = 0
					for _, k in { "highrise", "shops", "plaza", "park", "canal", "court" } do
						acc += w[k]
						if roll < acc then
							kind = k
							break
						end
					end
					kind = kind or "park"
					local cell = hood:shift(cx, top, cz, yaw)
					-- avenue lamps: only one in four lit (each light costs frame time on phones)
					if kind == "highrise" then
						cell:box(0, -0.05, -52, CELL, 0.3, 14, hex(0x3b4152), M.Asphalt, { decor = true })
						cell:box(0, 0.25, -52, CELL, 0.05, 0.6, Pal.white, M.SmoothPlastic, { decor = true })
						Props.highrise(cell, -30, 6, 0, rnd, if r and r.kind == "city" then 220 else 150)
						Props.highrise(cell, 32, 10, 0, rnd, 120)
						Props.lamp(cell:shift(0, 0, -44, 180), 0, 0, accent, false, 12)
					elseif kind == "shops" then
						cell:box(0, -0.05, -48, CELL, 0.3, 14, hex(0x3b4152), M.Asphalt, { decor = true })
						Props.shopRow(cell, 0, -10, 0, rnd)
						Props.tree(cell, -40, 40, "blossom", 1.1)
						Props.tree(cell, 40, 40, "round", 1.1)
					elseif kind == "plaza" then
						Props.plaza(cell, 0, 0, rnd)
					elseif kind == "park" then
						Props.park(cell, 0, 0, rnd)
					elseif kind == "canal" then
						Props.canal(cell, 0, 0, 0, rnd)
					else
						Props.court(cell, -28, 0, 0, rnd)
						Props.court(cell, 28, 0, 0, rnd)
					end
					counts[kind] = (counts[kind] or 0) + 1
				end
			end
		end
		Campus.FillCounts = counts
	end


	-- =========================================================================================
	-- Distant skyline: towers standing in the lake beyond the islands
	-- =========================================================================================
	do
		local sky = Kit.at(world, CFrame.new()):group("Skyline")
		local accents = { Pal.lumen, Pal.gold, hex(0xe14bff), Pal.ember }
		local rnd = Props.rng(9001)
		for i = 1, 24 do
			local a = math.rad(i * 15 + rnd(-5, 5))
			local d = rnd(4700, 5300)
			local w, h = rnd(90, 170), rnd(600, 1200)
			local f = sky:shift(math.sin(a) * d, 0, math.cos(a) * d, rnd(0, 90))
			f:box(0, -30, 0, w * 1.8, 30, w * 1.8, hex(0x2a3148), M.Concrete, { decor = true })
			f:box(0, 0, 0, w, h, w, hex(0x1c2742), M.SmoothPlastic, { decor = true })
			f:box(0, h, 0, w * 0.6, h * 0.16, w * 0.6, hex(0x1c2742), M.SmoothPlastic, { decor = true })
			f:cyl(0, h * 1.16, 0, 2, h * 0.12, accents[1 + i % 4], M.Neon, { decor = true })
			for j = 1, 5 do
				f:box(0, h * (0.12 + 0.17 * (j - 1)), 0, w + 0.6, h * 0.025, w + 0.6, if j % 2 == 0 then accents[1 + i % 4] else hex(0xffe9b0), M.Neon, { decor = true })
			end
		end
	end

end

--- Builds the whole world under `parent` and returns its root folder.
function Campus.build(parent: Instance): Instance
	local world = Instance.new("Folder")
	world.Name = Config.WorldName
	build(world)
	world.Parent = parent
	return world
end

return Campus
