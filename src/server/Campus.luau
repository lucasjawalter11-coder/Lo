--!nonstrict
-- Campus: the Halcyon Concourse, a floating island shared by the four academies.
--
-- Layout (top view, +Z is south):
--   centre      the Register Plaza: the spire, the Register boards and the ring of twelve seats
--   south       the Skydock, where students arrive
--   east        the Training Hall
--   north       the Crown Arena and the Crown Gate
--   west        the Market Arcade
--   diagonals   the four academy pavilions (SE Solcrest, NE Northwind, NW Ironreach, SW Arcline)
-- Angles below use: position = (sin a, cos a) * radius, so 0 = south, 90 = east, 180 = north, 270 = west.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Roster = require(Shared:WaitForChild("Roster"))
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local M = Enum.Material
local Pal = Props.Pal
local hex = Kit.hex

local Campus = {}

Campus.IslandRadius = 520
Campus.PlazaRadius = 124

-- Where each default seat-holder stands on the plaza ring (degrees). Rookies stand near the Skydock,
-- the Crownbearer stands in front of the Crown Arena.
local SEAT_ANGLES = { 195, 165, 225, 135, 255, 105, 285, 75, 315, 45, 345, 15 }

local DIAGONALS = { [45] = "solcrest", [135] = "northwind", [225] = "ironreach", [315] = "arcline" }

local function polar(aDeg: number, r: number): (number, number)
	local a = math.rad(aDeg)
	return math.sin(a) * r, math.cos(a) * r
end

local function build(world: Instance)
	local root = Kit.at(world, CFrame.new())
	local anchors = Kit.new("Folder", { Name = "Anchors" }, world)

	--- A frame on the circle of radius r at angle a. Its -Z looks at the island centre, +Z points outward.
	local function spoke(name: string, aDeg: number, r: number)
		local x, z = polar(aDeg, r)
		return root:group(name, x, 0, z, aDeg)
	end

	--- An invisible marker other code looks up by name (NPC posts, return points).
	local function anchor(name: string, frame, x: number, y: number, z: number, yawDeg: number?)
		local cf = frame.cf * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
		Kit.part(anchors, "Block", Vector3.new(1, 1, 1), cf, Pal.white, M.SmoothPlastic, { name = name, trans = 1, decor = true })
	end

	local function prompt(part: BasePart, open: string, action: string, object: string, distance: number?)
		local p = Kit.new("ProximityPrompt", {
			Name = "HalcyonPrompt",
			ActionText = action,
			ObjectText = object,
			HoldDuration = 0,
			MaxActivationDistance = distance or 18,
			RequiresLineOfSight = false,
			KeyboardKeyCode = Enum.KeyCode.E,
			GamepadKeyCode = Enum.KeyCode.ButtonX,
		}, part)
		p:SetAttribute("Open", open)
		return p
	end

	-- =========================================================================================
	-- The island itself
	-- =========================================================================================
	local island = root:group("Island")
	island:cyl(0, -30, 0, 520, 30, Pal.grass, M.Grass, { name = "Ground" })
	island:cyl(0, -66, 0, 474, 36, Pal.rock, M.Slate, { decor = true })
	island:cyl(0, -68, 0, 482, 2.5, Pal.lumen, M.Neon, { decor = true })
	island:cyl(0, -116, 0, 372, 50, Pal.rockDark, M.Slate, { decor = true })
	island:cyl(0, -180, 0, 246, 64, Pal.rockDark, M.Slate, { decor = true })
	island:cyl(0, -264, 0, 124, 84, hex(0x2c303d), M.Slate, { decor = true })
	local engine = island:cyl(0, -276, 0, 60, 12, Pal.lumen, M.Neon, { decor = true })
	Kit.glow(engine, 60, 3, Pal.lumen)

	-- Rim: a kerb, a glass rail, a glowing handrail and an invisible wall so nobody walks off the edge.
	island:ring(0, 0, 0, 512, 72, function(f, i)
		if i == 54 then
			return -- gap for the bridge to Halcyon City
		end
		f:box(0, 0, 0, 45.4, 2.4, 5, Pal.stoneDark, M.Marble)
		f:box(0, 2.4, 0.6, 45, 4.2, 0.3, Pal.glass, M.Glass, { trans = 0.6, shadow = false })
		f:box(0, 6.6, 0.6, 45.2, 0.35, 0.6, Pal.lumen, M.Neon, { decor = true })
		f:box(0, 0, 3.4, 45.8, 90, 1.6, Pal.white, M.SmoothPlastic, { trans = 1, name = "Barrier", shadow = false })
	end)

	-- =========================================================================================
	-- Register Plaza
	-- =========================================================================================
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

	-- The spire
	local spire = plaza:group("RegisterSpire")
	spire:cyl(0, 0.66, 0, 15, 1.4, Pal.slate, M.Marble)
	spire:cyl(0, 2.06, 0, 12.6, 0.3, Pal.lumen, M.Neon, { decor = true })
	spire:cyl(0, 2.06, 0, 12, 1.0, Pal.stone, M.Marble)
	spire:cyl(0, 3.06, 0, 3.4, 104, Pal.glass, M.Glass, { trans = 0.5, shadow = false })
	local core = spire:cyl(0, 3.06, 0, 1.4, 108, Pal.lumen, M.Neon, { decor = true, name = "SpireCore" })
	Kit.glow(core, 60, 2.2, Pal.lumen)
	for i, h in { 34, 54, 74, 92 } do
		local r = 15 - i * 2.2
		local seg = 2 * math.pi * r / 14 + 0.25
		spire:ring(0, h, 0, r, 14, function(f)
			f:box(0, 0, 0, seg, 1.3, 0.9, if i % 2 == 0 then Pal.lumen else Pal.gold, M.Neon, { decor = true })
		end)
	end
	spire:ring(0, 110, 0, 4.4, 6, function(f)
		f:wedge(0, 0, 0, 2.4, 8, 3.4, 0, Pal.gold, M.Neon, { decor = true })
	end)
	local star = spire:ball(0, 121, 0, 3, Pal.white, M.Neon, { decor = true, name = "SpireStar" })
	Kit.glow(star, 60, 3, Pal.gold)
	Kit.sparkles(core, Pal.lumen, 10, { Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(2, 4) })

	-- Register boards, one facing the Skydock and one facing the Crown Arena
	for _, yaw in { 0, 180 } do
		local f = spire:shift(0, 0, 0, yaw)
		for _, sx in { -21, 21 } do
			f:box(sx, 0.66, 19.5, 2.6, 27, 2.6, Pal.darkMetal, M.Metal)
			f:box(sx, 27.66, 19.5, 3.2, 0.7, 3.2, Pal.lumen, M.Neon, { decor = true })
		end
		f:box(0, 4.3, 19.5, 40, 0.7, 1.4, Pal.lumen, M.Neon, { decor = true })
		f:box(0, 26, 19.5, 40, 0.7, 1.4, Pal.lumen, M.Neon, { decor = true })
		local board = f:box(0, 5, 19.5, 39.4, 21, 0.8, Pal.night, M.Glass, { trans = 0.12, name = "RegisterBoard" })
		Kit.label(board, Enum.NormalId.Back, "THE REGISTER", { color = Pal.lumen, sizeY = 0.3, name = "Baked" })
		prompt(board, "register", "Read", "The Register", 30)
	end

	-- The ring of seats
	for i, npc in Roster.Seats do
		local a = SEAT_ANGLES[i]
		local x, z = polar(a, 84)
		local f = plaza:shift(x, 0, z, a)
		f:cyl(0, 0.42, 0, 5.6, 0.22, npc.look.accent, M.Neon, { decor = true })
		f:cyl(0, 0.42, 0, 5.1, 0.9, Pal.slate, M.Marble, { name = "SeatPedestal" })
		f:box(0, 0.42, -7.4, 5.4, 0.3, 2, npc.look.accent, M.Neon, { decor = true, trans = 0.2 })
		anchor("Npc_" .. npc.id, f, 0, 1.32, 0, 0)
		anchor("Return_" .. npc.id, f, 0, 0.6, -12, 180)
	end

	-- Planters and benches between the avenue mouths
	for k = 0, 7 do
		local a = 22.5 + 45 * k
		local x, z = polar(a, 108)
		local f = plaza:shift(x, 0.3, z, a)
		Props.planter(f, 0, 0, 15, if k % 2 == 0 then "blossom" else "round")
		Props.bench(f, -13, -1, 90)
		Props.bench(f, 13, -1, -90)
	end

	-- =========================================================================================
	-- Avenues
	-- =========================================================================================
	for k = 0, 7 do
		local a = 45 * k
		local academy = DIAGONALS[a]
		local accent = if academy then Config.Academies[academy].accent else Pal.lumen
		local width = if academy then 24 else 32
		local av = spoke("Avenue" .. k, a, 218)
		av:box(0, -0.2, 0, width, 0.34, 200, Pal.stone, M.Marble, { name = "Road" })
		av:box(0, 0.14, 0, width * 0.34, 0.05, 200, Pal.stoneWarm, M.Marble, { decor = true })
		for _, side in { -1, 1 } do
			av:box(side * (width / 2 - 0.5), 0.14, 0, 0.6, 0.06, 200, accent, M.Neon, { decor = true })
			for j = 0, 4 do
				local lz = -80 + j * 40
				Props.lamp(av:shift(side * (width / 2 + 3.5), 0, lz, side * 90), 0, 0, accent, (j + (if side > 0 then 0 else 1)) % 2 == 0)
			end
			for j = 0, 3 do
				local kind = if academy == "solcrest" then "autumn" elseif academy == "ironreach" then "pine" elseif academy then "round" else "blossom"
				Props.tree(av, side * (width / 2 + 11), -60 + j * 40, kind, 1.0 + ((j + k) % 3) * 0.12)
			end
		end
		if academy then
			Props.banner(av, width / 2 + 5, -96, accent, 28, 0)
			Props.banner(av, -(width / 2 + 5), -96, accent, 28, 180)
		end
	end

	-- =========================================================================================
	-- Skydock (south): arrival terrace and spawn
	-- =========================================================================================
	do
		local d = spoke("Skydock", 0, 330)
		d:box(0, -0.2, 76, 124, 0.4, 152, Pal.stone, M.Marble, { name = "Terrace" })
		d:box(0, 0.2, 76, 30, 0.05, 150, Pal.stoneWarm, M.Marble, { decor = true })
		-- welcome arch
		for _, sx in { -21, 21 } do
			d:box(sx, 0, -6, 4, 30, 4, Pal.darkMetal, M.Metal)
			d:box(sx, 3, -6, 4.4, 22, 0.5, Pal.lumen, M.Neon, { decor = true, rot = CFrame.Angles(0, math.rad(90), 0) })
		end
		local beam = d:box(0, 30, -6, 50, 5, 4, Pal.night, M.Metal, { name = "WelcomeArch" })
		Kit.label(beam, Enum.NormalId.Back, "HALCYON CONCOURSE", { color = Pal.lumen })
		Kit.label(beam, Enum.NormalId.Front, "SKYDOCK", { color = Pal.gold })
		d:box(0, 35, -6, 52, 0.6, 4.6, Pal.lumen, M.Neon, { decor = true })
		-- spawn pad
		d:cyl(0, 0.2, 44, 9.6, 0.08, Pal.lumen, M.Neon, { decor = true })
		d:cyl(0, 0.2, 44, 9, 0.14, Pal.slate, M.Marble, { refl = 0.2 })
		local spawn = Kit.new("SpawnLocation", {
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
		spawn.CastShadow = false
		anchor("Npc_maren", d, -15, 0.2, 12, 180)
		anchor("Return_Default", d, 0, 0.6, 30, 0)
		-- dock masts and the docked airship
		for _, sx in { -54, 54 } do
			d:cyl(sx, 0, 138, 1.6, 56, Pal.darkMetal, M.Metal)
			local beacon = d:ball(sx, 58, 138, 2.6, Pal.lumen, M.Neon, { decor = true })
			Kit.glow(beacon, 60, 2, Pal.lumen)
			d:bar(Vector3.new(sx, 50, 138), Vector3.new(sx * 0.35, 20, 190), 0.4, Pal.darkMetal, M.Metal, { decor = true })
		end
		Props.airship(d, 0, 9, 204, 90, Pal.lumen, 1.25)
		d:box(0, 3.6, 172, 12, 0.6, 44, Pal.metal, M.DiamondPlate, { decor = true, rot = CFrame.Angles(math.rad(-7), 0, 0) })
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
		local rackColors = { Pal.lumen, Pal.gold, hex(0xe14bff), Pal.ember, hex(0x7dff7a), hex(0xff4fd8) }
		for i, c in rackColors do
			local sx = -35 + (i - 1) * 14
			t:box(sx, 6, 131.4, 1, 3, 0.8, Pal.darkMetal, M.Metal, { decor = true })
			t:box(sx, 9, 131.4, 0.9, 10 + (i % 3) * 2, 0.5, c, M.Neon, { decor = true })
			t:box(sx, 5.4, 131.2, 6, 0.6, 1.2, Pal.woodDark, M.Wood, { decor = true })
		end
		-- training dummies
		for _, p in { { -32, 34 }, { 32, 34 }, { -32, 100 }, { 32, 100 } } do
			local f = t:shift(p[1], 1.6, p[2])
			f:cyl(0, 0, 0, 1.6, 0.6, Pal.darkMetal, M.Metal)
			f:cyl(0, 0.6, 0, 0.6, 7, Pal.wood, M.Wood)
			f:box(0, 3.4, 0, 3, 3.8, 2.2, hex(0xb9a27a), M.Fabric)
			f:box(0, 6, 0, 7, 0.8, 0.8, Pal.wood, M.Wood, { decor = true })
			f:ball(0, 8.9, 0, 1.4, hex(0xb9a27a), M.Fabric, { decor = true })
			f:box(0, 4.8, -1.2, 1.6, 1.6, 0.2, Pal.ember, M.Neon, { decor = true })
		end
		anchor("Npc_brandt", t, 0, 1.6, 114, 0)
		anchor("Return_brandt", t, 0, 1.9, 96, 180)
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
		-- Lumen Exchange: the shop
		local s = k:shift(0, 0.2, 138)
		s:cyl(0, 0, 0, 18, 1.2, Pal.slate, M.Marble, { name = "ExchangeFloor" })
		s:cyl(0, 1.2, 0, 18.4, 0.1, teal, M.Neon, { decor = true })
		s:ring(0, 1.2, 0, 11.5, 9, function(f)
			f:box(0, 0, 0, 7.4, 3.8, 2.2, Pal.woodDark, M.Wood)
			f:box(0, 3.8, 0, 7.8, 0.4, 2.8, teal, M.Neon, { decor = true })
		end, 100, 160)
		for _, p in { { -13, -8 }, { 13, -8 }, { -13, 10 }, { 13, 10 } } do
			s:cyl(p[1], 1.2, p[2], 0.7, 17, Pal.darkMetal, M.Metal)
		end
		s:cyl(0, 18.2, 0, 20, 1.6, teal, M.SmoothPlastic)
		s:cyl(0, 19.8, 0, 14, 1.4, Kit.shade(teal, 0.75), M.SmoothPlastic, { decor = true })
		local coin = s:rod("z", 0, 28, 0, 5.4, 1.4, Pal.gold, M.Neon, { decor = true, name = "ShopCoin" })
		s:rod("z", 0, 28, 0, 3.6, 1.6, hex(0xfff3c2), M.Neon, { decor = true })
		Kit.glow(coin, 50, 2.2, Pal.gold)
		Props.holo(s, 0, 20.6, -17, 30, 5, "LUMEN EXCHANGE", Pal.gold, 0, "ShopSign")
		anchor("Npc_tilly", s, 0, 1.2, 2, 0)
		anchor("Return_tilly", s, 0, 0.6, -22, 180)
		-- showcase podiums
		local aura = s:cyl(-26, 0, -6, 4, 2, Pal.slate, M.Marble)
		local orb = s:ball(-26, 6, -6, 2.2, hex(0x7dff7a), M.Neon, { decor = true })
		Kit.sparkles(orb, hex(0x7dff7a), 16)
		Kit.glow(aura, 24, 1.2, hex(0x7dff7a))
		s:cyl(26, 0, -6, 4, 2, Pal.slate, M.Marble)
		s:cyl(26, 2, -6, 0.5, 7, Pal.darkMetal, M.Metal, { decor = true })
		s:box(26, 4.4, -5.2, 5, 6.4, 0.4, hex(0xb0243a), M.Fabric, { decor = true, rot = CFrame.Angles(math.rad(8), 0, 0) })
		s:box(26, 9.4, -6, 6, 0.8, 1.2, Pal.gold, M.Metal, { decor = true })
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

	-- =========================================================================================
	-- Crown Arena (north)
	-- =========================================================================================
	do
		local c = spoke("CrownArena", 180, 318)
		c:box(0, -0.2, 50, 136, 0.4, 100, Pal.stone, M.Marble)
		c:box(0, 0.2, 34, 22, 0.05, 68, Pal.gold, M.Marble, { decor = true })
		c:box(0, 0, 5, 66, 1, 4, Pal.stoneDark, M.Marble)
		c:box(0, 0, 8.5, 66, 2, 3, Pal.stoneDark, M.Marble)
		c:box(0, 0, 22, 66, 3, 24, Pal.slate, M.Marble, { name = "GatePlatform" })
		-- the drum
		c:cyl(0, 0, 110, 76, 44, Pal.stone, M.Marble, { name = "ArenaDrum" })
		c:cyl(0, 44, 110, 80, 5, Pal.slate, M.Marble)
		c:cyl(0, 49, 110, 74, 2.5, Pal.gold, M.Neon, { decor = true })
		c:cyl(0, 51.5, 110, 68, 5, Pal.night, M.Glass, { decor = true, trans = 0.15, refl = 0.3 })
		c:ring(0, 0, 110, 77, 20, function(f, i)
			if i == 10 then
				return
			end
			f:box(0, 0, 0, 6, 44, 3.2, Pal.stoneDark, M.Marble)
			f:box(0, 12, 0.9, 2.2, 22, 0.6, if i % 2 == 0 then Pal.gold else Pal.lumen, M.Neon, { decor = true })
		end)
		-- gate
		for _, sx in { -22, 22 } do
			c:box(sx, 3, 30, 9, 40, 12, Pal.slate, M.Marble)
			c:box(sx, 6, 23.8, 2, 30, 0.5, Pal.gold, M.Neon, { decor = true })
		end
		c:box(0, 43, 30, 58, 8, 12, Pal.slate, M.Marble)
		local sign = c:box(0, 44, 23.6, 40, 5.4, 0.5, Pal.night, M.Glass, { decor = true, name = "GateSign" })
		Kit.label(sign, Enum.NormalId.Front, "CROWN ARENA", { color = Pal.gold })
		for i = -2, 2 do
			c:wedge(i * 7, 51, 28, 3, 6 + (2 - math.abs(i)) * 3, 3.4, 0, Pal.gold, M.Neon, { decor = true })
		end
		c:box(0, 3, 35, 35, 40, 5, Pal.night, M.SmoothPlastic)
		local gate = c:box(0, 3, 31.6, 35, 40, 1.2, Pal.gold, M.ForceField, { name = "CrownGate", trans = 0.2 })
		Kit.glow(gate, 50, 2, Pal.gold)
		prompt(gate, "trials", "Enter", "The Crown Trials", 26)
		anchor("Npc_isolde", c, 14, 3, 17, 0)
		anchor("Return_trials", c, 0, 3.4, 16, 180)
		for _, sx in { -31, 31 } do
			local f = c:shift(sx, 3, 14)
			f:cyl(0, 0, 0, 2.6, 5, Pal.darkMetal, M.Metal)
			local fire = f:cyl(0, 5, 0, 2.2, 1, Pal.gold, M.Neon, { decor = true })
			Kit.glow(fire, 44, 2.2, Pal.gold)
			Kit.sparkles(fire, Pal.gold, 18, { Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(20, 20), Lifetime = NumberRange.new(0.6, 1.4) })
		end
		for i, id in Config.AcademyOrder do
			local accent = Config.Academies[id].accent
			Props.banner(c, -46, 14 + (i - 1) * 22, accent, 30, 0)
			Props.banner(c, 46, 14 + (i - 1) * 22, accent, 30, 180)
		end
		Props.crystal(c, -60, 86, Pal.gold, 1.5)
		Props.crystal(c, 60, 86, Pal.gold, 1.5)
		-- hologram crown and searchlights above the arena
		c:ring(0, 84, 110, 30, 16, function(f, i)
			f:box(0, 0, 0, 12.2, 2.4, 1, Pal.gold, M.Neon, { decor = true, trans = 0.15 })
			if i % 2 == 0 then
				f:wedge(0, 2.4, 0, 5, 12, 1, 0, Pal.gold, M.Neon, { decor = true, trans = 0.15, rot = CFrame.Angles(0, math.rad(90), 0) })
			end
		end)
		for i = 0, 3 do
			local a = math.rad(45 + i * 90)
			c:piece("Cylinder", CFrame.new(math.sin(a) * 60, 190, 110 + math.cos(a) * 60) * CFrame.Angles(math.cos(a) * 0.16, 0, math.rad(90) - math.sin(a) * 0.16),
				Vector3.new(300, 2.6, 2.6), Pal.lumen, M.Neon, { decor = true, trans = 0.75 })
		end
	end

	-- =========================================================================================
	-- Academy pavilions (diagonals)
	-- =========================================================================================
	local function pavilionBase(academyId: string, a: number)
		local info = Config.Academies[academyId]
		local p = spoke("Pavilion_" .. info.short, a, 330)
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
		p:cyl(0, -0.25, 96, 104, 0.3, gl[1], gl[2], { name = "DistrictGround" })
		p:cyl(0, -0.3, 96, 106, 0.3, info.accent, M.Neon, { decor = true })

		-- The school tower. Each academy is a high-rise campus with its own silhouette.
		local body = Kit.mix(info.uniform.dark, Pal.night, 0.3)
		local tw = p:shift(0, 0, 152)
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
	do
		local p, info = pavilionBase("northwind", 135)
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
	do
		local p, info = pavilionBase("solcrest", 45)
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
	do
		local p, info = pavilionBase("arcline", 315)
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
	do
		local p, info = pavilionBase("ironreach", 225)
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
		local rnd = Props.rng(1009 + k * 77)
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
		-- lookout terrace at the rim
		local t = spoke("Lookout" .. k, a, 476)
		t:box(0, -0.2, 0, 40, 0.4, 26, Pal.stone, M.Marble)
		t:box(0, 0.2, 0, 36, 0.05, 2, Pal.lumen, M.Neon, { decor = true })
		Props.bench(t, -10, -4, 180)
		Props.bench(t, 10, -4, 180)
		t:cyl(0, 0.2, 9, 0.5, 4.4, Pal.darkMetal, M.Metal)
		t:rod("z", 0, 5.2, 9.6, 0.9, 4.4, Pal.gold, M.Metal, { decor = true })
		Props.bollard(t, -18, 10, Pal.lumen)
		Props.bollard(t, 18, 10, Pal.lumen)
		-- footpath out to the lookout
		local path = spoke("Path" .. k, a, 372)
		for i = 0, 11 do
			path:cyl(math.sin(i * 1.1) * 3, 0, -84 + i * 15, 3.4, 0.22, Pal.stoneWarm, M.Marble, { decor = true })
		end
	end

	-- Scattered trees across the lawns, kept clear of roads and buildings
	do
		local rnd = Props.rng(424242)
		local kinds = { "round", "round", "blossom", "pine", "autumn" }
		local placed = 0
		for _ = 1, 400 do
			if placed >= 86 then
				break
			end
			local a, r = rnd(0, 360), rnd(150, 498)
			local toAvenue = math.abs(((a + 22.5) % 45) - 22.5) -- degrees from the nearest avenue line
			local lateral = math.sin(math.rad(toAvenue)) * r
			local toGarden = math.abs((a % 45) - 22.5)
			local ok = lateral > 84 or (r < 318 and lateral > 34)
			if r > 196 and r < 276 and toGarden < 16 then
				ok = false -- garden plots
			end
			if r > 350 and toGarden < 4.5 then
				ok = false -- lookout paths
			end
			if r > 452 and toGarden < 7 then
				ok = false -- lookout terraces
			end
			if r < 318 and lateral <= 34 then
				ok = false
			end
			if ok then
				local x, z = polar(a, r)
				Props.tree(island, x, z, kinds[1 + math.floor(rnd(0, #kinds - 0.001))], rnd(0.95, 1.7))
				placed += 1
			end
		end
	end

	-- =========================================================================================
	-- Halcyon City (far west, across the Skybridge)
	-- =========================================================================================
	do
		local c = spoke("HalcyonCity", 270, 505) -- local +Z runs away from the island
		local asphalt, kerb = hex(0x20242f), hex(0x8f97a8)
		local rndc = Props.rng(31337)
		-- the bridge
		c:box(0, -3, 110, 44, 3, 230, Pal.slate, M.Concrete, { name = "Skybridge" })
		c:box(0, 0, 110, 4, 0.08, 226, Pal.lumen, M.Neon, { decor = true })
		for _, sx in { -22, 22 } do
			c:box(sx, 0, 110, 1.2, 5, 230, Pal.glass, M.Glass, { trans = 0.55, shadow = false })
			c:box(sx, 5, 110, 1.4, 0.4, 230, Pal.lumen, M.Neon, { decor = true })
			c:box(sx * 1.08, 0, 110, 1.4, 90, 230, Pal.white, M.SmoothPlastic, { trans = 1, name = "Barrier", shadow = false })
			for j = 0, 3 do
				c:box(sx, -3, 30 + j * 55, 3, 70, 3, Pal.darkMetal, M.Metal, { decor = true })
				c:bar(Vector3.new(sx, 67, 30 + j * 55), Vector3.new(sx, 4, 57 + j * 55), 0.5, Pal.metal, M.Metal, { decor = true })
				c:bar(Vector3.new(sx, 67, 30 + j * 55), Vector3.new(sx, 4, 3 + j * 55), 0.5, Pal.metal, M.Metal, { decor = true })
			end
		end
		local gateBeam = c:box(0, 34, 6, 50, 6, 4, Pal.night, M.Metal, { name = "CityGate" })
		Kit.label(gateBeam, Enum.NormalId.Front, "HALCYON CITY", { color = hex(0xff4fd8) })
		Kit.label(gateBeam, Enum.NormalId.Back, "ACADEMY ISLAND", { color = Pal.lumen })
		for _, sx in { -23, 23 } do
			c:box(sx, 0, 6, 4, 34, 4, Pal.darkMetal, M.Metal)
		end
		-- the city platform: 560 x 560, centred 505 studs past the bridge start
		local city = c:shift(0, 0, 505)
		local H = 280
		city:box(0, -30, 0, 560, 30, 560, asphalt, M.Asphalt, { name = "CityGround" })
		city:box(0, -90, 0, 420, 60, 420, Pal.rockDark, M.Slate, { decor = true })
		city:box(0, -32, 0, 566, 2.4, 566, hex(0xff4fd8), M.Neon, { decor = true })
		for _, e in { { 0, H + 1, 564, 2 }, { 0, -(H + 1), 564, 2 }, { H + 1, 0, 2, 564 }, { -(H + 1), 0, 2, 564 } } do
			if not (e[2] < 0 and e[1] == 0) then
				city:box(e[1], 0, e[2], e[3], 90, e[4], Pal.white, M.SmoothPlastic, { trans = 1, name = "Barrier", shadow = false })
			end
			city:box(e[1], 0, e[2], e[3], 4, e[4], kerb, M.Concrete, { decor = true })
		end
		-- the island-side edge has a gap for the bridge
		city:box(-151, 0, -(H + 1), 258, 90, 2, Pal.white, M.SmoothPlastic, { trans = 1, name = "Barrier", shadow = false })
		city:box(151, 0, -(H + 1), 258, 90, 2, Pal.white, M.SmoothPlastic, { trans = 1, name = "Barrier", shadow = false })
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
		anchor("Npc_city_vendor", city, 30, 1, 30, 135)
		anchor("Npc_city_guide", city, -10, 1, -70, 180)
		anchor("Npc_city_kid", city, -34, 1, 26, -120)
		anchor("Npc_bridge_guard", c, 14, 0.2, 14, 180)
	end

	-- =========================================================================================
	-- The sky around the island
	-- =========================================================================================
	local sky = root:group("Skyline")
	local islets = {
		{ 760, -40, 150, 70, "falls" }, { 690, 60, -420, 56, "pagoda" }, { -560, 20, 700, 80, "falls" }, { -700, 90, -360, 52, "beacon" },
		{ 240, 110, 860, 60, "pagoda" }, { -260, -70, 900, 74, nil }, { 320, 40, -900, 66, "beacon" }, { -380, 130, -880, 48, nil },
		{ 1020, 150, -120, 44, nil }, { -1000, -30, -620, 58, "beacon" },
	}
	for i, it in islets do
		Props.islet(sky, it[1], it[2], it[3], it[4], 300 + i * 13, it[5])
	end
	local accents = { Pal.lumen, Pal.gold, hex(0xe14bff), Pal.ember }
	local rnd = Props.rng(9001)
	for i = 1, 16 do
		local a = math.rad(i * 22.5 + rnd(-6, 6))
		local r = rnd(1500, 2100)
		Props.skyTower(sky, math.sin(a) * r, rnd(-260, -40), math.cos(a) * r, rnd(70, 130), rnd(420, 900), accents[1 + i % 4], 700 + i)
	end
	Props.airship(sky, -380, 190, 520, 60, Pal.gold, 1.6)
	Props.airship(sky, 620, 260, -280, -30, hex(0xe14bff), 2)
	Props.airship(sky, -150, 320, -760, 100, Pal.ember, 1.8)
	-- ring gates the airships fly through
	for _, g in { { -620, 210, 760, 40 }, { 900, 280, -420, -50 } } do
		local f = sky:shift(g[1], g[2], g[3], g[4])
		for i = 0, 15 do
			local a = math.rad(i * 22.5)
			f:piece("Block", CFrame.new(math.sin(a) * 70, math.cos(a) * 70, 0) * CFrame.Angles(0, 0, -a), Vector3.new(28, 4, 5), if i % 2 == 0 then Pal.lumen else Pal.darkMetal, if i % 2 == 0 then M.Neon else M.Metal, { decor = true })
		end
	end
end

--- Builds the whole campus under `parent` and returns its root folder.
function Campus.build(parent: Instance): Instance
	local world = Instance.new("Folder")
	world.Name = Config.WorldName
	build(world)
	world.Parent = parent
	return world
end

return Campus
