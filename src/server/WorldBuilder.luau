--!strict
-- Procedurally constructs the entire Airport Hub, Smuggler's Hideout, Carousels, Workbenches,
-- Shops, Gates, Passenger NPCs, and Security Guards.

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
	transparency: number?
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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
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
	face: Enum.NormalId?
): Part
	local panel = makePart(parent, name, size, cframe, bgColor, Enum.Material.SmoothPlastic, true, 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
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

	return panel
end

local function buildPillar(parent: Instance, name: string, pos: Vector3, radius: number, height: number, color: Color3, accent: Color3)
	makePart(parent, name, Vector3.new(radius * 2, height, radius * 2), CFrame.new(pos.X, height * 0.5, pos.Z), color, Enum.Material.Concrete, true)
	makePart(parent, name .. "_Base", Vector3.new(radius * 2 + 0.6, 1.2, radius * 2 + 0.6), CFrame.new(pos.X, 0.6, pos.Z), accent, Enum.Material.Metal, true)
	makePart(parent, name .. "_Glow", Vector3.new(radius * 2 + 0.15, 0.35, radius * 2 + 0.15), CFrame.new(pos.X, height - 1.5, pos.Z), accent, Enum.Material.Neon, false)
end

local function buildPottedPalm(parent: Instance, pos: Vector3)
	local pot = makePart(parent, "Planter", Vector3.new(3.4, 2.2, 3.4), CFrame.new(pos.X, 1.1, pos.Z), Color3.fromRGB(225, 226, 230), Enum.Material.SmoothPlastic, true)
	makePart(pot, "Soil", Vector3.new(2.9, 0.3, 2.9), CFrame.new(pos.X, 2.15, pos.Z), Color3.fromRGB(78, 56, 38), Enum.Material.Grass, false)
	makePart(pot, "Trunk", Vector3.new(0.7, 4.6, 0.7), CFrame.new(pos.X, 4.3, pos.Z), Color3.fromRGB(116, 82, 52), Enum.Material.Wood, false)
	for i = 1, 5 do
		local yaw = math.rad((i - 1) * 72)
		local cf = CFrame.new(pos.X, 6.6, pos.Z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -1.7) * CFrame.Angles(math.rad(-22), 0, 0)
		makePart(pot, "Frond" .. i, Vector3.new(1.1, 0.18, 3.4), cf, Color3.fromRGB(64, 152, 76), Enum.Material.Grass, false)
	end
end

local function buildBenchRow(parent: Instance, pos: Vector3, yawDeg: number, cushionColor: Color3)
	local origin = CFrame.new(pos.X, 0, pos.Z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	makePart(parent, "BenchSeat", Vector3.new(10, 0.45, 2.6), origin * CFrame.new(0, 1.5, 0), cushionColor, Enum.Material.Fabric, true)
	makePart(parent, "BenchBack", Vector3.new(10, 1.7, 0.4), origin * CFrame.new(0, 2.4, 1.1), cushionColor, Enum.Material.Fabric, true)
	makePart(parent, "BenchBeam", Vector3.new(9.2, 0.35, 0.8), origin * CFrame.new(0, 1.1, 0), Color3.fromRGB(162, 170, 180), Enum.Material.Metal, true)
	makePart(parent, "BenchLegL", Vector3.new(0.4, 1.1, 1.8), origin * CFrame.new(-3.8, 0.55, 0), Color3.fromRGB(96, 102, 112), Enum.Material.Metal, true)
	makePart(parent, "BenchLegR", Vector3.new(0.4, 1.1, 1.8), origin * CFrame.new(3.8, 0.55, 0), Color3.fromRGB(96, 102, 112), Enum.Material.Metal, true)
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

	-- Central island chute cover (blocks NPC vision across the carousel core!)
	makePart(coverParent, id .. "_CenterCore", Vector3.new(straightX + 4, 4.4, halfD * 0.9), CFrame.new(center.X, 2.2, center.Z), Color3.fromRGB(54, 60, 72), Enum.Material.Metal, true)
	makeSignBoard(
		model,
		id .. "_Sign",
		Vector3.new(10, 3.2, 0.8),
		CFrame.new(center.X, 6.2, center.Z),
		Color3.fromRGB(22, 26, 36),
		id:upper(),
		accentColor,
		"CLAIM BAGS CAREFULLY",
		Enum.NormalId.Front
	)
	makeSignBoard(
		model,
		id .. "_SignBack",
		Vector3.new(10, 3.2, 0.8),
		CFrame.new(center.X, 6.2, center.Z) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(22, 26, 36),
		id:upper(),
		accentColor,
		"CLAIM BAGS CAREFULLY",
		Enum.NormalId.Front
	)

	-- Base belt bed
	makePart(model, "BeltBase", Vector3.new(halfW * 2, 1.0, halfD * 2), CFrame.new(center.X, 0.5, center.Z), Color3.fromRGB(40, 44, 52), Enum.Material.SmoothPlastic, true)

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
	makePart(coverParent, terminalId .. "_GatePillarL", Vector3.new(2.4, 14, 2.4), origin * CFrame.new(-pillarOffset, 7, 0), Color3.fromRGB(36, 42, 54), Enum.Material.Metal, true)
	makePart(coverParent, terminalId .. "_GatePillarR", Vector3.new(2.4, 14, 2.4), origin * CFrame.new(pillarOffset, 7, 0), Color3.fromRGB(36, 42, 54), Enum.Material.Metal, true)
	makePart(coverParent, terminalId .. "_GateHeader", Vector3.new(width + 4.8, 2.8, 2.6), origin * CFrame.new(0, 12.6, 0), Color3.fromRGB(26, 30, 40), Enum.Material.Metal, true)

	makeSignBoard(
		windowsParent,
		terminalId .. "_GateMarquee",
		Vector3.new(width + 2, 2.4, 0.4),
		origin * CFrame.new(0, 12.6, 1.4),
		Color3.fromRGB(18, 22, 32),
		def.name:upper(),
		def.accentColor,
		string.format("TERMINAL PASS: %s", GameConfig.FormatCash(def.unlockCost)),
		Enum.NormalId.Front
	)
	makeSignBoard(
		windowsParent,
		terminalId .. "_GateMarqueeBack",
		Vector3.new(width + 2, 2.4, 0.4),
		origin * CFrame.new(0, 12.6, -1.4) * CFrame.Angles(0, math.pi, 0),
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
		Vector3.new(width, 10, 0.7),
		origin * CFrame.new(0, 5.2, 0),
		def.accentColor,
		Enum.Material.ForceField,
		true,
		0.45
	)
	barrier:SetAttribute("TerminalId", terminalId)

	-- Turnstile reader post in front of the barrier
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

local function buildWorkbench(parent: Instance, slotIndex: number, pos: Vector3): WorkbenchStation
	local model = Instance.new("Model")
	model.Name = "Workbench_" .. slotIndex
	model.Parent = parent

	local origin = CFrame.new(pos.X, 0.4, pos.Z)
	makePart(model, "DeskBase", Vector3.new(7.4, 3.1, 4.4), origin * CFrame.new(0, 1.55, 0), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, true)
	makePart(model, "DeskTop", Vector3.new(7.8, 0.35, 4.8), origin * CFrame.new(0, 3.25, 0), Color3.fromRGB(72, 78, 90), Enum.Material.DiamondPlate, true)

	local stripColor = if slotIndex == 1 then Color3.fromRGB(72, 224, 255) else Color3.fromRGB(110, 118, 132)
	local statusStrip = makePart(model, "StatusStrip", Vector3.new(7.6, 0.25, 0.35), origin * CFrame.new(0, 3.15, -2.45), stripColor, Enum.Material.Neon, false)

	-- Tool rack accent on back edge
	makePart(model, "Backboard", Vector3.new(7.2, 2.2, 0.35), origin * CFrame.new(0, 4.4, 2.1), Color3.fromRGB(36, 40, 50), Enum.Material.Metal, true)

	-- Overhead live status BillboardGui
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

	-- Eyes so direction is always readable even at a glance
	makePart(npc, "EyeL", Vector3.new(0.18, 0.18, 0.1), origin * CFrame.new(-0.28, 4.82, -0.66), Color3.fromRGB(22, 24, 30), Enum.Material.SmoothPlastic, false)
	makePart(npc, "EyeR", Vector3.new(0.18, 0.18, 0.1), origin * CFrame.new(0.28, 4.82, -0.66), Color3.fromRGB(22, 24, 30), Enum.Material.SmoothPlastic, false)

	-- Hair cap
	makePart(npc, "Hair", Vector3.new(1.38, 0.55, 1.38), origin * CFrame.new(0, 5.28, 0.06), hairColor, Enum.Material.SmoothPlastic, false)

	-- Limbs
	makePart(npc, "LeftArm", Vector3.new(0.85, 2.0, 0.85), origin * CFrame.new(-1.52, 3.0, 0), shirtColor, Enum.Material.Fabric, false)
	makePart(npc, "RightArm", Vector3.new(0.85, 2.0, 0.85), origin * CFrame.new(1.52, 3.0, 0), shirtColor, Enum.Material.Fabric, false)
	makePart(npc, "LeftLeg", Vector3.new(0.9, 2.0, 0.9), origin * CFrame.new(-0.55, 1.0, 0), trimColor, Enum.Material.SmoothPlastic, false)
	makePart(npc, "RightLeg", Vector3.new(0.9, 2.0, 0.9), origin * CFrame.new(0.55, 1.0, 0), trimColor, Enum.Material.SmoothPlastic, false)

	-- Distinctive matching accessory in tagColor / trimColor!
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

	-- Weld all parts cleanly to HumanoidRootPart so PivotTo / CFrame moves the whole rig seamlessly
	for _, descendant in ipairs(npc:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= hrp then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = descendant
			weld.Parent = hrp
		end
	end

	-- Status indicator icon above NPC head (? / ! / Distracted)
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
	Lighting.Ambient = Color3.fromRGB(95, 102, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 136, 152)
	Lighting.GlobalShadows = true
end

local function buildPrivateJet(parent: Instance)
	local jet = Instance.new("Model")
	jet.Name = "CelebrityPrivateJet"
	jet.Parent = parent

	local center = Vector3.new(12, 8.5, -226)
	-- Fuselage
	makePart(jet, "Fuselage", Vector3.new(44, 8, 8), CFrame.new(center), Color3.fromRGB(244, 246, 250), Enum.Material.SmoothPlastic, true)
	makePart(jet, "GoldStripe", Vector3.new(42, 1.1, 8.2), CFrame.new(center + Vector3.new(0, -0.5, 0)), Color3.fromRGB(255, 198, 62), Enum.Material.Neon, false)
	makePart(jet, "NoseCone", Vector3.new(7, 6.2, 6.2), CFrame.new(center + Vector3.new(-24.5, -0.5, 0)), Color3.fromRGB(238, 242, 248), Enum.Material.SmoothPlastic, true)
	makePart(jet, "CockpitGlass", Vector3.new(4, 2.2, 5.4), CFrame.new(center + Vector3.new(-21, 1.6, 0)), Color3.fromRGB(32, 56, 84), Enum.Material.Glass, false, 0.2)
	-- Wings
	makePart(jet, "MainWing", Vector3.new(12, 1.0, 42), CFrame.new(center + Vector3.new(2, -1.8, 0)), Color3.fromRGB(232, 236, 244), Enum.Material.SmoothPlastic, true)
	-- Tailfin
	makePart(jet, "TailFin", Vector3.new(7, 9, 1.2), CFrame.new(center + Vector3.new(18, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(-18)), Color3.fromRGB(255, 86, 152), Enum.Material.SmoothPlastic, true)
	-- Landing gear
	makePart(jet, "GearNose", Vector3.new(1.2, 4.5, 1.2), CFrame.new(center + Vector3.new(-16, -6.2, 0)), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
	makePart(jet, "GearMain", Vector3.new(2.0, 4.5, 8.0), CFrame.new(center + Vector3.new(3, -6.2, 0)), Color3.fromRGB(38, 40, 48), Enum.Material.Metal, true)
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

	-- Outer asphalt tarmac surrounding the facility
	makePart(decor, "TarmacNorth", Vector3.new(512, 0.2, 64), CFrame.new(0, 0.1, -224), Color3.fromRGB(54, 58, 66), Enum.Material.Asphalt, true)

	-- SpawnLocation in Back-Alley Courtyard facing North toward Airport Entrance
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "CourtyardSpawn"
	spawnLoc.Size = Vector3.new(10, 0.5, 10)
	spawnLoc.CFrame = CFrame.new(0, 0.25, 94)
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(48, 56, 70)
	spawnLoc.Material = Enum.Material.SmoothPlastic
	spawnLoc.Parent = decor

	-----------------------------------------------------------------------
	-- 1. SMUGGLER'S HIDEOUT (Z = 102..162, X = -68..68) & COURTYARD
	-----------------------------------------------------------------------
	makePart(decor, "HideoutFloor", Vector3.new(136, 0.4, 60), CFrame.new(0, 0.2, 132), Color3.fromRGB(40, 44, 52), Enum.Material.Concrete, true)
	makePart(decor, "CourtyardFloor", Vector3.new(136, 0.3, 37), CFrame.new(0, 0.15, 83.5), Color3.fromRGB(66, 70, 80), Enum.Material.Asphalt, true)

	-- Safe Zone threshold line + glowing floor chevrons
	makePart(decor, "SafeZoneLine", Vector3.new(24, 0.12, 1.2), CFrame.new(0, 0.44, 102), Color3.fromRGB(68, 255, 156), Enum.Material.Neon, false)
	for idx = 1, 3 do
		makePart(decor, "EscapeArrow_" .. idx, Vector3.new(4.5, 0.1, 2.2), CFrame.new(0, 0.34, 74 + idx * 8), Color3.fromRGB(68, 255, 156), Enum.Material.Neon, false, 0.25)
	end

	-- Hideout Perimeter Walls (North has wide 24-stud archway at X = -12..12)
	makePart(opaqueCover, "HideoutWallNL", Vector3.new(56, 16, 2), CFrame.new(-40, 8, 102), Color3.fromRGB(78, 56, 50), Enum.Material.Brick, true)
	makePart(opaqueCover, "HideoutWallNR", Vector3.new(56, 16, 2), CFrame.new(40, 8, 102), Color3.fromRGB(78, 56, 50), Enum.Material.Brick, true)
	makePart(opaqueCover, "HideoutArchHeader", Vector3.new(28, 4, 2.5), CFrame.new(0, 14, 102), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, true)
	makeSignBoard(
		decor,
		"HideoutSign",
		Vector3.new(24, 3.2, 0.5),
		CFrame.new(0, 14, 100.6) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(16, 20, 28),
		"SMUGGLER'S HIDEOUT",
		Color3.fromRGB(72, 255, 162),
		"SAFE ZONE • SECURE & CRACK STOLEN BAGS",
		Enum.NormalId.Front
	)
	makePart(opaqueCover, "HideoutWallS", Vector3.new(138, 16, 2), CFrame.new(0, 8, 162), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)
	makePart(opaqueCover, "HideoutWallW", Vector3.new(2, 16, 62), CFrame.new(-68, 8, 132), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)
	makePart(opaqueCover, "HideoutWallE", Vector3.new(2, 16, 62), CFrame.new(68, 8, 132), Color3.fromRGB(70, 52, 46), Enum.Material.Brick, true)

	-- Industrial lighting beams above Hideout (high Y=24 so camera never clips)
	for x = -48, 48, 32 do
		makePart(decor, "HideoutRafter_" .. x, Vector3.new(2, 1.2, 60), CFrame.new(x, 22, 132), Color3.fromRGB(32, 36, 44), Enum.Material.Metal, false)
		makePart(decor, "HideoutTube_" .. x, Vector3.new(0.8, 0.4, 48), CFrame.new(x, 21.3, 132), Color3.fromRGB(255, 214, 142), Enum.Material.Neon, false)
	end

	-- 4 Cracking Workbenches inside Hideout West/Center
	local workbenches: { WorkbenchStation } = {}
	local benchPositions = {
		Vector3.new(-46, 0, 130),
		Vector3.new(-30, 0, 130),
		Vector3.new(-14, 0, 130),
		Vector3.new(2, 0, 130),
	}
	for i, benchPos in ipairs(benchPositions) do
		table.insert(workbenches, buildWorkbench(decor, i, benchPos))
	end

	-- Shady Fence Sell Counter (East Hideout)
	local fenceModel = Instance.new("Model")
	fenceModel.Name = "FenceCounter"
	fenceModel.Parent = decor
	makePart(fenceModel, "CounterDesk", Vector3.new(12, 3.6, 4.2), CFrame.new(40, 2.2, 122), Color3.fromRGB(76, 50, 36), Enum.Material.Wood, true)
	makePart(fenceModel, "CounterTrim", Vector3.new(12.2, 0.35, 4.4), CFrame.new(40, 4.1, 122), Color3.fromRGB(255, 198, 62), Enum.Material.Metal, true)
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

	-- Black-Market Stealth & Tools Shop Kiosk (South-East Hideout)
	local shopModel = Instance.new("Model")
	shopModel.Name = "StealthShopKiosk"
	shopModel.Parent = decor
	makePart(shopModel, "ShopCounter", Vector3.new(12, 3.6, 4.2), CFrame.new(40, 2.2, 146), Color3.fromRGB(32, 44, 62), Enum.Material.Metal, true)
	makePart(shopModel, "ShopNeon", Vector3.new(12.2, 0.35, 4.4), CFrame.new(40, 4.1, 146), Color3.fromRGB(74, 208, 255), Enum.Material.Neon, false)
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

	-- Courtyard Terminal Pass Kiosk (Right side of Courtyard)
	local kiosk = makePart(decor, "TerminalPassKiosk", Vector3.new(6, 4.2, 3.2), CFrame.new(26, 2.2, 86), Color3.fromRGB(34, 42, 60), Enum.Material.Metal, true)
	makeSignBoard(
		decor,
		"TerminalKioskSign",
		Vector3.new(7, 2.8, 0.4),
		CFrame.new(26, 6.2, 86),
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

	-----------------------------------------------------------------------
	-- 2. SKYPORT TERMINAL FLOORS & OUTER SHELL
	-----------------------------------------------------------------------
	-- Zone 1: Domestic (X = -86..86, Z = -58..65)
	makePart(decor, "Floor_Domestic", Vector3.new(172, 0.4, 123), CFrame.new(0, 0.2, 3.5), GameConfig.TERMINALS.Domestic.floorColor, Enum.Material.Marble, true)
	-- Zone 2: International (X = -208..-86, Z = -58..65)
	makePart(decor, "Floor_International", Vector3.new(122, 0.4, 123), CFrame.new(-147, 0.2, 3.5), GameConfig.TERMINALS.International.floorColor, Enum.Material.SmoothPlastic, true)
	-- Zone 3: First-Class VIP (X = 86..208, Z = -58..65)
	makePart(decor, "Floor_FirstClass", Vector3.new(122, 0.4, 123), CFrame.new(147, 0.2, 3.5), GameConfig.TERMINALS.FirstClass.floorColor, Enum.Material.Fabric, true)
	-- Zone 4: Celebrity Private Terminal (X = -116..116, Z = -194..-58)
	makePart(decor, "Floor_Celebrity", Vector3.new(232, 0.4, 136), CFrame.new(0, 0.2, -126), GameConfig.TERMINALS.Celebrity.floorColor, Enum.Material.Marble, true)
	-- Red Carpet aisle inside Celebrity
	makePart(decor, "CelebrityRedCarpet", Vector3.new(18, 0.44, 120), CFrame.new(0, 0.22, -124), Color3.fromRGB(168, 24, 48), Enum.Material.Fabric, false)

	-- South Facade Wall (Z = 65) with Main Sliding Glass Entrance at X = -16..+16
	makePart(opaqueCover, "SouthWall_L1", Vector3.new(192, 4, 2), CFrame.new(-112, 2, 65), Color3.fromRGB(54, 62, 76), Enum.Material.Concrete, true)
	makePart(windows, "SouthGlass_L1", Vector3.new(192, 13, 0.8), CFrame.new(-112, 10.5, 65), Color3.fromRGB(156, 206, 236), Enum.Material.Glass, true, 0.6)
	makePart(opaqueCover, "SouthWall_R1", Vector3.new(192, 4, 2), CFrame.new(112, 2, 65), Color3.fromRGB(54, 62, 76), Enum.Material.Concrete, true)
	makePart(windows, "SouthGlass_R1", Vector3.new(192, 13, 0.8), CFrame.new(112, 10.5, 65), Color3.fromRGB(156, 206, 236), Enum.Material.Glass, true, 0.6)
	makePart(opaqueCover, "MainDoorHeader", Vector3.new(36, 4.5, 3), CFrame.new(0, 15.25, 65), Color3.fromRGB(30, 38, 52), Enum.Material.Metal, true)
	makeSignBoard(
		decor,
		"MainAirportMarquee",
		Vector3.new(32, 3.4, 0.6),
		CFrame.new(0, 15.2, 66.8),
		Color3.fromRGB(16, 22, 34),
		"SKYPORT INTERNATIONAL",
		Color3.fromRGB(82, 206, 255),
		"DOMESTIC • INTERNATIONAL • FIRST-CLASS • CELEBRITY",
		Enum.NormalId.Front
	)

	-- Outer East & West Walls of Lower Wings (Z = -58..65)
	makePart(opaqueCover, "WestOuterWall", Vector3.new(2, 17, 125), CFrame.new(-208, 8.5, 3.5), Color3.fromRGB(224, 228, 234), Enum.Material.Concrete, true)
	makePart(opaqueCover, "EastOuterWall", Vector3.new(2, 17, 125), CFrame.new(208, 8.5, 3.5), Color3.fromRGB(48, 46, 62), Enum.Material.Concrete, true)

	-- Dividing Wall at Z = -58 (North end of International, Domestic, FirstClass)
	-- International & FirstClass outer north walls:
	makePart(opaqueCover, "NorthWall_Intl", Vector3.new(92, 17, 2), CFrame.new(-162, 8.5, -58), Color3.fromRGB(210, 214, 220), Enum.Material.Concrete, true)
	makePart(opaqueCover, "NorthWall_Vip", Vector3.new(92, 17, 2), CFrame.new(162, 8.5, -58), Color3.fromRGB(48, 50, 68), Enum.Material.Concrete, true)
	-- Celebrity overhangs X = -116..-86 and 86..116, wall closes Z = -58 cleanly:
	makePart(opaqueCover, "CelebritySouthW", Vector3.new(100, 17, 2), CFrame.new(-66, 8.5, -58), Color3.fromRGB(42, 44, 56), Enum.Material.Concrete, true)
	makePart(opaqueCover, "CelebritySouthE", Vector3.new(100, 17, 2), CFrame.new(66, 8.5, -58), Color3.fromRGB(42, 44, 56), Enum.Material.Concrete, true)

	-- Celebrity North Glass Curtain Wall overlooking Private Jet (Z = -194)
	makePart(opaqueCover, "CelebrityBulkheadN", Vector3.new(232, 3.2, 2), CFrame.new(0, 1.6, -194), Color3.fromRGB(32, 34, 42), Enum.Material.Concrete, true)
	makePart(windows, "CelebrityGlassN", Vector3.new(232, 14, 0.8), CFrame.new(0, 10.2, -194), Color3.fromRGB(168, 214, 244), Enum.Material.Glass, true, 0.65)
	makePart(opaqueCover, "CelebrityWallW", Vector3.new(2, 17, 138), CFrame.new(-116, 8.5, -126), Color3.fromRGB(38, 40, 50), Enum.Material.Concrete, true)
	makePart(opaqueCover, "CelebrityWallE", Vector3.new(2, 17, 138), CFrame.new(116, 8.5, -126), Color3.fromRGB(38, 40, 50), Enum.Material.Concrete, true)

	-- Domestic <-> International Wall (X = -86, Z = -58..65, doorway Z = -22..0)
	makePart(opaqueCover, "WallDomIntl_N", Vector3.new(2, 17, 36), CFrame.new(-86, 8.5, -40), Color3.fromRGB(220, 224, 230), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomIntl_S", Vector3.new(2, 17, 65), CFrame.new(-86, 8.5, 32.5), Color3.fromRGB(220, 224, 230), Enum.Material.Concrete, true)

	-- Domestic <-> FirstClass Wall (X = +86, Z = -58..65, doorway Z = -22..0)
	makePart(opaqueCover, "WallDomVip_N", Vector3.new(2, 17, 36), CFrame.new(86, 8.5, -40), Color3.fromRGB(54, 58, 76), Enum.Material.Concrete, true)
	makePart(opaqueCover, "WallDomVip_S", Vector3.new(2, 17, 65), CFrame.new(86, 8.5, 32.5), Color3.fromRGB(54, 58, 76), Enum.Material.Concrete, true)

	-----------------------------------------------------------------------
	-- 3. SECURITY TURNSTILE GATES
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
	-- 4. INTERIOR ARCHITECTURE, COVER PROPS & CAROUSELS
	-----------------------------------------------------------------------
	local carousels: { CarouselTrack } = {}
	local restingSpots: { RestingSpot } = {}

	-- DOMESTIC DETAILS
	makeSignBoard(
		decor,
		"DepartureBoard",
		Vector3.new(32, 7.5, 1.4),
		CFrame.new(0, 12.5, 24),
		Color3.fromRGB(16, 20, 30),
		"DEPARTURES  |  FLIGHT 402 ON TIME",
		Color3.fromRGB(255, 208, 64),
		"GATE A1 TOKYO • GATE B4 PARIS • GATE C9 ZURICH",
		Enum.NormalId.Front
	)
	makePart(opaqueCover, "BoardColL", Vector3.new(2.2, 12, 2.2), CFrame.new(-16, 6, 24), Color3.fromRGB(156, 166, 180), Enum.Material.Metal, true)
	makePart(opaqueCover, "BoardColR", Vector3.new(2.2, 12, 2.2), CFrame.new(16, 6, 24), Color3.fromRGB(156, 166, 180), Enum.Material.Metal, true)

	-- Check-in desks & pillars (great stealth cover!)
	makePart(opaqueCover, "CheckInWest", Vector3.new(18, 3.8, 4.5), CFrame.new(-52, 1.9, 44), Color3.fromRGB(230, 234, 240), Enum.Material.SmoothPlastic, true)
	makePart(opaqueCover, "CheckInEast", Vector3.new(18, 3.8, 4.5), CFrame.new(52, 1.9, 44), Color3.fromRGB(230, 234, 240), Enum.Material.SmoothPlastic, true)
	for _, pPos in ipairs({
		Vector3.new(-24, 0, 42), Vector3.new(24, 0, 42),
		Vector3.new(-24, 0, 6), Vector3.new(24, 0, 6),
		Vector3.new(-66, 0, 10), Vector3.new(66, 0, 10),
	}) do
		buildPillar(opaqueCover, "DomPillar", pPos, 1.8, 16, Color3.fromRGB(234, 238, 244), GameConfig.TERMINALS.Domestic.accentColor)
	end
	for _, palmPos in ipairs({ Vector3.new(-19, 0, 56), Vector3.new(19, 0, 56), Vector3.new(0, 0, -40) }) do
		buildPottedPalm(opaqueCover, palmPos)
	end
	buildBenchRow(opaqueCover, Vector3.new(-44, 0, 12), 0, Color3.fromRGB(58, 112, 168))
	buildBenchRow(opaqueCover, Vector3.new(44, 0, 12), 0, Color3.fromRGB(58, 112, 168))
	buildBenchRow(opaqueCover, Vector3.new(0, 0, -6), 90, Color3.fromRGB(58, 112, 168))

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Claim 1", "Domestic", Vector3.new(-44, 0, -18), 18, 9, 6.2, GameConfig.TERMINALS.Domestic.accentColor))
	table.insert(carousels, buildCarousel(decor, opaqueCover, "Claim 2", "Domestic", Vector3.new(44, 0, -18), 18, 9, 6.2, GameConfig.TERMINALS.Domestic.accentColor))

	-- Domestic resting spots near benches & check-in
	table.insert(restingSpots, { id = "DomSpot1", terminalId = "Domestic", bagPos = Vector3.new(-52, 0.4, 15), bagYaw = 0.2, ownerHomePos = Vector3.new(-44, 0.4, 16), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.48, patrolWaypoint = Vector3.new(-35, 0.4, 16) })
	table.insert(restingSpots, { id = "DomSpot2", terminalId = "Domestic", bagPos = Vector3.new(52, 0.4, 15), bagYaw = -0.3, ownerHomePos = Vector3.new(44, 0.4, 16), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.48, patrolWaypoint = Vector3.new(35, 0.4, 16) })
	table.insert(restingSpots, { id = "DomSpot3", terminalId = "Domestic", bagPos = Vector3.new(-40, 0.4, 41), bagYaw = 0, ownerHomePos = Vector3.new(-50, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = -math.pi * 0.55, patrolWaypoint = Vector3.new(-58, 0.4, 38) })
	table.insert(restingSpots, { id = "DomSpot4", terminalId = "Domestic", bagPos = Vector3.new(40, 0.4, 41), bagYaw = 0, ownerHomePos = Vector3.new(50, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.55, patrolWaypoint = Vector3.new(58, 0.4, 38) })
	table.insert(restingSpots, { id = "DomSpot5", terminalId = "Domestic", bagPos = Vector3.new(0, 0.4, -14), bagYaw = 0.5, ownerHomePos = Vector3.new(5, 0.4, -4), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = 0.4, patrolWaypoint = Vector3.new(6, 0.4, 6) })

	-- INTERNATIONAL CONCOURSE DETAILS (X = -208..-86, Z = -58..65)
	makePart(opaqueCover, "DutyFreeIsland1", Vector3.new(20, 5.2, 10), CFrame.new(-178, 2.6, 26), Color3.fromRGB(142, 98, 62), Enum.Material.Wood, true)
	makePart(opaqueCover, "DutyFreeIsland2", Vector3.new(20, 5.2, 10), CFrame.new(-120, 2.6, 26), Color3.fromRGB(64, 128, 114), Enum.Material.SmoothPlastic, true)
	makeSignBoard(
		decor,
		"DutyFreeSign",
		Vector3.new(18, 3, 0.6),
		CFrame.new(-148, 10, 48),
		Color3.fromRGB(22, 32, 34),
		"INTERNATIONAL DUTY-FREE",
		GameConfig.TERMINALS.International.accentColor,
		"PASSPORT CONTROL & CUSTOMS",
		Enum.NormalId.Front
	)
	for _, pPos in ipairs({ Vector3.new(-186, 0, -40), Vector3.new(-112, 0, -40), Vector3.new(-148, 0, 10) }) do
		buildPillar(opaqueCover, "IntlPillar", pPos, 1.8, 16, Color3.fromRGB(218, 206, 184), GameConfig.TERMINALS.International.accentColor)
	end
	buildBenchRow(opaqueCover, Vector3.new(-148, 0, 18), 0, Color3.fromRGB(48, 148, 108))
	buildPottedPalm(opaqueCover, Vector3.new(-194, 0, 46))
	buildPottedPalm(opaqueCover, Vector3.new(-102, 0, 46))

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Intl Claim 3", "International", Vector3.new(-148, 0, -18), 22, 10, 7.2, GameConfig.TERMINALS.International.accentColor))

	table.insert(restingSpots, { id = "IntlSpot1", terminalId = "International", bagPos = Vector3.new(-164, 0.4, 24), bagYaw = 0.2, ownerHomePos = Vector3.new(-156, 0.4, 14), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = 0.4, patrolWaypoint = Vector3.new(-142, 0.4, 14) })
	table.insert(restingSpots, { id = "IntlSpot2", terminalId = "International", bagPos = Vector3.new(-132, 0.4, 24), bagYaw = -0.3, ownerHomePos = Vector3.new(-140, 0.4, 14), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -0.4, patrolWaypoint = Vector3.new(-126, 0.4, 10) })
	table.insert(restingSpots, { id = "IntlSpot3", terminalId = "International", bagPos = Vector3.new(-186, 0.4, 4), bagYaw = 1.1, ownerHomePos = Vector3.new(-180, 0.4, -6), ownerLookAwayYaw = -math.pi * 0.5, ownerWatchBagYaw = 0.35, patrolWaypoint = Vector3.new(-174, 0.4, -14) })
	table.insert(restingSpots, { id = "IntlSpot4", terminalId = "International", bagPos = Vector3.new(-124, 0.4, -44), bagYaw = 0, ownerHomePos = Vector3.new(-136, 0.4, -44), ownerLookAwayYaw = math.pi * 0.5, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(-152, 0.4, -44) })

	-- FIRST-CLASS VIP LOUNGE DETAILS (X = 86..208, Z = -58..65)
	makePart(opaqueCover, "VipBarCounter", Vector3.new(24, 4.2, 6), CFrame.new(174, 2.1, 28), Color3.fromRGB(36, 28, 42), Enum.Material.Marble, true)
	makePart(decor, "VipBarGold", Vector3.new(24.2, 0.35, 6.2), CFrame.new(174, 4.3, 28), Color3.fromRGB(255, 198, 64), Enum.Material.Metal, false)
	makePart(opaqueCover, "VipDivider1", Vector3.new(16, 6.5, 1.4), CFrame.new(124, 3.25, 22), Color3.fromRGB(98, 68, 42), Enum.Material.Wood, true)
	makePart(opaqueCover, "VipDivider2", Vector3.new(16, 6.5, 1.4), CFrame.new(148, 3.25, -42), Color3.fromRGB(98, 68, 42), Enum.Material.Wood, true)
	for _, pPos in ipairs({ Vector3.new(112, 0, -40), Vector3.new(186, 0, -40), Vector3.new(114, 0, 44) }) do
		buildPillar(opaqueCover, "VipPillar", pPos, 1.8, 16, Color3.fromRGB(58, 64, 92), GameConfig.TERMINALS.FirstClass.accentColor)
	end
	buildBenchRow(opaqueCover, Vector3.new(124, 0, 32), 0, Color3.fromRGB(168, 128, 48))
	buildBenchRow(opaqueCover, Vector3.new(174, 0, 12), 180, Color3.fromRGB(168, 128, 48))

	table.insert(carousels, buildCarousel(decor, opaqueCover, "VIP Valet", "FirstClass", Vector3.new(148, 0, -18), 20, 9, 7.8, GameConfig.TERMINALS.FirstClass.accentColor))

	table.insert(restingSpots, { id = "VipSpot1", terminalId = "FirstClass", bagPos = Vector3.new(136, 0.4, 30), bagYaw = 0.2, ownerHomePos = Vector3.new(146, 0.4, 30), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(155, 0.4, 22) })
	table.insert(restingSpots, { id = "VipSpot2", terminalId = "FirstClass", bagPos = Vector3.new(164, 0.4, 38), bagYaw = -0.3, ownerHomePos = Vector3.new(176, 0.4, 38), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(186, 0.4, 34) })
	table.insert(restingSpots, { id = "VipSpot3", terminalId = "FirstClass", bagPos = Vector3.new(116, 0.4, -2), bagYaw = 0.8, ownerHomePos = Vector3.new(106, 0.4, 8), ownerLookAwayYaw = math.pi * 0.75, ownerWatchBagYaw = -math.pi * 0.75, patrolWaypoint = Vector3.new(106, 0.4, -18) })
	table.insert(restingSpots, { id = "VipSpot4", terminalId = "FirstClass", bagPos = Vector3.new(162, 0.4, -48), bagYaw = 0.1, ownerHomePos = Vector3.new(174, 0.4, -46), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(184, 0.4, -34) })

	-- CELEBRITY PRIVATE TERMINAL DETAILS (X = -116..116, Z = -194..-58)
	buildPrivateJet(decor)
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
		buildPillar(opaqueCover, "CelebPillar", pPos, 2.0, 17, Color3.fromRGB(48, 44, 60), GameConfig.TERMINALS.Celebrity.accentColor)
	end
	makePart(opaqueCover, "CelebBoothW", Vector3.new(14, 5.8, 4), CFrame.new(-64, 2.9, -98), Color3.fromRGB(64, 24, 58), Enum.Material.Marble, true)
	makePart(opaqueCover, "CelebBoothE", Vector3.new(14, 5.8, 4), CFrame.new(64, 2.9, -98), Color3.fromRGB(64, 24, 58), Enum.Material.Marble, true)
	buildBenchRow(opaqueCover, Vector3.new(-64, 0, -148), 0, Color3.fromRGB(182, 42, 112))
	buildBenchRow(opaqueCover, Vector3.new(64, 0, -148), 0, Color3.fromRGB(182, 42, 112))

	table.insert(carousels, buildCarousel(decor, opaqueCover, "Royal Valet", "Celebrity", Vector3.new(0, 0, -126), 24, 11, 8.6, GameConfig.TERMINALS.Celebrity.accentColor))

	table.insert(restingSpots, { id = "CelebSpot1", terminalId = "Celebrity", bagPos = Vector3.new(-54, 0.4, -108), bagYaw = 0.2, ownerHomePos = Vector3.new(-44, 0.4, -108), ownerLookAwayYaw = 0, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(-44, 0.4, -128) })
	table.insert(restingSpots, { id = "CelebSpot2", terminalId = "Celebrity", bagPos = Vector3.new(54, 0.4, -108), bagYaw = -0.2, ownerHomePos = Vector3.new(44, 0.4, -108), ownerLookAwayYaw = 0, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(44, 0.4, -128) })
	table.insert(restingSpots, { id = "CelebSpot3", terminalId = "Celebrity", bagPos = Vector3.new(-74, 0.4, -158), bagYaw = 0.4, ownerHomePos = Vector3.new(-62, 0.4, -160), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = math.pi * 0.5, patrolWaypoint = Vector3.new(-50, 0.4, -162) })
	table.insert(restingSpots, { id = "CelebSpot4", terminalId = "Celebrity", bagPos = Vector3.new(74, 0.4, -158), bagYaw = -0.4, ownerHomePos = Vector3.new(62, 0.4, -160), ownerLookAwayYaw = math.pi, ownerWatchBagYaw = -math.pi * 0.5, patrolWaypoint = Vector3.new(50, 0.4, -162) })

	-----------------------------------------------------------------------
	-- 5. SECURITY PATROL ROUTES
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
