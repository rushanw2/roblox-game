--!strict
-- Renders smooth raycast-clipped circular-sector Vision Cones on the airport floor for nearby NPCs.
-- Dynamically scales cone dimensions to reflect Stealth Coat & Crouch bonuses accurately.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ClientFolder = script.Parent
local ClientState = require(ClientFolder:WaitForChild("ClientState"))

type ConeSlicePair = {
	left: WedgePart,
	right: WedgePart,
}

type ConePoolSlot = {
	slices: { ConeSlicePair },
	inUse: boolean,
}

local SLICE_COUNT = 8
local POOL_SIZE = 16
local MAX_RENDER_DIST = 115
local CONE_THICKNESS = 0.06
local FLOOR_Y = 0.46

local VisionConeRenderer = {}

local coneFolder: Folder
local conePool: { ConePoolSlot } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true

local function createWedge(parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = "ConeSlice"
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	w.CastShadow = false
	w.Material = Enum.Material.Neon
	w.Transparency = 0.76
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Size = Vector3.new(CONE_THICKNESS, 1, 1)
	w.CFrame = CFrame.new(0, -500, 0)
	w.Parent = parent
	return w
end

local function initPool()
	local existing = Workspace:FindFirstChild("LocalVisionCones")
	if existing then
		existing:Destroy()
	end

	coneFolder = Instance.new("Folder")
	coneFolder.Name = "LocalVisionCones"
	coneFolder.Parent = Workspace

	for i = 1, POOL_SIZE do
		local slices: { ConeSlicePair } = {}
		for _ = 1, SLICE_COUNT do
			table.insert(slices, {
				left = createWedge(coneFolder),
				right = createWedge(coneFolder),
			})
		end
		conePool[i] = {
			slices = slices,
			inUse = false,
		}
	end
end

local function hideSlot(slot: ConePoolSlot)
	if not slot.inUse then
		return
	end
	slot.inUse = false
	for _, pair in ipairs(slot.slices) do
		pair.left.CFrame = CFrame.new(0, -500, 0)
		pair.right.CFrame = CFrame.new(0, -500, 0)
	end
end

local function getConeAppearance(npc: Model, kind: string, alertState: string, now: number): (Color3, number, number)
	if alertState == "Blinded" then
		return Color3.fromRGB(160, 185, 205), 0.9, 0.25
	elseif alertState == "Distracted" then
		return Color3.fromRGB(255, 178, 62), 0.86, 0.55
	elseif alertState == "Alerted" then
		local pulse = 0.64 + math.sin(now * 14) * 0.1
		return Color3.fromRGB(255, 56, 72), pulse, 1.05
	elseif alertState == "Suspicious" then
		return Color3.fromRGB(255, 218, 48), 0.68, 1.0
	elseif kind == "Security" then
		return Color3.fromRGB(255, 138, 62), 0.76, 1.0
	else
		return Color3.fromRGB(96, 206, 255), 0.80, 1.0
	end
end

local function renderCone(
	slot: ConePoolSlot,
	originPos: Vector3,
	baseYaw: number,
	effRange: number,
	effAngleDeg: number,
	color: Color3,
	transparency: number
)
	slot.inUse = true
	local totalRad = math.rad(math.clamp(effAngleDeg, 10, 170))
	local sliceRad = totalRad / SLICE_COUNT
	local halfSlice = sliceRad * 0.5

	local sinHalf = math.sin(halfSlice)
	local cosHalf = math.cos(halfSlice)

	-- Precompute wedge orientations matching our local triangle derivation
	local rightBaseRot = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.pi * 0.5)
	local leftBaseRot = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, -math.pi * 0.5)

	local eyeOrigin = Vector3.new(originPos.X, 4.2, originPos.Z)

	for i = 1, SLICE_COUNT do
		local pair = slot.slices[i]
		local sliceCenterAngle = baseYaw - totalRad * 0.5 + (i - 0.5) * sliceRad

		-- Raycast along slice centerline against opaque cover so cones stop visually at pillars & walls!
		local dirX = -math.sin(sliceCenterAngle)
		local dirZ = -math.cos(sliceCenterAngle)
		local rayDir = Vector3.new(dirX * effRange, 0, dirZ * effRange)
		local hit = Workspace:Raycast(eyeOrigin, rayDir, rayParams)
		local clippedRange = if hit then math.max(1.2, hit.Distance) else effRange

		local sz = clippedRange * cosHalf
		local sy = clippedRange * sinHalf
		local sliceOrigin = CFrame.new(originPos.X, FLOOR_Y, originPos.Z) * CFrame.Angles(0, sliceCenterAngle, 0)

		pair.right.Size = Vector3.new(CONE_THICKNESS, sy, sz)
		pair.right.Color = color
		pair.right.Transparency = transparency
		pair.right.CFrame = sliceOrigin * CFrame.new(sy * 0.5, 0, -sz * 0.5) * rightBaseRot

		pair.left.Size = Vector3.new(CONE_THICKNESS, sy, sz)
		pair.left.Color = color
		pair.left.Transparency = transparency
		pair.left.CFrame = sliceOrigin * CFrame.new(-sy * 0.5, 0, -sz * 0.5) * leftBaseRot
	end
end

local function collectNearbyNpcs(playerPos: Vector3, container: Instance?, outList: { { model: Model, distSq: number } })
	if not container then
		return
	end
	local maxSq = MAX_RENDER_DIST * MAX_RENDER_DIST
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsStealthNPC") == true and child.PrimaryPart then
			local p = child.PrimaryPart.Position
			local dx = p.X - playerPos.X
			local dz = p.Z - playerPos.Z
			local dSq = dx * dx + dz * dz
			if dSq <= maxSq then
				table.insert(outList, { model = child, distSq = dSq })
			end
		end
	end
end

function VisionConeRenderer.Start()
	initPool()

	local airportWorld = Workspace:WaitForChild("AirportWorld", 15)
	if airportWorld then
		local cover = airportWorld:FindFirstChild("OpaqueCover")
		if cover then
			rayParams.FilterDescendantsInstances = { cover }
		end
	end

	RunService.RenderStepped:Connect(function()
		local player = Players.LocalPlayer
		local char = player.Character
		local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if not hrp then
			for i = 1, POOL_SIZE do
				hideSlot(conePool[i])
			end
			return
		end

		local airport = Workspace:FindFirstChild("AirportWorld")
		if not airport then
			return
		end
		if #rayParams.FilterDescendantsInstances == 0 then
			local cover = airport:FindFirstChild("OpaqueCover")
			if cover then
				rayParams.FilterDescendantsInstances = { cover }
			end
		end

		local passengersFolder = airport:FindFirstChild("Passengers")
		local guardsFolder = airport:FindFirstChild("SecurityGuards")

		local candidates: { { model: Model, distSq: number } } = {}
		collectNearbyNpcs(hrp.Position, passengersFolder, candidates)
		collectNearbyNpcs(hrp.Position, guardsFolder, candidates)

		table.sort(candidates, function(a, b)
			return a.distSq < b.distSq
		end)

		local snap = ClientState.GetSnapshot()
		local coatLevel = if snap then snap.UpgradeLevels.StealthCoat else 1
		local coat = GameConfig.GetStealthCoatUpgrade(coatLevel)
		local crouchRangeMult = if ClientState.IsCrouching() then GameConfig.CROUCH_DETECTION_RANGE_MULT else 1.0
		local now = os.clock()

		local used = math.min(#candidates, POOL_SIZE)
		for i = 1, used do
			local npc = candidates[i].model
			local root = npc.PrimaryPart :: BasePart
			local baseRange = (npc:GetAttribute("VisionRange") :: number?) or 28
			local baseAngle = (npc:GetAttribute("VisionAngle") :: number?) or 75
			local kind = (npc:GetAttribute("NPCKind") :: string?) or "Passenger"
			local alertState = (npc:GetAttribute("AlertState") :: string?) or "Calm"
			local termId = ((npc:GetAttribute("TerminalId") :: string?) or "Domestic") :: GameConfig.TerminalId
			local termDef = GameConfig.TERMINALS[termId] or GameConfig.TERMINALS.Domestic

			local guardDetMult = if kind == "Security" then termDef.detectionMultiplier else 1.0
			local color, transparency, rangeScale = getConeAppearance(npc, kind, alertState, now)
			local effRange = baseRange * guardDetMult * coat.rangeMultiplier * crouchRangeMult * rangeScale
			local effAngle = baseAngle * coat.angleMultiplier

			local _, yaw, _ = root.CFrame:ToOrientation()
			renderCone(conePool[i], root.Position, yaw, effRange, effAngle, color, transparency)
		end

		for i = used + 1, POOL_SIZE do
			hideSlot(conePool[i])
		end
	end)
end

return VisionConeRenderer
