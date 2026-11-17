--!nonstrict
-- Rig: a standard R15 body built from parts and Motor6Ds. Used for NPC duelists (so they animate with the
-- same poses as players) and by the offline pose renderer. Feet stand on the origin, facing -Z.
local Rig = {}

local PARTS = {
	-- name, size, centre
	{ "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3.0, 0) },
	{ "LowerTorso", Vector3.new(2, 0.6, 1), Vector3.new(0, 2.9, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 4.0, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5.45, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 4.2, 0) },
	{ "RightLowerArm", Vector3.new(1, 1.0, 1), Vector3.new(1.5, 3.1, 0) },
	{ "RightHand", Vector3.new(1, 0.5, 1), Vector3.new(1.5, 2.35, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 4.2, 0) },
	{ "LeftLowerArm", Vector3.new(1, 1.0, 1), Vector3.new(-1.5, 3.1, 0) },
	{ "LeftHand", Vector3.new(1, 0.5, 1), Vector3.new(-1.5, 2.35, 0) },
	{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, 2.0, 0) },
	{ "RightLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(0.5, 0.95, 0) },
	{ "RightFoot", Vector3.new(1, 0.4, 1.1), Vector3.new(0.5, 0.2, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, 2.0, 0) },
	{ "LeftLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(-0.5, 0.95, 0) },
	{ "LeftFoot", Vector3.new(1, 0.4, 1.1), Vector3.new(-0.5, 0.2, 0) },
}

-- joint name, parent part, child part, pivot point (world, at rest)
local JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, 2.9, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 3.2, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 4.8, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.5, 4.7, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.5, 3.6, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.5, 2.6, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.5, 4.7, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.5, 3.6, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.5, 2.6, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, 2.6, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.5, 1.5, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.5, 0.4, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, 2.6, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.5, 1.5, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.5, 0.4, 0) },
}
Rig.Joints = JOINTS

--- Builds an R15 rig model with a Humanoid. `cf` places the feet (default: origin, facing -Z).
function Rig.build(name: string?, cf: CFrame?): Model
	local model = Instance.new("Model")
	model.Name = name or "Rig"
	local parts = {}
	for _, def in PARTS do
		local p = Instance.new("Part")
		p.Name = def[1]
		p.Size = def[2]
		p.CFrame = CFrame.new(def[3])
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = Color3.fromRGB(240, 200, 173)
		p.CanCollide = def[1] == "HumanoidRootPart" or def[1] == "LowerTorso" or def[1] == "UpperTorso"
		if def[1] == "HumanoidRootPart" then
			p.Transparency = 1
		end
		p.Parent = model
		parts[def[1]] = p
	end
	for _, j in JOINTS do
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		m.Part0 = parts[j[2]]
		m.Part1 = parts[j[3]]
		m.C0 = CFrame.new(j[4] - parts[j[2]].CFrame.Position)
		m.C1 = CFrame.new(j[4] - parts[j[3]].CFrame.Position)
		m.Parent = parts[j[3]]
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 2.0
	hum.Parent = model
	model.PrimaryPart = parts.HumanoidRootPart
	if cf then
		local delta = cf
		for _, p in parts do
			p.CFrame = delta * p.CFrame
		end
	end
	return model
end

--- Forward kinematics without physics: places every part from the root using a pose (joint -> CFrame).
--- Only needed offline; inside Roblox the Motor6Ds do this themselves.
function Rig.applyPose(model: Model, pose: { [string]: CFrame })
	local root = model:FindFirstChild("HumanoidRootPart")
	local function walk(part: BasePart)
		for _, j in JOINTS do
			if j[2] == part.Name then
				local child = model:FindFirstChild(j[3])
				local motor = child and child:FindFirstChild(j[1])
				if child and motor then
					local t = pose[j[1]] or CFrame.new()
					child.CFrame = part.CFrame * motor.C0 * t * motor.C1:Inverse()
					walk(child)
				end
			end
		end
	end
	walk(root)
end

return Rig
