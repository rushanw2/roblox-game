--!strict
-- Procedurally constructs the finished, enclosed Airport Hub, multi-level Mezzanines & Escalators,
-- Carousels, Service Corridor, Smuggler's Hideout, Workbenches, Shops, Gates, and NPCs.

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

-- Helpers declared before callers

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

	-- Full-height collision curtain glass
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

	-- Top steel spandrel beam connecting seamlessly into the roof slab
	makePart(
		opaqueParent,
		name .. "_Spandrel",
		Vector3.new(length, spandrelH, 1.6),
		origin * CFrame.new(0, topY - spandrelH * 0.5, 0),
		Color3.fromRGB(46, 52, 64),
		Enum.Material.Metal,
		true
	)

	-- Brushed aluminum vertical mullions grounded from floor to spandrel
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

	-- Perimeter fascia frame
	makePart(opaqueParent, name .. "_BeamN", Vector3.new(width + 2, 1.8, 2.2), CFrame.new(centerX, roofY, minZ), trussColor, Enum.Material.Metal, true)
	makePart(opaqueParent, name .. "_BeamS", Vector3.new(width + 2, 1.8, 2.2), CFrame.new(centerX, roofY, maxZ), trussColor, Enum.Material.Metal, true)
	makePart(opaqueParent, name .. "_BeamW", Vector3.new(2.2, 1.8, depth + 2), CFrame.new(minX, roofY, centerZ), trussColor, Enum.Material.Metal, true)
	makePart(opaqueParent, name .. "_BeamE", Vector3.new(2.2, 1.8, depth + 2), CFrame.new(maxX, roofY, centerZ), trussColor, Enum.Material.Metal, true)

	-- Structural trusses running East-West with physically mounted LED housing strips
	for r = 0, rows do
		local zPos = minZ + r * cellD
		makePart(decorParent, name .. "_TrussEW_" .. r, Vector3.new(width, 1.3, 1.4), CFrame.new(centerX, roofY - 0.1, zPos), trussColor, Enum.Material.Metal, true)
		if r > 0 and r < rows then
			-- Recessed linear fixture housing bolted directly to bottom of truss
			makePart(decorParent, name .. "_LedHousing_" .. r, Vector3.new(width * 0.86, 0.35, 0.9), CFrame.new(centerX, roofY - 0.85, zPos), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, false)
			makePart(decorParent, name .. "_LedStrip_" .. r, Vector3.new(width * 0.84, 0.16, 0.5), CFrame.new(centerX, roofY - 1.04, zPos), accentColor, Enum.Material.Neon, false)
		end
	end

	-- Structural cross-trusses running North-South
	for c = 0, cols do
		local xPos = minX + c * cellW
		makePart(decorParent, name .. "_TrussNS_" .. c, Vector3.new(1.4, 1.3, depth), CFrame.new(xPos, roofY - 0.1, centerZ), trussColor, Enum.Material.Metal, true)
	end

	-- Coffered acoustic bays alternating with frosted glass atrium skylights
	for r = 1, rows do
		for c = 1, cols do
			local bx = minX + (c - 0.5) * cellW
			local bz = minZ + (r - 0.5) * cellD
			local isSkylight = skylightPattern and ((r + c) % 2 == 0)
			if isSkylight then
				-- Frosted skylight glass framed by aluminum curb (CanCollide = true, CastShadow = false so sunlight pours in!)
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
				-- Acoustic coffered ceiling panel + warm recessed downlight pod mounted directly onto panel
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
	-- Grounded floor plinth -> marble/concrete shaft -> top capital bolted directly into ceiling trusses
	makePart(parent, name .. "_Plinth", Vector3.new(radius * 2 + 0.9, 1.3, radius * 2 + 0.9), CFrame.new(pos.X, 0.65, pos.Z), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(parent, name, Vector3.new(radius * 2, height, radius * 2), CFrame.new(pos.X, height * 0.5, pos.Z), color, Enum.Material.Marble, true)
	makePart(decorParent, name .. "_BrassBandLow", Vector3.new(radius * 2 + 0.2, 0.35, radius * 2 + 0.2), CFrame.new(pos.X, 4.2, pos.Z), accent, Enum.Material.Metal, false)
	makePart(decorParent, name .. "_GlowCollar", Vector3.new(radius * 2 + 0.18, 0.32, radius * 2 + 0.18), CFrame.new(pos.X, height - 2.2, pos.Z), accent, Enum.Material.Neon, false)
	makePart(parent, name .. "_Capital", Vector3.new(radius * 2 + 1.0, 1.1, radius * 2 + 1.0), CFrame.new(pos.X, height - 0.55, pos.Z), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
end

local function buildPlanterBed(coverParent: Instance, decorParent: Instance, pos: Vector3, accentColor: Color3, width: number?, depth: number?)
	local w = width or 4.6
	local d = depth or 4.6
	makePart(coverParent, "PlanterBox", Vector3.new(w, 2.2, d), CFrame.new(pos.X, 1.1, pos.Z), Color3.fromRGB(232, 234, 238), Enum.Material.Marble, true)
	makePart(decorParent, "PlanterRim", Vector3.new(w + 0.25, 0.28, d + 0.25), CFrame.new(pos.X, 2.24, pos.Z), Color3.fromRGB(186, 152, 74), Enum.Material.Metal, false)
	-- Recessed warm accent light mounted inside planter overhang lip
	makePart(decorParent, "PlanterLightStrip", Vector3.new(w + 0.1, 0.14, d + 0.1), CFrame.new(pos.X, 2.02, pos.Z), accentColor, Enum.Material.Neon, false)
	makePart(decorParent, "PlanterSoil", Vector3.new(w - 0.5, 0.25, d - 0.5), CFrame.new(pos.X, 2.26, pos.Z), Color3.fromRGB(68, 48, 34), Enum.Material.Grass, false)
	-- Grounded palm trunk and crown
	makePart(decorParent, "PalmTrunk", Vector3.new(0.75, 5.2, 0.75), CFrame.new(pos.X, 4.9, pos.Z), Color3.fromRGB(116, 82, 52), Enum.Material.Wood, false)
	for i = 1, 6 do
		local yaw = math.rad((i - 1) * 60)
		local cf = CFrame.new(pos.X, 7.45, pos.Z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -1.9) * CFrame.Angles(math.rad(-20), 0, 0)
		makePart(decorParent, "Frond_" .. i, Vector3.new(1.15, 0.16, 3.8), cf, Color3.fromRGB(58, 148, 72), Enum.Material.Grass, false)
	end
end

local function buildLeatherSeatingCluster(parent: Instance, pos: Vector3, yawDeg: number, cushionColor: Color3, trimColor: Color3)
	local origin = CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(parent, "BenchFrame", Vector3.new(10.4, 0.35, 2.8), origin * CFrame.new(0, 1.0, 0), Color3.fromRGB(148, 156, 168), Enum.Material.Metal, true)
	makePart(parent, "BenchSeat", Vector3.new(10.0, 0.52, 2.6), origin * CFrame.new(0, 1.42, 0), cushionColor, Enum.Material.Leather, true)
	makePart(parent, "BenchBack", Vector3.new(10.0, 1.75, 0.48), origin * CFrame.new(0, 2.38, 1.06), cushionColor, Enum.Material.Leather, true)
	-- Armrests and grounded chrome legs
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

local function buildEscalator(
	decorParent: Instance,
	windowsParent: Instance,
	name: string,
	bottomPos: Vector3,
	topPos: Vector3,
	width: number,
	accentColor: Color3
)
	local model = Instance.new("Model")
	model.Name = "Escalator_" .. name
	model.Parent = decorParent

	local deltaXZ = Vector3.new(topPos.X - bottomPos.X, 0, topPos.Z - bottomPos.Z)
	local run = deltaXZ.Magnitude
	local dir = deltaXZ.Unit
	local rise = topPos.Y - bottomPos.Y
	local hyp = math.sqrt(run * run + rise * rise)
	local pitchAngle = math.atan2(rise, run)
	local centerXZ = (Vector3.new(bottomPos.X, 0, bottomPos.Z) + Vector3.new(topPos.X, 0, topPos.Z)) * 0.5
	local midY = (bottomPos.Y + topPos.Y) * 0.5

	-- Smooth invisible wedge ramp overlaid on steps so characters glide up/down effortlessly!
	-- CFrame.lookAt(c, c - dir) aligns local +Z along +dir (rising from bottomPos to topPos).
	local rampCF = CFrame.lookAt(Vector3.new(centerXZ.X, midY, centerXZ.Z), Vector3.new(centerXZ.X, midY, centerXZ.Z) - dir)
	local ramp = makeWedge(
		model,
		"WalkRamp",
		Vector3.new(width - 0.6, rise, run),
		rampCF,
		Color3.fromRGB(100, 100, 100),
		Enum.Material.SmoothPlastic,
		true,
		1
	)
	ramp.CastShadow = false

	-- Sloped truss underbody & comb plates grounded at bottom & top
	local slopeCF = CFrame.lookAt(Vector3.new(centerXZ.X, midY - 0.8, centerXZ.Z), Vector3.new(centerXZ.X, midY - 0.8, centerXZ.Z) - dir)
		* CFrame.Angles(pitchAngle, 0, 0)
	makePart(model, "UnderTruss", Vector3.new(width + 1.2, 1.4, hyp + 1.2), slopeCF, Color3.fromRGB(36, 40, 48), Enum.Material.Metal, true)

	-- Grounded base & top support pedestals
	makePart(model, "BottomComb", Vector3.new(width + 1.2, 0.5, 2.4), CFrame.lookAt(bottomPos + Vector3.new(0, 0.25, 0), bottomPos + Vector3.new(0, 0.25, 0) - dir), Color3.fromRGB(168, 176, 186), Enum.Material.Metal, true)
	makePart(model, "TopComb", Vector3.new(width + 1.2, 0.5, 2.4), CFrame.lookAt(topPos - Vector3.new(0, 0.25, 0), topPos - Vector3.new(0, 0.25, 0) - dir), Color3.fromRGB(168, 176, 186), Enum.Material.Metal, true)

	-- Ribbed metal step treads (non-colliding so players never snag on stair lips)
	local stepCount = 24
	for i = 1, stepCount do
		local t = (i - 0.5) / stepCount
		local stepXZ = Vector3.new(bottomPos.X, 0, bottomPos.Z):Lerp(Vector3.new(topPos.X, 0, topPos.Z), t)
		local stepY = bottomPos.Y + t * rise
		local stepCF = CFrame.lookAt(Vector3.new(stepXZ.X, stepY - 0.25, stepXZ.Z), Vector3.new(stepXZ.X, stepY - 0.25, stepXZ.Z) - dir)
		makePart(model, "Tread_" .. i, Vector3.new(width - 0.7, 0.48, (run / stepCount) + 0.18), stepCF, Color3.fromRGB(72, 78, 88), Enum.Material.DiamondPlate, false)
	end

	-- Side skirt panels, tinted glass balustrades, illuminated skirt accent & rubber handrails
	for _, side in ipairs({ -1, 1 }) do
		local sideOff = side * (width * 0.5 + 0.25)
		local sideCenter = CFrame.lookAt(Vector3.new(centerXZ.X, midY, centerXZ.Z), Vector3.new(centerXZ.X, midY, centerXZ.Z) - dir)
			* CFrame.new(sideOff, 0, 0)
			* CFrame.Angles(pitchAngle, 0, 0)

		-- Lower chrome skirt + glowing accent strip
		makePart(model, "Skirt_" .. side, Vector3.new(0.45, 1.35, hyp + 1.2), sideCenter * CFrame.new(0, 0.4, 0), Color3.fromRGB(190, 198, 208), Enum.Material.Metal, true)
		makePart(model, "SkirtGlow_" .. side, Vector3.new(0.18, 0.2, hyp), sideCenter * CFrame.new(-side * 0.2, 0.85, 0), accentColor, Enum.Material.Neon, false)

		-- Sleek glass balustrade
		makePart(windowsParent, name .. "_Balustrade_" .. side, Vector3.new(0.24, 3.0, hyp), sideCenter * CFrame.new(0, 2.3, 0), Color3.fromRGB(178, 224, 248), Enum.Material.Glass, true, 0.48, false)

		-- Black rubber handrail top + rounded end newels
		makePart(model, "Handrail_" .. side, Vector3.new(0.46, 0.3, hyp + 1.5), sideCenter * CFrame.new(0, 3.85, 0), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic, true)
		makePart(model, "BottomNewel_" .. side, Vector3.new(0.48, 3.8, 1.2), CFrame.lookAt(bottomPos, bottomPos - dir) * CFrame.new(sideOff, 1.9, -0.4), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, true)
		makePart(model, "TopNewel_" .. side, Vector3.new(0.48, 3.8, 1.2), CFrame.lookAt(topPos, topPos - dir) * CFrame.new(sideOff, 1.9, 0.4), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, true)
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

	-- Structural steel fascia deck + polished marble/carpet surface
	makePart(opaqueParent, name .. "_Slab", Vector3.new(w, 1.0, d), CFrame.new(cx, deckY - 0.5, cz), floorColor, Enum.Material.Marble, true)
	makePart(decorParent, name .. "_Trim", Vector3.new(w + 0.3, 0.35, d + 0.3), CFrame.new(cx, deckY - 0.85, cz), trimColor, Enum.Material.Metal, false)

	-- Grounded support columns under deck corners/midpoints reaching down to floor Y=0.4
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

-- Parametric rounded/rectangular loop evaluation for Carousel tracks
function WorldBuilder.EvaluateCarouselPoint(track: CarouselTrack, dist: number): (Vector3, number)
	local straightX = math.max(1, (track.halfW - track.halfD) * 2)
	local arcRadius = track.halfD
	local halfArc = math.pi * arcRadius
	local p = dist % track.perimeter

	-- Segment 1: Top straight (-Z side, moving +X)
	if p < straightX then
		local t = p - straightX * 0.5
		local pos = track.center + Vector3.new(t, track.surfaceY, -arcRadius)
		return pos, -math.pi * 0.5
	end
	p -= straightX

	-- Segment 2: Right semicircle (+X side, moving +Z)
	if p < halfArc then
		local theta = -math.pi * 0.5 + (p / arcRadius)
		local pos = track.center + Vector3.new(straightX * 0.5 + math.cos(theta) * arcRadius, track.surfaceY, math.sin(theta) * arcRadius)
		return pos, -(theta + math.pi * 0.5)
	end
	p -= halfArc

	-- Segment 3: Bottom straight (+Z side, moving -X)
	if p < straightX then
		local t = straightX * 0.5 - p
		local pos = track.center + Vector3.new(t, track.surfaceY, arcRadius)
		return pos, math.pi * 0.5
	end
	p -= straightX

	-- Segment 4: Left semicircle (-X side, moving -Z)
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

	-- Central island chute cover grounded to floor + chrome bumper trim
	makePart(coverParent, id .. "_CenterCore", Vector3.new(straightX + 4, 4.4, halfD * 0.9), CFrame.new(center.X, 2.2, center.Z), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(model, id .. "_CoreAccent", Vector3.new(straightX + 4.2, 0.25, halfD * 0.9 + 0.2), CFrame.new(center.X, 4.2, center.Z), accentColor, Enum.Material.Neon, false)

	-- Twin structural ceiling hanger rods connecting overhead carousel sign cleanly to roof trusses (Y = 24.5)
	local signY = 8.4
	local rodLen = AIRPORT_ROOF_Y - signY
	makePart(model, id .. "_HangerL", Vector3.new(0.32, rodLen, 0.32), CFrame.new(center.X - 4.2, signY + rodLen * 0.5, center.Z), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	makePart(model, id .. "_HangerR", Vector3.new(0.32, rodLen, 0.32), CFrame.new(center.X + 4.2, signY + rodLen * 0.5, center.Z), Color3.fromRGB(168, 176, 188), Enum.Material.Metal, false)
	-- Grounded central support frame connecting sign housing to carousel core
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
		Enum.NormalId.Front
	)
	makeSignBoard(
		model,
		id .. "_SignBack",
		Vector3.new(11, 3.2, 0.9),
		CFrame.new(center.X, signY, center.Z) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(20, 24, 34),
		id:upper(),
		accentColor,
		"CLAIM BAGS CAREFULLY",
		Enum.NormalId.Front
	)

	-- Base belt bed + brushed stainless bumper skirt
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

	-- Clerestory glass sealing above gate header cleanly up to the ceiling
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
		Enum.NormalId.Front
	)
	makeSignBoard(
		windowsParent,
		terminalId .. "_GateMarqueeBack",
		Vector3.new(width + 2, 2.5, 0.45),
		origin * CFrame.new(0, 12.2, -1.4) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(18, 22, 32),
		def.name:upper(),
		def.accentColor,
		string.format("TERMINAL PASS: %s", GameConfig.FormatCash(def.unlockCost)),
		Enum.NormalId.Front
	)

	-- Holographic barrier
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

	-- Grounded turnstile reader post
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
	-- Physically mounted junction box -> rigid steel drop conduit -> industrial shade -> glowing bulb
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
	-- 4 grounded upright posts
	for _, xS in ipairs({ -4.6, 4.6 }) do
		for _, zS in ipairs({ -1.3, 1.3 }) do
			makePart(parent, name .. "_Post", Vector3.new(0.35, 9.2, 0.35), origin * CFrame.new(xS, 4.6, zS), Color3.fromRGB(62, 68, 78), Enum.Material.Metal, true)
		end
	end
	-- 3 shelf levels with crates/cases seated flush
	local shelfHeights = { 0.4, 4.0, 7.6 }
	for idx, sy in ipairs(shelfHeights) do
		makePart(parent, name .. "_Deck_" .. idx, Vector3.new(9.6, 0.3, 3.0), origin * CFrame.new(0, sy, 0), Color3.fromRGB(132, 98, 64), Enum.Material.Wood, true)
		makePart(parent, name .. "_CrateA_" .. idx, Vector3.new(2.4, 2.0, 2.0), origin * CFrame.new(-2.4, sy + 1.15, 0), Color3.fromRGB(156, 118, 76), Enum.Material.WoodPlanks, true)
		makePart(parent, name .. "_CrateB_" .. idx, Vector3.new(2.2, 1.6, 1.8), origin * CFrame.new(1.8, sy + 0.95, 0), Color3.fromRGB(58, 74, 96), Enum.Material.Metal, true)
	end
end

local function buildWorkbench(parent: Instance, slotIndex: number, pos: Vector3): WorkbenchStation
	local model = Instance.new("Model")
	model.Name = "Workbench_" .. slotIndex
	model.Parent = parent

	local origin = CFrame.new(pos.X, 0.4, pos.Z)
	-- Grounded steel legs & rubber feet resting cleanly on Hideout floor (Y = 0.4)
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

	-- Pegboard tool rack & overhead grounded gantry arm holding the bench lamp
	makePart(model, "Backboard", Vector3.new(7.2, 2.4, 0.35), origin * CFrame.new(0, 4.6, 2.1), Color3.fromRGB(36, 40, 50), Enum.Material.Metal, true)
	makePart(model, "GantryPostL", Vector3.new(0.35, 5.2, 0.35), origin * CFrame.new(-3.4, 5.8, 2.1), Color3.fromRGB(58, 64, 76), Enum.Material.Metal, true)
	makePart(model, "GantryPostR", Vector3.new(0.35, 5.2, 0.35), origin * CFrame.new(3.4, 5.8, 2.1), Color3.fromRGB(58, 64, 76), Enum.Material.Metal, true)
	makePart(model, "GantryArm", Vector3.new(7.2, 0.35, 2.6), origin * CFrame.new(0, 8.2, 0.9), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, false)
	makePart(model, "BenchLampGlow", Vector3.new(5.4, 0.18, 0.6), origin * CFrame.new(0, 7.98, 0.2), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, false)

	-- Overhead live status BillboardGui (preserve exact hierarchy expected by WorldVisualsController)
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

	local origin = CFrame.new(pos.X, 0, pos.Z) * CFrame.Angles(0, yaw, 0)

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

local function buildExteriorTarmacAndAircraft(parent: Instance)
	-- Grounded tarmac aprons around North, West, and East perimeter glass views
	makePart(parent, "TarmacNorth", Vector3.new(512, 0.2, 62), CFrame.new(0, 0.1, -225), Color3.fromRGB(54, 58, 66), Enum.Material.Asphalt, true)
	makePart(parent, "TarmacWestApron", Vector3.new(92, 0.2, 136), CFrame.new(-162, 0.1, -126), Color3.fromRGB(58, 62, 70), Enum.Material.Asphalt, true)
	makePart(parent, "TarmacEastApron", Vector3.new(92, 0.2, 136), CFrame.new(162, 0.1, -126), Color3.fromRGB(58, 62, 70), Enum.Material.Asphalt, true)

	-- Painted yellow runway taxi lines & post-mounted runway lights
	makePart(parent, "TaxiCenterLine", Vector3.new(380, 0.06, 1.4), CFrame.new(0, 0.22, -210), Color3.fromRGB(245, 198, 52), Enum.Material.SmoothPlastic, false)
	for x = -180, 180, 30 do
		makePart(parent, "RunwayPost_" .. x, Vector3.new(0.4, 1.1, 0.4), CFrame.new(x, 0.75, -206), Color3.fromRGB(48, 52, 60), Enum.Material.Metal, false)
		makePart(parent, "RunwayLight_" .. x, Vector3.new(0.55, 0.35, 0.55), CFrame.new(x, 1.38, -206), Color3.fromRGB(82, 206, 255), Enum.Material.Neon, false)
	end

	-- Celebrity Private Jet parked outside North Celebrity Curtain Glass (grounded on landing gear)
	local jet = Instance.new("Model")
	jet.Name = "CelebrityPrivateJet"
	jet.Parent = parent
	local center = Vector3.new(12, 8.5, -226)
	makePart(jet, "GearNose", Vector3.new(1.2, 4.5, 1.2), CFrame.new(center + Vector3.new(-16, -6.2, 0)), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
	makePart(jet, "GearMain", Vector3.new(2.0, 4.5, 8.0), CFrame.new(center + Vector3.new(3, -6.2, 0)), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
	makePart(jet, "Fuselage", Vector3.new(44, 8, 8), CFrame.new(center), Color3.fromRGB(244, 246, 250), Enum.Material.SmoothPlastic, true)
	makePart(jet, "GoldStripe", Vector3.new(42, 1.1, 8.2), CFrame.new(center + Vector3.new(0, -0.5, 0)), Color3.fromRGB(255, 198, 62), Enum.Material.Neon, false)
	makePart(jet, "NoseCone", Vector3.new(7, 6.2, 6.2), CFrame.new(center + Vector3.new(-24.5, -0.5, 0)), Color3.fromRGB(238, 242, 248), Enum.Material.SmoothPlastic, true)
	makePart(jet, "CockpitGlass", Vector3.new(4, 2.2, 5.4), CFrame.new(center + Vector3.new(-21, 1.6, 0)), Color3.fromRGB(32, 56, 84), Enum.Material.Glass, false, 0.2)
	makePart(jet, "MainWing", Vector3.new(12, 1.0, 42), CFrame.new(center + Vector3.new(2, -1.8, 0)), Color3.fromRGB(232, 236, 244), Enum.Material.SmoothPlastic, true)
	makePart(jet, "TailFin", Vector3.new(7, 9, 1.2), CFrame.new(center + Vector3.new(18, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(-18)), Color3.fromRGB(255, 86, 152), Enum.Material.SmoothPlastic, true)

	-- Regional Airliner visible through International North Glass
	local intlJet = Instance.new("Model")
	intlJet.Name = "InternationalAirliner"
	intlJet.Parent = parent
	local j2 = Vector3.new(-164, 9.5, -112)
	makePart(intlJet, "GearF", Vector3.new(1.4, 5.4, 1.4), CFrame.new(j2 + Vector3.new(-14, -6.6, 0)), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
	makePart(intlJet, "GearR", Vector3.new(2.2, 5.4, 7.6), CFrame.new(j2 + Vector3.new(4, -6.6, 0)), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
	makePart(intlJet, "Body", Vector3.new(46, 9, 8.6), CFrame.new(j2), Color3.fromRGB(238, 244, 250), Enum.Material.SmoothPlastic, true)
	makePart(intlJet, "Livery", Vector3.new(44, 1.4, 8.8), CFrame.new(j2 + Vector3.new(0, 0.2, 0)), GameConfig.TERMINALS.International.accentColor, Enum.Material.SmoothPlastic, false)
	makePart(intlJet, "Wing", Vector3.new(14, 1.0, 44), CFrame.new(j2 + Vector3.new(2, -1.8, 0)), Color3.fromRGB(224, 228, 236), Enum.Material.SmoothPlastic, true)
	makePart(intlJet, "Tail", Vector3.new(8, 10, 1.4), CFrame.new(j2 + Vector3.new(19, 7.2, 0)) * CFrame.Angles(0, 0, math.rad(-18)), GameConfig.TERMINALS.International.accentColor, Enum.Material.SmoothPlastic, true)

	-- Baggage Tug & Carts visible outside First-Class VIP North Glass
	local tugPos = Vector3.new(162, 0.2, -104)
	makePart(parent, "BaggageTugBody", Vector3.new(8, 3.2, 4.4), CFrame.new(tugPos + Vector3.new(0, 2.2, 0)), Color3.fromRGB(238, 186, 52), Enum.Material.SmoothPlastic, true)
	makePart(parent, "BaggageTugCab", Vector3.new(4.2, 2.6, 4.0), CFrame.new(tugPos + Vector3.new(-1.2, 5.1, 0)), Color3.fromRGB(48, 56, 70), Enum.Material.Glass, false, 0.35)
	for _, xW in ipairs({ -2.6, 2.6 }) do
		makePart(parent, "TugWheel", Vector3.new(1.5, 1.5, 4.8), CFrame.new(tugPos + Vector3.new(xW, 0.75, 0)), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic, true)
	end
end

local function buildServiceCorridorAndHideout(
	decorParent: Instance,
	coverParent: Instance
): ({ WorkbenchStation }, ProximityPrompt, ProximityPrompt, ProximityPrompt)
	-- Floors (flush at Y = 0.4)
	makePart(decorParent, "HideoutFloor", Vector3.new(136, 0.4, 60), CFrame.new(0, 0.2, 132), Color3.fromRGB(40, 44, 52), Enum.Material.Concrete, true)
	makePart(decorParent, "CorridorFloor", Vector3.new(68, 0.4, 37), CFrame.new(0, 0.2, 83.5), Color3.fromRGB(52, 56, 66), Enum.Material.DiamondPlate, true)

	-- Yellow/black industrial hazard edge strips & green escape floor chevrons
	makePart(decorParent, "CorridorEdgeW", Vector3.new(1.2, 0.08, 36), CFrame.new(-32.2, 0.44, 83.5), Color3.fromRGB(232, 178, 44), Enum.Material.SmoothPlastic, false)
	makePart(decorParent, "CorridorEdgeE", Vector3.new(1.2, 0.08, 36), CFrame.new(32.2, 0.44, 83.5), Color3.fromRGB(232, 178, 44), Enum.Material.SmoothPlastic, false)
	makePart(decorParent, "SafeZoneLine", Vector3.new(24, 0.12, 1.2), CFrame.new(0, 0.44, 102), Color3.fromRGB(68, 255, 156), Enum.Material.Neon, false)
	for idx = 1, 3 do
		makePart(decorParent, "EscapeArrow_" .. idx, Vector3.new(4.5, 0.1, 2.2), CFrame.new(0, 0.44, 72 + idx * 8), Color3.fromRGB(68, 255, 156), Enum.Material.Neon, false, 0.25)
	end

	-- Enclosed Service Corridor Walls (X = -34 and +34, Z = 65..102) + Finished Ceiling (Y = 18.0)
	makePart(coverParent, "CorridorWallW", Vector3.new(2, HIDEOUT_CEILING_Y, 39), CFrame.new(-34, HIDEOUT_CEILING_Y * 0.5, 83.5), Color3.fromRGB(68, 72, 82), Enum.Material.Concrete, true)
	makePart(coverParent, "CorridorWallE", Vector3.new(2, HIDEOUT_CEILING_Y, 39), CFrame.new(34, HIDEOUT_CEILING_Y * 0.5, 83.5), Color3.fromRGB(68, 72, 82), Enum.Material.Concrete, true)
	makePart(coverParent, "CorridorCeiling", Vector3.new(70, 1.2, 39), CFrame.new(0, HIDEOUT_CEILING_Y + 0.4, 83.5), Color3.fromRGB(48, 52, 60), Enum.Material.Concrete, true)

	-- Staff-Only Maintenance Vestibule Doorway Frame connecting Airport South Wall (Z = 65) into Corridor
	makePart(coverParent, "StaffPortalL", Vector3.new(18, 14, 2.2), CFrame.new(-25, 7, 65.5), Color3.fromRGB(54, 60, 72), Enum.Material.Concrete, true)
	makePart(coverParent, "StaffPortalR", Vector3.new(18, 14, 2.2), CFrame.new(25, 7, 65.5), Color3.fromRGB(54, 60, 72), Enum.Material.Concrete, true)
	makePart(coverParent, "StaffPortalHeader", Vector3.new(68, 4.5, 2.4), CFrame.new(0, 15.75, 65.5), Color3.fromRGB(38, 44, 56), Enum.Material.Metal, true)
	makeSignBoard(
		decorParent,
		"StaffDoorSign",
		Vector3.new(28, 3.0, 0.45),
		CFrame.new(0, 15.6, 66.9),
		Color3.fromRGB(24, 28, 38),
		"AUTHORIZED STAFF CORRIDOR B2",
		Color3.fromRGB(255, 198, 62),
		"BASEMENT MAINTENANCE • HIDEOUT ACCESS",
		Enum.NormalId.Front
	)

	-- Corridor ceiling beams, HVAC ducting, and grounded cage lights
	for _, zBeam in ipairs({ 74, 84, 94 }) do
		makePart(decorParent, "CorridorBeam_" .. zBeam, Vector3.new(66, 1.0, 1.2), CFrame.new(0, HIDEOUT_CEILING_Y - 0.5, zBeam), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, true)
		buildIndustrialCageLight(decorParent, "CorridorLight_" .. zBeam, Vector3.new(0, HIDEOUT_CEILING_Y - 1.0, zBeam), 1.4)
	end
	buildVentDuct(decorParent, "CorridorHVAC", Vector3.new(-26, 15.6, 67), Vector3.new(-26, 15.6, 101), HIDEOUT_CEILING_Y - 0.2, 3.6, 2.2)

	-- Wall-mounted conduit pipes in Service Corridor
	for _, hPipe in ipairs({ 6.5, 7.6 }) do
		makePart(decorParent, "CorridorPipeW_" .. hPipe, Vector3.new(0.4, 0.4, 35), CFrame.new(-32.8, hPipe, 83.5), Color3.fromRGB(168, 102, 58), Enum.Material.Metal, false)
	end

	-- Courtyard/Corridor Terminal Pass Kiosk (Right side, X = 26, Z = 86, grounded cleanly to floor)
	local kiosk = makePart(decorParent, "TerminalPassKiosk", Vector3.new(6, 4.2, 3.2), CFrame.new(26, 2.5, 86), Color3.fromRGB(34, 42, 60), Enum.Material.Metal, true)
	makePart(decorParent, "KioskPostL", Vector3.new(0.45, 3.2, 0.45), CFrame.new(23.5, 5.8, 86), Color3.fromRGB(140, 150, 166), Enum.Material.Metal, false)
	makePart(decorParent, "KioskPostR", Vector3.new(0.45, 3.2, 0.45), CFrame.new(28.5, 5.8, 86), Color3.fromRGB(140, 150, 166), Enum.Material.Metal, false)
	makeSignBoard(
		decorParent,
		"TerminalKioskSign",
		Vector3.new(7, 2.8, 0.4),
		CFrame.new(26, 7.2, 86),
		Color3.fromRGB(18, 24, 38),
		"TERMINAL PASSES",
		Color3.fromRGB(255, 206, 72),
		"UNLOCK HIGHER-TIER WINGS",
		Enum.NormalId.Front
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

	-- SpawnLocation inside enclosed Service Vestibule facing North toward Airport
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

	-- Hideout Vault North Archway (Z = 102) & Perimeter Walls + Finished Ceiling (Y = 18.0)
	makePart(coverParent, "HideoutWallNL", Vector3.new(56, HIDEOUT_CEILING_Y, 2), CFrame.new(-40, HIDEOUT_CEILING_Y * 0.5, 102), Color3.fromRGB(78, 56, 50), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutWallNR", Vector3.new(56, HIDEOUT_CEILING_Y, 2), CFrame.new(40, HIDEOUT_CEILING_Y * 0.5, 102), Color3.fromRGB(78, 56, 50), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutArchHeader", Vector3.new(28, 5.5, 2.6), CFrame.new(0, 15.25, 102), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, true)
	makeSignBoard(
		decorParent,
		"HideoutSign",
		Vector3.new(24, 3.2, 0.5),
		CFrame.new(0, 14.4, 100.5) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(16, 20, 28),
		"SMUGGLER'S HIDEOUT",
		Color3.fromRGB(72, 255, 162),
		"SAFE ZONE • SECURE & CRACK STOLEN BAGS",
		Enum.NormalId.Front
	)
	makePart(coverParent, "HideoutWallS", Vector3.new(138, HIDEOUT_CEILING_Y, 2), CFrame.new(0, HIDEOUT_CEILING_Y * 0.5, 162), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutWallW", Vector3.new(2, HIDEOUT_CEILING_Y, 62), CFrame.new(-68, HIDEOUT_CEILING_Y * 0.5, 132), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)
	makePart(coverParent, "HideoutWallE", Vector3.new(2, HIDEOUT_CEILING_Y, 62), CFrame.new(68, HIDEOUT_CEILING_Y * 0.5, 132), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)

	-- Solid Hideout Roof & Concrete Ceiling Slab + Structural Steel Beams + HVAC Ducts + Cage Lights
	makePart(coverParent, "HideoutCeilingSlab", Vector3.new(138, 1.2, 62), CFrame.new(0, HIDEOUT_CEILING_Y + 0.4, 132), Color3.fromRGB(44, 48, 56), Enum.Material.Concrete, true)
	for _, xBeam in ipairs({ -46, -16, 16, 46 }) do
		makePart(decorParent, "HideoutSteelBeam_" .. xBeam, Vector3.new(1.8, 1.2, 60), CFrame.new(xBeam, HIDEOUT_CEILING_Y - 0.6, 132), Color3.fromRGB(32, 36, 44), Enum.Material.Metal, true)
		buildIndustrialCageLight(decorParent, "HideoutLightN_" .. xBeam, Vector3.new(xBeam, HIDEOUT_CEILING_Y - 1.2, 118), 1.4)
		buildIndustrialCageLight(decorParent, "HideoutLightS_" .. xBeam, Vector3.new(xBeam, HIDEOUT_CEILING_Y - 1.2, 146), 1.4)
	end
	buildVentDuct(decorParent, "HideoutMainHVAC", Vector3.new(-60, 15.6, 114), Vector3.new(60, 15.6, 114), HIDEOUT_CEILING_Y - 0.2, 4.0, 2.4)
	buildVentDuct(decorParent, "HideoutSouthHVAC", Vector3.new(-60, 15.6, 150), Vector3.new(24, 15.6, 150), HIDEOUT_CEILING_Y - 0.2, 3.2, 2.0)

	-- Industrial Storage Shelving grounded along West & South Hideout walls
	buildStorageShelf(decorParent, "HideoutShelfW1", Vector3.new(-64.5, 0, 118), 90)
	buildStorageShelf(decorParent, "HideoutShelfW2", Vector3.new(-64.5, 0, 144), 90)
	buildStorageShelf(decorParent, "HideoutShelfS1", Vector3.new(-32, 0, 158.5), 0)
	buildStorageShelf(decorParent, "HideoutShelfS2", Vector3.new(-10, 0, 158.5), 0)

	-- 4 Grounded Cracking Workbenches inside Hideout West/Center
	local workbenches: { WorkbenchStation } = {}
	local benchPositions = {
		Vector3.new(-46, 0, 130),
		Vector3.new(-30, 0, 130),
		Vector3.new(-14, 0, 130),
		Vector3.new(2, 0, 130),
	}
	for i, benchPos in ipairs(benchPositions) do
		table.insert(workbenches, buildWorkbench(decorParent, i, benchPos))
	end

	-- Shady Fence Sell Counter (East Hideout, sign mounted via floor posts to counter)
	local fenceModel = Instance.new("Model")
	fenceModel.Name = "FenceCounter"
	fenceModel.Parent = decorParent
	makePart(fenceModel, "CounterDesk", Vector3.new(12, 3.6, 4.2), CFrame.new(40, 2.2, 122), Color3.fromRGB(76, 50, 36), Enum.Material.Wood, true)
	makePart(fenceModel, "CounterTrim", Vector3.new(12.2, 0.35, 4.4), CFrame.new(40, 4.1, 122), Color3.fromRGB(255, 198, 62), Enum.Material.Metal, true)
	makePart(fenceModel, "FencePostL", Vector3.new(0.4, 5.4, 0.4), CFrame.new(35, 6.8, 122), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makePart(fenceModel, "FencePostR", Vector3.new(0.4, 5.4, 0.4), CFrame.new(45, 6.8, 122), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makeSignBoard(
		fenceModel,
		"FenceSign",
		Vector3.new(11, 2.6, 0.5),
		CFrame.new(40, 9.2, 122),
		Color3.fromRGB(24, 20, 30),
		"VINNIE'S FENCE",
		Color3.fromRGB(255, 206, 68),
		"SELL REVEALED LOOT FOR CASH",
		Enum.NormalId.Front
	)
	buildStylizedNPC(
		fenceModel,
		"FenceNPC",
		Vector3.new(40, 0.4, 126),
		0,
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
	fencePrompt.MaxActivationDistance = 12
	fencePrompt.RequiresLineOfSight = false
	fencePrompt.Parent = fenceModel:FindFirstChild("CounterDesk") :: BasePart

	-- Black-Market Stealth & Tools Shop Kiosk (South-East Hideout, sign mounted on steel posts)
	local shopModel = Instance.new("Model")
	shopModel.Name = "StealthShopKiosk"
	shopModel.Parent = decorParent
	makePart(shopModel, "ShopCounter", Vector3.new(12, 3.6, 4.2), CFrame.new(40, 2.2, 146), Color3.fromRGB(32, 44, 62), Enum.Material.Metal, true)
	makePart(shopModel, "ShopNeon", Vector3.new(12.2, 0.35, 4.4), CFrame.new(40, 4.1, 146), Color3.fromRGB(74, 208, 255), Enum.Material.Neon, false)
	makePart(shopModel, "ShopPostL", Vector3.new(0.4, 5.4, 0.4), CFrame.new(35, 6.8, 146), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makePart(shopModel, "ShopPostR", Vector3.new(0.4, 5.4, 0.4), CFrame.new(45, 6.8, 146), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, false)
	makeSignBoard(
		shopModel,
		"ShopSign",
		Vector3.new(11, 2.6, 0.5),
		CFrame.new(40, 9.2, 146),
		Color3.fromRGB(16, 22, 36),
		"BLACK-MARKET GEAR",
		Color3.fromRGB(78, 224, 255),
		"TOOLS • SNEAKERS • STEALTH COATS • GADGETS",
		Enum.NormalId.Front
	)
	buildStylizedNPC(
		shopModel,
		"QuartermasterNPC",
		Vector3.new(40, 0.4, 150),
		0,
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
	shopPrompt.MaxActivationDistance = 12
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopModel:FindFirstChild("ShopCounter") :: BasePart

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
	-- 1. EXTERIOR TARMAC, AIRCRAFT & ENCLOSED HIDEOUT ACCESS
	-----------------------------------------------------------------------
	buildExteriorTarmacAndAircraft(decor)
	local workbenches, fencePrompt, shopPrompt, terminalKioskPrompt = buildServiceCorridorAndHideout(decor, opaqueCover)

	-----------------------------------------------------------------------
	-- 2. LUXURY AIRPORT FLOORS & BRASS INLAY PATTERNS
	-----------------------------------------------------------------------
	-- Ground floor slabs (top Y = 0.4)
	makePart(decor, "Floor_Domestic", Vector3.new(172, 0.4, 123), CFrame.new(0, 0.2, 3.5), GameConfig.TERMINALS.Domestic.floorColor, Enum.Material.Marble, true)
	makePart(decor, "Floor_International", Vector3.new(122, 0.4, 123), CFrame.new(-147, 0.2, 3.5), GameConfig.TERMINALS.International.floorColor, Enum.Material.Marble, true)
	makePart(decor, "Floor_FirstClass", Vector3.new(122, 0.4, 123), CFrame.new(147, 0.2, 3.5), GameConfig.TERMINALS.FirstClass.floorColor, Enum.Material.Fabric, true)
	makePart(decor, "Floor_Celebrity", Vector3.new(232, 0.4, 136), CFrame.new(0, 0.2, -126), GameConfig.TERMINALS.Celebrity.floorColor, Enum.Material.Marble, true)

	-- Polished brass promenade inlays & red carpet aisle
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
	-- South Perimeter Curtain Glass Walls (Z = 65) flanking the enclosed Service Corridor (X = -34..34)
	buildCurtainWallBay(opaqueCover, windows, "SouthCurtainW", Vector3.new(-208, 0, 65), Vector3.new(-34, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(54, 62, 76), Color3.fromRGB(156, 206, 236))
	buildCurtainWallBay(opaqueCover, windows, "SouthCurtainE", Vector3.new(34, 0, 65), Vector3.new(208, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(54, 62, 76), Color3.fromRGB(156, 206, 236))
	-- Clerestory glass above the Staff Portal header (X = -34..34, Z = 65, Y = 18..24.5) sealing the South Atrium
	buildCurtainWallBay(opaqueCover, windows, "SouthCenterClerestory", Vector3.new(-34, 0, 65), Vector3.new(34, 0, 65), 18.0, AIRPORT_ROOF_Y, 0, Color3.fromRGB(38, 44, 56), Color3.fromRGB(156, 206, 236))

	-- Airport Side Curtain Entrance Marquee mounted cleanly to portal frame
	makeSignBoard(
		decor,
		"MainAirportMarquee",
		Vector3.new(32, 3.4, 0.6),
		CFrame.new(0, 15.8, 63.8) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(16, 22, 34),
		"SKYPORT INTERNATIONAL",
		Color3.fromRGB(82, 206, 255),
		"DOMESTIC • INTERNATIONAL • FIRST-CLASS • CELEBRITY",
		Enum.NormalId.Front
	)

	-- Exterior West & East Curtain Glass Walls of Lower Wings (Z = -58..65)
	buildCurtainWallBay(opaqueCover, windows, "WestOuterCurtain", Vector3.new(-208, 0, -58), Vector3.new(-208, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(204, 210, 218), Color3.fromRGB(164, 212, 240))
	buildCurtainWallBay(opaqueCover, windows, "EastOuterCurtain", Vector3.new(208, 0, -58), Vector3.new(208, 0, 65), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(48, 50, 68), Color3.fromRGB(142, 186, 224))

	-- North Curtain Glass Walls of International & First-Class Wings (overlooking parked Airliner & Baggage Tug)
	buildCurtainWallBay(opaqueCover, windows, "NorthCurtainIntl", Vector3.new(-208, 0, -58), Vector3.new(-116, 0, -58), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(198, 204, 214), Color3.fromRGB(164, 212, 240))
	buildCurtainWallBay(opaqueCover, windows, "NorthCurtainVip", Vector3.new(116, 0, -58), Vector3.new(208, 0, -58), 0, AIRPORT_ROOF_Y, 3.6, Color3.fromRGB(48, 50, 68), Color3.fromRGB(142, 186, 224))

	-- Celebrity North, West & East Perimeter Curtain Glass Walls (overlooking Private Jet & Runway)
	buildCurtainWallBay(opaqueCover, windows, "CelebNorthCurtain", Vector3.new(-116, 0, -194), Vector3.new(116, 0, -194), 0, AIRPORT_ROOF_Y, 3.4, Color3.fromRGB(32, 34, 42), Color3.fromRGB(168, 214, 244))
	buildCurtainWallBay(opaqueCover, windows, "CelebWestCurtain", Vector3.new(-116, 0, -194), Vector3.new(-116, 0, -58), 0, AIRPORT_ROOF_Y, 3.4, Color3.fromRGB(38, 40, 50), Color3.fromRGB(154, 198, 232))
	buildCurtainWallBay(opaqueCover, windows, "CelebEastCurtain", Vector3.new(116, 0, -194), Vector3.new(116, 0, -58), 0, AIRPORT_ROOF_Y, 3.4, Color3.fromRGB(38, 40, 50), Color3.fromRGB(154, 198, 232))

	-- Full-height Interior Wing Dividing Walls (meeting roof at Y = 24.5)
	makePart(opaqueCover, "CelebritySouthW", Vector3.new(102, AIRPORT_ROOF_Y, 2), CFrame.new(-65, AIRPORT_ROOF_Y * 0.5, -58), Color3.fromRGB(42, 44, 56), Enum.Material.Concrete, true)
	makePart(opaqueCover, "CelebritySouthE", Vector3.new(102, AIRPORT_ROOF_Y, 2), CFrame.new(65, AIRPORT_ROOF_Y * 0.5, -58), Color3.fromRGB(42, 44, 56), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomIntl_N", Vector3.new(2, AIRPORT_ROOF_Y, 37), CFrame.new(-86, AIRPORT_ROOF_Y * 0.5, -39.5), Color3.fromRGB(220, 224, 230), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomIntl_S", Vector3.new(2, AIRPORT_ROOF_Y, 66), CFrame.new(-86, AIRPORT_ROOF_Y * 0.5, 32), Color3.fromRGB(220, 224, 230), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomVip_N", Vector3.new(2, AIRPORT_ROOF_Y, 37), CFrame.new(86, AIRPORT_ROOF_Y * 0.5, -39.5), Color3.fromRGB(54, 58, 76), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomVip_S", Vector3.new(2, AIRPORT_ROOF_Y, 66), CFrame.new(86, AIRPORT_ROOF_Y * 0.5, 32), Color3.fromRGB(54, 58, 76), Enum.Material.Concrete, true)

	-- Complete Airport Roof, Structural Trusses, Coffered Acoustic Bays & Frosted Skylights
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
	-- 5. INTERIOR DETAILS, ESCALATORS, MEZZANINES & CAROUSELS
	-----------------------------------------------------------------------
	local carousels: { CarouselTrack } = {}
	local restingSpots: { RestingSpot } = {}

	-- DOMESTIC DETAILS + GRAND MEZZANINE & DUAL ESCALATORS
	makeSignBoard(
		decor,
		"DepartureBoard",
		Vector3.new(32, 7.5, 1.4),
		CFrame.new(0, 12.8, 24),
		Color3.fromRGB(16, 20, 30),
		"DEPARTURES  |  FLIGHT 402 ON TIME",
		Color3.fromRGB(255, 208, 64),
		"GATE A1 TOKYO • GATE B4 PARIS • GATE C9 ZURICH",
		Enum.NormalId.Front
	)
	-- Columns extend cleanly from floor (Y = 0) through the Departure Board all the way into ceiling trusses (Y = 24.5)
	makePart(opaqueCover, "BoardColL", Vector3.new(2.2, AIRPORT_ROOF_Y, 2.2), CFrame.new(-16, AIRPORT_ROOF_Y * 0.5, 24), Color3.fromRGB(156, 166, 180), Enum.Material.Metal, true)
	makePart(opaqueCover, "BoardColR", Vector3.new(2.2, AIRPORT_ROOF_Y, 2.2), CFrame.new(16, AIRPORT_ROOF_Y * 0.5, 24), Color3.fromRGB(156, 166, 180), Enum.Material.Metal, true)

	-- Marble Check-in Desks with brass front trim & grounded overhead airline kiosks
	for _, deskX in ipairs({ -52, 52 }) do
		makePart(opaqueCover, "CheckInMarble_" .. deskX, Vector3.new(18, 3.8, 4.5), CFrame.new(deskX, 1.9, 44), Color3.fromRGB(238, 240, 244), Enum.Material.Marble, true)
		makePart(decor, "CheckInBrass_" .. deskX, Vector3.new(18.2, 0.35, 4.7), CFrame.new(deskX, 3.9, 44), Color3.fromRGB(204, 164, 72), Enum.Material.Metal, false)
	end

	-- Full-height architectural columns connecting floor to ceiling trusses
	for _, pPos in ipairs({
		Vector3.new(-24, 0, 42), Vector3.new(24, 0, 42),
		Vector3.new(-24, 0, 6), Vector3.new(24, 0, 6),
		Vector3.new(-66, 0, 10), Vector3.new(66, 0, 10),
	}) do
		buildPillar(opaqueCover, decor, "DomPillar", pPos, 1.8, AIRPORT_ROOF_Y, Color3.fromRGB(234, 238, 244), Color3.fromRGB(204, 166, 76))
	end

	for _, palmPos in ipairs({ Vector3.new(-20, 0, 56), Vector3.new(20, 0, 56), Vector3.new(0, 0, -40) }) do
		buildPlanterBed(opaqueCover, decor, palmPos, GameConfig.TERMINALS.Domestic.accentColor)
	end

	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-44, 0, 12), 0, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(44, 0, 12), 0, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(0, 0, -6), 90, Color3.fromRGB(48, 86, 134), Color3.fromRGB(172, 180, 192))

	-- Domestic Grand Mezzanine Observation Balcony & Side Skywalks (Y = 12.0) + Dual Escalators
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"DomMainMezz",
		-83,
		83,
		46,
		63,
		12.0,
		Color3.fromRGB(218, 224, 232),
		Color3.fromRGB(198, 160, 72),
		{ N = true, S = false, W = false, E = false },
		{
			{ axis = "Z", minV = -83, maxV = -62, side = "N" },
			{ axis = "Z", minV = 62, maxV = 83, side = "N" },
		}
	)
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"DomSkywalkW",
		-83,
		-70,
		-46,
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
		70,
		83,
		-46,
		46,
		12.0,
		Color3.fromRGB(218, 224, 232),
		Color3.fromRGB(198, 160, 72),
		{ N = true, S = false, W = true, E = false },
		nil
	)
	buildEscalator(decor, windows, "DomWest", Vector3.new(-65.5, 0.4, 23), Vector3.new(-65.5, 12.0, 46), 6.0, GameConfig.TERMINALS.Domestic.accentColor)
	buildEscalator(decor, windows, "DomEast", Vector3.new(65.5, 0.4, 23), Vector3.new(65.5, 12.0, 46), 6.0, GameConfig.TERMINALS.Domestic.accentColor)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Claim 1", "Domestic", Vector3.new(-44, 0, -18), 18, 9, 6.2, GameConfig.TERMINALS.Domestic.accentColor))
	table.insert(carousels, buildCarousel(decor, opaqueCover, "Claim 2", "Domestic", Vector3.new(44, 0, -18), 18, 9, 6.2, GameConfig.TERMINALS.Domestic.accentColor))

	table.insert(restingSpots, { id = "DomSpot1", terminalId = "Domestic", bagPos = Vector3.new(-52, 0.4, 15), bagYaw = 0.2, ownerHomePos = Vector3.new(-44, 0.4, 16), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.48, patrolWaypoint = Vector3.new(-35, 0.4, 16) })
	table.insert(restingSpots, { id = "DomSpot2", terminalId = "Domestic", bagPos = Vector3.new(52, 0.4, 15), bagYaw = -0.3, ownerHomePos = Vector3.new(44, 0.4, 16), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.48, patrolWaypoint = Vector3.new(35, 0.4, 16) })
	table.insert(restingSpots, { id = "DomSpot3", terminalId = "Domestic", bagPos = Vector3.new(-40, 0.4, 41), bagYaw = 0, ownerHomePos = Vector3.new(-50, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = -math.pi * 0.55, patrolWaypoint = Vector3.new(-58, 0.4, 38) })
	table.insert(restingSpots, { id = "DomSpot4", terminalId = "Domestic", bagPos = Vector3.new(40, 0.4, 41), bagYaw = 0, ownerHomePos = Vector3.new(50, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.55, patrolWaypoint = Vector3.new(58, 0.4, 38) })
	table.insert(restingSpots, { id = "DomSpot5", terminalId = "Domestic", bagPos = Vector3.new(0, 0.4, -14), bagYaw = 0.5, ownerHomePos = Vector3.new(5, 0.4, -4), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = 0.4, patrolWaypoint = Vector3.new(6, 0.4, 6) })

	-- INTERNATIONAL CONCOURSE DETAILS + OBSERVATION MEZZANINE & ESCALATOR
	makePart(opaqueCover, "DutyFreeIsland1", Vector3.new(20, 5.2, 10), CFrame.new(-174, 2.6, 26), Color3.fromRGB(142, 98, 62), Enum.Material.Wood, true)
	makePart(decor, "DutyFreeTrim1", Vector3.new(20.4, 0.35, 10.4), CFrame.new(-174, 5.25, 26), Color3.fromRGB(204, 168, 76), Enum.Material.Metal, false)
	makePart(opaqueCover, "DutyFreeIsland2", Vector3.new(20, 5.2, 10), CFrame.new(-120, 2.6, 26), Color3.fromRGB(64, 128, 114), Enum.Material.SmoothPlastic, true)
	makePart(decor, "DutyFreeTrim2", Vector3.new(20.4, 0.35, 10.4), CFrame.new(-120, 5.25, 26), Color3.fromRGB(204, 168, 76), Enum.Material.Metal, false)

	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"IntlMezz",
		-206,
		-104,
		48,
		63,
		11.5,
		Color3.fromRGB(198, 184, 158),
		Color3.fromRGB(68, 214, 152),
		{ N = true, S = false, W = false, E = true },
		{
			{ axis = "Z", minV = -203, maxV = -193, side = "N" },
		}
	)
	buildEscalator(decor, windows, "IntlWest", Vector3.new(-198, 0.4, 26), Vector3.new(-198, 11.5, 48), 6.2, GameConfig.TERMINALS.International.accentColor)
	makeSignBoard(
		decor,
		"DutyFreeSign",
		Vector3.new(18, 3.0, 0.6),
		CFrame.new(-148, 13.6, 48.2),
		Color3.fromRGB(22, 32, 34),
		"INTERNATIONAL DUTY-FREE",
		GameConfig.TERMINALS.International.accentColor,
		"PASSPORT CONTROL & CUSTOMS",
		Enum.NormalId.Front
	)

	for _, pPos in ipairs({ Vector3.new(-186, 0, -40), Vector3.new(-112, 0, -40), Vector3.new(-148, 0, 10) }) do
		buildPillar(opaqueCover, decor, "IntlPillar", pPos, 1.8, AIRPORT_ROOF_Y, Color3.fromRGB(218, 206, 184), GameConfig.TERMINALS.International.accentColor)
	end
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-148, 0, 18), 0, Color3.fromRGB(48, 148, 108), Color3.fromRGB(204, 174, 92))
	buildPlanterBed(opaqueCover, decor, Vector3.new(-186, 0, 42), GameConfig.TERMINALS.International.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(-102, 0, 42), GameConfig.TERMINALS.International.accentColor)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Intl Claim 3", "International", Vector3.new(-148, 0, -18), 22, 10, 7.2, GameConfig.TERMINALS.International.accentColor))

	table.insert(restingSpots, { id = "IntlSpot1", terminalId = "International", bagPos = Vector3.new(-164, 0.4, 24), bagYaw = 0.2, ownerHomePos = Vector3.new(-156, 0.4, 14), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = 0.4, patrolWaypoint = Vector3.new(-142, 0.4, 14) })
	table.insert(restingSpots, { id = "IntlSpot2", terminalId = "International", bagPos = Vector3.new(-132, 0.4, 24), bagYaw = -0.3, ownerHomePos = Vector3.new(-140, 0.4, 14), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -0.4, patrolWaypoint = Vector3.new(-126, 0.4, 10) })
	table.insert(restingSpots, { id = "IntlSpot3", terminalId = "International", bagPos = Vector3.new(-186, 0.4, 4), bagYaw = 1.1, ownerHomePos = Vector3.new(-180, 0.4, -6), ownerLookAwayYaw = -math.pi * 0.5, ownerWatchBagYaw = 0.35, patrolWaypoint = Vector3.new(-174, 0.4, -14) })
	table.insert(restingSpots, { id = "IntlSpot4", terminalId = "International", bagPos = Vector3.new(-124, 0.4, -44), bagYaw = 0, ownerHomePos = Vector3.new(-136, 0.4, -44), ownerLookAwayYaw = math.pi * 0.5, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(-152, 0.4, -44) })

	-- FIRST-CLASS VIP LOUNGE DETAILS + SKY-LOFT MEZZANINE, VELVET ROPES & ESCALATOR
	makePart(opaqueCover, "VipBarCounter", Vector3.new(22, 4.2, 6), CFrame.new(172, 2.1, 28), Color3.fromRGB(36, 28, 42), Enum.Material.Marble, true)
	makePart(decor, "VipBarGold", Vector3.new(22.2, 0.35, 6.2), CFrame.new(172, 4.3, 28), Color3.fromRGB(255, 198, 64), Enum.Material.Metal, false)
	makePart(opaqueCover, "VipDivider1", Vector3.new(16, 6.5, 1.4), CFrame.new(124, 3.25, 22), Color3.fromRGB(98, 68, 42), Enum.Material.Wood, true)
	makePart(opaqueCover, "VipDivider2", Vector3.new(16, 6.5, 1.4), CFrame.new(148, 3.25, -42), Color3.fromRGB(98, 68, 42), Enum.Material.Wood, true)

	-- Luxury velvet ropes framing the VIP Champagne Bar
	buildVelvetRopeLine(decor, Vector3.new(158, 0, 22), Vector3.new(158, 0, 34), Color3.fromRGB(178, 30, 58))

	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"VipSkyLoft",
		104,
		206,
		46,
		63,
		11.5,
		Color3.fromRGB(58, 64, 96),
		Color3.fromRGB(255, 194, 64),
		{ N = true, S = false, W = true, E = false },
		{
			{ axis = "Z", minV = 193, maxV = 203, side = "N" },
		}
	)
	buildEscalator(decor, windows, "VipEast", Vector3.new(198, 0.4, 24), Vector3.new(198, 11.5, 46), 6.2, GameConfig.TERMINALS.FirstClass.accentColor)

	for _, pPos in ipairs({ Vector3.new(112, 0, -40), Vector3.new(186, 0, -40), Vector3.new(114, 0, 40) }) do
		buildPillar(opaqueCover, decor, "VipPillar", pPos, 1.8, AIRPORT_ROOF_Y, Color3.fromRGB(58, 64, 92), GameConfig.TERMINALS.FirstClass.accentColor)
	end
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(124, 0, 32), 0, Color3.fromRGB(168, 128, 48), Color3.fromRGB(234, 194, 86))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(172, 0, 12), 180, Color3.fromRGB(168, 128, 48), Color3.fromRGB(234, 194, 86))
	buildPlanterBed(opaqueCover, decor, Vector3.new(98, 0, 42), GameConfig.TERMINALS.FirstClass.accentColor)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "VIP Valet", "FirstClass", Vector3.new(148, 0, -18), 20, 9, 7.8, GameConfig.TERMINALS.FirstClass.accentColor))

	table.insert(restingSpots, { id = "VipSpot1", terminalId = "FirstClass", bagPos = Vector3.new(136, 0.4, 30), bagYaw = 0.2, ownerHomePos = Vector3.new(146, 0.4, 30), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(155, 0.4, 22) })
	table.insert(restingSpots, { id = "VipSpot2", terminalId = "FirstClass", bagPos = Vector3.new(164, 0.4, 38), bagYaw = -0.3, ownerHomePos = Vector3.new(176, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(186, 0.4, 34) })
	table.insert(restingSpots, { id = "VipSpot3", terminalId = "FirstClass", bagPos = Vector3.new(116, 0.4, -2), bagYaw = 0.8, ownerHomePos = Vector3.new(106, 0.4, 8), ownerLookAwayYaw = math.pi * 0.75, ownerWatchBagYaw = -math.pi * 0.75, patrolWaypoint = Vector3.new(106, 0.4, -18) })
	table.insert(restingSpots, { id = "VipSpot4", terminalId = "FirstClass", bagPos = Vector3.new(162, 0.4, -48), bagYaw = 0.1, ownerHomePos = Vector3.new(174, 0.4, -46), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(184, 0.4, -34) })

	-- CELEBRITY PRIVATE TERMINAL DETAILS + JET-VIEW TERRACE MEZZANINES & DUAL ESCALATORS
	-- Grounded overhead flight board suspended cleanly from Celebrity ceiling trusses (Y = 24.5)
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
		Enum.NormalId.Front
	)

	for _, pPos in ipairs({
		Vector3.new(-36, 0, -90), Vector3.new(36, 0, -90),
		Vector3.new(-36, 0, -158), Vector3.new(36, 0, -158),
		Vector3.new(-80, 0, -124), Vector3.new(80, 0, -124),
	}) do
		buildPillar(opaqueCover, decor, "CelebPillar", pPos, 2.0, AIRPORT_ROOF_Y, Color3.fromRGB(48, 44, 60), GameConfig.TERMINALS.Celebrity.accentColor)
	end

	-- Velvet ropes flanking Celebrity Red Carpet runway
	buildVelvetRopeLine(decor, Vector3.new(-10.5, 0, -76), Vector3.new(-10.5, 0, -104), Color3.fromRGB(198, 28, 64))
	buildVelvetRopeLine(decor, Vector3.new(10.5, 0, -76), Vector3.new(10.5, 0, -104), Color3.fromRGB(198, 28, 64))

	makePart(opaqueCover, "CelebBoothW", Vector3.new(14, 5.8, 4), CFrame.new(-64, 2.9, -98), Color3.fromRGB(64, 24, 58), Enum.Material.Marble, true)
	makePart(opaqueCover, "CelebBoothE", Vector3.new(14, 5.8, 4), CFrame.new(64, 2.9, -98), Color3.fromRGB(64, 24, 58), Enum.Material.Marble, true)
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(-64, 0, -148), 0, Color3.fromRGB(182, 42, 112), Color3.fromRGB(238, 198, 76))
	buildLeatherSeatingCluster(opaqueCover, Vector3.new(64, 0, -148), 0, Color3.fromRGB(182, 42, 112), Color3.fromRGB(238, 198, 76))
	buildPlanterBed(opaqueCover, decor, Vector3.new(-24, 0, -178), GameConfig.TERMINALS.Celebrity.accentColor)
	buildPlanterBed(opaqueCover, decor, Vector3.new(24, 0, -178), GameConfig.TERMINALS.Celebrity.accentColor)

	-- Celebrity VIP Jet-View Terrace Mezzanines & Dual Escalators (completely clear of ground spots)
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"CelebSouthTerrace",
		-114,
		114,
		-80,
		-61,
		11.5,
		Color3.fromRGB(48, 36, 56),
		Color3.fromRGB(255, 86, 152),
		{ N = true, S = false, W = false, E = false },
		{
			{ axis = "Z", minV = -114, maxV = -88, side = "N" },
			{ axis = "Z", minV = 88, maxV = 114, side = "N" },
		}
	)
	buildMezzanineDeck(
		decor,
		opaqueCover,
		windows,
		"CelebJetWalkW",
		-114,
		-96,
		-188,
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
		96,
		114,
		-188,
		-80,
		11.5,
		Color3.fromRGB(48, 36, 56),
		Color3.fromRGB(255, 86, 152),
		{ N = true, S = false, W = true, E = false },
		nil
	)
	buildEscalator(decor, windows, "CelebWest", Vector3.new(-92, 0.4, -104), Vector3.new(-92, 11.5, -80), 5.8, GameConfig.TERMINALS.Celebrity.accentColor)
	buildEscalator(decor, windows, "CelebEast", Vector3.new(92, 0.4, -104), Vector3.new(92, 11.5, -80), 5.8, GameConfig.TERMINALS.Celebrity.accentColor)

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Royal Valet", "Celebrity", Vector3.new(0, 0, -126), 24, 11, 8.6, GameConfig.TERMINALS.Celebrity.accentColor))

	table.insert(restingSpots, { id = "CelebSpot1", terminalId = "Celebrity", bagPos = Vector3.new(-54, 0.4, -108), bagYaw = 0.2, ownerHomePos = Vector3.new(-44, 0.4, -108), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(-44, 0.4, -128) })
	table.insert(restingSpots, { id = "CelebSpot2", terminalId = "Celebrity", bagPos = Vector3.new(54, 0.4, -108), bagYaw = -0.2, ownerHomePos = Vector3.new(44, 0.4, -108), ownerLookAwayYaw = 0, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(44, 0.4, -128) })
	table.insert(restingSpots, { id = "CelebSpot3", terminalId = "Celebrity", bagPos = Vector3.new(-74, 0.4, -158), bagYaw = 0.4, ownerHomePos = Vector3.new(-62, 0.4, -160), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(-50, 0.4, -162) })
	table.insert(restingSpots, { id = "CelebSpot4", terminalId = "Celebrity", bagPos = Vector3.new(74, 0.4, -158), bagYaw = -0.4, ownerHomePos = Vector3.new(62, 0.4, -160), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(50, 0.4, -162) })

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

-- Convenience helper so server doesn't duplicate LuggageVisuals calls
function WorldBuilder.CreateWorldBagModel(archetype: GameConfig.ArchetypeDef, cf: CFrame): Model
	return LuggageVisuals.BuildModel(archetype, cf, {
		scale = 1,
		anchored = true,
		withHingedLid = false,
		withRarityGlow = true,
	})
end

return WorldBuilder
