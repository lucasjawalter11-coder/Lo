--!nonstrict
-- Looks: the character customisation options and the saved look format.
-- A look stores option indices, so a saved profile stays small and is easy to validate.
local Config = require(script.Parent.Config)
local hex = Config.hex

local Looks = {}

Looks.Skin = {
	{ name = "Porcelain", color = hex(0xf6dccb) },
	{ name = "Fair", color = hex(0xf0c8ad) },
	{ name = "Warm", color = hex(0xe2b594) },
	{ name = "Honey", color = hex(0xd9a37e) },
	{ name = "Tan", color = hex(0xc08a62) },
	{ name = "Bronze", color = hex(0xa5663f) },
	{ name = "Umber", color = hex(0x7a4f36) },
	{ name = "Deep", color = hex(0x5a3826) },
}

Looks.HairStyles = {
	{ id = "spiky", name = "Spiky" },
	{ id = "short", name = "Short" },
	{ id = "slick", name = "Swept back" },
	{ id = "bob", name = "Bob" },
	{ id = "ponytail", name = "Ponytail" },
	{ id = "long", name = "Long" },
	{ id = "twin", name = "Twin tails" },
	{ id = "bun", name = "Bun" },
}

Looks.HairColors = {
	{ name = "Ink", color = hex(0x14131a), tip = hex(0x3a3a4a) },
	{ name = "Chestnut", color = hex(0x5a3522), tip = hex(0x8a5a3a) },
	{ name = "Copper", color = hex(0xb5482a), tip = hex(0xff7a3a) },
	{ name = "Gold", color = hex(0xe8c66a), tip = hex(0xfff0b0) },
	{ name = "Silver", color = hex(0xd9e2f2), tip = hex(0x7fcfff) },
	{ name = "Snow", color = hex(0xf4f4f8), tip = hex(0xbfd0ff) },
	{ name = "Sakura", color = hex(0xff8fb0), tip = hex(0xffd0dd) },
	{ name = "Violet", color = hex(0x6b2bd6), tip = hex(0xe14bff) },
	{ name = "Ocean", color = hex(0x2f5bd6), tip = hex(0x39c9ff) },
	{ name = "Mint", color = hex(0x35d6c3), tip = hex(0xb6fff3) },
	{ name = "Ember", color = hex(0x14110f), tip = hex(0xff5a2a) },
	{ name = "Moss", color = hex(0x2f6b4a), tip = hex(0x7dffb0) },
}

Looks.EyeColors = {
	{ name = "Azure", color = hex(0x2e9bff) },
	{ name = "Amber", color = hex(0xffa521) },
	{ name = "Violet", color = hex(0xc04dff) },
	{ name = "Ember", color = hex(0xff5a2a) },
	{ name = "Jade", color = hex(0x3fd08a) },
	{ name = "Rose", color = hex(0xff5f9a) },
	{ name = "Teal", color = hex(0x35d6c3) },
	{ name = "Hazel", color = hex(0x8a6a3a) },
}

Looks.Outfits = {
	{ id = "coat", name = "Long coat" },
	{ id = "skirt", name = "Pleated uniform" },
	{ id = "hoodie", name = "Hoodie" },
	{ id = "armor", name = "Light armour" },
}

-- Uniform for players who have not joined a school yet
Looks.VisitorUniform = { jacket = hex(0xe9ecf3), trim = hex(0x6fe6ff), dark = hex(0x2a3148), pants = hex(0x2a3148), boots = hex(0x15161b), glove = hex(0x2a3148) }
Looks.VisitorAccent = hex(0x6fe6ff)

-- The rows the Customize screen shows, in order. `list` is nil for the on/off row.
Looks.Fields = {
	{ key = "outfit", label = "Uniform", list = Looks.Outfits },
	{ key = "hair", label = "Hair style", list = Looks.HairStyles },
	{ key = "hairColor", label = "Hair colour", list = Looks.HairColors },
	{ key = "eye", label = "Eyes", list = Looks.EyeColors },
	{ key = "skin", label = "Skin tone", list = Looks.Skin },
	{ key = "avatar", label = "Wear my Roblox avatar" },
}

export type Look = { outfit: number, hair: number, hairColor: number, eye: number, skin: number, avatar: boolean }

function Looks.default(): Look
	return { outfit = 1, hair = 1, hairColor = 1, eye = 1, skin = 2, avatar = false }
end

local function index(value: any, list: { any }, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.clamp(math.floor(value), 1, #list)
end

--- Turns anything (a saved profile, a client request) into a valid look.
function Looks.sanitize(input: any): Look
	local d = Looks.default()
	if type(input) ~= "table" then
		return d
	end
	return {
		outfit = index(input.outfit, Looks.Outfits, d.outfit),
		hair = index(input.hair, Looks.HairStyles, d.hair),
		hairColor = index(input.hairColor, Looks.HairColors, d.hairColor),
		eye = index(input.eye, Looks.EyeColors, d.eye),
		skin = index(input.skin, Looks.Skin, d.skin),
		avatar = input.avatar == true,
	}
end

return Looks
