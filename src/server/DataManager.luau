--!strict
-- Session-based player profile management with DataStore-ready serialization

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

export type RawRelicEntry = {
	uid: string,
	itemId: string,
	foundAt: number,
}

export type CleanedRelicEntry = {
	uid: string,
	itemId: string,
	cleanedFromId: string?,
	obtainedAt: number,
}

export type OwnedPetEntry = {
	uid: string,
	speciesId: string,
	rarity: GameConfig.Rarity,
	hatchedAt: number,
}

export type GearLevels = {
	Oxygen: number,
	SwimSpeed: number,
	LightStrength: number,
}

export type CleaningSlotEntry = {
	slotIndex: number,
	rawUid: string,
	rawItemId: string,
	startedAt: number,
	endsAt: number,
	duration: number,
}

export type PlayerProfile = {
	Coins: number,
	RelicsFound: number,
	RawRelics: { RawRelicEntry },
	CleanedRelics: { CleanedRelicEntry },
	OwnedPets: { OwnedPetEntry },
	EquippedPetIds: { string },
	GearLevels: GearLevels,
	ActiveBuffs: { [string]: number },
	CleaningSlots: { [number]: CleaningSlotEntry },
}

export type SerializedProfile = {
	Coins: number,
	RelicsFound: number,
	RawRelics: { RawRelicEntry },
	CleanedRelics: { CleanedRelicEntry },
	OwnedPets: { OwnedPetEntry },
	EquippedPetIds: { string },
	GearLevels: GearLevels,
	ActiveBuffRemaining: { [string]: number },
	CleaningSlotsRemaining: { [string]: { rawUid: string, rawItemId: string, remaining: number, duration: number } },
}

local DATASTORE_NAME = "AbyssalHarborProfiles_v1"

local profilesByUserId: { [number]: PlayerProfile } = {}
local activeDataStore: DataStore? = nil

local DataManager = {}

local function generateUid(): string
	return HttpService:GenerateGUID(false)
end

local function createDefaultProfile(): PlayerProfile
	return {
		Coins = GameConfig.STARTING_COINS,
		RelicsFound = 0,
		RawRelics = {},
		CleanedRelics = {},
		OwnedPets = {},
		EquippedPetIds = {},
		GearLevels = {
			Oxygen = 1,
			SwimSpeed = 1,
			LightStrength = 1,
		},
		ActiveBuffs = {},
		CleaningSlots = {},
	}
end

local function hydrateProfile(rawData: any): PlayerProfile
	local profile = createDefaultProfile()
	if typeof(rawData) ~= "table" then
		return profile
	end

	local now = Workspace:GetServerTimeNow()

	if typeof(rawData.Coins) == "number" then
		profile.Coins = math.max(0, math.floor(rawData.Coins))
	end
	if typeof(rawData.RelicsFound) == "number" then
		profile.RelicsFound = math.max(0, math.floor(rawData.RelicsFound))
	end

	if typeof(rawData.RawRelics) == "table" then
		for _, entry in ipairs(rawData.RawRelics) do
			if typeof(entry) == "table" and typeof(entry.itemId) == "string" and GameConfig.RELICS[entry.itemId] ~= nil then
				table.insert(profile.RawRelics, {
					uid = if typeof(entry.uid) == "string" then entry.uid else generateUid(),
					itemId = entry.itemId,
					foundAt = if typeof(entry.foundAt) == "number" then entry.foundAt else now,
				})
			end
		end
	end

	if typeof(rawData.CleanedRelics) == "table" then
		for _, entry in ipairs(rawData.CleanedRelics) do
			if typeof(entry) == "table" and typeof(entry.itemId) == "string" and GameConfig.RELICS[entry.itemId] ~= nil then
				table.insert(profile.CleanedRelics, {
					uid = if typeof(entry.uid) == "string" then entry.uid else generateUid(),
					itemId = entry.itemId,
					cleanedFromId = if typeof(entry.cleanedFromId) == "string" then entry.cleanedFromId else nil,
					obtainedAt = if typeof(entry.obtainedAt) == "number" then entry.obtainedAt else now,
				})
			end
		end
	end

	local validPetUids: { [string]: boolean } = {}
	if typeof(rawData.OwnedPets) == "table" then
		for _, entry in ipairs(rawData.OwnedPets) do
			if typeof(entry) == "table" and typeof(entry.speciesId) == "string" then
				local species = GameConfig.PETS[entry.speciesId]
				if species ~= nil then
					local uid = if typeof(entry.uid) == "string" then entry.uid else generateUid()
					validPetUids[uid] = true
					table.insert(profile.OwnedPets, {
						uid = uid,
						speciesId = species.id,
						rarity = species.rarity,
						hatchedAt = if typeof(entry.hatchedAt) == "number" then entry.hatchedAt else now,
					})
				end
			end
		end
	end

	if typeof(rawData.EquippedPetIds) == "table" then
		local seen: { [string]: boolean } = {}
		for _, uid in ipairs(rawData.EquippedPetIds) do
			if typeof(uid) == "string" and validPetUids[uid] and not seen[uid] then
				seen[uid] = true
				table.insert(profile.EquippedPetIds, uid)
				if #profile.EquippedPetIds >= GameConfig.MAX_EQUIPPED_PETS then
					break
				end
			end
		end
	end

	if typeof(rawData.GearLevels) == "table" then
		if typeof(rawData.GearLevels.Oxygen) == "number" then
			profile.GearLevels.Oxygen = math.clamp(math.floor(rawData.GearLevels.Oxygen), 1, GameConfig.GetMaxGearLevel("Oxygen"))
		end
		if typeof(rawData.GearLevels.SwimSpeed) == "number" then
			profile.GearLevels.SwimSpeed = math.clamp(math.floor(rawData.GearLevels.SwimSpeed), 1, GameConfig.GetMaxGearLevel("SwimSpeed"))
		end
		if typeof(rawData.GearLevels.LightStrength) == "number" then
			profile.GearLevels.LightStrength = math.clamp(math.floor(rawData.GearLevels.LightStrength), 1, GameConfig.GetMaxGearLevel("LightStrength"))
		end
	end

	if typeof(rawData.ActiveBuffRemaining) == "table" then
		for buffId, rem in pairs(rawData.ActiveBuffRemaining) do
			if typeof(buffId) == "string" and typeof(rem) == "number" and rem > 0 then
				profile.ActiveBuffs[buffId] = now + rem
			end
		end
	end

	if typeof(rawData.CleaningSlotsRemaining) == "table" then
		for key, slotRaw in pairs(rawData.CleaningSlotsRemaining) do
			local slotIdx = tonumber(key)
			if slotIdx and slotIdx >= 1 and slotIdx <= GameConfig.CLEANING_SLOT_COUNT and typeof(slotRaw) == "table" then
				if typeof(slotRaw.rawItemId) == "string" and GameConfig.RELICS[slotRaw.rawItemId] ~= nil then
					local duration = if typeof(slotRaw.duration) == "number" then math.max(1, slotRaw.duration) else 6
					local remaining = if typeof(slotRaw.remaining) == "number" then math.max(0, slotRaw.remaining) else 0
					profile.CleaningSlots[slotIdx] = {
						slotIndex = slotIdx,
						rawUid = if typeof(slotRaw.rawUid) == "string" then slotRaw.rawUid else generateUid(),
						rawItemId = slotRaw.rawItemId,
						startedAt = now - math.max(0, duration - remaining),
						endsAt = now + remaining,
						duration = duration,
					}
				end
			end
		end
	end

	return profile
end

local function serializeProfileForSave(profile: PlayerProfile): SerializedProfile
	local now = Workspace:GetServerTimeNow()
	local activeBuffRemaining: { [string]: number } = {}
	for buffId, expiresAt in pairs(profile.ActiveBuffs) do
		local rem = expiresAt - now
		if rem > 0 then
			activeBuffRemaining[buffId] = rem
		end
	end

	local slotsRemaining: { [string]: { rawUid: string, rawItemId: string, remaining: number, duration: number } } = {}
	for slotIndex, slot in pairs(profile.CleaningSlots) do
		slotsRemaining[tostring(slotIndex)] = {
			rawUid = slot.rawUid,
			rawItemId = slot.rawItemId,
			remaining = math.max(0, slot.endsAt - now),
			duration = slot.duration,
		}
	end

	return {
		Coins = profile.Coins,
		RelicsFound = profile.RelicsFound,
		RawRelics = profile.RawRelics,
		CleanedRelics = profile.CleanedRelics,
		OwnedPets = profile.OwnedPets,
		EquippedPetIds = profile.EquippedPetIds,
		GearLevels = profile.GearLevels,
		ActiveBuffRemaining = activeBuffRemaining,
		CleaningSlotsRemaining = slotsRemaining,
	}
end

local function setupLeaderstats(player: Player, profile: PlayerProfile): ()
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = profile.Coins
	coinsValue.Parent = folder

	local relicsValue = Instance.new("IntValue")
	relicsValue.Name = "Relics Found"
	relicsValue.Value = profile.RelicsFound
	relicsValue.Parent = folder
end

local function syncPlayerAttributes(player: Player, profile: PlayerProfile): ()
	local speciesList: { string } = {}
	local ownedById: { [string]: OwnedPetEntry } = {}
	for _, pet in ipairs(profile.OwnedPets) do
		ownedById[pet.uid] = pet
	end

	for _, uid in ipairs(profile.EquippedPetIds) do
		local entry = ownedById[uid]
		if entry then
			table.insert(speciesList, entry.speciesId)
		end
	end

	player:SetAttribute("EquippedPetSpecies", table.concat(speciesList, ","))
end

function DataManager.Init(): ()
	if game.GameId == 0 then
		activeDataStore = nil
		return
	end

	local ok, storeOrErr = pcall(function(): DataStore
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)

	if ok and storeOrErr then
		activeDataStore = storeOrErr
	else
		activeDataStore = nil
	end
end

function DataManager.GenerateUid(): string
	return generateUid()
end

function DataManager.UpdateLeaderstats(player: Player): ()
	local profile = profilesByUserId[player.UserId]
	if not profile then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coinsVal = leaderstats:FindFirstChild("Coins")
		if coinsVal and coinsVal:IsA("IntValue") then
			coinsVal.Value = profile.Coins
		end
		local relicsVal = leaderstats:FindFirstChild("Relics Found")
		if relicsVal and relicsVal:IsA("IntValue") then
			relicsVal.Value = profile.RelicsFound
		end
	end

	syncPlayerAttributes(player, profile)
end

function DataManager.LoadProfile(player: Player): PlayerProfile
	local loadedRaw: any = nil
	local store = activeDataStore
	if store ~= nil then
		local key = "Player_" .. tostring(player.UserId)
		local ok, result = pcall(function(): any
			return store:GetAsync(key)
		end)
		if ok then
			loadedRaw = result
		end
	end

	local profile = hydrateProfile(loadedRaw)
	profilesByUserId[player.UserId] = profile
	setupLeaderstats(player, profile)
	syncPlayerAttributes(player, profile)
	return profile
end

function DataManager.SaveProfile(player: Player): boolean
	local profile = profilesByUserId[player.UserId]
	if not profile then
		return false
	end

	local store = activeDataStore
	if store == nil then
		return true
	end

	local serialized = serializeProfileForSave(profile)
	local key = "Player_" .. tostring(player.UserId)
	local ok = pcall(function()
		store:SetAsync(key, serialized)
	end)
	return ok
end

function DataManager.UnloadProfile(player: Player): ()
	DataManager.SaveProfile(player)
	profilesByUserId[player.UserId] = nil
end

function DataManager.GetProfile(player: Player): PlayerProfile?
	return profilesByUserId[player.UserId]
end

function DataManager.AddCoins(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local profile = profilesByUserId[player.UserId]
	if not profile then
		return false
	end
	profile.Coins += math.floor(amount)
	DataManager.UpdateLeaderstats(player)
	return true
end

function DataManager.SpendCoins(player: Player, amount: number): boolean
	if amount < 0 then
		return false
	end
	local profile = profilesByUserId[player.UserId]
	if not profile then
		return false
	end
	local rounded = math.floor(amount)
	if profile.Coins < rounded then
		return false
	end
	profile.Coins -= rounded
	DataManager.UpdateLeaderstats(player)
	return true
end

function DataManager.IncrementRelicsFound(player: Player, delta: number): ()
	local profile = profilesByUserId[player.UserId]
	if not profile then
		return
	end
	profile.RelicsFound += math.max(0, math.floor(delta))
	DataManager.UpdateLeaderstats(player)
end

function DataManager.PruneExpiredBuffs(profile: PlayerProfile): boolean
	local now = Workspace:GetServerTimeNow()
	local changed = false
	for buffId, expiresAt in pairs(profile.ActiveBuffs) do
		if expiresAt <= now then
			profile.ActiveBuffs[buffId] = nil
			changed = true
		end
	end
	return changed
end

function DataManager.IsBuffActive(profile: PlayerProfile, buffId: string): boolean
	local expiresAt = profile.ActiveBuffs[buffId]
	if expiresAt == nil then
		return false
	end
	return expiresAt > Workspace:GetServerTimeNow()
end

function DataManager.GetBuffRemainingSeconds(profile: PlayerProfile, buffId: string): number
	local expiresAt = profile.ActiveBuffs[buffId]
	if expiresAt == nil then
		return 0
	end
	return math.max(0, expiresAt - Workspace:GetServerTimeNow())
end

function DataManager.GetEquippedSpeciesIds(profile: PlayerProfile): { string }
	local ownedById: { [string]: OwnedPetEntry } = {}
	for _, pet in ipairs(profile.OwnedPets) do
		ownedById[pet.uid] = pet
	end

	local result: { string } = {}
	for _, uid in ipairs(profile.EquippedPetIds) do
		local pet = ownedById[uid]
		if pet then
			table.insert(result, pet.speciesId)
		end
	end
	return result
end

function DataManager.GetPetPassives(profile: PlayerProfile): GameConfig.PetPassives
	local speciesIds = DataManager.GetEquippedSpeciesIds(profile)
	return GameConfig.CalculatePetPassives(speciesIds)
end

function DataManager.FindOwnedPet(profile: PlayerProfile, petUid: string): OwnedPetEntry?
	for _, pet in ipairs(profile.OwnedPets) do
		if pet.uid == petUid then
			return pet
		end
	end
	return nil
end

function DataManager.FindRawRelic(profile: PlayerProfile, rawUid: string): (number?, RawRelicEntry?)
	for index, relic in ipairs(profile.RawRelics) do
		if relic.uid == rawUid then
			return index, relic
		end
	end
	return nil, nil
end

return DataManager
