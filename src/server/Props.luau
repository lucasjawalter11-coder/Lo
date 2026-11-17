--!nonstrict
-- Props: the palette and the small reusable pieces the campus is dressed with.
local Kit = require(script.Parent.Kit)

local M = Enum.Material
local hex = Kit.hex

local Props = {}

Props.Pal = {
	stone = hex(0xd5dbe8),
	stoneWarm = hex(0xe6dfd2),
	stoneDark = hex(0x8c95aa),
	slate = hex(0x39415a),
	deck = hex(0x262c40),
	night = hex(0x161b2c),
	metal = hex(0x9aa3b5),
	darkMetal = hex(0x2b3040),
	glass = hex(0xbfe6ff),
	grass = hex(0x5aa85c),
	grassDark = hex(0x4a9150),
	leaf = hex(0x4f9d58),
	leafLight = hex(0x7fcf74),
	blossom = hex(0xffb3d1),
	blossomDeep = hex(0xff86b8),
	autumn = hex(0xffb347),
	wood = hex(0x8a5c3e),
	woodDark = hex(0x5c3b28),
	rock = hex(0x565c6e),
	rockDark = hex(0x3a3f4f),
	water = hex(0x49b8ff),
	gold = hex(0xffc94a),
	white = hex(0xf5f7fc),
	lumen = hex(0x6fe6ff),
	ember = hex(0xff7a2a),
	cloth = hex(0xf0f0f5),
}
local Pal = Props.Pal

-- Small deterministic random source, so the baked map is identical every time.
function Props.rng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(lo: number?, hi: number?): number
		state = (state * 48271) % 2147483647
		local u = (state - 1) / 2147483646
		if lo and hi then
			return lo + (hi - lo) * u
		end
		return u
	end
end

--- Street lamp: pole, curved arm and a glowing lantern. `lit` adds a real light source.
function Props.lamp(b, x: number, z: number, color: Color3, lit: boolean?, height: number?)
	local h = height or 15
	b:cyl(x, 0, z, 0.9, 0.8, Pal.darkMetal, M.Metal)
	b:cyl(x, 0.8, z, 0.34, h - 0.8, Pal.darkMetal, M.Metal, { decor = true })
	b:box(x, h - 0.2, z - 1.3, 0.5, 0.4, 3.2, Pal.darkMetal, M.Metal, { decor = true })
	local lantern = b:box(x, h - 1.9, z - 2.6, 1.5, 1.7, 1.5, color, M.Neon, { decor = true, name = "Lantern" })
	if lit then
		Kit.glow(lantern, 46, 1.5, color)
	end
	return lantern
end

--- Low garden light.
function Props.bollard(b, x: number, z: number, color: Color3)
	b:cyl(x, 0, z, 0.5, 2.4, Pal.darkMetal, M.Metal, { decor = true })
	b:cyl(x, 2.4, z, 0.6, 0.7, color, M.Neon, { decor = true })
end

--- Tree. kind: "round" | "blossom" | "pine" | "autumn".
function Props.tree(b, x: number, z: number, kind: string?, scale: number?)
	local s = scale or 1
	local k = kind or "round"
	if k == "pine" then
		b:cyl(x, 0, z, 0.9 * s, 6 * s, Pal.woodDark, M.Wood, { shadow = false })
		for i = 0, 2 do
			local r = (6.2 - i * 1.6) * s
			b:cyl(x, (4 + i * 4.4) * s, z, r, 3.4 * s, if i % 2 == 0 then Pal.leaf else Pal.grassDark, M.Grass, { decor = true })
		end
		b:cyl(x, 17.2 * s, z, 1.4 * s, 3 * s, Pal.leaf, M.Grass, { decor = true })
		return
	end
	local c1, c2 = Pal.leaf, Pal.leafLight
	if k == "blossom" then
		c1, c2 = Pal.blossom, Pal.blossomDeep
	elseif k == "autumn" then
		c1, c2 = Pal.autumn, hex(0xff8a3c)
	end
	b:cyl(x, 0, z, 1.0 * s, 9 * s, Pal.woodDark, M.Wood, { shadow = false })
	b:ball(x, 12.5 * s, z, 6.2 * s, c1, M.Grass, { decor = true })
	b:ball(x + 3.6 * s, 10.5 * s, z + 1.8 * s, 4.3 * s, c2, M.Grass, { decor = true })
	b:ball(x - 3.2 * s, 10.8 * s, z - 2.4 * s, 4.6 * s, c1, M.Grass, { decor = true })
	b:ball(x + 0.6 * s, 15.6 * s, z - 0.8 * s, 3.8 * s, c2, M.Grass, { decor = true })
end

function Props.bush(b, x: number, z: number, color: Color3?, r: number?)
	local radius = r or 2.4
	b:ball(x, radius * 0.7, z, radius, color or Pal.leaf, M.Grass, { decor = true })
end

--- Bench facing local -Z.
function Props.bench(b, x: number, z: number, yawDeg: number?)
	local f = b:shift(x, 0, z, yawDeg or 0)
	f:box(0, 1.5, 0, 9, 0.45, 2.6, Pal.wood, M.WoodPlanks)
	f:box(0, 1.95, 1.2, 9, 2.3, 0.4, Pal.wood, M.WoodPlanks, { rot = CFrame.Angles(math.rad(-10), 0, 0), decor = true })
	f:box(-3.6, 0, 0, 0.5, 1.5, 2.4, Pal.darkMetal, M.Metal, { decor = true })
	f:box(3.6, 0, 0, 0.5, 1.5, 2.4, Pal.darkMetal, M.Metal, { decor = true })
end

--- Hanging banner on a pole. The cloth faces local -Z / +Z.
function Props.banner(b, x: number, z: number, color: Color3, height: number?, yawDeg: number?)
	local h = height or 26
	local f = b:shift(x, 0, z, yawDeg or 0)
	f:cyl(0, 0, 0, 0.45, h, Pal.darkMetal, M.Metal, { shadow = false })
	f:box(2.6, h - 1.2, 0, 5.6, 0.4, 0.4, Pal.darkMetal, M.Metal, { decor = true })
	f:box(2.9, h - 13.2, 0, 4.6, 12, 0.25, color, M.Fabric, { decor = true })
	f:box(2.9, h - 9.2, 0, 2.2, 2.2, 0.4, Pal.white, M.Neon, { decor = true, rot = CFrame.Angles(0, 0, math.rad(45)) })
	f:wedge(2.9, h - 15.4, 0, 0.25, 2.2, 2.3, 90, color, M.Fabric, { decor = true, rot = CFrame.Angles(math.rad(180), 0, 0) })
	f:ball(0, h + 0.5, 0, 0.8, Pal.gold, M.Metal, { decor = true })
end

--- Raised planter with a tree and bushes.
function Props.planter(b, x: number, z: number, size: number, treeKind: string?, yawDeg: number?)
	local f = b:shift(x, 0, z, yawDeg or 0)
	f:box(0, 0, 0, size, 1.6, size, Pal.stoneDark, M.Marble)
	f:box(0, 1.6, 0, size - 1.4, 0.25, size - 1.4, Pal.grass, M.Grass, { decor = true })
	Props.tree(f:shift(0, 1.6, 0), 0, 0, treeKind or "blossom", 1.05)
	local q = size / 2 - 2.6
	Props.bush(f:shift(0, 1.6, 0), -q, -q, Pal.leafLight, 1.7)
	Props.bush(f:shift(0, 1.6, 0), q, q, Pal.leaf, 1.9)
end

--- Glass railing between two points (posts at both ends).
function Props.rail(b, a: Vector3, c: Vector3, color: Color3?)
	local glow = color or Pal.lumen
	local mid = (a + c) / 2
	local len = (c - a).Magnitude
	local yaw = math.deg(math.atan2(c.X - a.X, c.Z - a.Z)) + 90
	local f = b:shift(mid.X, mid.Y, mid.Z, yaw)
	f:box(0, 0.4, 0, len, 3.4, 0.25, Pal.glass, M.Glass, { trans = 0.6, shadow = false })
	f:box(0, 3.8, 0, len, 0.35, 0.5, glow, M.Neon, { decor = true })
	f:box(0, 0, 0, len, 0.4, 0.7, Pal.darkMetal, M.Metal, { decor = true })
end

--- Free-standing holographic sign: a framed glass panel with glowing text on both sides.
function Props.holo(b, x: number, y: number, z: number, w: number, h: number, text: string, color: Color3, yawDeg: number?, name: string?)
	local f = b:shift(x, y, z, yawDeg or 0)
	local panel = f:box(0, 0, 0, w, h, 0.3, Pal.night, M.Glass, { trans = 0.35, decor = true, name = name or "Holo" })
	f:box(0, h, 0, w + 0.8, 0.4, 0.6, color, M.Neon, { decor = true })
	f:box(0, -0.4, 0, w + 0.8, 0.4, 0.6, color, M.Neon, { decor = true })
	Kit.label(panel, Enum.NormalId.Front, text, { color = color })
	Kit.label(panel, Enum.NormalId.Back, text, { color = color })
	return panel
end

--- Stone column with a capital.
function Props.column(b, x: number, z: number, radius: number, height: number, color: Color3?, mat: Enum.Material?)
	local c = color or Pal.stone
	b:cyl(x, 0, z, radius * 1.35, 1.2, c, mat or M.Marble)
	b:cyl(x, 1.2, z, radius, height - 2.4, c, mat or M.Marble)
	b:cyl(x, height - 1.2, z, radius * 1.35, 1.2, c, mat or M.Marble, { decor = true })
end

--- A Lumen crystal: tilted glowing shards on a plinth.
function Props.crystal(b, x: number, z: number, color: Color3, scale: number?)
	local s = scale or 1
	local f = b:shift(x, 0, z)
	f:cyl(0, 0, 0, 3.4 * s, 1.2 * s, Pal.slate, M.Marble)
	f:box(0, 1.2 * s, 0, 1.8 * s, 9 * s, 1.8 * s, color, M.Neon, { decor = true, rot = CFrame.Angles(math.rad(6), math.rad(30), math.rad(-5)) })
	f:box(1.5 * s, 1.2 * s, 0.6 * s, 1.2 * s, 5.6 * s, 1.2 * s, color, M.Glass, { decor = true, trans = 0.25, rot = CFrame.Angles(math.rad(-14), math.rad(10), math.rad(-22)) })
	local shard = f:box(-1.3 * s, 1.2 * s, -0.7 * s, 1.1 * s, 4.4 * s, 1.1 * s, color, M.Glass, { decor = true, trans = 0.25, rot = CFrame.Angles(math.rad(12), math.rad(50), math.rad(20)) })
	Kit.glow(shard, 30, 1.4, color)
end

--- Round fountain with a glowing jet.
function Props.fountain(b, x: number, z: number, radius: number, color: Color3)
	local f = b:shift(x, 0, z)
	f:cyl(0, 0, 0, radius, 1.6, Pal.stone, M.Marble)
	f:cyl(0, 1.3, 0, radius - 1.2, 0.5, Pal.water, M.Glass, { trans = 0.35, decor = true, refl = 0.3 })
	f:cyl(0, 1.6, 0, radius * 0.32, 3, Pal.stone, M.Marble)
	f:cyl(0, 4.6, 0, radius * 0.5, 0.8, Pal.stone, M.Marble, { decor = true })
	local jet = f:cyl(0, 5.4, 0, 0.5, 7, color, M.Neon, { decor = true, trans = 0.3 })
	Kit.glow(jet, 34, 1.6, color)
	Kit.sparkles(jet, color, 14, { Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -14, 0) })
end

--- A floating rock islet with a grass cap and a few trees.
function Props.islet(b, x: number, y: number, z: number, radius: number, seed: number, feature: string?)
	local rnd = Props.rng(seed)
	local f = b:shift(x, y, z, rnd(0, 360))
	f:cyl(0, -6, 0, radius, 6, Pal.grass, M.Grass, { decor = true })
	f:cyl(0, -18, 0, radius * 0.82, 12, Pal.rock, M.Slate, { decor = true })
	f:cyl(0, -36, 0, radius * 0.55, 18, Pal.rockDark, M.Slate, { decor = true })
	f:cyl(0, -58, 0, radius * 0.26, 22, Pal.rockDark, M.Slate, { decor = true })
	local count = math.max(2, math.floor(radius / 14))
	for i = 1, count do
		local a, r = rnd(0, math.pi * 2), rnd(0.15, 0.7) * radius
		Props.tree(f, math.sin(a) * r, math.cos(a) * r, if i % 3 == 0 then "blossom" elseif i % 3 == 1 then "round" else "pine", rnd(0.9, 1.5))
	end
	if feature == "falls" then
		local fall = f:box(radius * 0.86, -150, 0, 1.2, 148, 10, Pal.water, M.Neon, { decor = true, trans = 0.45 })
		fall.Name = "Waterfall"
		f:cyl(radius * 0.4, -5.9, 0, radius * 0.36, 0.3, Pal.water, M.Glass, { decor = true, trans = 0.3 })
	elseif feature == "pagoda" then
		for i = 0, 2 do
			local w = 22 - i * 5
			f:box(0, i * 11, 0, w - 6, 8, w - 6, Pal.stoneWarm, M.Marble, { decor = true })
			f:box(0, 8 + i * 11, 0, w + 4, 1.2, w + 4, hex(0x8a2f3a), M.Slate, { decor = true })
		end
		f:cyl(0, 34, 0, 0.6, 10, Pal.gold, M.Metal, { decor = true })
		local beacon = f:ball(0, 45, 0, 1.6, Pal.lumen, M.Neon, { decor = true })
		Kit.glow(beacon, 60, 2, Pal.lumen)
	elseif feature == "beacon" then
		f:cyl(0, 0, 0, 3, 46, Pal.darkMetal, M.Metal, { decor = true })
		local beacon = f:ball(0, 49, 0, 4, Pal.lumen, M.Neon, { decor = true })
		Kit.glow(beacon, 60, 2.5, Pal.lumen)
	end
end

--- Distant sky-city tower on its own hovering base.
function Props.skyTower(b, x: number, y: number, z: number, width: number, height: number, accent: Color3, seed: number)
	local rnd = Props.rng(seed)
	local f = b:shift(x, y, z, rnd(0, 90))
	local body = hex(0x1c2742)
	f:cyl(0, -30, 0, width * 1.5, 30, hex(0x232c44), M.Slate, { decor = true })
	f:cyl(0, -70, 0, width * 0.8, 40, hex(0x1a2135), M.Slate, { decor = true })
	f:box(0, 0, 0, width, height, width, body, M.SmoothPlastic, { decor = true })
	f:box(0, height, 0, width * 0.6, height * 0.18, width * 0.6, body, M.SmoothPlastic, { decor = true })
	f:cyl(0, height * 1.18, 0, 1.6, height * 0.16, accent, M.Neon, { decor = true })
	-- window bands
	for i = 1, 4 do
		local hy = height * (0.14 + 0.2 * (i - 1))
		f:box(0, hy, 0, width + 0.6, height * 0.035, width + 0.6, if i % 2 == 0 then accent else hex(0xffe9b0), M.Neon, { decor = true })
	end
end

--- A docked or drifting airship (decor).
function Props.airship(b, x: number, y: number, z: number, yawDeg: number, accent: Color3, scale: number?)
	local s = scale or 1
	local f = b:shift(x, y, z, yawDeg)
	local hull = Pal.white
	f:box(0, 0, 0, 16 * s, 9 * s, 62 * s, hull, M.SmoothPlastic, { decor = true })
	f:wedge(0, 0, -39 * s, 16 * s, 9 * s, 16 * s, 0, hull, M.SmoothPlastic, { decor = true })
	f:wedge(0, 0, 37 * s, 16 * s, 9 * s, 12 * s, 180, hull, M.SmoothPlastic, { decor = true })
	f:box(0, 9 * s, 6 * s, 10 * s, 5 * s, 26 * s, Pal.darkMetal, M.Metal, { decor = true })
	f:box(0, 10.4 * s, 6 * s, 10.4 * s, 2 * s, 22 * s, hex(0xfff1c4), M.Neon, { decor = true })
	f:box(8.2 * s, 3.6 * s, 0, 0.5 * s, 1.2 * s, 58 * s, accent, M.Neon, { decor = true })
	f:box(-8.2 * s, 3.6 * s, 0, 0.5 * s, 1.2 * s, 58 * s, accent, M.Neon, { decor = true })
	f:box(15 * s, 2 * s, 14 * s, 14 * s, 1 * s, 14 * s, Pal.metal, M.Metal, { decor = true })
	f:box(-15 * s, 2 * s, 14 * s, 14 * s, 1 * s, 14 * s, Pal.metal, M.Metal, { decor = true })
	f:rod("z", 21 * s, 2.4 * s, 14 * s, 3 * s, 12 * s, Pal.darkMetal, M.Metal, { decor = true })
	f:rod("z", -21 * s, 2.4 * s, 14 * s, 3 * s, 12 * s, Pal.darkMetal, M.Metal, { decor = true })
	f:rod("z", 21 * s, 2.4 * s, 20.4 * s, 2.4 * s, 1 * s, accent, M.Neon, { decor = true })
	f:rod("z", -21 * s, 2.4 * s, 20.4 * s, 2.4 * s, 1 * s, accent, M.Neon, { decor = true })
	f:box(0, 9 * s, 28 * s, 1 * s, 9 * s, 10 * s, hull, M.SmoothPlastic, { decor = true })
end

-- ---------------------------------------------------------------------------------------------
-- Neighbourhood pieces used to fill the land between the districts
-- ---------------------------------------------------------------------------------------------
local WALLS = { hex(0xf4efe4), hex(0xffffff), hex(0xdce8f5), hex(0xf6dfe4), hex(0xe0eedb), hex(0xe9dcc6), hex(0xd9d4e8) }
local ROOFS = { hex(0x2b3a5c), hex(0xb0563a), hex(0x2f5b46), hex(0x4a4f5e), hex(0x7a2f3a), hex(0x3b5f8a) }

--- A house whose front door faces local -Z. Origin = centre of the footprint on the ground.
function Props.house(b, x: number, z: number, yawDeg: number, rnd)
	local f = b:shift(x, 0, z, yawDeg)
	local w, d = rnd(18, 26), rnd(16, 21)
	local twoStorey = rnd() > 0.5
	local h = if twoStorey then rnd(15, 18) else rnd(9.5, 11)
	local wall = WALLS[1 + math.floor(rnd(0, #WALLS - 0.001))]
	local roof = ROOFS[1 + math.floor(rnd(0, #ROOFS - 0.001))]
	f:box(0, 0, 0, w + 2, 0.6, d + 2, Pal.stoneDark, M.Concrete)
	f:box(0, 0.6, 0, w, h, d, wall, M.SmoothPlastic, { name = "House" })
	local rh = rnd(5, 8)
	f:wedge(0, h + 0.6, -(d + 2) / 4, w + 2, rh, (d + 2) / 2, 0, roof, M.Slate, { name = "Roof" })
	f:wedge(0, h + 0.6, (d + 2) / 4, w + 2, rh, (d + 2) / 2, 180, roof, M.Slate, { name = "Roof" })
	f:box(0, 0.6, -d / 2 - 0.15, 3.4, 7, 0.4, Pal.woodDark, M.Wood, { decor = true })
	f:box(0, 7.8, -d / 2 - 1.2, 5.4, 0.4, 2.6, roof, M.Slate, { decor = true })
	local glow = hex(0xffe6a8)
	for _, sx in { -w / 4 - 1, w / 4 + 1 } do
		f:box(sx, 3.4, -d / 2 - 0.1, 3.6, 3, 0.25, glow, M.Neon, { decor = true, trans = 0.35 })
		if twoStorey then
			f:box(sx, h - 5.5, -d / 2 - 0.1, 3.6, 3, 0.25, glow, M.Neon, { decor = true, trans = 0.35 })
		end
	end
	if rnd() > 0.55 then
		f:box(w / 3, h + 0.6, d / 5, 2.4, rh + 2, 2.4, hex(0x8a5a48), M.Brick, { decor = true })
	end
	f:box(0, 0, -d / 2 - 4, 3.4, 0.35, 7, Pal.stoneWarm, M.Pavement, { decor = true })
	if rnd() > 0.4 then
		Props.bush(f, -w / 2 + 1, -d / 2 - 3, if rnd() > 0.5 then Pal.leafLight else Pal.blossomDeep, 1.5)
	end
end

--- A row of small shops with awnings, fronts facing local -Z.
function Props.shopRow(b, x: number, z: number, yawDeg: number, rnd)
	local f = b:shift(x, 0, z, yawDeg)
	local colors = { hex(0xff4fd8), hex(0x39c9ff), hex(0xffc94a), hex(0x7dff7a), hex(0xff7a2a), hex(0xb06bff) }
	local names = { "TEA", "BAKERY", "BOOKS", "FLOWERS", "GEAR", "SNACKS", "MUSIC", "TAILOR", "CAFE", "GAMES" }
	for i = -1, 1 do
		local c = colors[1 + math.floor(rnd(0, #colors - 0.001))]
		local sx = i * 26
		f:box(sx, 0, 0, 24, 14, 18, WALLS[1 + math.floor(rnd(0, #WALLS - 0.001))], M.SmoothPlastic, { name = "Shop" })
		f:box(sx, 14, 0, 25, 1.2, 19, Kit.shade(c, 0.6), M.Slate)
		f:box(sx, 0.2, -9.1, 18, 8, 0.3, hex(0xcfe9ff), M.Glass, { decor = true, trans = 0.4 })
		f:box(sx, 8.6, -11, 22, 0.5, 4.4, c, M.Fabric, { decor = true, rot = CFrame.Angles(math.rad(-12), 0, 0) })
		local sign = f:box(sx, 10, -9.25, 16, 3, 0.3, Pal.night, M.SmoothPlastic, { decor = true })
		Kit.label(sign, Enum.NormalId.Front, names[1 + math.floor(rnd(0, #names - 0.001))], { color = c })
	end
	f:box(0, 0, -16, 80, 0.35, 10, Pal.stoneWarm, M.Pavement, { decor = true })
	Props.lamp(f:shift(-40, 0, -14, -90), 0, 0, hex(0xffe6a8), false, 12)
end

--- Crop field with a small barn.
function Props.field(b, x: number, z: number, yawDeg: number, rnd)
	local f = b:shift(x, 0, z, yawDeg)
	local crop = if rnd() > 0.5 then hex(0x8fbf4a) else hex(0xe2c25a)
	for i = 0, 7 do
		f:box(-24 + i * 7, 0, 6, 4, 1.4, 56, if i % 2 == 0 then crop else Kit.shade(crop, 0.85), M.Grass, { decor = true })
	end
	f:box(-32, 0, 6, 0.5, 3, 60, Pal.wood, M.Wood, { decor = true })
	f:box(32, 0, 6, 0.5, 3, 60, Pal.wood, M.Wood, { decor = true })
	f:box(20, 0, -32, 16, 12, 12, hex(0x9c3b32), M.WoodPlanks, { name = "Barn" })
	f:wedge(20, 12, -35, 17, 5, 6.5, 0, hex(0x4a4f5e), M.Slate)
	f:wedge(20, 12, -29, 17, 5, 6.5, 180, hex(0x4a4f5e), M.Slate)
	f:box(20, 0, -38.2, 6, 8, 0.3, Pal.white, M.Wood, { decor = true })
end

--- Small park: crossing paths, flower beds, benches and a centrepiece.
function Props.park(b, x: number, z: number, rnd)
	local f = b:shift(x, 0, z)
	f:box(0, -0.05, 0, 94, 0.3, 94, Pal.grass, M.Grass, { name = "Lawn" })
	f:box(0, -0.05, 0, 80, 0.3, 6, Pal.stoneWarm, M.Pavement, { decor = true })
	f:box(0, -0.05, 0, 6, 0.3, 80, Pal.stoneWarm, M.Pavement, { decor = true })
	if rnd() > 0.5 then
		Props.fountain(f, 0, 0, 8, Pal.water)
	else
		f:cyl(0, 0, 0, 4, 2, Pal.stone, M.Marble)
		f:box(0, 2, 0, 2.6, 9, 2.6, Pal.stone, M.Marble, { decor = true })
		f:ball(0, 12.4, 0, 2.2, Pal.gold, M.Metal, { decor = true })
	end
	local beds = { Pal.blossomDeep, hex(0xffd24a), hex(0x8f6bff), hex(0xff6a6a) }
	for i, q in { { -20, -20 }, { 20, -20 }, { -20, 20 }, { 20, 20 } } do
		f:box(q[1], 0, q[2], 13, 1.2, 13, beds[i], M.Grass, { decor = true })
		Props.tree(f, q[1] * 1.7, q[2] * 1.7, if i % 2 == 0 then "blossom" else "round", rnd(0.9, 1.3))
	end
	Props.bench(f, -10, -6, 90)
	Props.bench(f, 10, 6, -90)
end

--- Outdoor sports court with hoops.
function Props.court(b, x: number, z: number, yawDeg: number, rnd)
	local f = b:shift(x, 0, z, yawDeg)
	local c = if rnd() > 0.5 then hex(0x3b6fb5) else hex(0xb5563b)
	f:box(0, -0.05, 0, 44, 0.4, 70, c, M.Concrete, { name = "Court" })
	f:box(0, 0.36, 0, 40, 0.05, 0.6, Pal.white, M.SmoothPlastic, { decor = true })
	f:cyl(0, 0.36, 0, 7, 0.05, Pal.white, M.SmoothPlastic, { decor = true })
	for _, sz in { -33, 33 } do
		f:cyl(0, 0, sz, 0.4, 12, Pal.darkMetal, M.Metal, { decor = true })
		f:box(0, 11, sz * 0.97, 7, 4.4, 0.4, Pal.white, M.SmoothPlastic, { decor = true })
		f:cyl(0, 10.4, sz * 0.93, 1.2, 0.2, hex(0xff7a2a), M.Metal, { decor = true })
	end
	for _, sx in { -24, 24 } do
		f:box(sx, 0, 0, 0.3, 4, 72, Pal.darkMetal, M.Metal, { decor = true, trans = 0.3 })
	end
end

-- ---------------------------------------------------------------------------------------------
-- Sky-city pieces: clean white high-rises, plazas and canals
-- ---------------------------------------------------------------------------------------------
local TOWER_WHITE = { hex(0xf4f6fa), hex(0xe9edf4), hex(0xdfe5ee), hex(0xf7f3ec) }
local GLASS = { hex(0x9fd8ff), hex(0x7fb8e8), hex(0xb7e3ff), hex(0x8fc9d8) }
local BAND = { Pal.lumen, hex(0xffffff), hex(0x7fb8ff), Pal.gold }

--- A futuristic high-rise: a white frame, a glass face, glowing floor bands, sometimes a rounded end.
function Props.highrise(b, x: number, z: number, yawDeg: number, rnd, maxHeight: number?)
	local f = b:shift(x, 0, z, yawDeg)
	local w, d = rnd(26, 40), rnd(22, 32)
	local h = rnd(40, maxHeight or 140)
	local white = TOWER_WHITE[1 + math.floor(rnd(0, #TOWER_WHITE - 0.001))]
	local glass = GLASS[1 + math.floor(rnd(0, #GLASS - 0.001))]
	local band = BAND[1 + math.floor(rnd(0, #BAND - 0.001))]
	if rnd() > 0.7 then
		-- round tower
		local r = math.min(w, d) * 0.55
		f:cyl(0, 0, 0, r + 3, 6, white, M.SmoothPlastic, { name = "Building" })
		f:cyl(0, 6, 0, r, h, glass, M.Glass, { trans = 0.15, refl = 0.3, name = "Building" })
		for y = 26, h, 26 do
			f:cyl(0, 6 + y - 1, 0, r + 0.6, 1.2, white, M.SmoothPlastic, { decor = true })
		end
		f:cyl(0, h + 6, 0, r + 1.5, 3, white, M.SmoothPlastic, { decor = true })
		f:cyl(0, h + 9, 0, r * 0.4, 6, band, M.Neon, { decor = true })
		return
	end
	f:box(0, 0, 0, w + 6, 6, d + 6, white, M.SmoothPlastic, { name = "Building" })
	f:box(0, 6, 0, w, h, d, white, M.SmoothPlastic, { name = "Building" })
	f:box(0, 8, -d / 2 - 0.3, w * 0.72, h - 6, 0.6, glass, M.Glass, { decor = true, trans = 0.1, refl = 0.35 })
	f:box(0, 8, d / 2 + 0.3, w * 0.72, h - 6, 0.6, glass, M.Glass, { decor = true, trans = 0.1, refl = 0.35 })
	for y = 30, h - 4, 30 do
		f:box(0, 6 + y, 0, w + 0.8, 0.8, d + 0.8, band, M.Neon, { decor = true, trans = 0.2 })
	end
	if rnd() > 0.5 then
		local r = d / 2
		f:cyl(w / 2, 6, 0, r, h * 0.8, white, M.SmoothPlastic, { decor = true })
		f:cyl(w / 2, 6, 0, r + 0.3, h * 0.8 - 2, glass, M.Glass, { decor = true, trans = 0.4 })
	end
	f:box(0, h + 6, 0, w * 0.6, 4, d * 0.6, Kit.shade(white, 0.85), M.Metal, { decor = true })
	if rnd() > 0.6 then
		f:cyl(-w * 0.2, h + 10, 0, 0.5, 14, Pal.darkMetal, M.Metal, { decor = true })
		f:ball(-w * 0.2, h + 24.5, 0, 0.9, Pal.ember, M.Neon, { decor = true })
	end
end

--- A city plaza: a hex-tiled square with a hologram screen, planters and benches.
function Props.plaza(b, x: number, z: number, rnd)
	local f = b:shift(x, 0, z)
	local tile = hex(0xe3e8f0)
	for k = 0, 2 do
		f:box(0, 0, 0, 80, 0.2, 80 / math.sqrt(3), tile, M.Marble, { rot = CFrame.Angles(0, math.rad(k * 60), 0) })
	end
	f:cyl(0, 0.2, 0, 24, 0.06, Pal.lumen, M.Neon, { decor = true })
	local words = { "TOURNAMENT TONIGHT", "SKY ARENA", "FESTA", "NEWS", "TRIALS OPEN", "HALCYON" }
	if rnd() > 0.45 then
		f:cyl(0, 0.2, 0, 3, 3, Pal.darkMetal, M.Metal)
		Props.holo(f, 0, 6, 0, 18, 9, words[1 + math.floor(rnd(0, #words - 0.001))], Pal.lumen, rnd(0, 180))
	else
		f:cyl(0, 0.2, 0, 5, 1.6, Pal.stone, M.Marble)
		for k = 0, 2 do
			f:piece("Block", CFrame.new(0, 9, 0) * CFrame.Angles(math.rad(k * 60), math.rad(k * 40), 0), Vector3.new(1.2, 14, 1.2), Pal.white, M.SmoothPlastic, { decor = true })
		end
		f:ball(0, 9, 0, 2.4, Pal.lumen, M.Neon, { decor = true })
	end
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local px, pz = math.sin(a) * 30, math.cos(a) * 30
		f:cyl(px, 0.2, pz, 6, 1.6, Pal.white, M.Marble)
		if i % 2 == 0 then
			Props.tree(f:shift(0, 1.8, 0), px, pz, "blossom", 0.85)
			Props.bench(f, math.sin(a + 0.6) * 18, math.cos(a + 0.6) * 18, math.deg(a + 0.6) + 180)
		else
			Props.bush(f:shift(0, 1.8, 0), px, pz, Pal.leafLight, 3)
		end
	end
end

--- A canal across the cell (along local X) with a footbridge in the middle.
function Props.canal(b, x: number, z: number, yawDeg: number, rnd)
	local f = b:shift(x, 0, z, yawDeg)
	f:box(0, 0, 0, 100, 0.12, 22, Pal.water, M.Glass, { trans = 0.15, refl = 0.35, name = "Canal" })
	for _, sz in { -12, 12 } do
		f:box(0, 0, sz, 100, 1, 2.4, Pal.white, M.Marble, { decor = true })
		f:box(0, 1, sz, 100, 0.3, 0.6, Pal.lumen, M.Neon, { decor = true })
	end
	local bx = rnd(-20, 20)
	f:box(bx, 1.4, 0, 9, 0.8, 28, Pal.white, M.Marble, { name = "Bridge" })
	f:wedge(bx, 0, -13, 9, 1.4, 3, 180, Pal.white, M.Marble)
	f:wedge(bx, 0, 13, 9, 1.4, 3, 0, Pal.white, M.Marble)
	for _, sx in { -4.4, 4.4 } do
		f:box(bx + sx, 2.2, 0, 0.4, 3, 28, Pal.glass, M.Glass, { trans = 0.5, decor = true })
	end
	for _, side in { -1, 1 } do
		Props.tree(f, bx + 32 * side, 22 * side, "blossom", 1.0)
		Props.lamp(f:shift(-40 * side, 0, 18 * side, side * 90), 0, 0, Pal.lumen, false, 12)
	end
end

return Props
