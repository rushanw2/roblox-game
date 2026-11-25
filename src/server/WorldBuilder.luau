--!strict
-- Procedural builder for Harbor Island, Pier Hub, Smooth Terrain Ocean, 3 Depth Zones & Excavation Nodes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

export type ExcavationNodeInfo = {
	nodeId: string,
	zoneId: GameConfig.ZoneId,
	nodeType: string,
	displayName: string,
	digDuration: number,
	respawnTime: number,
	model: Model,
	primaryPart: BasePart,
	visualParts: { BasePart },
}

local WorldBuilder = {}

local worldRoot: Folder? = nil
local nodeInfoById: { [string]: ExcavationNodeInfo } = {}

local function createPart(props: {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	shape: Enum.PartType?,
	parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.name or "Part"
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Anchored = true
	part.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = props.parent
	return part
end

local function createWedge(props: {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?,
	parent: Instance,
}): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = props.name or "Wedge"
	wedge.Size = props.size
	wedge.CFrame = props.cframe
	wedge.Color = props.color
	wedge.Material = props.material or Enum.Material.SmoothPlastic
	wedge.Anchored = true
	wedge.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	wedge.Parent = props.parent
	return wedge
end

local function addSurfaceSign(parentPart: BasePart, face: Enum.NormalId, titleText: string, subtitleText: string?, bgColor: Color3, textColor: Color3): ()
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 38
	gui.LightInfluence = 0.25
	gui.Parent = parentPart

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = bgColor
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = if subtitleText then UDim2.fromScale(1, 0.58) else UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = textColor
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = bg

	if subtitleText then
		local sub = Instance.new("TextLabel")
		sub.Position = UDim2.fromScale(0, 0.58)
		sub.Size = UDim2.fromScale(1, 0.42)
		sub.BackgroundTransparency = 1
		sub.Text = subtitleText
		sub.TextColor3 = Color3.fromRGB(220, 236, 255)
		sub.TextScaled = true
		sub.Font = Enum.Font.GothamMedium
		sub.Parent = bg
	end
end

local function buildOceanTerrain(): ()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(24, 146, 186)
	terrain.WaterTransparency = 0.32
	terrain.WaterWaveSize = 0.16
	terrain.WaterWaveSpeed = 8.5
	terrain.WaterReflectance = 0.85

	-- Fill full ocean water box (X: -272..272, Y: -316..0, Z: -272..272)
	terrain:FillBlock(CFrame.new(0, -158, 0), Vector3.new(544, 316, 544), Enum.Material.Water)

	-- Solid abyssal bedrock floor across the whole basin (Y: -316..-292)
	terrain:FillBlock(CFrame.new(0, -304, 0), Vector3.new(544, 24, 544), Enum.Material.Basalt)

	-- Outer perimeter seafloor plateau up to Shallow Reef height (Y = -64)
	-- Central trench opening spans X: -96..96, Z: -24..144
	-- North Shelf (under harbor & beach)
	terrain:FillBlock(CFrame.new(0, -178, -148), Vector3.new(544, 228, 248), Enum.Material.Sand)
	-- South Shelf
	terrain:FillBlock(CFrame.new(0, -178, 208), Vector3.new(544, 228, 128), Enum.Material.Sand)
	-- West Shelf
	terrain:FillBlock(CFrame.new(-184, -178, 60), Vector3.new(176, 228, 168), Enum.Material.Sand)
	-- East Shelf
	terrain:FillBlock(CFrame.new(184, -178, 60), Vector3.new(176, 228, 168), Enum.Material.Sand)

	-- Sunken Ruins Terraces inside Central Trench (X: -96..96, Z: -24..144)
	-- Upper Ruins rim ledges (Y = -112), leaving X: -64..64, Z: 0..120 open
	terrain:FillBlock(CFrame.new(-80, -202, 60), Vector3.new(32, 180, 168), Enum.Material.Sandstone)
	terrain:FillBlock(CFrame.new(80, -202, 60), Vector3.new(32, 180, 168), Enum.Material.Sandstone)
	terrain:FillBlock(CFrame.new(0, -202, -12), Vector3.new(192, 180, 24), Enum.Material.Sandstone)
	terrain:FillBlock(CFrame.new(0, -202, 132), Vector3.new(192, 180, 24), Enum.Material.Sandstone)

	-- Main Sunken Temple Courtyard floor (Y = -152), leaving Abyssal Chasm X: -38..38, Z: 20..100 open
	terrain:FillBlock(CFrame.new(-51, -222, 60), Vector3.new(26, 140, 120), Enum.Material.Slate)
	terrain:FillBlock(CFrame.new(51, -222, 60), Vector3.new(26, 140, 120), Enum.Material.Slate)
	terrain:FillBlock(CFrame.new(0, -222, 10), Vector3.new(128, 140, 20), Enum.Material.Slate)
	terrain:FillBlock(CFrame.new(0, -222, 110), Vector3.new(128, 140, 20), Enum.Material.Slate)

	-- Abyssal Trench intermediate volcanic ledges (Y = -220 and Y = -256) along side walls (Z: 36..80)
	terrain:FillBlock(CFrame.new(-28, -256, 58), Vector3.new(20, 72, 44), Enum.Material.Basalt)
	terrain:FillBlock(CFrame.new(28, -274, 58), Vector3.new(20, 36, 44), Enum.Material.Basalt)

	-- Shallow Reef undulating sandy hills & beach slope leading down from Harbor Island
	terrain:FillBlock(CFrame.new(0, -38, -110), Vector3.new(176, 52, 24), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -48, -90), Vector3.new(210, 44, 24), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(-126, -50, -32), Vector3.new(72, 28, 60), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(126, -46, 30), Vector3.new(76, 36, 72), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(-110, -52, 148), Vector3.new(84, 24, 68), Enum.Material.Sand)

	-- Harbor Island Sand & Grass Landmass (X: -84..84, Z: -236..-120)
	terrain:FillBlock(CFrame.new(0, -2, -176), Vector3.new(168, 16, 112), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, 2, -182), Vector3.new(148, 8, 92), Enum.Material.Grass)

	-- Outer Underwater Perimeter Reef Walls
	terrain:FillBlock(CFrame.new(-264, -36, 0), Vector3.new(16, 60, 544), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(264, -36, 0), Vector3.new(16, 60, 544), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(0, -36, 264), Vector3.new(544, 60, 16), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(0, -36, -264), Vector3.new(544, 60, 16), Enum.Material.Rock)
end

local function buildBoundaryWalls(parent: Instance): ()
	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "BoundaryWalls"
	wallsFolder.Parent = parent

	local wallSpecs = {
		{ size = Vector3.new(12, 460, 540), cframe = CFrame.new(-260, -100, 0) },
		{ size = Vector3.new(12, 460, 540), cframe = CFrame.new(260, -100, 0) },
		{ size = Vector3.new(540, 460, 12), cframe = CFrame.new(0, -100, 260) },
		{ size = Vector3.new(540, 460, 12), cframe = CFrame.new(0, -100, -260) },
		{ size = Vector3.new(540, 16, 540), cframe = CFrame.new(0, -314, 0) },
	}

	for index, spec in ipairs(wallSpecs) do
		createPart({
			name = "Boundary_" .. tostring(index),
			size = spec.size,
			cframe = spec.cframe,
			color = Color3.fromRGB(20, 30, 50),
			transparency = 1,
			canCollide = true,
			parent = wallsFolder,
		})
	end
end

local function buildPalmTree(parent: Instance, basePos: Vector3, leanDir: Vector3, scale: number): ()
	local tree = Instance.new("Model")
	tree.Name = "PalmTree"
	tree.Parent = parent

	local currentPos = basePos
	local segments = 6
	for i = 1, segments do
		local t = i / segments
		local nextPos = currentPos + Vector3.new(leanDir.X * (0.9 + t * 1.4), 2.5 * scale, leanDir.Z * (0.9 + t * 1.4))
		local mid = (currentPos + nextPos) * 0.5
		local look = CFrame.lookAt(mid, nextPos)
		local radius = (1.15 - t * 0.48) * scale
		createPart({
			name = "Trunk_" .. tostring(i),
			size = Vector3.new(radius * 2, radius * 2, (nextPos - currentPos).Magnitude + 0.35),
			cframe = look,
			color = Color3.fromRGB(134, 96, 62),
			material = Enum.Material.Wood,
			parent = tree,
		})
		currentPos = nextPos
	end

	-- Coconuts
	for c = 1, 3 do
		local angle = (c / 3) * math.pi * 2
		createPart({
			name = "Coconut_" .. tostring(c),
			size = Vector3.new(1.3, 1.4, 1.3) * scale,
			cframe = CFrame.new(currentPos + Vector3.new(math.cos(angle) * 0.9 * scale, -0.5 * scale, math.sin(angle) * 0.9 * scale)),
			color = Color3.fromRGB(98, 66, 38),
			material = Enum.Material.Wood,
			shape = Enum.PartType.Ball,
			parent = tree,
		})
	end

	-- Fronds
	local frondCount = 7
	for f = 1, frondCount do
		local yaw = (f / frondCount) * math.pi * 2
		local baseCFrame = CFrame.new(currentPos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-0.32, 0, 0)
		createPart({
			name = "FrondInner_" .. tostring(f),
			size = Vector3.new(2.2 * scale, 0.25 * scale, 5.2 * scale),
			cframe = baseCFrame * CFrame.new(0, 0, -2.5 * scale),
			color = Color3.fromRGB(72, 168, 86),
			material = Enum.Material.Grass,
			canCollide = false,
			parent = tree,
		})
		createPart({
			name = "FrondOuter_" .. tostring(f),
			size = Vector3.new(1.6 * scale, 0.2 * scale, 4.4 * scale),
			cframe = baseCFrame * CFrame.new(0, -0.45 * scale, -5.8 * scale) * CFrame.Angles(-0.36, 0, 0),
			color = Color3.fromRGB(88, 186, 98),
			material = Enum.Material.Grass,
			canCollide = false,
			parent = tree,
		})
	end
end

local function buildLantern(parent: Instance, pos: Vector3, height: number): ()
	local model = Instance.new("Model")
	model.Name = "HarborLantern"
	model.Parent = parent

	createPart({
		name = "Post",
		size = Vector3.new(0.6, height, 0.6),
		cframe = CFrame.new(pos + Vector3.new(0, height * 0.5, 0)),
		color = Color3.fromRGB(74, 54, 42),
		material = Enum.Material.Wood,
		parent = model,
	})
	createPart({
		name = "Cap",
		size = Vector3.new(1.3, 0.35, 1.3),
		cframe = CFrame.new(pos + Vector3.new(0, height + 0.85, 0)),
		color = Color3.fromRGB(48, 52, 62),
		material = Enum.Material.Metal,
		parent = model,
	})
	local bulb = createPart({
		name = "GlowBulb",
		size = Vector3.new(0.85, 0.95, 0.85),
		cframe = CFrame.new(pos + Vector3.new(0, height + 0.3, 0)),
		color = Color3.fromRGB(255, 212, 128),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 212, 138)
	light.Range = 28
	light.Brightness = 1.4
	light.Parent = bulb
end

local function buildMooredBoat(parent: Instance, origin: Vector3, yawRad: number, hullColor: Color3): ()
	local boat = Instance.new("Model")
	boat.Name = "MooredBoat"
	boat.Parent = parent

	local baseCf = CFrame.new(origin) * CFrame.Angles(0, yawRad, 0)
	-- Hull floor & sides
	createPart({
		name = "HullFloor",
		size = Vector3.new(6.8, 1.0, 15.0),
		cframe = baseCf * CFrame.new(0, 0, 0),
		color = hullColor,
		material = Enum.Material.WoodPlanks,
		parent = boat,
	})
	createPart({
		name = "LeftGunwale",
		size = Vector3.new(0.7, 2.2, 15.0),
		cframe = baseCf * CFrame.new(-3.2, 1.2, 0),
		color = Color3.fromRGB(242, 240, 234),
		material = Enum.Material.WoodPlanks,
		parent = boat,
	})
	createPart({
		name = "RightGunwale",
		size = Vector3.new(0.7, 2.2, 15.0),
		cframe = baseCf * CFrame.new(3.2, 1.2, 0),
		color = Color3.fromRGB(242, 240, 234),
		material = Enum.Material.WoodPlanks,
		parent = boat,
	})
	createPart({
		name = "Stern",
		size = Vector3.new(7.0, 2.2, 0.8),
		cframe = baseCf * CFrame.new(0, 1.2, 7.2),
		color = hullColor,
		material = Enum.Material.WoodPlanks,
		parent = boat,
	})
	createWedge({
		name = "Bow",
		size = Vector3.new(6.8, 2.6, 4.4),
		cframe = baseCf * CFrame.new(0, 1.2, -9.6) * CFrame.Angles(0, math.pi, 0),
		color = hullColor,
		material = Enum.Material.WoodPlanks,
		parent = boat,
	})
	-- Cabin & Benches
	createPart({
		name = "Bench1",
		size = Vector3.new(5.6, 0.5, 1.5),
		cframe = baseCf * CFrame.new(0, 1.1, -3.5),
		color = Color3.fromRGB(168, 118, 72),
		material = Enum.Material.Wood,
		parent = boat,
	})
	createPart({
		name = "Cabin",
		size = Vector3.new(4.8, 3.6, 4.8),
		cframe = baseCf * CFrame.new(0, 2.3, 2.8),
		color = Color3.fromRGB(244, 248, 255),
		material = Enum.Material.SmoothPlastic,
		parent = boat,
	})
	createPart({
		name = "CabinRoof",
		size = Vector3.new(5.4, 0.4, 5.4),
		cframe = baseCf * CFrame.new(0, 4.3, 2.8),
		color = Color3.fromRGB(58, 154, 214),
		material = Enum.Material.SmoothPlastic,
		parent = boat,
	})
	createPart({
		name = "DiveFlagMast",
		size = Vector3.new(0.25, 6.2, 0.25),
		cframe = baseCf * CFrame.new(0, 6.8, 2.8),
		color = Color3.fromRGB(210, 214, 224),
		material = Enum.Material.Metal,
		parent = boat,
	})
	createPart({
		name = "DiveFlag",
		size = Vector3.new(0.15, 1.8, 2.8),
		cframe = baseCf * CFrame.new(0, 8.9, 4.2),
		color = Color3.fromRGB(236, 62, 74),
		material = Enum.Material.Fabric,
		canCollide = false,
		parent = boat,
	})
end

local function buildCleaningStation(parent: Instance): ()
	local origin = GameConfig.CLEANING_STATION_POSITION
	local model = Instance.new("Model")
	model.Name = "CleaningStation"
	model.Parent = parent

	-- Deck base
	createPart({
		name = "DeckBase",
		size = Vector3.new(16, 0.8, 24),
		cframe = CFrame.new(origin + Vector3.new(0, 0.4, 0)),
		color = Color3.fromRGB(142, 102, 68),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})

	-- Canopy corners & roof
	local postOffsets = {
		Vector3.new(-7, 5, -10.5),
		Vector3.new(7, 5, -10.5),
		Vector3.new(-7, 5, 10.5),
		Vector3.new(7, 5, 10.5),
	}
	for idx, off in ipairs(postOffsets) do
		createPart({
			name = "CanopyPost_" .. tostring(idx),
			size = Vector3.new(0.9, 10, 0.9),
			cframe = CFrame.new(origin + off),
			color = Color3.fromRGB(112, 76, 48),
			material = Enum.Material.Wood,
			parent = model,
		})
	end

	local canopy = createPart({
		name = "CanopyRoof",
		size = Vector3.new(17.5, 0.7, 25),
		cframe = CFrame.new(origin + Vector3.new(0, 10.2, 0)),
		color = Color3.fromRGB(54, 168, 212),
		material = Enum.Material.Fabric,
		parent = model,
	})
	local signBoard = createPart({
		name = "StationSign",
		size = Vector3.new(0.6, 2.4, 15.5),
		cframe = CFrame.new(origin + Vector3.new(7.4, 8.8, 0)),
		color = Color3.fromRGB(26, 42, 68),
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})
	addSurfaceSign(signBoard, Enum.NormalId.Right, "RELIC CLEANING STATION", "Scrub & Reveal Hidden Treasures", Color3.fromRGB(20, 44, 72), Color3.fromRGB(108, 236, 255))

	-- Water tank barrel on back side
	createPart({
		name = "WaterTank",
		size = Vector3.new(4.2, 5.2, 4.2),
		cframe = CFrame.new(origin + Vector3.new(-4.8, 3.0, -7.8)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(108, 76, 52),
		material = Enum.Material.Wood,
		shape = Enum.PartType.Cylinder,
		parent = model,
	})

	-- 3 Washbasins with live brushes and BillboardGui progress displays
	local slotZOffsets = { -6.5, 0, 6.5 }
	for slotIndex, zOff in ipairs(slotZOffsets) do
		local basinCenter = origin + Vector3.new(1.5, 2.2, zOff)
		local basinModel = Instance.new("Model")
		basinModel.Name = "WashBasin_" .. tostring(slotIndex)
		basinModel:SetAttribute("SlotIndex", slotIndex)
		basinModel.Parent = model

		createPart({
			name = "Pedestal",
			size = Vector3.new(4.8, 2.8, 4.8),
			cframe = CFrame.new(basinCenter + Vector3.new(0, -0.4, 0)),
			color = Color3.fromRGB(196, 206, 218),
			material = Enum.Material.Marble,
			parent = basinModel,
		})
		createPart({
			name = "RimFront",
			size = Vector3.new(0.5, 1.3, 4.8),
			cframe = CFrame.new(basinCenter + Vector3.new(2.15, 1.4, 0)),
			color = Color3.fromRGB(224, 232, 240),
			material = Enum.Material.Marble,
			parent = basinModel,
		})
		createPart({
			name = "RimBack",
			size = Vector3.new(0.5, 1.3, 4.8),
			cframe = CFrame.new(basinCenter + Vector3.new(-2.15, 1.4, 0)),
			color = Color3.fromRGB(224, 232, 240),
			material = Enum.Material.Marble,
			parent = basinModel,
		})
		createPart({
			name = "RimLeft",
			size = Vector3.new(4.8, 1.3, 0.5),
			cframe = CFrame.new(basinCenter + Vector3.new(0, 1.4, -2.15)),
			color = Color3.fromRGB(224, 232, 240),
			material = Enum.Material.Marble,
			parent = basinModel,
		})
		createPart({
			name = "RimRight",
			size = Vector3.new(4.8, 1.3, 0.5),
			cframe = CFrame.new(basinCenter + Vector3.new(0, 1.4, 2.15)),
			color = Color3.fromRGB(224, 232, 240),
			material = Enum.Material.Marble,
			parent = basinModel,
		})

		local waterSurface = createPart({
			name = "WashWater",
			size = Vector3.new(3.8, 0.3, 3.8),
			cframe = CFrame.new(basinCenter + Vector3.new(0, 1.55, 0)),
			color = Color3.fromRGB(84, 212, 244),
			material = Enum.Material.Glass,
			transparency = 0.25,
			canCollide = false,
			parent = basinModel,
		})

		-- Relic orb inside basin (hidden when empty, colored by client when scrubbing!)
		createPart({
			name = "RelicPreview",
			size = Vector3.new(1.3, 1.3, 1.3),
			cframe = CFrame.new(basinCenter + Vector3.new(0, 1.9, 0)),
			color = Color3.fromRGB(168, 162, 152),
			material = Enum.Material.Slate,
			transparency = 1,
			canCollide = false,
			shape = Enum.PartType.Ball,
			parent = basinModel,
		})

		-- Scrub brush model
		local brushModel = Instance.new("Model")
		brushModel.Name = "ScrubBrush"
		brushModel:SetAttribute("BasePos", basinCenter + Vector3.new(0, 2.65, 0))
		brushModel.Parent = basinModel

		local brushBlock = createPart({
			name = "BrushWood",
			size = Vector3.new(1.8, 0.45, 0.9),
			cframe = CFrame.new(basinCenter + Vector3.new(0, 2.65, 0)),
			color = Color3.fromRGB(196, 146, 86),
			material = Enum.Material.Wood,
			canCollide = false,
			parent = brushModel,
		})
		createPart({
			name = "Bristles",
			size = Vector3.new(1.6, 0.45, 0.75),
			cframe = CFrame.new(basinCenter + Vector3.new(0, 2.25, 0)),
			color = Color3.fromRGB(246, 246, 238),
			material = Enum.Material.Fabric,
			canCollide = false,
			parent = brushModel,
		})
		brushModel.PrimaryPart = brushBlock

		-- Live progress BillboardGui above each basin
		local bGui = Instance.new("BillboardGui")
		bGui.Name = "SlotProgressGui"
		bGui.Adornee = waterSurface
		bGui.Size = UDim2.fromOffset(180, 68)
		bGui.StudsOffset = Vector3.new(0, 3.6, 0)
		bGui.MaxDistance = 48
		bGui.AlwaysOnTop = false
		bGui.Parent = basinModel

		local frame = Instance.new("Frame")
		frame.Name = "Container"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
		frame.BackgroundTransparency = 0.14
		frame.Parent = bGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Name = "BorderStroke"
		stroke.Color = Color3.fromRGB(82, 186, 244)
		stroke.Thickness = 2
		stroke.Parent = frame

		local label = Instance.new("TextLabel")
		label.Name = "StatusLabel"
		label.Position = UDim2.fromScale(0.06, 0.08)
		label.Size = UDim2.fromScale(0.88, 0.45)
		label.BackgroundTransparency = 1
		label.Text = string.format("Basin %d: Empty", slotIndex)
		label.TextColor3 = Color3.fromRGB(228, 244, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = frame

		local barBg = Instance.new("Frame")
		barBg.Name = "BarBg"
		barBg.Position = UDim2.fromScale(0.08, 0.62)
		barBg.Size = UDim2.fromScale(0.84, 0.24)
		barBg.BackgroundColor3 = Color3.fromRGB(36, 48, 72)
		barBg.BorderSizePixel = 0
		barBg.Parent = frame

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 6)
		barCorner.Parent = barBg

		local barFill = Instance.new("Frame")
		barFill.Name = "BarFill"
		barFill.Size = UDim2.fromScale(0, 1)
		barFill.BackgroundColor3 = Color3.fromRGB(78, 224, 255)
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 6)
		fillCorner.Parent = barFill
	end

	-- Invisible interaction anchor for proximity prompt
	local interact = createPart({
		name = "CleaningStationInteract",
		size = Vector3.new(14, 6, 20),
		cframe = CFrame.new(origin + Vector3.new(1, 3, 0)),
		color = Color3.new(1, 1, 1),
		transparency = 1,
		canCollide = false,
		parent = model,
	})
	interact:SetAttribute("InteractType", "CleaningStation")

	-- Reference canopy so Luau doesn't flag unused
	canopy:SetAttribute("StationPart", true)
end

local function buildAppraisalCounter(parent: Instance): ()
	local origin = GameConfig.APPRAISAL_COUNTER_POSITION
	local model = Instance.new("Model")
	model.Name = "AppraisalCounter"
	model.Parent = parent

	createPart({
		name = "Platform",
		size = Vector3.new(14, 0.8, 16),
		cframe = CFrame.new(origin + Vector3.new(0, 0.4, 0)),
		color = Color3.fromRGB(224, 214, 198),
		material = Enum.Material.Marble,
		parent = model,
	})
	createPart({
		name = "CounterBody",
		size = Vector3.new(3.6, 3.6, 12),
		cframe = CFrame.new(origin + Vector3.new(2.2, 2.4, 0)),
		color = Color3.fromRGB(112, 62, 42),
		material = Enum.Material.Wood,
		parent = model,
	})
	createPart({
		name = "VelvetRunner",
		size = Vector3.new(2.4, 0.2, 10.6),
		cframe = CFrame.new(origin + Vector3.new(2.2, 4.3, 0)),
		color = Color3.fromRGB(168, 38, 72),
		material = Enum.Material.Fabric,
		parent = model,
	})
	-- Golden Appraisal Scale
	createPart({
		name = "ScaleBase",
		size = Vector3.new(1.4, 0.4, 1.4),
		cframe = CFrame.new(origin + Vector3.new(2.2, 4.6, -2.5)),
		color = Color3.fromRGB(246, 198, 72),
		material = Enum.Material.Metal,
		parent = model,
	})
	createPart({
		name = "ScalePillar",
		size = Vector3.new(0.25, 2.0, 0.25),
		cframe = CFrame.new(origin + Vector3.new(2.2, 5.6, -2.5)),
		color = Color3.fromRGB(246, 198, 72),
		material = Enum.Material.Metal,
		parent = model,
	})
	createPart({
		name = "ScaleBeam",
		size = Vector3.new(0.2, 0.2, 2.4),
		cframe = CFrame.new(origin + Vector3.new(2.2, 6.4, -2.5)),
		color = Color3.fromRGB(246, 198, 72),
		material = Enum.Material.Metal,
		parent = model,
	})
	-- Coin Treasure Chest prop
	createPart({
		name = "GoldPile",
		size = Vector3.new(1.8, 0.9, 2.2),
		cframe = CFrame.new(origin + Vector3.new(2.2, 4.8, 2.6)),
		color = Color3.fromRGB(255, 206, 68),
		material = Enum.Material.Neon,
		parent = model,
	})
	-- Back wall sign
	createPart({
		name = "BackPillarL",
		size = Vector3.new(0.8, 8.5, 0.8),
		cframe = CFrame.new(origin + Vector3.new(-3.5, 4.5, -5.5)),
		color = Color3.fromRGB(112, 62, 42),
		material = Enum.Material.Wood,
		parent = model,
	})
	createPart({
		name = "BackPillarR",
		size = Vector3.new(0.8, 8.5, 0.8),
		cframe = CFrame.new(origin + Vector3.new(-3.5, 4.5, 5.5)),
		color = Color3.fromRGB(112, 62, 42),
		material = Enum.Material.Wood,
		parent = model,
	})
	local sign = createPart({
		name = "AppraisalSign",
		size = Vector3.new(0.6, 2.6, 12.2),
		cframe = CFrame.new(origin + Vector3.new(-3.5, 8.6, 0)),
		color = Color3.fromRGB(64, 34, 18),
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})
	addSurfaceSign(sign, Enum.NormalId.Right, "APPRAISAL & SELL COUNTER", "Cash In Cleaned Treasures & Fossils", Color3.fromRGB(58, 32, 16), Color3.fromRGB(255, 214, 88))

	local interact = createPart({
		name = "AppraisalInteract",
		size = Vector3.new(12, 6, 14),
		cframe = CFrame.new(origin + Vector3.new(1.5, 3, 0)),
		color = Color3.new(1, 1, 1),
		transparency = 1,
		canCollide = false,
		parent = model,
	})
	interact:SetAttribute("InteractType", "AppraisalCounter")
end

local function buildDiveShopStall(parent: Instance): ()
	local origin = GameConfig.SHOP_STALL_POSITION
	local model = Instance.new("Model")
	model.Name = "DiveGearShop"
	model.Parent = parent

	createPart({
		name = "FloorDeck",
		size = Vector3.new(16, 0.8, 22),
		cframe = CFrame.new(origin + Vector3.new(0, 0.4, 0)),
		color = Color3.fromRGB(156, 114, 78),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	createPart({
		name = "ShopCounter",
		size = Vector3.new(3.2, 3.4, 16),
		cframe = CFrame.new(origin + Vector3.new(-2.4, 2.2, 0)),
		color = Color3.fromRGB(62, 122, 158),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})

	-- Awning posts & striped roof
	for idx, zOff in ipairs({ -9.5, 9.5 }) do
		createPart({
			name = "FrontPost_" .. tostring(idx),
			size = Vector3.new(0.8, 9.5, 0.8),
			cframe = CFrame.new(origin + Vector3.new(-6.2, 4.8, zOff)),
			color = Color3.fromRGB(224, 232, 240),
			material = Enum.Material.Wood,
			parent = model,
		})
		createPart({
			name = "BackPost_" .. tostring(idx),
			size = Vector3.new(0.8, 10.5, 0.8),
			cframe = CFrame.new(origin + Vector3.new(6.2, 5.2, zOff)),
			color = Color3.fromRGB(224, 232, 240),
			material = Enum.Material.Wood,
			parent = model,
		})
	end

	for s = -4, 4 do
		local stripeColor = if s % 2 == 0 then Color3.fromRGB(48, 186, 208) else Color3.fromRGB(252, 248, 240)
		createPart({
			name = "AwningStripe_" .. tostring(s),
			size = Vector3.new(14.6, 0.5, 2.3),
			cframe = CFrame.new(origin + Vector3.new(0, 9.8, s * 2.3)) * CFrame.Angles(0, 0, math.rad(10)),
			color = stripeColor,
			material = Enum.Material.Fabric,
			parent = model,
		})
	end

	-- Display Potion Bottles & Oxygen Tanks on counter
	local bottleColors = {
		Color3.fromRGB(82, 224, 255),
		Color3.fromRGB(112, 248, 178),
		Color3.fromRGB(255, 206, 86),
		Color3.fromRGB(234, 146, 255),
	}
	for i, col in ipairs(bottleColors) do
		createPart({
			name = "DisplayPotion_" .. tostring(i),
			size = Vector3.new(0.8, 1.3, 0.8),
			cframe = CFrame.new(origin + Vector3.new(-2.4, 4.6, -5.5 + (i - 1) * 2.4)),
			color = col,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
			parent = model,
		})
	end
	createPart({
		name = "DisplayTank",
		size = Vector3.new(2.2, 1.3, 1.3),
		cframe = CFrame.new(origin + Vector3.new(-2.4, 5.0, 5.2)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(246, 186, 54),
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		parent = model,
	})

	local sign = createPart({
		name = "ShopSign",
		size = Vector3.new(0.6, 2.6, 16),
		cframe = CFrame.new(origin + Vector3.new(-6.6, 8.6, 0)),
		color = Color3.fromRGB(18, 48, 72),
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})
	addSurfaceSign(sign, Enum.NormalId.Left, "DIVE GEAR & BUFF SHOP", "Upgrade Tank, Fins, Flashlight & Potions", Color3.fromRGB(16, 44, 72), Color3.fromRGB(122, 244, 212))

	local interact = createPart({
		name = "ShopInteract",
		size = Vector3.new(14, 6, 18),
		cframe = CFrame.new(origin + Vector3.new(-2.0, 3, 0)),
		color = Color3.new(1, 1, 1),
		transparency = 1,
		canCollide = false,
		parent = model,
	})
	interact:SetAttribute("InteractType", "GearShop")
end

local function buildEggShrine(parent: Instance): ()
	local origin = GameConfig.EGG_SHRINE_POSITION
	local model = Instance.new("Model")
	model.Name = "EggHatchingShrine"
	model.Parent = parent

	-- Stepped shrine platform
	createPart({
		name = "ShrineStep1",
		size = Vector3.new(20, 0.9, 28),
		cframe = CFrame.new(origin + Vector3.new(0, 0.45, 0)),
		color = Color3.fromRGB(230, 232, 246),
		material = Enum.Material.Marble,
		parent = model,
	})
	createPart({
		name = "ShrineStep2",
		size = Vector3.new(17, 0.7, 25),
		cframe = CFrame.new(origin + Vector3.new(0, 1.25, 0)),
		color = Color3.fromRGB(244, 242, 255),
		material = Enum.Material.Marble,
		parent = model,
	})
	createPart({
		name = "ShrineGlowRing",
		size = Vector3.new(0.4, 14, 14),
		cframe = CFrame.new(origin + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(255, 168, 238),
		material = Enum.Material.Neon,
		transparency = 0.25,
		canCollide = false,
		shape = Enum.PartType.Cylinder,
		parent = model,
	})

	-- Shrine Sign Arch
	createPart({
		name = "ArchPillarL",
		size = Vector3.new(1.2, 10.5, 1.2),
		cframe = CFrame.new(origin + Vector3.new(-7.5, 6.2, -11.5)),
		color = Color3.fromRGB(238, 236, 252),
		material = Enum.Material.Marble,
		parent = model,
	})
	createPart({
		name = "ArchPillarR",
		size = Vector3.new(1.2, 10.5, 1.2),
		cframe = CFrame.new(origin + Vector3.new(-7.5, 6.2, 11.5)),
		color = Color3.fromRGB(238, 236, 252),
		material = Enum.Material.Marble,
		parent = model,
	})
	local sign = createPart({
		name = "ShrineSign",
		size = Vector3.new(0.8, 2.5, 22),
		cframe = CFrame.new(origin + Vector3.new(-7.5, 11.2, 0)),
		color = Color3.fromRGB(64, 34, 96),
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})
	addSurfaceSign(sign, Enum.NormalId.Left, "ANIME COMPANION EGG SHRINE", "Hatch Guardians That Swim & Buff Your Stats", Color3.fromRGB(62, 28, 92), Color3.fromRGB(255, 186, 242))

	-- 4 Egg Pedestals + Rarity Rate Boards
	local zPositions = { -9.0, -3.0, 3.0, 9.0 }
	for idx, eggId in ipairs(GameConfig.EGG_ORDER) do
		local eggConfig = GameConfig.EGGS[eggId]
		local pedPos = origin + Vector3.new(2.4, 1.6, zPositions[idx])
		local pedModel = Instance.new("Model")
		pedModel.Name = "EggPedestal_" .. eggId
		pedModel.Parent = model

		createPart({
			name = "PedestalBase",
			size = Vector3.new(3.6, 2.6, 3.6),
			cframe = CFrame.new(pedPos + Vector3.new(0, 1.3, 0)),
			color = Color3.fromRGB(242, 240, 252),
			material = Enum.Material.Marble,
			parent = pedModel,
		})
		createPart({
			name = "PedestalHalo",
			size = Vector3.new(3.9, 0.35, 3.9),
			cframe = CFrame.new(pedPos + Vector3.new(0, 2.7, 0)),
			color = eggConfig.secondaryColor,
			material = Enum.Material.Neon,
			parent = pedModel,
		})

		-- Sculpted Egg
		local eggPart = createPart({
			name = "EggMeshPart",
			size = Vector3.new(2.6, 3.5, 2.6),
			cframe = CFrame.new(pedPos + Vector3.new(0, 4.8, 0)),
			color = eggConfig.primaryColor,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = pedModel,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.15, 1)
		mesh.Parent = eggPart

		local eggLight = Instance.new("PointLight")
		eggLight.Color = eggConfig.primaryColor
		eggLight.Range = 14
		eggLight.Brightness = 1.2
		eggLight.Parent = eggPart

		eggPart:SetAttribute("InteractType", "EggPedestal")
		eggPart:SetAttribute("EggId", eggId)

		-- Decorative Band Ring
		createPart({
			name = "EggRing",
			size = Vector3.new(2.75, 0.45, 2.75),
			cframe = CFrame.new(pedPos + Vector3.new(0, 4.8, 0)),
			color = eggConfig.secondaryColor,
			material = Enum.Material.Neon,
			canCollide = false,
			shape = Enum.PartType.Cylinder,
			parent = pedModel,
		})

		-- Rarity Rate Board directly behind the pedestal facing West (toward plaza)
		local boardPost = createPart({
			name = "BoardPost",
			size = Vector3.new(0.4, 5.2, 0.4),
			cframe = CFrame.new(pedPos + Vector3.new(3.4, 2.6, 0)),
			color = Color3.fromRGB(224, 224, 236),
			material = Enum.Material.Marble,
			parent = pedModel,
		})
		local board = createPart({
			name = "RarityBoard",
			size = Vector3.new(0.4, 4.8, 4.4),
			cframe = CFrame.new(pedPos + Vector3.new(3.2, 6.2, 0)),
			color = Color3.fromRGB(22, 24, 44),
			material = Enum.Material.SmoothPlastic,
			parent = pedModel,
		})
		boardPost:SetAttribute("BoardPart", true)

		local boardGui = Instance.new("SurfaceGui")
		boardGui.Face = Enum.NormalId.Left
		boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		boardGui.PixelsPerStud = 55
		boardGui.LightInfluence = 0.15
		boardGui.Parent = board

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(20, 24, 46)
		bg.BorderSizePixel = 0
		bg.Parent = boardGui

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0.02, 0)
		layout.Parent = bg

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.04, 0)
		pad.PaddingBottom = UDim.new(0.04, 0)
		pad.PaddingLeft = UDim.new(0.06, 0)
		pad.PaddingRight = UDim.new(0.06, 0)
		pad.Parent = bg

		local header = Instance.new("TextLabel")
		header.Size = UDim2.fromScale(1, 0.18)
		header.BackgroundTransparency = 1
		header.Text = eggConfig.name
		header.TextColor3 = eggConfig.primaryColor
		header.TextScaled = true
		header.Font = Enum.Font.GothamBold
		header.Parent = bg

		local costLbl = Instance.new("TextLabel")
		costLbl.Size = UDim2.fromScale(1, 0.14)
		costLbl.BackgroundTransparency = 1
		costLbl.Text = GameConfig.FormatNumber(eggConfig.cost) .. " Coins"
		costLbl.TextColor3 = Color3.fromRGB(255, 214, 88)
		costLbl.TextScaled = true
		costLbl.Font = Enum.Font.GothamBold
		costLbl.Parent = bg

		local totalWeight = 0
		for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
			totalWeight += eggConfig.rarityWeights[rarity] or 0
		end
		for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
			local weight = eggConfig.rarityWeights[rarity] or 0
			if weight > 0 and totalWeight > 0 then
				local pct = (weight / totalWeight) * 100
				local row = Instance.new("TextLabel")
				row.Size = UDim2.fromScale(1, 0.13)
				row.BackgroundTransparency = 1
				row.Text = string.format("%s: %.0f%%", rarity, pct)
				row.TextColor3 = GameConfig.RARITY_META[rarity].color
				row.TextScaled = true
				row.Font = Enum.Font.GothamMedium
				row.Parent = bg
			end
		end
	end
end

local function buildHarborHub(parent: Instance): ()
	local hub = Instance.new("Folder")
	hub.Name = "HarborHub"
	hub.Parent = parent

	-- Paved Harbor Stone Plaza (top at Y = 6.0)
	createPart({
		name = "MainPlazaDeck",
		size = Vector3.new(124, 18, 66),
		cframe = CFrame.new(0, -3.0, -151),
		color = Color3.fromRGB(224, 210, 184),
		material = Enum.Material.Cobblestone,
		parent = hub,
	})
	-- Seawall front curb
	createPart({
		name = "SeawallCurbLeft",
		size = Vector3.new(50, 2.2, 2.4),
		cframe = CFrame.new(-37, 6.2, -118.5),
		color = Color3.fromRGB(168, 158, 144),
		material = Enum.Material.Brick,
		parent = hub,
	})
	createPart({
		name = "SeawallCurbRight",
		size = Vector3.new(50, 2.2, 2.4),
		cframe = CFrame.new(37, 6.2, -118.5),
		color = Color3.fromRGB(168, 158, 144),
		material = Enum.Material.Brick,
		parent = hub,
	})

	-- SpawnLocation at center of plaza facing South (+Z) toward Pier & Ocean
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "HarborSpawn"
	spawnLoc.Size = Vector3.new(12, 0.8, 12)
	spawnLoc.CFrame = CFrame.new(0, 6.2, -150) * CFrame.Angles(0, math.pi, 0)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(92, 182, 214)
	spawnLoc.Material = Enum.Material.Marble
	spawnLoc.Duration = 0
	spawnLoc.Parent = hub

	-- Harbor Compass Emblem around Spawn
	createPart({
		name = "PlazaCenterRing",
		size = Vector3.new(0.4, 20, 20),
		cframe = CFrame.new(0, 6.02, -150) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(72, 166, 206),
		material = Enum.Material.Marble,
		canCollide = false,
		shape = Enum.PartType.Cylinder,
		parent = hub,
	})

	-- Main Wooden Pier extending South (Z = -118 to -52)
	createPart({
		name = "MainPierDeck",
		size = Vector3.new(18, 1.2, 66),
		cframe = CFrame.new(0, 5.2, -85),
		color = Color3.fromRGB(154, 108, 68),
		material = Enum.Material.WoodPlanks,
		parent = hub,
	})

	-- Pier pilings going deep into seabed
	for z = -112, -54, 14 do
		for _, xOff in ipairs({ -8.2, 8.2 }) do
			createPart({
				name = "PierPiling",
				size = Vector3.new(1.8, 52, 1.8),
				cframe = CFrame.new(xOff, -19, z),
				color = Color3.fromRGB(98, 70, 48),
				material = Enum.Material.Wood,
				shape = Enum.PartType.Cylinder,
				parent = hub,
			})
			-- Mooring bollards on top
			createPart({
				name = "Bollard",
				size = Vector3.new(1.5, 2.2, 1.5),
				cframe = CFrame.new(xOff, 6.8, z),
				color = Color3.fromRGB(76, 56, 42),
				material = Enum.Material.Wood,
				parent = hub,
			})
		end
	end

	-- Pier lanterns
	for z = -112, -56, 28 do
		buildLantern(hub, Vector3.new(-8.2, 5.8, z), 6.2)
		buildLantern(hub, Vector3.new(8.2, 5.8, z), 6.2)
	end
	buildLantern(hub, Vector3.new(-16, 6.0, -120), 6.8)
	buildLantern(hub, Vector3.new(16, 6.0, -120), 6.8)

	-- Pier Entrance Archway
	createPart({
		name = "PierArchL",
		size = Vector3.new(1.4, 11, 1.4),
		cframe = CFrame.new(-8.2, 11.2, -118),
		color = Color3.fromRGB(116, 80, 52),
		material = Enum.Material.Wood,
		parent = hub,
	})
	createPart({
		name = "PierArchR",
		size = Vector3.new(1.4, 11, 1.4),
		cframe = CFrame.new(8.2, 11.2, -118),
		color = Color3.fromRGB(116, 80, 52),
		material = Enum.Material.Wood,
		parent = hub,
	})
	local archSign = createPart({
		name = "PierArchSign",
		size = Vector3.new(18, 2.8, 1.0),
		cframe = CFrame.new(0, 15.6, -118),
		color = Color3.fromRGB(22, 46, 74),
		material = Enum.Material.SmoothPlastic,
		parent = hub,
	})
	addSurfaceSign(archSign, Enum.NormalId.Back, "ABYSSAL HARBOR • DIVE PIER", "Jump In & Excavate Sunken Relics!", Color3.fromRGB(18, 42, 72), Color3.fromRGB(122, 240, 255))
	addSurfaceSign(archSign, Enum.NormalId.Front, "WELCOME BACK TO HARBOR", "Clean Relics • Sell • Upgrade • Hatch Pets", Color3.fromRGB(18, 42, 72), Color3.fromRGB(255, 224, 128))

	-- Sloped Dive & Re-entry Ramp at end of Pier (Z = -52 to -34, Y = 5.5 down to -3.5)
	createWedge({
		name = "PierDiveRamp",
		size = Vector3.new(14, 9.0, 18),
		cframe = CFrame.new(0, 1.2, -43) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(148, 106, 68),
		material = Enum.Material.WoodPlanks,
		parent = hub,
	})
	-- Side dive steps
	for step = 1, 4 do
		createPart({
			name = "SideDiveStep_" .. tostring(step),
			size = Vector3.new(6, 1.2, 3.2),
			cframe = CFrame.new(-12, 5.2 - step * 1.8, -58 - step * 2.5),
			color = Color3.fromRGB(142, 98, 62),
			material = Enum.Material.WoodPlanks,
			parent = hub,
		})
	end

	-- Two Moored Boats beside the pier
	buildMooredBoat(hub, Vector3.new(-22, 0.2, -78), math.rad(14), Color3.fromRGB(72, 134, 186))
	buildMooredBoat(hub, Vector3.new(23, 0.2, -66), math.rad(-18), Color3.fromRGB(214, 108, 86))

	-- Palm Trees around Harbor Island
	local palmSpecs = {
		{ pos = Vector3.new(-58, 5.8, -124), lean = Vector3.new(0.25, 0, 0.35), scale = 1.2 },
		{ pos = Vector3.new(58, 5.8, -124), lean = Vector3.new(-0.25, 0, 0.35), scale = 1.25 },
		{ pos = Vector3.new(-60, 5.8, -176), lean = Vector3.new(0.2, 0, 0.2), scale = 1.15 },
		{ pos = Vector3.new(60, 5.8, -176), lean = Vector3.new(-0.2, 0, 0.2), scale = 1.15 },
		{ pos = Vector3.new(-72, 3.5, -138), lean = Vector3.new(-0.3, 0, 0.25), scale = 1.05 },
		{ pos = Vector3.new(72, 3.5, -142), lean = Vector3.new(0.3, 0, 0.2), scale = 1.1 },
		{ pos = Vector3.new(-20, 6.0, -182), lean = Vector3.new(0.15, 0, -0.2), scale = 1.3 },
		{ pos = Vector3.new(20, 6.0, -182), lean = Vector3.new(-0.15, 0, -0.2), scale = 1.25 },
	}
	for _, spec in ipairs(palmSpecs) do
		buildPalmTree(hub, spec.pos, spec.lean, spec.scale)
	end

	-- Harbor Crates & Dive Prop Cluster on Pier
	for i = 1, 3 do
		createPart({
			name = "PierCrate_" .. tostring(i),
			size = Vector3.new(2.2, 2.2, 2.2),
			cframe = CFrame.new(6.8, 6.9, -102 + (i - 1) * 2.6) * CFrame.Angles(0, i * 0.2, 0),
			color = Color3.fromRGB(168, 122, 74),
			material = Enum.Material.WoodPlanks,
			parent = hub,
		})
	end

	-- Build 4 functional Harbor Stations
	buildCleaningStation(hub)
	buildAppraisalCounter(hub)
	buildDiveShopStall(hub)
	buildEggShrine(hub)
end

local function buildCoralCluster(parent: Instance, pos: Vector3, primaryColor: Color3, secondaryColor: Color3, scale: number): ()
	local model = Instance.new("Model")
	model.Name = "CoralCluster"
	model.Parent = parent

	createPart({
		name = "RockBase",
		size = Vector3.new(5.5, 2.2, 5.5) * scale,
		cframe = CFrame.new(pos),
		color = Color3.fromRGB(108, 114, 118),
		material = Enum.Material.Rock,
		shape = Enum.PartType.Ball,
		parent = model,
	})
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		local height = (3.0 + (i % 3) * 1.4) * scale
		createPart({
			name = "CoralBranch_" .. tostring(i),
			size = Vector3.new(0.9 * scale, height, 0.9 * scale),
			cframe = CFrame.new(pos + Vector3.new(math.cos(angle) * 1.4 * scale, height * 0.45, math.sin(angle) * 1.4 * scale))
				* CFrame.Angles(math.sin(angle) * 0.35, 0, -math.cos(angle) * 0.35),
			color = if i % 2 == 0 then primaryColor else secondaryColor,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = model,
		})
	end
	local glowTip = createPart({
		name = "AnemoneCore",
		size = Vector3.new(1.8, 1.4, 1.8) * scale,
		cframe = CFrame.new(pos + Vector3.new(0, 1.4 * scale, 0)),
		color = secondaryColor,
		material = Enum.Material.Neon,
		canCollide = false,
		shape = Enum.PartType.Ball,
		parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = secondaryColor
	light.Range = 14 * scale
	light.Brightness = 0.7
	light.Parent = glowTip
end

local function buildSunkenShipwreck(parent: Instance, origin: Vector3): ()
	local wreck = Instance.new("Model")
	wreck.Name = "ShallowShipwreck"
	wreck.Parent = parent

	local cf = CFrame.new(origin) * CFrame.Angles(math.rad(12), math.rad(28), math.rad(-18))
	createPart({
		name = "KeelHull",
		size = Vector3.new(12, 3.5, 34),
		cframe = cf,
		color = Color3.fromRGB(92, 68, 52),
		material = Enum.Material.WoodPlanks,
		parent = wreck,
	})
	for rib = -3, 3 do
		for _, side in ipairs({ -5.5, 5.5 }) do
			createPart({
				name = "HullRib",
				size = Vector3.new(1.1, 7.5, 1.4),
				cframe = cf * CFrame.new(side, 4.2, rib * 4.5) * CFrame.Angles(0, 0, math.rad(side * -2.8)),
				color = Color3.fromRGB(78, 58, 44),
				material = Enum.Material.Wood,
				parent = wreck,
			})
		end
	end
	createPart({
		name = "BrokenMast",
		size = Vector3.new(1.4, 22, 1.4),
		cframe = cf * CFrame.new(0, 11, -3) * CFrame.Angles(math.rad(16), 0, math.rad(8)),
		color = Color3.fromRGB(86, 64, 48),
		material = Enum.Material.Wood,
		parent = wreck,
	})
	createPart({
		name = "Anchor",
		size = Vector3.new(4.2, 6.2, 1.0),
		cframe = CFrame.new(origin + Vector3.new(9, 1.2, -12)) * CFrame.Angles(math.rad(68), 0, math.rad(22)),
		color = Color3.fromRGB(68, 74, 84),
		material = Enum.Material.CorrodedMetal,
		parent = wreck,
	})
end

local function buildTemplePillar(parent: Instance, basePos: Vector3, height: number, broken: boolean): ()
	local model = Instance.new("Model")
	model.Name = "TemplePillar"
	model.Parent = parent

	createPart({
		name = "Plinth",
		size = Vector3.new(5.2, 2.2, 5.2),
		cframe = CFrame.new(basePos + Vector3.new(0, 1.1, 0)),
		color = Color3.fromRGB(152, 168, 174),
		material = Enum.Material.Marble,
		parent = model,
	})
	createPart({
		name = "Column",
		size = Vector3.new(height, 3.6, 3.6),
		cframe = CFrame.new(basePos + Vector3.new(0, 2.2 + height * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(168, 184, 188),
		material = Enum.Material.Marble,
		shape = Enum.PartType.Cylinder,
		parent = model,
	})
	local runeBand = createPart({
		name = "RuneBand",
		size = Vector3.new(0.8, 3.8, 3.8),
		cframe = CFrame.new(basePos + Vector3.new(0, 2.2 + height * 0.65, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(72, 224, 255),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(72, 224, 255)
	light.Range = 24
	light.Brightness = 1.2
	light.Parent = runeBand

	if not broken then
		createPart({
			name = "Capital",
			size = Vector3.new(5.0, 2.0, 5.0),
			cframe = CFrame.new(basePos + Vector3.new(0, 2.2 + height + 1.0, 0)),
			color = Color3.fromRGB(152, 168, 174),
			material = Enum.Material.Marble,
			parent = model,
		})
	end
end

local function buildTempleArchway(parent: Instance, centerPos: Vector3, yawRad: number): ()
	local model = Instance.new("Model")
	model.Name = "SunkenTempleArch"
	model.Parent = parent

	local cf = CFrame.new(centerPos) * CFrame.Angles(0, yawRad, 0)
	for _, xOff in ipairs({ -10, 10 }) do
		createPart({
			name = "ArchCol",
			size = Vector3.new(4.2, 22, 4.2),
			cframe = cf * CFrame.new(xOff, 11, 0),
			color = Color3.fromRGB(158, 174, 182),
			material = Enum.Material.Marble,
			parent = model,
		})
	end
	createPart({
		name = "Lintel",
		size = Vector3.new(26, 4.2, 5.4),
		cframe = cf * CFrame.new(0, 23, 0),
		color = Color3.fromRGB(144, 162, 172),
		material = Enum.Material.Marble,
		parent = model,
	})
	local runeKeystone = createPart({
		name = "ArchKeystone",
		size = Vector3.new(5.0, 2.6, 5.8),
		cframe = cf * CFrame.new(0, 23, 0),
		color = Color3.fromRGB(84, 232, 255),
		material = Enum.Material.Neon,
		parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(84, 232, 255)
	light.Range = 36
	light.Brightness = 1.8
	light.Parent = runeKeystone
end

local function buildCrystalCluster(parent: Instance, basePos: Vector3, crystalColor: Color3, scale: number): ()
	local model = Instance.new("Model")
	model.Name = "AbyssalCrystalCluster"
	model.Parent = parent

	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		local h = (8 + (i % 3) * 4.5) * scale
		local tilt = 0.18 + (i % 2) * 0.22
		local spire = createPart({
			name = "Crystal_" .. tostring(i),
			size = Vector3.new(2.2 * scale, h, 2.2 * scale),
			cframe = CFrame.new(basePos + Vector3.new(math.cos(angle) * 2.0 * scale, h * 0.42, math.sin(angle) * 2.0 * scale))
				* CFrame.Angles(math.sin(angle) * tilt, angle, -math.cos(angle) * tilt),
			color = crystalColor,
			material = Enum.Material.Neon,
			transparency = 0.1,
			parent = model,
		})
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = crystalColor
			light.Range = 32 * scale
			light.Brightness = 1.8
			light.Parent = spire
		end
	end
end

local function buildGiantRibcageFossil(parent: Instance, origin: Vector3): ()
	local fossil = Instance.new("Model")
	fossil.Name = "LeviathanRibcage"
	fossil.Parent = parent

	local boneColor = Color3.fromRGB(224, 218, 202)
	-- Spine vertebrae
	for i = 0, 7 do
		local zPos = origin.Z - 24 + i * 7
		createPart({
			name = "Vertebra_" .. tostring(i),
			size = Vector3.new(4.2, 4.2, 4.8),
			cframe = CFrame.new(origin.X, origin.Y + 2.2, zPos),
			color = boneColor,
			material = Enum.Material.Sandstone,
			parent = fossil,
		})
		-- Paired giant curved ribs forming dramatic archway
		if i >= 1 and i <= 6 then
			for _, side in ipairs({ -1, 1 }) do
				createPart({
					name = "LowerRib",
					size = Vector3.new(2.0, 12.0, 2.0),
					cframe = CFrame.new(origin.X + side * 8.5, origin.Y + 6.5, zPos) * CFrame.Angles(0, 0, math.rad(side * -38)),
					color = boneColor,
					material = Enum.Material.Sandstone,
					parent = fossil,
				})
				createPart({
					name = "UpperRib",
					size = Vector3.new(1.7, 11.0, 1.7),
					cframe = CFrame.new(origin.X + side * 8.0, origin.Y + 15.5, zPos) * CFrame.Angles(0, 0, math.rad(side * 34)),
					color = boneColor,
					material = Enum.Material.Sandstone,
					parent = fossil,
				})
			end
		end
	end

	-- Colossal Leviathan Skull
	createPart({
		name = "LeviathanSkull",
		size = Vector3.new(11, 7.5, 16),
		cframe = CFrame.new(origin.X, origin.Y + 4.0, origin.Z - 34),
		color = boneColor,
		material = Enum.Material.Sandstone,
		parent = fossil,
	})
	for _, side in ipairs({ -3.8, 3.8 }) do
		local eyeGlow = createPart({
			name = "SkullEyeGlow",
			size = Vector3.new(1.6, 1.6, 1.6),
			cframe = CFrame.new(origin.X + side, origin.Y + 5.4, origin.Z - 38),
			color = Color3.fromRGB(168, 92, 255),
			material = Enum.Material.Neon,
			canCollide = false,
			shape = Enum.PartType.Ball,
			parent = fossil,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(168, 92, 255)
		light.Range = 26
		light.Brightness = 1.5
		light.Parent = eyeGlow
	end
end

local function buildUnderwaterEnvironment(parent: Instance): ()
	local env = Instance.new("Folder")
	env.Name = "UnderwaterEnv"
	env.Parent = parent

	-- Zone 1: Shallow Reef Coral Clusters & Shipwreck
	local coralPositions = {
		{ pos = Vector3.new(-28, -26, -78), c1 = Color3.fromRGB(255, 118, 146), c2 = Color3.fromRGB(255, 198, 102), s = 1.1 },
		{ pos = Vector3.new(32, -32, -74), c1 = Color3.fromRGB(112, 232, 212), c2 = Color3.fromRGB(255, 134, 186), s = 1.2 },
		{ pos = Vector3.new(-74, -56, -42), c1 = Color3.fromRGB(255, 152, 92), c2 = Color3.fromRGB(255, 224, 128), s = 1.3 },
		{ pos = Vector3.new(82, -58, -36), c1 = Color3.fromRGB(186, 132, 255), c2 = Color3.fromRGB(102, 232, 244), s = 1.4 },
		{ pos = Vector3.new(-118, -36, -30), c1 = Color3.fromRGB(255, 108, 156), c2 = Color3.fromRGB(122, 244, 188), s = 1.5 },
		{ pos = Vector3.new(124, -28, 28), c1 = Color3.fromRGB(102, 214, 255), c2 = Color3.fromRGB(255, 178, 128), s = 1.4 },
		{ pos = Vector3.new(-106, -40, 142), c1 = Color3.fromRGB(246, 124, 214), c2 = Color3.fromRGB(118, 242, 228), s = 1.3 },
		{ pos = Vector3.new(102, -58, 148), c1 = Color3.fromRGB(255, 188, 92), c2 = Color3.fromRGB(255, 112, 162), s = 1.2 },
		{ pos = Vector3.new(0, -60, 164), c1 = Color3.fromRGB(98, 228, 214), c2 = Color3.fromRGB(214, 148, 255), s = 1.5 },
	}
	for _, spec in ipairs(coralPositions) do
		buildCoralCluster(env, spec.pos, spec.c1, spec.c2, spec.s)
	end

	buildSunkenShipwreck(env, Vector3.new(-102, -62, 24))

	-- Zone 2: Sunken Ruins Pillars & Arches
	buildTempleArchway(env, Vector3.new(0, -152, 10), 0)
	buildTempleArchway(env, Vector3.new(0, -152, 110), 0)
	buildTempleArchway(env, Vector3.new(-50, -152, 60), math.rad(90))
	buildTempleArchway(env, Vector3.new(50, -152, 60), math.rad(90))

	local pillarSpecs = {
		{ pos = Vector3.new(-78, -112, 10), h = 22, broken = false },
		{ pos = Vector3.new(78, -112, 10), h = 16, broken = true },
		{ pos = Vector3.new(-78, -112, 104), h = 18, broken = true },
		{ pos = Vector3.new(78, -112, 104), h = 24, broken = false },
		{ pos = Vector3.new(-50, -152, 22), h = 18, broken = false },
		{ pos = Vector3.new(50, -152, 22), h = 14, broken = true },
		{ pos = Vector3.new(-50, -152, 92), h = 15, broken = true },
		{ pos = Vector3.new(50, -152, 92), h = 20, broken = false },
	}
	for _, spec in ipairs(pillarSpecs) do
		buildTemplePillar(env, spec.pos, spec.h, spec.broken)
	end

	-- Zone 3: Abyssal Trench Glowing Crystals, Giant Ribcage & Deep Bathysphere Wreck
	local crystalSpecs = {
		{ pos = Vector3.new(-28, -220, 42), col = Color3.fromRGB(162, 82, 255), s = 1.1 },
		{ pos = Vector3.new(-28, -220, 74), col = Color3.fromRGB(72, 218, 255), s = 1.0 },
		{ pos = Vector3.new(28, -256, 42), col = Color3.fromRGB(238, 86, 214), s = 1.2 },
		{ pos = Vector3.new(28, -256, 74), col = Color3.fromRGB(118, 132, 255), s = 1.1 },
		{ pos = Vector3.new(-28, -292, 26), col = Color3.fromRGB(172, 92, 255), s = 1.4 },
		{ pos = Vector3.new(28, -292, 26), col = Color3.fromRGB(68, 224, 255), s = 1.3 },
		{ pos = Vector3.new(-28, -292, 92), col = Color3.fromRGB(255, 92, 206), s = 1.5 },
		{ pos = Vector3.new(28, -292, 92), col = Color3.fromRGB(142, 98, 255), s = 1.4 },
	}
	for _, spec in ipairs(crystalSpecs) do
		buildCrystalCluster(env, spec.pos, spec.col, spec.s)
	end

	buildGiantRibcageFossil(env, Vector3.new(0, -292, 62))

	-- Deep-Sea Bathysphere Debris
	local bathysphere = createPart({
		name = "AbyssalBathysphere",
		size = Vector3.new(8.5, 8.5, 8.5),
		cframe = CFrame.new(Vector3.new(10, -289, 88)) * CFrame.Angles(0.3, 0.7, 0.2),
		color = Color3.fromRGB(98, 106, 122),
		material = Enum.Material.CorrodedMetal,
		shape = Enum.PartType.Ball,
		parent = env,
	})
	local beacon = createPart({
		name = "DistressBeacon",
		size = Vector3.new(1.4, 1.4, 1.4),
		cframe = CFrame.new(Vector3.new(10, -284.4, 88)),
		color = Color3.fromRGB(255, 112, 86),
		material = Enum.Material.Neon,
		canCollide = false,
		shape = Enum.PartType.Ball,
		parent = env,
	})
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(255, 112, 86)
	beaconLight.Range = 28
	beaconLight.Brightness = 1.6
	beaconLight.Parent = beacon
	bathysphere:SetAttribute("Wreck", true)
end

local function createExcavationNodeModel(
	parent: Instance,
	nodeId: string,
	zoneId: GameConfig.ZoneId,
	nodeType: string,
	pos: Vector3,
	digDuration: number,
	respawnTime: number
): ExcavationNodeInfo
	local model = Instance.new("Model")
	model.Name = nodeId
	model.Parent = parent

	local visualParts: { BasePart } = {}
	local displayName = "Excavation Mound"

	local primary: Part
	if nodeType == "SandMound" then
		displayName = "Golden Sand Mound"
		primary = createPart({
			name = "MoundBase",
			size = Vector3.new(5.6, 2.2, 5.6),
			cframe = CFrame.new(pos),
			color = Color3.fromRGB(224, 198, 134),
			material = Enum.Material.Sand,
			canCollide = false,
			shape = Enum.PartType.Ball,
			parent = model,
		})
		table.insert(visualParts, primary)
		local glint = createPart({
			name = "GlintGem",
			size = Vector3.new(1.2, 1.2, 1.2),
			cframe = CFrame.new(pos + Vector3.new(0.6, 0.9, -0.4)),
			color = Color3.fromRGB(255, 224, 102),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
		table.insert(visualParts, glint)
	elseif nodeType == "CoralCluster" then
		displayName = "Encrusted Coral Chest"
		primary = createPart({
			name = "ChestBody",
			size = Vector3.new(4.2, 2.6, 3.0),
			cframe = CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.rad(25), 0),
			color = Color3.fromRGB(132, 92, 62),
			material = Enum.Material.WoodPlanks,
			canCollide = false,
			parent = model,
		})
		table.insert(visualParts, primary)
		local band = createPart({
			name = "GoldTrim",
			size = Vector3.new(4.4, 0.5, 3.2),
			cframe = primary.CFrame * CFrame.new(0, 0.5, 0),
			color = Color3.fromRGB(255, 206, 86),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
		table.insert(visualParts, band)
	elseif nodeType == "RuinFragment" then
		displayName = "Sunken Ruin Fragment"
		primary = createPart({
			name = "RuinBlock",
			size = Vector3.new(4.4, 3.4, 4.4),
			cframe = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0.1, 0.4, -0.08),
			color = Color3.fromRGB(142, 162, 174),
			material = Enum.Material.Marble,
			canCollide = false,
			parent = model,
		})
		table.insert(visualParts, primary)
		local rune = createPart({
			name = "RuneCore",
			size = Vector3.new(1.6, 1.6, 4.6),
			cframe = primary.CFrame,
			color = Color3.fromRGB(78, 228, 255),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
		table.insert(visualParts, rune)
	else
		displayName = "Abyssal Fossil & Crystal Deposit"
		primary = createPart({
			name = "FossilStone",
			size = Vector3.new(4.8, 3.2, 4.8),
			cframe = CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0.6, 0),
			color = Color3.fromRGB(72, 68, 86),
			material = Enum.Material.Basalt,
			canCollide = false,
			parent = model,
		})
		table.insert(visualParts, primary)
		local crystal = createPart({
			name = "AbyssalCrystal",
			size = Vector3.new(1.6, 3.8, 1.6),
			cframe = primary.CFrame * CFrame.new(0.5, 1.2, 0) * CFrame.Angles(0.25, 0, -0.2),
			color = Color3.fromRGB(212, 108, 255),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
		table.insert(visualParts, crystal)
	end

	local light = Instance.new("PointLight")
	light.Color = GameConfig.ZONES[zoneId].accentColor
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = primary

	model.PrimaryPart = primary
	model:SetAttribute("NodeId", nodeId)
	model:SetAttribute("ZoneId", zoneId)
	model:SetAttribute("NodeType", nodeType)
	model:SetAttribute("NodeDisplayName", displayName)
	model:SetAttribute("DigDuration", digDuration)
	model:SetAttribute("IsAvailable", true)

	return {
		nodeId = nodeId,
		zoneId = zoneId,
		nodeType = nodeType,
		displayName = displayName,
		digDuration = digDuration,
		respawnTime = respawnTime,
		model = model,
		primaryPart = primary,
		visualParts = visualParts,
	}
end

local function buildExcavationNodes(parent: Instance): ()
	local nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "ExcavationNodes"
	nodesFolder.Parent = parent

	nodeInfoById = {}

	local nodeSpecs: { { id: string, zone: GameConfig.ZoneId, kind: string, pos: Vector3, dur: number, respawn: number } } = {
		-- Shallow Reef (0 to -85) - 14 nodes
		{ id = "Node_SR_01", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(-14, -12, -104), dur = 2.0, respawn = 12 },
		{ id = "Node_SR_02", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(18, -12, -102), dur = 2.0, respawn = 12 },
		{ id = "Node_SR_03", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(-32, -26, -84), dur = 2.1, respawn = 12 },
		{ id = "Node_SR_04", zone = "ShallowReef", kind = "CoralCluster", pos = Vector3.new(28, -26, -84), dur = 2.2, respawn = 14 },
		{ id = "Node_SR_05", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(0, -26, -86), dur = 2.0, respawn = 12 },
		{ id = "Node_SR_06", zone = "ShallowReef", kind = "CoralCluster", pos = Vector3.new(-58, -64, -52), dur = 2.3, respawn = 14 },
		{ id = "Node_SR_07", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(58, -64, -48), dur = 2.3, respawn = 14 },
		{ id = "Node_SR_08", zone = "ShallowReef", kind = "CoralCluster", pos = Vector3.new(-102, -64, 4), dur = 2.4, respawn = 14 },
		{ id = "Node_SR_09", zone = "ShallowReef", kind = "CoralCluster", pos = Vector3.new(-118, -36, -24), dur = 2.4, respawn = 14 },
		{ id = "Node_SR_10", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(118, -28, 20), dur = 2.3, respawn = 14 },
		{ id = "Node_SR_11", zone = "ShallowReef", kind = "CoralCluster", pos = Vector3.new(130, -64, 72), dur = 2.4, respawn = 14 },
		{ id = "Node_SR_12", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(-106, -40, 138), dur = 2.3, respawn = 14 },
		{ id = "Node_SR_13", zone = "ShallowReef", kind = "CoralCluster", pos = Vector3.new(100, -64, 152), dur = 2.4, respawn = 14 },
		{ id = "Node_SR_14", zone = "ShallowReef", kind = "SandMound", pos = Vector3.new(4, -64, 158), dur = 2.3, respawn = 14 },

		-- Sunken Ruins (-85 to -185) - 12 nodes
		{ id = "Node_RU_01", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(-78, -112, 26), dur = 2.6, respawn = 16 },
		{ id = "Node_RU_02", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(78, -112, 26), dur = 2.6, respawn = 16 },
		{ id = "Node_RU_03", zone = "SunkenRuins", kind = "CoralCluster", pos = Vector3.new(-78, -112, 86), dur = 2.7, respawn = 16 },
		{ id = "Node_RU_04", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(78, -112, 86), dur = 2.7, respawn = 16 },
		{ id = "Node_RU_05", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(0, -112, -12), dur = 2.6, respawn = 16 },
		{ id = "Node_RU_06", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(0, -112, 132), dur = 2.6, respawn = 16 },
		{ id = "Node_RU_07", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(-50, -152, 34), dur = 2.9, respawn = 18 },
		{ id = "Node_RU_08", zone = "SunkenRuins", kind = "FossilRock", pos = Vector3.new(50, -152, 34), dur = 2.9, respawn = 18 },
		{ id = "Node_RU_09", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(-50, -152, 78), dur = 2.9, respawn = 18 },
		{ id = "Node_RU_10", zone = "SunkenRuins", kind = "CoralCluster", pos = Vector3.new(50, -152, 78), dur = 2.9, respawn = 18 },
		{ id = "Node_RU_11", zone = "SunkenRuins", kind = "RuinFragment", pos = Vector3.new(-18, -152, 10), dur = 2.8, respawn = 18 },
		{ id = "Node_RU_12", zone = "SunkenRuins", kind = "FossilRock", pos = Vector3.new(18, -152, 110), dur = 2.8, respawn = 18 },

		-- Abyssal Trench (-185 to -300) - 10 nodes
		{ id = "Node_AB_01", zone = "AbyssalTrench", kind = "FossilRock", pos = Vector3.new(-28, -220, 48), dur = 3.2, respawn = 20 },
		{ id = "Node_AB_02", zone = "AbyssalTrench", kind = "FossilRock", pos = Vector3.new(-28, -220, 68), dur = 3.2, respawn = 20 },
		{ id = "Node_AB_03", zone = "AbyssalTrench", kind = "FossilRock", pos = Vector3.new(28, -256, 48), dur = 3.4, respawn = 22 },
		{ id = "Node_AB_04", zone = "AbyssalTrench", kind = "RuinFragment", pos = Vector3.new(28, -256, 68), dur = 3.4, respawn = 22 },
		{ id = "Node_AB_05", zone = "AbyssalTrench", kind = "FossilRock", pos = Vector3.new(-12, -292, 42), dur = 3.5, respawn = 22 },
		{ id = "Node_AB_06", zone = "AbyssalTrench", kind = "FossilRock", pos = Vector3.new(12, -292, 42), dur = 3.5, respawn = 22 },
		{ id = "Node_AB_07", zone = "AbyssalTrench", kind = "RuinFragment", pos = Vector3.new(0, -292, 58), dur = 3.6, respawn = 24 },
		{ id = "Node_AB_08", zone = "AbyssalTrench", kind = "FossilRock", pos = Vector3.new(-14, -292, 86), dur = 3.5, respawn = 22 },
		{ id = "Node_AB_09", zone = "AbyssalTrench", kind = "RuinFragment", pos = Vector3.new(18, -292, 26), dur = 3.6, respawn = 24 },
		{ id = "Node_AB_10", zone = "AbyssalTrench", kind = "FossilRock", pos = Vector3.new(-18, -292, 26), dur = 3.5, respawn = 22 },
	}

	for _, spec in ipairs(nodeSpecs) do
		local info = createExcavationNodeModel(
			nodesFolder,
			spec.id,
			spec.zone,
			spec.kind,
			spec.pos,
			spec.dur,
			spec.respawn
		)
		nodeInfoById[spec.id] = info
	end
end

function WorldBuilder.Build(): ()
	local existingBaseplate = Workspace:FindFirstChild("Baseplate")
	if existingBaseplate then
		existingBaseplate:Destroy()
	end

	local oldWorld = Workspace:FindFirstChild("OceanWorld")
	if oldWorld then
		oldWorld:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "OceanWorld"
	root.Parent = Workspace
	worldRoot = root

	buildOceanTerrain()
	buildBoundaryWalls(root)
	buildHarborHub(root)
	buildUnderwaterEnvironment(root)
	buildExcavationNodes(root)
end

function WorldBuilder.GetWorldRoot(): Folder?
	return worldRoot
end

function WorldBuilder.GetNodeInfo(nodeId: string): ExcavationNodeInfo?
	return nodeInfoById[nodeId]
end

function WorldBuilder.GetAllNodes(): { [string]: ExcavationNodeInfo }
	return nodeInfoById
end

function WorldBuilder.SetNodeAvailable(nodeId: string, available: boolean): ()
	local info = nodeInfoById[nodeId]
	if not info then
		return
	end
	info.model:SetAttribute("IsAvailable", available)
	for _, part in ipairs(info.visualParts) do
		part.Transparency = if available then 0 else 0.88
	end
	local light = info.primaryPart:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = available
	end
end

return WorldBuilder
