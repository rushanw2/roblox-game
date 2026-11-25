--!strict
-- Manages Passenger NPCs, Security Guards, moving Baggage Carousels, Vision Cone LoS detection,
-- Gadgets (Smoke Bomb & Distraction Alarm), and the "Cooked" Bust mechanic.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ServerFolder = script.Parent
local DataManager = require(ServerFolder:WaitForChild("DataManager"))
local WorldBuilder = require(ServerFolder:WaitForChild("WorldBuilder"))

export type TerminalId = GameConfig.TerminalId
export type AlertState = "Calm" | "Suspicious" | "Alerted" | "Distracted" | "Blinded"

type WorldBagRecord = {
	bagId: string,
	terminalId: TerminalId,
	archetype: GameConfig.ArchetypeDef,
	model: Model?,
	prompt: ProximityPrompt?,
	isStolen: boolean,
	carouselTrack: WorldBuilder.CarouselTrack?,
	carouselDist: number,
	restingSpot: WorldBuilder.RestingSpot?,
	position: Vector3,
	ownerId: string,
	respawnAt: number?,
}

type PassengerRecord = {
	npcId: string,
	terminalId: TerminalId,
	archetype: GameConfig.ArchetypeDef,
	model: Model,
	bagId: string,
	isCarouselOwner: boolean,
	carouselTrack: WorldBuilder.CarouselTrack?,
	restingSpot: WorldBuilder.RestingSpot?,
	homePos: Vector3,
	currentPos: Vector3,
	currentYaw: number,
	targetYaw: number,
	baseYaw: number,
	lookAwayYaw: number,
	watchBagYaw: number,
	state: "IdleAway" | "WatchBag" | "WalkOut" | "WalkBack" | "AlertScan" | "Distracted",
	stateEndsAt: number,
	alertState: AlertState,
	distractedUntil: number,
	distractedPos: Vector3?,
	blindedUntil: number,
	leaveAt: number?,
	visionRange: number,
	visionAngleDeg: number,
}

type GuardRecord = {
	npcId: string,
	terminalId: TerminalId?,
	route: WorldBuilder.GuardRoute,
	waypointIndex: number,
	model: Model,
	currentPos: Vector3,
	currentYaw: number,
	alertState: AlertState,
	distractedUntil: number,
	distractedPos: Vector3?,
	blindedUntil: number,
	visionRange: number,
	visionAngleDeg: number,
}

type ActiveEffect = {
	id: string,
	kind: GameConfig.ConsumableId,
	position: Vector3,
	radius: number,
	expiresAt: number,
	model: Model,
}

type PlayerStealthState = {
	suspicion: number,
	isCrouching: boolean,
	bustedUntil: number,
	lastStealAttempt: number,
	lastGateWarnAt: number,
	gadgetCooldowns: { [GameConfig.ConsumableId]: number },
}

local StealthManager = {}

local worldRefs: WorldBuilder.WorldRefs
local remotes: Remotes.RemoteSet
local rng = Random.new()

local bagsById: { [string]: WorldBagRecord } = {}
local passengersById: { [string]: PassengerRecord } = {}
local guardsById: { [string]: GuardRecord } = {}
local activeEffects: { ActiveEffect } = {}
local playerStates: { [Player]: PlayerStealthState } = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true

-- Helper functions declared before callers

local function lerpAngle(fromAngle: number, toAngle: number, alpha: number): number
	local diff = ((toAngle - fromAngle + math.pi) % (math.pi * 2)) - math.pi
	return fromAngle + diff * math.clamp(alpha, 0, 1)
end

local function yawToward(fromPos: Vector3, toPos: Vector3): number
	local dx = toPos.X - fromPos.X
	local dz = toPos.Z - fromPos.Z
	-- Forward vector for CFrame.Angles(0, yaw, 0) is (-sin(yaw), 0, -cos(yaw))
	return math.atan2(-dx, -dz)
end

local function segmentIntersectsCircle2D(a: Vector3, b: Vector3, center: Vector3, radius: number): boolean
	local ax, az = a.X, a.Z
	local bx, bz = b.X, b.Z
	local cx, cz = center.X, center.Z

	local dx = bx - ax
	local dz = bz - az
	local lenSq = dx * dx + dz * dz
	if lenSq < 0.0001 then
		return ((ax - cx) ^ 2 + (az - cz) ^ 2) <= radius * radius
	end

	local t = math.clamp(((cx - ax) * dx + (cz - az) * dz) / lenSq, 0, 1)
	local closestX = ax + t * dx
	local closestZ = az + t * dz
	local distSq = (closestX - cx) ^ 2 + (closestZ - cz) ^ 2
	return distSq <= radius * radius
end

local function isBlockedBySmoke(fromPos: Vector3, toPos: Vector3, now: number): boolean
	for _, eff in ipairs(activeEffects) do
		if eff.kind == "SmokeBomb" and now < eff.expiresAt then
			if segmentIntersectsCircle2D(fromPos, toPos, eff.position, eff.radius) then
				return true
			end
		end
	end
	return false
end

local function isPointInVisionCone(
	npcPos: Vector3,
	npcYaw: number,
	range: number,
	angleDeg: number,
	targetPos: Vector3,
	now: number
): boolean
	-- Players scouting from upper Mezzanine balconies are out of ground-level eye cone
	if math.abs(targetPos.Y - (npcPos.Y + 3.0)) > 6.5 then
		return false
	end

	local dx = targetPos.X - npcPos.X
	local dz = targetPos.Z - npcPos.Z
	local distSq = dx * dx + dz * dz
	if distSq > range * range then
		return false
	end

	if isBlockedBySmoke(npcPos, targetPos, now) then
		return false
	end

	local dist = math.sqrt(distSq)
	if dist > 1.8 then
		local forwardX = -math.sin(npcYaw)
		local forwardZ = -math.cos(npcYaw)
		local dot = (dx / dist) * forwardX + (dz / dist) * forwardZ
		local cosHalf = math.cos(math.rad(angleDeg * 0.5))
		if dot < cosHalf then
			return false
		end
	end

	local eyeOrigin = Vector3.new(npcPos.X, 4.4, npcPos.Z)
	local targetMid = Vector3.new(targetPos.X, 2.8, targetPos.Z)
	local rayResult = Workspace:Raycast(eyeOrigin, targetMid - eyeOrigin, rayParams)
	if rayResult ~= nil then
		return false
	end

	return true
end

local function setNpcAlertVisual(model: Model, alertState: AlertState)
	model:SetAttribute("AlertState", alertState)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = head:FindFirstChild("AlertBillboard") :: BillboardGui?
	if not bb then
		return
	end
	local label = bb:FindFirstChild("StatusText") :: TextLabel?
	if not label then
		return
	end

	if alertState == "Calm" then
		bb.Enabled = false
	elseif alertState == "Suspicious" then
		bb.Enabled = true
		label.Text = "?"
		label.TextColor3 = Color3.fromRGB(255, 214, 52)
	elseif alertState == "Alerted" then
		bb.Enabled = true
		label.Text = "!"
		label.TextColor3 = Color3.fromRGB(255, 68, 76)
	elseif alertState == "Distracted" then
		bb.Enabled = true
		label.Text = "♪"
		label.TextColor3 = Color3.fromRGB(255, 174, 58)
	elseif alertState == "Blinded" then
		bb.Enabled = true
		label.Text = "☁"
		label.TextColor3 = Color3.fromRGB(178, 212, 236)
	end
end

local function pickArchetypeForTerminal(terminalId: TerminalId): GameConfig.ArchetypeDef
	local termDef = GameConfig.TERMINALS[terminalId]
	local pool: { GameConfig.ArchetypeDef } = {}
	for _, tier in ipairs(termDef.allowedTiers) do
		for _, arch in ipairs(GameConfig.GetArchetypesForTier(tier)) do
			table.insert(pool, arch)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function getOrCreatePlayerState(player: Player): PlayerStealthState
	local existing = playerStates[player]
	if existing then
		return existing
	end
	local state: PlayerStealthState = {
		suspicion = 0,
		isCrouching = false,
		bustedUntil = 0,
		lastStealAttempt = 0,
		lastGateWarnAt = 0,
		gadgetCooldowns = {
			SmokeBomb = 0,
			DistractionAlarm = 0,
		},
	}
	playerStates[player] = state
	return state
end

local function sendToast(player: Player, message: string, tone: string?, extra: { [string]: any }?)
	local snapshot = DataManager.BuildClientSnapshot(player)
	remotes.SyncPlayerState:FireClient(player, {
		kind = "StateAndAlert",
		snapshot = snapshot,
		toast = message,
		tone = tone or "info",
		extra = extra,
	})
end

local function applyPlayerMovementSpeed(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local state = getOrCreatePlayerState(player)
	local now = os.clock()
	if now < state.bustedUntil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end

	local profile = DataManager.GetProfile(player)
	local sneakerLevel = if profile then profile.UpgradeLevels.Sneakers else 1
	local sneakerDef = GameConfig.GetSneakerUpgrade(sneakerLevel)
	humanoid.JumpPower = 50
	humanoid.WalkSpeed = if state.isCrouching then sneakerDef.crouchSpeed else sneakerDef.walkSpeed
end

local function spawnBustSecurityAnimation(targetPos: Vector3)
	local spawnPos = targetPos + Vector3.new(10, 0, 10)
	local officer = WorldBuilder.BuildSecurityNPC(worldRefs.EffectsFolder, spawnPos, yawToward(spawnPos, targetPos))
	officer:SetAttribute("IsStealthNPC", false)
	setNpcAlertVisual(officer, "Alerted")

	local hrp = officer.PrimaryPart
	if hrp then
		local endCF = CFrame.new(targetPos + Vector3.new(2.5, 3.0, 2.5)) * CFrame.Angles(0, yawToward(targetPos + Vector3.new(2.5, 0, 2.5), targetPos), 0)
		local tween = TweenService:Create(hrp, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = endCF })
		tween:Play()
	end

	task.delay(GameConfig.BUST_STUN_SECONDS + 0.6, function()
		if officer and officer.Parent then
			officer:Destroy()
		end
	end)
end

function StealthManager.BustPlayer(player: Player, reason: string, terminalId: TerminalId?)
	local state = getOrCreatePlayerState(player)
	local now = os.clock()
	if now < state.bustedUntil then
		return
	end

	state.bustedUntil = now + GameConfig.BUST_STUN_SECONDS
	state.suspicion = 0
	state.isCrouching = false
	player:SetAttribute("Suspicion", 0)
	player:SetAttribute("IsCrouching", false)
	player:SetAttribute("StealthStatus", "Busted")

	local confiscated = DataManager.ClearCarriedLuggage(player)
	player:SetAttribute("CarriedArchetype", "")
	player:SetAttribute("CarriedTier", "")

	local zone: TerminalId = terminalId or (if confiscated then confiscated.sourceTerminal else "Domestic")
	local fine = DataManager.ApplyFine(player, GameConfig.GetTerminalBustFine(zone))

	-- If player was carrying a bag whose owner is still waiting around, schedule fresh spawn cleanly
	if confiscated then
		local bagRec = bagsById[confiscated.worldBagId]
		if bagRec and bagRec.isStolen and not bagRec.respawnAt then
			bagRec.respawnAt = now + 4
		end
	end

	applyPlayerMovementSpeed(player)

	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if hrp then
		spawnBustSecurityAnimation(Vector3.new(hrp.Position.X, 0.4, hrp.Position.Z))
	end

	local bagMsg = if confiscated then string.format("Lost %s", confiscated.displayName) else "Caught red-handed"
	local fineMsg = if fine > 0 then string.format(" & fined %s", GameConfig.FormatCash(fine)) else ""
	sendToast(player, string.format("COOKED! %s (%s%s)!", reason, bagMsg, fineMsg), "danger", {
		busted = true,
	})

	task.delay(GameConfig.BUST_STUN_SECONDS, function()
		if not player.Parent then
			return
		end
		local charNow = player.Character
		local rootNow = if charNow then charNow:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if rootNow then
			rootNow.CFrame = CFrame.new(GameConfig.BUST_RESPAWN_POSITION)
		end
		player:SetAttribute("StealthStatus", "Safe")
		applyPlayerMovementSpeed(player)
	end)
end

function StealthManager.AttemptSteal(player: Player, bagId: string)
	local profile = DataManager.GetProfile(player)
	if not profile then
		return
	end
	local state = getOrCreatePlayerState(player)
	local now = os.clock()

	if now < state.bustedUntil then
		return
	end
	if now - state.lastStealAttempt < 0.35 then
		return
	end
	state.lastStealAttempt = now

	if profile.CarriedLuggage ~= nil then
		sendToast(player, "You're already carrying a bag! Escape to the Hideout first.", "warning")
		return
	end

	local bagRec = bagsById[bagId]
	if not bagRec or bagRec.isStolen then
		sendToast(player, "That luggage is already gone!", "warning")
		return
	end

	if not profile.UnlockedTerminals[bagRec.terminalId] then
		sendToast(player, "Unlock this terminal pass first!", "danger")
		return
	end

	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not hrp then
		return
	end

	local distToBag = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(bagRec.position.X, 0, bagRec.position.Z)).Magnitude
	if distToBag > GameConfig.STEAL_RANGE + 4 then
		sendToast(player, "Move closer to snatch that luggage!", "warning")
		return
	end

	-- Authoritative stealth cone verification against owner & security guards
	local coat = GameConfig.GetStealthCoatUpgrade(profile.UpgradeLevels.StealthCoat)
	local crouchMult = if state.isCrouching then GameConfig.CROUCH_DETECTION_RANGE_MULT else 1.0
	local termDef = GameConfig.TERMINALS[bagRec.terminalId]

	local owner = passengersById[bagRec.ownerId]
	if owner and now >= owner.distractedUntil and now >= owner.blindedUntil then
		local effRange = owner.visionRange * coat.rangeMultiplier * crouchMult
		local effAngle = owner.visionAngleDeg * coat.angleMultiplier
		local seesPlayer = isPointInVisionCone(owner.currentPos, owner.currentYaw, effRange, effAngle, hrp.Position, now)
		local seesBag = isPointInVisionCone(owner.currentPos, owner.currentYaw, owner.visionRange, owner.visionAngleDeg, bagRec.position, now)
		if seesPlayer or seesBag or (owner.alertState == "Alerted" and distToBag < 14) then
			setNpcAlertVisual(owner.model, "Alerted")
			StealthManager.BustPlayer(player, owner.archetype.npcTitle .. " spotted you grabbing their bag!", bagRec.terminalId)
			return
		end
	end

	for _, guard in pairs(guardsById) do
		if guard.terminalId == bagRec.terminalId and now >= guard.distractedUntil and now >= guard.blindedUntil then
			local gRange = guard.visionRange * termDef.detectionMultiplier * coat.rangeMultiplier * crouchMult
			local gAngle = guard.visionAngleDeg * coat.angleMultiplier
			if isPointInVisionCone(guard.currentPos, guard.currentYaw, gRange, gAngle, hrp.Position, now) then
				setNpcAlertVisual(guard.model, "Alerted")
				StealthManager.BustPlayer(player, "Airport Security caught you mid-steal!", bagRec.terminalId)
				return
			end
		end
	end

	-- Steal succeeded!
	bagRec.isStolen = true
	bagRec.respawnAt = now + 11
	if bagRec.model then
		bagRec.model:Destroy()
		bagRec.model = nil
		bagRec.prompt = nil
	end

	DataManager.SetCarriedLuggage(player, {
		uid = HttpService:GenerateGUID(false),
		worldBagId = bagRec.bagId,
		archetypeId = bagRec.archetype.id,
		tier = bagRec.archetype.tier,
		displayName = bagRec.archetype.displayName,
		sourceTerminal = bagRec.terminalId,
		stolenAt = now,
	})
	player:SetAttribute("CarriedArchetype", bagRec.archetype.id)
	player:SetAttribute("CarriedTier", bagRec.archetype.tier)

	if owner then
		owner.leaveAt = now + 16
	end

	local toolWarning = ""
	if not GameConfig.CanToolCrackTier(profile.UpgradeLevels.Tool, bagRec.archetype.tier) then
		toolWarning = " (Upgrade Cracking Tool to open!)"
	end
	sendToast(
		player,
		string.format("Snatched [%s] %s! Escape south to the Hideout!%s", bagRec.archetype.tier, bagRec.archetype.displayName, toolWarning),
		"success"
	)
end

local function spawnBagAndOwnerAtSlot(bagRec: WorldBagRecord)
	-- Clean up previous models if respawning
	if bagRec.model then
		bagRec.model:Destroy()
		bagRec.model = nil
	end
	local oldOwner = passengersById[bagRec.ownerId]
	if oldOwner then
		if oldOwner.model then
			oldOwner.model:Destroy()
		end
		passengersById[bagRec.ownerId] = nil
	end

	local arch = pickArchetypeForTerminal(bagRec.terminalId)
	local termDef = GameConfig.TERMINALS[bagRec.terminalId]
	bagRec.archetype = arch
	bagRec.isStolen = false
	bagRec.respawnAt = nil

	local spawnCF: CFrame
	local ownerPos: Vector3
	local ownerBaseYaw: number
	local ownerLookAwayYaw: number
	local ownerWatchYaw: number
	local isCarousel = bagRec.carouselTrack ~= nil

	if bagRec.carouselTrack then
		local track = bagRec.carouselTrack
		local pos, yaw = WorldBuilder.EvaluateCarouselPoint(track, bagRec.carouselDist)
		bagRec.position = pos
		spawnCF = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		local standSpot = track.ownerStandSpots[rng:NextInteger(1, #track.ownerStandSpots)]
		ownerPos = Vector3.new(standSpot.pos.X, 0.4, standSpot.pos.Z)
		ownerBaseYaw = standSpot.baseYaw
		ownerWatchYaw = standSpot.baseYaw
		ownerLookAwayYaw = standSpot.baseYaw + (if rng:NextNumber() > 0.5 then math.pi * 0.85 else -math.pi * 0.85)
	elseif bagRec.restingSpot then
		local spot = bagRec.restingSpot
		bagRec.position = spot.bagPos
		spawnCF = CFrame.new(spot.bagPos) * CFrame.Angles(0, spot.bagYaw, 0)
		ownerPos = spot.ownerHomePos
		ownerBaseYaw = spot.ownerLookAwayYaw
		ownerLookAwayYaw = spot.ownerLookAwayYaw
		ownerWatchYaw = spot.ownerWatchBagYaw
	else
		spawnCF = CFrame.new(0, 0.4, 0)
		ownerPos = Vector3.new(0, 0.4, 6)
		ownerBaseYaw = 0
		ownerLookAwayYaw = math.pi
		ownerWatchYaw = 0
	end

	local bagModel = WorldBuilder.CreateWorldBagModel(arch, spawnCF)
	bagModel.Name = "WorldBag_" .. bagRec.bagId
	bagModel:SetAttribute("BagId", bagRec.bagId)
	bagModel:SetAttribute("ArchetypeId", arch.id)
	bagModel:SetAttribute("Tier", arch.tier)
	bagModel:SetAttribute("TerminalId", bagRec.terminalId)
	bagModel.Parent = worldRefs.BagsFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealLuggagePrompt"
	prompt.ActionText = "Steal " .. arch.displayName
	prompt.ObjectText = string.format("[%s] %s's Bag", arch.tier, arch.npcTitle)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GameConfig.STEAL_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = bagModel.PrimaryPart

	prompt.Triggered:Connect(function(triggerPlayer: Player)
		StealthManager.AttemptSteal(triggerPlayer, bagRec.bagId)
	end)

	bagRec.model = bagModel
	bagRec.prompt = prompt

	-- Create matching Passenger Owner NPC
	local npcId = "NPC_" .. HttpService:GenerateGUID(false)
	bagRec.ownerId = npcId

	local startWatching = rng:NextNumber() < 0.35
	local initYaw = if startWatching then ownerWatchYaw else ownerLookAwayYaw
	local npcModel = WorldBuilder.BuildPassengerNPC(worldRefs.PassengersFolder, arch, ownerPos, initYaw)
	local visionRange = arch.visionRange + termDef.visionRangeBonus
	npcModel:SetAttribute("IsStealthNPC", true)
	npcModel:SetAttribute("NPCKind", "Passenger")
	npcModel:SetAttribute("NpcId", npcId)
	npcModel:SetAttribute("TerminalId", bagRec.terminalId)
	npcModel:SetAttribute("OwnerBagId", bagRec.bagId)
	npcModel:SetAttribute("VisionRange", visionRange)
	npcModel:SetAttribute("VisionAngle", arch.visionAngleDeg)
	setNpcAlertVisual(npcModel, "Calm")

	passengersById[npcId] = {
		npcId = npcId,
		terminalId = bagRec.terminalId,
		archetype = arch,
		model = npcModel,
		bagId = bagRec.bagId,
		isCarouselOwner = isCarousel,
		carouselTrack = bagRec.carouselTrack,
		restingSpot = bagRec.restingSpot,
		homePos = ownerPos,
		currentPos = ownerPos,
		currentYaw = initYaw,
		targetYaw = initYaw,
		baseYaw = ownerBaseYaw,
		lookAwayYaw = ownerLookAwayYaw,
		watchBagYaw = ownerWatchYaw,
		state = if startWatching then "WatchBag" else "IdleAway",
		stateEndsAt = os.clock() + rng:NextNumber(2.5, 4.8),
		alertState = "Calm",
		distractedUntil = 0,
		distractedPos = nil,
		blindedUntil = 0,
		leaveAt = nil,
		visionRange = visionRange,
		visionAngleDeg = arch.visionAngleDeg,
	}
end

local function spawnSecurityGuards()
	for _, route in ipairs(worldRefs.GuardRoutes) do
		local startPos = route.waypoints[1]
		local nextPos = route.waypoints[2] or startPos
		local initYaw = yawToward(startPos, nextPos)
		local model = WorldBuilder.BuildSecurityNPC(worldRefs.GuardsFolder, startPos, initYaw)
		model:SetAttribute("IsStealthNPC", true)
		model:SetAttribute("NPCKind", "Security")
		model:SetAttribute("NpcId", route.id)
		model:SetAttribute("TerminalId", route.terminalId or "Domestic")
		model:SetAttribute("VisionRange", route.visionRange)
		model:SetAttribute("VisionAngle", route.visionAngleDeg)
		setNpcAlertVisual(model, "Calm")

		guardsById[route.id] = {
			npcId = route.id,
			terminalId = route.terminalId,
			route = route,
			waypointIndex = 2,
			model = model,
			currentPos = startPos,
			currentYaw = initYaw,
			alertState = "Calm",
			distractedUntil = 0,
			distractedPos = nil,
			blindedUntil = 0,
			visionRange = route.visionRange,
			visionAngleDeg = route.visionAngleDeg,
		}
	end
end

function StealthManager.SetCrouch(player: Player, wantsCrouch: boolean)
	local state = getOrCreatePlayerState(player)
	if os.clock() < state.bustedUntil then
		return
	end
	state.isCrouching = wantsCrouch
	player:SetAttribute("IsCrouching", wantsCrouch)
	applyPlayerMovementSpeed(player)
end

function StealthManager.UseDistraction(player: Player, itemId: string)
	local profile = DataManager.GetProfile(player)
	if not profile then
		return
	end
	local state = getOrCreatePlayerState(player)
	local now = os.clock()
	if now < state.bustedUntil then
		return
	end

	local cid: GameConfig.ConsumableId? = if itemId == "SmokeBomb" or itemId == "DistractionAlarm" then itemId :: GameConfig.ConsumableId else nil
	if not cid then
		sendToast(player, "Invalid gadget selected.", "warning")
		return
	end

	local def = GameConfig.CONSUMABLES[cid]
	local readyAt = state.gadgetCooldowns[cid] or 0
	if now < readyAt then
		sendToast(player, string.format("%s recharging (%.1fs)...", def.name, readyAt - now), "warning")
		return
	end

	local ok, resultOrErr = DataManager.ConsumeGadget(player, cid)
	if not ok then
		sendToast(player, resultOrErr, "warning")
		return
	end

	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not hrp then
		return
	end

	state.gadgetCooldowns[cid] = now + def.cooldown

	-- Place slightly ahead of player if DistractionAlarm, or right on player if SmokeBomb
	local deployPos: Vector3
	if cid == "SmokeBomb" then
		deployPos = Vector3.new(hrp.Position.X, 1.0, hrp.Position.Z)
	else
		local forward = hrp.CFrame.LookVector
		local offset = Vector3.new(forward.X, 0, forward.Z) * 10
		deployPos = Vector3.new(hrp.Position.X + offset.X, 0.8, hrp.Position.Z + offset.Z)
	end

	local effModel = Instance.new("Model")
	effModel.Name = "Effect_" .. cid
	effModel.Parent = worldRefs.EffectsFolder

	if cid == "SmokeBomb" then
		local cloud = Instance.new("Part")
		cloud.Name = "SmokeCloud"
		cloud.Shape = Enum.PartType.Ball
		cloud.Size = Vector3.new(def.radius * 1.4, 9, def.radius * 1.4)
		cloud.Position = deployPos + Vector3.new(0, 3.2, 0)
		cloud.Color = Color3.fromRGB(190, 206, 224)
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Transparency = 0.42
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Parent = effModel

		local ring = Instance.new("Part")
		ring.Name = "SmokeRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, def.radius * 2, def.radius * 2)
		ring.CFrame = CFrame.new(deployPos.X, 0.45, deployPos.Z) * CFrame.Angles(0, 0, math.pi * 0.5)
		ring.Color = def.color
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.65
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = effModel

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(220, 232, 244))
		emitter.Size = NumberSequence.new(4.5, 8.5)
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(1.2, 2.0)
		emitter.Rate = 32
		emitter.Speed = NumberRange.new(2, 5)
		emitter.Parent = cloud

		-- Instantly clear suspicion and blind NPCs touching the smoke
		state.suspicion = 0
		player:SetAttribute("Suspicion", 0)
	else
		local beacon = Instance.new("Part")
		beacon.Name = "AlarmBeacon"
		beacon.Size = Vector3.new(1.2, 1.0, 1.2)
		beacon.Position = deployPos
		beacon.Color = def.color
		beacon.Material = Enum.Material.Neon
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.Parent = effModel

		local pulseRing = Instance.new("Part")
		pulseRing.Name = "AlarmPulse"
		pulseRing.Shape = Enum.PartType.Cylinder
		pulseRing.Size = Vector3.new(0.15, def.radius * 1.9, def.radius * 1.9)
		pulseRing.CFrame = CFrame.new(deployPos.X, 0.42, deployPos.Z) * CFrame.Angles(0, 0, math.pi * 0.5)
		pulseRing.Color = def.color
		pulseRing.Material = Enum.Material.Neon
		pulseRing.Transparency = 0.78
		pulseRing.Anchored = true
		pulseRing.CanCollide = false
		pulseRing.Parent = effModel

		-- Lure nearby Passengers & Security Guards
		for _, npc in pairs(passengersById) do
			if (Vector3.new(npc.currentPos.X, 0, npc.currentPos.Z) - Vector3.new(deployPos.X, 0, deployPos.Z)).Magnitude <= def.radius then
				npc.distractedUntil = now + def.duration
				npc.distractedPos = deployPos
				npc.alertState = "Distracted"
				setNpcAlertVisual(npc.model, "Distracted")
			end
		end
		for _, guard in pairs(guardsById) do
			if (Vector3.new(guard.currentPos.X, 0, guard.currentPos.Z) - Vector3.new(deployPos.X, 0, deployPos.Z)).Magnitude <= def.radius then
				guard.distractedUntil = now + def.duration
				guard.distractedPos = deployPos
				guard.alertState = "Distracted"
				setNpcAlertVisual(guard.model, "Distracted")
			end
		end
	end

	table.insert(activeEffects, {
		id = HttpService:GenerateGUID(false),
		kind = cid,
		position = deployPos,
		radius = def.radius,
		expiresAt = now + def.duration,
		model = effModel,
	})

	sendToast(player, string.format("Deployed %s!", def.name), "info")
end

function StealthManager.OnPlayerAdded(player: Player)
	local state = getOrCreatePlayerState(player)
	player:SetAttribute("Suspicion", 0)
	player:SetAttribute("IsCrouching", false)
	player:SetAttribute("StealthStatus", "Safe")
	player:SetAttribute("CarriedArchetype", "")
	player:SetAttribute("CarriedTier", "")

	local function bindCharacter(character: Model)
		state.isCrouching = false
		state.suspicion = 0
		player:SetAttribute("IsCrouching", false)
		player:SetAttribute("Suspicion", 0)
		local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if hrp then
			hrp.CFrame = CFrame.new(GameConfig.SPAWN_POSITION)
		end
		task.defer(function()
			applyPlayerMovementSpeed(player)
		end)
	end

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
end

function StealthManager.OnPlayerRemoving(player: Player)
	playerStates[player] = nil
end

function StealthManager.ApplyMovementStats(player: Player)
	applyPlayerMovementSpeed(player)
end

function StealthManager.Init(refs: WorldBuilder.WorldRefs, remoteSet: Remotes.RemoteSet)
	worldRefs = refs
	remotes = remoteSet
	rayParams.FilterDescendantsInstances = { worldRefs.OpaqueCoverFolder }

	-- Create carousel bag slots
	local carouselAllocations: { [string]: number } = {
		["Claim 1"] = 2,
		["Claim 2"] = 2,
		["Intl Claim 3"] = 3,
		["VIP Valet"] = 3,
		["Royal Valet"] = 3,
	}

	for _, track in ipairs(worldRefs.Carousels) do
		local count = carouselAllocations[track.id] or 2
		for i = 1, count do
			local bagId = "Bag_" .. HttpService:GenerateGUID(false)
			local startDist = ((i - 1) / count) * track.perimeter
			local arch = pickArchetypeForTerminal(track.terminalId)
			local rec: WorldBagRecord = {
				bagId = bagId,
				terminalId = track.terminalId,
				archetype = arch,
				model = nil,
				prompt = nil,
				isStolen = false,
				carouselTrack = track,
				carouselDist = startDist,
				restingSpot = nil,
				position = track.center,
				ownerId = "",
				respawnAt = nil,
			}
			bagsById[bagId] = rec
			spawnBagAndOwnerAtSlot(rec)
		end
	end

	-- Create resting-spot bags
	for _, spot in ipairs(worldRefs.RestingSpots) do
		local bagId = "Bag_" .. HttpService:GenerateGUID(false)
		local arch = pickArchetypeForTerminal(spot.terminalId)
		local rec: WorldBagRecord = {
			bagId = bagId,
			terminalId = spot.terminalId,
			archetype = arch,
			model = nil,
			prompt = nil,
			isStolen = false,
			carouselTrack = nil,
			carouselDist = 0,
			restingSpot = spot,
			position = spot.bagPos,
			ownerId = "",
			respawnAt = nil,
		}
		bagsById[bagId] = rec
		spawnBagAndOwnerAtSlot(rec)
	end

	spawnSecurityGuards()
end

local function updateCarouselsAndBags(dt: number, now: number)
	for _, track in ipairs(worldRefs.Carousels) do
		for _, slat in ipairs(track.slats) do
			slat.dist = (slat.dist + track.speed * dt) % track.perimeter
			local pos, yaw = WorldBuilder.EvaluateCarouselPoint(track, slat.dist)
			slat.part.CFrame = CFrame.new(pos.X, 1.15, pos.Z) * CFrame.Angles(0, yaw, 0)
		end
	end

	for _, bagRec in pairs(bagsById) do
		if bagRec.isStolen then
			if bagRec.respawnAt and now >= bagRec.respawnAt then
				spawnBagAndOwnerAtSlot(bagRec)
			end
		elseif bagRec.carouselTrack and bagRec.model then
			local track = bagRec.carouselTrack
			bagRec.carouselDist = (bagRec.carouselDist + track.speed * dt) % track.perimeter
			local pos, yaw = WorldBuilder.EvaluateCarouselPoint(track, bagRec.carouselDist)
			bagRec.position = pos
			bagRec.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
		end
	end
end

local function updatePassengerBehavior(dt: number, now: number)
	for _, npc in pairs(passengersById) do
		-- Check smoke blindness
		local isBlinded = false
		for _, eff in ipairs(activeEffects) do
			if eff.kind == "SmokeBomb" and now < eff.expiresAt then
				if (Vector3.new(npc.currentPos.X, 0, npc.currentPos.Z) - Vector3.new(eff.position.X, 0, eff.position.Z)).Magnitude <= eff.radius + 2 then
					isBlinded = true
					break
				end
			end
		end

		if isBlinded then
			npc.blindedUntil = now + 0.3
			if npc.alertState ~= "Blinded" then
				npc.alertState = "Blinded"
				setNpcAlertVisual(npc.model, "Blinded")
			end
		elseif now < npc.distractedUntil and npc.distractedPos then
			npc.targetYaw = yawToward(npc.currentPos, npc.distractedPos)
			if npc.alertState ~= "Distracted" then
				npc.alertState = "Distracted"
				setNpcAlertVisual(npc.model, "Distracted")
			end
		else
			if npc.alertState == "Distracted" or npc.alertState == "Blinded" then
				npc.alertState = "Calm"
				setNpcAlertVisual(npc.model, "Calm")
			end

			local bagRec = bagsById[npc.bagId]
			local bagMissing = bagRec ~= nil and bagRec.isStolen

			if npc.state == "WalkOut" and npc.restingSpot and npc.restingSpot.patrolWaypoint then
				local target = npc.restingSpot.patrolWaypoint
				local toTarget = Vector3.new(target.X - npc.currentPos.X, 0, target.Z - npc.currentPos.Z)
				if toTarget.Magnitude < 0.6 then
					npc.state = "IdleAway"
					npc.stateEndsAt = now + rng:NextNumber(2.6, 4.4)
					npc.targetYaw = npc.lookAwayYaw
				else
					local step = math.min(toTarget.Magnitude, 5.2 * dt)
					npc.currentPos += toTarget.Unit * step
					npc.targetYaw = yawToward(npc.currentPos, target)
				end
			elseif npc.state == "WalkBack" then
				local toHome = Vector3.new(npc.homePos.X - npc.currentPos.X, 0, npc.homePos.Z - npc.currentPos.Z)
				if toHome.Magnitude < 0.6 then
					npc.currentPos = npc.homePos
					npc.state = "WatchBag"
					npc.stateEndsAt = now + rng:NextNumber(2.4, 3.8)
					npc.targetYaw = npc.watchBagYaw
				else
					local step = math.min(toHome.Magnitude, 5.2 * dt)
					npc.currentPos += toHome.Unit * step
					npc.targetYaw = yawToward(npc.currentPos, npc.homePos)
				end
			else
				if npc.state == "WatchBag" then
					if bagMissing then
						if npc.alertState ~= "Alerted" then
							npc.alertState = "Alerted"
							setNpcAlertVisual(npc.model, "Alerted")
						end
						npc.state = "AlertScan"
						npc.stateEndsAt = now + 7.5
					elseif npc.isCarouselOwner and bagRec then
						npc.targetYaw = yawToward(npc.currentPos, bagRec.position)
					else
						npc.targetYaw = npc.watchBagYaw
					end
				elseif npc.state == "AlertScan" then
					npc.targetYaw = npc.baseYaw + math.sin(now * 2.5) * 1.45
				end

				if now >= npc.stateEndsAt then
					if npc.state == "IdleAway" then
						if npc.restingSpot and npc.restingSpot.patrolWaypoint then
							if (npc.currentPos - npc.homePos).Magnitude > 1.2 then
								npc.state = "WalkBack"
							elseif rng:NextNumber() < 0.48 then
								npc.state = "WalkOut"
							else
								npc.state = "WatchBag"
								npc.stateEndsAt = now + rng:NextNumber(2.4, 3.8)
							end
						else
							npc.state = "WatchBag"
							npc.stateEndsAt = now + rng:NextNumber(2.4, 3.8)
						end
					elseif npc.state == "WatchBag" then
						npc.state = "IdleAway"
						npc.stateEndsAt = now + rng:NextNumber(3.4, 5.6)
						npc.targetYaw = npc.lookAwayYaw + rng:NextNumber(-0.4, 0.4)
					elseif npc.state == "AlertScan" then
						npc.state = "IdleAway"
						npc.stateEndsAt = now + 3.0
						if npc.alertState == "Alerted" then
							npc.alertState = "Calm"
							setNpcAlertVisual(npc.model, "Calm")
						end
					end
				end
			end
		end

		npc.currentYaw = lerpAngle(npc.currentYaw, npc.targetYaw, dt * 5.2)
		npc.model:PivotTo(CFrame.new(npc.currentPos.X, 3.0, npc.currentPos.Z) * CFrame.Angles(0, npc.currentYaw, 0))
	end
end

local function updateSecurityGuards(dt: number, now: number)
	for _, guard in pairs(guardsById) do
		local isBlinded = false
		for _, eff in ipairs(activeEffects) do
			if eff.kind == "SmokeBomb" and now < eff.expiresAt then
				if (Vector3.new(guard.currentPos.X, 0, guard.currentPos.Z) - Vector3.new(eff.position.X, 0, eff.position.Z)).Magnitude <= eff.radius + 2 then
					isBlinded = true
					break
				end
			end
		end

		local targetYaw = guard.currentYaw
		if isBlinded then
			guard.blindedUntil = now + 0.3
			if guard.alertState ~= "Blinded" then
				guard.alertState = "Blinded"
				setNpcAlertVisual(guard.model, "Blinded")
			end
		elseif now < guard.distractedUntil and guard.distractedPos then
			targetYaw = yawToward(guard.currentPos, guard.distractedPos)
			if guard.alertState ~= "Distracted" then
				guard.alertState = "Distracted"
				setNpcAlertVisual(guard.model, "Distracted")
			end
		else
			if guard.alertState == "Distracted" or guard.alertState == "Blinded" then
				guard.alertState = "Calm"
				setNpcAlertVisual(guard.model, "Calm")
			end
			local waypoints = guard.route.waypoints
			local dest = waypoints[guard.waypointIndex]
			local toDest = Vector3.new(dest.X - guard.currentPos.X, 0, dest.Z - guard.currentPos.Z)
			if toDest.Magnitude < 1.0 then
				guard.waypointIndex = (guard.waypointIndex % #waypoints) + 1
				dest = waypoints[guard.waypointIndex]
				toDest = Vector3.new(dest.X - guard.currentPos.X, 0, dest.Z - guard.currentPos.Z)
			end
			if toDest.Magnitude > 0.01 then
				local step = math.min(toDest.Magnitude, guard.route.speed * dt)
				guard.currentPos += toDest.Unit * step
				targetYaw = yawToward(guard.currentPos, dest)
			end
		end

		guard.currentYaw = lerpAngle(guard.currentYaw, targetYaw, dt * 6.5)
		guard.model:PivotTo(CFrame.new(guard.currentPos.X, 3.0, guard.currentPos.Z) * CFrame.Angles(0, guard.currentYaw, 0))
	end
end

local function evaluatePlayersStealth(dt: number, now: number)
	-- Track which NPCs currently see any player so alert colors stay crisp
	local npcThreatSeen: { [string]: AlertState } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataManager.GetProfile(player)
		if not profile then
			continue
		end
		local state = getOrCreatePlayerState(player)
		if now < state.bustedUntil then
			continue
		end

		local character = player.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if not hrp then
			continue
		end

		local pos = hrp.Position

		-- 1. Hideout Safe Zone check: auto-secure carried luggage!
		if GameConfig.IsPointInHideout(pos) then
			if profile.CarriedLuggage then
				local ok, stashed, err = DataManager.BankCarriedLuggage(player)
				if ok and stashed then
					player:SetAttribute("CarriedArchetype", "")
					player:SetAttribute("CarriedTier", "")
					sendToast(player, string.format("Secured %s in Hideout! Place it on a Workbench!", stashed.displayName), "success")
				elseif err then
					sendToast(player, err, "warning")
				end
			end
			if state.suspicion > 0 then
				state.suspicion = 0
				player:SetAttribute("Suspicion", 0)
			end
			if player:GetAttribute("StealthStatus") ~= "Safe" then
				player:SetAttribute("StealthStatus", "Safe")
			end
			continue
		end

		-- 2. Strict server check: prevent entering locked terminals
		local insideTerm = GameConfig.GetTerminalAtPosition(pos)
		if insideTerm and not profile.UnlockedTerminals[insideTerm] then
			local termDef = GameConfig.TERMINALS[insideTerm]
			hrp.CFrame = CFrame.new(termDef.gateReturnPosition)
			if now - state.lastGateWarnAt > 1.5 then
				state.lastGateWarnAt = now
				sendToast(player, string.format("Access Denied! Buy the %s Pass (%s) at the gate.", termDef.name, GameConfig.FormatCash(termDef.unlockCost)), "warning")
			end
			continue
		end

		-- 3. Vision cone detection
		local coat = GameConfig.GetStealthCoatUpgrade(profile.UpgradeLevels.StealthCoat)
		local crouchRangeMult = if state.isCrouching then GameConfig.CROUCH_DETECTION_RANGE_MULT else 1.0
		local crouchSuspMult = if state.isCrouching then GameConfig.CROUCH_SUSPICION_MULT else 1.0
		local carried = profile.CarriedLuggage

		local maxThreatRate = 0
		local spottedByHotSource: string? = nil
		local spottedTerminal: TerminalId? = insideTerm

		for _, npc in pairs(passengersById) do
			if insideTerm and npc.terminalId ~= insideTerm then
				continue
			end
			if now < npc.distractedUntil or now < npc.blindedUntil then
				continue
			end

			local effRange = npc.visionRange * coat.rangeMultiplier * crouchRangeMult
			local effAngle = npc.visionAngleDeg * coat.angleMultiplier
			if isPointInVisionCone(npc.currentPos, npc.currentYaw, effRange, effAngle, pos, now) then
				local bagRec = bagsById[npc.bagId]
				if carried and carried.worldBagId == npc.bagId then
					-- Carrying THIS owner's hot bag directly in their sightline!
					local termDef = GameConfig.TERMINALS[npc.terminalId]
					local rate = 135 * termDef.awarenessSpeedMultiplier * coat.suspicionMultiplier
					if rate > maxThreatRate then
						maxThreatRate = rate
						spottedByHotSource = npc.archetype.npcTitle .. " spotted their stolen bag!"
						spottedTerminal = npc.terminalId
					end
					npcThreatSeen[npc.npcId] = "Alerted"
				elseif not carried and bagRec and not bagRec.isStolen then
					local distToBag = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(bagRec.position.X, 0, bagRec.position.Z)).Magnitude
					if distToBag <= GameConfig.OWNER_WATCH_BAG_RADIUS then
						local termDef = GameConfig.TERMINALS[npc.terminalId]
						local rate = npc.archetype.suspicionRate * termDef.awarenessSpeedMultiplier * coat.suspicionMultiplier * crouchSuspMult
						if rate > maxThreatRate then
							maxThreatRate = rate
						end
						npcThreatSeen[npc.npcId] = "Suspicious"
					end
				end
			end
		end

		if carried then
			for _, guard in pairs(guardsById) do
				if now < guard.distractedUntil or now < guard.blindedUntil then
					continue
				end
				local termDef = GameConfig.TERMINALS[guard.terminalId or "Domestic"]
				local gRange = guard.visionRange * termDef.detectionMultiplier * coat.rangeMultiplier * crouchRangeMult
				local gAngle = guard.visionAngleDeg * coat.angleMultiplier
				if isPointInVisionCone(guard.currentPos, guard.currentYaw, gRange, gAngle, pos, now) then
					local rate = 115 * termDef.awarenessSpeedMultiplier * coat.suspicionMultiplier * crouchSuspMult
					if rate > maxThreatRate then
						maxThreatRate = rate
						spottedByHotSource = "Airport Security spotted you fleeing with stolen luggage!"
						spottedTerminal = guard.terminalId or carried.sourceTerminal
					end
					npcThreatSeen[guard.npcId] = "Alerted"
				end
			end
		end

		if maxThreatRate > 0 then
			state.suspicion = math.min(100, state.suspicion + maxThreatRate * dt)
		else
			state.suspicion = math.max(0, state.suspicion - 34 * dt)
		end

		local rounded = math.floor(state.suspicion + 0.5)
		player:SetAttribute("Suspicion", rounded)

		if state.suspicion >= 100 and carried and spottedByHotSource then
			StealthManager.BustPlayer(player, spottedByHotSource, spottedTerminal)
			continue
		end

		local statusStr = if state.suspicion >= 65
			then "Danger"
			elseif state.suspicion >= 20 then "Caution"
			elseif carried then "Hot"
			else "Hidden"
		if player:GetAttribute("StealthStatus") ~= statusStr then
			player:SetAttribute("StealthStatus", statusStr)
		end
	end

	-- Reflect transient yellow/red alert state on NPC cones
	for npcId, npc in pairs(passengersById) do
		if now >= npc.distractedUntil and now >= npc.blindedUntil then
			local threat = npcThreatSeen[npcId]
			if threat then
				if npc.alertState ~= threat then
					npc.alertState = threat
					setNpcAlertVisual(npc.model, threat)
				end
			elseif npc.alertState == "Suspicious" or (npc.alertState == "Alerted" and npc.state ~= "AlertScan") then
				npc.alertState = "Calm"
				setNpcAlertVisual(npc.model, "Calm")
			end
		end
	end

	for guardId, guard in pairs(guardsById) do
		if now >= guard.distractedUntil and now >= guard.blindedUntil then
			local threat = npcThreatSeen[guardId]
			local targetAlert: AlertState = threat or "Calm"
			if guard.alertState ~= targetAlert then
				guard.alertState = targetAlert
				setNpcAlertVisual(guard.model, targetAlert)
			end
		end
	end
end

local stealthAcc = 0

function StealthManager.Step(dt: number)
	local now = os.clock()

	-- Clean expired gadgets
	for i = #activeEffects, 1, -1 do
		local eff = activeEffects[i]
		if now >= eff.expiresAt then
			if eff.model and eff.model.Parent then
				eff.model:Destroy()
			end
			table.remove(activeEffects, i)
		end
	end

	updateCarouselsAndBags(dt, now)
	updatePassengerBehavior(dt, now)
	updateSecurityGuards(dt, now)

	stealthAcc += dt
	if stealthAcc >= 0.1 then
		evaluatePlayersStealth(stealthAcc, now)
		stealthAcc = 0
	end
end

return StealthManager
