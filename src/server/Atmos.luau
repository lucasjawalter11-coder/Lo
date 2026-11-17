--!nonstrict
-- Atmos: lighting, sky and post-processing. Golden hour over a sky city, with bloom for the Lumen glow.
-- (Lighting.Technology = Future is set in default.project.json because scripts cannot change it.)
local Kit = require(script.Parent.Kit)

local Atmos = {}

local function ensure(parent: Instance, className: string, props: { [string]: any })
	local inst = parent:FindFirstChildOfClass(className)
	if not inst then
		inst = Instance.new(className)
		inst.Parent = parent
	end
	for key, value in props do
		(inst :: any)[key] = value
	end
	return inst
end

function Atmos.apply(dataModel)
	local lighting = dataModel:GetService("Lighting")
	lighting.ClockTime = 17.25
	lighting.GeographicLatitude = 24
	lighting.Brightness = 2.7
	lighting.ExposureCompensation = 0.2
	lighting.EnvironmentDiffuseScale = 0.9
	lighting.EnvironmentSpecularScale = 1
	lighting.GlobalShadows = true
	lighting.ShadowSoftness = 0.22
	lighting.Ambient = Color3.fromRGB(74, 80, 112)
	lighting.OutdoorAmbient = Color3.fromRGB(126, 128, 152)
	lighting.ColorShift_Top = Color3.fromRGB(255, 214, 168)
	lighting.ColorShift_Bottom = Color3.fromRGB(120, 130, 190)

	ensure(lighting, "Sky", { SunAngularSize = 15, MoonAngularSize = 9, StarCount = 3000, CelestialBodiesShown = true })
	ensure(lighting, "Atmosphere", {
		Density = 0.3,
		Offset = 0.22,
		Color = Color3.fromRGB(204, 196, 226),
		Decay = Color3.fromRGB(255, 186, 142),
		Glare = 0.45,
		Haze = 1.7,
	})
	ensure(lighting, "BloomEffect", { Intensity = 0.85, Size = 30, Threshold = 1.15 })
	ensure(lighting, "ColorCorrectionEffect", { Brightness = 0.02, Contrast = 0.14, Saturation = 0.2, TintColor = Color3.fromRGB(255, 247, 238) })
	ensure(lighting, "SunRaysEffect", { Intensity = 0.11, Spread = 0.62 })
	ensure(lighting, "DepthOfFieldEffect", { FarIntensity = 0.14, FocusDistance = 70, InFocusRadius = 110, NearIntensity = 0 })
end

--- Volumetric clouds live under Terrain, which only exists inside Roblox, so this part runs at server start.
function Atmos.clouds(workspace: Instance)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		Kit.new("Clouds", { Cover = 0.58, Density = 0.62, Color = Color3.fromRGB(255, 236, 220) }, terrain)
	end
end

return Atmos
