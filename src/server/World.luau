--!nonstrict
-- World: builds everything that exists before a player joins (campus, arena template, NPCs, lighting).
-- The offline bake calls this to put the world into the place file; at runtime the server calls it too
-- and it only builds whatever is missing.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Campus = require(script.Parent.Campus)

local World = {}

function World.build(dataModel)
	local workspace = dataModel:GetService("Workspace")
	local world = workspace:FindFirstChild(Config.WorldName)
	if not world then
		world = Campus.build(workspace)
	end
	return world
end

return World
