--!strict
-- Server-authoritative player profile, leaderstats, inventory, workbenches, and DataStore persistence.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

export type RarityTier = GameConfig.RarityTier
export type TerminalId = GameConfig.TerminalId
export type ConsumableId = GameConfig.ConsumableId

export type CarriedLuggageData = {
	uid: string,
	worldBagId: string,
	archetypeId: string,
	tier: RarityTier,
	displayName: string,
	sourceTerminal: TerminalId,
	stolenAt: number,
}

export type StashedLuggageData = {
	uid: string,
	archetypeId: string,
	tier: RarityTier,
	displayName: string,
	sourceTerminal: TerminalId,
}

export type LootEntry = {
	uid: string,
	itemId: string,
	name: string,
	tier: RarityTier,
	value: number,
	iconText: string,
}

export type WorkbenchSlotData = {
	slotIndex: number,
	bagUid: string?,
	archetypeId: string?,
	tier: RarityTier?,
	displayName: string?,
	startedAt: number?,
	duration: number?,
	endsAt: number?,
	isReady: boolean,
	pendingLoot: { LootEntry }?,
}

export type UpgradeLevelsData = {
	Tool: number,
	Sneakers: number,
	StealthCoat: number,
	WorkbenchCount: number,
}

export type PlayerProfile = {
	Cash: number,
	TotalStolen: number,
	CarriedLuggage: CarriedLuggageData?,
	StashedLuggage: { StashedLuggageData },
	WorkbenchSlots: { WorkbenchSlotData },
	RevealedLoot: { LootEntry },
	UnlockedTerminals: { [TerminalId]: boolean },
	UpgradeLevels: UpgradeLevelsData,
	Consumables: { [ConsumableId]: number },
}

export type ClientProfileSnapshot = {
	Cash: number,
	TotalStolen: number,
	CarriedLuggage: CarriedLuggageData?,
	StashedLuggage: { StashedLuggageData },
	WorkbenchSlots: { WorkbenchSlotData },
	RevealedLoot: { LootEntry },
	UnlockedTerminals: { [TerminalId]: boolean },
	UpgradeLevels: UpgradeLevelsData,
	Consumables: { [ConsumableId]: number },
	ServerNow: number,
}

type SavedWorkbenchSlot = {
	slotIndex: number,
	bagUid: string?,
	archetypeId: string?,
	tier: RarityTier?,
	displayName: string?,
	remainingSeconds: number?,
	duration: number?,
	isReady: boolean?,
	pendingLoot: { LootEntry }?,
}

type SavedProfilePayload = {
	Cash: number?,
	TotalStolen: number?,
	StashedLuggage: { StashedLuggageData }?,
	WorkbenchSlots: { SavedWorkbenchSlot }?,
	RevealedLoot: { LootEntry }?,
	UnlockedTerminals: { [string]: boolean }?,
	UpgradeLevels: UpgradeLevelsData?,
	Consumables: { [string]: number }?,
}

local DATASTORE_NAME = "StealALuggage_Profile_v1"
local MAX_WORKBENCH_SLOTS = 4
local MAX_STASH_CAPACITY = 20

local DataManager = {}

local profiles: { [Player]: PlayerProfile } = {}
local leaderstatsCash: { [Player]: IntValue } = {}
local leaderstatsStolen: { [Player]: IntValue } = {}
local rng = Random.new()

local profileStore: DataStore? = nil
local storeInitAttempted = false

local function getDataStore(): DataStore?
	if storeInitAttempted then
		return profileStore
	end
	storeInitAttempted = true
	local ok, storeOrErr = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok and storeOrErr then
		profileStore = storeOrErr :: DataStore
	elseif RunService:IsStudio() then
		-- Studio without API services falls back seamlessly to session-only storage
		profileStore = nil
	end
	return profileStore
end

local function makeEmptySlot(slotIndex: number): WorkbenchSlotData
	return {
		slotIndex = slotIndex,
		bagUid = nil,
		archetypeId = nil,
		tier = nil,
		displayName = nil,
		startedAt = nil,
		duration = nil,
		endsAt = nil,
		isReady = false,
		pendingLoot = nil,
	}
end

local function createDefaultProfile(): PlayerProfile
	local slots: { WorkbenchSlotData } = {}
	for i = 1, MAX_WORKBENCH_SLOTS do
		table.insert(slots, makeEmptySlot(i))
	end

	return {
		Cash = 0,
		TotalStolen = 0,
		CarriedLuggage = nil,
		StashedLuggage = {},
		WorkbenchSlots = slots,
		RevealedLoot = {},
		UnlockedTerminals = {
			Domestic = true,
			International = false,
			FirstClass = false,
			Celebrity = false,
		},
		UpgradeLevels = {
			Tool = 1,
			Sneakers = 1,
			StealthCoat = 1,
			WorkbenchCount = 1,
		},
		Consumables = {
			SmokeBomb = 1,
			DistractionAlarm = 1,
		},
	}
end

local function rollTierFromWeights(weights: { [RarityTier]: number }): RarityTier
	local totalWeight = 0
	for _, tier in ipairs(GameConfig.TIER_ORDER) do
		totalWeight += (weights[tier] or 0)
	end
	if totalWeight <= 0 then
		return "Common"
	end

	local roll = rng:NextNumber(0, totalWeight)
	local cumulative = 0
	for _, tier in ipairs(GameConfig.TIER_ORDER) do
		cumulative += (weights[tier] or 0)
		if roll <= cumulative then
			return tier
		end
	end
	return "Common"
end

local function rollLootForArchetype(archetypeId: string, fallbackTier: RarityTier): { LootEntry }
	local arch = GameConfig.GetArchetype(archetypeId)
	local bagTier = if arch then arch.tier else fallbackTier
	local rollCount = if arch then arch.lootRolls else 1
	local weights = GameConfig.TIER_LOOT_WEIGHTS[bagTier] or GameConfig.TIER_LOOT_WEIGHTS.Common

	local results: { LootEntry } = {}
	for _ = 1, rollCount do
		local rolledTier = rollTierFromWeights(weights)
		local pool = GameConfig.GetLootItemsForTier(rolledTier)
		if #pool == 0 then
			pool = GameConfig.GetLootItemsForTier("Common")
		end
		local chosen = pool[rng:NextInteger(1, #pool)]
		table.insert(results, {
			uid = HttpService:GenerateGUID(false),
			itemId = chosen.id,
			name = chosen.name,
			tier = chosen.tier,
			value = chosen.value,
			iconText = chosen.iconText,
		})
	end
	return results
end

local function updateLeaderstats(player: Player, profile: PlayerProfile)
	local cashVal = leaderstatsCash[player]
	if cashVal then
		cashVal.Value = math.floor(profile.Cash)
	end
	local stolenVal = leaderstatsStolen[player]
	if stolenVal then
		stolenVal.Value = math.floor(profile.TotalStolen)
	end
end

local function applySavedPayload(profile: PlayerProfile, saved: SavedProfilePayload)
	if typeof(saved.Cash) == "number" then
		profile.Cash = math.max(0, math.floor(saved.Cash))
	end
	if typeof(saved.TotalStolen) == "number" then
		profile.TotalStolen = math.max(0, math.floor(saved.TotalStolen))
	end

	if typeof(saved.UnlockedTerminals) == "table" then
		for _, termId in ipairs(GameConfig.TERMINAL_ORDER) do
			if saved.UnlockedTerminals[termId] == true then
				profile.UnlockedTerminals[termId] = true
			end
		end
		profile.UnlockedTerminals.Domestic = true
	end

	if typeof(saved.UpgradeLevels) == "table" then
		profile.UpgradeLevels.Tool = math.clamp(math.floor(saved.UpgradeLevels.Tool or 1), 1, #GameConfig.CRACKING_TOOLS)
		profile.UpgradeLevels.Sneakers = math.clamp(math.floor(saved.UpgradeLevels.Sneakers or 1), 1, #GameConfig.SNEAKER_UPGRADES)
		profile.UpgradeLevels.StealthCoat = math.clamp(math.floor(saved.UpgradeLevels.StealthCoat or 1), 1, #GameConfig.STEALTH_COAT_UPGRADES)
		profile.UpgradeLevels.WorkbenchCount = math.clamp(math.floor(saved.UpgradeLevels.WorkbenchCount or 1), 1, MAX_WORKBENCH_SLOTS)
	end

	if typeof(saved.Consumables) == "table" then
		for _, cid in ipairs(GameConfig.CONSUMABLE_ORDER) do
			local def = GameConfig.CONSUMABLES[cid]
			local rawCount = saved.Consumables[cid]
			if typeof(rawCount) == "number" then
				profile.Consumables[cid] = math.clamp(math.floor(rawCount), 0, def.maxStack)
			end
		end
	end

	if typeof(saved.StashedLuggage) == "table" then
		for _, entry in ipairs(saved.StashedLuggage) do
			if #profile.StashedLuggage >= MAX_STASH_CAPACITY then
				break
			end
			if typeof(entry) == "table" and typeof(entry.archetypeId) == "string" and GameConfig.GetArchetype(entry.archetypeId) then
				table.insert(profile.StashedLuggage, {
					uid = if typeof(entry.uid) == "string" then entry.uid else HttpService:GenerateGUID(false),
					archetypeId = entry.archetypeId,
					tier = entry.tier,
					displayName = entry.displayName,
					sourceTerminal = entry.sourceTerminal,
				})
			end
		end
	end

	if typeof(saved.RevealedLoot) == "table" then
		for _, item in ipairs(saved.RevealedLoot) do
			if typeof(item) == "table" and typeof(item.itemId) == "string" then
				local def = GameConfig.GetLootItem(item.itemId)
				if def then
					table.insert(profile.RevealedLoot, {
						uid = if typeof(item.uid) == "string" then item.uid else HttpService:GenerateGUID(false),
						itemId = def.id,
						name = def.name,
						tier = def.tier,
						value = def.value,
						iconText = def.iconText,
					})
				end
			end
		end
	end

	if typeof(saved.WorkbenchSlots) == "table" then
		local now = Workspace:GetServerTimeNow()
		for i = 1, MAX_WORKBENCH_SLOTS do
			local savedSlot = saved.WorkbenchSlots[i]
			if savedSlot and typeof(savedSlot.bagUid) == "string" and typeof(savedSlot.archetypeId) == "string" then
				local dur = math.max(1, savedSlot.duration or 10)
				local rem = math.max(0, savedSlot.remainingSeconds or 0)
				local isReady = (savedSlot.isReady == true) or (rem <= 0)
				local slot = profile.WorkbenchSlots[i]
				slot.bagUid = savedSlot.bagUid
				slot.archetypeId = savedSlot.archetypeId
				slot.tier = savedSlot.tier
				slot.displayName = savedSlot.displayName
				slot.duration = dur
				slot.startedAt = now - (dur - rem)
				slot.endsAt = now + rem
				slot.isReady = isReady
				if isReady then
					if typeof(savedSlot.pendingLoot) == "table" and #savedSlot.pendingLoot > 0 then
						slot.pendingLoot = savedSlot.pendingLoot
					else
						slot.pendingLoot = rollLootForArchetype(savedSlot.archetypeId, savedSlot.tier or "Common")
					end
				end
			end
		end
	end
end

local function serializeProfile(profile: PlayerProfile): SavedProfilePayload
	local now = Workspace:GetServerTimeNow()
	local savedSlots: { SavedWorkbenchSlot } = {}
	for i, slot in ipairs(profile.WorkbenchSlots) do
		local remaining = 0
		if slot.endsAt then
			remaining = math.max(0, slot.endsAt - now)
		end
		table.insert(savedSlots, {
			slotIndex = i,
			bagUid = slot.bagUid,
			archetypeId = slot.archetypeId,
			tier = slot.tier,
			displayName = slot.displayName,
			remainingSeconds = remaining,
			duration = slot.duration,
			isReady = slot.isReady,
			pendingLoot = slot.pendingLoot,
		})
	end

	local savedTerminals: { [string]: boolean } = {}
	for k, v in pairs(profile.UnlockedTerminals) do
		savedTerminals[k] = v
	end
	local savedConsumables: { [string]: number } = {}
	for k, v in pairs(profile.Consumables) do
		savedConsumables[k] = v
	end

	return {
		Cash = profile.Cash,
		TotalStolen = profile.TotalStolen,
		StashedLuggage = profile.StashedLuggage,
		WorkbenchSlots = savedSlots,
		RevealedLoot = profile.RevealedLoot,
		UnlockedTerminals = savedTerminals,
		UpgradeLevels = profile.UpgradeLevels,
		Consumables = savedConsumables,
	}
end

local function setupLeaderstats(player: Player, profile: PlayerProfile)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local cashStat = Instance.new("IntValue")
	cashStat.Name = "Cash"
	cashStat.Value = math.floor(profile.Cash)
	cashStat.Parent = folder

	local stolenStat = Instance.new("IntValue")
	stolenStat.Name = "Bags Stolen"
	stolenStat.Value = math.floor(profile.TotalStolen)
	stolenStat.Parent = folder

	leaderstatsCash[player] = cashStat
	leaderstatsStolen[player] = stolenStat
end

function DataManager.LoadProfile(player: Player): PlayerProfile
	local profile = createDefaultProfile()

	local store = getDataStore()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("Player_" .. tostring(player.UserId))
		end)
		if ok and typeof(data) == "table" then
			applySavedPayload(profile, data :: SavedProfilePayload)
		end
	end

	profiles[player] = profile
	setupLeaderstats(player, profile)
	return profile
end

function DataManager.SaveProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local store = getDataStore()
	if not store then
		return
	end
	local payload = serializeProfile(profile)
	pcall(function()
		store:SetAsync("Player_" .. tostring(player.UserId), payload)
	end)
end

function DataManager.UnloadProfile(player: Player)
	DataManager.SaveProfile(player)
	profiles[player] = nil
	leaderstatsCash[player] = nil
	leaderstatsStolen[player] = nil
end

function DataManager.GetProfile(player: Player): PlayerProfile?
	return profiles[player]
end

function DataManager.AddCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 then
		return false
	end
	profile.Cash += math.floor(amount)
	updateLeaderstats(player, profile)
	return true
end

function DataManager.SpendCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.Cash < amount then
		return false
	end
	profile.Cash -= math.floor(amount)
	updateLeaderstats(player, profile)
	return true
end

function DataManager.ApplyFine(player: Player, fineAmount: number): number
	local profile = profiles[player]
	if not profile or fineAmount <= 0 then
		return 0
	end
	local deducted = math.min(profile.Cash, math.floor(fineAmount))
	profile.Cash -= deducted
	updateLeaderstats(player, profile)
	return deducted
end

function DataManager.SetCarriedLuggage(player: Player, bagData: CarriedLuggageData): boolean
	local profile = profiles[player]
	if not profile or profile.CarriedLuggage ~= nil then
		return false
	end
	profile.CarriedLuggage = bagData
	return true
end

function DataManager.ClearCarriedLuggage(player: Player): CarriedLuggageData?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local dropped = profile.CarriedLuggage
	profile.CarriedLuggage = nil
	return dropped
end

function DataManager.BankCarriedLuggage(player: Player): (boolean, StashedLuggageData?, string?)
	local profile = profiles[player]
	if not profile then
		return false, nil, "Profile missing"
	end
	local carried = profile.CarriedLuggage
	if not carried then
		return false, nil, "No carried bag"
	end
	if #profile.StashedLuggage >= MAX_STASH_CAPACITY then
		return false, nil, "Stash full (max 20 bags) — crack some on a Workbench!"
	end

	local stashed: StashedLuggageData = {
		uid = carried.uid,
		archetypeId = carried.archetypeId,
		tier = carried.tier,
		displayName = carried.displayName,
		sourceTerminal = carried.sourceTerminal,
	}
	profile.CarriedLuggage = nil
	table.insert(profile.StashedLuggage, stashed)
	profile.TotalStolen += 1
	updateLeaderstats(player, profile)
	return true, stashed, nil
end

function DataManager.PlaceStashedOnWorkbench(player: Player, bagUid: string?, slotIndex: number): (boolean, string)
	local profile = profiles[player]
	if not profile then
		return false, "Profile not loaded."
	end

	if slotIndex < 1 or slotIndex > MAX_WORKBENCH_SLOTS then
		return false, "Invalid workbench slot."
	end
	if slotIndex > profile.UpgradeLevels.WorkbenchCount then
		return false, "Unlock this Workbench slot in the Black-Market Shop first!"
	end

	local slot = profile.WorkbenchSlots[slotIndex]
	if slot.bagUid ~= nil then
		return false, "That Workbench slot is already occupied."
	end

	if #profile.StashedLuggage == 0 then
		return false, "You have no stashed luggage yet. Steal a bag from the Airport!"
	end

	-- Find matching bagUid or pick the newest bag if nil/empty
	local chosenIndex: number? = nil
	if bagUid and bagUid ~= "" then
		for idx, bag in ipairs(profile.StashedLuggage) do
			if bag.uid == bagUid then
				chosenIndex = idx
				break
			end
		end
	else
		-- Prefer the highest-value bag the player's current tool can crack, fallback to #1
		for idx = #profile.StashedLuggage, 1, -1 do
			local candidate = profile.StashedLuggage[idx]
			if GameConfig.CanToolCrackTier(profile.UpgradeLevels.Tool, candidate.tier) then
				chosenIndex = idx
				break
			end
		end
		if chosenIndex == nil then
			chosenIndex = #profile.StashedLuggage
		end
	end

	if not chosenIndex then
		return false, "Selected bag not found in stash."
	end

	local bag = profile.StashedLuggage[chosenIndex]
	if not GameConfig.CanToolCrackTier(profile.UpgradeLevels.Tool, bag.tier) then
		local neededLevel = 2
		for _, tool in ipairs(GameConfig.CRACKING_TOOLS) do
			if GameConfig.TIER_RANK[tool.maxBagTier] >= GameConfig.TIER_RANK[bag.tier] then
				neededLevel = tool.level
				break
			end
		end
		local neededTool = GameConfig.GetToolUpgrade(neededLevel)
		return false, string.format("%s (%s) requires %s (Lv.%d) to crack!", bag.displayName, bag.tier, neededTool.name, neededTool.level)
	end

	table.remove(profile.StashedLuggage, chosenIndex)

	local arch = GameConfig.GetArchetype(bag.archetypeId)
	local baseTime = if arch then arch.baseOpenTime else (GameConfig.TIER_UNLOCK_SECONDS[bag.tier] or 10)
	local tool = GameConfig.GetToolUpgrade(profile.UpgradeLevels.Tool)
	local duration = math.max(2.5, math.round((baseTime / tool.speedMultiplier) * 10) / 10)
	local now = Workspace:GetServerTimeNow()

	slot.bagUid = bag.uid
	slot.archetypeId = bag.archetypeId
	slot.tier = bag.tier
	slot.displayName = bag.displayName
	slot.startedAt = now
	slot.duration = duration
	slot.endsAt = now + duration
	slot.isReady = false
	slot.pendingLoot = nil

	return true, string.format("Cracking %s (%ds)!", bag.displayName, math.ceil(duration))
end

function DataManager.ClaimWorkbenchSlot(player: Player, slotIndex: number): (boolean, { LootEntry }?, string)
	local profile = profiles[player]
	if not profile then
		return false, nil, "Profile not loaded."
	end
	if slotIndex < 1 or slotIndex > MAX_WORKBENCH_SLOTS then
		return false, nil, "Invalid workbench slot."
	end

	local slot = profile.WorkbenchSlots[slotIndex]
	if not slot.bagUid then
		return false, nil, "This Workbench is empty."
	end

	local now = Workspace:GetServerTimeNow()
	if not slot.isReady then
		if slot.endsAt and now >= slot.endsAt then
			slot.isReady = true
			if not slot.pendingLoot then
				slot.pendingLoot = rollLootForArchetype(slot.archetypeId or "Backpacker", slot.tier or "Common")
			end
		else
			local rem = math.ceil(math.max(0, (slot.endsAt or now) - now))
			return false, nil, string.format("Still cracking (%ds remaining)...", rem)
		end
	end

	local loot = slot.pendingLoot or rollLootForArchetype(slot.archetypeId or "Backpacker", slot.tier or "Common")
	for _, entry in ipairs(loot) do
		table.insert(profile.RevealedLoot, entry)
	end

	profile.WorkbenchSlots[slotIndex] = makeEmptySlot(slotIndex)
	return true, loot, "Loot claimed!"
end

function DataManager.SellAllLoot(player: Player): (boolean, number, number)
	local profile = profiles[player]
	if not profile then
		return false, 0, 0
	end
	local count = #profile.RevealedLoot
	if count == 0 then
		return false, 0, 0
	end
	local totalCash = 0
	for _, entry in ipairs(profile.RevealedLoot) do
		totalCash += entry.value
	end
	table.clear(profile.RevealedLoot)
	profile.Cash += totalCash
	updateLeaderstats(player, profile)
	return true, totalCash, count
end

function DataManager.BuyUpgrade(player: Player, category: string): (boolean, string)
	local profile = profiles[player]
	if not profile then
		return false, "Profile missing."
	end

	if category == "Tool" then
		local nextLevel = profile.UpgradeLevels.Tool + 1
		if nextLevel > #GameConfig.CRACKING_TOOLS then
			return false, "Cracking Tool is already maxed!"
		end
		local nextDef = GameConfig.GetToolUpgrade(nextLevel)
		if not DataManager.SpendCash(player, nextDef.cost) then
			return false, string.format("Need %s for %s!", GameConfig.FormatCash(nextDef.cost), nextDef.name)
		end
		profile.UpgradeLevels.Tool = nextLevel
		return true, string.format("Upgraded to %s!", nextDef.name)
	elseif category == "WorkbenchCount" then
		local nextLevel = profile.UpgradeLevels.WorkbenchCount + 1
		if nextLevel > #GameConfig.WORKBENCH_UPGRADES then
			return false, "All 4 Workbenches are already unlocked!"
		end
		local nextDef = GameConfig.GetWorkbenchUpgrade(nextLevel)
		if not DataManager.SpendCash(player, nextDef.cost) then
			return false, string.format("Need %s for %s!", GameConfig.FormatCash(nextDef.cost), nextDef.name)
		end
		profile.UpgradeLevels.WorkbenchCount = nextLevel
		return true, string.format("Unlocked Workbench Slot #%d!", nextLevel)
	elseif category == "Sneakers" then
		local nextLevel = profile.UpgradeLevels.Sneakers + 1
		if nextLevel > #GameConfig.SNEAKER_UPGRADES then
			return false, "Sneakers are already maxed!"
		end
		local nextDef = GameConfig.GetSneakerUpgrade(nextLevel)
		if not DataManager.SpendCash(player, nextDef.cost) then
			return false, string.format("Need %s for %s!", GameConfig.FormatCash(nextDef.cost), nextDef.name)
		end
		profile.UpgradeLevels.Sneakers = nextLevel
		return true, string.format("Equipped %s!", nextDef.name)
	elseif category == "StealthCoat" then
		local nextLevel = profile.UpgradeLevels.StealthCoat + 1
		if nextLevel > #GameConfig.STEALTH_COAT_UPGRADES then
			return false, "Stealth Coat is already maxed!"
		end
		local nextDef = GameConfig.GetStealthCoatUpgrade(nextLevel)
		if not DataManager.SpendCash(player, nextDef.cost) then
			return false, string.format("Need %s for %s!", GameConfig.FormatCash(nextDef.cost), nextDef.name)
		end
		profile.UpgradeLevels.StealthCoat = nextLevel
		return true, string.format("Equipped %s!", nextDef.name)
	end

	return false, "Unknown upgrade category."
end

function DataManager.BuyConsumable(player: Player, itemId: string): (boolean, string)
	local profile = profiles[player]
	if not profile then
		return false, "Profile missing."
	end
	local def = GameConfig.CONSUMABLES[itemId :: ConsumableId]
	if not def then
		return false, "Unknown gadget."
	end
	local current = profile.Consumables[def.id] or 0
	if current >= def.maxStack then
		return false, string.format("%s stack full (%d/%d)!", def.name, current, def.maxStack)
	end
	if not DataManager.SpendCash(player, def.cost) then
		return false, string.format("Need %s for %s!", GameConfig.FormatCash(def.cost), def.name)
	end
	profile.Consumables[def.id] = current + 1
	return true, string.format("Bought %s (%d/%d)!", def.name, current + 1, def.maxStack)
end

function DataManager.ConsumeGadget(player: Player, itemId: ConsumableId): (boolean, string)
	local profile = profiles[player]
	if not profile then
		return false, "Profile missing."
	end
	local def = GameConfig.CONSUMABLES[itemId]
	if not def then
		return false, "Invalid gadget."
	end
	local current = profile.Consumables[itemId] or 0
	if current <= 0 then
		return false, string.format("Out of %s! Buy more in the Hideout Shop.", def.name)
	end
	profile.Consumables[itemId] = current - 1
	return true, def.name
end

function DataManager.UnlockTerminal(player: Player, terminalId: string): (boolean, string)
	local profile = profiles[player]
	if not profile then
		return false, "Profile missing."
	end
	local def = GameConfig.TERMINALS[terminalId :: TerminalId]
	if not def then
		return false, "Unknown terminal."
	end
	if profile.UnlockedTerminals[def.id] then
		return false, string.format("%s is already unlocked!", def.name)
	end
	if not DataManager.SpendCash(player, def.unlockCost) then
		return false, string.format("Need %s for %s pass!", GameConfig.FormatCash(def.unlockCost), def.name)
	end
	profile.UnlockedTerminals[def.id] = true
	return true, string.format("Unlocked %s!", def.name)
end

function DataManager.UpdateWorkbenchTimers(now: number): { Player }
	local newlyCompletedPlayers: { Player } = {}
	for player, profile in pairs(profiles) do
		local changed = false
		for _, slot in ipairs(profile.WorkbenchSlots) do
			if slot.bagUid ~= nil and not slot.isReady and slot.endsAt ~= nil and now >= slot.endsAt then
				slot.isReady = true
				slot.pendingLoot = rollLootForArchetype(slot.archetypeId or "Backpacker", slot.tier or "Common")
				changed = true
			end
		end
		if changed then
			table.insert(newlyCompletedPlayers, player)
		end
	end
	return newlyCompletedPlayers
end

function DataManager.BuildClientSnapshot(player: Player): ClientProfileSnapshot?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return {
		Cash = profile.Cash,
		TotalStolen = profile.TotalStolen,
		CarriedLuggage = profile.CarriedLuggage,
		StashedLuggage = profile.StashedLuggage,
		WorkbenchSlots = profile.WorkbenchSlots,
		RevealedLoot = profile.RevealedLoot,
		UnlockedTerminals = profile.UnlockedTerminals,
		UpgradeLevels = profile.UpgradeLevels,
		Consumables = profile.Consumables,
		ServerNow = Workspace:GetServerTimeNow(),
	}
end

function DataManager.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager.SaveProfile(player)
	end
end

return DataManager
