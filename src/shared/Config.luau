--!nonstrict
-- Config: names, colours and tuning shared by the server and the client.

local Config = {}

Config.GameName = "Halcyon Clash"
Config.Version = "0.2.0"

-- Saved data. Change the name to wipe every profile (useful while you are still testing).
Config.DataStoreName = "HalcyonClash_v1"

local function hex(n: number): Color3
	return Color3.fromRGB(bit32.band(bit32.rshift(n, 16), 255), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end
Config.hex = hex

-- ---------------------------------------------------------------------------------------------
-- The four academies of Halcyon
-- ---------------------------------------------------------------------------------------------
Config.AcademyOrder = { "northwind", "solcrest", "arcline", "ironreach" }

Config.Academies = {
	northwind = {
		id = "northwind",
		name = "Northwind Academy",
		short = "Northwind",
		motto = "Still water cuts deepest.",
		blurb = "Patient, precise duelists. Northwind students learn to end a fight with one clean line.",
		accent = hex(0x39c9ff),
		ace = "kaito",
		uniform = { jacket = hex(0xe8ecf5), trim = hex(0x39c9ff), dark = hex(0x1a2340), pants = hex(0x1a2340), boots = hex(0x0f1322), glove = hex(0x1a2340) },
	},
	solcrest = {
		id = "solcrest",
		name = "Solcrest Institute",
		short = "Solcrest",
		motto = "Rise before the sun does.",
		blurb = "Discipline and reach. Solcrest drills its students until the lance moves on its own.",
		accent = hex(0xffb62e),
		ace = "sera",
		uniform = { jacket = hex(0x24356a), trim = hex(0xffb62e), dark = hex(0x141d36), pants = hex(0xf3efe6), boots = hex(0xf3efe6), glove = hex(0xf3efe6) },
	},
	arcline = {
		id = "arcline",
		name = "Arcline Polytechnic",
		short = "Arcline",
		motto = "Measure twice. Fire once.",
		blurb = "Tinkerers and tacticians. Arcline builds its own Lumen gear and fights from a distance.",
		accent = hex(0xe14bff),
		ace = "mira",
		uniform = { jacket = hex(0x6a4fa3), trim = hex(0xe14bff), dark = hex(0x1b1a26), pants = hex(0x1b1a26), boots = hex(0xe9e9f2), glove = hex(0x1b1a26) },
	},
	ironreach = {
		id = "ironreach",
		name = "Ironreach Citadel",
		short = "Ironreach",
		motto = "Stand. Then stand again.",
		blurb = "Raised in the forge districts. Ironreach duelists take the hit and answer with a bigger one.",
		accent = hex(0xff5a2a),
		ace = "drake",
		uniform = { jacket = hex(0x3a3e4a), trim = hex(0xff5a2a), dark = hex(0x23262e), pants = hex(0x444854), boots = hex(0x15161b), glove = hex(0x15161b) },
	},
}

-- ---------------------------------------------------------------------------------------------
-- The Register: twelve ranked seats. Index 1 is Seat I.
-- ---------------------------------------------------------------------------------------------
Config.SeatCount = 12
Config.Roman = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }
Config.ChallengeReach = 3 -- how many seats above your own you may challenge

Config.Stats = {
	{ id = "power", name = "Power", desc = "+5% damage per point", max = 8 },
	{ id = "vitality", name = "Vitality", desc = "+6% sigil integrity (health) per point", max = 8 },
	{ id = "agility", name = "Agility", desc = "+2.5% speed and faster dash recovery per point", max = 8 },
	{ id = "focus", name = "Focus", desc = "+8% Lumen gain per point", max = 8 },
}
Config.PointsPerLevel = 2
Config.MaxLevel = 40

-- Techniques granted by the best seat you have ever held.
Config.Perks = {
	{ id = "keen", seat = 9, name = "Keen Guard", desc = "The Perfect Guard window is 40% longer." },
	{ id = "wind", seat = 6, name = "Second Wind", desc = "Once per round, dropping below 25% restores 20% of your sigil." },
	{ id = "over", seat = 3, name = "Overdrive", desc = "Start every round with half your Lumen gauge." },
	{ id = "mantle", seat = 1, name = "Crownbearer's Mantle", desc = "All of your attacks deal 10% more damage." },
}

Config.TrialLevels = { 20, 21, 23 }

-- ---------------------------------------------------------------------------------------------
-- Combat tuning (distances in studs, times in seconds)
-- ---------------------------------------------------------------------------------------------
Config.Combat = {
	LumenMax = 100,
	SkillCost = 33,
	GuardChip = 0.2, -- share of damage that gets through a normal guard
	HeavyChip = 0.32,
	PerfectWindow = 0.2, -- guard pressed this long before a hit lands = Perfect Guard
	PerfectStagger = 0.75,
	DashTime = 0.3,
	DashInvuln = 0.26,
	DashCooldown = 1.0,
	DashSpeed = 64,
	DownTime = 1.0, -- time on the floor after a launch
	GetupTime = 0.45,
	ComboScale = 0.08, -- damage falloff per hit inside one combo
	ComboFloor = 0.6,
	RoundTime = 99,
	IntroTime = 3.2,
	KoTime = 2.6,
	BaseWalk = 2.8, -- studs per second for each point of a weapon's speed stat
	ArenaRadius = 44,
	FighterGap = 30, -- distance between the duelists at the start of a round
	InputBuffer = 0.22,
}

Config.Campus = {
	WalkSpeed = 20,
	SprintSpeed = 32,
}

-- Rewards
Config.Rewards = {
	WinCoinsBase = 40,
	WinCoinsPerLevel = 6,
	LoseCoins = 10,
	SparCoins = 8,
	TrialCoins = 400,
	ChampionCoins = 1500,
}

-- ---------------------------------------------------------------------------------------------
-- Sound. These are sounds that ship inside the Roblox client, so the game needs no uploads.
-- Swap any of them for your own asset ids ("rbxassetid://123") whenever you like.
-- ---------------------------------------------------------------------------------------------
Config.Sounds = {
	Swing = { id = "rbxasset://sounds/swordslash.wav", volume = 0.5 },
	Lunge = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.5 },
	Draw = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6 },
	Hit = { id = "rbxasset://sounds/hit.wav", volume = 0.7 },
	Heavy = { id = "rbxasset://sounds/collide.wav", volume = 0.9 },
	Guard = { id = "rbxasset://sounds/snap.mp3", volume = 0.6 },
	Perfect = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8 },
	Shot = { id = "rbxasset://sounds/paintball.wav", volume = 0.5 },
	Dash = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.35 },
	Ult = { id = "rbxasset://sounds/HalloweenThunder.wav", volume = 0.7 },
	Ko = { id = "rbxasset://sounds/bass.wav", volume = 0.9 },
	Click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	Open = { id = "rbxasset://sounds/switch.wav", volume = 0.5 },
	Win = { id = "rbxasset://sounds/victory.wav", volume = 0.6 },
	Coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	Music = { id = "", volume = 0.35 }, -- put a music asset id here to add a soundtrack
}

-- Tags and names used to find things in the world
Config.WorldName = "HalcyonWorld"
Config.ArenaTemplateName = "HalcyonArenaTemplate"
Config.RemotesName = "HalcyonRemotes"

return Config
