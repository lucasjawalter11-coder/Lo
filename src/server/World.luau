--!nonstrict
-- World: builds everything that exists before a player joins (campus, NPCs, arena template, lighting).
-- The offline bake calls this to put the world into the place file; at runtime the server calls it too
-- and it only builds whatever is missing.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Campus = require(script.Parent.Campus)
local Npcs = require(script.Parent.Npcs)
local Arena = require(script.Parent.Arena)
local Atmos = require(script.Parent.Atmos)

local World = {}

function World.build(dataModel)
	local workspace = dataModel:GetService("Workspace")
	local world = workspace:FindFirstChild(Config.WorldName)
	if not world then
		world = Campus.build(workspace)
	end
	Npcs.build(world)
	local storage = dataModel:GetService("ServerStorage")
	if not storage:FindFirstChild(Config.ArenaTemplateName) then
		Arena.build(storage)
	end
	Atmos.apply(dataModel)
	return world
end

return World
