--!strict
-- Server-authoritative Oxygen drain, Surface refill, Blackout rescue, Swim Speed & Diving Flashlight

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ServerFolder = script.Parent
local DataManager = require(ServerFolder:WaitForChild("DataManager"))

export type DivingSnapshot = {
	oxygen: number,
	maxOxygen: number,
	depth: number,
	zoneId: GameConfig.ZoneId?,
	isUnderwater: boolean,
	flashlightOn: boolean,
	isBlackedOut: boolean,
}

type PlayerDivingState = {
	oxygen: number,
	maxOxygen: number,
	depth: number,
	zoneId: GameConfig.ZoneId?,
	isUnderwater: boolean,
	flashlightOn: boolean,
	isBlackedOut: boolean,
	lastFlashlightToggle: number,
	lastSyncAt: number,
	spotLight: SpotLight?,
	pointLight: PointLight?,
	lensPart: BasePart?,
}

local DivingManager = {}

local stateByUserId: { [number]: PlayerDivingState } = {}
local onBlackoutCallback: ((player: Player, lostCount: number) -> ())? = nil
local onSyncCallback: ((player: Player, eventPayload: { [string]: any }?) -> ())? = nil
local accumulator = 0

local function computeMaxOxygen(player: Player): number
	local profile = DataManager.GetProfile(player)
	if not profile then
		return 100
	end
	local tier = GameConfig.GetOxygenTier(profile.GearLevels.Oxygen)
	local passives = DataManager.GetPetPassives(profile)
	return math.floor(tier.maxOxygen + passives.oxygenCapacityBonus)
end

local function computeMovementSpeed(player: Player, isUnderwater: boolean): number
	local profile = DataManager.GetProfile(player)
	if not profile then
		return GameConfig.LAND_WALK_SPEED
	end
	local tier = GameConfig.GetSwimSpeedTier(profile.GearLevels.SwimSpeed)
	local passives = DataManager.GetPetPassives(profile)

	if not isUnderwater then
		return math.clamp(GameConfig.LAND_WALK_SPEED + passives.swimSpeedBonus * 0.35, 22, 34)
	end

	local swimSpeed = tier.swimSpeed + passives.swimSpeedBonus
	if DataManager.IsBuffActive(profile, "SpeedPotion") then
		swimSpeed *= 1.35
	end
	return swimSpeed
end

local function applyFlashlightVisuals(player: Player, state: PlayerDivingState): ()
	local profile = DataManager.GetProfile(player)
	local level = if profile then profile.GearLevels.LightStrength else 1
	local tier = GameConfig.GetLightStrengthTier(level)

	if state.spotLight and state.spotLight.Parent then
		state.spotLight.Enabled = state.flashlightOn
		state.spotLight.Brightness = tier.brightness
		state.spotLight.Range = tier.range
		state.spotLight.Angle = tier.angle
		state.spotLight.Color = tier.color
	end

	if state.pointLight and state.pointLight.Parent then
		state.pointLight.Enabled = state.flashlightOn
		state.pointLight.Brightness = math.min(1.6, tier.brightness * 0.25)
		state.pointLight.Range = math.min(24, tier.range * 0.25)
		state.pointLight.Color = tier.color
	end

	if state.lensPart and state.lensPart.Parent then
		state.lensPart.Material = if state.flashlightOn then Enum.Material.Neon else Enum.Material.Glass
		state.lensPart.Color = if state.flashlightOn then tier.color else Color3.fromRGB(90, 110, 130)
	end
end

local function attachHeadlamp(player: Player, character: Model): ()
	local headInst = character:WaitForChild("Head", 5)
	if not headInst or not headInst:IsA("BasePart") then
		return
	end
	local head = headInst

	local existing = character:FindFirstChild("DivingHeadlamp")
	if existing then
		existing:Destroy()
	end

	local lampModel = Instance.new("Model")
	lampModel.Name = "DivingHeadlamp"
	lampModel.Parent = character

	local housing = Instance.new("Part")
	housing.Name = "LampHousing"
	housing.Size = Vector3.new(0.65, 0.38, 0.55)
	housing.Color = Color3.fromRGB(48, 56, 72)
	housing.Material = Enum.Material.Metal
	housing.CanCollide = false
	housing.Massless = true
	housing.CFrame = head.CFrame * CFrame.new(0, 0.42, -0.52)
	housing.Parent = lampModel

	local lens = Instance.new("Part")
	lens.Name = "LampLens"
	lens.Size = Vector3.new(0.42, 0.24, 0.12)
	lens.Color = Color3.fromRGB(255, 244, 212)
	lens.Material = Enum.Material.Glass
	lens.CanCollide = false
	lens.Massless = true
	lens.CFrame = head.CFrame * CFrame.new(0, 0.42, -0.78)
	lens.Parent = lampModel

	local weld1 = Instance.new("WeldConstraint")
	weld1.Part0 = head
	weld1.Part1 = housing
	weld1.Parent = housing

	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = housing
	weld2.Part1 = lens
	weld2.Parent = lens

	local spotLight = Instance.new("SpotLight")
	spotLight.Name = "DivingSpotLight"
	spotLight.Face = Enum.NormalId.Front
	spotLight.Shadows = false
	spotLight.Enabled = false
	spotLight.Parent = lens

	local pointLight = Instance.new("PointLight")
	pointLight.Name = "DivingHaloLight"
	pointLight.Shadows = false
	pointLight.Enabled = false
	pointLight.Parent = lens

	local state = stateByUserId[player.UserId]
	if state then
		state.spotLight = spotLight
		state.pointLight = pointLight
		state.lensPart = lens
		applyFlashlightVisuals(player, state)
	end
end

local function triggerBlackoutRescue(player: Player, state: PlayerDivingState): ()
	if state.isBlackedOut then
		return
	end
	state.isBlackedOut = true
	state.oxygen = 0

	local profile = DataManager.GetProfile(player)
	local droppedCount = 0
	if profile then
		droppedCount = #profile.RawRelics
		profile.RawRelics = {}
	end

	if onBlackoutCallback then
		onBlackoutCallback(player, droppedCount)
	end

	task.delay(1.8, function()
		if not player.Parent then
			return
		end
		local currentState = stateByUserId[player.UserId]
		if not currentState then
			return
		end

		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				character:PivotTo(CFrame.new(GameConfig.PIER_RESCUE_POSITION))
			end
			if humanoid then
				humanoid.WalkSpeed = computeMovementSpeed(player, false)
			end
		end

		currentState.maxOxygen = computeMaxOxygen(player)
		currentState.oxygen = currentState.maxOxygen
		currentState.depth = 0
		currentState.zoneId = nil
		currentState.isUnderwater = false
		currentState.isBlackedOut = false

		if onSyncCallback then
			onSyncCallback(player, {
				type = "BlackoutRescued",
				lostCount = droppedCount,
			})
		end
	end)
end

local function stepPlayer(player: Player, dt: number, now: number): ()
	local state = stateByUserId[player.UserId]
	local profile = DataManager.GetProfile(player)
	if not state or not profile then
		return
	end

	local character = player.Character
	local rootInst = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local headInst = if character then character:FindFirstChild("Head") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil

	local prevMax = state.maxOxygen
	state.maxOxygen = computeMaxOxygen(player)
	if state.maxOxygen > prevMax then
		state.oxygen += (state.maxOxygen - prevMax)
	end
	state.oxygen = math.clamp(state.oxygen, 0, state.maxOxygen)

	if not rootInst or not rootInst:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local headY = if headInst and headInst:IsA("BasePart") then headInst.Position.Y else rootInst.Position.Y + 1.5
	local rootY = rootInst.Position.Y
	local isUnderwater = headY < (GameConfig.WATER_SURFACE_Y - 0.15)
	state.isUnderwater = isUnderwater
	state.depth = GameConfig.GetDepthAtY(rootY)
	local zone = if isUnderwater then GameConfig.GetZoneAtY(rootY) else nil
	state.zoneId = if zone then zone.id else nil

	humanoid.WalkSpeed = computeMovementSpeed(player, isUnderwater)

	if state.isBlackedOut then
		return
	end

	local prevOxygen = state.oxygen
	if isUnderwater then
		local zoneMult = if zone then zone.oxygenDrainMultiplier else 1.0
		local buffMult = if DataManager.IsBuffActive(profile, "OxygenCanister") then 0.65 else 1.0
		local drain = GameConfig.BASE_OXYGEN_DRAIN_PER_SEC * zoneMult * buffMult * dt
		state.oxygen = math.max(0, state.oxygen - drain)
		if state.oxygen <= 0 then
			triggerBlackoutRescue(player, state)
			return
		end
	else
		state.oxygen = math.min(state.maxOxygen, state.oxygen + GameConfig.SURFACE_OXYGEN_REFILL_PER_SEC * dt)
	end

	local syncInterval = if isUnderwater then 0.25 else (if state.oxygen < state.maxOxygen then 0.25 else 1.25)
	local oxygenChanged = math.abs(state.oxygen - prevOxygen) > 0.01
	if (now - state.lastSyncAt >= syncInterval) and (oxygenChanged or isUnderwater or (now - state.lastSyncAt >= 1.25)) then
		state.lastSyncAt = now
		if onSyncCallback then
			onSyncCallback(player, nil)
		end
	end
end

function DivingManager.Init(): ()
	Remotes.ToggleFlashlight.OnServerEvent:Connect(function(player: Player, desiredState: any)
		local state = stateByUserId[player.UserId]
		if not state or state.isBlackedOut then
			return
		end
		local now = Workspace:GetServerTimeNow()
		if now - state.lastFlashlightToggle < 0.12 then
			return
		end
		state.lastFlashlightToggle = now

		if typeof(desiredState) == "boolean" then
			state.flashlightOn = desiredState
		else
			state.flashlightOn = not state.flashlightOn
		end

		applyFlashlightVisuals(player, state)
		if onSyncCallback then
			onSyncCallback(player, nil)
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local stepDt = accumulator
		accumulator = 0
		local now = Workspace:GetServerTimeNow()

		for _, player in ipairs(Players:GetPlayers()) do
			stepPlayer(player, stepDt, now)
		end
	end)
end

function DivingManager.SetCallbacks(
	blackoutFn: (player: Player, lostCount: number) -> (),
	syncFn: (player: Player, eventPayload: { [string]: any }?) -> ()
): ()
	onBlackoutCallback = blackoutFn
	onSyncCallback = syncFn
end

function DivingManager.SetupPlayer(player: Player): ()
	local maxO2 = computeMaxOxygen(player)
	stateByUserId[player.UserId] = {
		oxygen = maxO2,
		maxOxygen = maxO2,
		depth = 0,
		zoneId = nil,
		isUnderwater = false,
		flashlightOn = false,
		isBlackedOut = false,
		lastFlashlightToggle = 0,
		lastSyncAt = 0,
		spotLight = nil,
		pointLight = nil,
		lensPart = nil,
	}

	player.CharacterAdded:Connect(function(character: Model)
		local current = stateByUserId[player.UserId]
		if current then
			current.maxOxygen = computeMaxOxygen(player)
			current.oxygen = current.maxOxygen
			current.isBlackedOut = false
			current.isUnderwater = false
			current.depth = 0
			current.zoneId = nil
		end
		task.spawn(function()
			attachHeadlamp(player, character)
		end)
	end)

	if player.Character then
		task.spawn(function()
			attachHeadlamp(player, player.Character :: Model)
		end)
	end
end

function DivingManager.CleanupPlayer(player: Player): ()
	stateByUserId[player.UserId] = nil
end

function DivingManager.RefreshPlayerStats(player: Player): ()
	local state = stateByUserId[player.UserId]
	if not state then
		return
	end
	local prevMax = state.maxOxygen
	state.maxOxygen = computeMaxOxygen(player)
	if state.maxOxygen > prevMax then
		state.oxygen = math.min(state.maxOxygen, state.oxygen + (state.maxOxygen - prevMax))
	else
		state.oxygen = math.min(state.maxOxygen, state.oxygen)
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = computeMovementSpeed(player, state.isUnderwater)
	end

	applyFlashlightVisuals(player, state)
end

function DivingManager.RefillOxygen(player: Player, fraction: number): ()
	local state = stateByUserId[player.UserId]
	if not state then
		return
	end
	state.maxOxygen = computeMaxOxygen(player)
	state.oxygen = math.min(state.maxOxygen, state.oxygen + state.maxOxygen * math.clamp(fraction, 0, 1))
end

function DivingManager.IsBlackedOut(player: Player): boolean
	local state = stateByUserId[player.UserId]
	return if state then state.isBlackedOut else false
end

function DivingManager.GetDivingSnapshot(player: Player): DivingSnapshot
	local state = stateByUserId[player.UserId]
	if not state then
		return {
			oxygen = 100,
			maxOxygen = 100,
			depth = 0,
			zoneId = nil,
			isUnderwater = false,
			flashlightOn = false,
			isBlackedOut = false,
		}
	end

	return {
		oxygen = math.floor(state.oxygen * 10 + 0.5) / 10,
		maxOxygen = state.maxOxygen,
		depth = math.floor(state.depth * 10 + 0.5) / 10,
		zoneId = state.zoneId,
		isUnderwater = state.isUnderwater,
		flashlightOn = state.flashlightOn,
		isBlackedOut = state.isBlackedOut,
	}
end

return DivingManager
