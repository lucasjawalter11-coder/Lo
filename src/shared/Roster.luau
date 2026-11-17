--!nonstrict
-- Roster: every designed NPC of Halcyon. Looks, weapons, levels and the lines they say.
-- The player's own Roblox avatar is the hero, so nobody here is playable.
local Config = require(script.Parent.Config)
local hex = Config.hex

local Roster = {}

export type Look = {
	fem: boolean?,
	height: number, -- 1.0 = average
	bulk: number?,
	skin: Color3,
	hair: Color3,
	hairTip: Color3,
	hairStyle: string, -- spiky | bob | ponytail | slick | long | bun | twin
	eye: Color3,
	outfit: string, -- coat | skirt | hoodie | armor | staff
	accent: Color3,
	glasses: boolean?,
	stern: boolean?,
}

-- The twelve seat-holders a new student climbs past. Index 1 holds Seat I.
Roster.Seats = {
	{
		id = "elara", name = "Elara Wynn", epithet = "The Crownbearer", academy = "solcrest", weapon = "lance", level = 19, ai = 3,
		look = { fem = true, height = 1.03, skin = hex(0xf1d0b5), hair = hex(0xf2f0ea), hairTip = hex(0xb9cdfb), hairStyle = "long", eye = hex(0x7fb6ff), outfit = "skirt", accent = hex(0xcfe0ff) },
		taunt = "Seat I is not a prize. It is a promise to every student below it. Show me you can keep one.",
		lose = "Then the promise is yours. Carry our colours into the Trials.",
		win = "Come back when you understand what you are asking for.",
	},
	{
		id = "magnus", name = "Magnus Thorne", epithet = "The Rampart", academy = "ironreach", weapon = "maul", level = 17, ai = 3,
		look = { height = 1.14, bulk = 1.22, skin = hex(0xc98f6b), hair = hex(0x4b2f1c), hairTip = hex(0x7a5232), hairStyle = "slick", eye = hex(0x8fd96b), outfit = "armor", accent = hex(0x7dff7a), stern = true },
		taunt = "Nobody has moved me off this seat in two years. You are welcome to push.",
		lose = "Hah! Moved. Good. Elara has been bored for too long.",
		win = "Still standing. Try again when your arms stop shaking.",
	},
	{
		id = "odette", name = "Odette Varga", epithet = "Glass Rain", academy = "arcline", weapon = "pistols", level = 15, ai = 3,
		look = { fem = true, height = 0.98, skin = hex(0xe8c3a6), hair = hex(0x2a2140), hairTip = hex(0x7b5cff), hairStyle = "bob", eye = hex(0x8f6bff), outfit = "coat", accent = hex(0x8f7bff), glasses = true },
		taunt = "I counted your steps on the way over. Forty-one. You will not get that many in the ring.",
		lose = "I miscounted. That almost never happens.",
		win = "As calculated.",
	},
	{
		id = "cassian", name = "Cassian Roe", epithet = "The Quiet Cut", academy = "northwind", weapon = "scythe", level = 13, ai = 2,
		look = { height = 1.06, skin = hex(0xd9b08c), hair = hex(0x101418), hairTip = hex(0x2b3a4a), hairStyle = "ponytail", eye = hex(0x56d8c8), outfit = "coat", accent = hex(0x4fe3d0), stern = true },
		taunt = "...Draw.",
		lose = "...Clean. Well cut.",
		win = "...Sloppy.",
	},
	{
		id = "yui", name = "Yui Arakawa", epithet = "Needle of Dawn", academy = "solcrest", weapon = "lance", level = 12, ai = 2,
		look = { fem = true, height = 0.92, skin = hex(0xf4d6c0), hair = hex(0xff8fb0), hairTip = hex(0xffd0dd), hairStyle = "twin", eye = hex(0xff5f9a), outfit = "hoodie", accent = hex(0xff6fa8) },
		taunt = "A challenge? Now? I have not even had breakfast! ...Fine. Make it quick.",
		lose = "Ugh, breakfast AND my seat. Worst morning ever.",
		win = "Done! The canteen is that way if you need to cry into some noodles.",
	},
	{
		id = "gideon", name = "Gideon Brask", epithet = "Wrecking Bell", academy = "ironreach", weapon = "maul", level = 10, ai = 2,
		look = { height = 1.1, bulk = 1.18, skin = hex(0x8a5a3c), hair = hex(0xd8d2c4), hairTip = hex(0xffffff), hairStyle = "spiky", eye = hex(0xffc04a), outfit = "armor", accent = hex(0xffc23a) },
		taunt = "One good hit. That is all I ever need. Let us see if you can avoid it.",
		lose = "You avoided it. Every time. Respect.",
		win = "One good hit.",
	},
	{
		id = "noor", name = "Noor Halabi", epithet = "Twin Comets", academy = "arcline", weapon = "pistols", level = 9, ai = 2,
		look = { fem = true, height = 0.96, skin = hex(0xb9805a), hair = hex(0x1c1a22), hairTip = hex(0x38d0ff), hairStyle = "ponytail", eye = hex(0x38d0ff), outfit = "skirt", accent = hex(0x38d0ff) },
		taunt = "Keep moving. Standing targets are no fun at all.",
		lose = "You kept moving. Annoying. Impressive, but annoying.",
		win = "Too slow.",
	},
	{
		id = "ravi", name = "Ravi Castellan", epithet = "The Show-off", academy = "arcline", weapon = "orbit", level = 7, ai = 1,
		look = { height = 1.02, skin = hex(0xa8734c), hair = hex(0x6b2bd6), hairTip = hex(0xe14bff), hairStyle = "spiky", eye = hex(0xe14bff), outfit = "hoodie", accent = hex(0xff4fd8) },
		taunt = "Smile! The whole Concourse is watching me win.",
		lose = "Okay, nobody saw that. Nobody saw that, right?",
		win = "And THAT is how it is done. Did everyone see?",
	},
	{
		id = "tessa", name = "Tessa Lindqvist", epithet = "Long Reach", academy = "solcrest", weapon = "lance", level = 6, ai = 1,
		look = { fem = true, height = 1.02, skin = hex(0xf3d9c6), hair = hex(0xe8c66a), hairTip = hex(0xfff0b0), hairStyle = "ponytail", eye = hex(0x5fb0ff), outfit = "skirt", accent = hex(0xffe07a) },
		taunt = "I keep my rivals at exactly one lance-length. You will learn the distance.",
		lose = "You got inside my reach. I need to drill more.",
		win = "One lance-length. Remember it.",
	},
	{
		id = "bram", name = "Bram Holloway", epithet = "The Doorstop", academy = "ironreach", weapon = "maul", level = 4, ai = 1,
		look = { height = 1.09, bulk = 1.15, skin = hex(0xe2b594), hair = hex(0xb5482a), hairTip = hex(0xff7a3a), hairStyle = "slick", eye = hex(0x6bd0a0), outfit = "armor", accent = hex(0xff8a3a) },
		taunt = "They call me the Doorstop. Rookies stop here.",
		lose = "Guess the door is open now.",
		win = "Door stays shut.",
	},
	{
		id = "juno", name = "Juno Marsh", epithet = "Quickdraw", academy = "northwind", weapon = "pistols", level = 3, ai = 0,
		look = { fem = true, height = 0.91, skin = hex(0xd8a47c), hair = hex(0x2f6b4a), hairTip = hex(0x7dffb0), hairStyle = "bob", eye = hex(0x7dffb0), outfit = "hoodie", accent = hex(0x6dffa8) },
		taunt = "First week and already challenging? I like you. I am still going to shoot you.",
		lose = "Okay, okay! The seat is yours. Buy me lunch sometime.",
		win = "Told you.",
	},
	{
		id = "pell", name = "Pell Okoro", epithet = "The Eager", academy = "northwind", weapon = "saber", level = 2, ai = 0,
		look = { height = 0.99, skin = hex(0x6e4630), hair = hex(0x1a1414), hairTip = hex(0x3a2a22), hairStyle = "slick", eye = hex(0xffb62e), outfit = "coat", accent = hex(0xffd24a) },
		taunt = "A challenger! Finally! I only got this seat last month, so... please go easy?",
		lose = "That was amazing! I am going to train twice as hard!",
		win = "I won? I WON! Sorry! But also, yes!",
	},
}

-- Each academy's ace. They wait at their academy and face you in the Crown Trials.
Roster.Aces = {
	{
		id = "kaito", name = "Kaito Asher", epithet = "The Azure Edge", academy = "northwind", weapon = "saber", level = 20, ai = 3,
		look = { height = 1.03, skin = hex(0xf0c8ad), hair = hex(0xd9e2f2), hairTip = hex(0x7fcfff), hairStyle = "spiky", eye = hex(0x2e9bff), outfit = "coat", accent = hex(0x39c9ff) },
		taunt = "Northwind does not rush. I will wait for your first mistake.",
		lose = "No mistake. Not one. Well fought.",
		win = "There it was. Train the gap closed and come back.",
		idle = "The Crown Trials open to whoever holds Seat I. I would like it to be someone worth facing.",
	},
	{
		id = "sera", name = "Sera Vale", epithet = "The Solar Lance", academy = "solcrest", weapon = "lance", level = 21, ai = 3,
		look = { fem = true, height = 0.99, skin = hex(0xd9a37e), hair = hex(0x1d3038), hairTip = hex(0x2f8f8a), hairStyle = "ponytail", eye = hex(0xffa521), outfit = "skirt", accent = hex(0xffb62e) },
		taunt = "Solcrest was drilling before you woke up. Let me show you what that buys.",
		lose = "You earned every step of that. The sun rises for you today.",
		win = "Again tomorrow. Earlier.",
		idle = "Up before the sun, every day. That is the whole secret. Nobody likes hearing it.",
	},
	{
		id = "mira", name = "Mira Quill", epithet = "The Violet Tempest", academy = "arcline", weapon = "pistols", level = 22, ai = 3,
		look = { fem = true, height = 0.93, skin = hex(0xf6d3bd), hair = hex(0xcdb6ff), hairTip = hex(0x8f5bff), hairStyle = "bob", eye = hex(0xc04dff), outfit = "hoodie", accent = hex(0xe14bff), glasses = true },
		taunt = "I rebuilt these pistols last night. You get to be the first test. Lucky!",
		lose = "Fascinating. I need to see that again, slower, with instruments.",
		win = "Data collected. Thank you for participating!",
		idle = "Hush and Holler. I named the pistols. Holler is the loud one. Obviously.",
	},
	{
		id = "drake", name = "Drake Onyx", epithet = "The Ember Titan", academy = "ironreach", weapon = "maul", level = 23, ai = 3,
		look = { height = 1.15, bulk = 1.24, skin = hex(0xa5663f), hair = hex(0x14110f), hairTip = hex(0xff5a2a), hairStyle = "slick", eye = hex(0xff7a2a), outfit = "armor", accent = hex(0xff5a2a), stern = true },
		taunt = "Ironreach stands. Knock me down if you can.",
		lose = "Down. Hm. Then I stand again, and so will you.",
		win = "Stand up. Again.",
		idle = "The forge does not care who you are. Neither does the ring.",
	},
}

-- Staff. They do not duel; they open menus and give directions.
Roster.Staff = {
	{
		id = "maren", name = "Proctor Maren Voss", epithet = "Registrar of the Concourse", academy = "staff", role = "guide",
		look = { fem = true, height = 1.04, skin = hex(0xe9c9ae), hair = hex(0xcfd4de), hairTip = hex(0xffffff), hairStyle = "bun", eye = hex(0x7ad0c0), outfit = "staff", accent = hex(0xffc94a), glasses = true },
		lines = {
			"Welcome to the Halcyon Concourse. Four academies share this island, and one Register ranks them all.",
			"Twelve seats, XII up to I. Walk up to a seat-holder and challenge them. Win, and the seat is yours.",
			"You may challenge up to three seats above your own. Hold Seat I and the Crown Gate will open for you.",
		},
	},
	{
		id = "brandt", name = "Armsmaster Hale Brandt", epithet = "Keeper of the Training Hall", academy = "staff", role = "trainer",
		look = { height = 1.12, bulk = 1.2, skin = hex(0xb07a55), hair = hex(0x8d8f96), hairTip = hex(0xc9ccd4), hairStyle = "slick", eye = hex(0xd8b25a), outfit = "armor", accent = hex(0xff9d3a), stern = true },
		lines = {
			"Every weapon on that wall has put someone on the floor. Pick the one that suits your hands.",
			"Spar with the training construct as often as you like. It does not get tired and it does not gossip.",
		},
	},
	{
		id = "tilly", name = "Tilly Quince", epithet = "Lumen Exchange", academy = "staff", role = "shop",
		look = { fem = true, height = 0.9, skin = hex(0xf7d9c4), hair = hex(0x35d6c3), hairTip = hex(0xb6fff3), hairStyle = "twin", eye = hex(0xffc94a), outfit = "hoodie", accent = hex(0x35d6c3) },
		lines = {
			"Coins in, style out! Blade glows, auras, capes, titles. Come and look!",
		},
	},
	{
		id = "isolde", name = "Warden Isolde Crane", epithet = "Keeper of the Crown Gate", academy = "staff", role = "gate",
		look = { fem = true, height = 1.1, skin = hex(0xe0bba0), hair = hex(0xeeeef6), hairTip = hex(0xbfd0ff), hairStyle = "long", eye = hex(0xff6a6a), outfit = "armor", accent = hex(0xffc94a), stern = true },
		lines = {
			"The Crown Gate answers to Seat I and nobody else. Earn the seat, then knock.",
		},
	},
}

-- Students who simply hang around the island.
Roster.Crowd = {
	{ id = "s1", academy = "northwind", look = { fem = true, height = 0.95, skin = hex(0xf0cdb4), hair = hex(0x5b6ee1), hairTip = hex(0x9fb0ff), hairStyle = "bob", eye = hex(0x5b9bff), outfit = "skirt", accent = hex(0x39c9ff) } },
	{ id = "s2", academy = "northwind", look = { height = 1.0, skin = hex(0xc8946d), hair = hex(0x2b2b33), hairTip = hex(0x55606e), hairStyle = "spiky", eye = hex(0x6fe6ff), outfit = "coat", accent = hex(0x39c9ff) } },
	{ id = "s3", academy = "solcrest", look = { fem = true, height = 0.97, skin = hex(0x9c6a48), hair = hex(0x3a2418), hairTip = hex(0xffb62e), hairStyle = "bun", eye = hex(0xffb62e), outfit = "skirt", accent = hex(0xffb62e) } },
	{ id = "s4", academy = "solcrest", look = { height = 1.04, skin = hex(0xf2d4bd), hair = hex(0xe0b060), hairTip = hex(0xfff0c0), hairStyle = "slick", eye = hex(0x4f8fff), outfit = "coat", accent = hex(0xffb62e) } },
	{ id = "s5", academy = "arcline", look = { fem = true, height = 0.93, skin = hex(0xe6c1a5), hair = hex(0x8c5bff), hairTip = hex(0xe14bff), hairStyle = "twin", eye = hex(0xe14bff), outfit = "hoodie", accent = hex(0xe14bff), glasses = true } },
	{ id = "s6", academy = "arcline", look = { height = 0.99, skin = hex(0x7a4f36), hair = hex(0x151520), hairTip = hex(0x8c5bff), hairStyle = "ponytail", eye = hex(0xb6fff3), outfit = "hoodie", accent = hex(0xe14bff) } },
	{ id = "s7", academy = "ironreach", look = { height = 1.08, bulk = 1.12, skin = hex(0xd9a680), hair = hex(0x8a2f1c), hairTip = hex(0xff5a2a), hairStyle = "spiky", eye = hex(0xff9d3a), outfit = "armor", accent = hex(0xff5a2a) } },
	{ id = "s8", academy = "ironreach", look = { fem = true, height = 1.0, skin = hex(0xb07a55), hair = hex(0x1a1a1a), hairTip = hex(0xff7a2a), hairStyle = "long", eye = hex(0xffc04a), outfit = "coat", accent = hex(0xff5a2a) } },
	{ id = "s9", academy = "solcrest", look = { fem = true, height = 0.9, skin = hex(0xf4d6c0), hair = hex(0xffe08a), hairTip = hex(0xffffff), hairStyle = "ponytail", eye = hex(0x7fd96b), outfit = "hoodie", accent = hex(0xffb62e) } },
	{ id = "s10", academy = "northwind", look = { height = 1.05, skin = hex(0x6e4630), hair = hex(0xd9e2f2), hairTip = hex(0x7fcfff), hairStyle = "slick", eye = hex(0x39c9ff), outfit = "coat", accent = hex(0x39c9ff), glasses = true } },
}

-- People you can just talk to: a guide outside every school tower and the folk of Halcyon City.
Roster.Talkers = {
	{
		id = "guide_northwind", name = "Aoi Frost", epithet = "Northwind Prefect", academy = "northwind",
		look = { fem = true, height = 0.97, skin = hex(0xf2d2bc), hair = hex(0xe6eefa), hairTip = hex(0x7fcfff), hairStyle = "long", eye = hex(0x39c9ff), outfit = "coat", accent = hex(0x39c9ff) },
		lines = {
			"Welcome to Northwind Academy. The twin spires behind me are our dormitories and the training decks.",
			"Northwind duelists favour the saber. Patience first, then one clean line.",
			"Our Register is the hardest to climb. Everyone here is quiet, and everyone here is dangerous.",
		},
	},
	{
		id = "guide_solcrest", name = "Rafael Sol", epithet = "Solcrest Prefect", academy = "solcrest",
		look = { height = 1.04, skin = hex(0xc08a62), hair = hex(0x3a2418), hairTip = hex(0xffb62e), hairStyle = "spiky", eye = hex(0xffb62e), outfit = "coat", accent = hex(0xffb62e) },
		lines = {
			"Morning! Or it is morning somewhere. Solcrest students are always up before the sun.",
			"Five terraces, one for each year, and the Sun Crown on top. Only Seat I eats lunch up there.",
			"Pick up a lance and keep your rival at the tip of it. That is the Solcrest way.",
		},
	},
	{
		id = "guide_arcline", name = "Pip Calloway", epithet = "Arcline Lab Assistant", academy = "arcline",
		look = { fem = true, height = 0.9, skin = hex(0xe9c6ab), hair = hex(0x8c5bff), hairTip = hex(0xe14bff), hairStyle = "twin", eye = hex(0xb6fff3), outfit = "hoodie", accent = hex(0xe14bff), glasses = true },
		lines = {
			"Careful near the rings, they hum when the reactor is warm. Which is always.",
			"Every Arcline weapon is built in-house. The Orbit Discs started as a cooling-fan accident!",
			"Range, angles and timing. If you are close enough to be hit, you have already made a mistake.",
		},
	},
	{
		id = "guide_ironreach", name = "Bruno Kessler", epithet = "Ironreach Forgehand", academy = "ironreach",
		look = { height = 1.12, bulk = 1.2, skin = hex(0x9a6844), hair = hex(0x1a1a1a), hairTip = hex(0xff7a2a), hairStyle = "slick", eye = hex(0xff9d3a), outfit = "armor", accent = hex(0xff5a2a), stern = true },
		lines = {
			"The Citadel keeps its forges running day and night. You get used to the heat.",
			"Ironreach does not dodge. We plant our feet and swing the maul harder than you.",
			"Want our respect? Get knocked down and stand back up. Then do it again.",
		},
	},
	{
		id = "city_vendor", name = "Mama Ito", epithet = "Ramen Stand", academy = "city",
		look = { fem = true, height = 0.92, skin = hex(0xf0cfb4), hair = hex(0x6e6e78), hairTip = hex(0xb0b0bb), hairStyle = "bun", eye = hex(0x5b4636), outfit = "staff", accent = hex(0xff7a2a) },
		lines = {
			"Welcome, welcome! Sit down, you look like you lost a duel.",
			"Every Crownbearer in twenty years has eaten at my counter. Not one of them paid on time.",
		},
	},
	{
		id = "city_guide", name = "Officer Danvers", epithet = "City Patrol", academy = "city",
		look = { height = 1.05, skin = hex(0x7a4f36), hair = hex(0x1a1414), hairTip = hex(0x3a2a22), hairStyle = "slick", eye = hex(0x6fe6ff), outfit = "staff", accent = hex(0x39c9ff), stern = true },
		lines = {
			"Halcyon City. Shops, arcades, the best ramen in the sky. No duels on the streets, please.",
			"The Skybridge takes you back to Academy Island. The four towers are hard to miss.",
		},
	},
	{
		id = "city_kid", name = "Milo", epithet = "Future Crownbearer", academy = "city",
		look = { height = 0.78, skin = hex(0xf4d6c0), hair = hex(0xffd24a), hairTip = hex(0xff7a2a), hairStyle = "spiky", eye = hex(0x39c9ff), outfit = "hoodie", accent = hex(0xffd24a) },
		lines = {
			"Are you a real student?! Which school? Did you beat anyone? Who is your rank?",
			"When I grow up I am going to hold Seat I at EVERY academy. At the same time.",
		},
	},
	{
		id = "bridge_guard", name = "Sentinel Ward", epithet = "Skybridge Watch", academy = "city",
		look = { height = 1.08, bulk = 1.1, skin = hex(0xd9b08c), hair = hex(0x8d8f96), hairTip = hex(0xc9ccd4), hairStyle = "slick", eye = hex(0x7ad0c0), outfit = "armor", accent = hex(0x6fe6ff), stern = true },
		lines = {
			"Halcyon City is straight ahead. Academy Island is behind you. Mind the drop.",
		},
	},
}

local byId = {}
for _, list in { Roster.Seats, Roster.Aces, Roster.Staff, Roster.Crowd, Roster.Talkers } do
	for _, npc in list do
		byId[npc.id] = npc
	end
end
Roster.ById = byId

function Roster.get(id: string)
	return byId[id]
end

--- The default ladder: seat-holder ids from Seat I down to Seat XII.
function Roster.defaultLadder(): { string }
	local out = {}
	for i, npc in Roster.Seats do
		out[i] = npc.id
	end
	return out
end

function Roster.aceOf(academyId: string)
	for _, ace in Roster.Aces do
		if ace.academy == academyId then
			return ace
		end
	end
	return nil
end

--- The three aces a student of `academyId` meets in the Crown Trials, weakest first.
function Roster.trialOrder(academyId: string): { string }
	local out = {}
	for _, ace in Roster.Aces do
		if ace.academy ~= academyId then
			table.insert(out, ace.id)
		end
	end
	return out
end

return Roster
