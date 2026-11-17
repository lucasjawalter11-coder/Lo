--!nonstrict
-- Arena: the Crown Arena duelling ring. One template is kept in ServerStorage and cloned for every duel,
-- so any number of duels can run at the same time without the duelists seeing each other.
-- Local space: the ring floor is at y = 0, centred on the origin. Duelist A starts at +Z, B at -Z.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local M = Enum.Material
local Pal = Props.Pal
local hex = Kit.hex

local Arena = {}

function Arena.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = Config.ArenaTemplateName
	local b = Kit.at(model, CFrame.new())
	local R = Config.Combat.ArenaRadius
	local rnd = Props.rng(5150)

	-- Ring floor
	local floor = b:cyl(0, -3, 0, R + 2, 3, Pal.night, M.SmoothPlastic, { name = "Floor", refl = 0.22 })
	model.PrimaryPart = floor
	b:cyl(0, 0, 0, R, 0.06, Pal.lumen, M.Neon, { decor = true })
	b:cyl(0, 0, 0, R - 1, 0.12, Pal.deck, M.SmoothPlastic, { refl = 0.3, name = "RingFloor" })
	b:cyl(0, 0.12, 0, 30.6, 0.05, Pal.gold, M.Neon, { decor = true })
	b:cyl(0, 0.12, 0, 30, 0.1, hex(0x1d2338), M.SmoothPlastic, { refl = 0.35 })
	b:cyl(0, 0.22, 0, 10.5, 0.05, Pal.lumen, M.Neon, { decor = true })
	b:cyl(0, 0.22, 0, 10, 0.1, Pal.night, M.SmoothPlastic, { refl = 0.4 })
	b:ring(0, 0.22, 0, 20, 8, function(f)
		f:box(0, 0, 0, 0.6, 0.06, 19, Pal.lumen, M.Neon, { decor = true })
	end, 22.5)
	b:ring(0, 0.12, 0, 37, 16, function(f, i)
		f:box(0, 0, 0, 0.5, 0.06, 13, if i % 2 == 0 then Pal.gold else Pal.lumen, M.Neon, { decor = true })
	end)
	-- start marks
	for _, sz in { Config.Combat.FighterGap / 2, -Config.Combat.FighterGap / 2 } do
		b:box(0, 0.22, sz, 7, 0.07, 0.8, Pal.white, M.Neon, { decor = true })
	end

	-- Barrier: a shimmering field you can see through, backed by an invisible wall
	b:ring(0, 0, 0, R + 0.4, 28, function(f, i)
		f:box(0, 0, 0, 10.6, 13, 0.3, Pal.lumen, M.ForceField, { trans = 0.55, shadow = false, name = "Field", collide = false })
		f:box(0, 0, 0.6, 10.8, 70, 1.2, Pal.white, M.SmoothPlastic, { trans = 1, name = "Wall", shadow = false })
		f:box(0, 13, 0, 10.6, 0.4, 0.5, if i % 2 == 0 then Pal.lumen else Pal.gold, M.Neon, { decor = true })
		if i % 4 == 0 then
			f:box(5.3, 0, 0.2, 0.9, 15, 0.9, Pal.darkMetal, M.Metal, { decor = true })
		end
	end)

	-- Stands: three tiers with a crowd in academy colours
	local crowd = Instance.new("Model")
	crowd.Name = "Crowd"
	crowd.Parent = model
	local accents = {}
	for _, id in Config.AcademyOrder do
		table.insert(accents, Config.Academies[id].accent)
	end
	for tier = 0, 2 do
		local radius = 62 + tier * 10
		local height = 5 + tier * 6
		local seg = 2 * math.pi * radius / 24 + 0.4
		b:ring(0, -3, 0, radius, 24, function(f, i)
			f:box(0, 0, 0, seg, height + 3, 10, if tier % 2 == 0 then hex(0x2a3148) else hex(0x232a40), M.Concrete)
			f:box(0, height + 3, -4.6, seg, 0.4, 0.5, accents[1 + (i % 4)], M.Neon, { decor = true })
			if tier < 2 or i % 2 == 0 then
				local cf = Kit.at(crowd, f.cf)
				for sIdx = -1, 1 do
					local c = accents[1 + math.floor(rnd(0, 3.999))]
					local tone = Kit.mix(c, Pal.night, rnd(0.25, 0.6))
					local sx = sIdx * (seg / 3.4) + rnd(-0.5, 0.5)
					cf:box(sx, height + 3, -1 + rnd(-1.5, 1.5), 1.9, 2.7, 1.5, tone, M.SmoothPlastic, { decor = true })
					cf:ball(sx, height + 6.6, -1, 0.95, Kit.mix(hex(0xe2b594), Pal.night, rnd(0, 0.35)), M.SmoothPlastic, { decor = true })
					if (i + sIdx + tier) % 5 == 0 then
						cf:box(sx + 0.9, height + 5.4, -1.6, 0.25, 2.2, 0.25, c, M.Neon, { decor = true, rot = CFrame.Angles(0, 0, math.rad(-20)) })
					end
				end
			end
		end, tier * 7.5)
	end
	b:ring(0, -3, 0, 92, 24, function(f)
		f:box(0, 0, 0, 24.6, 34, 4, hex(0x1b2136), M.Concrete, { decor = true })
		f:box(0, 34, 0, 24.6, 1, 4.6, Pal.lumen, M.Neon, { decor = true })
	end, 7.5)

	-- Light pylons and jumbotrons
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local f = b:shift(math.sin(a) * 56, 0, math.cos(a) * 56, math.deg(a))
		f:box(0, -3, 0, 5, 58, 5, Pal.darkMetal, M.Metal, { decor = true })
		f:box(0, 6, -2.7, 1.4, 44, 0.4, accents[i + 1], M.Neon, { decor = true })
		local lamp = f:box(0, 55, -3, 9, 5, 3, Pal.white, M.Neon, { decor = true, name = "Floodlight", rot = CFrame.Angles(math.rad(-42), 0, 0) })
		Kit.spot(lamp, Enum.NormalId.Front, 60, 5, hex(0xfff3da), 80)
		Kit.glow(lamp, 60, 1.6, accents[i + 1])
	end
	for i = 0, 1 do
		local f = b:shift(0, 0, 0, i * 180)
		local screen = f:box(0, 36, 84, 46, 18, 1.2, Pal.night, M.Glass, { decor = true, name = "Jumbotron", trans = 0.08 })
		Kit.label(screen, Enum.NormalId.Front, "HALCYON CLASH", { color = Pal.gold, sizeY = 0.42 })
		f:box(0, 35, 84, 48, 0.8, 1.6, Pal.lumen, M.Neon, { decor = true })
		f:box(0, 54.2, 84, 48, 0.8, 1.6, Pal.lumen, M.Neon, { decor = true })
		f:box(-21, 0, 86, 2, 36, 2, Pal.darkMetal, M.Metal, { decor = true })
		f:box(21, 0, 86, 2, 36, 2, Pal.darkMetal, M.Metal, { decor = true })
	end

	-- Overhead light truss
	b:ring(0, 46, 0, 34, 16, function(f, i)
		f:box(0, 0, 0, 13.6, 1.2, 1.2, if i % 2 == 0 then Pal.lumen else Pal.darkMetal, if i % 2 == 0 then M.Neon else M.Metal, { decor = true })
	end)
	for i = 0, 3 do
		local a = math.rad(i * 90)
		local lamp = b:box(math.sin(a) * 22, 44, math.cos(a) * 22, 4, 1.2, 4, Pal.white, M.Neon, { decor = true })
		Kit.glow(lamp, 60, 2.2, hex(0xf6f1ff))
	end
	local centre = b:box(0, 40, 0, 6, 1.2, 6, Pal.gold, M.Neon, { decor = true })
	Kit.glow(centre, 60, 2.6, hex(0xfff0d0))

	-- Under-structure so the arena reads as a floating platform
	b:cyl(0, -26, 0, 98, 23, hex(0x1a2032), M.Slate, { decor = true })
	b:cyl(0, -56, 0, 66, 30, hex(0x151a29), M.Slate, { decor = true })
	b:cyl(0, -29, 0, 99, 2.6, Pal.lumen, M.Neon, { decor = true })
	b:cyl(0, -86, 0, 30, 30, hex(0x10141f), M.Slate, { decor = true })

	-- Skyline around the arena
	for i = 1, 10 do
		local a = math.rad(i * 36 + rnd(-8, 8))
		local r = rnd(520, 760)
		Props.skyTower(b, math.sin(a) * r, rnd(-320, -120), math.cos(a) * r, rnd(60, 110), rnd(420, 760), accents[1 + i % 4], 40 + i)
	end

	-- Markers the duel code looks up
	local gap = Config.Combat.FighterGap / 2
	for name, cf in {
		SpawnA = CFrame.new(0, 3.2, gap) * CFrame.Angles(0, 0, 0),
		SpawnB = CFrame.new(0, 3.2, -gap) * CFrame.Angles(0, math.rad(180), 0),
		Centre = CFrame.new(0, 0.3, 0),
	} do
		Kit.part(model, "Block", Vector3.new(1, 1, 1), cf, Pal.white, M.SmoothPlastic, { name = name, trans = 1, decor = true })
	end

	model.Parent = parent
	return model
end

return Arena
