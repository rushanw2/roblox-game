--!strict
-- Smoothly transitions Lighting, Atmosphere, Fog, ColorCorrection & underwater ambient bubbles by depth zone

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local AtmosphereController = {}

local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect
local bubbleEmitter: ParticleEmitter? = nil

local function ensureEffects(): ()
	local existingAtmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmo then
		atmosphere = existingAtmo
	else
		local created = Instance.new("Atmosphere")
		created.Name = "OceanAtmosphere"
		created.Offset = 0.1
		created.Glare = 0.15
		created.Haze = 1.6
		created.Parent = Lighting
		atmosphere = created
	end

	local existingCC = Lighting:FindFirstChild("OceanDepthColorCorrection")
	if existingCC and existingCC:IsA("ColorCorrectionEffect") then
		colorCorrection = existingCC
	else
		local createdCC = Instance.new("ColorCorrectionEffect")
		createdCC.Name = "OceanDepthColorCorrection"
		createdCC.Parent = Lighting
		colorCorrection = createdCC
	end

	Lighting.ClockTime = 13.5
	Lighting.GlobalShadows = true
end

local function attachBubbleEmitter(character: Model): ()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") then
		return
	end

	local existing = root:FindFirstChild("DiveBubbleAttachment")
	if existing then
		existing:Destroy()
	end

	local att = Instance.new("Attachment")
	att.Name = "DiveBubbleAttachment"
	att.Position = Vector3.new(0, 1.5, -0.5)
	att.Parent = root

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AmbientBubbles"
	emitter.Enabled = false
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(1.4, 2.6)
	emitter.Speed = NumberRange.new(2.0, 4.5)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.7, 0.28),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(205, 246, 255))
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = att

	bubbleEmitter = emitter
end

local function lerpNumber(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function applyTargetAtmosphere(dt: number, cameraY: number): ()
	local alpha = math.clamp(1 - math.exp(-5.0 * dt), 0.02, 1)
	local isUnderwater = cameraY < GameConfig.WATER_SURFACE_Y

	local target = GameConfig.SURFACE_ATMOSPHERE
	local tintColor = Color3.fromRGB(255, 255, 255)
	local saturation = 0.08
	local contrast = 0.06
	local haze = 0.4

	if isUnderwater then
		local zone = GameConfig.GetZoneAtY(cameraY)
		if zone then
			target = {
				fogColor = zone.fogColor,
				fogStart = zone.fogStart,
				fogEnd = zone.fogEnd,
				ambient = zone.ambient,
				outdoorAmbient = zone.outdoorAmbient,
				colorShiftTop = zone.colorShiftTop,
				brightness = zone.brightness,
				atmosphereColor = zone.atmosphereColor,
				atmosphereDecay = zone.atmosphereDecay,
				atmosphereDensity = zone.atmosphereDensity,
			}
			if zone.id == "ShallowReef" then
				tintColor = Color3.fromRGB(206, 246, 255)
				saturation = 0.14
				contrast = 0.08
				haze = 1.9
			elseif zone.id == "SunkenRuins" then
				tintColor = Color3.fromRGB(164, 214, 255)
				saturation = 0.04
				contrast = 0.14
				haze = 2.8
			else
				tintColor = Color3.fromRGB(142, 146, 232)
				saturation = -0.06
				contrast = 0.22
				haze = 4.2
			end
		end
	end

	Lighting.FogColor = Lighting.FogColor:Lerp(target.fogColor, alpha)
	Lighting.FogStart = lerpNumber(Lighting.FogStart, target.fogStart, alpha)
	Lighting.FogEnd = lerpNumber(Lighting.FogEnd, target.fogEnd, alpha)
	Lighting.Ambient = Lighting.Ambient:Lerp(target.ambient, alpha)
	Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(target.outdoorAmbient, alpha)
	Lighting.ColorShift_Top = Lighting.ColorShift_Top:Lerp(target.colorShiftTop, alpha)
	Lighting.Brightness = lerpNumber(Lighting.Brightness, target.brightness, alpha)

	atmosphere.Color = atmosphere.Color:Lerp(target.atmosphereColor, alpha)
	atmosphere.Decay = atmosphere.Decay:Lerp(target.atmosphereDecay, alpha)
	atmosphere.Density = lerpNumber(atmosphere.Density, target.atmosphereDensity, alpha)
	atmosphere.Haze = lerpNumber(atmosphere.Haze, haze, alpha)

	colorCorrection.TintColor = colorCorrection.TintColor:Lerp(tintColor, alpha)
	colorCorrection.Saturation = lerpNumber(colorCorrection.Saturation, saturation, alpha)
	colorCorrection.Contrast = lerpNumber(colorCorrection.Contrast, contrast, alpha)

	if bubbleEmitter and bubbleEmitter.Parent then
		bubbleEmitter.Enabled = isUnderwater
	end
end

function AtmosphereController.Init(): ()
	ensureEffects()

	local localPlayer = Players.LocalPlayer
	localPlayer.CharacterAdded:Connect(function(character: Model)
		task.spawn(function()
			attachBubbleEmitter(character)
		end)
	end)
	if localPlayer.Character then
		task.spawn(function()
			attachBubbleEmitter(localPlayer.Character :: Model)
		end)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		local camY = if camera then camera.CFrame.Position.Y else 10
		applyTargetAtmosphere(dt, camY)
	end)
end

return AtmosphereController
