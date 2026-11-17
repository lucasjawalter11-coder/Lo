--!nonstrict
-- Npcs: builds every designed NPC as a block-styled anime character and stands them on their posts.
-- Posts are the "Npc_<id>" anchors the campus builder leaves behind. A character faces its post's -Z.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("HalcyonShared")
local Config = require(Shared:WaitForChild("Config"))
local Roster = require(Shared:WaitForChild("Roster"))
local Kit = require(script.Parent.Kit)

local M = Enum.Material
local hex = Kit.hex

local Npcs = {}

local STAFF_UNIFORM = { jacket = hex(0x2b2f45), trim = hex(0xffc94a), dark = hex(0x1b1e2c), pants = hex(0x1b1e2c), boots = hex(0x111320), glove = hex(0xf0f0f5) }
local CITY_UNIFORM = { jacket = hex(0x4a5270), trim = hex(0x6fe6ff), dark = hex(0x252a3c), pants = hex(0x2f3448), boots = hex(0x15161b), glove = hex(0x252a3c) }

local CROWD_LINES = {
	northwind = { "Did you see the spar on the training deck? Not a single wasted move.", "Quiet, please. I am visualising my next duel." },
	solcrest = { "Up at four, drills at five. Do not ask me how I am still awake.", "Our Seat I could hit a coin off your shoulder with a lance." },
	arcline = { "My pistols jammed mid-duel. Again. I swear they have opinions.", "Have you tried the new Lumen cells at the market? Zero recoil!" },
	ironreach = { "You want to arm-wrestle? No? Smart.", "The forge smell never leaves your coat. You learn to like it." },
}

local function uniformFor(npc)
	if npc.academy == "staff" then
		return STAFF_UNIFORM
	elseif npc.academy == "city" then
		return CITY_UNIFORM
	end
	return Config.Academies[npc.academy].uniform
end

--- Builds one character model. Origin = feet, facing -Z.
function Npcs.rig(npc, cf: CFrame): Model
	local look = npc.look
	local u = uniformFor(npc)
	local h = look.height or 1
	local w = (look.bulk or 1) * (if look.fem then 0.92 else 1)
	local model = Instance.new("Model")
	model.Name = npc.name or npc.id
	local b = Kit.at(model, cf)

	local legH, torsoH, headS = 2.5 * h, 2.1 * h, 1.45
	local hipY = legH
	local shoulderY = hipY + torsoH
	local skin, hair, tip = look.skin, look.hair, look.hairTip

	local root = b:box(0, 0, 0, 2 * w, legH + torsoH, 1, hex(0xffffff), M.SmoothPlastic, { name = "HumanoidRootPart", trans = 1, decor = true })
	model.PrimaryPart = root

	-- legs and boots
	for _, sx in { -0.5 * w, 0.5 * w } do
		local legColor = if look.outfit == "skirt" or look.fem then Kit.mix(skin, hex(0x1b1a26), 0.75) else u.pants
		b:box(sx, 0.6, 0, 0.88 * w, legH - 0.6, 0.9, legColor, M.SmoothPlastic, { decor = true, name = "Leg" })
		b:box(sx, 0, -0.1, 0.96 * w, 1.0 + 0.2 * h, 1.15, u.boots, M.SmoothPlastic, { decor = true, name = "Boot" })
	end

	-- torso
	local torso = b:box(0, hipY, 0, 2 * w, torsoH, 1.05, u.jacket, M.SmoothPlastic, { decor = true, name = "UpperTorso" })
	b:box(0, hipY + torsoH * 0.55, -0.54, 0.5, torsoH * 0.4, 0.06, u.trim or look.accent, M.Neon, { decor = true })
	b:box(0, hipY - 0.05, 0, 2.05 * w, 0.3, 1.1, u.dark, M.SmoothPlastic, { decor = true, name = "Belt" })
	if look.outfit == "skirt" then
		b:box(0, hipY - 1.25, 0, 2.2 * w, 1.25, 1.2, u.dark, M.Fabric, { decor = true, name = "Skirt" })
		b:box(0, hipY - 1.25, -0.61, 2.2 * w, 0.12, 0.02, look.accent, M.Neon, { decor = true })
	elseif look.outfit == "coat" then
		b:box(0, hipY - 1.6, 0.2, 2.1 * w, 1.6, 0.6, u.jacket, M.Fabric, { decor = true, name = "CoatTail" })
		b:box(0, hipY - 1.6, 0.51, 2.1 * w, 0.15, 0.02, look.accent, M.Neon, { decor = true })
	elseif look.outfit == "hoodie" then
		b:box(0, shoulderY - 0.5, 0.55, 1.6 * w, 0.9, 0.35, u.jacket, M.Fabric, { decor = true, name = "Hood" })
		b:box(0, hipY + 0.2, -0.54, 1.2 * w, 0.6, 0.06, Kit.shade(u.jacket, 0.8), M.Fabric, { decor = true })
	elseif look.outfit == "armor" then
		b:box(0, hipY + 0.3, 0, 2.15 * w, torsoH * 0.7, 1.2, hex(0x8b8f9a), M.Metal, { decor = true, name = "Breastplate" })
		b:box(0, hipY + torsoH * 0.45, -0.61, 1.1, 0.25, 0.04, look.accent, M.Neon, { decor = true })
	elseif look.outfit == "staff" then
		b:box(0, 0.9, 0.05, 2.1 * w, hipY - 0.9, 1.15, u.jacket, M.Fabric, { decor = true, name = "Robe" })
		b:box(0, 0.9, -0.53, 0.18, hipY - 0.9, 0.04, u.trim, M.Neon, { decor = true })
	end

	-- arms
	for _, side in { -1, 1 } do
		local ax = side * (w + 0.45 * w)
		local sleeve = if look.outfit == "armor" then skin else u.jacket
		b:box(ax, shoulderY - 1.95 * h, 0, 0.85 * w, 1.95 * h, 0.85, sleeve, M.SmoothPlastic, { decor = true, name = "Arm" })
		b:box(ax, shoulderY - 2.5 * h, 0, 0.8 * w, 0.6, 0.8, if look.outfit == "armor" then hex(0x8b8f9a) else u.glove, M.SmoothPlastic, { decor = true, name = "Hand" })
		if look.outfit == "armor" then
			b:box(ax, shoulderY - 0.45, 0, 1.15 * w, 0.75, 1.15, hex(0x8b8f9a), M.Metal, { decor = true, name = "Pauldron" })
		else
			b:box(ax, shoulderY - 1.0 * h, 0, 0.9 * w, 0.12, 0.9, look.accent, M.Neon, { decor = true })
		end
	end
	b:box(0, shoulderY, 0, 0.6, 0.35, 0.6, skin, M.SmoothPlastic, { decor = true, name = "Neck" })

	-- head
	local hy = shoulderY + 0.3
	local head = b:box(0, hy, 0, headS, headS, headS, skin, M.SmoothPlastic, { name = "Head", decor = true })
	local fy = hy + headS * 0.48
	for _, sx in { -0.32, 0.32 } do
		b:box(sx, fy - 0.2, -headS / 2 - 0.01, 0.3, 0.42, 0.04, hex(0xffffff), M.SmoothPlastic, { decor = true, name = "EyeWhite" })
		b:box(sx, fy - 0.16, -headS / 2 - 0.03, 0.22, 0.34, 0.04, look.eye, M.Neon, { decor = true, name = "Iris" })
		b:box(sx, fy - 0.08, -headS / 2 - 0.05, 0.1, 0.12, 0.03, hex(0x10121a), M.SmoothPlastic, { decor = true, name = "Pupil" })
		local tilt = if look.stern then sx * -30 else sx * 12
		b:box(sx, fy + 0.3, -headS / 2 - 0.02, 0.36, 0.07, 0.04, Kit.shade(hair, 0.7), M.SmoothPlastic, { decor = true, name = "Brow", rot = CFrame.Angles(0, 0, math.rad(tilt)) })
	end
	b:box(0, hy + 0.32, -headS / 2 - 0.02, if look.stern then 0.36 else 0.28, 0.06, 0.04, hex(0x8a4a44), M.SmoothPlastic, { decor = true, name = "Mouth" })
	if look.fem then
		for _, sx in { -0.5, 0.5 } do
			b:box(sx, hy + 0.48, -headS / 2 - 0.01, 0.22, 0.1, 0.03, hex(0xff9aa8), M.SmoothPlastic, { decor = true, trans = 0.35 })
		end
	end
	if look.glasses then
		for _, sx in { -0.32, 0.32 } do
			b:box(sx, fy - 0.24, -headS / 2 - 0.08, 0.46, 0.5, 0.03, hex(0xcfe9ff), M.Glass, { decor = true, trans = 0.6 })
		end
		b:box(0, fy - 0.02, -headS / 2 - 0.08, 0.2, 0.05, 0.03, hex(0x2b2f45), M.Metal, { decor = true })
	end

	-- hair
	local top = hy + headS
	local function tuft(x: number, y: number, z: number, sx: number, sy: number, sz: number, rot: CFrame?, c: Color3?)
		b:box(x, y, z, sx, sy, sz, c or hair, M.SmoothPlastic, { decor = true, name = "Hair", rot = rot })
	end
	tuft(0, top - 0.25, 0.05, headS + 0.2, 0.55, headS + 0.25)
	tuft(0, hy + 0.5, 0.45, headS + 0.22, headS - 0.3, 0.6)
	tuft(0, top - 0.55, -headS / 2 - 0.08, headS + 0.12, 0.42, 0.25, nil, Kit.mix(hair, tip, 0.25))
	local style = look.hairStyle
	if style == "spiky" then
		for i = -2, 2 do
			tuft(i * 0.32, top + 0.05, 0.1, 0.36, 0.75, 0.36, CFrame.Angles(math.rad(-20), 0, math.rad(i * 14)), if i % 2 == 0 then tip else hair)
		end
		tuft(0, top - 0.1, 0.55, 0.5, 0.6, 0.4, CFrame.Angles(math.rad(-40), 0, 0), tip)
	elseif style == "bob" then
		for _, sx in { -1, 1 } do
			tuft(sx * (headS / 2 + 0.1), hy - 0.2, -0.05, 0.3, headS * 0.95, headS + 0.1, nil, Kit.mix(hair, tip, 0.35))
		end
	elseif style == "ponytail" then
		tuft(0, hy - 0.4, 0.95, 0.5, 1.6, 0.5, CFrame.Angles(math.rad(14), 0, 0), Kit.mix(hair, tip, 0.5))
		tuft(0, top - 0.35, 0.82, 0.38, 0.3, 0.3, nil, look.accent)
	elseif style == "long" then
		tuft(0, hy - 1.8, 0.55, headS + 0.25, 2.3, 0.4, nil, Kit.mix(hair, tip, 0.35))
		for _, sx in { -1, 1 } do
			tuft(sx * (headS / 2 + 0.1), hy - 0.8, -0.1, 0.28, headS + 0.6, 0.8, nil, Kit.mix(hair, tip, 0.2))
		end
	elseif style == "bun" then
		b:ball(0, top + 0.15, 0.5, 0.48, hair, M.SmoothPlastic, { decor = true, name = "Hair" })
		tuft(0, top + 0.1, 0.5, 0.9, 0.1, 0.1, nil, look.accent)
	elseif style == "twin" then
		for _, sx in { -1, 1 } do
			tuft(sx * (headS / 2 + 0.35), hy - 0.5, 0.25, 0.42, 1.7, 0.42, CFrame.Angles(0, 0, math.rad(sx * -12)), Kit.mix(hair, tip, 0.45))
			b:ball(sx * (headS / 2 + 0.2), top - 0.2, 0.25, 0.25, look.accent, M.Neon, { decor = true })
		end
	else -- slick
		tuft(0, top - 0.05, 0.25, headS + 0.15, 0.3, headS * 0.8, CFrame.Angles(math.rad(-6), 0, 0), Kit.mix(hair, tip, 0.2))
	end

	-- sigil badge on the chest in the academy colour
	b:box(0.55 * w, hipY + torsoH * 0.72, -0.56, 0.4, 0.4, 0.04, look.accent, M.Neon, { decor = true, name = "Badge", rot = CFrame.Angles(0, 0, math.rad(45)) })

	local hum = Instance.new("Humanoid")
	hum.DisplayName = npc.name or ""
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 46
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model

	local _ = torso
	local _h = head
	return model
end

--- The lines an NPC says when you talk to them.
function Npcs.linesFor(npc): { string }
	if npc.lines then
		return npc.lines
	elseif npc.idle then
		return { npc.idle, npc.taunt }
	elseif npc.taunt then
		return { npc.taunt }
	end
	return CROWD_LINES[npc.academy] or { "Hello there." }
end

function Npcs.build(world: Instance)
	local anchors = world:FindFirstChild("Anchors")
	local folder = world:FindFirstChild("Npcs") or Kit.new("Folder", { Name = "Npcs" }, world)
	for id, npc in Roster.ById do
		local post = anchors and anchors:FindFirstChild("Npc_" .. id)
		if post and not folder:FindFirstChild(id) then
			local model = Npcs.rig(npc, post.CFrame)
			model.Name = id
			model:SetAttribute("NpcId", id)
			model:SetAttribute("Accent", npc.look.accent)
			local prompt = Kit.new("ProximityPrompt", {
				Name = "TalkPrompt",
				ActionText = "Talk",
				ObjectText = npc.name or "Student",
				HoldDuration = 0,
				MaxActivationDistance = 14,
				RequiresLineOfSight = false,
				KeyboardKeyCode = Enum.KeyCode.E,
				GamepadKeyCode = Enum.KeyCode.DPadDown,
			}, model.PrimaryPart)
			prompt:SetAttribute("Open", "talk:" .. id)
			model.Parent = folder
		end
	end
	return folder
end

return Npcs
