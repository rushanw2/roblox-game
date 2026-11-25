--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldBuilder = require(script.Parent.WorldBuilder)

export type CarStyleId = "SakuraKei" | "MatchaDeliveryVan" | "SkylineSedan" | "MochiMiniTruck"

export type PathSample = {
	position: Vector3,
	distance: number,
}

export type TrafficRoute = {
	samples: { PathSample },
	totalLength: number,
}

export type ActiveTrafficCar = {
	id: string,
	model: Model,
	route: TrafficRoute,
	speed: number,
	distanceAlong: number,
}

type CarStyleConfig = {
	id: CarStyleId,
	bodyColor: Color3,
	roofColor: Color3,
	accentColor: Color3,
	bodySize: Vector3,
	cabinSize: Vector3,
	cabinOffsetZ: number,
}

local TrafficManager = {}

local TRAFFIC_FOLDER_NAME = "AmbientTraffic"
local ROAD_SURFACE_Y = 0.12
local LANE_OFFSET = 5.5

local CAR_STYLES: { [CarStyleId]: CarStyleConfig } = {
	SakuraKei = {
		id = "SakuraKei",
		bodyColor = Color3.fromRGB(255, 186, 212),
		roofColor = Color3.fromRGB(255, 248, 246),
		accentColor = Color3.fromRGB(255, 148, 184),
		bodySize = Vector3.new(5.2, 1.8, 8.2),
		cabinSize = Vector3.new(4.6, 1.7, 4.8),
		cabinOffsetZ = 0.3,
	},
	MatchaDeliveryVan = {
		id = "MatchaDeliveryVan",
		bodyColor = Color3.fromRGB(178, 232, 208),
		roofColor = Color3.fromRGB(250, 248, 242),
		accentColor = Color3.fromRGB(132, 206, 174),
		bodySize = Vector3.new(5.6, 2.2, 10.2),
		cabinSize = Vector3.new(5.2, 2.1, 7.2),
		cabinOffsetZ = 0.8,
	},
	SkylineSedan = {
		id = "SkylineSedan",
		bodyColor = Color3.fromRGB(168, 216, 250),
		roofColor = Color3.fromRGB(246, 250, 255),
		accentColor = Color3.fromRGB(130, 188, 236),
		bodySize = Vector3.new(5.4, 1.7, 9.6),
		cabinSize = Vector3.new(4.8, 1.5, 4.8),
		cabinOffsetZ = 0.2,
	},
	MochiMiniTruck = {
		id = "MochiMiniTruck",
		bodyColor = Color3.fromRGB(252, 236, 216),
		roofColor = Color3.fromRGB(255, 198, 152),
		accentColor = Color3.fromRGB(255, 176, 128),
		bodySize = Vector3.new(5.2, 1.8, 8.8),
		cabinSize = Vector3.new(4.8, 2.0, 4.6),
		cabinOffsetZ = 1.6,
	},
}

local activeCars: { ActiveTrafficCar } = {}
local trafficFolder: Folder? = nil
local heartbeatConnection: RBXScriptConnection? = nil

local function makeCarPart(
	parent: Instance,
	name: string,
	size: Vector3,
	localCF: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = localCF
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function buildCarModel(style: CarStyleConfig, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = `TrafficCar_{style.id}`
	model.Parent = parent

	local wheelRadius = 0.85
	local chassisBaseY = wheelRadius

	local rootPart = makeCarPart(
		model,
		"Root",
		Vector3.new(1, 0.2, 1),
		CFrame.new(0, 0.1, 0),
		style.bodyColor,
		nil,
		1
	)
	model.PrimaryPart = rootPart

	makeCarPart(
		model,
		"Body",
		style.bodySize,
		CFrame.new(0, chassisBaseY + style.bodySize.Y * 0.5, 0),
		style.bodyColor
	)

	local cabinY = chassisBaseY + style.bodySize.Y + style.cabinSize.Y * 0.5
	makeCarPart(
		model,
		"Cabin",
		style.cabinSize,
		CFrame.new(0, cabinY, style.cabinOffsetZ),
		style.roofColor
	)

	makeCarPart(
		model,
		"Windshield",
		Vector3.new(style.cabinSize.X - 0.5, style.cabinSize.Y * 0.65, style.cabinSize.Z + 0.1),
		CFrame.new(0, cabinY - 0.05, style.cabinOffsetZ),
		Color3.fromRGB(185, 232, 250),
		Enum.Material.Glass,
		0.3
	)

	makeCarPart(
		model,
		"SideStripe",
		Vector3.new(style.bodySize.X + 0.08, 0.35, style.bodySize.Z * 0.85),
		CFrame.new(0, chassisBaseY + style.bodySize.Y * 0.45, 0),
		style.accentColor
	)

	local halfX = style.bodySize.X * 0.32
	local halfZ = style.bodySize.Z * 0.5
	local lightY = chassisBaseY + style.bodySize.Y * 0.5
	for _, xSide in { -halfX, halfX } do
		makeCarPart(
			model,
			"Headlight",
			Vector3.new(0.85, 0.5, 0.15),
			CFrame.new(xSide, lightY, -halfZ - 0.04),
			Color3.fromRGB(255, 246, 206)
		)
		makeCarPart(
			model,
			"Taillight",
			Vector3.new(0.85, 0.45, 0.15),
			CFrame.new(xSide, lightY, halfZ + 0.04),
			Color3.fromRGB(246, 118, 134)
		)
	end

	local wheelX = style.bodySize.X * 0.5 - 0.2
	local wheelZ = style.bodySize.Z * 0.32
	for _, xSide in { -wheelX, wheelX } do
		for _, zSide in { -wheelZ, wheelZ } do
			makeCarPart(
				model,
				"Wheel",
				Vector3.new(0.65, wheelRadius * 2, wheelRadius * 2),
				CFrame.new(xSide, wheelRadius, zSide),
				Color3.fromRGB(54, 58, 68),
				nil,
				nil,
				Enum.PartType.Cylinder
			)
		end
	end

	return model
end

local function buildRouteFromPoints(rawPoints: { Vector3 }): TrafficRoute
	local samples: { PathSample } = {}
	local totalLength = 0

	for i = 1, #rawPoints do
		local pt = Vector3.new(rawPoints[i].X, ROAD_SURFACE_Y, rawPoints[i].Z)
		if i > 1 then
			totalLength += (pt - samples[i - 1].position).Magnitude
		end
		table.insert(samples, {
			position = pt,
			distance = totalLength,
		})
	end

	if #samples >= 2 then
		totalLength += (samples[1].position - samples[#samples].position).Magnitude
		table.insert(samples, {
			position = samples[1].position,
			distance = totalLength,
		})
	end

	return {
		samples = samples,
		totalLength = totalLength,
	}
end

local function buildCircleRoute(radius: number, steps: number, clockwise: boolean): TrafficRoute
	local pts: { Vector3 } = {}
	for i = 0, steps - 1 do
		local frac = i / steps
		local angle = if clockwise then frac * math.pi * 2 else -frac * math.pi * 2
		table.insert(pts, Vector3.new(math.cos(angle) * radius, ROAD_SURFACE_Y, math.sin(angle) * radius))
	end
	return buildRouteFromPoints(pts)
end

local function buildOffsetCurvePoints(centerline: { Vector3 }, maxIndex: number, offsetRight: number, reverseOrder: boolean): { Vector3 }
	local pts: { Vector3 } = {}
	local limit = math.min(#centerline, maxIndex)

	local startIdx = if reverseOrder then limit else 1
	local endIdx = if reverseOrder then 1 else limit
	local step = if reverseOrder then -1 else 1

	for i = startIdx, endIdx, step do
		local curr = centerline[i]
		local tangent: Vector3
		if i < limit and not reverseOrder then
			tangent = (centerline[i + 1] - curr).Unit
		elseif i > 1 and reverseOrder then
			tangent = (centerline[i - 1] - curr).Unit
		elseif i > 1 then
			tangent = (curr - centerline[i - 1]).Unit
		else
			tangent = (curr - centerline[i + 1]).Unit
		end

		local rightVec = Vector3.new(-tangent.Z, 0, tangent.X)
		table.insert(pts, curr + rightVec * offsetRight)
	end

	return pts
end

local function buildThroughAvenueRoute(curveA: { Vector3 }, curveB: { Vector3 }, roundaboutRadius: number, startAngleRad: number): TrafficRoute
	local pts: { Vector3 } = {}
	local maxCurveIdx = 22 -- Turns cleanly around ~290 studs out, hidden behind skyline bend

	-- Outbound along curveA (on right-hand lane), U-turn behind skyline bend, inbound back to plaza
	local outboundA = buildOffsetCurvePoints(curveA, maxCurveIdx, LANE_OFFSET, false)
	local inboundA = buildOffsetCurvePoints(curveA, maxCurveIdx, LANE_OFFSET, true)
	for _, p in outboundA do
		table.insert(pts, p)
	end
	for _, p in inboundA do
		table.insert(pts, p)
	end

	-- Smooth counter-clockwise half-circle along roundabout to opposite avenue curveB
	local arcSteps = 10
	for s = 1, arcSteps - 1 do
		local angle = startAngleRad - (s / arcSteps) * math.pi
		table.insert(pts, Vector3.new(math.cos(angle) * (roundaboutRadius + LANE_OFFSET), ROAD_SURFACE_Y, math.sin(angle) * (roundaboutRadius + LANE_OFFSET)))
	end

	local outboundB = buildOffsetCurvePoints(curveB, maxCurveIdx, LANE_OFFSET, false)
	local inboundB = buildOffsetCurvePoints(curveB, maxCurveIdx, LANE_OFFSET, true)
	for _, p in outboundB do
		table.insert(pts, p)
	end
	for _, p in inboundB do
		table.insert(pts, p)
	end

	for s = 1, arcSteps - 1 do
		local angle = startAngleRad - math.pi - (s / arcSteps) * math.pi
		table.insert(pts, Vector3.new(math.cos(angle) * (roundaboutRadius + LANE_OFFSET), ROAD_SURFACE_Y, math.sin(angle) * (roundaboutRadius + LANE_OFFSET)))
	end

	return buildRouteFromPoints(pts)
end

local function sampleRoutePosition(route: TrafficRoute, dist: number): Vector3
	local wrapped = dist % route.totalLength
	local samples = route.samples

	for i = 1, #samples - 1 do
		local a = samples[i]
		local b = samples[i + 1]
		if wrapped >= a.distance and wrapped <= b.distance then
			local segLen = b.distance - a.distance
			if segLen <= 0.0001 then
				return a.position
			end
			local alpha = (wrapped - a.distance) / segLen
			return a.position:Lerp(b.position, alpha)
		end
	end

	return samples[1].position
end

local function updateCarTransform(car: ActiveTrafficCar)
	local pos = sampleRoutePosition(car.route, car.distanceAlong)
	local lookAheadPos = sampleRoutePosition(car.route, car.distanceAlong + 3.0)
	local flatLook = Vector3.new(lookAheadPos.X, pos.Y, lookAheadPos.Z)
	if (flatLook - pos).Magnitude > 0.05 then
		car.model:PivotTo(CFrame.lookAt(pos, flatLook))
	end
end

function TrafficManager.Stop()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	if trafficFolder then
		trafficFolder:Destroy()
		trafficFolder = nil
	end

	table.clear(activeCars)
end

function TrafficManager.Init()
	TrafficManager.Stop()

	local centerlines = WorldBuilder.GetTrafficCenterlines()
	if not centerlines then
		warn("[TrafficManager] WorldBuilder centerlines not initialized; skipping ambient traffic.")
		return
	end

	local existing = Workspace:FindFirstChild(TRAFFIC_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = TRAFFIC_FOLDER_NAME
	folder.Parent = Workspace
	trafficFolder = folder

	local plazaRoute = buildCircleRoute(centerlines.plazaRadius - LANE_OFFSET, 48, false)
	local eastWestRoute = buildThroughAvenueRoute(centerlines.eastCurve, centerlines.westCurve, centerlines.plazaRadius, 0)
	local northSouthRoute = buildThroughAvenueRoute(centerlines.northCurve, centerlines.southCurve, centerlines.plazaRadius, -math.pi * 0.5)

	local carConfigs: {
		{ id: string, style: CarStyleId, route: TrafficRoute, speed: number, startFraction: number }
	} = {
		{ id = "Car_SakuraKei", style = "SakuraKei", route = plazaRoute, speed = 13.0, startFraction = 0.0 },
		{ id = "Car_MatchaVan", style = "MatchaDeliveryVan", route = plazaRoute, speed = 13.0, startFraction = 0.5 },
		{ id = "Car_SkylineSedan", style = "SkylineSedan", route = eastWestRoute, speed = 16.0, startFraction = 0.08 },
		{ id = "Car_MochiTruck", style = "MochiMiniTruck", route = northSouthRoute, speed = 15.5, startFraction = 0.34 },
	}

	for _, cfg in carConfigs do
		local style = CAR_STYLES[cfg.style]
		local model = buildCarModel(style, folder)
		local car: ActiveTrafficCar = {
			id = cfg.id,
			model = model,
			route = cfg.route,
			speed = cfg.speed,
			distanceAlong = cfg.route.totalLength * cfg.startFraction,
		}
		updateCarTransform(car)
		table.insert(activeCars, car)
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		local clampedDt = math.min(dt, 0.1)
		for _, car in activeCars do
			car.distanceAlong = (car.distanceAlong + car.speed * clampedDt) % car.route.totalLength
			updateCarTransform(car)
		end
	end)
end

return TrafficManager
