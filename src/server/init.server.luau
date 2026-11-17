--!nonstrict
-- Halcyon Clash server entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Roster = require(Shared:WaitForChild("Roster"))
local World = require(script:WaitForChild("World"))
local Npcs = require(script:WaitForChild("Npcs"))
local Atmos = require(script:WaitForChild("Atmos"))

-- The baked place already contains the world; this only fills in anything missing.
World.build(game)
Atmos.clouds(Workspace)

local remotes = ReplicatedStorage:FindFirstChild(Config.RemotesName)
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = Config.RemotesName
	remotes.Parent = ReplicatedStorage
end
local function remote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end
local Dialogue = remote("Dialogue")

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	local open = prompt:GetAttribute("Open")
	if type(open) ~= "string" then
		return
	end
	local kind, id = string.match(open, "^(%w+):(.+)$")
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
