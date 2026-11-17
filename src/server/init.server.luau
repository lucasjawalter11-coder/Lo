--!nonstrict
-- Halcyon Clash server entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Roster = require(Shared:WaitForChild("Roster"))
local Looks = require(Shared:WaitForChild("Looks"))
local Appearance = require(Shared:WaitForChild("Appearance"))
local World = require(script:WaitForChild("World"))
local Npcs = require(script:WaitForChild("Npcs"))
local Atmos = require(script:WaitForChild("Atmos"))
local Profiles = require(script:WaitForChild("Profiles"))

-- Characters are only created when a player presses Start Game in the hub.
Players.CharacterAutoLoads = false

-- The baked place already contains the world; this only fills in anything missing.
local world = World.build(game)
Atmos.clouds(Workspace)
local anchors = world:WaitForChild("Anchors")
Profiles.start()

local remotes = ReplicatedStorage:FindFirstChild(Config.RemotesName)
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = Config.RemotesName
	remotes.Parent = ReplicatedStorage
end
local function remote(className: string, name: string)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remotes
	end
	return r
end
local Dialogue = remote("RemoteEvent", "Dialogue")
local MenuRemote = remote("RemoteFunction", "Menu")
local LiftRemote = remote("RemoteEvent", "Lift")

local previews = ReplicatedStorage:FindFirstChild(Config.PreviewsName)
if not previews then
	previews = Instance.new("Folder")
	previews.Name = Config.PreviewsName
	previews.Parent = ReplicatedStorage
end

-- ---------------------------------------------------------------------------------------------
-- Spawning
-- ---------------------------------------------------------------------------------------------
local function spawnPoint(schoolId: string?): CFrame
	local anchor = schoolId and anchors:FindFirstChild("Spawn_" .. schoolId) or anchors:FindFirstChild("Return_Default")
	if anchor then
		return anchor.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 8, 360)
end

local function dress(player: Player, character: Model)
	local profile = Profiles.get(player)
	if not profile then
		return
	end
	local started = os.clock()
	while not player:HasAppearanceLoaded() and os.clock() - started < 6 do
		task.wait(0.1)
	end
	if character.Parent then
		Appearance.apply(character, profile.look, profile.school)
	end
end

local function onCharacter(player: Player, character: Model)
	local profile = Profiles.get(player)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and profile then
		character:PivotTo(spawnPoint(profile.school))
	end
	task.spawn(dress, player, character)
	-- with the uniform on, accessories added later (slow avatar loads) are removed too
	character.ChildAdded:Connect(function(child)
		local p = Profiles.get(player)
		if p and not p.look.avatar and child:IsA("Accessory") then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = Config.Campus.WalkSpeed
		humanoid.Died:Connect(function()
			task.wait(4)
			if player.Parent and player.Character == character then
				player:LoadCharacter()
			end
		end)
	end
end

local function startGame(player: Player)
	local profile = Profiles.get(player)
	if not profile or not profile.school then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return true -- already playing: the hub was just a pause screen
	end
	pcall(function()
		player:RequestStreamAroundAsync(spawnPoint(profile.school).Position, 10)
	end)
	player:LoadCharacter()
	return true
end

-- ---------------------------------------------------------------------------------------------
-- The hub menu
-- ---------------------------------------------------------------------------------------------
local lastCall: { [Player]: number } = {}

local function makePreview(player: Player)
	if previews:FindFirstChild(tostring(player.UserId)) then
		return
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(player.UserId)
	end)
	if ok and model then
		model.Name = tostring(player.UserId)
		for _, d in model:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		model.Archivable = true
		model.Parent = previews
	end
end

MenuRemote.OnServerInvoke = function(player: Player, action: any, payload: any)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.15 then
		return nil
	end
	lastCall[player] = now
	local profile = Profiles.get(player)
	if not profile then
		return nil
	end
	if action == "profile" then
		task.spawn(makePreview, player)
		return { school = profile.school, look = profile.look, customised = profile.customised }
	elseif action == "look" then
		profile.look = Looks.sanitize(payload)
		profile.customised = true
		Profiles.markDirty(player)
		local character = player.Character
		if character then
			Appearance.apply(character, profile.look, profile.school)
		end
		return profile.look
	elseif action == "start" then
		local school = type(payload) == "table" and payload.school
		if type(school) == "string" and Config.Academies[school] and school ~= profile.school then
			profile.school = school
			Profiles.markDirty(player)
			Profiles.save(player)
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				-- switching school mid-game: walk out of the hub at the new campus
				Appearance.apply(character, profile.look, profile.school)
				character:PivotTo(spawnPoint(school))
			end
		end
		return startGame(player)
	end
	return nil
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		player.ReplicationFocus = nil
		onCharacter(player, character)
	end)
	Profiles.load(player)
	-- while in the hub, stream the world around the central spire for the menu camera
	local spire = world:FindFirstChild("SpireCore", true)
	if spire and not player.Character then
		player.ReplicationFocus = spire
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
	local preview = previews:FindFirstChild(tostring(player.UserId))
	if preview then
		preview:Destroy()
	end
end)

-- ---------------------------------------------------------------------------------------------
-- Talking to NPCs
-- ---------------------------------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	local open = prompt:GetAttribute("Open")
	if type(open) ~= "string" then
		return
	end
	local kind, id = string.match(open, "^(%w+):(.+)$")
	if kind == "lift" then
		-- the Skylift between the foot of the central tower and the Sky Arena
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (humanoid and humanoid.Health > 0) then
			return
		end
		local target = if id == "up" then anchors:FindFirstChild("LiftTop") else anchors:FindFirstChild("LiftBottom_0")
		if target then
			pcall(function()
				player:RequestStreamAroundAsync(target.CFrame.Position, 5)
			end)
			character:PivotTo(target.CFrame)
			LiftRemote:FireClient(player, id)
		end
		return
	end
	if kind == "talk" then
		local npc = Roster.get(id)
		if not npc then
			return
		end
		local model = prompt:FindFirstAncestorOfClass("Model")
		local root = model and model.PrimaryPart
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		-- turn the NPC to face whoever is talking to them
		if model and root and hrp then
			local from = root.Position
			local to = Vector3.new(hrp.Position.X, from.Y, hrp.Position.Z)
			if (to - from).Magnitude > 0.5 then
				model:PivotTo(CFrame.lookAt(from, to))
			end
		end
		Dialogue:FireClient(player, {
			id = id,
			name = npc.name or "Student",
			title = npc.epithet or "",
			accent = npc.look.accent,
			lines = Npcs.linesFor(npc),
		})
	end
end)
