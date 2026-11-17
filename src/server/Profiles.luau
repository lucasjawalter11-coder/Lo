--!nonstrict
-- Profiles: each player's saved data (school, look, coins). Saved with DataStoreService.
-- In Studio, saving needs "Enable Studio Access to API Services" (Game Settings > Security);
-- without it the game still runs and simply forgets profiles when the server closes.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Looks = require(Shared:WaitForChild("Looks"))

local Profiles = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Halcyon] Saving is off: " .. tostring(result))
	end
end

local cache: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}

local function key(player: Player): string
	return "p_" .. player.UserId
end

local function blank()
	return { v = 1, school = nil, look = Looks.default(), coins = 0, customised = false }
end

local function clean(data)
	local p = blank()
	if type(data) == "table" then
		if type(data.school) == "string" and Config.Academies[data.school] then
			p.school = data.school
		end
		p.look = Looks.sanitize(data.look)
		p.coins = if type(data.coins) == "number" then math.max(0, math.floor(data.coins)) else 0
		p.customised = data.customised == true
	end
	return p
end

function Profiles.load(player: Player)
	local data = nil
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result
				break
			end
			warn("[Halcyon] Could not load profile (attempt " .. attempt .. "): " .. tostring(result))
			task.wait(attempt)
		end
	end
	cache[player] = clean(data)
	return cache[player]
end

function Profiles.get(player: Player)
	return cache[player]
end

function Profiles.markDirty(player: Player)
	dirty[player] = true
end

function Profiles.save(player: Player)
	local profile = cache[player]
	if not (store and profile) then
		return
	end
	dirty[player] = nil
	local ok, err = pcall(function()
		store:SetAsync(key(player), profile)
	end)
	if not ok then
		warn("[Halcyon] Could not save profile: " .. tostring(err))
		dirty[player] = true
	end
end

function Profiles.release(player: Player)
	Profiles.save(player)
	cache[player] = nil
	dirty[player] = nil
end

function Profiles.start()
	Players.PlayerRemoving:Connect(Profiles.release)
	game:BindToClose(function()
		for player in cache do
			Profiles.save(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in dirty do
				Profiles.save(player)
			end
		end
	end)
end

return Profiles
