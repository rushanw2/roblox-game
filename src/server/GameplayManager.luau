--!strict
-- Server-authoritative Excavation, Cleaning Station, Appraisal Selling, Upgrades, Shop Buffs & Egg Hatching

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ServerFolder = script.Parent
local DataManager = require(ServerFolder:WaitForChild("DataManager"))
local WorldBuilder = require(ServerFolder:WaitForChild("WorldBuilder"))
local DivingManager = require(ServerFolder:WaitForChild("DivingManager"))

export type ActiveExcavationState = {
	nodeId: string,
	startedAt: number,
	endsAt: number,
	duration: number,
}

local GameplayManager = {}

local activeExcavations: { [number]: ActiveExcavationState } = {}
local nodeRespawnAt: { [string]: number } = {}
local rng = Random.new()

local function getCharacterRoot(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root, humanoid
end

local function buildSyncPayload(player: Player, eventPayload: { [string]: any }?): { [string]: any }?
	local profile = DataManager.GetProfile(player)
	if not profile then
		return nil
	end

	DataManager.PruneExpiredBuffs(profile)

	local slotsPayload: { [string]: DataManager.CleaningSlotEntry } = {}
	for slotIdx, slot in pairs(profile.CleaningSlots) do
		slotsPayload[tostring(slotIdx)] = slot
	end

	return {
		profile = {
			Coins = profile.Coins,
			RelicsFound = profile.RelicsFound,
			RawRelics = profile.RawRelics,
			CleanedRelics = profile.CleanedRelics,
			OwnedPets = profile.OwnedPets,
			EquippedPetIds = profile.EquippedPetIds,
			GearLevels = profile.GearLevels,
			ActiveBuffs = profile.ActiveBuffs,
			CleaningSlots = slotsPayload,
		},
		diving = DivingManager.GetDivingSnapshot(player),
		activeExcavation = activeExcavations[player.UserId],
		serverNow = Workspace:GetServerTimeNow(),
		event = eventPayload,
	}
end

local function syncPlayer(player: Player, eventPayload: { [string]: any }?): ()
	if not player.Parent then
		return
	end
	local payload = buildSyncPayload(player, eventPayload)
	if payload then
		Remotes.SyncState:FireClient(player, payload)
	end
end

local function rollWeightedRarity(weights: { [GameConfig.Rarity]: number }): GameConfig.Rarity
	local total = 0
	for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
		total += math.max(0, weights[rarity] or 0)
	end
	if total <= 0 then
		return "Common"
	end

	local roll = rng:NextNumber(0, total)
	local cumulative = 0
	for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
		local w = math.max(0, weights[rarity] or 0)
		cumulative += w
		if roll <= cumulative and w > 0 then
			return rarity
		end
	end
	return "Common"
end

local function zoneContains(zones: { GameConfig.ZoneId }, target: GameConfig.ZoneId): boolean
	for _, z in ipairs(zones) do
		if z == target then
			return true
		end
	end
	return false
end

local function rollRelicForZone(zoneId: GameConfig.ZoneId, hasLuckCharm: boolean): GameConfig.RelicConfig
	local zone = GameConfig.ZONES[zoneId]
	local adjustedWeights: { [GameConfig.Rarity]: number } = {}
	for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
		local baseWeight = zone.excavationRarityWeights[rarity] or 0
		if hasLuckCharm then
			if rarity == "Common" then
				baseWeight *= 0.72
			elseif rarity == "Rare" then
				baseWeight *= 1.35
			elseif rarity == "Epic" then
				baseWeight *= 1.55
			elseif rarity == "Legendary" then
				baseWeight *= 1.85
			elseif rarity == "Godly" then
				baseWeight *= 2.2
			end
		end
		adjustedWeights[rarity] = baseWeight
	end

	local rolledRarity = rollWeightedRarity(adjustedWeights)
	local candidates: { GameConfig.RelicConfig } = {}
	local zoneFallback: { GameConfig.RelicConfig } = {}
	local rarityFallback: { GameConfig.RelicConfig } = {}

	for _, relic in pairs(GameConfig.RELICS) do
		if relic.findable then
			local inZone = zoneContains(relic.zones, zoneId)
			if inZone then
				table.insert(zoneFallback, relic)
			end
			if relic.rarity == rolledRarity then
				table.insert(rarityFallback, relic)
				if inZone then
					table.insert(candidates, relic)
				end
			end
		end
	end

	local pool = if #candidates > 0
		then candidates
		elseif #rarityFallback > 0 then rarityFallback
		else zoneFallback

	if #pool == 0 then
		return GameConfig.RELICS.SeaGlassDoubloon
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function completeExcavation(player: Player, exc: ActiveExcavationState): ()
	local profile = DataManager.GetProfile(player)
	local nodeInfo = WorldBuilder.GetNodeInfo(exc.nodeId)
	activeExcavations[player.UserId] = nil

	if not profile or not nodeInfo then
		syncPlayer(player, nil)
		return
	end
	if nodeInfo.model:GetAttribute("IsAvailable") ~= true then
		syncPlayer(player, {
			type = "Toast",
			kind = "Warn",
			text = "Node was already excavated!",
		})
		return
	end

	local now = Workspace:GetServerTimeNow()
	WorldBuilder.SetNodeAvailable(exc.nodeId, false)
	nodeRespawnAt[exc.nodeId] = now + nodeInfo.respawnTime

	local hasLuck = DataManager.IsBuffActive(profile, "TreasureLuckCharm")
	local relicCfg = rollRelicForZone(nodeInfo.zoneId, hasLuck)
	local uid = DataManager.GenerateUid()

	if relicCfg.requiresCleaning then
		table.insert(profile.RawRelics, {
			uid = uid,
			itemId = relicCfg.id,
			foundAt = now,
		})
	else
		table.insert(profile.CleanedRelics, {
			uid = uid,
			itemId = relicCfg.id,
			cleanedFromId = nil,
			obtainedAt = now,
		})
	end

	DataManager.IncrementRelicsFound(player, 1)
	syncPlayer(player, {
		type = "ExcavationComplete",
		itemId = relicCfg.id,
		isRaw = relicCfg.requiresCleaning,
	})
end

local function handleExcavateNode(player: Player, nodeId: any): { [string]: any }
	if typeof(nodeId) ~= "string" then
		return { success = false, message = "Invalid node request." }
	end

	if nodeId == "__CANCEL__" then
		if activeExcavations[player.UserId] then
			activeExcavations[player.UserId] = nil
			syncPlayer(player, nil)
		end
		return { success = true, message = "Excavation canceled." }
	end

	if DivingManager.IsBlackedOut(player) then
		return { success = false, message = "Cannot excavate while blacked out." }
	end

	local profile = DataManager.GetProfile(player)
	local _, root, _ = getCharacterRoot(player)
	if not profile or not root then
		return { success = false, message = "Character unavailable." }
	end

	if activeExcavations[player.UserId] then
		return { success = false, message = "Already excavating a site." }
	end

	local nodeInfo = WorldBuilder.GetNodeInfo(nodeId)
	if not nodeInfo then
		return { success = false, message = "Excavation site not found." }
	end

	if nodeInfo.model:GetAttribute("IsAvailable") ~= true then
		return { success = false, message = "Site is regenerating..." }
	end

	local distance = (root.Position - nodeInfo.primaryPart.Position).Magnitude
	if distance > 22 then
		return { success = false, message = "Swim closer to excavate!" }
	end

	if #profile.RawRelics >= GameConfig.MAX_RELICS_PER_BUCKET or #profile.CleanedRelics >= GameConfig.MAX_RELICS_PER_BUCKET then
		return { success = false, message = "Relic bag is full! Clean or sell relics first." }
	end

	local passives = DataManager.GetPetPassives(profile)
	local speedBonus = passives.excavationSpeedBonus
	if DataManager.IsBuffActive(profile, "SpeedPotion") then
		speedBonus += 0.25
	end

	local duration = math.max(0.65, nodeInfo.digDuration / (1 + speedBonus))
	local now = Workspace:GetServerTimeNow()

	activeExcavations[player.UserId] = {
		nodeId = nodeId,
		startedAt = now,
		endsAt = now + duration,
		duration = duration,
	}

	syncPlayer(player, nil)
	return {
		success = true,
		message = "Excavating " .. nodeInfo.displayName,
		duration = duration,
		nodeId = nodeId,
	}
end

local function handleStartCleaning(player: Player, rawUid: any, requestedSlot: any): { [string]: any }
	if typeof(rawUid) ~= "string" then
		return { success = false, message = "Invalid relic selected." }
	end
	if DivingManager.IsBlackedOut(player) then
		return { success = false, message = "Cannot clean while recovering." }
	end

	local profile = DataManager.GetProfile(player)
	local _, root, _ = getCharacterRoot(player)
	if not profile or not root then
		return { success = false, message = "Character unavailable." }
	end

	if (root.Position - GameConfig.CLEANING_STATION_POSITION).Magnitude > 30 then
		return { success = false, message = "Move closer to the Cleaning Station!" }
	end

	local slotIndex: number? = nil
	if typeof(requestedSlot) == "number" then
		local rounded = math.floor(requestedSlot)
		if rounded >= 1 and rounded <= GameConfig.CLEANING_SLOT_COUNT and profile.CleaningSlots[rounded] == nil then
			slotIndex = rounded
		end
	else
		for idx = 1, GameConfig.CLEANING_SLOT_COUNT do
			if profile.CleaningSlots[idx] == nil then
				slotIndex = idx
				break
			end
		end
	end

	if slotIndex == nil then
		return { success = false, message = "All 3 washbasin slots are busy!" }
	end

	local relicIdx, rawEntry = DataManager.FindRawRelic(profile, rawUid)
	if not relicIdx or not rawEntry then
		return { success = false, message = "Raw relic not found in backpack." }
	end

	local relicCfg = GameConfig.RELICS[rawEntry.itemId]
	if not relicCfg then
		return { success = false, message = "Unknown relic configuration." }
	end

	table.remove(profile.RawRelics, relicIdx)

	local passives = DataManager.GetPetPassives(profile)
	local cleanSpeedBonus = passives.cleaningSpeedBonus
	if DataManager.IsBuffActive(profile, "AutoScrubberBoost") then
		cleanSpeedBonus += 1.5
	end

	local baseDur = math.max(1, relicCfg.cleanDuration)
	local duration = math.max(0.8, baseDur / (1 + cleanSpeedBonus))
	local now = Workspace:GetServerTimeNow()

	profile.CleaningSlots[slotIndex] = {
		slotIndex = slotIndex,
		rawUid = rawEntry.uid,
		rawItemId = rawEntry.itemId,
		startedAt = now,
		endsAt = now + duration,
		duration = duration,
	}

	syncPlayer(player, nil)
	return {
		success = true,
		message = "Scrubbing " .. relicCfg.name .. " in Basin " .. tostring(slotIndex),
		slotIndex = slotIndex,
	}
end

local function handleClaimCleaned(player: Player, slotIndexRaw: any): { [string]: any }
	if typeof(slotIndexRaw) ~= "number" then
		return { success = false, message = "Invalid washbasin slot." }
	end
	local slotIndex = math.floor(slotIndexRaw)
	if slotIndex < 1 or slotIndex > GameConfig.CLEANING_SLOT_COUNT then
		return { success = false, message = "Invalid washbasin slot." }
	end

	if DivingManager.IsBlackedOut(player) then
		return { success = false, message = "Cannot claim while recovering." }
	end

	local profile = DataManager.GetProfile(player)
	local _, root, _ = getCharacterRoot(player)
	if not profile or not root then
		return { success = false, message = "Character unavailable." }
	end

	if (root.Position - GameConfig.CLEANING_STATION_POSITION).Magnitude > 30 then
		return { success = false, message = "Move closer to the Cleaning Station!" }
	end

	local slot = profile.CleaningSlots[slotIndex]
	if not slot then
		return { success = false, message = "That washbasin slot is empty." }
	end

	local now = Workspace:GetServerTimeNow()
	if now < slot.endsAt - 0.15 then
		return { success = false, message = "Still scrubbing! Please wait." }
	end

	if #profile.CleanedRelics >= GameConfig.MAX_RELICS_PER_BUCKET then
		return { success = false, message = "Cleaned relic bag is full! Sell relics first." }
	end

	local rawCfg = GameConfig.RELICS[slot.rawItemId]
	local revealedId = if rawCfg and rawCfg.revealedItemId then rawCfg.revealedItemId else slot.rawItemId
	local revealedCfg = GameConfig.RELICS[revealedId] or rawCfg
	if not revealedCfg then
		return { success = false, message = "Unknown relic configuration." }
	end

	profile.CleaningSlots[slotIndex] = nil
	table.insert(profile.CleanedRelics, {
		uid = DataManager.GenerateUid(),
		itemId = revealedCfg.id,
		cleanedFromId = slot.rawItemId,
		obtainedAt = now,
	})

	syncPlayer(player, {
		type = "CleanedClaimed",
		itemId = revealedCfg.id,
		cleanedFromId = slot.rawItemId,
	})

	return {
		success = true,
		message = "Uncovered " .. revealedCfg.name .. "!",
		revealedItemId = revealedCfg.id,
	}
end

local function handleSellAllRelics(player: Player): { [string]: any }
	if DivingManager.IsBlackedOut(player) then
		return { success = false, message = "Cannot sell while recovering." }
	end

	local profile = DataManager.GetProfile(player)
	local _, root, _ = getCharacterRoot(player)
	if not profile or not root then
		return { success = false, message = "Character unavailable." }
	end

	if (root.Position - GameConfig.APPRAISAL_COUNTER_POSITION).Magnitude > 30 then
		return { success = false, message = "Walk up to the Appraisal Counter to sell!" }
	end

	local count = #profile.CleanedRelics
	if count == 0 then
		return { success = false, message = "No cleaned relics ready to appraise!" }
	end

	local baseTotal = 0
	for _, entry in ipairs(profile.CleanedRelics) do
		local cfg = GameConfig.RELICS[entry.itemId]
		if cfg then
			baseTotal += cfg.sellValue
		end
	end

	local passives = DataManager.GetPetPassives(profile)
	local finalCoins = math.max(1, math.floor(baseTotal * (1 + passives.coinMultiplierBonus) + 0.5))

	profile.CleanedRelics = {}
	DataManager.AddCoins(player, finalCoins)

	syncPlayer(player, {
		type = "RelicsSold",
		coinsEarned = finalCoins,
		soldCount = count,
	})

	return {
		success = true,
		message = string.format("Sold %d relics for %s Coins!", count, GameConfig.FormatNumber(finalCoins)),
		coinsEarned = finalCoins,
		soldCount = count,
	}
end

local function handleBuyUpgrade(player: Player, upgradeId: any): { [string]: any }
	if upgradeId ~= "Oxygen" and upgradeId ~= "SwimSpeed" and upgradeId ~= "LightStrength" then
		return { success = false, message = "Invalid upgrade type." }
	end
	if DivingManager.IsBlackedOut(player) then
		return { success = false, message = "Cannot purchase while recovering." }
	end

	local profile = DataManager.GetProfile(player)
	local _, root, _ = getCharacterRoot(player)
	if not profile or not root then
		return { success = false, message = "Character unavailable." }
	end

	if root.Position.Y < -18 then
		return { success = false, message = "Return to the Harbor Surface to upgrade gear!" }
	end

	local typedId = upgradeId :: GameConfig.UpgradeId
	local currentLevel = profile.GearLevels[typedId]
	local maxLevel = GameConfig.GetMaxGearLevel(typedId)
	if currentLevel >= maxLevel then
		return { success = false, message = "Already at maximum tier!" }
	end

	local nextLevel = currentLevel + 1
	local cost = 0
	local tierName = ""
	if typedId == "Oxygen" then
		local t = GameConfig.GetOxygenTier(nextLevel)
		cost = t.cost
		tierName = t.name
	elseif typedId == "SwimSpeed" then
		local t = GameConfig.GetSwimSpeedTier(nextLevel)
		cost = t.cost
		tierName = t.name
	else
		local t = GameConfig.GetLightStrengthTier(nextLevel)
		cost = t.cost
		tierName = t.name
	end

	if not DataManager.SpendCoins(player, cost) then
		return { success = false, message = "Not enough Coins!" }
	end

	profile.GearLevels[typedId] = nextLevel
	DivingManager.RefreshPlayerStats(player)
	syncPlayer(player, {
		type = "UpgradePurchased",
		upgradeId = typedId,
		level = nextLevel,
		tierName = tierName,
	})

	return {
		success = true,
		message = "Upgraded to " .. tierName .. "!",
		level = nextLevel,
	}
end

local function handleBuyShopItem(player: Player, itemId: any): { [string]: any }
	if typeof(itemId) ~= "string" then
		return { success = false, message = "Invalid shop item." }
	end
	local itemCfg = (GameConfig.SHOP_ITEMS :: { [string]: GameConfig.ShopItemConfig })[itemId]
	if not itemCfg then
		return { success = false, message = "Unknown shop item." }
	end
	if DivingManager.IsBlackedOut(player) then
		return { success = false, message = "Cannot buy items while recovering." }
	end

	local profile = DataManager.GetProfile(player)
	local _, _, _ = getCharacterRoot(player)
	if not profile then
		return { success = false, message = "Profile not loaded." }
	end

	if not DataManager.SpendCoins(player, itemCfg.cost) then
		return { success = false, message = "Not enough Coins!" }
	end

	local now = Workspace:GetServerTimeNow()
	if itemCfg.id == "OxygenCanister" then
		DivingManager.RefillOxygen(player, 1.0)
	end

	local existingExpiry = profile.ActiveBuffs[itemCfg.id]
	local baseTime = if existingExpiry and existingExpiry > now then existingExpiry else now
	profile.ActiveBuffs[itemCfg.id] = math.min(now + 900, baseTime + itemCfg.duration)

	DivingManager.RefreshPlayerStats(player)
	syncPlayer(player, {
		type = "ShopItemBought",
		itemId = itemCfg.id,
	})

	return {
		success = true,
		message = "Activated " .. itemCfg.name .. "!",
	}
end

local function handleHatchEgg(player: Player, eggId: any): { [string]: any }
	if typeof(eggId) ~= "string" then
		return { success = false, message = "Invalid egg selected." }
	end
	local eggCfg = (GameConfig.EGGS :: { [string]: GameConfig.EggConfig })[eggId]
	if not eggCfg then
		return { success = false, message = "Unknown egg tier." }
	end
	if DivingManager.IsBlackedOut(player) then
		return { success = false, message = "Cannot hatch while recovering." }
	end

	local profile = DataManager.GetProfile(player)
	local _, root, _ = getCharacterRoot(player)
	if not profile or not root then
		return { success = false, message = "Character unavailable." }
	end

	if root.Position.Y < -18 then
		return { success = false, message = "Visit the Egg Shrine on Harbor Island to hatch!" }
	end

	if #profile.OwnedPets >= GameConfig.MAX_OWNED_PETS then
		return { success = false, message = "Companion storage full!" }
	end

	if not DataManager.SpendCoins(player, eggCfg.cost) then
		return { success = false, message = "Not enough Coins for " .. eggCfg.name .. "!" }
	end

	local rolledRarity = rollWeightedRarity(eggCfg.rarityWeights)
	local pool = GameConfig.GetPetsByRarity(rolledRarity)
	if #pool == 0 then
		pool = GameConfig.GetPetsByRarity("Common")
	end
	local species = pool[rng:NextInteger(1, #pool)]

	local now = Workspace:GetServerTimeNow()
	local newPet: DataManager.OwnedPetEntry = {
		uid = DataManager.GenerateUid(),
		speciesId = species.id,
		rarity = species.rarity,
		hatchedAt = now,
	}
	table.insert(profile.OwnedPets, newPet)

	local autoEquipped = false
	if #profile.EquippedPetIds < GameConfig.MAX_EQUIPPED_PETS then
		table.insert(profile.EquippedPetIds, newPet.uid)
		autoEquipped = true
	end

	DataManager.UpdateLeaderstats(player)
	DivingManager.RefreshPlayerStats(player)

	syncPlayer(player, {
		type = "PetHatched",
		eggId = eggCfg.id,
		pet = newPet,
		autoEquipped = autoEquipped,
	})

	return {
		success = true,
		message = "Hatched " .. species.name .. " (" .. species.rarity .. ")!",
		eggId = eggCfg.id,
		pet = newPet,
		autoEquipped = autoEquipped,
	}
end

local function handleEquipPets(player: Player, petIdsRaw: any): { [string]: any }
	if typeof(petIdsRaw) ~= "table" then
		return { success = false, message = "Invalid pet list." }
	end
	local profile = DataManager.GetProfile(player)
	if not profile then
		return { success = false, message = "Profile not loaded." }
	end

	local nextEquipped: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, uid in ipairs(petIdsRaw :: { any }) do
		if typeof(uid) ~= "string" then
			return { success = false, message = "Invalid pet ID format." }
		end
		if not seen[uid] then
			local owned = DataManager.FindOwnedPet(profile, uid)
			if not owned then
				return { success = false, message = "You do not own one of the selected companions." }
			end
			seen[uid] = true
			table.insert(nextEquipped, uid)
			if #nextEquipped >= GameConfig.MAX_EQUIPPED_PETS then
				break
			end
		end
	end

	profile.EquippedPetIds = nextEquipped
	DataManager.UpdateLeaderstats(player)
	DivingManager.RefreshPlayerStats(player)
	syncPlayer(player, nil)

	return {
		success = true,
		message = string.format("Equipped %d / %d companions.", #nextEquipped, GameConfig.MAX_EQUIPPED_PETS),
	}
end

function GameplayManager.Init(): ()
	DivingManager.SetCallbacks(
		function(player: Player, lostCount: number)
			activeExcavations[player.UserId] = nil
			syncPlayer(player, {
				type = "Blackout",
				lostCount = lostCount,
			})
		end,
		function(player: Player, eventPayload: { [string]: any }?)
			syncPlayer(player, eventPayload)
		end
	)

	Remotes.ExcavateNode.OnServerInvoke = handleExcavateNode
	Remotes.StartCleaning.OnServerInvoke = handleStartCleaning
	Remotes.ClaimCleaned.OnServerInvoke = handleClaimCleaned
	Remotes.SellAllRelics.OnServerInvoke = handleSellAllRelics
	Remotes.BuyUpgrade.OnServerInvoke = handleBuyUpgrade
	Remotes.BuyShopItem.OnServerInvoke = handleBuyShopItem
	Remotes.HatchEgg.OnServerInvoke = handleHatchEgg
	Remotes.EquipPets.OnServerInvoke = handleEquipPets

	Remotes.SyncState.OnServerEvent:Connect(function(player: Player)
		syncPlayer(player, nil)
	end)

	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()

		-- Respawn depleted excavation nodes
		for nodeId, readyAt in pairs(nodeRespawnAt) do
			if now >= readyAt then
				nodeRespawnAt[nodeId] = nil
				WorldBuilder.SetNodeAvailable(nodeId, true)
			end
		end

		-- Progress / validate active player excavations
		for userId, exc in pairs(activeExcavations) do
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				activeExcavations[userId] = nil
			else
				local _, root, _ = getCharacterRoot(player)
				local nodeInfo = WorldBuilder.GetNodeInfo(exc.nodeId)
				if not root or not nodeInfo or DivingManager.IsBlackedOut(player) then
					activeExcavations[userId] = nil
					syncPlayer(player, nil)
				elseif (root.Position - nodeInfo.primaryPart.Position).Magnitude > 24 then
					activeExcavations[userId] = nil
					syncPlayer(player, {
						type = "Toast",
						kind = "Warn",
						text = "Moved too far away — excavation canceled.",
					})
				elseif now >= exc.endsAt then
					completeExcavation(player, exc)
				end
			end
		end
	end)
end

function GameplayManager.OnPlayerJoined(player: Player): ()
	DataManager.LoadProfile(player)
	DivingManager.SetupPlayer(player)
	DivingManager.RefreshPlayerStats(player)
	syncPlayer(player, nil)
end

function GameplayManager.OnPlayerLeaving(player: Player): ()
	activeExcavations[player.UserId] = nil
	DivingManager.CleanupPlayer(player)
	DataManager.UnloadProfile(player)
end

return GameplayManager
