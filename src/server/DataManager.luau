--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

export type StationSlot = GameConfig.StationSlot
export type OwnedWorkerData = Remotes.OwnedWorkerData
export type PlayerStateSnapshot = Remotes.PlayerStateSnapshot
export type RemoteActionResult = Remotes.RemoteActionResult

export type PlayerProfile = {
	yen: number,
	totalServed: number,
	ingredients: { [string]: number },
	ownedWorkers: { OwnedWorkerData },
	equippedWorkers: { [StationSlot]: string? },
	assignedPlotIndex: number?,
}

type LeaderstatsRefs = {
	folder: Folder,
	yenValue: IntValue,
	totalServedValue: IntValue,
}

-- Flip to true when the experience is published and Studio API Access is enabled.
local USE_DATASTORE = false
local DATASTORE_NAME = "AnimeCafeTycoon_Profiles_v1"

local DataManager = {}

local profiles: { [Player]: PlayerProfile } = {}
local leaderstatsByPlayer: { [Player]: LeaderstatsRefs } = {}
local rng = Random.new()

local function getDataStore(): DataStore?
	if not USE_DATASTORE then
		return nil
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		return store :: DataStore
	end
	warn(`[DataManager] Failed to acquire DataStore: {store}`)
	return nil
end

local function createDefaultIngredients(): { [string]: number }
	local stock: { [string]: number } = {}
	for ingredientId, _ in GameConfig.Ingredients do
		stock[ingredientId] = 0
	end
	return stock
end

local function createDefaultEquipped(): { [StationSlot]: string? }
	return {
		Prep = nil,
		Stove = nil,
		Server = nil,
		Cashier = nil,
	}
end

local function createDefaultProfile(): PlayerProfile
	return {
		yen = GameConfig.STARTING_YEN,
		totalServed = 0,
		ingredients = createDefaultIngredients(),
		ownedWorkers = {},
		equippedWorkers = createDefaultEquipped(),
		assignedPlotIndex = nil,
	}
end

local function reconcileProfile(raw: any): PlayerProfile
	local profile = createDefaultProfile()
	if typeof(raw) ~= "table" then
		return profile
	end

	if typeof(raw.yen) == "number" and raw.yen >= 0 then
		profile.yen = math.floor(raw.yen)
	end

	if typeof(raw.totalServed) == "number" and raw.totalServed >= 0 then
		profile.totalServed = math.floor(raw.totalServed)
	end

	if typeof(raw.ingredients) == "table" then
		for ingredientId, _ in GameConfig.Ingredients do
			local count = raw.ingredients[ingredientId]
			if typeof(count) == "number" and count >= 0 then
				profile.ingredients[ingredientId] = math.floor(count)
			end
		end
	end

	local validWorkerIds: { [string]: boolean } = {}
	if typeof(raw.ownedWorkers) == "table" then
		for _, item in raw.ownedWorkers do
			if typeof(item) == "table" and typeof(item.id) == "string" and typeof(item.archetypeId) == "string" then
				local archetype = GameConfig.StaffById[item.archetypeId]
				if archetype then
					validWorkerIds[item.id] = true
					table.insert(profile.ownedWorkers, {
						id = item.id,
						archetypeId = archetype.id,
						name = archetype.name,
						rarity = archetype.rarity,
						workSpeedMultiplier = archetype.workSpeedMultiplier,
					})
				end
			end
		end
	end

	if typeof(raw.equippedWorkers) == "table" then
		for _, slot in GameConfig.StationSlots do
			local assignedId = raw.equippedWorkers[slot]
			if typeof(assignedId) == "string" and validWorkerIds[assignedId] then
				profile.equippedWorkers[slot] = assignedId
			end
		end
	end

	return profile
end

local function serializeProfile(profile: PlayerProfile): { [string]: any }
	return {
		yen = profile.yen,
		totalServed = profile.totalServed,
		ingredients = table.clone(profile.ingredients),
		ownedWorkers = profile.ownedWorkers,
		equippedWorkers = table.clone(profile.equippedWorkers),
	}
end

local function getLeaderstatsKey(player: Player): LeaderstatsRefs?
	return leaderstatsByPlayer[player]
end

local function refreshLeaderstats(player: Player, profile: PlayerProfile)
	local refs = getLeaderstatsKey(player)
	if not refs then
		return
	end
	refs.yenValue.Value = profile.yen
	refs.totalServedValue.Value = profile.totalServed
end

local function createLeaderstats(player: Player, profile: PlayerProfile)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local yenValue = Instance.new("IntValue")
	yenValue.Name = "Yen"
	yenValue.Value = profile.yen
	yenValue.Parent = folder

	local totalServedValue = Instance.new("IntValue")
	totalServedValue.Name = "Total Served"
	totalServedValue.Value = profile.totalServed
	totalServedValue.Parent = folder

	folder.Parent = player
	leaderstatsByPlayer[player] = {
		folder = folder,
		yenValue = yenValue,
		totalServedValue = totalServedValue,
	}
end

local function findOwnedWorker(profile: PlayerProfile, workerId: string): OwnedWorkerData?
	for _, worker in profile.ownedWorkers do
		if worker.id == workerId then
			return worker
		end
	end
	return nil
end

function DataManager.GetStateSnapshot(player: Player): PlayerStateSnapshot?
	local profile = profiles[player]
	if not profile then
		return nil
	end

	local ownedCopy: { OwnedWorkerData } = {}
	for _, worker in profile.ownedWorkers do
		table.insert(ownedCopy, table.clone(worker))
	end

	return {
		yen = profile.yen,
		totalServed = profile.totalServed,
		ingredients = table.clone(profile.ingredients),
		ownedWorkers = ownedCopy,
		equippedWorkers = table.clone(profile.equippedWorkers),
		assignedPlotIndex = profile.assignedPlotIndex,
	}
end

function DataManager.SyncPlayerState(player: Player)
	local snapshot = DataManager.GetStateSnapshot(player)
	if snapshot then
		Remotes.PlayerStateSync:FireClient(player, snapshot)
	end
end

function DataManager.LoadPlayer(player: Player): PlayerProfile
	if profiles[player] then
		return profiles[player]
	end

	local rawData: any = nil
	local store = getDataStore()
	if store then
		local key = `Player_{player.UserId}`
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			rawData = result
		else
			warn(`[DataManager] GetAsync failed for {player.Name}: {result}`)
		end
	end

	local profile = reconcileProfile(rawData)
	profiles[player] = profile
	createLeaderstats(player, profile)
	DataManager.SyncPlayerState(player)

	return profile
end

function DataManager.SavePlayer(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end

	local store = getDataStore()
	if not store then
		return true
	end

	local key = `Player_{player.UserId}`
	local payload = serializeProfile(profile)
	local ok, err = pcall(function()
		store:SetAsync(key, payload)
	end)
	if not ok then
		warn(`[DataManager] SetAsync failed for {player.Name}: {err}`)
		return false
	end
	return true
end

function DataManager.UnloadPlayer(player: Player)
	DataManager.SavePlayer(player)
	profiles[player] = nil
	leaderstatsByPlayer[player] = nil
end

function DataManager.GetProfile(player: Player): PlayerProfile?
	return profiles[player]
end

function DataManager.SetAssignedPlot(player: Player, plotIndex: number?)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.assignedPlotIndex = plotIndex
	DataManager.SyncPlayerState(player)
end

function DataManager.AddYen(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or typeof(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return false
	end
	profile.yen += math.floor(amount)
	refreshLeaderstats(player, profile)
	DataManager.SyncPlayerState(player)
	return true
end

function DataManager.TrySpendYen(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or typeof(amount) ~= "number" or amount < 0 or amount ~= amount then
		return false
	end
	local cost = math.floor(amount)
	if profile.yen < cost then
		return false
	end
	profile.yen -= cost
	refreshLeaderstats(player, profile)
	DataManager.SyncPlayerState(player)
	return true
end

function DataManager.IncrementTotalServed(player: Player, amount: number?): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local delta = if typeof(amount) == "number" and amount > 0 then math.floor(amount) else 1
	profile.totalServed += delta
	refreshLeaderstats(player, profile)
	DataManager.SyncPlayerState(player)
	return profile.totalServed
end

function DataManager.GetStationSpeedMultiplier(player: Player, stationSlot: StationSlot): number
	local profile = profiles[player]
	if not profile then
		return 1.0
	end
	local workerId = profile.equippedWorkers[stationSlot]
	if not workerId then
		return 1.0
	end
	local worker = findOwnedWorker(profile, workerId)
	if not worker then
		return 1.0
	end
	return worker.workSpeedMultiplier
end

function DataManager.RestockSupplies(player: Player, ingredientId: unknown, boxCount: unknown): RemoteActionResult
	local profile = profiles[player]
	if not profile then
		return { success = false, message = "Player profile not loaded." }
	end

	if typeof(ingredientId) ~= "string" then
		return { success = false, message = "Invalid ingredient ID." }
	end

	local ingredient = GameConfig.Ingredients[ingredientId]
	if not ingredient then
		return { success = false, message = "Unknown ingredient." }
	end

	if typeof(boxCount) ~= "number" or boxCount ~= boxCount or boxCount == math.huge or boxCount == -math.huge then
		return { success = false, message = "Invalid box count." }
	end

	local boxes = math.floor(boxCount)
	if boxes ~= boxCount or boxes < 1 or boxes > GameConfig.MAX_RESTOCK_BOXES_PER_REQUEST then
		return {
			success = false,
			message = `Box count must be an integer between 1 and {GameConfig.MAX_RESTOCK_BOXES_PER_REQUEST}.`,
		}
	end

	local totalCost = ingredient.boxCost * boxes
	if profile.yen < totalCost then
		return { success = false, message = `Not enough Yen (need {totalCost} Yen).` }
	end

	local addedUnits = ingredient.bundleAmount * boxes
	profile.yen -= totalCost
	profile.ingredients[ingredientId] = (profile.ingredients[ingredientId] or 0) + addedUnits

	refreshLeaderstats(player, profile)
	DataManager.SyncPlayerState(player)

	return {
		success = true,
		message = `Restocked +{addedUnits} {ingredient.name}!`,
		data = {
			ingredientId = ingredientId,
			addedUnits = addedUnits,
			newStock = profile.ingredients[ingredientId],
			yen = profile.yen,
		},
	}
end

function DataManager.RollWorkerGacha(player: Player): RemoteActionResult
	local profile = profiles[player]
	if not profile then
		return { success = false, message = "Player profile not loaded." }
	end

	local rollCost = GameConfig.GACHA_ROLL_COST
	if profile.yen < rollCost then
		return { success = false, message = `Need {rollCost} Yen to summon a staff member.` }
	end

	profile.yen -= rollCost

	local archetype = GameConfig.RollStaffArchetype(rng)
	local newWorker: OwnedWorkerData = {
		id = HttpService:GenerateGUID(false),
		archetypeId = archetype.id,
		name = archetype.name,
		rarity = archetype.rarity,
		workSpeedMultiplier = archetype.workSpeedMultiplier,
	}

	table.insert(profile.ownedWorkers, newWorker)
	refreshLeaderstats(player, profile)
	DataManager.SyncPlayerState(player)

	return {
		success = true,
		message = `Summoned [{archetype.rarity}] {archetype.name} ({archetype.workSpeedMultiplier}x speed)!`,
		data = newWorker,
	}
end

function DataManager.AssignWorker(player: Player, stationSlot: unknown, workerId: unknown): RemoteActionResult
	local profile = profiles[player]
	if not profile then
		return { success = false, message = "Player profile not loaded." }
	end

	if typeof(stationSlot) ~= "string" or not GameConfig.StationSlotSet[stationSlot] then
		return { success = false, message = "Invalid station slot." }
	end
	local validSlot = stationSlot :: StationSlot

	if workerId == nil or workerId == "" then
		profile.equippedWorkers[validSlot] = nil
		DataManager.SyncPlayerState(player)
		return {
			success = true,
			message = `Cleared {validSlot} station.`,
			data = { slot = validSlot, workerId = nil },
		}
	end

	if typeof(workerId) ~= "string" then
		return { success = false, message = "Invalid worker ID." }
	end

	local worker = findOwnedWorker(profile, workerId)
	if not worker then
		return { success = false, message = "You do not own this staff member." }
	end

	-- Prevent the same worker instance from occupying multiple stations simultaneously.
	for _, slot in GameConfig.StationSlots do
		if profile.equippedWorkers[slot] == workerId then
			profile.equippedWorkers[slot] = nil
		end
	end

	profile.equippedWorkers[validSlot] = workerId
	DataManager.SyncPlayerState(player)

	return {
		success = true,
		message = `Assigned {worker.name} to {validSlot}!`,
		data = { slot = validSlot, workerId = workerId },
	}
end

function DataManager.BindRemotes()
	Remotes.RestockSupplies.OnServerInvoke = function(player: Player, ingredientId: unknown, boxCount: unknown): RemoteActionResult
		return DataManager.RestockSupplies(player, ingredientId, boxCount)
	end

	Remotes.RollWorkerGacha.OnServerInvoke = function(player: Player): RemoteActionResult
		return DataManager.RollWorkerGacha(player)
	end

	Remotes.AssignWorker.OnServerInvoke = function(player: Player, stationSlot: unknown, workerId: unknown): RemoteActionResult
		return DataManager.AssignWorker(player, stationSlot, workerId)
	end

	Remotes.PlayerStateSync.OnServerEvent:Connect(function(player: Player)
		DataManager.SyncPlayerState(player)
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataManager.SavePlayer(player)
		end
	end)
end

return DataManager
