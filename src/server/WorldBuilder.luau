--!strict
-- Procedurally constructs the finished, enclosed Airport Hub, parallel dual Escalators, Mezzanines,
-- Fast-Food & Cafe stands, exterior Runways/Planes/City Skyline, enclosed Service Corridor, and Smuggler's Hideout.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LuggageVisuals = require(Shared:WaitForChild("LuggageVisuals"))

export type TerminalId = GameConfig.TerminalId

export type CarouselTrack = {
	id: string,
	terminalId: TerminalId,
	center: Vector3,
	halfW: number,
	halfD: number,
	surfaceY: number,
	speed: number,
	slats: { { part: BasePart, dist: number } },
	perimeter: number,
	ownerStandSpots: { { pos: Vector3, baseYaw: number } },
}

export type RestingSpot = {
	id: string,
	terminalId: TerminalId,
	bagPos: Vector3,
	bagYaw: number,
	ownerHomePos: Vector3,
	ownerLookAwayYaw: number,
	ownerWatchBagYaw: number,
	patrolWaypoint: Vector3?,
}

export type GuardRoute = {
	id: string,
	terminalId: TerminalId?,
	waypoints: { Vector3 },
	speed: number,
	visionRange: number,
	visionAngleDeg: number,
}

export type WorkbenchStation = {
	slotIndex: number,
	model: Model,
	surfaceCFrame: CFrame,
	statusStrip: BasePart,
	prompt: ProximityPrompt,
	billboardTitle: TextLabel,
	billboardSub: TextLabel,
	progressFill: Frame,
}

export type WorldRefs = {
	RootFolder: Folder,
	OpaqueCoverFolder: Folder,
	WindowsFolder: Folder,
	BagsFolder: Folder,
	PassengersFolder: Folder,
	GuardsFolder: Folder,
	EffectsFolder: Folder,
	Carousels: { CarouselTrack },
	RestingSpots: { RestingSpot },
	GuardRoutes: { GuardRoute },
	Workbenches: { WorkbenchStation },
	GateBarriers: { [TerminalId]: BasePart },
	GatePrompts: { [TerminalId]: ProximityPrompt },
	FencePrompt: ProximityPrompt,
	ShopPrompt: ProximityPrompt,
	TerminalKioskPrompt: ProximityPrompt,
}

local AIRPORT_ROOF_Y = 24.5
local HIDEOUT_CEILING_Y = 18.0

local WorldBuilder = {}

-- Helpers declared strictly top-down before callers

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?,
	transparency: number?,
	castShadow: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = if canCollide ~= nil then canCollide else true
	p.Transparency = transparency or 0
	if castShadow ~= nil then
		p.CastShadow = castShadow
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?,
	transparency: number?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material
	w.Anchored = true
	w.CanCollide = if canCollide ~= nil then canCollide else true
	w.Transparency = transparency or 0
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function makeSignBoard(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	bgColor: Color3,
	text: string,
	textColor: Color3,
	subText: string?,
	face: Enum.NormalId?,
	bothSides: boolean?
): Part
	local panel = makePart(parent, name, size, cframe, bgColor, Enum.Material.SmoothPlastic, true, 0)

	local faces: { Enum.NormalId } = { face or Enum.NormalId.Front }
	if bothSides ~= false then
		local primaryFace = face or Enum.NormalId.Front
		if primaryFace == Enum.NormalId.Front then
			table.insert(faces, Enum.NormalId.Back)
		elseif primaryFace == Enum.NormalId.Back then
			table.insert(faces, Enum.NormalId.Front)
		end
	end

	for _, targetFace in ipairs(faces) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = targetFace
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 35
		gui.Parent = panel

		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundColor3 = bgColor
		holder.BorderSizePixel = 0
		holder.Parent = gui

		local title = Instance.new("TextLabel")
		title.Size = if subText then UDim2.fromScale(0.94, 0.56) else UDim2.fromScale(0.94, 0.86)
		title.Position = UDim2.fromScale(0.03, 0.06)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.Text = text
		title.TextColor3 = textColor
		title.TextScaled = true
		title.Parent = holder

		if subText then
			local sub = Instance.new("TextLabel")
			sub.Size = UDim2.fromScale(0.94, 0.34)
			sub.Position = UDim2.fromScale(0.03, 0.62)
			sub.BackgroundTransparency = 1
			sub.Font = Enum.Font.GothamMedium
			sub.Text = subText
			sub.TextColor3 = Color3.fromRGB(220, 228, 240)
			sub.TextScaled = true
			sub.Parent = holder
		end
	end

	return panel
end

local function buildCurtainWallBay(
	opaqueParent: Instance,
	windowsParent: Instance,
	name: string,
	startPos: Vector3,
	endPos: Vector3,
	bottomY: number,
	topY: number,
	bulkheadHeight: number,
	frameColor: Color3,
	glassColor: Color3
)
	local delta = endPos - startPos
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local midXZ = (startPos + endPos) * 0.5
	local yaw = math.atan2(-delta.X, -delta.Z) + math.pi * 0.5
	local origin = CFrame.new(midXZ.X, 0, midXZ.Z) * CFrame.Angles(0, yaw, 0)

	local totalH = topY - bottomY
	if bulkheadHeight > 0 then
		makePart(
			opaqueParent,
			name .. "_Bulkhead",
			Vector3.new(length, bulkheadHeight, 1.4),
			origin * CFrame.new(0, bottomY + bulkheadHeight * 0.5, 0),
			frameColor,
			Enum.Material.Marble,
			true
		)
	end

	local glassBottom = bottomY + bulkheadHeight
	local spandrelH = 1.4
	local glassH = math.max(1, totalH - bulkheadHeight - spandrelH)

	-- Full-height collision curtain glass preventing players from exiting the airport
	makePart(
		windowsParent,
		name .. "_Glass",
		Vector3.new(length, glassH, 0.55),
		origin * CFrame.new(0, glassBottom + glassH * 0.5, 0),
		glassColor,
		Enum.Material.Glass,
		true,
		0.58,
		false
	)

	makePart(
		opaqueParent,
		name .. "_Spandrel",
		Vector3.new(length, spandrelH, 1.6),
		origin * CFrame.new(0, topY - spandrelH * 0.5, 0),
		Color3.fromRGB(46, 52, 64),
		Enum.Material.Metal,
		true
	)

	local mullionSpacing = 18
	local count = math.max(1, math.floor(length / mullionSpacing))
	for i = 0, count do
		local xOff = -length * 0.5 + (i / count) * length
		makePart(
			opaqueParent,
			name .. "_Mullion_" .. i,
			Vector3.new(0.7, totalH, 1.2),
			origin * CFrame.new(xOff, bottomY + totalH * 0.5, 0),
			Color3.fromRGB(162, 172, 184),
			Enum.Material.Metal,
			true
		)
	end
end

local function buildRoofSection(
	decorParent: Instance,
	opaqueParent: Instance,
	windowsParent: Instance,
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	roofY: number,
	cofferColor: Color3,
	trussColor: Color3,
	accentColor: Color3,
	skylightPattern: boolean
)
	local width = maxX - minX
	local depth = maxZ - minZ
	local centerX = (minX + maxX) * 0.5
	local centerZ = (minZ + maxZ) * 0.5

	local cols = math.max(2, math.round(width / 34))
	local rows = math.max(2, math.round(depth / 34))
	local cellW = width / cols
	local cellD = depth / rows

	makePart(opaqueParent, name .. "_BeamN", Vector3.new(width + 2, 1.8, 2.2), CFrame.new(centerX, roofY, minZ), trussColor, Enum.Material.Metal, true)
	makePart(opaqueParent, name .. "_BeamS", Vector3.new(width + 2, 1.8, 2.2), CFrame.new(centerX, roofY, maxZ), trussColor, Enum.Material.Metal, true)
	makePart(opaqueParent, name .. "_BeamW", Vector3.new(2.2, 1.8, depth + 2), CFrame.new(minX, roofY, centerZ), trussColor, Enum.Material.Metal, true)
	makePart(opaqueParent, name .. "_BeamE", Vector3.new(2.2, 1.8, depth + 2), CFrame.new(maxX, roofY, centerZ), trussColor, Enum.Material.Metal, true)

	for r = 0, rows do
		local zPos = minZ + r * cellD
		makePart(decorParent, name .. "_TrussEW_" .. r, Vector3.new(width, 1.3, 1.4), CFrame.new(centerX, roofY - 0.1, zPos), trussColor, Enum.Material.Metal, true)
		if r > 0 and r < rows then
			makePart(decorParent, name .. "_LedHousing_" .. r, Vector3.new(width * 0.86, 0.35, 0.9), CFrame.new(centerX, roofY - 0.85, zPos), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, false)
			makePart(decorParent, name .. "_LedStrip_" .. r, Vector3.new(width * 0.84, 0.16, 0.5), CFrame.new(centerX, roofY - 1.04, zPos), accentColor, Enum.Material.Neon, false)
		end
	end

	for c = 0, cols do
		local xPos = minX + c * cellW
		makePart(decorParent, name .. "_TrussNS_" .. c, Vector3.new(1.4, 1.3, depth), CFrame.new(xPos, roofY - 0.1, centerZ), trussColor, Enum.Material.Metal, true)
	end

	for r = 1, rows do
		for c = 1, cols do
			local bx = minX + (c - 0.5) * cellW
			local bz = minZ + (r - 0.5) * cellD
			local isSkylight = skylightPattern and ((r + c) % 2 == 0)
			if isSkylight then
				makePart(
					windowsParent,
					string.format("%s_Skylight_%d_%d", name, r, c),
					Vector3.new(cellW - 1.2, 0.45, cellD - 1.2),
					CFrame.new(bx, roofY + 0.7, bz),
					Color3.fromRGB(204, 232, 250),
					Enum.Material.Glass,
					true,
					0.38,
					false
				)
				makePart(
					decorParent,
					string.format("%s_SkylightFrame_%d_%d", name, r, c),
					Vector3.new(cellW - 0.6, 0.7, 0.6),
					CFrame.new(bx, roofY + 0.5, bz - cellD * 0.5 + 0.6),
					Color3.fromRGB(168, 176, 188),
					Enum.Material.Metal,
					false
				)
			else
				makePart(
					opaqueParent,
					string.format("%s_Coffer_%d_%d", name, r, c),
					Vector3.new(cellW - 0.8, 0.6, cellD - 0.8),
					CFrame.new(bx, roofY + 0.7, bz),
					cofferColor,
					Enum.Material.SmoothPlastic,
					true
				)
				makePart(
					decorParent,
					string.format("%s_PodBezel_%d_%d", name, r, c),
					Vector3.new(cellW * 0.42, 0.3, cellD * 0.42),
					CFrame.new(bx, roofY + 0.35, bz),
					trussColor,
					Enum.Material.Metal,
					false
				)
				makePart(
					decorParent,
					string.format("%s_PodGlow_%d_%d", name, r, c),
					Vector3.new(cellW * 0.36, 0.14, cellD * 0.36),
					CFrame.new(bx, roofY + 0.16, bz),
					Color3.fromRGB(255, 242, 214),
					Enum.Material.Neon,
					false
				)
			end
		end
	end
end

local function buildPillar(parent: Instance, decorParent: Instance, name: string, pos: Vector3, radius: number, height: number, color: Color3, accent: Color3)
	makePart(parent, name .. "_Plinth", Vector3.new(radius * 2 + 0.9, 1.3, radius * 2 + 0.9), CFrame.new(pos.X, 0.65, pos.Z), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(parent, name, Vector3.new(radius * 2, height, radius * 2), CFrame.new(pos.X, height * 0.5, pos.Z), color, Enum.Material.Marble, true)
	makePart(decorParent, name .. "_BrassBandLow", Vector3.new(radius * 2 + 0.2, 0.35, radius * 2 + 0.2), CFrame.new(pos.X, 4.2, pos.Z), accent, Enum.Material.Metal, false)
	makePart(decorParent, name .. "_GlowCollar", Vector3.new(radius * 2 + 0.18, 0.32, radius * 2 + 0.18), CFrame.new(pos.X, height - 2.2, pos.Z), accent, Enum.Material.Neon, false)
	makePart(parent, name .. "_Capital", Vector3.new(radius * 2 + 1.0, 1.1, radius * 2 + 1.0), CFrame.new(pos.X, height - 0.55, pos.Z), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
end

local function buildPlanterBed(coverParent: Instance, decorParent: Instance, pos: Vector3, accentColor: Color3, width: number?, depth: number?)
	local w = width or 4.6
	local d = depth or 4.6
	local floorY = if pos.Y > 0.5 then pos.Y else 0.4
	makePart(coverParent, "PlanterBox", Vector3.new(w, 2.2, d), CFrame.new(pos.X, floorY + 0.7, pos.Z), Color3.fromRGB(232, 234, 238), Enum.Material.Marble, true)
	makePart(decorParent, "PlanterRim", Vector3.new(w + 0.25, 0.28, d + 0.25), CFrame.new(pos.X, floorY + 1.84, pos.Z), Color3.fromRGB(186, 152, 74), Enum.Material.Metal, false)
	makePart(decorParent, "PlanterLightStrip", Vector3.new(w + 0.1, 0.14, d + 0.1), CFrame.new(pos.X, floorY + 1.62, pos.Z), accentColor, Enum.Material.Neon, false)
	makePart(decorParent, "PlanterSoil", Vector3.new(w - 0.5, 0.25, d - 0.5), CFrame.new(pos.X, floorY + 1.86, pos.Z), Color3.fromRGB(68, 48, 34), Enum.Material.Grass, false)
	makePart(decorParent, "PalmTrunk", Vector3.new(0.75, 4.8, 0.75), CFrame.new(pos.X, floorY + 4.3, pos.Z), Color3.fromRGB(116, 82, 52), Enum.Material.Wood, false)
	for i = 1, 6 do
		local yaw = math.rad((i - 1) * 60)
		local cf = CFrame.new(pos.X, floorY + 6.65, pos.Z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -1.8) * CFrame.Angles(math.rad(-20), 0, 0)
		makePart(decorParent, "Frond_" .. i, Vector3.new(1.15, 0.16, 3.6), cf, Color3.fromRGB(58, 148, 72), Enum.Material.Grass, false)
	end
end

local function buildLeatherSeatingCluster(parent: Instance, pos: Vector3, yawDeg: number, cushionColor: Color3, trimColor: Color3)
	local floorY = if pos.Y > 0.5 then pos.Y else 0.4
	local origin = CFrame.new(pos.X, floorY, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(parent, "BenchFrame", Vector3.new(10.4, 0.35, 2.8), origin * CFrame.new(0, 1.0, 0), Color3.fromRGB(148, 156, 168), Enum.Material.Metal, true)
	makePart(parent, "BenchSeat", Vector3.new(10.0, 0.52, 2.6), origin * CFrame.new(0, 1.42, 0), cushionColor, Enum.Material.Leather, true)
	makePart(parent, "BenchBack", Vector3.new(10.0, 1.75, 0.48), origin * CFrame.new(0, 2.38, 1.06), cushionColor, Enum.Material.Leather, true)
	for _, xArm in ipairs({ -4.8, 0, 4.8 }) do
		makePart(parent, "ArmRest", Vector3.new(0.32, 0.72, 2.5), origin * CFrame.new(xArm, 1.88, 0), trimColor, Enum.Material.Metal, true)
	end
	for _, xLeg in ipairs({ -4.2, 4.2 }) do
		makePart(parent, "BenchLeg", Vector3.new(0.45, 0.95, 2.2), origin * CFrame.new(xLeg, 0.48, 0), Color3.fromRGB(84, 90, 102), Enum.Material.Metal, true)
	end
end

local function buildVelvetRopeLine(parent: Instance, startPos: Vector3, endPos: Vector3, ropeColor: Color3)
	local delta = endPos - startPos
	local dist = delta.Magnitude
	local steps = math.max(1, math.round(dist / 8))
	for i = 0, steps do
		local t = i / steps
		local p = startPos:Lerp(endPos, t)
		makePart(parent, "StanchionBase_" .. i, Vector3.new(1.1, 0.22, 1.1), CFrame.new(p.X, 0.51, p.Z), Color3.fromRGB(224, 178, 62), Enum.Material.Metal, true)
		makePart(parent, "StanchionPost_" .. i, Vector3.new(0.28, 3.1, 0.28), CFrame.new(p.X, 2.05, p.Z), Color3.fromRGB(224, 178, 62), Enum.Material.Metal, true)
		makePart(parent, "StanchionCap_" .. i, Vector3.new(0.45, 0.35, 0.45), CFrame.new(p.X, 3.65, p.Z), Color3.fromRGB(245, 206, 86), Enum.Material.Metal, false)
		if i < steps then
			local pNext = startPos:Lerp(endPos, (i + 1) / steps)
			local seg = pNext - p
			local mid = (p + pNext) * 0.5
			local yaw = math.atan2(-seg.X, -seg.Z) + math.pi * 0.5
			makePart(
				parent,
				"VelvetRope_" .. i,
				Vector3.new(seg.Magnitude, 0.22, 0.22),
				CFrame.new(mid.X, 2.95, mid.Z) * CFrame.Angles(0, yaw, 0),
				ropeColor,
				Enum.Material.Fabric,
				false
			)
		end
	end
end

-- Decorative Fast-Food / Coffee Stand + Cafe Bistro Tables
local function buildFoodStand(
	coverParent: Instance,
	decorParent: Instance,
	windowsParent: Instance,
	name: string,
	pos: Vector3,
	yawDeg: number,
	brandName: string,
	brandColor: Color3,
	subtitle: string
)
	local origin = CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	-- Grounded base counter & rear wall backdrop
	makePart(coverParent, name .. "_BackWall", Vector3.new(16, 8.8, 1.2), origin * CFrame.new(0, 4.4, 2.8), Color3.fromRGB(38, 42, 54), Enum.Material.SmoothPlastic, true)
	makePart(coverParent, name .. "_FrontCounter", Vector3.new(16, 3.4, 2.2), origin * CFrame.new(0, 1.7, -2.0), Color3.fromRGB(228, 232, 238), Enum.Material.Marble, true)
	makePart(decorParent, name .. "_CounterTrim", Vector3.new(16.2, 0.28, 2.4), origin * CFrame.new(0, 3.45, -2.0), brandColor, Enum.Material.Neon, false)

	-- Sneeze guard glass display + pastries/espresso props on counter
	makePart(windowsParent, name .. "_DisplayGlass", Vector3.new(7.4, 1.8, 1.2), origin * CFrame.new(-3.2, 4.4, -2.0), Color3.fromRGB(190, 228, 248), Enum.Material.Glass, true, 0.45, false)
	makePart(decorParent, name .. "_EspressoMachine", Vector3.new(2.4, 1.8, 1.6), origin * CFrame.new(3.8, 4.4, -1.8), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	makePart(decorParent, name .. "_WarmerLamp", Vector3.new(1.2, 0.4, 0.9), origin * CFrame.new(-3.2, 4.0, -2.0), Color3.fromRGB(255, 206, 112), Enum.Material.Neon, false)

	-- Side pillars supporting fascia canopy & glowing menu board
	makePart(coverParent, name .. "_PostL", Vector3.new(1.0, 8.8, 5.6), origin * CFrame.new(-7.5, 4.4, 0.4), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(coverParent, name .. "_PostR", Vector3.new(1.0, 8.8, 5.6), origin * CFrame.new(7.5, 4.4, 0.4), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(coverParent, name .. "_Canopy", Vector3.new(16.4, 1.2, 6.2), origin * CFrame.new(0, 8.8, 0.2), Color3.fromRGB(28, 32, 42), Enum.Material.Metal, true)
	makeSignBoard(
		decorParent,
		name .. "_MenuSign",
		Vector3.new(13.6, 2.6, 0.45),
		origin * CFrame.new(0, 8.8, -2.95),
		Color3.fromRGB(18, 22, 32),
		brandName,
		brandColor,
		subtitle,
		Enum.NormalId.Front,
		false
	)

	-- Menu board mounted flush on rear wall
	makeSignBoard(
		decorParent,
		name .. "_RearMenu",
		Vector3.new(11.0, 3.2, 0.3),
		origin * CFrame.new(0, 6.0, 2.05),
		Color3.fromRGB(20, 24, 34),
		"ESPRESSO • CROISSANT • PANINI • SMOOTHIES",
		Color3.fromRGB(255, 232, 182),
		"FRESHLY BREWED • GRAB & FLY",
		Enum.NormalId.Front,
		false
	)

	-- Two grounded bistro cafe tables & stools directly in front of the stand
	for _, xTable in ipairs({ -4.6, 4.6 }) do
		local tOrigin = origin * CFrame.new(xTable, 0, -6.2)
		makePart(decorParent, name .. "_TableBase", Vector3.new(1.6, 0.2, 1.6), tOrigin * CFrame.new(0, 0.1, 0), Color3.fromRGB(54, 60, 72), Enum.Material.Metal, true)
		makePart(decorParent, name .. "_TablePedestal", Vector3.new(0.45, 2.6, 0.45), tOrigin * CFrame.new(0, 1.4, 0), Color3.fromRGB(156, 164, 176), Enum.Material.Metal, true)
		makePart(decorParent, name .. "_TableTop", Vector3.new(3.2, 0.25, 3.2), tOrigin * CFrame.new(0, 2.8, 0), Color3.fromRGB(232, 236, 242), Enum.Material.Marble, true)
		for _, sx in ipairs({ -2.2, 2.2 }) do
			makePart(decorParent, name .. "_StoolLeg", Vector3.new(0.35, 1.6, 0.35), tOrigin * CFrame.new(sx, 0.8, 0), Color3.fromRGB(64, 70, 82), Enum.Material.Metal, true)
			makePart(decorParent, name .. "_StoolSeat", Vector3.new(1.3, 0.32, 1.3), tOrigin * CFrame.new(sx, 1.72, 0), brandColor, Enum.Material.Leather, true)
		end
	end
end

local function buildLuggageCartCorral(decorParent: Instance, coverParent: Instance, name: string, pos: Vector3, yawDeg: number)
	local origin = CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(coverParent, name .. "_RailL", Vector3.new(0.28, 3.0, 7.6), origin * CFrame.new(-2.2, 1.5, 0), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, true)
	makePart(coverParent, name .. "_RailR", Vector3.new(0.28, 3.0, 7.6), origin * CFrame.new(2.2, 1.5, 0), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, true)
	makePart(coverParent, name .. "_RailBack", Vector3.new(4.6, 3.0, 0.28), origin * CFrame.new(0, 1.5, 3.8), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, true)
	-- 3 nested smart luggage carts inside the corral
	for cIdx = 1, 3 do
		local zCart = 2.0 - (cIdx - 1) * 1.9
		makePart(decorParent, name .. "_CartDeck_" .. cIdx, Vector3.new(2.8, 0.22, 2.2), origin * CFrame.new(0, 0.75, zCart), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, false)
		makePart(decorParent, name .. "_CartHandle_" .. cIdx, Vector3.new(2.6, 2.4, 0.2), origin * CFrame.new(0, 2.05, zCart - 0.9), Color3.fromRGB(192, 200, 210), Enum.Material.Metal, false)
		makePart(decorParent, name .. "_CartSign_" .. cIdx, Vector3.new(2.2, 0.7, 0.14), origin * CFrame.new(0, 2.2, zCart - 0.95), Color3.fromRGB(48, 152, 232), Enum.Material.SmoothPlastic, false)
	end
end

local function buildTrashRecyclingStation(coverParent: Instance, decorParent: Instance, name: string, pos: Vector3, yawDeg: number)
	local origin = CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(coverParent, name .. "_WasteBin", Vector3.new(1.8, 3.1, 1.8), origin * CFrame.new(-1.05, 1.55, 0), Color3.fromRGB(64, 70, 80), Enum.Material.Metal, true)
	makePart(decorParent, name .. "_WasteLid", Vector3.new(1.9, 0.25, 1.9), origin * CFrame.new(-1.05, 3.22, 0), Color3.fromRGB(36, 40, 48), Enum.Material.SmoothPlastic, false)
	makePart(coverParent, name .. "_RecycleBin", Vector3.new(1.8, 3.1, 1.8), origin * CFrame.new(1.05, 1.55, 0), Color3.fromRGB(52, 118, 178), Enum.Material.Metal, true)
	makePart(decorParent, name .. "_RecycleLid", Vector3.new(1.9, 0.25, 1.9), origin * CFrame.new(1.05, 3.22, 0), Color3.fromRGB(72, 186, 255), Enum.Material.SmoothPlastic, false)
end

local function buildInfoKiosk(coverParent: Instance, decorParent: Instance, name: string, pos: Vector3, yawDeg: number, title: string, accent: Color3)
	local origin = CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(coverParent, name .. "_Base", Vector3.new(3.6, 0.4, 2.2), origin * CFrame.new(0, 0.2, 0), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makeSignBoard(
		decorParent,
		name .. "_Screen",
		Vector3.new(3.2, 6.2, 0.9),
		origin * CFrame.new(0, 3.5, 0),
		Color3.fromRGB(16, 20, 30),
		title,
		accent,
		"BAGGAGE CLAIM • LOUNGES • GATES",
		Enum.NormalId.Front,
		true
	)
	makePart(decorParent, name .. "_TopCap", Vector3.new(3.4, 0.28, 1.1), origin * CFrame.new(0, 6.72, 0), accent, Enum.Material.Neon, false)
end

local function buildDualEscalator(
	decorParent: Instance,
	windowsParent: Instance,
	name: string,
	bottomCenter: Vector3,
	topCenter: Vector3,
	laneWidth: number,
	accentColor: Color3
): ()
	local model = Instance.new("Model")
	model.Name = "DualEscalator_" .. name
	model.Parent = decorParent

	local deltaXZ = Vector3.new(topCenter.X - bottomCenter.X, 0, topCenter.Z - bottomCenter.Z)
	local dir = deltaXZ.Unit
	-- Terminate the sloped escalator 1.2 studs ahead of the mezzanine edge so the top comb plate meets the deck flush without clipping slabs, fascia trim, or glass balustrades
	local rampTopCenter = topCenter - dir * 1.2
	local rampDeltaXZ = Vector3.new(rampTopCenter.X - bottomCenter.X, 0, rampTopCenter.Z - bottomCenter.Z)
	local run = rampDeltaXZ.Magnitude
	local rise = topCenter.Y - bottomCenter.Y
	local hyp = math.sqrt(run * run + rise * rise)
	local pitchAngle = math.atan2(rise, run)
	local cosP = math.cos(pitchAngle)
	local sinP = math.sin(pitchAngle)
	local centerXZ = (Vector3.new(bottomCenter.X, 0, bottomCenter.Z) + Vector3.new(rampTopCenter.X, 0, rampTopCenter.Z)) * 0.5
	local midY = (bottomCenter.Y + topCenter.Y) * 0.5

	-- baseCF has local +Z = +dir (uphill direction) and local +Y = world +Y
	local baseCF = CFrame.lookAt(Vector3.new(centerXZ.X, midY, centerXZ.Z), Vector3.new(centerXZ.X, midY, centerXZ.Z) - dir)
	local bottomBaseCF = CFrame.lookAt(bottomCenter, bottomCenter - dir)
	local topBaseCF = CFrame.lookAt(topCenter, topCenter - dir)

	local totalWidth = laneWidth * 2 + 1.0
	local laneOffset = laneWidth * 0.5 + 0.25

	-- Single wide under-truss + bottom & top comb landings supporting both parallel lanes without overhanging past topCenter
	makePart(
		model,
		"UnderTruss",
		Vector3.new(totalWidth + 0.8, 1.2, hyp),
		baseCF * CFrame.new(0, -0.7 * cosP, -0.7 * sinP) * CFrame.Angles(-pitchAngle, 0, 0),
		Color3.fromRGB(36, 40, 48),
		Enum.Material.Metal,
		true
	)
	makePart(model, "BottomComb", Vector3.new(totalWidth + 0.8, 0.3, 1.4), bottomBaseCF * CFrame.new(0, 0.05, -0.7), Color3.fromRGB(168, 176, 186), Enum.Material.Metal, true)
	makePart(model, "TopComb", Vector3.new(totalWidth + 0.8, 0.5, 1.4), topBaseCF * CFrame.new(0, -0.25, -0.7), Color3.fromRGB(168, 176, 186), Enum.Material.Metal, true)

	-- Build both parallel lanes (Up Lane on -X, Down Lane on +X) along the exact same incline!
	local laneOffsets = { -laneOffset, laneOffset }
	local laneColors = { Color3.fromRGB(64, 224, 148), accentColor }
	local stepCount = 24
	for laneIdx, xLane in ipairs(laneOffsets) do
		-- Smooth invisible WedgePart collision ramp aligned along +Z (+dir uphill)
		local ramp = makeWedge(
			model,
			"WalkRamp_" .. laneIdx,
			Vector3.new(laneWidth - 0.35, rise, run),
			baseCF * CFrame.new(xLane, 0, 0),
			Color3.fromRGB(100, 100, 100),
			Enum.Material.SmoothPlastic,
			true,
			1
		)
		ramp.CastShadow = false

		-- Non-colliding ribbed metal treads parallel to the ramp
		for s = 1, stepCount do
			local t = (s - 0.5) / stepCount
			local stepXZ = Vector3.new(bottomCenter.X, 0, bottomCenter.Z):Lerp(Vector3.new(rampTopCenter.X, 0, rampTopCenter.Z), t)
			local stepY = bottomCenter.Y + t * rise
			local stepCF = CFrame.lookAt(Vector3.new(stepXZ.X, stepY - 0.25, stepXZ.Z), Vector3.new(stepXZ.X, stepY - 0.25, stepXZ.Z) - dir)
				* CFrame.new(xLane, 0, 0)
			makePart(model, string.format("Tread_%d_%d", laneIdx, s), Vector3.new(laneWidth - 0.45, 0.48, (run / stepCount) + 0.16), stepCF, Color3.fromRGB(70, 76, 86), Enum.Material.DiamondPlate, false)
		end

		-- Subtle LED directional entry strips on comb plates
		makePart(model, "LaneGlowBot_" .. laneIdx, Vector3.new(laneWidth - 0.8, 0.12, 0.4), bottomBaseCF * CFrame.new(xLane, 0.22, -0.7), laneColors[laneIdx], Enum.Material.Neon, false)
		makePart(model, "LaneGlowTop_" .. laneIdx, Vector3.new(laneWidth - 0.8, 0.12, 0.4), topBaseCF * CFrame.new(xLane, 0.04, -0.7), laneColors[laneIdx], Enum.Material.Neon, false)
	end

	-- 3 parallel balustrade dividers: Left outer, Center shared divider, Right outer
	-- Using vertical height projection (H*cosP, H*sinP) keeps both ends cleanly seated inside the bottom & top newels
	local dividerXs = { -(laneWidth + 0.5), 0, (laneWidth + 0.5) }
	for dIdx, dX in ipairs(dividerXs) do
		local divCF = baseCF * CFrame.new(dX, 0, 0) * CFrame.Angles(-pitchAngle, 0, 0)
		makePart(model, "Skirt_" .. dIdx, Vector3.new(0.45, 1.2, hyp + 0.6), divCF * CFrame.new(0, 0.4 * cosP, 0.4 * sinP), Color3.fromRGB(188, 196, 208), Enum.Material.Metal, true)
		makePart(model, "SkirtGlow_" .. dIdx, Vector3.new(0.5, 0.16, hyp), divCF * CFrame.new(0, 0.88 * cosP, 0.88 * sinP), accentColor, Enum.Material.Neon, false)
		makePart(windowsParent, name .. "_Balustrade_" .. dIdx, Vector3.new(0.24, 2.6, hyp + 0.8), divCF * CFrame.new(0, 2.1 * cosP, 2.1 * sinP), Color3.fromRGB(178, 224, 248), Enum.Material.Glass, true, 0.48, false)
		makePart(model, "Handrail_" .. dIdx, Vector3.new(0.48, 0.28, hyp + 0.6), divCF * CFrame.new(0, 3.65 * cosP, 3.65 * sinP), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic, true)
		makePart(model, "NewelBot_" .. dIdx, Vector3.new(0.5, 3.6, 1.4), bottomBaseCF * CFrame.new(dX, 1.8, -0.45), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, true)
		makePart(model, "HandrailCapBot_" .. dIdx, Vector3.new(0.52, 0.28, 1.5), bottomBaseCF * CFrame.new(dX, 3.65, -0.45), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic, true)
		makePart(model, "NewelTop_" .. dIdx, Vector3.new(0.5, 3.6, 1.4), topBaseCF * CFrame.new(dX, 1.8, -0.75), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, true)
		makePart(model, "HandrailCapTop_" .. dIdx, Vector3.new(0.52, 0.28, 1.5), topBaseCF * CFrame.new(dX, 3.65, -0.75), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic, true)
	end
end

local function buildMezzanineDeck(
	decorParent: Instance,
	opaqueParent: Instance,
	windowsParent: Instance,
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	deckY: number,
	floorColor: Color3,
	trimColor: Color3,
	railingSides: { N: boolean?, S: boolean?, W: boolean?, E: boolean? },
	gateOpenings: { { axis: string, minV: number, maxV: number, side: string } }?
)
	local w = maxX - minX
	local d = maxZ - minZ
	local cx = (minX + maxX) * 0.5
	local cz = (minZ + maxZ) * 0.5

	makePart(opaqueParent, name .. "_Slab", Vector3.new(w, 1.0, d), CFrame.new(cx, deckY - 0.5, cz), floorColor, Enum.Material.Marble, true)
	makePart(decorParent, name .. "_Trim", Vector3.new(w + 0.3, 0.35, d + 0.3), CFrame.new(cx, deckY - 0.85, cz), trimColor, Enum.Material.Metal, false)

	local colXs = { minX + 2.5, maxX - 2.5 }
	if w > 70 then
		table.insert(colXs, minX + w * 0.32)
		table.insert(colXs, maxX - w * 0.32)
	end
	for _, xC in ipairs(colXs) do
		for _, zC in ipairs({ minZ + 2.5, maxZ - 2.5 }) do
			makePart(opaqueParent, name .. "_Support", Vector3.new(1.5, deckY - 1.0, 1.5), CFrame.new(xC, (deckY - 1.0) * 0.5 + 0.2, zC), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, true)
		end
	end

	local function addGlassRail(railName: string, p1: Vector3, p2: Vector3): ()
		local seg = p2 - p1
		local len = seg.Magnitude
		if len < 0.8 then
			return
		end
		local mid = (p1 + p2) * 0.5
		local yaw = math.atan2(-seg.X, -seg.Z) + math.pi * 0.5
		local cf = CFrame.new(mid.X, deckY, mid.Z) * CFrame.Angles(0, yaw, 0)
		makePart(windowsParent, railName .. "_Glass", Vector3.new(len, 3.6, 0.28), cf * CFrame.new(0, 1.85, 0), Color3.fromRGB(182, 224, 248), Enum.Material.Glass, true, 0.45, false)
		makePart(decorParent, railName .. "_TopRail", Vector3.new(len, 0.26, 0.46), cf * CFrame.new(0, 3.7, 0), trimColor, Enum.Material.Metal, true)
		local posts = math.max(1, math.round(len / 12))
		for i = 0, posts do
			local xOff = -len * 0.5 + (i / posts) * len
			makePart(decorParent, railName .. "_Post_" .. i, Vector3.new(0.32, 3.7, 0.32), cf * CFrame.new(xOff, 1.85, 0), Color3.fromRGB(54, 60, 72), Enum.Material.Metal, true)
		end
	end

	local openings = gateOpenings or {}
	local function addSegmentedRail(sideKey: string, fixedCoord: number, spanMin: number, spanMax: number, isHorizontal: boolean): ()
		local cuts: { { minV: number, maxV: number } } = {}
		for _, op in ipairs(openings) do
			if op.side == sideKey then
				table.insert(cuts, { minV = math.max(spanMin, op.minV), maxV = math.min(spanMax, op.maxV) })
			end
		end
		table.sort(cuts, function(a: { minV: number, maxV: number }, b: { minV: number, maxV: number }): boolean
			return a.minV < b.minV
		end)
		local cursor = spanMin
		local idx = 1
		for _, cut in ipairs(cuts) do
			if cut.minV > cursor + 0.5 then
				local p1 = if isHorizontal then Vector3.new(cursor, 0, fixedCoord) else Vector3.new(fixedCoord, 0, cursor)
				local p2 = if isHorizontal then Vector3.new(cut.minV, 0, fixedCoord) else Vector3.new(fixedCoord, 0, cut.minV)
				addGlassRail(name .. "_" .. sideKey .. idx, p1, p2)
				idx += 1
			end
			cursor = math.max(cursor, cut.maxV)
		end
		if cursor < spanMax - 0.5 then
			local p1 = if isHorizontal then Vector3.new(cursor, 0, fixedCoord) else Vector3.new(fixedCoord, 0, cursor)
			local p2 = if isHorizontal then Vector3.new(spanMax, 0, fixedCoord) else Vector3.new(fixedCoord, 0, spanMax)
			addGlassRail(name .. "_" .. sideKey .. idx, p1, p2)
		end
	end

	if railingSides.N then
		addSegmentedRail("N", minZ + 0.25, minX, maxX, true)
	end
	if railingSides.S then
		addSegmentedRail("S", maxZ - 0.25, minX, maxX, true)
	end
	if railingSides.W then
		addSegmentedRail("W", minX + 0.25, minZ, maxZ, false)
	end
	if railingSides.E then
		addSegmentedRail("E", maxX - 0.25, minZ, maxZ, false)
	end
end

function WorldBuilder.EvaluateCarouselPoint(track: CarouselTrack, dist: number): (Vector3, number)
	local straightX = math.max(1, (track.halfW - track.halfD) * 2)
	local arcRadius = track.halfD
	local halfArc = math.pi * arcRadius
	local p = dist % track.perimeter

	if p < straightX then
		local t = p - straightX * 0.5
		local pos = track.center + Vector3.new(t, track.surfaceY, -arcRadius)
		return pos, -math.pi * 0.5
	end
	p -= straightX

	if p < halfArc then
		local theta = -math.pi * 0.5 + (p / arcRadius)
		local pos = track.center + Vector3.new(straightX * 0.5 + math.cos(theta) * arcRadius, track.surfaceY, math.sin(theta) * arcRadius)
		return pos, -(theta + math.pi * 0.5)
	end
	p -= halfArc

	if p < straightX then
		local t = straightX * 0.5 - p
		local pos = track.center + Vector3.new(t, track.surfaceY, arcRadius)
		return pos, math.pi * 0.5
	end
	p -= straightX

	local theta = math.pi * 0.5 + (p / arcRadius)
	local pos = track.center + Vector3.new(-straightX * 0.5 + math.cos(theta) * arcRadius, track.surfaceY, math.sin(theta) * arcRadius)
	return pos, -(theta + math.pi * 0.5)
end

local function buildCarousel(
	parent: Instance,
	coverParent: Instance,
	id: string,
	terminalId: TerminalId,
	center: Vector3,
	halfW: number,
	halfD: number,
	speed: number,
	accentColor: Color3
): CarouselTrack
	local straightX = math.max(1, (halfW - halfD) * 2)
	local perimeter = 2 * straightX + 2 * math.pi * halfD
	local surfaceY = 1.35

	local model = Instance.new("Model")
	model.Name = "Carousel_" .. id
	model.Parent = parent

	makePart(coverParent, id .. "_CenterCore", Vector3.new(straightX + 4, 4.4, halfD * 0.9), CFrame.new(center.X, 2.2, center.Z), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(model, id .. "_CoreAccent", Vector3.new(straightX + 4.2, 0.25, halfD * 0.9 + 0.2), CFrame.new(center.X, 4.2, center.Z), accentColor, Enum.Material.Neon, false)

	local signY = 8.4
	local rodLen = AIRPORT_ROOF_Y - signY
	makePart(model, id .. "_HangerL", Vector3.new(0.32, rodLen, 0.32), CFrame.new(center.X - 4.2, signY + rodLen * 0.5, center.Z), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	makePart(model, id .. "_HangerR", Vector3.new(0.32, rodLen, 0.32), CFrame.new(center.X + 4.2, signY + rodLen * 0.5, center.Z), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	makePart(model, id .. "_CorePost", Vector3.new(1.2, signY - 4.4, 0.9), CFrame.new(center.X, 4.4 + (signY - 4.4) * 0.5, center.Z), Color3.fromRGB(58, 64, 76), Enum.Material.Metal, false)

	makeSignBoard(
		model,
		id .. "_Sign",
		Vector3.new(11, 3.2, 0.9),
		CFrame.new(center.X, signY, center.Z),
		Color3.fromRGB(20, 24, 34),
		id:upper(),
		accentColor,
		"CLAIM BAGS CAREFULLY",
		Enum.NormalId.Front,
		true
	)

	makePart(model, "BeltBase", Vector3.new(halfW * 2, 1.0, halfD * 2), CFrame.new(center.X, 0.5, center.Z), Color3.fromRGB(36, 40, 48), Enum.Material.SmoothPlastic, true)
	makePart(model, "BeltTrimRing", Vector3.new(halfW * 2 + 0.4, 0.35, halfD * 2 + 0.4), CFrame.new(center.X, 0.85, center.Z), Color3.fromRGB(162, 172, 184), Enum.Material.Metal, false)

	local track: CarouselTrack = {
		id = id,
		terminalId = terminalId,
		center = center,
		halfW = halfW,
		halfD = halfD,
		surfaceY = surfaceY,
		speed = speed,
		slats = {},
		perimeter = perimeter,
		ownerStandSpots = {
			{ pos = center + Vector3.new(-halfW * 0.45, 0, -(halfD + 4.8)), baseYaw = math.pi },
			{ pos = center + Vector3.new(halfW * 0.45, 0, -(halfD + 4.8)), baseYaw = math.pi },
			{ pos = center + Vector3.new(-halfW * 0.45, 0, halfD + 4.8), baseYaw = 0 },
			{ pos = center + Vector3.new(halfW * 0.45, 0, halfD + 4.8), baseYaw = 0 },
			{ pos = center + Vector3.new(-(halfW + 4.8), 0, 0), baseYaw = -math.pi * 0.5 },
			{ pos = center + Vector3.new(halfW + 4.8, 0, 0), baseYaw = math.pi * 0.5 },
		},
	}

	local slatCount = math.max(16, math.floor(perimeter / 3.4))
	for i = 1, slatCount do
		local dist = ((i - 1) / slatCount) * perimeter
		local pos, yaw = WorldBuilder.EvaluateCarouselPoint(track, dist)
		local slatColor = if i % 2 == 0 then Color3.fromRGB(62, 66, 76) else Color3.fromRGB(48, 52, 60)
		local slat = makePart(
			model,
			"Slat_" .. i,
			Vector3.new(3.1, 0.25, 2.9),
			CFrame.new(pos.X, 1.15, pos.Z) * CFrame.Angles(0, yaw, 0),
			slatColor,
			Enum.Material.DiamondPlate,
			false
		)
		table.insert(track.slats, { part = slat, dist = dist })
	end

	return track
end

local function buildSecurityGate(
	coverParent: Instance,
	windowsParent: Instance,
	terminalId: TerminalId,
	gatePos: Vector3,
	yawDeg: number,
	width: number
): (BasePart, ProximityPrompt)
	local def = GameConfig.TERMINALS[terminalId]
	local origin = CFrame.new(gatePos) * CFrame.Angles(0, math.rad(yawDeg), 0)

	local pillarOffset = width * 0.5 + 1.2
	makePart(coverParent, terminalId .. "_GatePillarL", Vector3.new(2.4, AIRPORT_ROOF_Y, 2.4), origin * CFrame.new(-pillarOffset, AIRPORT_ROOF_Y * 0.5, 0), Color3.fromRGB(36, 42, 54), Enum.Material.Metal, true)
	makePart(coverParent, terminalId .. "_GatePillarR", Vector3.new(2.4, AIRPORT_ROOF_Y, 2.4), origin * CFrame.new(pillarOffset, AIRPORT_ROOF_Y * 0.5, 0), Color3.fromRGB(36, 42, 54), Enum.Material.Metal, true)
	makePart(coverParent, terminalId .. "_GateHeader", Vector3.new(width + 4.8, 3.0, 2.6), origin * CFrame.new(0, 12.2, 0), Color3.fromRGB(26, 30, 40), Enum.Material.Metal, true)

	local clerestoryH = AIRPORT_ROOF_Y - 13.7
	makePart(windowsParent, terminalId .. "_GateClerestory", Vector3.new(width, clerestoryH, 0.6), origin * CFrame.new(0, 13.7 + clerestoryH * 0.5, 0), Color3.fromRGB(168, 214, 244), Enum.Material.Glass, true, 0.55, false)

	makeSignBoard(
		windowsParent,
		terminalId .. "_GateMarquee",
		Vector3.new(width + 2, 2.5, 0.45),
		origin * CFrame.new(0, 12.2, 1.4),
		Color3.fromRGB(18, 22, 32),
		def.name:upper(),
		def.accentColor,
		string.format("TERMINAL PASS: %s", GameConfig.FormatCash(def.unlockCost)),
		Enum.NormalId.Front,
		true
	)

	local barrier = makePart(
		windowsParent,
		terminalId .. "_Barrier",
		Vector3.new(width, 10.7, 0.7),
		origin * CFrame.new(0, 5.35, 0),
		def.accentColor,
		Enum.Material.ForceField,
		true,
		0.45
	)
	barrier:SetAttribute("TerminalId", terminalId)

	local reader = makePart(
		coverParent,
		terminalId .. "_TurnstileReader",
		Vector3.new(1.8, 3.8, 1.8),
		origin * CFrame.new(width * 0.35, 1.9, 2.6),
		Color3.fromRGB(46, 52, 66),
		Enum.Material.Metal,
		true
	)
	makePart(reader, "ReaderTop", Vector3.new(1.4, 0.3, 1.4), origin * CFrame.new(width * 0.35, 3.9, 2.6), def.accentColor, Enum.Material.Neon, false)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockTerminalPrompt"
	prompt.ActionText = string.format("Buy %s Pass", def.shortName)
	prompt.ObjectText = string.format("%s (%s)", def.name, GameConfig.FormatCash(def.unlockCost))
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = reader

	return barrier, prompt
end

local function buildIndustrialCageLight(parent: Instance, name: string, ceilingPos: Vector3, dropLength: number)
	makePart(parent, name .. "_JBox", Vector3.new(1.1, 0.5, 1.1), CFrame.new(ceilingPos.X, ceilingPos.Y - 0.25, ceilingPos.Z), Color3.fromRGB(48, 52, 60), Enum.Material.Metal, false)
	makePart(parent, name .. "_Conduit", Vector3.new(0.24, dropLength, 0.24), CFrame.new(ceilingPos.X, ceilingPos.Y - 0.5 - dropLength * 0.5, ceilingPos.Z), Color3.fromRGB(72, 78, 88), Enum.Material.Metal, false)
	local fixtureY = ceilingPos.Y - 0.5 - dropLength
	makePart(parent, name .. "_Shade", Vector3.new(2.2, 0.55, 2.2), CFrame.new(ceilingPos.X, fixtureY, ceilingPos.Z), Color3.fromRGB(38, 42, 48), Enum.Material.Metal, false)
	local bulb = makePart(parent, name .. "_Bulb", Vector3.new(1.3, 0.4, 1.3), CFrame.new(ceilingPos.X, fixtureY - 0.32, ceilingPos.Z), Color3.fromRGB(255, 218, 146), Enum.Material.Neon, false)
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 220, 160)
	pl.Brightness = 0.85
	pl.Range = 36
	pl.Parent = bulb
end

local function buildVentDuct(parent: Instance, name: string, startPos: Vector3, endPos: Vector3, ceilingY: number, width: number, height: number)
	local delta = endPos - startPos
	local len = delta.Magnitude
	if len < 1 then
		return
	end
	local mid = (startPos + endPos) * 0.5
	local yaw = math.atan2(-delta.X, -delta.Z) + math.pi * 0.5
	local cf = CFrame.new(mid.X, startPos.Y, mid.Z) * CFrame.Angles(0, yaw, 0)
	makePart(parent, name .. "_Duct", Vector3.new(len, height, width), cf, Color3.fromRGB(152, 160, 170), Enum.Material.Metal, true)

	local straps = math.max(2, math.round(len / 14))
	local hangerH = math.max(0.2, ceilingY - (startPos.Y + height * 0.5))
	for i = 0, straps do
		local xOff = -len * 0.45 + (i / straps) * (len * 0.9)
		makePart(parent, name .. "_StrapL_" .. i, Vector3.new(0.35, hangerH, 0.25), cf * CFrame.new(xOff, height * 0.5 + hangerH * 0.5, -width * 0.48), Color3.fromRGB(64, 70, 80), Enum.Material.Metal, false)
		makePart(parent, name .. "_StrapR_" .. i, Vector3.new(0.35, hangerH, 0.25), cf * CFrame.new(xOff, height * 0.5 + hangerH * 0.5, width * 0.48), Color3.fromRGB(64, 70, 80), Enum.Material.Metal, false)
	end
end

local function buildStorageShelf(parent: Instance, name: string, pos: Vector3, yawDeg: number)
	local origin = CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	for _, xS in ipairs({ -4.6, 4.6 }) do
		for _, zS in ipairs({ -1.3, 1.3 }) do
			makePart(parent, name .. "_Post", Vector3.new(0.35, 9.2, 0.35), origin * CFrame.new(xS, 4.6, zS), Color3.fromRGB(62, 68, 78), Enum.Material.Metal, true)
		end
	end
	local shelfHeights = { 0.4, 4.0, 7.6 }
	for idx, sy in ipairs(shelfHeights) do
		makePart(parent, name .. "_Deck_" .. idx, Vector3.new(9.6, 0.3, 3.0), origin * CFrame.new(0, sy, 0), Color3.fromRGB(132, 98, 64), Enum.Material.Wood, true)
		makePart(parent, name .. "_CrateA_" .. idx, Vector3.new(2.4, 2.0, 2.0), origin * CFrame.new(-2.4, sy + 1.15, 0), Color3.fromRGB(156, 118, 76), Enum.Material.WoodPlanks, true)
		makePart(parent, name .. "_CrateB_" .. idx, Vector3.new(2.2, 1.6, 1.8), origin * CFrame.new(1.8, sy + 0.95, 0), Color3.fromRGB(58, 74, 96), Enum.Material.Metal, true)
	end
end

local function buildWorkbench(parent: Instance, slotIndex: number, pos: Vector3, yawRad: number): WorkbenchStation
	local model = Instance.new("Model")
	model.Name = "Workbench_" .. slotIndex
	model.Parent = parent

	-- Local -Z is front (StatusStrip); yawRad rotates bench cleanly to face the center aisle (+X / -X)
	local origin = CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, yawRad, 0)
	for _, lx in ipairs({ -3.4, 3.4 }) do
		for _, lz in ipairs({ -1.9, 1.9 }) do
			makePart(model, "Foot", Vector3.new(0.65, 0.25, 0.65), origin * CFrame.new(lx, 0.125, lz), Color3.fromRGB(28, 30, 36), Enum.Material.SmoothPlastic, true)
			makePart(model, "Leg", Vector3.new(0.45, 2.9, 0.45), origin * CFrame.new(lx, 1.65, lz), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
		end
	end
	makePart(model, "LowerShelf", Vector3.new(7.0, 0.25, 3.8), origin * CFrame.new(0, 0.95, 0), Color3.fromRGB(54, 60, 72), Enum.Material.Metal, true)
	makePart(model, "DeskBase", Vector3.new(7.4, 1.6, 4.4), origin * CFrame.new(0, 2.3, 0), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(model, "DeskTop", Vector3.new(7.8, 0.35, 4.8), origin * CFrame.new(0, 3.25, 0), Color3.fromRGB(72, 78, 90), Enum.Material.DiamondPlate, true)

	local stripColor = if slotIndex == 1 then Color3.fromRGB(72, 224, 255) else Color3.fromRGB(110, 118, 132)
	local statusStrip = makePart(model, "StatusStrip", Vector3.new(7.6, 0.25, 0.35), origin * CFrame.new(0, 3.15, -2.45), stripColor, Enum.Material.Neon, false)

	-- Tool backboard on South (+Z) edge, lamp gantry arching forward over the worktop
	makePart(model, "Backboard", Vector3.new(7.2, 2.4, 0.35), origin * CFrame.new(0, 4.6, 2.1), Color3.fromRGB(36, 40, 50), Enum.Material.Metal, true)
	makePart(model, "GantryPostL", Vector3.new(0.35, 5.2, 0.35), origin * CFrame.new(-3.4, 5.8, 2.1), Color3.fromRGB(58, 64, 76), Enum.Material.Metal, true)
	makePart(model, "GantryPostR", Vector3.new(0.35, 5.2, 0.35), origin * CFrame.new(3.4, 5.8, 2.1), Color3.fromRGB(58, 64, 76), Enum.Material.Metal, true)
	makePart(model, "GantryArm", Vector3.new(7.2, 0.35, 2.6), origin * CFrame.new(0, 8.2, 0.9), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, false)
	makePart(model, "BenchLampGlow", Vector3.new(5.4, 0.18, 0.6), origin * CFrame.new(0, 7.98, 0.2), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, false)

	local anchorPart = makePart(model, "PromptAnchor", Vector3.new(2, 1, 2), origin * CFrame.new(0, 4.0, 0), stripColor, Enum.Material.SmoothPlastic, false, 1)
	local bb = Instance.new("BillboardGui")
	bb.Name = "WorkbenchStatusGui"
	bb.Size = UDim2.fromOffset(220, 86)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 85
	bb.Parent = anchorPart

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	card.BackgroundTransparency = 0.14
	card.BorderSizePixel = 0
	card.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(82, 198, 255)
	stroke.Thickness = 2
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -14, 0, 28)
	title.Position = UDim2.fromOffset(7, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "WORKBENCH #" .. slotIndex
	title.TextColor3 = Color3.fromRGB(245, 248, 255)
	title.TextScaled = true
	title.Parent = card

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -14, 0, 22)
	sub.Position = UDim2.fromOffset(7, 34)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.Text = if slotIndex == 1 then "Empty — Press E to Crack" else "Locked Slot"
	sub.TextColor3 = Color3.fromRGB(168, 206, 232)
	sub.TextScaled = true
	sub.Parent = card

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -18, 0, 12)
	barBg.Position = UDim2.fromOffset(9, 64)
	barBg.BackgroundColor3 = Color3.fromRGB(38, 44, 58)
	barBg.BorderSizePixel = 0
	barBg.Parent = card

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = barBg

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Color3.fromRGB(72, 224, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = progressFill

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WorkbenchPrompt"
	prompt.ActionText = "Use Workbench #" .. slotIndex
	prompt.ObjectText = "Luggage Cracking Bench"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchorPart

	return {
		slotIndex = slotIndex,
		model = model,
		surfaceCFrame = origin * CFrame.new(0, 3.45, 0) * CFrame.Angles(0, math.pi, 0),
		statusStrip = statusStrip,
		prompt = prompt,
		billboardTitle = title,
		billboardSub = sub,
		progressFill = progressFill,
	}
end

local function buildStylizedNPC(
	parent: Instance,
	name: string,
	pos: Vector3,
	yaw: number,
	shirtColor: Color3,
	stripeColor: Color3,
	trimColor: Color3,
	tagColor: Color3,
	skinTone: Color3,
	hairColor: Color3,
	accessoryType: GameConfig.AccessoryType
): Model
	local npc = Instance.new("Model")
	npc.Name = name

	local origin = CFrame.new(pos.X, pos.Y, pos.Z) * CFrame.Angles(0, yaw, 0)

	local hrp = makePart(npc, "HumanoidRootPart", Vector3.new(2, 2, 1), origin * CFrame.new(0, 3.0, 0), shirtColor, Enum.Material.SmoothPlastic, false, 1)
	npc.PrimaryPart = hrp

	local torso = makePart(npc, "Torso", Vector3.new(2.1, 2.1, 1.05), origin * CFrame.new(0, 3.0, 0), shirtColor, Enum.Material.Fabric, false)
	makePart(npc, "OutfitStripe", Vector3.new(0.55, 2.12, 1.1), origin * CFrame.new(0, 3.0, 0), stripeColor, Enum.Material.SmoothPlastic, false)
	makePart(npc, "BeltTrim", Vector3.new(2.15, 0.25, 1.12), origin * CFrame.new(0, 2.12, 0), trimColor, Enum.Material.Metal, false)

	local head = makePart(npc, "Head", Vector3.new(1.3, 1.3, 1.3), origin * CFrame.new(0, 4.75, 0), skinTone, Enum.Material.SmoothPlastic, false)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.1, 1.1, 1.1)
	headMesh.Parent = head

	makePart(npc, "EyeL", Vector3.new(0.18, 0.18, 0.1), origin * CFrame.new(-0.28, 4.82, -0.66), Color3.fromRGB(22, 24, 30), Enum.Material.SmoothPlastic, false)
	makePart(npc, "EyeR", Vector3.new(0.18, 0.18, 0.1), origin * CFrame.new(0.28, 4.82, -0.66), Color3.fromRGB(22, 24, 30), Enum.Material.SmoothPlastic, false)
	makePart(npc, "Hair", Vector3.new(1.38, 0.55, 1.38), origin * CFrame.new(0, 5.28, 0.06), hairColor, Enum.Material.SmoothPlastic, false)

	makePart(npc, "LeftArm", Vector3.new(0.85, 2.0, 0.85), origin * CFrame.new(-1.52, 3.0, 0), shirtColor, Enum.Material.Fabric, false)
	makePart(npc, "RightArm", Vector3.new(0.85, 2.0, 0.85), origin * CFrame.new(1.52, 3.0, 0), shirtColor, Enum.Material.Fabric, false)
	makePart(npc, "LeftLeg", Vector3.new(0.9, 2.0, 0.9), origin * CFrame.new(-0.55, 1.0, 0), trimColor, Enum.Material.SmoothPlastic, false)
	makePart(npc, "RightLeg", Vector3.new(0.9, 2.0, 0.9), origin * CFrame.new(0.55, 1.0, 0), trimColor, Enum.Material.SmoothPlastic, false)

	if accessoryType == "Hat" then
		makePart(npc, "HatBrim", Vector3.new(2.0, 0.16, 2.0), origin * CFrame.new(0, 5.45, -0.08), tagColor, Enum.Material.SmoothPlastic, false)
		makePart(npc, "HatCrown", Vector3.new(1.35, 0.6, 1.35), origin * CFrame.new(0, 5.8, 0), tagColor, Enum.Material.SmoothPlastic, false)
		makePart(npc, "HatBand", Vector3.new(1.4, 0.16, 1.4), origin * CFrame.new(0, 5.58, 0), trimColor, Enum.Material.SmoothPlastic, false)
	elseif accessoryType == "Glasses" then
		makePart(npc, "GlassesBridge", Vector3.new(1.32, 0.34, 0.22), origin * CFrame.new(0, 4.84, -0.68), tagColor, Enum.Material.Neon, false)
	elseif accessoryType == "Headset" then
		makePart(npc, "Headband", Vector3.new(1.6, 0.24, 0.35), origin * CFrame.new(0, 5.55, 0), trimColor, Enum.Material.SmoothPlastic, false)
		makePart(npc, "EarCupL", Vector3.new(0.28, 0.65, 0.65), origin * CFrame.new(-0.78, 4.82, 0), tagColor, Enum.Material.Neon, false)
		makePart(npc, "EarCupR", Vector3.new(0.28, 0.65, 0.65), origin * CFrame.new(0.78, 4.82, 0), tagColor, Enum.Material.Neon, false)
	elseif accessoryType == "Crown" then
		makePart(npc, "CrownBase", Vector3.new(1.4, 0.45, 1.4), origin * CFrame.new(0, 5.65, 0), trimColor, Enum.Material.Metal, false)
		makePart(npc, "CrownGem", Vector3.new(0.35, 0.35, 0.2), origin * CFrame.new(0, 5.82, -0.7), tagColor, Enum.Material.Neon, false)
	elseif accessoryType == "Scarf" then
		makePart(npc, "ScarfRing", Vector3.new(1.7, 0.42, 1.35), origin * CFrame.new(0, 4.05, 0), tagColor, Enum.Material.Fabric, false)
		makePart(npc, "ScarfTail", Vector3.new(0.5, 1.2, 0.2), origin * CFrame.new(0.35, 3.35, -0.58), tagColor, Enum.Material.Fabric, false)
	elseif accessoryType == "Beret" then
		makePart(npc, "BeretTop", Vector3.new(1.65, 0.38, 1.65), origin * CFrame.new(0.15, 5.56, 0) * CFrame.Angles(0, 0, math.rad(-14)), tagColor, Enum.Material.Fabric, false)
	end

	for _, descendant in ipairs(npc:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= hrp then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = descendant
			weld.Parent = hrp
		end
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "AlertBillboard"
	bb.Size = UDim2.fromOffset(56, 56)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 75
	bb.Enabled = false
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "StatusText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "!"
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = bb

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 0
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = npc

	torso.Name = "Torso"
	npc.Parent = parent
	return npc
end

function WorldBuilder.BuildPassengerNPC(parent: Instance, archetype: GameConfig.ArchetypeDef, pos: Vector3, yaw: number): Model
	return buildStylizedNPC(
		parent,
		"Passenger_" .. archetype.id,
		pos,
		yaw,
		archetype.primaryColor,
		archetype.secondaryColor,
		archetype.trimColor,
		archetype.tagColor,
		archetype.skinTone,
		archetype.hairColor,
		archetype.accessoryType
	)
end

function WorldBuilder.BuildSecurityNPC(parent: Instance, pos: Vector3, yaw: number): Model
	return buildStylizedNPC(
		parent,
		"AirportSecurity",
		pos,
		yaw,
		Color3.fromRGB(26, 40, 74),
		Color3.fromRGB(245, 200, 62),
		Color3.fromRGB(24, 28, 38),
		Color3.fromRGB(64, 174, 255),
		Color3.fromRGB(224, 180, 148),
		Color3.fromRGB(36, 32, 30),
		"Hat"
	)
end

local function configureLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.1
	Lighting.Ambient = Color3.fromRGB(115, 122, 138)
	Lighting.OutdoorAmbient = Color3.fromRGB(142, 150, 166)
	Lighting.GlobalShadows = true
end

local function buildStylizedPlane(
	parent: Instance,
	name: string,
	origin: CFrame,
	scale: number,
	stripeColor: Color3,
	tailColor: Color3
)
	local jet = Instance.new("Model")
	jet.Name = name
	jet.Parent = parent

	local fuselageCenter = origin * CFrame.new(0, 9.2 * scale, 0)
	makePart(jet, "GearNose", Vector3.new(1.3 * scale, 5.2 * scale, 1.3 * scale), origin * CFrame.new(-16 * scale, 2.6 * scale, 0), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
	makePart(jet, "GearMain", Vector3.new(2.2 * scale, 5.2 * scale, 8.0 * scale), origin * CFrame.new(3 * scale, 2.6 * scale, 0), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
	makePart(jet, "Fuselage", Vector3.new(46 * scale, 8.6 * scale, 8.4 * scale), fuselageCenter, Color3.fromRGB(244, 246, 250), Enum.Material.SmoothPlastic, true)
	makePart(jet, "Stripe", Vector3.new(44 * scale, 1.3 * scale, 8.6 * scale), fuselageCenter * CFrame.new(0, -0.4 * scale, 0), stripeColor, Enum.Material.Neon, false)
	makePart(jet, "NoseCone", Vector3.new(7 * scale, 6.4 * scale, 6.4 * scale), fuselageCenter * CFrame.new(-25.5 * scale, -0.5 * scale, 0), Color3.fromRGB(238, 242, 248), Enum.Material.SmoothPlastic, true)
	makePart(jet, "CockpitGlass", Vector3.new(4 * scale, 2.2 * scale, 5.6 * scale), fuselageCenter * CFrame.new(-22 * scale, 1.7 * scale, 0), Color3.fromRGB(32, 56, 84), Enum.Material.Glass, false, 0.2)
	makePart(jet, "MainWing", Vector3.new(13 * scale, 1.1 * scale, 44 * scale), fuselageCenter * CFrame.new(2 * scale, -1.8 * scale, 0), Color3.fromRGB(230, 235, 244), Enum.Material.SmoothPlastic, true)
	-- Twin under-wing turbine engines
	for _, zSide in ipairs({ -10.5 * scale, 10.5 * scale }) do
		makePart(jet, "Engine", Vector3.new(6.8 * scale, 2.8 * scale, 2.8 * scale), fuselageCenter * CFrame.new(-1.5 * scale, -3.4 * scale, zSide), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, true)
	end
	makePart(jet, "TailFin", Vector3.new(7.5 * scale, 9.6 * scale, 1.3 * scale), fuselageCenter * CFrame.new(19 * scale, 7.0 * scale, 0) * CFrame.Angles(0, 0, math.rad(-18)), tailColor, Enum.Material.SmoothPlastic, true)
end

local function buildPerimeterTree(parent: Instance, pos: Vector3, scale: number)
	makePart(parent, "Trunk", Vector3.new(1.5 * scale, 7 * scale, 1.5 * scale), CFrame.new(pos.X, 3.5 * scale, pos.Z), Color3.fromRGB(98, 68, 44), Enum.Material.Wood, false)
	makePart(parent, "CanopyLow", Vector3.new(8.5 * scale, 5.5 * scale, 8.5 * scale), CFrame.new(pos.X, 9 * scale, pos.Z), Color3.fromRGB(54, 128, 62), Enum.Material.Grass, false)
	makePart(parent, "CanopyTop", Vector3.new(6.2 * scale, 4.5 * scale, 6.2 * scale), CFrame.new(pos.X, 12.2 * scale, pos.Z), Color3.fromRGB(68, 146, 72), Enum.Material.Grass, false)
end

local function buildCityBuilding(
	parent: Instance,
	name: string,
	pos: Vector3,
	w: number,
	d: number,
	h: number,
	bodyColor: Color3,
	accentColor: Color3
)
	-- Grounded podium + upper tower + lit window bands + rooftop penthouse
	local podiumH = math.min(18, h * 0.22)
	makePart(parent, name .. "_Podium", Vector3.new(w + 6, podiumH, d + 6), CFrame.new(pos.X, podiumH * 0.5, pos.Z), Color3.fromRGB(48, 54, 66), Enum.Material.Concrete, false)
	makePart(parent, name .. "_Shaft", Vector3.new(w, h, d), CFrame.new(pos.X, h * 0.5, pos.Z), bodyColor, Enum.Material.SmoothPlastic, false)
	local bandStep = 14
	for yBand = podiumH + 8, h - 6, bandStep do
		makePart(parent, name .. "_WinBand_" .. yBand, Vector3.new(w + 0.5, 4.2, d + 0.5), CFrame.new(pos.X, yBand, pos.Z), accentColor, Enum.Material.Glass, false, 0.25)
	end
	makePart(parent, name .. "_Crown", Vector3.new(w * 0.68, 6, d * 0.68), CFrame.new(pos.X, h + 3, pos.Z), Color3.fromRGB(36, 42, 54), Enum.Material.Metal, false)
	makePart(parent, name .. "_CrownGlow", Vector3.new(w * 0.72, 1.4, d * 0.72), CFrame.new(pos.X, h + 0.7, pos.Z), accentColor, Enum.Material.Neon, false)
end

local function buildParkingGarage(parent: Instance, name: string, pos: Vector3, w: number, d: number)
	local levels = 3
	local levelH = 8.5
	for lvl = 1, levels do
		local yDeck = lvl * levelH
		makePart(parent, name .. "_Deck_" .. lvl, Vector3.new(w, 1.2, d), CFrame.new(pos.X, yDeck, pos.Z), Color3.fromRGB(118, 124, 134), Enum.Material.Concrete, false)
		makePart(parent, name .. "_WallN_" .. lvl, Vector3.new(w, 3.2, 0.8), CFrame.new(pos.X, yDeck + 2.0, pos.Z - d * 0.5 + 0.4), Color3.fromRGB(152, 158, 168), Enum.Material.Concrete, false)
		makePart(parent, name .. "_WallS_" .. lvl, Vector3.new(w, 3.2, 0.8), CFrame.new(pos.X, yDeck + 2.0, pos.Z + d * 0.5 - 0.4), Color3.fromRGB(152, 158, 168), Enum.Material.Concrete, false)
	end
	for _, xCol in ipairs({ -w * 0.46, 0, w * 0.46 }) do
		for _, zCol in ipairs({ -d * 0.46, d * 0.46 }) do
			makePart(parent, name .. "_Col", Vector3.new(2.2, levels * levelH, 2.2), CFrame.new(pos.X + xCol, levels * levelH * 0.5, pos.Z + zCol), Color3.fromRGB(78, 84, 96), Enum.Material.Concrete, false)
		end
	end
	-- Stair tower & parked cars on roof deck
	makePart(parent, name .. "_StairTower", Vector3.new(10, levels * levelH + 6, 10), CFrame.new(pos.X - w * 0.5 - 4, (levels * levelH + 6) * 0.5, pos.Z), Color3.fromRGB(64, 72, 86), Enum.Material.Glass, false, 0.3)
	local carColors = { Color3.fromRGB(204, 52, 62), Color3.fromRGB(58, 128, 212), Color3.fromRGB(228, 232, 238), Color3.fromRGB(238, 182, 54) }
	for i = 1, 4 do
		local cx = pos.X - w * 0.32 + (i - 1) * (w * 0.21)
		local topY = levels * levelH + 0.6
		makePart(parent, name .. "_Car_" .. i, Vector3.new(6.2, 2.6, 11.0), CFrame.new(cx, topY + 1.3, pos.Z), carColors[i], Enum.Material.SmoothPlastic, false)
	end
end

local function buildHangarAndJet(parent: Instance, name: string, pos: Vector3, yawDeg: number, accentColor: Color3)
	local origin = CFrame.new(pos.X, 0, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(parent, name .. "_WallL", Vector3.new(3.2, 24, 56), origin * CFrame.new(-28, 12, 0), Color3.fromRGB(76, 84, 98), Enum.Material.Metal, false)
	makePart(parent, name .. "_WallR", Vector3.new(3.2, 24, 56), origin * CFrame.new(28, 12, 0), Color3.fromRGB(76, 84, 98), Enum.Material.Metal, false)
	makePart(parent, name .. "_WallBack", Vector3.new(59, 24, 3.2), origin * CFrame.new(0, 12, 28), Color3.fromRGB(68, 76, 90), Enum.Material.Metal, false)
	makePart(parent, name .. "_Roof", Vector3.new(62, 3.4, 60), origin * CFrame.new(0, 25.5, 0), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, false)
	makePart(parent, name .. "_SignStrip", Vector3.new(44, 2.2, 1.0), origin * CFrame.new(0, 22.8, -29.2), accentColor, Enum.Material.Neon, false)
	buildStylizedPlane(parent, name .. "_ParkedPlane", origin * CFrame.new(0, 0.18, -8) * CFrame.Angles(0, math.pi * 0.5, 0), 0.78, accentColor, accentColor)
end

local function buildJetwayBridge(parent: Instance, name: string, terminalPos: Vector3, planeDoorPos: Vector3)
	local delta = planeDoorPos - terminalPos
	local len = delta.Magnitude
	local mid = (terminalPos + planeDoorPos) * 0.5
	local yaw = math.atan2(-delta.X, -delta.Z) + math.pi * 0.5
	local cf = CFrame.new(mid.X, 8.2, mid.Z) * CFrame.Angles(0, yaw, 0)
	makePart(parent, name .. "_Tunnel", Vector3.new(len, 4.6, 4.2), cf, Color3.fromRGB(224, 228, 236), Enum.Material.SmoothPlastic, false)
	makePart(parent, name .. "_Glass", Vector3.new(len * 0.88, 2.2, 4.4), cf, Color3.fromRGB(132, 188, 228), Enum.Material.Glass, false, 0.4)
	makePart(parent, name .. "_Leg", Vector3.new(1.6, 6.2, 1.6), CFrame.new(planeDoorPos.X, 3.1, planeDoorPos.Z), Color3.fromRGB(58, 64, 76), Enum.Material.Metal, false)
end

local function buildFuelTruck(parent: Instance, name: string, pos: Vector3, yawDeg: number)
	local origin = CFrame.new(pos.X, 0.18, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(parent, name .. "_Cab", Vector3.new(4.2, 4.0, 4.6), origin * CFrame.new(0, 2.6, -4.8), Color3.fromRGB(238, 240, 246), Enum.Material.SmoothPlastic, false)
	makePart(parent, name .. "_Tank", Vector3.new(4.4, 4.2, 9.5), origin * CFrame.new(0, 2.9, 2.6), Color3.fromRGB(246, 188, 52), Enum.Material.Metal, false)
	makePart(parent, name .. "_Wheels", Vector3.new(4.8, 1.6, 11.5), origin * CFrame.new(0, 0.8, 0), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic, false)
end

local function buildExteriorTarmacAndSkyline(parent: Instance)
	-- Expansive 360-degree terrain base spanning well beyond all four airport curtain walls
	makePart(parent, "AirfieldGrassBase", Vector3.new(1400, 0.3, 1300), CFrame.new(0, -0.2, -100), Color3.fromRGB(72, 110, 64), Enum.Material.Grass, true)
	makePart(parent, "ApronConcrete", Vector3.new(760, 0.2, 340), CFrame.new(0, 0.08, -120), Color3.fromRGB(84, 88, 96), Enum.Material.Concrete, true)

	-- Parallel Asphalt Runways (North)
	for rIdx, zRunway in ipairs({ -285, -375 }) do
		makePart(parent, "Runway_" .. rIdx, Vector3.new(1180, 0.25, 36), CFrame.new(0, 0.14, zRunway), Color3.fromRGB(40, 44, 50), Enum.Material.Asphalt, true)
		for xDash = -540, 540, 32 do
			makePart(parent, string.format("CenterDash_%d_%d", rIdx, xDash), Vector3.new(16, 0.06, 1.4), CFrame.new(xDash, 0.28, zRunway), Color3.fromRGB(242, 245, 250), Enum.Material.SmoothPlastic, false)
		end
		for _, xEnd in ipairs({ -560, 560 }) do
			for k = -3, 3 do
				makePart(parent, string.format("Thresh_%d_%d_%d", rIdx, xEnd, k), Vector3.new(14, 0.06, 1.8), CFrame.new(xEnd, 0.28, zRunway + k * 4.4), Color3.fromRGB(242, 245, 250), Enum.Material.SmoothPlastic, false)
			end
		end
		for xLight = -500, 500, 40 do
			for _, zSide in ipairs({ zRunway - 19, zRunway + 19 }) do
				makePart(parent, "EdgePost", Vector3.new(0.45, 1.1, 0.45), CFrame.new(xLight, 0.72, zSide), Color3.fromRGB(48, 52, 60), Enum.Material.Metal, false)
				makePart(parent, "EdgeLamp", Vector3.new(0.65, 0.4, 0.65), CFrame.new(xLight, 1.38, zSide), Color3.fromRGB(255, 224, 118), Enum.Material.Neon, false)
			end
		end
	end

	makePart(parent, "TaxiWayNorth", Vector3.new(740, 0.1, 1.4), CFrame.new(0, 0.22, -214), Color3.fromRGB(245, 198, 52), Enum.Material.SmoothPlastic, false)
	for _, xConn in ipairs({ -240, -110, 110, 240 }) do
		makePart(parent, "TaxiConn_" .. xConn, Vector3.new(18, 0.2, 68), CFrame.new(xConn, 0.14, -248), Color3.fromRGB(52, 56, 64), Enum.Material.Asphalt, true)
		makePart(parent, "TaxiLine_" .. xConn, Vector3.new(1.2, 0.06, 64), CFrame.new(xConn, 0.26, -248), Color3.fromRGB(245, 198, 52), Enum.Material.SmoothPlastic, false)
	end

	-- Air Traffic Control Tower
	local towerPos = Vector3.new(-248, 0, -212)
	makePart(parent, "ATCTowerShaft", Vector3.new(12, 54, 12), CFrame.new(towerPos + Vector3.new(0, 27, 0)), Color3.fromRGB(198, 204, 214), Enum.Material.Concrete, true)
	makePart(parent, "ATCTowerCab", Vector3.new(22, 9, 22), CFrame.new(towerPos + Vector3.new(0, 58, 0)), Color3.fromRGB(68, 124, 168), Enum.Material.Glass, true, 0.35)
	makePart(parent, "ATCTowerRoof", Vector3.new(25, 2.2, 25), CFrame.new(towerPos + Vector3.new(0, 63.5, 0)), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(parent, "ATCRadarMast", Vector3.new(1.2, 10, 1.2), CFrame.new(towerPos + Vector3.new(0, 69, 0)), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	makePart(parent, "ATCBeacon", Vector3.new(2.2, 1.6, 2.2), CFrame.new(towerPos + Vector3.new(0, 74.5, 0)), Color3.fromRGB(255, 68, 76), Enum.Material.Neon, false)

	-- Parked & Taxiing Aircraft + Jetways + Hangars + Fuel Trucks
	buildStylizedPlane(parent, "CelebrityPrivateJet", CFrame.new(12, 0.18, -222), 0.95, Color3.fromRGB(255, 198, 62), Color3.fromRGB(255, 86, 152))
	buildStylizedPlane(parent, "InternationalAirliner", CFrame.new(-168, 0.18, -112) * CFrame.Angles(0, math.rad(14), 0), 1.05, GameConfig.TERMINALS.International.accentColor, GameConfig.TERMINALS.International.accentColor)
	buildStylizedPlane(parent, "VipCharterAirliner", CFrame.new(168, 0.18, -138) * CFrame.Angles(0, math.rad(-18), 0), 0.92, Color3.fromRGB(255, 194, 64), Color3.fromRGB(48, 56, 86))
	buildStylizedPlane(parent, "RunwayTaxiAirliner1", CFrame.new(-135, 0.26, -285), 1.25, Color3.fromRGB(78, 178, 255), Color3.fromRGB(36, 72, 148))
	buildStylizedPlane(parent, "RunwayTaxiAirliner2", CFrame.new(240, 0.26, -375) * CFrame.Angles(0, math.pi, 0), 1.2, Color3.fromRGB(238, 92, 68), Color3.fromRGB(168, 32, 46))

	buildJetwayBridge(parent, "IntlJetway", Vector3.new(-158, 0, -59), Vector3.new(-164, 0, -104))
	buildJetwayBridge(parent, "VipJetway", Vector3.new(158, 0, -59), Vector3.new(164, 0, -130))
	buildFuelTruck(parent, "IntlFuelTruck", Vector3.new(-142, 0, -136), 35)
	buildFuelTruck(parent, "VipFuelTruck", Vector3.new(140, 0, -118), -40)
	buildHangarAndJet(parent, "WestHangar", Vector3.new(-325, 0, -138), -90, GameConfig.TERMINALS.International.accentColor)
	buildHangarAndJet(parent, "EastHangar", Vector3.new(325, 0, -138), 90, GameConfig.TERMINALS.FirstClass.accentColor)

	-- Baggage Tug & Loaded Carts
	local tugPos = Vector3.new(158, 0.18, -96)
	makePart(parent, "BaggageTugBody", Vector3.new(8, 3.2, 4.4), CFrame.new(tugPos + Vector3.new(0, 2.2, 0)), Color3.fromRGB(238, 186, 52), Enum.Material.SmoothPlastic, true)
	makePart(parent, "BaggageTugCab", Vector3.new(4.2, 2.6, 4.0), CFrame.new(tugPos + Vector3.new(-1.2, 5.1, 0)), Color3.fromRGB(48, 56, 70), Enum.Material.Glass, false, 0.35)
	for _, xW in ipairs({ -2.6, 2.6 }) do
		makePart(parent, "TugWheel", Vector3.new(1.5, 1.5, 4.8), CFrame.new(tugPos + Vector3.new(xW, 0.75, 0)), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic, true)
	end
	for c = 1, 2 do
		local cPos = tugPos + Vector3.new(9 * c, 0, 0)
		makePart(parent, "BaggageTrailer_" .. c, Vector3.new(6.8, 1.6, 4.0), CFrame.new(cPos + Vector3.new(0, 1.4, 0)), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, true)
		makePart(parent, "TrailerHitch_" .. c, Vector3.new(2.4, 0.35, 0.5), CFrame.new(cPos + Vector3.new(-4.5, 1.1, 0)), Color3.fromRGB(48, 52, 60), Enum.Material.Metal, false)
	end

	-- Perimeter Roads & Elevated Highway Overpass (strictly clear of Corridor X=-35..35, Z=65..102 and Hideout X=-69..69, Z=102..163)
	makePart(parent, "RoadWestPerimeter", Vector3.new(22, 0.2, 300), CFrame.new(-244, 0.06, 42), Color3.fromRGB(48, 52, 58), Enum.Material.Asphalt, false)
	makePart(parent, "RoadEastPerimeter", Vector3.new(22, 0.2, 300), CFrame.new(244, 0.06, 42), Color3.fromRGB(48, 52, 58), Enum.Material.Asphalt, false)
	makePart(parent, "RoadSouthW", Vector3.new(196, 0.2, 20), CFrame.new(-144, 0.06, 92), Color3.fromRGB(48, 52, 58), Enum.Material.Asphalt, false)
	makePart(parent, "RoadSouthE", Vector3.new(196, 0.2, 20), CFrame.new(144, 0.06, 92), Color3.fromRGB(48, 52, 58), Enum.Material.Asphalt, false)
	makePart(parent, "RoadSouthLoop", Vector3.new(620, 0.2, 24), CFrame.new(0, 0.06, 192), Color3.fromRGB(48, 52, 58), Enum.Material.Asphalt, false)

	-- Streetlights along South & Perimeter Boulevards
	for _, xLamp in ipairs({ -200, -140, -80, 80, 140, 200 }) do
		makePart(parent, "BoulevardPole_" .. xLamp, Vector3.new(0.6, 14, 0.6), CFrame.new(xLamp, 7, 104), Color3.fromRGB(68, 74, 86), Enum.Material.Metal, false)
		makePart(parent, "BoulevardArm_" .. xLamp, Vector3.new(0.5, 0.5, 4.2), CFrame.new(xLamp, 13.8, 102), Color3.fromRGB(68, 74, 86), Enum.Material.Metal, false)
		makePart(parent, "BoulevardLamp_" .. xLamp, Vector3.new(1.4, 0.4, 2.0), CFrame.new(xLamp, 13.4, 100.4), Color3.fromRGB(255, 224, 152), Enum.Material.Neon, false)
	end

	-- Elevated Highway Overpass (Z = 242, Y = 18) with piers & streetlights
	makePart(parent, "HighwayDeck", Vector3.new(1240, 2.2, 34), CFrame.new(0, 18.0, 242), Color3.fromRGB(54, 58, 66), Enum.Material.Asphalt, false)
	makePart(parent, "HighwayRailN", Vector3.new(1240, 2.6, 1.2), CFrame.new(0, 20.4, 225.6), Color3.fromRGB(168, 174, 184), Enum.Material.Concrete, false)
	makePart(parent, "HighwayRailS", Vector3.new(1240, 2.6, 1.2), CFrame.new(0, 20.4, 258.4), Color3.fromRGB(168, 174, 184), Enum.Material.Concrete, false)
	for xPier = -480, 480, 80 do
		makePart(parent, "HighwayPier_" .. xPier, Vector3.new(6, 17, 14), CFrame.new(xPier, 8.5, 242), Color3.fromRGB(132, 138, 148), Enum.Material.Concrete, false)
		makePart(parent, "HighwayMedianPole_" .. xPier, Vector3.new(0.7, 12, 0.7), CFrame.new(xPier, 25, 242), Color3.fromRGB(76, 82, 92), Enum.Material.Metal, false)
		makePart(parent, "HighwayLampN_" .. xPier, Vector3.new(2.2, 0.5, 4.8), CFrame.new(xPier, 30.8, 242), Color3.fromRGB(255, 224, 156), Enum.Material.Neon, false)
	end

	-- Multi-level Airport Parking Garages outside South-West & South-East windows
	buildParkingGarage(parent, "ParkingGarageSW", Vector3.new(-150, 0, 144), 76, 48)
	buildParkingGarage(parent, "ParkingGarageSE", Vector3.new(150, 0, 144), 76, 48)

	-- Dense Tree Groves on West, East & South landscaped parks
	for _, zTree in ipairs({ -60, -20, 20, 60, 120, 165 }) do
		buildPerimeterTree(parent, Vector3.new(-224, 0, zTree), 1.35)
		buildPerimeterTree(parent, Vector3.new(224, 0, zTree), 1.35)
		buildPerimeterTree(parent, Vector3.new(-264, 0, zTree + 12), 1.45)
		buildPerimeterTree(parent, Vector3.new(264, 0, zTree + 12), 1.45)
	end
	for _, xTree in ipairs({ -200, -130, -90, 90, 130, 200 }) do
		buildPerimeterTree(parent, Vector3.new(xTree, 0, 74), 1.2)
	end

	-- Dense 360-Degree City Skyline (North, West, East, and South Districts)
	local buildingPalette = {
		Color3.fromRGB(64, 76, 98),
		Color3.fromRGB(82, 92, 112),
		Color3.fromRGB(52, 62, 82),
		Color3.fromRGB(98, 108, 128),
	}
	local northTowers = {
		{ x = -480, z = -490, w = 44, d = 44, h = 115 },
		{ x = -410, z = -515, w = 50, d = 46, h = 158 },
		{ x = -335, z = -485, w = 42, d = 40, h = 92 },
		{ x = -255, z = -525, w = 54, d = 48, h = 185 },
		{ x = -175, z = -495, w = 46, d = 42, h = 130 },
		{ x = -95, z = -520, w = 52, d = 50, h = 168 },
		{ x = -15, z = -540, w = 60, d = 54, h = 210 },
		{ x = 70, z = -510, w = 48, d = 46, h = 148 },
		{ x = 150, z = -530, w = 54, d = 48, h = 192 },
		{ x = 235, z = -495, w = 46, d = 44, h = 122 },
		{ x = 315, z = -520, w = 50, d = 46, h = 164 },
		{ x = 395, z = -490, w = 44, d = 42, h = 104 },
		{ x = 475, z = -515, w = 52, d = 46, h = 142 },
	}
	for idx, b in ipairs(northTowers) do
		local col = buildingPalette[((idx - 1) % #buildingPalette) + 1]
		buildCityBuilding(parent, "SkylineN_" .. idx, Vector3.new(b.x, 0, b.z), b.w, b.d, b.h, col, Color3.fromRGB(168, 214, 244))
	end

	-- West & East Airport Hotel / Corporate Districts (directly outside West & East terminal glass)
	for idx, zCoord in ipairs({ -40, 35, 115, 185 }) do
		local hW = 72 + (idx % 3) * 34
		local hE = 78 + ((idx + 1) % 3) * 36
		buildCityBuilding(parent, "WestHotel_" .. idx, Vector3.new(-305, 0, zCoord), 44, 46, hW, buildingPalette[(idx % 4) + 1], Color3.fromRGB(142, 212, 250))
		buildCityBuilding(parent, "WestTower_" .. idx, Vector3.new(-390, 0, zCoord + 15), 52, 50, hW + 46, buildingPalette[((idx + 2) % 4) + 1], Color3.fromRGB(255, 218, 146))
		buildCityBuilding(parent, "EastHotel_" .. idx, Vector3.new(305, 0, zCoord), 44, 46, hE, buildingPalette[((idx + 1) % 4) + 1], Color3.fromRGB(255, 206, 112))
		buildCityBuilding(parent, "EastTower_" .. idx, Vector3.new(390, 0, zCoord - 15), 52, 50, hE + 48, buildingPalette[((idx + 3) % 4) + 1], Color3.fromRGB(168, 214, 244))
	end

	-- South City Skyline District across the highway overpass (directly visible from South terminal windows)
	for idx = 1, 11 do
		local sx = -450 + (idx - 1) * 90
		local sz = 315 + (idx % 2) * 55
		local sh = 85 + ((idx * 37) % 105)
		buildCityBuilding(parent, "SouthTower_" .. idx, Vector3.new(sx, 0, sz), 48, 48, sh, buildingPalette[(idx % 4) + 1], if idx % 2 == 0 then Color3.fromRGB(255, 214, 140) else Color3.fromRGB(148, 212, 250))
	end
end

local function buildServiceCorridorAndHideout(
	decorParent: Instance,
	coverParent: Instance
): ({ WorkbenchStation }, ProximityPrompt, ProximityPrompt, ProximityPrompt)
	-- Flush non-overlapping floor slabs (top Y = 0.4)
	makePart(decorParent, "CorridorFloor", Vector3.new(66, 0.4, 37), CFrame.new(0, 0.2, 83.5), Color3.fromRGB(52, 56, 66), Enum.Material.DiamondPlate, true)
	makePart(decorParent, "HideoutFloor", Vector3.new(134, 0.4, 59), CFrame.new(0, 0.2, 131.5), Color3.fromRGB(40, 44, 52), Enum.Material.Concrete, true)

	makePart(decorParent, "CorridorEdgeW", Vector3.new(1.2, 0.08, 34), CFrame.new(-32.2, 0.44, 83.8), Color3.fromRGB(232, 178, 44), Enum.Material.SmoothPlastic, false)
	makePart(decorParent, "CorridorEdgeE", Vector3.new(1.2, 0.08, 34), CFrame.new(32.2, 0.44, 83.8), Color3.fromRGB(232, 178, 44), Enum.Material.SmoothPlastic, false)
	makePart(decorParent, "SafeZoneLine", Vector3.new(24, 0.12, 1.2), CFrame.new(0, 0.44, 102), Color3.fromRGB(68, 255, 156), Enum.Material.Neon, false)
	for idx = 1, 3 do
		makePart(decorParent, "EscapeArrow_" .. idx, Vector3.new(4.5, 0.1, 2.2), CFrame.new(0, 0.44, 72 + idx * 8), Color3.fromRGB(68, 255, 156), Enum.Material.Neon, false, 0.25)
	end

	-- Service Corridor Walls strictly trimmed between Z = 66.6 and Z = 101.0 (zero overlap with Hideout brick wall or Staff Portal!)
	makePart(coverParent, "CorridorWallW", Vector3.new(2, HIDEOUT_CEILING_Y, 34.4), CFrame.new(-34, HIDEOUT_CEILING_Y * 0.5, 83.8), Color3.fromRGB(68, 72, 82), Enum.Material.Concrete, true)
	makePart(coverParent, "CorridorWallE", Vector3.new(2, HIDEOUT_CEILING_Y, 34.4), CFrame.new(34, HIDEOUT_CEILING_Y * 0.5, 83.8), Color3.fromRGB(68, 72, 82), Enum.Material.Concrete, true)
	makePart(coverParent, "CorridorCeiling", Vector3.new(70, 1.2, 34.4), CFrame.new(0, HIDEOUT_CEILING_Y + 0.6, 83.8), Color3.fromRGB(48, 52, 60), Enum.Material.Concrete, true)

	-- Staff-Only Maintenance Portal at Z = 65.5 (Y = 0..14 side jambs, Y = 14..18 header — zero Z-fighting!)
	makePart(coverParent, "StaffPortalL", Vector3.new(19, 14, 2.2), CFrame.new(-25.5, 7, 65.5), Color3.fromRGB(54, 60, 72), Enum.Material.Concrete, true)
	makePart(coverParent, "StaffPortalR", Vector3.new(19, 14, 2.2), CFrame.new(25.5, 7, 65.5), Color3.fromRGB(54, 60, 72), Enum.Material.Concrete, true)
	makePart(coverParent, "StaffPortalHeader", Vector3.new(70, 4.0, 2.2), CFrame.new(0, 16.0, 65.5), Color3.fromRGB(38, 44, 56), Enum.Material.Metal, true)
	makeSignBoard(
		decorParent,
		"StaffDoorSign",
		Vector3.new(28, 3.0, 0.45),
		CFrame.new(0, 15.8, 66.85),
		Color3.fromRGB(24, 28, 38),
		"AUTHORIZED STAFF CORRIDOR B2",
		Color3.fromRGB(255, 198, 62),
		"BASEMENT MAINTENANCE • HIDEOUT ACCESS",
		Enum.NormalId.Front,
		true
	)

	for _, zBeam in ipairs({ 74, 84, 94 }) do
		makePart(decorParent, "CorridorBeam_" .. zBeam, Vector3.new(66, 1.0, 1.2), CFrame.new(0, HIDEOUT_CEILING_Y - 0.5, zBeam), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, true)
		buildIndustrialCageLight(decorParent, "CorridorLight_" .. zBeam, Vector3.new(0, HIDEOUT_CEILING_Y - 1.0, zBeam), 1.4)
	end
	buildVentDuct(decorParent, "CorridorHVAC", Vector3.new(-26, 15.6, 68), Vector3.new(-26, 15.6, 100), HIDEOUT_CEILING_Y - 0.2, 3.6, 2.2)

	for _, hPipe in ipairs({ 6.5, 7.6 }) do
		makePart(decorParent, "CorridorPipeW_" .. hPipe, Vector3.new(0.4, 0.4, 33), CFrame.new(-32.8, hPipe, 83.8), Color3.fromRGB(168, 102, 58), Enum.Material.Metal, false)
	end

	-- Terminal Pass Kiosk rotated 90 deg so desk & sign face perpendicular into the middle of the corridor (-X)
	local kioskOrigin = CFrame.new(28, 0.4, 84) * CFrame.Angles(0, math.pi * 0.5, 0)
	local kiosk = makePart(decorParent, "TerminalPassKiosk", Vector3.new(6.8, 4.0, 3.2), kioskOrigin * CFrame.new(0, 2.0, 0), Color3.fromRGB(34, 42, 60), Enum.Material.Metal, true)
	makePart(decorParent, "KioskPostL", Vector3.new(0.45, 3.2, 0.45), kioskOrigin * CFrame.new(-2.8, 5.6, 0), Color3.fromRGB(140, 150, 166), Enum.Material.Metal, false)
	makePart(decorParent, "KioskPostR", Vector3.new(0.45, 3.2, 0.45), kioskOrigin * CFrame.new(2.8, 5.6, 0), Color3.fromRGB(140, 150, 166), Enum.Material.Metal, false)
	makeSignBoard(
		decorParent,
		"TerminalKioskSign",
		Vector3.new(7.4, 2.8, 0.42),
		kioskOrigin * CFrame.new(0, 7.2, 0),
		Color3.fromRGB(18, 24, 38),
		"TERMINAL PASSES",
		Color3.fromRGB(255, 206, 72),
		"UNLOCK HIGHER-TIER WINGS",
		Enum.NormalId.Front,
		true
	)
	local terminalKioskPrompt = Instance.new("ProximityPrompt")
	terminalKioskPrompt.Name = "OpenTerminalsPrompt"
	terminalKioskPrompt.ActionText = "Terminal Passes"
	terminalKioskPrompt.ObjectText = "SkyPort Access Desk"
	terminalKioskPrompt.KeyboardKeyCode = Enum.KeyCode.E
	terminalKioskPrompt.HoldDuration = 0
	terminalKioskPrompt.MaxActivationDistance = 12
	terminalKioskPrompt.RequiresLineOfSight = false
	terminalKioskPrompt.Parent = kiosk

	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "CourtyardSpawn"
	spawnLoc.Size = Vector3.new(10, 0.5, 10)
	spawnLoc.CFrame = CFrame.new(0, 0.25, 94)
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(48, 56, 70)
	spawnLoc.Material = Enum.Material.SmoothPlastic
	spawnLoc.Parent = decorParent

	-- Hideout Brick Walls (clean butt joints, zero overlap with CorridorWallW/E or HideoutCeilingSlab!)
	makePart(coverParent, "HideoutWallNL", Vector3.new(57, HIDEOUT_CEILING_Y, 2), CFrame.new(-40.5, HIDEOUT_CEILING_Y * 0.5, 102), Color3.fromRGB(78, 56, 50), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutWallNR", Vector3.new(57, HIDEOUT_CEILING_Y, 2), CFrame.new(40.5, HIDEOUT_CEILING_Y * 0.5, 102), Color3.fromRGB(78, 56, 50), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutArchHeader", Vector3.new(24, 5.5, 2.2), CFrame.new(0, 15.25, 102), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, true)
	makeSignBoard(
		decorParent,
		"HideoutSign",
		Vector3.new(22, 3.2, 0.5),
		CFrame.new(0, 14.4, 100.65),
		Color3.fromRGB(16, 20, 28),
		"SMUGGLER'S HIDEOUT",
		Color3.fromRGB(72, 255, 162),
		"SAFE ZONE • SECURE & CRACK STOLEN BAGS",
		Enum.NormalId.Front,
		true
	)
	makePart(coverParent, "HideoutWallS", Vector3.new(138, HIDEOUT_CEILING_Y, 2), CFrame.new(0, HIDEOUT_CEILING_Y * 0.5, 162), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutWallW", Vector3.new(2, HIDEOUT_CEILING_Y, 58), CFrame.new(-68, HIDEOUT_CEILING_Y * 0.5, 132), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutWallE", Vector3.new(2, HIDEOUT_CEILING_Y, 58), CFrame.new(68, HIDEOUT_CEILING_Y * 0.5, 132), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)

	-- Hideout Concrete Ceiling Slab sitting flush at Y = 18.0..19.2
	makePart(coverParent, "HideoutCeilingSlab", Vector3.new(138, 1.2, 62), CFrame.new(0, HIDEOUT_CEILING_Y + 0.6, 132), Color3.fromRGB(44, 48, 56), Enum.Material.Concrete, true)
	for _, xBeam in ipairs({ -46, -16, 16, 46 }) do
		makePart(decorParent, "HideoutSteelBeam_" .. xBeam, Vector3.new(1.8, 1.2, 58), CFrame.new(xBeam, HIDEOUT_CEILING_Y - 0.6, 132), Color3.fromRGB(32, 36, 44), Enum.Material.Metal, true)
		buildIndustrialCageLight(decorParent, "HideoutLightN_" .. xBeam, Vector3.new(xBeam, HIDEOUT_CEILING_Y - 1.2, 118), 1.4)
		buildIndustrialCageLight(decorParent, "HideoutLightS_" .. xBeam, Vector3.new(xBeam, HIDEOUT_CEILING_Y - 1.2, 146), 1.4)
	end
	buildVentDuct(decorParent, "HideoutMainHVAC", Vector3.new(-60, 15.6, 112), Vector3.new(60, 15.6, 112), HIDEOUT_CEILING_Y - 0.2, 4.0, 2.4)
	buildVentDuct(decorParent, "HideoutSouthHVAC", Vector3.new(-60, 15.6, 152), Vector3.new(24, 15.6, 152), HIDEOUT_CEILING_Y - 0.2, 3.2, 2.0)

	-- Industrial Storage Shelving neatly along the South Hideout wall
	buildStorageShelf(decorParent, "HideoutShelfS1", Vector3.new(-46, 0, 158.5), 0)
	buildStorageShelf(decorParent, "HideoutShelfS2", Vector3.new(-16, 0, 158.5), 0)
	buildStorageShelf(decorParent, "HideoutShelfS3", Vector3.new(16, 0, 158.5), 0)
	buildStorageShelf(decorParent, "HideoutShelfS4", Vector3.new(46, 0, 158.5), 0)

	-- 4 Grounded Cracking Workbenches in a symmetric 2x2 grid rotated exact +-90 degrees toward the center aisle!
	-- Workbench_1 is front-most closest to the Hideout entrance archway (Z = 102) on the left column.
	local workbenches: { WorkbenchStation } = {}
	local benchConfigs = {
		{ pos = Vector3.new(-22, 0, 118), yaw = -math.pi * 0.5 }, -- #1 Front-Left facing East (+X) toward center aisle
		{ pos = Vector3.new(22, 0, 118), yaw = math.pi * 0.5 },   -- #2 Front-Right facing West (-X) toward center aisle
		{ pos = Vector3.new(-22, 0, 136), yaw = -math.pi * 0.5 }, -- #3 Back-Left facing East (+X) toward center aisle
		{ pos = Vector3.new(22, 0, 136), yaw = math.pi * 0.5 },   -- #4 Back-Right facing West (-X) toward center aisle
	}
	for i, cfg in ipairs(benchConfigs) do
		table.insert(workbenches, buildWorkbench(decorParent, i, cfg.pos, cfg.yaw))
	end

	-- Shady Fence Sell Counter on East side (exact +90 deg) facing straight West (-X) toward the center aisle
	local fenceModel = Instance.new("Model")
	fenceModel.Name = "FenceCounter"
	fenceModel.Parent = decorParent
	local fenceYaw = math.pi * 0.5
	local fenceOrigin = CFrame.new(54, 0.4, 132) * CFrame.Angles(0, fenceYaw, 0)
	local fenceDesk = makePart(fenceModel, "CounterDesk", Vector3.new(14, 3.6, 4.2), fenceOrigin * CFrame.new(0, 1.8, 0), Color3.fromRGB(76, 50, 36), Enum.Material.Wood, true)
	makePart(fenceModel, "CounterTrim", Vector3.new(14.2, 0.35, 4.4), fenceOrigin * CFrame.new(0, 3.7, 0), Color3.fromRGB(255, 198, 62), Enum.Material.Metal, true)
	makePart(fenceModel, "FencePostL", Vector3.new(0.4, 5.4, 0.4), fenceOrigin * CFrame.new(-5.8, 6.4, 0), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makePart(fenceModel, "FencePostR", Vector3.new(0.4, 5.4, 0.4), fenceOrigin * CFrame.new(5.8, 6.4, 0), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makeSignBoard(
		fenceModel,
		"FenceSign",
		Vector3.new(12.6, 2.6, 0.5),
		fenceOrigin * CFrame.new(0, 8.8, 0),
		Color3.fromRGB(24, 20, 30),
		"VINNIE'S FENCE",
		Color3.fromRGB(255, 206, 68),
		"SELL REVEALED LOOT FOR CASH",
		Enum.NormalId.Front,
		true
	)
	local fenceNpcPos = (fenceOrigin * CFrame.new(0, 0, 3.6)).Position
	buildStylizedNPC(
		fenceModel,
		"FenceNPC",
		fenceNpcPos,
		fenceYaw,
		Color3.fromRGB(54, 34, 62),
		Color3.fromRGB(255, 196, 62),
		Color3.fromRGB(32, 30, 36),
		Color3.fromRGB(255, 196, 62),
		Color3.fromRGB(224, 182, 152),
		Color3.fromRGB(48, 38, 36),
		"Glasses"
	)
	local fencePrompt = Instance.new("ProximityPrompt")
	fencePrompt.Name = "SellLootPrompt"
	fencePrompt.ActionText = "Sell Revealed Loot"
	fencePrompt.ObjectText = "Vinnie the Fence"
	fencePrompt.KeyboardKeyCode = Enum.KeyCode.E
	fencePrompt.HoldDuration = 0
	fencePrompt.MaxActivationDistance = 14
	fencePrompt.RequiresLineOfSight = false
	fencePrompt.Parent = fenceDesk

	-- Black-Market Stealth & Tools Shop Kiosk on opposite West side (exact -90 deg) facing straight East (+X) toward center aisle
	local shopModel = Instance.new("Model")
	shopModel.Name = "StealthShopKiosk"
	shopModel.Parent = decorParent
	local shopYaw = -math.pi * 0.5
	local shopOrigin = CFrame.new(-54, 0.4, 132) * CFrame.Angles(0, shopYaw, 0)
	local shopCounter = makePart(shopModel, "ShopCounter", Vector3.new(14, 3.6, 4.2), shopOrigin * CFrame.new(0, 1.8, 0), Color3.fromRGB(32, 44, 62), Enum.Material.Metal, true)
	makePart(shopModel, "ShopNeon", Vector3.new(14.2, 0.35, 4.4), shopOrigin * CFrame.new(0, 3.7, 0), Color3.fromRGB(74, 208, 255), Enum.Material.Neon, false)
	makePart(shopModel, "ShopPostL", Vector3.new(0.4, 5.4, 0.4), shopOrigin * CFrame.new(-5.8, 6.4, 0), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makePart(shopModel, "ShopPostR", Vector3.new(0.4, 5.4, 0.4), shopOrigin * CFrame.new(5.8, 6.4, 0), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makeSignBoard(
		shopModel,
		"ShopSign",
		Vector3.new(12.6, 2.6, 0.5),
		shopOrigin * CFrame.new(0, 8.8, 0),
		Color3.fromRGB(16, 22, 36),
		"BLACK-MARKET GEAR",
		Color3.fromRGB(78, 224, 255),
		"TOOLS • SNEAKERS • STEALTH COATS • GADGETS",
		Enum.NormalId.Front,
		true
	)
	local shopNpcPos = (shopOrigin * CFrame.new(0, 0, 3.6)).Position
	buildStylizedNPC(
		shopModel,
		"QuartermasterNPC",
		shopNpcPos,
		shopYaw,
		Color3.fromRGB(26, 32, 42),
		Color3.fromRGB(72, 220, 255),
		Color3.fromRGB(44, 52, 66),
		Color3.fromRGB(72, 220, 255),
		Color3.fromRGB(192, 146, 114),
		Color3.fromRGB(28, 28, 34),
		"Beret"
	)
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "OpenShopPrompt"
	shopPrompt.ActionText = "Open Black-Market Shop"
	shopPrompt.ObjectText = "Gear, Tools & Gadgets"
	shopPrompt.KeyboardKeyCode = Enum.KeyCode.E
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 14
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopCounter

	return workbenches, fencePrompt, shopPrompt, terminalKioskPrompt
end

function WorldBuilder.Build(): WorldRefs
	local existing = Workspace:FindFirstChild("AirportWorld")
	if existing then
		existing:Destroy()
	end

	configureLighting()

	local root = Instance.new("Folder")
	root.Name = "AirportWorld"
	root.Parent = Workspace

	local opaqueCover = Instance.new("Folder")
	opaqueCover.Name = "OpaqueCover"
	opaqueCover.Parent = root

	local windows = Instance.new("Folder")
	windows.Name = "Windows"
	windows.Parent = root

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = root

	local bagsFolder = Instance.new("Folder")
	bagsFolder.Name = "Luggage"
	bagsFolder.Parent = root

	local passengersFolder = Instance.new("Folder")
	passengersFolder.Name = "Passengers"
	passengersFolder.Parent = root

	local guardsFolder = Instance.new("Folder")
	guardsFolder.Name = "SecurityGuards"
	guardsFolder.Parent = root

	local effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "ActiveEffects"
	effectsFolder.Parent = root

	-----------------------------------------------------------------------
	-- 1. EXTERIOR RUNWAYS, PLANES, SKYLINE & HIDEOUT ACCESS
	-----------------------------------------------------------------------
	buildExteriorTarmacAndSkyline(decor)
	local workbenches, fencePrompt, shopPrompt, terminalKioskPrompt = buildServiceCorridorAndHideout(decor, opaqueCover)

	-----------------------------------------------------------------------
	-- 2. LUXURY AIRPORT FLOORS & BRASS INLAY PATTERNS
	-----------------------------------------------------------------------
	makePart(decor, "Floor_Domestic", Vector3.new(172, 0.4, 123), CFrame.new(0, 0.2, 3.5), GameConfig.TERMINALS.Domestic.floorColor, Enum.Material.Marble, true)
	makePart(decor, "Floor_International", Vector3.new(122, 0.4, 123), CFrame.new(-147, 0.2, 3.5), GameConfig.TERMINALS.International.floorColor, Enum.Material.Marble, true)
	makePart(decor, "Floor_FirstClass", Vector3.new(122, 0.4, 123), CFrame.new(147, 0.2, 3.5), GameConfig.TERMINALS.FirstClass.floorColor, Enum.Material.Fabric, true)
	makePart(decor, "Floor_Celebrity", Vector3.new(232, 0.4, 136), CFrame.new(0, 0.2, -126), GameConfig.TERMINALS.Celebrity.floorColor, Enum.Material.Marble, true)

	makePart(decor, "DomCenterPromenade", Vector3.new(16, 0.04, 120), CFrame.new(0, 0.42, 3.5), Color3.fromRGB(228, 232, 240), Enum.Material.Marble, false)
	makePart(decor, "DomBrassInlayW", Vector3.new(0.45, 0.06, 120), CFrame.new(-8.2, 0.43, 3.5), Color3.fromRGB(206, 166, 72), Enum.Material.Metal, false)
	makePart(decor, "DomBrassInlayE", Vector3.new(0.45, 0.06, 120), CFrame.new(8.2, 0.43, 3.5), Color3.fromRGB(206, 166, 72), Enum.Material.Metal, false)
	makePart(decor, "IntlBrassInlay", Vector3.new(112, 0.05, 0.55), CFrame.new(-147, 0.42, 4.5), Color3.fromRGB(198, 162, 74), Enum.Material.Metal, false)
	makePart(decor, "VipGoldWalkway", Vector3.new(108, 0.05, 8.5), CFrame.new(147, 0.42, -2), Color3.fromRGB(206, 168, 72), Enum.Material.Marble, false)
	makePart(decor, "CelebrityRedCarpet", Vector3.new(18, 0.06, 128), CFrame.new(0, 0.43, -126), Color3.fromRGB(168, 24, 48), Enum.Material.Fabric, false)
	makePart(decor, "CelebrityBrassL", Vector3.new(0.5, 0.07, 128), CFrame.new(-9.3, 0.43, -126), Color3.fromRGB(224, 182, 72), Enum.Material.Metal, false)
	makePart(decor, "CelebrityBrassR", Vector3.new(0.5, 0.07, 128), CFrame.new(9.3, 0.43, -126), Color3.fromRGB(224, 182, 72), Enum.Material.Metal, false)

	-----------------------------------------------------------------------
	-- 3. COMPLETE ENCLOSED PERIMETER CURTAIN WALLS, DIVIDING WALLS & ROOF
	-----------------------------------------------------------------------
	buildCurtainWallBay(opaqueCover, windows, "SouthCurtainW", Vector3.new(-208, 0, 65), Vector3.new(-35, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(54, 62, 76), Color3.fromRGB(156, 206, 236))
	buildCurtainWallBay(opaqueCover, windows, "SouthCurtainE", Vector3.new(35, 0, 65), Vector3.new(208, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(54, 62, 76), Color3.fromRGB(156, 206, 236))
	buildCurtainWallBay(opaqueCover, windows, "SouthCenterClerestory", Vector3.new(-35, 0, 65), Vector3.new(35, 0, 65), 18.0, AIRPORT_ROOF_Y, 0, Color3.fromRGB(38, 44, 56), Color3.fromRGB(156, 206, 236))

	-- Mounted directly onto the front outward-facing gold fascia beam of DomMainMezz facing the ground-floor concourse (-Z)
	makePart(decor, "MarqueeMountL", Vector3.new(0.8, 0.9, 1.0), CFrame.new(-14, 11.5, 45.95), Color3.fromRGB(46, 52, 64), Enum.Material.Metal, false)
	makePart(decor, "MarqueeMountR", Vector3.new(0.8, 0.9, 1.0), CFrame.new(14, 11.5, 45.95), Color3.fromRGB(46, 52, 64), Enum.Material.Metal, false)
	makeSignBoard(
		decor,
		"MainAirportMarquee",
		Vector3.new(38, 3.6, 0.65),
		CFrame.new(0, 11.5, 45.45),
		Color3.fromRGB(16, 22, 34),
		"SKYPORT INTERNATIONAL",
		Color3.fromRGB(82, 206, 255),
		"DOMESTIC • INTERNATIONAL • FIRST-CLASS • CELEBRITY",
		Enum.NormalId.Front,
		false
	)

	buildCurtainWallBay(opaqueCover, windows, "WestOuterCurtain", Vector3.new(-208, 0, -58), Vector3.new(-208, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(204, 210, 218), Color3.fromRGB(164, 212, 240))
	buildCurtainWallBay(opaqueCover, windows, "EastOuterCurtain", Vector3.new(208, 0, -58), Vector3.new(208, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(48, 50, 68), Color3.fromRGB(142, 186, 224))
	buildCurtainWallBay(opaqueCover, windows, "NorthCurtainIntl", Vector3.new(-208, 0, -58), Vector3.new(-116, 0, -58), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(198, 204, 214), Color3.fromRGB(164, 212, 240))
	buildCurtainWallBay(opaqueCover, windows, "NorthCurtainVip", Vector3.new(116, 0, -58), Vector3.new(208, 0, -58), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(48, 50, 68), Color3.fromRGB(142, 186, 224))
	buildCurtainWallBay(opaqueCover, windows, "CelebNorthCurtain", Vector3.new(-116, 0, -194), Vector3.new(116, 0, -194), 0, AIRPORT_ROOF_Y, 3.4, Color3.fromRGB(32, 34, 42), Color3.fromRGB(168, 214, 244))
	buildCurtainWallBay(opaqueCover, windows, "CelebWestCurtain", Vector3.new(-116, 0, -194), Vector3.new(-116, 0, -58), 0, AIRPORT_ROOF_Y, 3.4, Color3.fromRGB(38, 40, 50), Color3.fromRGB(154, 198, 232))
	buildCurtainWallBay(opaqueCover, windows, "CelebEastCurtain", Vector3.new(116, 0, -194), Vector3.new(116, 0, -58), 0, AIRPORT_ROOF_Y, 3.4, Color3.fromRGB(38, 40, 50), Color3.fromRGB(154, 198, 232))

	makePart(opaqueCover, "CelebritySouthW", Vector3.new(102, AIRPORT_ROOF_Y, 2), CFrame.new(-65, AIRPORT_ROOF_Y * 0.5, -58), Color3.fromRGB(42, 44, 56), Enum.Material.Concrete, true)
	makePart(opaqueCover, "CelebritySouthE", Vector3.new(102, AIRPORT_ROOF_Y, 2), CFrame.new(65, AIRPORT_ROOF_Y * 0.5, -58), Color3.fromRGB(42, 44, 56), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomIntl_N", Vector3.new(2, AIRPORT_ROOF_Y, 37), CFrame.new(-86, AIRPORT_ROOF_Y * 0.5, -39.5), Color3.fromRGB(220, 224, 230), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomIntl_S", Vector3.new(2, AIRPORT_ROOF_Y, 66), CFrame.new(-86, AIRPORT_ROOF_Y * 0.5, 32), Color3.fromRGB(220, 224, 230), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomVip_N", Vector3.new(2, AIRPORT_ROOF_Y, 37), CFrame.new(86, AIRPORT_ROOF_Y * 0.5, -39.5), Color3.fromRGB(54, 58, 76), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomVip_S", Vector3.new(2, AIRPORT_ROOF_Y, 66), CFrame.new(86, AIRPORT_ROOF_Y * 0.5, 32), Color3.fromRGB(54, 58, 76), Enum.Material.Concrete, true)

	buildRoofSection(decor, opaqueCover, windows, "IntlRoof", -208, -86, -58, 65, AIRPORT_ROOF_Y, Color3.fromRGB(226, 228, 232), Color3.fromRGB(64, 72, 84), GameConfig.TERMINALS.International.accentColor, true)
	buildRoofSection(decor, opaqueCover, windows, "DomRoof", -86, 86, -58, 65, AIRPORT_ROOF_Y, Color3.fromRGB(234, 238, 244), Color3.fromRGB(72, 80, 94), GameConfig.TERMINALS.Domestic.accentColor, true)
	buildRoofSection(decor, opaqueCover, windows, "VipRoof", 86, 208, -58, 65, AIRPORT_ROOF_Y, Color3.fromRGB(48, 52, 72), Color3.fromRGB(36, 40, 56), GameConfig.TERMINALS.FirstClass.accentColor, true)
	buildRoofSection(decor, opaqueCover, windows, "CelebRoof", -116, 116, -194, -58, AIRPORT_ROOF_Y, Color3.fromRGB(36, 34, 46), Color3.fromRGB(28, 28, 38), GameConfig.TERMINALS.Celebrity.accentColor, true)

	-----------------------------------------------------------------------
	-- 4. SECURITY TURNSTILE GATES
	-----------------------------------------------------------------------
	local gateBarriers: { [TerminalId]: BasePart } = {}
	local gatePrompts: { [TerminalId]: ProximityPrompt } = {}

	local intlBarrier, intlPrompt = buildSecurityGate(opaqueCover, windows, "International", Vector3.new(-86, 0, -11), 90, 20)
	gateBarriers.International = intlBarrier
	gatePrompts.International = intlPrompt

	local vipBarrier, vipPrompt = buildSecurityGate(opaqueCover, windows, "FirstClass", Vector3.new(86, 0, -11), -90, 20)
	gateBarriers.FirstClass = vipBarrier
	gatePrompts.FirstClass = vipPrompt

	local celebBarrier, celebPrompt = buildSecurityGate(opaqueCover, windows, "Celebrity", Vector3.new(0, 0, -58), 0, 28)
	gateBarriers.Celebrity = celebBarrier
	gatePrompts.Celebrity = celebPrompt

	-----------------------------------------------------------------------
	-- 5. INTERIOR DETAILS, PARALLEL DUAL ESCALATORS, MEZZANINES, FOOD STANDS & CAROUSELS
	-----------------------------------------------------------------------
	local carousels: { CarouselTrack } = {}
	local restingSpots: { RestingSpot } = {}

	-- DOMESTIC ATRIUM & CLAIM HALL
	makeSignBoard(
		decor,
		"DepartureBoard",
		Vector3.new(32, 7.5, 1.4),
		CFrame.new(0, 12.8, 24),
		Color3.fromRGB(16, 20, 30),
		"DEPARTURES  |  FLIGHT 402 ON TIME",
		Color3.fromRGB(255, 208, 64),
		"GATE A1 TOKYO • GATE B4 PARIS • GATE C9 ZURICH",
		Enum.NormalId.Front,
		true
	)
	makePart(opaqueCover, "BoardColL", Vector3.new(2.2, AIRPORT_ROOF_Y, 2.2), CFrame.new(-16, AIRPORT_ROOF_Y * 0.5, 24), Color3.fromRGB(156, 166, 180), Enum.Material.Metal, true)
	makePart(opaqueCover, "BoardColR", Vector3.new(2.2, AIRPORT_ROOF_Y, 2.2), CFrame.new(16, AIRPORT_ROOF_Y * 0.5, 24), Color3.fromRGB(156, 166, 180), Enum.Material.Metal, true)

	for _, deskX in ipairs({ -44, 44 }) do
		makePart(opaqueCover, "CheckInMarble_" .. deskX, Vector3.new(17, 3.8, 4.5), CFrame.new(deskX, 1.9, 44), Color3.fromRGB(238, 240, 244), Enum.Material.Marble, true)
		makePart(decor, "CheckInBrass_" .. deskX, Vector3.new(17.2, 0.35, 4.7), CFrame.new(deskX, 3.9, 44), Color3.fromRGB(204, 164, 72), Enum.Material.Metal, false)
	end

	for _, pPos in ipairs({
		Vector3.new(-24, 0, 42), Vector3.new(24, 0, 42),
		Vector3.new(-24, 0, 6), Vector3.new(24, 0, 6),
		Vector3.new(-66, 0, 10), Vector3.new(66, 0, 10),
	}) do
		buildPillar(opaqueCover, decor, "DomPillar", pPos, 1.8, AIRPORT_ROOF_Y, Color3.fromRGB(234, 238, 244), Color3.fromRGB(204, 166, 76))
	end

	for _, palmPos in ipairs({ Vector3.new(-20, 0, 56), Vector3.new(20, 0, 56), Vector3.new(0, 0, -40), Vector3.new(-76, 0, -34), Vector3.new(76, 0, -34) }) do
		buildPlanterBed(opaqueCover, decor, palmPos, GameConfig.TERMINALS.Domestic.accentColor)
	end

	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-44, 0, 12), 0, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(44, 0, 12), 0, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(0, 0, -6), 90, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-44, 0, -36), 180, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(44, 0, -36), 180, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))

	-- Decorative Fast-Food / Coffee Stand #1 in Domestic North-West alcove + airport amenities
	buildFoodStand(opaqueCover, decor, windows, "Cloud9Cafe", Vector3.new(-46, 0, -53), 180, "CLOUD 9 ESPRESSO", Color3.fromRGB(255, 168, 52), "COFFEE • PASTRIES • SANDWICHES")
	buildLuggageCartCorral(decor, opaqueCover, "DomCartsW", Vector3.new(-79, 0, 6), 90)
	buildLuggageCartCorral(decor, opaqueCover, "DomCartsE", Vector3.new(79, 0, 6), -90)
	buildTrashRecyclingStation(opaqueCover, decor, "DomBinsW", Vector3.new(-18, 0, 50), 0)
	buildTrashRecyclingStation(opaqueCover, decor, "DomBinsE", Vector3.new(18, 0, 50), 0)
	buildInfoKiosk(opaqueCover, decor, "DomInfo", Vector3.new(-15, 0, 34), 35, "TERMINAL MAP", GameConfig.TERMINALS.Domestic.accentColor)

	-- Domestic Grand Mezzanine & Side Skywalks (flush with perimeter/divider walls) + Parallel Dual Escalators
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"DomMainMezz",
		-85,
		85,
		46,
		64.6,
		12.0,
		Color3.fromRGB(218, 224, 232),
		Color3.fromRGB(198, 160, 72),
		{ N = true, S = true, W = false, E = false },
		{
			{ axis = "Z", minV = -85, maxV = -59, side = "N" },
			{ axis = "Z", minV = 59, maxV = 85, side = "N" },
		}
	)
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"DomSkywalkW",
		-85,
		-73,
		-57,
		46,
		12.0,
		Color3.fromRGB(218, 224, 232),
		Color3.fromRGB(198, 160, 72),
		{ N = true, S = false, W = false, E = true },
		nil
	)
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"DomSkywalkE",
		73,
		85,
		-57,
		46,
		12.0,
		Color3.fromRGB(218, 224, 232),
		Color3.fromRGB(198, 160, 72),
		{ N = true, S = false, W = true, E = false },
		nil
	)
	buildDualEscalator(decor, windows, "DomWest", Vector3.new(-66.5, 0.4, 22), Vector3.new(-66.5, 12.0, 46), 4.2, GameConfig.TERMINALS.Domestic.accentColor)
	buildDualEscalator(decor, windows, "DomEast", Vector3.new(66.5, 0.4, 22), Vector3.new(66.5, 12.0, 46), 4.2, GameConfig.TERMINALS.Domestic.accentColor)

	-- Domestic 2nd-floor Mezzanine seating, cover planters & upper-level passenger spots
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-34, 12.0, 58), 180, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(34, 12.0, 58), 180, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildPlanterBed(opaqueCover, decor, Vector3.new(-22, 12.0, 58), GameConfig.TERMINALS.Domestic.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(22, 12.0, 58), GameConfig.TERMINALS.Domestic.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(-79, 12.0, -14), GameConfig.TERMINALS.Domestic.accentColor, 3.6, 3.6)
	buildPlanterBed(opaqueCover, decor, Vector3.new(79, 12.0, -14), GameConfig.TERMINALS.Domestic.accentColor, 3.6, 3.6)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Claim 1", "Domestic", Vector3.new(-44, 0, -18), 18, 9, 6.2, GameConfig.TERMINALS.Domestic.accentColor))
	table.insert(carousels, buildCarousel(decor, opaqueCover, "Claim 2", "Domestic", Vector3.new(44, 0, -18), 18, 9, 6.2, GameConfig.TERMINALS.Domestic.accentColor))

	table.insert(restingSpots, { id = "DomSpot1", terminalId = "Domestic", bagPos = Vector3.new(-52, 0.4, 15), bagYaw = 0.2, ownerHomePos = Vector3.new(-44, 0.4, 16), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.48, patrolWaypoint = Vector3.new(-35, 0.4, 16) })
	table.insert(restingSpots, { id = "DomSpot2", terminalId = "Domestic", bagPos = Vector3.new(52, 0.4, 15), bagYaw = -0.3, ownerHomePos = Vector3.new(44, 0.4, 16), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.48, patrolWaypoint = Vector3.new(35, 0.4, 16) })
	table.insert(restingSpots, { id = "DomSpot3", terminalId = "Domestic", bagPos = Vector3.new(-38, 0.4, 41), bagYaw = 0, ownerHomePos = Vector3.new(-48, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = -math.pi * 0.55, patrolWaypoint = Vector3.new(-55, 0.4, 38) })
	table.insert(restingSpots, { id = "DomSpot4", terminalId = "Domestic", bagPos = Vector3.new(38, 0.4, 41), bagYaw = 0, ownerHomePos = Vector3.new(48, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.55, patrolWaypoint = Vector3.new(55, 0.4, 38) })
	table.insert(restingSpots, { id = "DomSpot5", terminalId = "Domestic", bagPos = Vector3.new(0, 0.4, -14), bagYaw = 0.5, ownerHomePos = Vector3.new(5, 0.4, -4), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = 0.4, patrolWaypoint = Vector3.new(6, 0.4, 6) })
	table.insert(restingSpots, { id = "DomMezzSpot1", terminalId = "Domestic", bagPos = Vector3.new(-44, 12.0, 56), bagYaw = 0.3, ownerHomePos = Vector3.new(-32, 12.0, 51), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.45, patrolWaypoint = Vector3.new(-10, 12.0, 51) })
	table.insert(restingSpots, { id = "DomMezzSpot2", terminalId = "Domestic", bagPos = Vector3.new(44, 12.0, 56), bagYaw = -0.3, ownerHomePos = Vector3.new(32, 12.0, 51), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.45, patrolWaypoint = Vector3.new(10, 12.0, 51) })
	table.insert(restingSpots, { id = "DomMezzSpot3", terminalId = "Domestic", bagPos = Vector3.new(-79, 12.0, -34), bagYaw = 0.1, ownerHomePos = Vector3.new(-79, 12.0, -24), ownerLookAwayYaw = -math.pi * 0.5, ownerWatchBagYaw = 0, patrolWaypoint = Vector3.new(-79, 12.0, -2) })

	-- INTERNATIONAL CONCOURSE
	makePart(opaqueCover, "DutyFreeIsland1", Vector3.new(20, 5.2, 10), CFrame.new(-174, 2.6, 26), Color3.fromRGB(142, 98, 62), Enum.Material.Wood, true)
	makePart(decor, "DutyFreeTrim1", Vector3.new(20.4, 0.35, 10.4), CFrame.new(-174, 5.25, 26), Color3.fromRGB(204, 168, 76), Enum.Material.Metal, false)
	makePart(opaqueCover, "DutyFreeIsland2", Vector3.new(20, 5.2, 10), CFrame.new(-120, 2.6, 26), Color3.fromRGB(64, 128, 114), Enum.Material.SmoothPlastic, true)
	makePart(decor, "DutyFreeTrim2", Vector3.new(20.4, 0.35, 10.4), CFrame.new(-120, 5.25, 26), Color3.fromRGB(204, 168, 76), Enum.Material.Metal, false)

	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"IntlMezz",
		-207.2,
		-104,
		48,
		64.6,
		11.5,
		Color3.fromRGB(198, 184, 158),
		Color3.fromRGB(68, 214, 152),
		{ N = true, S = true, W = false, E = true },
		{
			{ axis = "Z", minV = -203, maxV = -189, side = "N" },
		}
	)
	buildDualEscalator(decor, windows, "IntlWest", Vector3.new(-196, 0.4, 25), Vector3.new(-196, 11.5, 48), 4.2, GameConfig.TERMINALS.International.accentColor)
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-146, 11.5, 58), 180, Color3.fromRGB(48, 148, 108), Color3.fromRGB(204, 174, 92))
	buildPlanterBed(opaqueCover, decor, Vector3.new(-134, 11.5, 58), GameConfig.TERMINALS.International.accentColor)
	makeSignBoard(
		decor,
		"DutyFreeSign",
		Vector3.new(18, 3.0, 0.6),
		CFrame.new(-148, 13.6, 48.2),
		Color3.fromRGB(22, 32, 34),
		"INTERNATIONAL DUTY-FREE",
		GameConfig.TERMINALS.International.accentColor,
		"PASSPORT CONTROL & CUSTOMS",
		Enum.NormalId.Front,
		true
	)

	for _, pPos in ipairs({ Vector3.new(-186, 0, -40), Vector3.new(-112, 0, -40), Vector3.new(-148, 0, 10) }) do
		buildPillar(opaqueCover, decor, "IntlPillar", pPos, 1.8, AIRPORT_ROOF_Y, Color3.fromRGB(218, 206, 184), GameConfig.TERMINALS.International.accentColor)
	end
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-148, 0, 18), 0, Color3.fromRGB(48, 148, 108), Color3.fromRGB(204, 174, 92))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-168, 0, -42), 180, Color3.fromRGB(48, 148, 108), Color3.fromRGB(204, 174, 92))
	buildPlanterBed(opaqueCover, decor, Vector3.new(-184, 0, 40), GameConfig.TERMINALS.International.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(-106, 0, 40), GameConfig.TERMINALS.International.accentColor)

	-- Decorative Fast-Food Stand #2 along International East divider wall
	buildFoodStand(opaqueCover, decor, windows, "JetSetBites", Vector3.new(-91, 0, 32), 90, "JETSET SUSHI & BITES", GameConfig.TERMINALS.International.accentColor, "RAMEN • SUSHI • MATCHA")
	buildLuggageCartCorral(decor, opaqueCover, "IntlCarts", Vector3.new(-92, 0, -34), 90)
	buildTrashRecyclingStation(opaqueCover, decor, "IntlBins", Vector3.new(-148, 0, 42), 0)
	buildInfoKiosk(opaqueCover, decor, "IntlInfo", Vector3.new(-148, 0, 32), 0, "CUSTOMS GUIDE", GameConfig.TERMINALS.International.accentColor)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Intl Claim 3", "International", Vector3.new(-148, 0, -18), 22, 10, 7.2, GameConfig.TERMINALS.International.accentColor))

	table.insert(restingSpots, { id = "IntlSpot1", terminalId = "International", bagPos = Vector3.new(-164, 0.4, 24), bagYaw = 0.2, ownerHomePos = Vector3.new(-156, 0.4, 14), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = 0.4, patrolWaypoint = Vector3.new(-142, 0.4, 14) })
	table.insert(restingSpots, { id = "IntlSpot2", terminalId = "International", bagPos = Vector3.new(-132, 0.4, 24), bagYaw = -0.3, ownerHomePos = Vector3.new(-140, 0.4, 14), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -0.4, patrolWaypoint = Vector3.new(-126, 0.4, 10) })
	table.insert(restingSpots, { id = "IntlSpot3", terminalId = "International", bagPos = Vector3.new(-186, 0.4, 4), bagYaw = 1.1, ownerHomePos = Vector3.new(-180, 0.4, -6), ownerLookAwayYaw = -math.pi * 0.5, ownerWatchBagYaw = 0.35, patrolWaypoint = Vector3.new(-174, 0.4, -14) })
	table.insert(restingSpots, { id = "IntlSpot4", terminalId = "International", bagPos = Vector3.new(-124, 0.4, -44), bagYaw = 0, ownerHomePos = Vector3.new(-136, 0.4, -44), ownerLookAwayYaw = math.pi * 0.5, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(-152, 0.4, -44) })
	table.insert(restingSpots, { id = "IntlMezzSpot1", terminalId = "International", bagPos = Vector3.new(-168, 11.5, 56), bagYaw = 0.25, ownerHomePos = Vector3.new(-156, 11.5, 52), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.45, patrolWaypoint = Vector3.new(-138, 11.5, 52) })
	table.insert(restingSpots, { id = "IntlMezzSpot2", terminalId = "International", bagPos = Vector3.new(-114, 11.5, 56), bagYaw = -0.2, ownerHomePos = Vector3.new(-122, 11.5, 52), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.45, patrolWaypoint = Vector3.new(-144, 11.5, 51) })

	-- FIRST-CLASS VIP LOUNGE
	makePart(opaqueCover, "VipBarCounter", Vector3.new(22, 4.2, 6), CFrame.new(172, 2.1, 28), Color3.fromRGB(36, 28, 42), Enum.Material.Marble, true)
	makePart(decor, "VipBarGold", Vector3.new(22.2, 0.35, 6.2), CFrame.new(172, 4.3, 28), Color3.fromRGB(255, 198, 64), Enum.Material.Metal, false)
	makePart(opaqueCover, "VipDivider1", Vector3.new(16, 6.5, 1.4), CFrame.new(124, 3.25, 22), Color3.fromRGB(98, 68, 42), Enum.Material.Wood, true)
	makePart(opaqueCover, "VipDivider2", Vector3.new(16, 6.5, 1.4), CFrame.new(148, 3.25, -42), Color3.fromRGB(98, 68, 42), Enum.Material.Wood, true)

	buildVelvetRopeLine(decor, Vector3.new(158, 0, 22), Vector3.new(158, 0, 34), Color3.fromRGB(178, 30, 58))

	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"VipSkyLoft",
		104,
		207.2,
		46,
		64.6,
		11.5,
		Color3.fromRGB(58, 64, 96),
		Color3.fromRGB(255, 194, 64),
		{ N = true, S = true, W = true, E = false },
		{
			{ axis = "Z", minV = 189, maxV = 203, side = "N" },
		}
	)
	buildDualEscalator(decor, windows, "VipEast", Vector3.new(196, 0.4, 23), Vector3.new(196, 11.5, 46), 4.2, GameConfig.TERMINALS.FirstClass.accentColor)
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(146, 11.5, 57), 180, Color3.fromRGB(168, 128, 48), Color3.fromRGB(234, 194, 86))
	buildPlanterBed(opaqueCover, decor, Vector3.new(134, 11.5, 57), GameConfig.TERMINALS.FirstClass.accentColor)

	for _, pPos in ipairs({ Vector3.new(112, 0, -40), Vector3.new(186, 0, -40), Vector3.new(114, 0, 40) }) do
		buildPillar(opaqueCover, decor, "VipPillar", pPos, 1.8, AIRPORT_ROOF_Y, Color3.fromRGB(58, 64, 92), GameConfig.TERMINALS.FirstClass.accentColor)
	end
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(124, 0, 32), 0, Color3.fromRGB(168, 128, 48), Color3.fromRGB(234, 194, 86))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(172, 0, 12), 180, Color3.fromRGB(168, 128, 48), Color3.fromRGB(234, 194, 86))
	buildPlanterBed(opaqueCover, decor, Vector3.new(102, 0, 42), GameConfig.TERMINALS.FirstClass.accentColor)

	-- Decorative Fast-Food / Patisserie Stand #3 along VIP West divider wall
	buildFoodStand(opaqueCover, decor, windows, "SkylinePatisserie", Vector3.new(91, 0, 32), -90, "SKYLINE PATISSERIE", GameConfig.TERMINALS.FirstClass.accentColor, "ARTISAN PASTRY • CHAMPAGNE")
	buildLuggageCartCorral(decor, opaqueCover, "VipCarts", Vector3.new(92, 0, -34), -90)
	buildTrashRecyclingStation(opaqueCover, decor, "VipBins", Vector3.new(148, 0, 40), 0)
	buildInfoKiosk(opaqueCover, decor, "VipInfo", Vector3.new(148, 0, 10), 0, "VIP CONCIERGE", GameConfig.TERMINALS.FirstClass.accentColor)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "VIP Valet", "FirstClass", Vector3.new(148, 0, -18), 20, 9, 7.8, GameConfig.TERMINALS.FirstClass.accentColor))

	table.insert(restingSpots, { id = "VipSpot1", terminalId = "FirstClass", bagPos = Vector3.new(136, 0.4, 30), bagYaw = 0.2, ownerHomePos = Vector3.new(146, 0.4, 30), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(155, 0.4, 22) })
	table.insert(restingSpots, { id = "VipSpot2", terminalId = "FirstClass", bagPos = Vector3.new(164, 0.4, 38), bagYaw = -0.3, ownerHomePos = Vector3.new(176, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(186, 0.4, 34) })
	table.insert(restingSpots, { id = "VipSpot3", terminalId = "FirstClass", bagPos = Vector3.new(116, 0.4, -2), bagYaw = 0.8, ownerHomePos = Vector3.new(106, 0.4, 8), ownerLookAwayYaw = math.pi * 0.75, ownerWatchBagYaw = -math.pi * 0.75, patrolWaypoint = Vector3.new(106, 0.4, -18) })
	table.insert(restingSpots, { id = "VipSpot4", terminalId = "FirstClass", bagPos = Vector3.new(162, 0.4, -48), bagYaw = 0.1, ownerHomePos = Vector3.new(174, 0.4, -46), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(184, 0.4, -34) })
	table.insert(restingSpots, { id = "VipMezzSpot1", terminalId = "FirstClass", bagPos = Vector3.new(168, 11.5, 55), bagYaw = -0.25, ownerHomePos = Vector3.new(156, 11.5, 51), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.45, patrolWaypoint = Vector3.new(138, 11.5, 51) })
	table.insert(restingSpots, { id = "VipMezzSpot2", terminalId = "FirstClass", bagPos = Vector3.new(114, 11.5, 55), bagYaw = 0.2, ownerHomePos = Vector3.new(122, 11.5, 51), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.45, patrolWaypoint = Vector3.new(144, 11.5, 50) })

	-- CELEBRITY PRIVATE TERMINAL
	makePart(decor, "CelebBoardHangerL", Vector3.new(0.45, AIRPORT_ROOF_Y - 12, 0.45), CFrame.new(-10, 12 + (AIRPORT_ROOF_Y - 12) * 0.5, -186), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	makePart(decor, "CelebBoardHangerR", Vector3.new(0.45, AIRPORT_ROOF_Y - 12, 0.45), CFrame.new(10, 12 + (AIRPORT_ROOF_Y - 12) * 0.5, -186), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	makeSignBoard(
		decor,
		"CelebrityBoard",
		Vector3.new(28, 6.2, 1.2),
		CFrame.new(0, 12, -186),
		Color3.fromRGB(22, 18, 30),
		"PRIVATE JET BOARDING",
		GameConfig.TERMINALS.Celebrity.accentColor,
		"ROYAL & BILLIONAIRE CONCOURSE",
		Enum.NormalId.Front,
		true
	)

	for _, pPos in ipairs({
		Vector3.new(-36, 0, -90), Vector3.new(36, 0, -90),
		Vector3.new(-36, 0, -158), Vector3.new(36, 0, -158),
		Vector3.new(-80, 0, -124), Vector3.new(80, 0, -124),
	}) do
		buildPillar(opaqueCover, decor, "CelebPillar", pPos, 2.0, AIRPORT_ROOF_Y, Color3.fromRGB(48, 44, 60), GameConfig.TERMINALS.Celebrity.accentColor)
	end

	buildVelvetRopeLine(decor, Vector3.new(-10.5, 0, -76), Vector3.new(-10.5, 0, -104), Color3.fromRGB(198, 28, 64))
	buildVelvetRopeLine(decor, Vector3.new(10.5, 0, -76), Vector3.new(10.5, 0, -104), Color3.fromRGB(198, 28, 64))

	makePart(opaqueCover, "CelebBoothW", Vector3.new(14, 5.8, 4), CFrame.new(-64, 2.9, -98), Color3.fromRGB(64, 24, 58), Enum.Material.Marble, true)
	makePart(opaqueCover, "CelebBoothE", Vector3.new(14, 5.8, 4), CFrame.new(64, 2.9, -98), Color3.fromRGB(64, 24, 58), Enum.Material.Marble, true)
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-64, 0, -148), 0, Color3.fromRGB(182, 42, 112), Color3.fromRGB(238, 198, 76))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(64, 0, -148), 0, Color3.fromRGB(182, 42, 112), Color3.fromRGB(238, 198, 76))
	buildPlanterBed(opaqueCover, decor, Vector3.new(-24, 0, -178), GameConfig.TERMINALS.Celebrity.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(24, 0, -178), GameConfig.TERMINALS.Celebrity.accentColor)
	buildTrashRecyclingStation(opaqueCover, decor, "CelebBinsW", Vector3.new(-24, 0, -76), 180)
	buildTrashRecyclingStation(opaqueCover, decor, "CelebBinsE", Vector3.new(24, 0, -76), 180)
	buildInfoKiosk(opaqueCover, decor, "CelebInfo", Vector3.new(-16, 0, -150), 20, "PRIVATE CHARTER", GameConfig.TERMINALS.Celebrity.accentColor)

	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"CelebSouthTerrace",
		-115,
		115,
		-80,
		-59,
		11.5,
		Color3.fromRGB(48, 36, 56),
		Color3.fromRGB(255, 86, 152),
		{ N = true, S = true, W = false, E = false },
		{
			{ axis = "Z", minV = -115, maxV = -85, side = "N" },
			{ axis = "Z", minV = 85, maxV = 115, side = "N" },
		}
	)
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"CelebJetWalkW",
		-115,
		-100,
		-193,
		-80,
		11.5,
		Color3.fromRGB(48, 36, 56),
		Color3.fromRGB(255, 86, 152),
		{ N = true, S = false, W = false, E = true },
		nil
	)
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"CelebJetWalkE",
		100,
		115,
		-193,
		-80,
		11.5,
		Color3.fromRGB(48, 36, 56),
		Color3.fromRGB(255, 86, 152),
		{ N = true, S = false, W = true, E = false },
		nil
	)
	buildDualEscalator(decor, windows, "CelebWest", Vector3.new(-92, 0.4, -104), Vector3.new(-92, 11.5, -80), 4.0, GameConfig.TERMINALS.Celebrity.accentColor)
	buildDualEscalator(decor, windows, "CelebEast", Vector3.new(92, 0.4, -104), Vector3.new(92, 11.5, -80), 4.0, GameConfig.TERMINALS.Celebrity.accentColor)

	-- Celebrity 2nd-floor terrace lounge seating, cover planters & upper-level VIP spots
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-38, 11.5, -67), 0, Color3.fromRGB(182, 42, 112), Color3.fromRGB(238, 198, 76))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(38, 11.5, -67), 0, Color3.fromRGB(182, 42, 112), Color3.fromRGB(238, 198, 76))
	buildPlanterBed(opaqueCover, decor, Vector3.new(-20, 11.5, -69), GameConfig.TERMINALS.Celebrity.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(20, 11.5, -69), GameConfig.TERMINALS.Celebrity.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(-107, 11.5, -136), GameConfig.TERMINALS.Celebrity.accentColor, 3.6, 3.6)
	buildPlanterBed(opaqueCover, decor, Vector3.new(107, 11.5, -136), GameConfig.TERMINALS.Celebrity.accentColor, 3.6, 3.6)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Royal Valet", "Celebrity", Vector3.new(0, 0, -126), 24, 11, 8.6, GameConfig.TERMINALS.Celebrity.accentColor))

	table.insert(restingSpots, { id = "CelebSpot1", terminalId = "Celebrity", bagPos = Vector3.new(-54, 0.4, -108), bagYaw = 0.2, ownerHomePos = Vector3.new(-44, 0.4, -108), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(-44, 0.4, -128) })
	table.insert(restingSpots, { id = "CelebSpot2", terminalId = "Celebrity", bagPos = Vector3.new(54, 0.4, -108), bagYaw = -0.2, ownerHomePos = Vector3.new(44, 0.4, -108), ownerLookAwayYaw = 0, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(44, 0.4, -128) })
	table.insert(restingSpots, { id = "CelebSpot3", terminalId = "Celebrity", bagPos = Vector3.new(-74, 0.4, -158), bagYaw = 0.4, ownerHomePos = Vector3.new(-62, 0.4, -160), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(-50, 0.4, -162) })
	table.insert(restingSpots, { id = "CelebSpot4", terminalId = "Celebrity", bagPos = Vector3.new(74, 0.4, -158), bagYaw = -0.4, ownerHomePos = Vector3.new(62, 0.4, -160), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(50, 0.4, -162) })
	table.insert(restingSpots, { id = "CelebMezzSpot1", terminalId = "Celebrity", bagPos = Vector3.new(-58, 11.5, -69), bagYaw = 0.2, ownerHomePos = Vector3.new(-46, 11.5, -69), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(-26, 11.5, -72) })
	table.insert(restingSpots, { id = "CelebMezzSpot2", terminalId = "Celebrity", bagPos = Vector3.new(58, 11.5, -69), bagYaw = -0.2, ownerHomePos = Vector3.new(46, 11.5, -69), ownerLookAwayYaw = 0, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(26, 11.5, -72) })

	-----------------------------------------------------------------------
	-- 6. SECURITY PATROL ROUTES
	-----------------------------------------------------------------------
	local guardRoutes: { GuardRoute } = {
		{
			id = "Guard_Domestic",
			terminalId = "Domestic",
			waypoints = {
				Vector3.new(-20, 0.4, 34),
				Vector3.new(20, 0.4, 34),
				Vector3.new(20, 0.4, -2),
				Vector3.new(-20, 0.4, -2),
			},
			speed = 7.5,
			visionRange = 28,
			visionAngleDeg = 76,
		},
		{
			id = "Guard_International",
			terminalId = "International",
			waypoints = {
				Vector3.new(-174, 0.4, 8),
				Vector3.new(-122, 0.4, 8),
				Vector3.new(-122, 0.4, -38),
				Vector3.new(-174, 0.4, -38),
			},
			speed = 8.5,
			visionRange = 32,
			visionAngleDeg = 82,
		},
		{
			id = "Guard_FirstClass",
			terminalId = "FirstClass",
			waypoints = {
				Vector3.new(122, 0.4, 8),
				Vector3.new(174, 0.4, 8),
				Vector3.new(174, 0.4, -38),
				Vector3.new(122, 0.4, -38),
			},
			speed = 9.0,
			visionRange = 34,
			visionAngleDeg = 86,
		},
		{
			id = "Guard_Celebrity",
			terminalId = "Celebrity",
			waypoints = {
				Vector3.new(-32, 0.4, -84),
				Vector3.new(32, 0.4, -84),
				Vector3.new(32, 0.4, -164),
				Vector3.new(-32, 0.4, -164),
			},
			speed = 9.8,
			visionRange = 38,
			visionAngleDeg = 92,
		},
	}

	return {
		RootFolder = root,
		OpaqueCoverFolder = opaqueCover,
		WindowsFolder = windows,
		BagsFolder = bagsFolder,
		PassengersFolder = passengersFolder,
		GuardsFolder = guardsFolder,
		EffectsFolder = effectsFolder,
		Carousels = carousels,
		RestingSpots = restingSpots,
		GuardRoutes = guardRoutes,
		Workbenches = workbenches,
		GateBarriers = gateBarriers,
		GatePrompts = gatePrompts,
		FencePrompt = fencePrompt,
		ShopPrompt = shopPrompt,
		TerminalKioskPrompt = terminalKioskPrompt,
	}
end

function WorldBuilder.CreateWorldBagModel(archetype: GameConfig.ArchetypeDef, cf: CFrame): Model
	return LuggageVisuals.BuildModel(archetype, cf, {
		scale = 1,
		anchored = true,
		withHingedLid = false,
		withRarityGlow = true,
	})
end

return WorldBuilder
