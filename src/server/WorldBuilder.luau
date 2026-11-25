--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

export type DiningTableRefs = {
	model: Model,
	tableTop: BasePart,
	seats: { Seat },
}

export type PlotData = {
	index: number,
	origin: CFrame,
	owner: Player?,
	rootModel: Model,
	interiorModel: Model?,
	spawnLocation: SpawnLocation?,
	supplyStation: Model?,
	prepCounter: Model?,
	cookingStove: Model?,
	servingCounter: Model?,
	diningTables: { DiningTableRefs },
}

export type TrafficCenterlines = {
	plazaRadius: number,
	westCurve: { Vector3 },
	eastCurve: { Vector3 },
	northCurve: { Vector3 },
	southCurve: { Vector3 },
}

type PartSpec = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	canQuery: boolean?,
	shape: Enum.PartType?,
	parent: Instance,
}

local WorldBuilder = {}

local CITY_WORLD_NAME = "CityWorld"
local FLOOR_TOP_Y = 0.50
local CAFE_FLOOR_TOP_Y = 0.55

local PLAZA_RADIUS = 26
local ROAD_WIDTH = 22
local ROUNDABOUT_CENTER_RADIUS = 37
local SIDEWALK_WIDTH = 8
local PLAYABLE_BOUNDARY_RADIUS = 148
local SKYLINE_EXTENT = 780

local PALETTE = {
	Asphalt = Color3.fromRGB(58, 62, 72),
	RoadLine = Color3.fromRGB(246, 244, 238),
	Sidewalk = Color3.fromRGB(232, 228, 220),
	OuterGround = Color3.fromRGB(214, 212, 206),
	PlazaStone = Color3.fromRGB(246, 238, 234),
	PlazaTrim = Color3.fromRGB(255, 198, 218),
	Grass = Color3.fromRGB(168, 222, 166),
	Bark = Color3.fromRGB(134, 98, 82),
	SakuraLeaf = Color3.fromRGB(255, 182, 212),
	SakuraLeafAlt = Color3.fromRGB(255, 204, 226),
	LampPost = Color3.fromRGB(76, 82, 96),
	LampGlow = Color3.fromRGB(255, 238, 194),
	ShrineRed = Color3.fromRGB(238, 108, 128),
	ShrineWood = Color3.fromRGB(246, 232, 218),
	ShrineGold = Color3.fromRGB(255, 214, 120),
	CafeWall = Color3.fromRGB(255, 248, 242),
	CafeTrim = Color3.fromRGB(255, 178, 206),
	CafeFloor = Color3.fromRGB(238, 216, 190),
	CafeCounter = Color3.fromRGB(252, 250, 254),
	CafeMint = Color3.fromRGB(186, 238, 220),
	CafeGlass = Color3.fromRGB(212, 242, 255),
	StoveMetal = Color3.fromRGB(214, 220, 230),
	CrateWood = Color3.fromRGB(220, 184, 140),
	InteriorLamp = Color3.fromRGB(255, 244, 216),
	SkylineColors = {
		Color3.fromRGB(228, 230, 238),
		Color3.fromRGB(240, 234, 226),
		Color3.fromRGB(218, 224, 236),
		Color3.fromRGB(246, 228, 236),
		Color3.fromRGB(214, 228, 226),
	},
}

-- 4 spacious 60x58 restaurant plots aligned along the sweeping curved avenues around the plaza
local PLOT_ORIGINS: { CFrame } = {
	CFrame.new(-86, 0, -48) * CFrame.Angles(0, math.rad(-10), 0), -- Plot 1 (NW, faces West Ave)
	CFrame.new(48, 0, -86) * CFrame.Angles(0, math.rad(-100), 0), -- Plot 2 (NE, faces North Ave)
	CFrame.new(-48, 0, 86) * CFrame.Angles(0, math.rad(80), 0), -- Plot 3 (SW, faces South Ave)
	CFrame.new(86, 0, 48) * CFrame.Angles(0, math.rad(170), 0), -- Plot 4 (SE, faces East Ave)
}

-- Sweeping S-curve control points extending 780+ studs so no straight road reaches any edge
local EAST_CONTROL_POINTS: { Vector3 } = {
	Vector3.new(38, 0, 0),
	Vector3.new(88, 0, -10),
	Vector3.new(150, 0, -34),
	Vector3.new(235, 0, -82),
	Vector3.new(370, 0, -175),
	Vector3.new(560, 0, -330),
	Vector3.new(790, 0, -540),
}

local NORTH_CONTROL_POINTS: { Vector3 } = {
	Vector3.new(0, 0, -38),
	Vector3.new(-10, 0, -88),
	Vector3.new(-34, 0, -150),
	Vector3.new(-82, 0, -235),
	Vector3.new(-175, 0, -370),
	Vector3.new(-330, 0, -560),
	Vector3.new(-540, 0, -790),
}

local worldRoot: Model? = nil
local gachaPrompt: ProximityPrompt? = nil
local plots: { PlotData } = {}
local playerToPlot: { [Player]: PlotData } = {}
local roadCollisionPoints: { Vector3 } = {}
local cachedTrafficCenterlines: TrafficCenterlines? = nil

local function createPart(spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Anchored = true
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.CanCollide = if spec.canCollide ~= nil then spec.canCollide else true
	if spec.canQuery ~= nil then
		part.CanQuery = spec.canQuery
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.shape then
		part.Shape = spec.shape
	end
	part.Parent = spec.parent
	return part
end

local function createSurfaceLabel(
	parent: BasePart,
	face: Enum.NormalId,
	titleText: string,
	subtitleText: string?,
	bgColor: Color3,
	textColor: Color3
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = bgColor
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = if subtitleText then UDim2.fromScale(1, 0.58) else UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextColor3 = textColor
	title.TextScaled = true
	title.Parent = frame

	if subtitleText then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.Position = UDim2.fromScale(0, 0.6)
		sub.Size = UDim2.fromScale(1, 0.38)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamMedium
		sub.Text = subtitleText
		sub.TextColor3 = textColor
		sub.TextScaled = true
		sub.Parent = frame
	end

	return gui
end

local function configureBrightAnimeLighting()
	Lighting.Ambient = Color3.fromRGB(105, 102, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 115, 125)
	Lighting.Brightness = 1.45
	Lighting.ExposureCompensation = -0.25
	Lighting.ClockTime = 14.5
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 232)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "SakuraCityAtmosphere"
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(246, 228, 238)
	atmosphere.Decay = Color3.fromRGB(210, 202, 224)
	atmosphere.Glare = 0.05
	atmosphere.Haze = 1.25
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChild("SakuraBloom") :: BloomEffect?
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "SakuraBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.10
	bloom.Size = 14
	bloom.Threshold = 1.8

	local colorCorrection = Lighting:FindFirstChild("SakuraColorCorrection") :: ColorCorrectionEffect?
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "SakuraColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0.03
	colorCorrection.Saturation = 0.08
end

local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (
		(2 * p1)
		+ (-p0 + p2) * t
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
		+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

local function sampleSplinePoints(controlPoints: { Vector3 }, stepsPerSegment: number): { Vector3 }
	local result: { Vector3 } = {}
	local count = #controlPoints
	for i = 1, count - 1 do
		local p0 = controlPoints[math.max(1, i - 1)]
		local p1 = controlPoints[i]
		local p2 = controlPoints[i + 1]
		local p3 = controlPoints[math.min(count, i + 2)]
		for s = 0, stepsPerSegment - 1 do
			local t = s / stepsPerSegment
			table.insert(result, catmullRom(p0, p1, p2, p3, t))
		end
	end
	table.insert(result, controlPoints[count])
	return result
end

local function mirrorPoints180(points: { Vector3 }): { Vector3 }
	local mirrored: { Vector3 } = {}
	for _, p in points do
		table.insert(mirrored, Vector3.new(-p.X, p.Y, -p.Z))
	end
	return mirrored
end

local function buildCherryBlossomTree(parent: Instance, basePos: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = "CherryBlossomTree"
	model.Parent = parent

	local trunkHeight = 7 * scale
	createPart({
		name = "Trunk",
		size = Vector3.new(1.5 * scale, trunkHeight, 1.5 * scale),
		cframe = CFrame.new(basePos + Vector3.new(0, trunkHeight * 0.5, 0)),
		color = PALETTE.Bark,
		material = Enum.Material.Wood,
		parent = model,
	})

	local canopyCenter = basePos + Vector3.new(0, trunkHeight + 1.8 * scale, 0)
	local canopyClusters = {
		{ offset = Vector3.new(0, 0.8 * scale, 0), size = Vector3.new(7 * scale, 5.5 * scale, 7 * scale), color = PALETTE.SakuraLeaf },
		{ offset = Vector3.new(-2.2 * scale, -0.4 * scale, 1.2 * scale), size = Vector3.new(5 * scale, 4.2 * scale, 5 * scale), color = PALETTE.SakuraLeafAlt },
		{ offset = Vector3.new(2.3 * scale, -0.2 * scale, -1.3 * scale), size = Vector3.new(5 * scale, 4.2 * scale, 5 * scale), color = PALETTE.SakuraLeafAlt },
		{ offset = Vector3.new(0.4 * scale, 2.2 * scale, 0.5 * scale), size = Vector3.new(4.5 * scale, 3.6 * scale, 4.5 * scale), color = PALETTE.SakuraLeaf },
	}

	for index, cluster in canopyClusters do
		createPart({
			name = `Canopy_{index}`,
			size = cluster.size,
			cframe = CFrame.new(canopyCenter + cluster.offset),
			color = cluster.color,
			shape = Enum.PartType.Ball,
			parent = model,
		})
	end
end

local function buildStreetlight(parent: Instance, basePos: Vector3, armDir: Vector3, withLight: boolean)
	local model = Instance.new("Model")
	model.Name = "Streetlight"
	model.Parent = parent

	createPart({
		name = "Base",
		size = Vector3.new(1.2, 0.6, 1.2),
		cframe = CFrame.new(basePos + Vector3.new(0, 0.3, 0)),
		color = PALETTE.LampPost,
		parent = model,
	})
	createPart({
		name = "Pole",
		size = Vector3.new(0.55, 11, 0.55),
		cframe = CFrame.new(basePos + Vector3.new(0, 5.8, 0)),
		color = PALETTE.LampPost,
		parent = model,
	})

	local armOffset = armDir.Unit * 1.4
	createPart({
		name = "Arm",
		size = Vector3.new(0.4, 0.4, 3.0),
		cframe = CFrame.lookAt(basePos + Vector3.new(0, 11.2, 0) + armOffset, basePos + Vector3.new(0, 11.2, 0) + armOffset * 2),
		color = PALETTE.LampPost,
		parent = model,
	})

	local bulb = createPart({
		name = "LampHead",
		size = Vector3.new(1.1, 0.6, 1.1),
		cframe = CFrame.new(basePos + Vector3.new(0, 10.8, 0) + armOffset * 1.8),
		color = PALETTE.LampGlow,
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})

	if withLight then
		local light = Instance.new("PointLight")
		light.Color = PALETTE.LampGlow
		light.Brightness = 0.85
		light.Range = 26
		light.Shadows = false
		light.Parent = bulb
	end
end

local function buildCrosswalkAtCFrame(parent: Instance, roadCenterCF: CFrame, roadWidth: number)
	local stripeCount = 6
	local spacing = 2.6
	local startOffset = -((stripeCount - 1) * spacing) * 0.5

	for i = 0, stripeCount - 1 do
		local xOffset = startOffset + i * spacing
		createPart({
			name = "CrosswalkStripe",
			size = Vector3.new(1.2, 0.04, roadWidth - 3.0),
			cframe = roadCenterCF * CFrame.new(xOffset, 0.08, 0),
			color = PALETTE.RoadLine,
			canCollide = false,
			parent = parent,
		})
	end
end

local function buildPlazaBench(parent: Instance, cframe: CFrame)
	local bench = Instance.new("Model")
	bench.Name = "PlazaBench"
	bench.Parent = parent

	createPart({
		name = "BenchSeat",
		size = Vector3.new(5.6, 0.45, 2.0),
		cframe = cframe * CFrame.new(0, 1.4, 0),
		color = PALETTE.ShrineWood,
		material = Enum.Material.Wood,
		parent = bench,
	})
	createPart({
		name = "BenchBack",
		size = Vector3.new(5.6, 1.6, 0.4),
		cframe = cframe * CFrame.new(0, 2.4, 0.8),
		color = PALETTE.CafeTrim,
		parent = bench,
	})
	for _, xLeg in { -2.2, 2.2 } do
		createPart({
			name = "BenchLeg",
			size = Vector3.new(0.5, 1.2, 1.8),
			cframe = cframe * CFrame.new(xLeg, 0.6, 0),
			color = PALETTE.LampPost,
			parent = bench,
		})
	end
end

local function buildVendingMachine(parent: Instance, cframe: CFrame, bodyColor: Color3)
	local vm = Instance.new("Model")
	vm.Name = "VendingMachine"
	vm.Parent = parent

	createPart({
		name = "MachineBody",
		size = Vector3.new(2.6, 4.6, 1.8),
		cframe = cframe * CFrame.new(0, 2.3, 0),
		color = bodyColor,
		parent = vm,
	})
	createPart({
		name = "DisplayPanel",
		size = Vector3.new(2.0, 2.3, 0.2),
		cframe = cframe * CFrame.new(0, 2.8, -0.88),
		color = Color3.fromRGB(232, 248, 255),
		parent = vm,
	})
	createPart({
		name = "PickupSlot",
		size = Vector3.new(1.8, 0.65, 0.22),
		cframe = cframe * CFrame.new(0, 0.9, -0.88),
		color = PALETTE.LampPost,
		parent = vm,
	})
end

local function buildBushCluster(parent: Instance, basePos: Vector3)
	local bush = Instance.new("Model")
	bush.Name = "BushCluster"
	bush.Parent = parent

	local puffs = {
		{ offset = Vector3.new(0, 1.0, 0), size = Vector3.new(2.8, 2.2, 2.8), color = Color3.fromRGB(142, 206, 148) },
		{ offset = Vector3.new(-1.3, 0.8, 0.4), size = Vector3.new(2.1, 1.7, 2.1), color = Color3.fromRGB(158, 218, 162) },
		{ offset = Vector3.new(1.3, 0.85, -0.3), size = Vector3.new(2.2, 1.8, 2.2), color = Color3.fromRGB(132, 196, 140) },
	}
	for index, p in puffs do
		createPart({
			name = `BushPuff_{index}`,
			size = p.size,
			cframe = CFrame.new(basePos + p.offset),
			color = p.color,
			shape = Enum.PartType.Ball,
			parent = bush,
		})
	end
end

local function buildCrosswalkSignal(parent: Instance, basePos: Vector3, yawRad: number)
	local signal = Instance.new("Model")
	signal.Name = "CrosswalkSignal"
	signal.Parent = parent

	local cf = CFrame.new(basePos) * CFrame.Angles(0, yawRad, 0)
	createPart({
		name = "Pole",
		size = Vector3.new(0.45, 7.2, 0.45),
		cframe = cf * CFrame.new(0, 3.6, 0),
		color = PALETTE.LampPost,
		parent = signal,
	})
	createPart({
		name = "SignalBox",
		size = Vector3.new(1.1, 2.2, 0.9),
		cframe = cf * CFrame.new(0, 6.2, -0.45),
		color = PALETTE.LampPost,
		parent = signal,
	})
	createPart({
		name = "RedLens",
		size = Vector3.new(0.55, 0.55, 0.18),
		cframe = cf * CFrame.new(0, 6.7, -0.9),
		color = Color3.fromRGB(245, 110, 120),
		parent = signal,
	})
	createPart({
		name = "GreenLens",
		size = Vector3.new(0.55, 0.55, 0.18),
		cframe = cf * CFrame.new(0, 5.7, -0.9),
		color = Color3.fromRGB(122, 232, 168),
		parent = signal,
	})
end

local function buildBusStopShelter(parent: Instance, cf: CFrame)
	local shelter = Instance.new("Model")
	shelter.Name = "BusStopShelter"
	shelter.Parent = parent

	createPart({
		name = "BackGlass",
		size = Vector3.new(8.5, 6.5, 0.3),
		cframe = cf * CFrame.new(0, 3.25, 1.5),
		color = PALETTE.CafeGlass,
		material = Enum.Material.Glass,
		transparency = 0.4,
		parent = shelter,
	})
	createPart({
		name = "Canopy",
		size = Vector3.new(9.4, 0.45, 3.8),
		cframe = cf * CFrame.new(0, 6.7, 0.1),
		color = PALETTE.CafeTrim,
		parent = shelter,
	})
	for _, xPost in { -4.1, 4.1 } do
		createPart({
			name = "Post",
			size = Vector3.new(0.45, 6.5, 0.45),
			cframe = cf * CFrame.new(xPost, 3.25, 1.5),
			color = PALETTE.LampPost,
			parent = shelter,
		})
	end
	buildPlazaBench(shelter, cf * CFrame.new(0, 0, 0.4))
end

local function buildUrbanStoreBuilding(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	depth: number,
	wallColor: Color3,
	trimColor: Color3,
	titleText: string,
	subtitleText: string,
	doubleFaced: boolean?
)
	local bldg = Instance.new("Model")
	bldg.Name = titleText
	bldg.Parent = parent

	createPart({
		name = "MainBody",
		size = Vector3.new(width, height, depth),
		cframe = cf * CFrame.new(0, height * 0.5, 0),
		color = wallColor,
		parent = bldg,
	})
	createPart({
		name = "RoofParapet",
		size = Vector3.new(width + 0.8, 1.4, depth + 0.8),
		cframe = cf * CFrame.new(0, height + 0.7, 0),
		color = trimColor,
		parent = bldg,
	})
	createPart({
		name = "RooftopUnit",
		size = Vector3.new(math.min(6, width * 0.28), 3.0, math.min(6, depth * 0.25)),
		cframe = cf * CFrame.new(width * 0.22, height + 2.9, 0),
		color = PALETTE.StoveMetal,
		parent = bldg,
	})

	local faces = if doubleFaced then { -1, 1 } else { -1 }
	local floors = math.max(1, math.floor((height - 10) / 6.5))
	local windowCols = if width >= 30 then { -width * 0.3, 0, width * 0.3 } else { -width * 0.24, width * 0.24 }

	for _, zSign in faces do
		local faceCF = if zSign < 0 then cf else cf * CFrame.Angles(0, math.pi, 0)
		local frontZ = -depth * 0.5

		createPart({
			name = "StorefrontGlass",
			size = Vector3.new(width - 4, 5.2, 0.35),
			cframe = faceCF * CFrame.new(0, 3.2, frontZ - 0.05),
			color = PALETTE.CafeGlass,
			material = Enum.Material.Glass,
			transparency = 0.35,
			parent = bldg,
		})
		createPart({
			name = "Awning",
			size = Vector3.new(width - 2.5, 0.55, 3.2),
			cframe = faceCF * CFrame.new(0, 6.8, frontZ - 1.4) * CFrame.Angles(math.rad(16), 0, 0),
			color = trimColor,
			parent = bldg,
		})
		local sign = createPart({
			name = "SignBoard",
			size = Vector3.new(math.min(width - 4, 22), 2.3, 0.45),
			cframe = faceCF * CFrame.new(0, 8.9, frontZ - 0.25),
			color = trimColor,
			parent = bldg,
		})
		createSurfaceLabel(
			sign,
			Enum.NormalId.Front,
			titleText,
			subtitleText,
			Color3.fromRGB(255, 248, 246),
			Color3.fromRGB(92, 62, 78)
		)

		for floorIdx = 1, floors do
			local y = 13.0 + (floorIdx - 1) * 6.5
			for _, xOff in windowCols do
				createPart({
					name = "WindowPane",
					size = Vector3.new(3.8, 3.4, 0.25),
					cframe = faceCF * CFrame.new(xOff, y, frontZ - 0.05),
					color = PALETTE.CafeGlass,
					material = Enum.Material.Glass,
					transparency = 0.35,
					parent = bldg,
				})
				createPart({
					name = "BalconySill",
					size = Vector3.new(4.4, 0.4, 0.9),
					cframe = faceCF * CFrame.new(xOff, y - 1.8, frontZ - 0.4),
					color = trimColor,
					parent = bldg,
				})
			end
		end
	end
end

local function buildSkylineBuilding(parent: Instance, centerPos: Vector3, width: number, height: number, depth: number, color: Color3, yawRad: number?)
	local bldg = Instance.new("Model")
	bldg.Name = "SkylineBuilding"
	bldg.Parent = parent

	local baseCF = CFrame.new(centerPos) * CFrame.Angles(0, yawRad or 0, 0)
	createPart({
		name = "TowerBody",
		size = Vector3.new(width, height, depth),
		cframe = baseCF * CFrame.new(0, height * 0.5, 0),
		color = color,
		parent = bldg,
	})
	createPart({
		name = "RoofCap",
		size = Vector3.new(width + 1.4, 1.6, depth + 1.4),
		cframe = baseCF * CFrame.new(0, height + 0.8, 0),
		color = PALETTE.LampPost,
		parent = bldg,
	})
	if height >= 48 then
		createPart({
			name = "AccentBand",
			size = Vector3.new(width + 0.4, 2.0, depth + 0.4),
			cframe = baseCF * CFrame.new(0, height * 0.72, 0),
			color = PALETTE.CafeTrim,
			parent = bldg,
		})
	end
end

local function buildElevatedOverpassRing(parent: Instance, radius: number, segments: number)
	local overpass = Instance.new("Model")
	overpass.Name = "ElevatedCityOverpass"
	overpass.Parent = parent

	local deckY = 20
	local stepAngle = (math.pi * 2) / segments
	local segLen = 2 * radius * math.tan(stepAngle * 0.5) + 3.0

	for i = 0, segments - 1 do
		local angle = i * stepAngle
		local pos = Vector3.new(math.cos(angle) * radius, deckY, math.sin(angle) * radius)
		local nextAngle = (i + 1) * stepAngle
		local nextPos = Vector3.new(math.cos(nextAngle) * radius, deckY, math.sin(nextAngle) * radius)
		local cf = CFrame.lookAt(pos, nextPos)

		createPart({
			name = "ViaductDeck",
			size = Vector3.new(16, 2.2, segLen),
			cframe = cf,
			color = Color3.fromRGB(186, 190, 200),
			parent = overpass,
		})
		createPart({
			name = "ViaductRoad",
			size = Vector3.new(12, 0.25, segLen),
			cframe = cf * CFrame.new(0, 1.2, 0),
			color = PALETTE.Asphalt,
			parent = overpass,
		})
		for _, xRail in { -7.4, 7.4 } do
			createPart({
				name = "ViaductRail",
				size = Vector3.new(0.8, 1.8, segLen),
				cframe = cf * CFrame.new(xRail, 2.0, 0),
				color = PALETTE.Sidewalk,
				parent = overpass,
			})
		end

		if i % 2 == 0 then
			createPart({
				name = "ViaductPier",
				size = Vector3.new(4.4, deckY - 1.0, 4.4),
				cframe = CFrame.new(pos.X, (deckY - 1.0) * 0.5, pos.Z),
				color = Color3.fromRGB(168, 172, 182),
				parent = overpass,
			})
		end
	end
end

local function buildGachaShrine(parent: Instance): ProximityPrompt
	local shrine = Instance.new("Model")
	shrine.Name = "StaffSummonShrine"
	shrine.Parent = parent

	local center = Vector3.new(0, FLOOR_TOP_Y, 0)

	createPart({
		name = "DaisBase",
		size = Vector3.new(16, 0.5, 13),
		cframe = CFrame.new(center + Vector3.new(0, 0.25, 0)),
		color = PALETTE.PlazaStone,
		parent = shrine,
	})
	createPart({
		name = "DaisTop",
		size = Vector3.new(12.5, 0.5, 9.5),
		cframe = CFrame.new(center + Vector3.new(0, 0.75, 0)),
		color = PALETTE.ShrineWood,
		parent = shrine,
	})

	for _, xOffset in { -4.8, 4.8 } do
		createPart({
			name = "ToriiPillar",
			size = Vector3.new(1.2, 10.5, 1.2),
			cframe = CFrame.new(center + Vector3.new(xOffset, 6.0, 0)),
			color = PALETTE.ShrineRed,
			parent = shrine,
		})
		createPart({
			name = "PillarBase",
			size = Vector3.new(1.8, 0.9, 1.8),
			cframe = CFrame.new(center + Vector3.new(xOffset, 1.25, 0)),
			color = PALETTE.LampPost,
			parent = shrine,
		})
	end

	createPart({
		name = "LowerCrossbeam",
		size = Vector3.new(13.0, 0.85, 1.1),
		cframe = CFrame.new(center + Vector3.new(0, 9.0, 0)),
		color = PALETTE.ShrineRed,
		parent = shrine,
	})
	createPart({
		name = "TopCrossbeam",
		size = Vector3.new(15.6, 1.2, 1.6),
		cframe = CFrame.new(center + Vector3.new(0, 11.4, 0)),
		color = PALETTE.ShrineRed,
		parent = shrine,
	})

	local banner = createPart({
		name = "GachaBanner",
		size = Vector3.new(8.2, 2.3, 0.45),
		cframe = CFrame.new(center + Vector3.new(0, 10.1, 0)),
		color = PALETTE.ShrineGold,
		parent = shrine,
	})
	createSurfaceLabel(
		banner,
		Enum.NormalId.Front,
		"STAFF SUMMON SHRINE",
		`{GameConfig.GACHA_ROLL_COST} YEN PER ROLL`,
		Color3.fromRGB(255, 240, 246),
		Color3.fromRGB(145, 58, 86)
	)
	createSurfaceLabel(
		banner,
		Enum.NormalId.Back,
		"STAFF SUMMON SHRINE",
		`{GameConfig.GACHA_ROLL_COST} YEN PER ROLL`,
		Color3.fromRGB(255, 240, 246),
		Color3.fromRGB(145, 58, 86)
	)

	local altar = createPart({
		name = "SummonAltar",
		size = Vector3.new(4.6, 2.3, 2.8),
		cframe = CFrame.new(center + Vector3.new(0, 2.15, 0)),
		color = PALETTE.CafeWall,
		parent = shrine,
	})

	local orb = createPart({
		name = "SummonOrb",
		size = Vector3.new(1.5, 1.5, 1.5),
		cframe = CFrame.new(center + Vector3.new(0, 4.25, 0)),
		color = Color3.fromRGB(255, 196, 232),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		parent = shrine,
	})
	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(255, 180, 224)
	orbLight.Brightness = 0.95
	orbLight.Range = 20
	orbLight.Shadows = false
	orbLight.Parent = orb

	for _, xOffset in { -5.8, 5.8 } do
		createPart({
			name = "LanternStand",
			size = Vector3.new(0.85, 2.8, 0.85),
			cframe = CFrame.new(center + Vector3.new(xOffset, 1.9, 3.4)),
			color = PALETTE.PlazaStone,
			parent = shrine,
		})
		createPart({
			name = "LanternGlow",
			size = Vector3.new(1.15, 1.25, 1.15),
			cframe = CFrame.new(center + Vector3.new(xOffset, 3.7, 3.4)),
			color = PALETTE.LampGlow,
			material = Enum.Material.SmoothPlastic,
			parent = shrine,
		})
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SummonPrompt"
	prompt.ObjectText = "Anime Staff Shrine"
	prompt.ActionText = `Summon Staff ({GameConfig.GACHA_ROLL_COST} Yen)`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt:SetAttribute("PromptType", "GachaShrine")
	prompt.Parent = altar

	shrine.PrimaryPart = altar
	return prompt
end

local function buildRoadSegmentStrip(
	roadFolder: Instance,
	sidewalkFolder: Instance,
	pA: Vector3,
	pB: Vector3,
	segIndex: number,
	addDashedLine: boolean
)
	local delta = pB - pA
	local segLen = delta.Magnitude
	if segLen < 0.1 then
		return
	end

	local mid = (pA + pB) * 0.5
	local yStep = (segIndex % 2) * 0.002
	local cf = CFrame.lookAt(mid, pB)

	createPart({
		name = `AsphaltSeg_{segIndex}`,
		size = Vector3.new(ROAD_WIDTH, 0.12, segLen + 2.5),
		cframe = cf * CFrame.new(0, 0.06 + yStep, 0),
		color = PALETTE.Asphalt,
		parent = roadFolder,
	})

	if addDashedLine and segIndex % 2 == 0 then
		createPart({
			name = `LaneDash_{segIndex}`,
			size = Vector3.new(0.6, 0.04, math.min(5.5, segLen * 0.55)),
			cframe = cf * CFrame.new(0, 0.14 + yStep, 0),
			color = PALETTE.RoadLine,
			canCollide = false,
			parent = roadFolder,
		})
	end

	-- Flanking curved/angled sidewalks on both sides of the road segment
	local sidewalkOffset = ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5
	for _, xSide in { -sidewalkOffset, sidewalkOffset } do
		createPart({
			name = `SidewalkSeg_{segIndex}`,
			size = Vector3.new(SIDEWALK_WIDTH, 0.5, segLen + 4.0),
			cframe = cf * CFrame.new(xSide, 0.25 + yStep, 0),
			color = PALETTE.Sidewalk,
			parent = sidewalkFolder,
		})
	end

	table.insert(roadCollisionPoints, mid)
end

local function buildCurvedRoadNetwork(streetsFolder: Folder, propsFolder: Folder)
	local roadFolder = Instance.new("Folder")
	roadFolder.Name = "CurvedRoads"
	roadFolder.Parent = streetsFolder

	local sidewalkFolder = Instance.new("Folder")
	sidewalkFolder.Name = "CurvedSidewalks"
	sidewalkFolder.Parent = streetsFolder

	-- Circular Central Sakura Plaza island (multi-sided ring for smooth organic curve)
	local plazaSegments = 24
	for i = 0, plazaSegments - 1 do
		local a0 = (i / plazaSegments) * math.pi * 2
		local a1 = ((i + 1) / plazaSegments) * math.pi * 2
		local yStep = (i % 2) * 0.002

		-- Roundabout road ring segment (center radius = 37, width = 22 -> r = 26..48)
		local pA = Vector3.new(math.cos(a0) * ROUNDABOUT_CENTER_RADIUS, 0, math.sin(a0) * ROUNDABOUT_CENTER_RADIUS)
		local pB = Vector3.new(math.cos(a1) * ROUNDABOUT_CENTER_RADIUS, 0, math.sin(a1) * ROUNDABOUT_CENTER_RADIUS)
		local mid = (pA + pB) * 0.5
		local segLen = (pB - pA).Magnitude
		local roadCF = CFrame.lookAt(mid, pB)

		createPart({
			name = `RoundaboutSeg_{i}`,
			size = Vector3.new(ROAD_WIDTH, 0.12, segLen + 3.0),
			cframe = roadCF * CFrame.new(0, 0.06 + yStep, 0),
			color = PALETTE.Asphalt,
			parent = roadFolder,
		})
		table.insert(roadCollisionPoints, mid)

		-- Outer sidewalk ring border around roundabout (at radius 51)
		local swA = Vector3.new(math.cos(a0) * (ROUNDABOUT_CENTER_RADIUS + ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5), 0, math.sin(a0) * (ROUNDABOUT_CENTER_RADIUS + ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5))
		local swB = Vector3.new(math.cos(a1) * (ROUNDABOUT_CENTER_RADIUS + ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5), 0, math.sin(a1) * (ROUNDABOUT_CENTER_RADIUS + ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5))
		createPart({
			name = `RoundaboutSidewalk_{i}`,
			size = Vector3.new(SIDEWALK_WIDTH, 0.5, (swB - swA).Magnitude + 3.0),
			cframe = CFrame.lookAt((swA + swB) * 0.5, swB) * CFrame.new(0, 0.25 + yStep, 0),
			color = PALETTE.Sidewalk,
			parent = sidewalkFolder,
		})

		-- Central Plaza stone wedge & pink trim ring
		local wedgeCF = CFrame.Angles(0, -a0, 0)
		createPart({
			name = `PlazaWedge_{i}`,
			size = Vector3.new(PLAZA_RADIUS * 2, 0.5, 8.5),
			cframe = CFrame.new(0, 0.25 + yStep, 0) * wedgeCF,
			color = PALETTE.PlazaStone,
			parent = sidewalkFolder,
		})
		createPart({
			name = `PlazaRim_{i}`,
			size = Vector3.new(3.2, 0.54, 7.6),
			cframe = CFrame.new(math.cos(a0) * (PLAZA_RADIUS - 1.5), 0.27 + yStep, math.sin(a0) * (PLAZA_RADIUS - 1.5)) * CFrame.Angles(0, -a0, 0),
			color = PALETTE.PlazaTrim,
			parent = sidewalkFolder,
		})
	end

	-- Sample the 4 sweeping curved avenues radiating out to +/-790 studs
	local eastCurve = sampleSplinePoints(EAST_CONTROL_POINTS, 6)
	local westCurve = mirrorPoints180(eastCurve)
	local northCurve = sampleSplinePoints(NORTH_CONTROL_POINTS, 6)
	local southCurve = mirrorPoints180(northCurve)

	cachedTrafficCenterlines = {
		plazaRadius = ROUNDABOUT_CENTER_RADIUS,
		westCurve = westCurve,
		eastCurve = eastCurve,
		northCurve = northCurve,
		southCurve = southCurve,
	}

	local allCurves = { eastCurve, westCurve, northCurve, southCurve }
	for curveIdx, curve in allCurves do
		for i = 1, #curve - 1 do
			local segId = curveIdx * 1000 + i
			buildRoadSegmentStrip(roadFolder, sidewalkFolder, curve[i], curve[i + 1], segId, true)

			-- Place crosswalks near the plaza exit and near the outer playable neighborhood edge
			if i == 2 or i == 11 then
				local pA = curve[i]
				local pB = curve[i + 1]
				local cwCF = CFrame.lookAt((pA + pB) * 0.5, pB)
				buildCrosswalkAtCFrame(roadFolder, cwCF, ROAD_WIDTH)
			end

			-- Place streetlights along the curved avenues inside and just past the playable zone
			if i >= 3 and i <= 18 and i % 3 == 0 then
				local pA = curve[i]
				local pB = curve[i + 1]
				local segCF = CFrame.lookAt(pA, pB)
				local withLight = pA.Magnitude < PLAYABLE_BOUNDARY_RADIUS + 20
				local sideOffset = ROAD_WIDTH * 0.5 + 2.5
				local leftPos = (segCF * CFrame.new(-sideOffset, FLOOR_TOP_Y, 0)).Position
				local rightPos = (segCF * CFrame.new(sideOffset, FLOOR_TOP_Y, 0)).Position
				buildStreetlight(propsFolder, leftPos, segCF.RightVector, withLight)
				buildStreetlight(propsFolder, rightPos, -segCF.RightVector, withLight)
			end
		end
	end
end

local function buildNeighborhoodDetails(propsFolder: Folder)
	-- 1. Mid-Block Flush Buildings flanking BOTH sides of all 4 restaurant plots
	-- Plot widths are 60 (local X: -30..+30), depths are 58 (local Z: -29..+29).
	-- Placing flush buildings at local X = -47 (width 34 -> X: -64..-30) and +47 (width 34 -> X: +30..+64)
	-- embeds each café directly in a dense continuous city block!
	local plotAdjacentBuildings = {
		{
			plotIndex = 1,
			left = { title = "SAKURA DEPT.", sub = "KONBINI & GOODS", height = 44, wall = Color3.fromRGB(248, 242, 236), trim = Color3.fromRGB(130, 208, 232) },
			right = { title = "SHIBUYA SWEETS", sub = "CREPES & BOBA", height = 38, wall = Color3.fromRGB(252, 238, 242), trim = PALETTE.CafeTrim },
			back = { title = "AOZORA TOWER", sub = "RESIDENCES", height = 62, wall = Color3.fromRGB(228, 234, 244), trim = Color3.fromRGB(168, 202, 236) },
		},
		{
			plotIndex = 2,
			left = { title = "ICHIRAKU RAMEN", sub = "HOT NOODLES", height = 40, wall = Color3.fromRGB(250, 240, 224), trim = PALETTE.ShrineRed },
			right = { title = "AKIBA ARCADE", sub = "CLAW & GAMES", height = 48, wall = Color3.fromRGB(236, 242, 248), trim = Color3.fromRGB(168, 212, 236) },
			back = { title = "MOCHI PLAZA", sub = "OFFICE SUITES", height = 66, wall = Color3.fromRGB(238, 236, 246), trim = Color3.fromRGB(192, 168, 236) },
		},
		{
			plotIndex = 3,
			left = { title = "NEKO ARCADE", sub = "PURIKURA STUDIO", height = 46, wall = Color3.fromRGB(242, 234, 252), trim = Color3.fromRGB(196, 152, 242) },
			right = { title = "KYOTO MATCHA", sub = "TEA & WAGASHI", height = 40, wall = Color3.fromRGB(238, 248, 238), trim = Color3.fromRGB(134, 206, 156) },
			back = { title = "TSUKI HEIGHTS", sub = "CITY APARTMENTS", height = 60, wall = Color3.fromRGB(244, 238, 230), trim = Color3.fromRGB(255, 178, 146) },
		},
		{
			plotIndex = 4,
			left = { title = "MANGA BOOKS", sub = "COMICS & LOUNGE", height = 52, wall = Color3.fromRGB(234, 240, 250), trim = Color3.fromRGB(146, 188, 242) },
			right = { title = "STARLIGHT LOFT", sub = "IDOL RECORDS", height = 48, wall = Color3.fromRGB(246, 236, 238), trim = PALETTE.CafeTrim },
			back = { title = "TOKYO BAKERY", sub = "MELONPAN TOWER", height = 64, wall = Color3.fromRGB(250, 242, 232), trim = Color3.fromRGB(246, 186, 138) },
		},
	}

	for _, cfg in plotAdjacentBuildings do
		local origin = PLOT_ORIGINS[cfg.plotIndex]
		-- Local +Z faces the street, while buildUrbanStoreBuilding faces local -Z, so rotate 180 deg!
		local facingStreetYaw = CFrame.Angles(0, math.pi, 0)

		buildUrbanStoreBuilding(
			propsFolder,
			origin * CFrame.new(-46, FLOOR_TOP_Y, 0) * facingStreetYaw,
			32,
			cfg.left.height,
			58,
			cfg.left.wall,
			cfg.left.trim,
			cfg.left.title,
			cfg.left.sub,
			false
		)
		buildUrbanStoreBuilding(
			propsFolder,
			origin * CFrame.new(46, FLOOR_TOP_Y, 0) * facingStreetYaw,
			32,
			cfg.right.height,
			58,
			cfg.right.wall,
			cfg.right.trim,
			cfg.right.title,
			cfg.right.sub,
			false
		)
		-- Tall tower directly behind the plot & side buildings to frame the block
		buildUrbanStoreBuilding(
			propsFolder,
			origin * CFrame.new(0, FLOOR_TOP_Y, -56) * facingStreetYaw,
			88,
			cfg.back.height,
			46,
			cfg.back.wall,
			cfg.back.trim,
			cfg.back.title,
			cfg.back.sub,
			false
		)

		-- Cozy street props right in front of the adjacent storefronts
		buildVendingMachine(propsFolder, origin * CFrame.new(-35, FLOOR_TOP_Y, 31) * facingStreetYaw, PALETTE.CafeTrim)
		buildVendingMachine(propsFolder, origin * CFrame.new(35, FLOOR_TOP_Y, 31) * facingStreetYaw, PALETTE.CafeMint)
		buildBushCluster(propsFolder, (origin * CFrame.new(-42, FLOOR_TOP_Y, 31)).Position)
		buildBushCluster(propsFolder, (origin * CFrame.new(42, FLOOR_TOP_Y, 31)).Position)
		buildCherryBlossomTree(propsFolder, (origin * CFrame.new(-58, FLOOR_TOP_Y, 33)).Position, 0.85)
		buildCherryBlossomTree(propsFolder, (origin * CFrame.new(58, FLOOR_TOP_Y, 33)).Position, 0.85)
	end

	-- 2. Plaza corner cherry blossom trees, benches & crosswalk signals
	for _, corner in {
		Vector3.new(-18, FLOOR_TOP_Y, -18),
		Vector3.new(18, FLOOR_TOP_Y, -18),
		Vector3.new(-18, FLOOR_TOP_Y, 18),
		Vector3.new(18, FLOOR_TOP_Y, 18),
	} do
		buildCherryBlossomTree(propsFolder, corner, 1.0)
	end

	buildPlazaBench(propsFolder, CFrame.new(-16, FLOOR_TOP_Y, 0) * CFrame.Angles(0, math.pi * 0.5, 0))
	buildPlazaBench(propsFolder, CFrame.new(16, FLOOR_TOP_Y, 0) * CFrame.Angles(0, -math.pi * 0.5, 0))
	buildPlazaBench(propsFolder, CFrame.new(0, FLOOR_TOP_Y, -17))
	buildPlazaBench(propsFolder, CFrame.new(0, FLOOR_TOP_Y, 17) * CFrame.Angles(0, math.pi, 0))

	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2 + math.pi / 8
		local sigPos = Vector3.new(math.cos(angle) * (PLAZA_RADIUS - 2), FLOOR_TOP_Y, math.sin(angle) * (PLAZA_RADIUS - 2))
		buildCrosswalkSignal(propsFolder, sigPos, -angle + math.pi * 0.5)
	end

	-- Bus stops along the curved avenues across from the plots
	buildBusStopShelter(propsFolder, CFrame.new(-62, FLOOR_TOP_Y, 22) * CFrame.Angles(0, math.rad(165), 0))
	buildBusStopShelter(propsFolder, CFrame.new(62, FLOOR_TOP_Y, -22) * CFrame.Angles(0, math.rad(-15), 0))
	buildBusStopShelter(propsFolder, CFrame.new(-24, FLOOR_TOP_Y, -64) * CFrame.Angles(0, math.rad(78), 0))
	buildBusStopShelter(propsFolder, CFrame.new(24, FLOOR_TOP_Y, 64) * CFrame.Angles(0, math.rad(-102), 0))
end

local function isNearRoadOrPlayableCore(pos: Vector3, minClearance: number): boolean
	-- Keep inner playable district (plots + central plaza) clear of random outer skyline blocks
	if pos.Magnitude < 142 then
		return true
	end

	for _, plotOrigin in PLOT_ORIGINS do
		if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(plotOrigin.Position.X, 0, plotOrigin.Position.Z)).Magnitude < 78 then
			return true
		end
	end

	for _, roadPt in roadCollisionPoints do
		local dx = pos.X - roadPt.X
		local dz = pos.Z - roadPt.Z
		if (dx * dx + dz * dz) < (minClearance * minClearance) then
			return true
		end
	end

	return false
end

local function buildEndlessCityBackdrop(root: Model)
	local backdrop = Instance.new("Folder")
	backdrop.Name = "EndlessCityBackdrop"
	backdrop.Parent = root

	local fullSpan = (SKYLINE_EXTENT + 80) * 2

	-- Outer concrete apron slab under distant blocks (top at Y = -0.03 so Baseplate Y = 0 never z-fights)
	createPart({
		name = "OuterHorizonGround",
		size = Vector3.new(fullSpan, 0.5, fullSpan),
		cframe = CFrame.new(0, -0.28, 0),
		color = PALETTE.OuterGround,
		parent = backdrop,
	})

	-- Playable neighborhood urban sidewalk base (under plots & wedges, below roads? Wait: top at 0.48,
	-- no — roads are at top 0.12, so urban block pads sit ONLY outside roads, or OuterHorizonGround handles ground!)
	-- Fill large urban block pads between curved avenues inside playable radius
	local blockFillerPads = {
		{ cf = CFrame.new(-92, 0.24, -76) * CFrame.Angles(0, math.rad(-10), 0), size = Vector3.new(135, 0.48, 118) },
		{ cf = CFrame.new(76, 0.24, -92) * CFrame.Angles(0, math.rad(-100), 0), size = Vector3.new(135, 0.48, 118) },
		{ cf = CFrame.new(-76, 0.24, 92) * CFrame.Angles(0, math.rad(80), 0), size = Vector3.new(135, 0.48, 118) },
		{ cf = CFrame.new(92, 0.24, 76) * CFrame.Angles(0, math.rad(170), 0), size = Vector3.new(135, 0.48, 118) },
	}
	for index, pad in blockFillerPads do
		createPart({
			name = `UrbanBlockBase_{index}`,
			size = pad.size,
			cframe = pad.cf,
			color = PALETTE.Sidewalk,
			parent = backdrop,
		})
	end

	-- Elevated highway/rail overpass rings framing the city skyline at r = 215 and r = 430
	buildElevatedOverpassRing(backdrop, 215, 28)
	buildElevatedOverpassRing(backdrop, 430, 36)

	-- Dense multi-ring skyscraper skyline extending +/-750+ studs in every direction
	local paletteCount = #PALETTE.SkylineColors
	local bldgIndex = 0
	for x = -740, 740, 62 do
		for z = -740, 740, 62 do
			local candidate = Vector3.new(x, FLOOR_TOP_Y, z)
			if not isNearRoadOrPlayableCore(candidate, 40) then
				bldgIndex += 1
				local dist = candidate.Magnitude
				local baseHeight = if dist > 420 then 95 elseif dist > 250 then 68 else 46
				local height = baseHeight + ((bldgIndex * 19) % 58)
				local width = 34 + ((bldgIndex * 7) % 14)
				local depth = 34 + ((bldgIndex * 11) % 14)
				local yaw = ((bldgIndex * 13) % 4) * (math.pi * 0.5)
				local color = PALETTE.SkylineColors[(bldgIndex % paletteCount) + 1]

				createPart({
					name = `SkylinePad_{bldgIndex}`,
					size = Vector3.new(width + 10, 0.5, depth + 10),
					cframe = CFrame.new(x, 0.25, z) * CFrame.Angles(0, yaw, 0),
					color = PALETTE.Sidewalk,
					parent = backdrop,
				})
				buildSkylineBuilding(backdrop, candidate, width, height, depth, color, yaw)
			end
		end
	end
end

local function buildBoundaryWalls(root: Model)
	local boundsFolder = Instance.new("Folder")
	boundsFolder.Name = "PlayableBoundaries"
	boundsFolder.Parent = root

	-- Tall 80-stud solid invisible polygonal perimeter ring (16 segments) keeping players inside the neighborhood
	local segments = 16
	local wallHeight = 80
	local wallThickness = 6
	local radius = PLAYABLE_BOUNDARY_RADIUS
	local stepAngle = (math.pi * 2) / segments
	local segWidth = 2 * radius * math.tan(stepAngle * 0.5) + 4

	for i = 0, segments - 1 do
		local angle = i * stepAngle
		local pos = Vector3.new(math.cos(angle) * radius, wallHeight * 0.5, math.sin(angle) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, wallHeight * 0.5, 0))

		createPart({
			name = `BoundaryWall_{i + 1}`,
			size = Vector3.new(segWidth, wallHeight, wallThickness),
			cframe = cf,
			color = PALETTE.Asphalt,
			transparency = 1,
			canCollide = true,
			canQuery = false,
			parent = boundsFolder,
		})
	end
end

local function buildStreetsAndPlaza(root: Model)
	local streetsFolder = Instance.new("Folder")
	streetsFolder.Name = "StreetsAndPlaza"
	streetsFolder.Parent = root

	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "StreetProps"
	propsFolder.Parent = root

	buildCurvedRoadNetwork(streetsFolder, propsFolder)
	buildNeighborhoodDetails(propsFolder)

	gachaPrompt = buildGachaShrine(root)
	buildEndlessCityBackdrop(root)
	buildBoundaryWalls(root)
end

local function buildUnclaimedPlotMarker(plotRoot: Model, origin: CFrame, index: number)
	local existing = plotRoot:FindFirstChild("UnclaimedMarker")
	if existing then
		existing:Destroy()
	end

	local marker = Instance.new("Model")
	marker.Name = "UnclaimedMarker"
	marker.Parent = plotRoot

	local post = createPart({
		name = "SignPost",
		size = Vector3.new(0.7, 5.5, 0.7),
		cframe = origin * CFrame.new(0, 2.75, 22),
		color = PALETTE.CafeTrim,
		parent = marker,
	})
	local board = createPart({
		name = "SignBoard",
		size = Vector3.new(9.5, 3.6, 0.45),
		cframe = origin * CFrame.new(0, 5.6, 22),
		color = PALETTE.CafeWall,
		parent = marker,
	})
	createSurfaceLabel(
		board,
		Enum.NormalId.Front,
		`CAFÉ PLOT #{index}`,
		"Waiting for Owner...",
		PALETTE.CafeWall,
		Color3.fromRGB(130, 82, 102)
	)
	marker.PrimaryPart = post
end

local function buildPlotBase(parent: Instance, index: number, origin: CFrame): PlotData
	local plotRoot = Instance.new("Model")
	plotRoot.Name = `RestaurantPlot_{index}`
	plotRoot.Parent = parent

	createPart({
		name = "PlotFoundation",
		size = Vector3.new(60, 0.5, 58),
		cframe = origin * CFrame.new(0, 0.25, 0),
		color = PALETTE.Sidewalk,
		parent = plotRoot,
	})
	createPart({
		name = "BackTrim",
		size = Vector3.new(60, 0.6, 0.8),
		cframe = origin * CFrame.new(0, 0.8, -28.6),
		color = PALETTE.CafeTrim,
		parent = plotRoot,
	})
	createPart({
		name = "LeftTrim",
		size = Vector3.new(0.8, 0.6, 57.2),
		cframe = origin * CFrame.new(-29.6, 0.8, 0),
		color = PALETTE.CafeTrim,
		parent = plotRoot,
	})
	createPart({
		name = "RightTrim",
		size = Vector3.new(0.8, 0.6, 57.2),
		cframe = origin * CFrame.new(29.6, 0.8, 0),
		color = PALETTE.CafeTrim,
		parent = plotRoot,
	})

	buildUnclaimedPlotMarker(plotRoot, origin, index)

	return {
		index = index,
		origin = origin,
		owner = nil,
		rootModel = plotRoot,
		interiorModel = nil,
		spawnLocation = nil,
		supplyStation = nil,
		prepCounter = nil,
		cookingStove = nil,
		servingCounter = nil,
		diningTables = {},
	}
end

local function buildDiningTable(parent: Instance, origin: CFrame, localPos: Vector3, tableIndex: number): DiningTableRefs
	local tableModel = Instance.new("Model")
	tableModel.Name = `DiningTable_{tableIndex}`
	tableModel:SetAttribute("TableIndex", tableIndex)
	tableModel.Parent = parent

	local tableBaseCFrame = origin * CFrame.new(localPos)

	createPart({
		name = "TablePedestal",
		size = Vector3.new(0.85, 2.2, 0.85),
		cframe = tableBaseCFrame * CFrame.new(0, 1.1, 0),
		color = PALETTE.CafeCounter,
		parent = tableModel,
	})

	local tableTop = createPart({
		name = "TableTop",
		size = Vector3.new(4.6, 0.4, 4.6),
		cframe = tableBaseCFrame * CFrame.new(0, 2.3, 0),
		color = PALETTE.CafeWall,
		parent = tableModel,
	})

	createPart({
		name = "Vase",
		size = Vector3.new(0.6, 0.7, 0.6),
		cframe = tableBaseCFrame * CFrame.new(0, 2.85, 0),
		color = PALETTE.CafeMint,
		shape = Enum.PartType.Cylinder,
		parent = tableModel,
	})
	createPart({
		name = "Flower",
		size = Vector3.new(0.8, 0.8, 0.8),
		cframe = tableBaseCFrame * CFrame.new(0, 3.35, 0),
		color = PALETTE.SakuraLeaf,
		shape = Enum.PartType.Ball,
		parent = tableModel,
	})

	local seats: { Seat } = {}
	local chairOffsets = {
		{ offset = Vector3.new(-3.6, 0, 0), yaw = -math.pi * 0.5 },
		{ offset = Vector3.new(3.6, 0, 0), yaw = math.pi * 0.5 },
	}

	for chairIndex, cfg in chairOffsets do
		local chairCFrame = tableBaseCFrame * CFrame.new(cfg.offset) * CFrame.Angles(0, cfg.yaw, 0)

		createPart({
			name = `ChairLeg_{chairIndex}`,
			size = Vector3.new(1.2, 1.2, 1.2),
			cframe = chairCFrame * CFrame.new(0, 0.6, 0),
			color = PALETTE.CrateWood,
			parent = tableModel,
		})

		local seat = Instance.new("Seat")
		seat.Name = `ChairSeat_{chairIndex}`
		seat.Anchored = true
		seat.Size = Vector3.new(1.8, 0.4, 1.8)
		seat.CFrame = chairCFrame * CFrame.new(0, 1.4, 0)
		seat.Color = PALETTE.CafeTrim
		seat.Material = Enum.Material.SmoothPlastic
		seat.Parent = tableModel
		table.insert(seats, seat)

		createPart({
			name = `ChairBack_{chairIndex}`,
			size = Vector3.new(1.8, 1.6, 0.35),
			cframe = chairCFrame * CFrame.new(0, 2.3, 0.72),
			color = PALETTE.CafeTrim,
			parent = tableModel,
		})
	end

	tableModel.PrimaryPart = tableTop

	return {
		model = tableModel,
		tableTop = tableTop,
		seats = seats,
	}
end

local function buildSupplyStation(parent: Instance, origin: CFrame, owner: Player, plotIndex: number): Model
	local model = Instance.new("Model")
	model.Name = "SupplyDeliveryStation"
	model:SetAttribute("StationType", "SupplyDelivery")
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("PlotIndex", plotIndex)
	model.Parent = parent

	local stationCF = origin * CFrame.new(-21.2, CAFE_FLOOR_TOP_Y, -10)

	createPart({
		name = "DeliveryDoorFrame",
		size = Vector3.new(0.6, 8.0, 5.6),
		cframe = stationCF * CFrame.new(-3.2, 4.0, 0),
		color = PALETTE.CafeTrim,
		parent = model,
	})
	createPart({
		name = "DeliveryDoor",
		size = Vector3.new(0.4, 7.2, 4.6),
		cframe = stationCF * CFrame.new(-3.3, 3.6, 0),
		color = PALETTE.CafeMint,
		parent = model,
	})

	local mainCrate = createPart({
		name = "SupplyCrateMain",
		size = Vector3.new(3.2, 2.5, 3.4),
		cframe = stationCF * CFrame.new(-0.6, 1.25, 0),
		color = PALETTE.CrateWood,
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	createPart({
		name = "SupplyCrateTop",
		size = Vector3.new(2.1, 1.6, 2.1),
		cframe = stationCF * CFrame.new(-0.7, 3.3, -0.3) * CFrame.Angles(0, 0.25, 0),
		color = PALETTE.SakuraLeafAlt,
		parent = model,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RestockPrompt"
	prompt.ObjectText = "Supply Delivery Crate"
	prompt.ActionText = "Order Ingredients"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt:SetAttribute("PromptType", "RestockSupplies")
	prompt:SetAttribute("OwnerUserId", owner.UserId)
	prompt.Parent = mainCrate

	model.PrimaryPart = mainCrate
	return model
end

local function buildPrepCounter(parent: Instance, origin: CFrame, owner: Player, plotIndex: number): Model
	local model = Instance.new("Model")
	model.Name = "PrepCounter"
	model:SetAttribute("StationType", "Prep")
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("PlotIndex", plotIndex)
	model.Parent = parent

	local cf = origin * CFrame.new(-9.5, CAFE_FLOOR_TOP_Y, -18.5)

	local body = createPart({
		name = "CounterBody",
		size = Vector3.new(8.5, 3.0, 3.4),
		cframe = cf * CFrame.new(0, 1.5, 0),
		color = PALETTE.CafeMint,
		parent = model,
	})
	createPart({
		name = "CounterTop",
		size = Vector3.new(8.8, 0.35, 3.7),
		cframe = cf * CFrame.new(0, 3.15, 0),
		color = PALETTE.CafeCounter,
		parent = model,
	})
	createPart({
		name = "CuttingBoard",
		size = Vector3.new(2.6, 0.16, 1.9),
		cframe = cf * CFrame.new(-1.4, 3.4, 0),
		color = PALETTE.CrateWood,
		material = Enum.Material.Wood,
		parent = model,
	})
	createPart({
		name = "MixingBowl",
		size = Vector3.new(1.3, 0.75, 1.3),
		cframe = cf * CFrame.new(2.0, 3.65, 0),
		color = PALETTE.CafeTrim,
		shape = Enum.PartType.Ball,
		parent = model,
	})

	model.PrimaryPart = body
	return model
end

local function buildCookingStove(parent: Instance, origin: CFrame, owner: Player, plotIndex: number): Model
	local model = Instance.new("Model")
	model.Name = "CookingStove"
	model:SetAttribute("StationType", "Stove")
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("PlotIndex", plotIndex)
	model.Parent = parent

	local cf = origin * CFrame.new(7.5, CAFE_FLOOR_TOP_Y, -18.5)

	local body = createPart({
		name = "StoveBody",
		size = Vector3.new(7.6, 3.0, 3.4),
		cframe = cf * CFrame.new(0, 1.5, 0),
		color = PALETTE.StoveMetal,
		parent = model,
	})
	createPart({
		name = "StoveTop",
		size = Vector3.new(7.8, 0.25, 3.6),
		cframe = cf * CFrame.new(0, 3.12, 0),
		color = PALETTE.LampPost,
		parent = model,
	})

	for _, xOff in { -1.8, 1.8 } do
		createPart({
			name = "BurnerRing",
			size = Vector3.new(1.7, 0.1, 1.7),
			cframe = cf * CFrame.new(xOff, 3.28, 0),
			color = Color3.fromRGB(255, 138, 108),
			material = Enum.Material.Neon,
			parent = model,
		})
	end

	createPart({
		name = "RamenPot",
		size = Vector3.new(1.9, 1.25, 1.9),
		cframe = cf * CFrame.new(-1.8, 3.92, 0),
		color = PALETTE.ShrineGold,
		parent = model,
	})

	createPart({
		name = "RangeHood",
		size = Vector3.new(8.0, 1.8, 3.8),
		cframe = cf * CFrame.new(0, 8.6, 0),
		color = PALETTE.CafeWall,
		parent = model,
	})

	model.PrimaryPart = body
	return model
end

local function buildServingCounter(parent: Instance, origin: CFrame, owner: Player, plotIndex: number): Model
	local model = Instance.new("Model")
	model.Name = "ServingCounter"
	model:SetAttribute("StationType", "Serving")
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("PlotIndex", plotIndex)
	model.Parent = parent

	local cf = origin * CFrame.new(6, CAFE_FLOOR_TOP_Y, -5.5)

	local base = createPart({
		name = "CounterBase",
		size = Vector3.new(15, 3.0, 3.2),
		cframe = cf * CFrame.new(0, 1.5, 0),
		color = PALETTE.CafeTrim,
		parent = model,
	})
	createPart({
		name = "CounterTop",
		size = Vector3.new(15.4, 0.35, 3.6),
		cframe = cf * CFrame.new(0, 3.15, 0),
		color = PALETTE.CafeCounter,
		parent = model,
	})

	createPart({
		name = "DessertDisplayCase",
		size = Vector3.new(4.8, 2.2, 2.5),
		cframe = cf * CFrame.new(-4.2, 4.4, 0),
		color = PALETTE.CafeGlass,
		material = Enum.Material.Glass,
		transparency = 0.45,
		parent = model,
	})
	createPart({
		name = "DisplayTray",
		size = Vector3.new(4.0, 0.25, 1.9),
		cframe = cf * CFrame.new(-4.2, 3.55, 0),
		color = PALETTE.SakuraLeafAlt,
		parent = model,
	})

	createPart({
		name = "CashierRegister",
		size = Vector3.new(1.9, 1.45, 1.5),
		cframe = cf * CFrame.new(4.8, 4.02, 0),
		color = PALETTE.CafeMint,
		parent = model,
	})

	model.PrimaryPart = base
	return model
end

local function buildInteriorCeilingLights(parent: Instance, origin: CFrame)
	local lightsFolder = Instance.new("Folder")
	lightsFolder.Name = "InteriorLights"
	lightsFolder.Parent = parent

	local lampPositions = {
		Vector3.new(-13, 13.5, -13),
		Vector3.new(0, 13.5, -13),
		Vector3.new(13, 13.5, -13),
		Vector3.new(-13, 13.5, 6),
		Vector3.new(0, 13.5, 6),
		Vector3.new(13, 13.5, 6),
	}

	for index, pos in lampPositions do
		createPart({
			name = `LampRod_{index}`,
			size = Vector3.new(0.2, 2.0, 0.2),
			cframe = origin * CFrame.new(pos + Vector3.new(0, -1.0, 0)),
			color = PALETTE.LampPost,
			canCollide = false,
			parent = lightsFolder,
		})

		createPart({
			name = `LampShade_{index}`,
			size = Vector3.new(2.2, 0.65, 2.2),
			cframe = origin * CFrame.new(pos + Vector3.new(0, -2.1, 0)),
			color = PALETTE.CafeTrim,
			canCollide = false,
			parent = lightsFolder,
		})

		local bulb = createPart({
			name = `LampBulb_{index}`,
			size = Vector3.new(1.4, 0.8, 1.4),
			cframe = origin * CFrame.new(pos + Vector3.new(0, -2.55, 0)),
			color = PALETTE.InteriorLamp,
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Ball,
			canCollide = false,
			parent = lightsFolder,
		})

		local pointLight = Instance.new("PointLight")
		pointLight.Color = PALETTE.InteriorLamp
		pointLight.Brightness = 0.65
		pointLight.Range = 22
		pointLight.Shadows = false
		pointLight.Parent = bulb
	end
end

local function buildCafeShell(parent: Instance, origin: CFrame, owner: Player)
	local shell = Instance.new("Model")
	shell.Name = "CafeShell"
	shell.Parent = parent

	createPart({
		name = "CafeFloor",
		size = Vector3.new(52, 0.1, 46),
		cframe = origin * CFrame.new(0, 0.50, -1),
		color = PALETTE.CafeFloor,
		material = Enum.Material.WoodPlanks,
		parent = shell,
	})

	createPart({
		name = "BackWall",
		size = Vector3.new(52, 13.5, 1.2),
		cframe = origin * CFrame.new(0, 7.25, -23.4),
		color = PALETTE.CafeWall,
		parent = shell,
	})

	for _, side in { { name = "LeftWall", x = -25.4 }, { name = "RightWall", x = 25.4 } } do
		createPart({
			name = `{side.name}Lower`,
			size = Vector3.new(1.2, 3.2, 44.8),
			cframe = origin * CFrame.new(side.x, 2.1, -1),
			color = PALETTE.CafeWall,
			parent = shell,
		})
		createPart({
			name = `{side.name}Window`,
			size = Vector3.new(0.4, 6.2, 24),
			cframe = origin * CFrame.new(side.x, 6.8, 4),
			color = PALETTE.CafeGlass,
			material = Enum.Material.Glass,
			transparency = 0.4,
			parent = shell,
		})
		createPart({
			name = `{side.name}BackPanel`,
			size = Vector3.new(1.2, 6.2, 18),
			cframe = origin * CFrame.new(side.x, 6.8, -14.4),
			color = PALETTE.CafeWall,
			parent = shell,
		})
		createPart({
			name = `{side.name}FrontPier`,
			size = Vector3.new(1.2, 6.2, 3.4),
			cframe = origin * CFrame.new(side.x, 6.8, 19.7),
			color = PALETTE.CafeWall,
			parent = shell,
		})
		createPart({
			name = `{side.name}Upper`,
			size = Vector3.new(1.2, 4.1, 44.8),
			cframe = origin * CFrame.new(side.x, 11.95, -1),
			color = PALETTE.CafeWall,
			parent = shell,
		})
	end

	for _, xCenter in { -16.5, 16.5 } do
		createPart({
			name = "FrontWallLower",
			size = Vector3.new(19, 3.2, 1.2),
			cframe = origin * CFrame.new(xCenter, 2.1, 21.4),
			color = PALETTE.CafeWall,
			parent = shell,
		})
		createPart({
			name = "FrontWindow",
			size = Vector3.new(16, 6.2, 0.4),
			cframe = origin * CFrame.new(xCenter, 6.8, 21.4),
			color = PALETTE.CafeGlass,
			material = Enum.Material.Glass,
			transparency = 0.4,
			parent = shell,
		})
		createPart({
			name = "FrontWallUpper",
			size = Vector3.new(19, 4.1, 1.2),
			cframe = origin * CFrame.new(xCenter, 11.95, 21.4),
			color = PALETTE.CafeWall,
			parent = shell,
		})
	end

	createPart({
		name = "DoorHeader",
		size = Vector3.new(14, 4.1, 1.2),
		cframe = origin * CFrame.new(0, 11.95, 21.4),
		color = PALETTE.CafeWall,
		parent = shell,
	})

	for i = -6, 6 do
		local color = if i % 2 == 0 then PALETTE.CafeTrim else PALETTE.CafeWall
		createPart({
			name = `AwningStripe_{i}`,
			size = Vector3.new(3.8, 0.45, 4.4),
			cframe = origin * CFrame.new(i * 3.8, 10.4, 23.8) * CFrame.Angles(math.rad(-18), 0, 0),
			color = color,
			parent = shell,
		})
	end

	local sign = createPart({
		name = "CafeSignboard",
		size = Vector3.new(19, 2.8, 0.6),
		cframe = origin * CFrame.new(0, 14.8, 22.5),
		color = PALETTE.CafeTrim,
		parent = shell,
	})
	createSurfaceLabel(
		sign,
		Enum.NormalId.Front,
		`{owner.DisplayName}'s Café`,
		"Sakura Anime Bistro",
		Color3.fromRGB(255, 244, 248),
		Color3.fromRGB(145, 58, 86)
	)

	createPart({
		name = "CafeRoof",
		size = Vector3.new(54, 1.0, 48),
		cframe = origin * CFrame.new(0, 14.0, -1),
		color = PALETTE.CafeTrim,
		parent = shell,
	})

	buildInteriorCeilingLights(shell, origin)
end

local function buildClaimedCafe(plot: PlotData, owner: Player)
	local marker = plot.rootModel:FindFirstChild("UnclaimedMarker")
	if marker then
		marker:Destroy()
	end

	local interior = Instance.new("Model")
	interior.Name = `CafeInterior_{owner.UserId}`
	interior.Parent = plot.rootModel

	buildCafeShell(interior, plot.origin, owner)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = `PlotSpawn_{plot.index}`
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(6, 0.3, 4.5)
	spawnLocation.CFrame = plot.origin * CFrame.new(0, 0.65, 25.0)
	spawnLocation.Color = PALETTE.CafeMint
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Enabled = true
	spawnLocation.Neutral = false
	spawnLocation.Duration = 0
	spawnLocation.AllowTeamChangeOnTouch = false
	spawnLocation.Parent = interior

	local supplyStation = buildSupplyStation(interior, plot.origin, owner, plot.index)
	local prepCounter = buildPrepCounter(interior, plot.origin, owner, plot.index)
	local cookingStove = buildCookingStove(interior, plot.origin, owner, plot.index)
	local servingCounter = buildServingCounter(interior, plot.origin, owner, plot.index)

	local diningTables: { DiningTableRefs } = {}
	local tablePositions = {
		Vector3.new(-14.5, CAFE_FLOOR_TOP_Y, 3),
		Vector3.new(-14.5, CAFE_FLOOR_TOP_Y, 14),
		Vector3.new(14.5, CAFE_FLOOR_TOP_Y, 8.5),
	}
	for tableIndex, localPos in tablePositions do
		local tableRefs = buildDiningTable(interior, plot.origin, localPos, tableIndex)
		table.insert(diningTables, tableRefs)
	end

	plot.interiorModel = interior
	plot.spawnLocation = spawnLocation
	plot.supplyStation = supplyStation
	plot.prepCounter = prepCounter
	plot.cookingStove = cookingStove
	plot.servingCounter = servingCounter
	plot.diningTables = diningTables
end

function WorldBuilder.Init(): Model
	local existing = Workspace:FindFirstChild(CITY_WORLD_NAME)
	if existing then
		existing:Destroy()
	end

	table.clear(plots)
	table.clear(playerToPlot)
	table.clear(roadCollisionPoints)
	gachaPrompt = nil
	cachedTrafficCenterlines = nil

	configureBrightAnimeLighting()

	local root = Instance.new("Model")
	root.Name = CITY_WORLD_NAME
	root.Parent = Workspace
	worldRoot = root

	buildStreetsAndPlaza(root)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "RestaurantPlots"
	plotsFolder.Parent = root

	for index, origin in PLOT_ORIGINS do
		local plotData = buildPlotBase(plotsFolder, index, origin)
		table.insert(plots, plotData)
	end

	return root
end

function WorldBuilder.ClaimPlot(player: Player): PlotData?
	local existing = playerToPlot[player]
	if existing then
		return existing
	end

	local availablePlot: PlotData? = nil
	for _, plot in plots do
		if plot.owner == nil then
			availablePlot = plot
			break
		end
	end

	if not availablePlot then
		warn(`[WorldBuilder] No open restaurant plots left for {player.Name}.`)
		return nil
	end

	availablePlot.owner = player
	playerToPlot[player] = availablePlot
	buildClaimedCafe(availablePlot, player)

	if availablePlot.spawnLocation then
		player.RespawnLocation = availablePlot.spawnLocation
		local character = player.Character
		if character then
			character:PivotTo(availablePlot.spawnLocation.CFrame + Vector3.new(0, 3.5, 0))
		end
	end

	return availablePlot
end

function WorldBuilder.ReleasePlot(player: Player)
	local plot = playerToPlot[player]
	if not plot then
		return
	end

	playerToPlot[player] = nil
	plot.owner = nil

	if plot.interiorModel then
		plot.interiorModel:Destroy()
		plot.interiorModel = nil
	end

	plot.spawnLocation = nil
	plot.supplyStation = nil
	plot.prepCounter = nil
	plot.cookingStove = nil
	plot.servingCounter = nil
	table.clear(plot.diningTables)

	if player.RespawnLocation then
		player.RespawnLocation = nil
	end

	buildUnclaimedPlotMarker(plot.rootModel, plot.origin, plot.index)
end

function WorldBuilder.GetPlayerPlot(player: Player): PlotData?
	return playerToPlot[player]
end

function WorldBuilder.GetAllPlots(): { PlotData }
	return plots
end

function WorldBuilder.GetGachaPrompt(): ProximityPrompt?
	return gachaPrompt
end

function WorldBuilder.GetWorldRoot(): Model?
	return worldRoot
end

function WorldBuilder.GetTrafficCenterlines(): TrafficCenterlines?
	return cachedTrafficCenterlines
end

return WorldBuilder
