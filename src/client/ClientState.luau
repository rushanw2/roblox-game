--!strict
-- Centralized reactive client state container synced from server Remotes.SyncState

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

export type ClientRawRelic = {
	uid: string,
	itemId: string,
	foundAt: number,
}

export type ClientCleanedRelic = {
	uid: string,
	itemId: string,
	cleanedFromId: string?,
	obtainedAt: number,
}

export type ClientOwnedPet = {
	uid: string,
	speciesId: string,
	rarity: GameConfig.Rarity,
	hatchedAt: number,
}

export type ClientCleaningSlot = {
	slotIndex: number,
	rawUid: string,
	rawItemId: string,
	startedAt: number,
	endsAt: number,
	duration: number,
}

export type ClientProfile = {
	Coins: number,
	RelicsFound: number,
	RawRelics: { ClientRawRelic },
	CleanedRelics: { ClientCleanedRelic },
	OwnedPets: { ClientOwnedPet },
	EquippedPetIds: { string },
	GearLevels: {
		Oxygen: number,
		SwimSpeed: number,
		LightStrength: number,
	},
	ActiveBuffs: { [string]: number },
	CleaningSlots: { [string]: ClientCleaningSlot },
}

export type ClientDivingState = {
	oxygen: number,
	maxOxygen: number,
	depth: number,
	zoneId: GameConfig.ZoneId?,
	isUnderwater: boolean,
	flashlightOn: boolean,
	isBlackedOut: boolean,
}

export type ClientExcavationState = {
	nodeId: string,
	startedAt: number,
	endsAt: number,
	duration: number,
}

export type ClientSnapshot = {
	profile: ClientProfile,
	diving: ClientDivingState,
	activeExcavation: ClientExcavationState?,
	serverNow: number,
}

export type WindowName = "None" | "Inventory" | "Shop" | "Cleaning" | "Appraisal" | "Eggs"

local ClientState = {}

local currentState: ClientSnapshot = {
	profile = {
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
	},
	diving = {
		oxygen = 100,
		maxOxygen = 100,
		depth = 0,
		zoneId = nil,
		isUnderwater = false,
		flashlightOn = false,
		isBlackedOut = false,
	},
	activeExcavation = nil,
	serverNow = Workspace:GetServerTimeNow(),
}

local serverClockOffset = 0
local activeWindow: WindowName = "None"
local stateListeners: { (state: ClientSnapshot) -> () } = {}
local eventListeners: { (eventPayload: { [string]: any }) -> () } = {}
local windowListeners: { (windowName: WindowName) -> () } = {}
local initialized = false

function ClientState.GetState(): ClientSnapshot
	return currentState
end

function ClientState.GetServerTime(): number
	return Workspace:GetServerTimeNow() + serverClockOffset
end

function ClientState.GetActiveWindow(): WindowName
	return activeWindow
end

function ClientState.SetActiveWindow(windowName: WindowName): ()
	if activeWindow == windowName then
		activeWindow = "None"
	else
		activeWindow = windowName
	end
	for _, cb in ipairs(windowListeners) do
		task.spawn(cb, activeWindow)
	end
end

function ClientState.OpenWindow(windowName: WindowName): ()
	activeWindow = windowName
	for _, cb in ipairs(windowListeners) do
		task.spawn(cb, activeWindow)
	end
end

function ClientState.CloseWindows(): ()
	if activeWindow == "None" then
		return
	end
	activeWindow = "None"
	for _, cb in ipairs(windowListeners) do
		task.spawn(cb, activeWindow)
	end
end

function ClientState.GetEquippedPetSpeciesIds(): { string }
	local byId: { [string]: ClientOwnedPet } = {}
	for _, pet in ipairs(currentState.profile.OwnedPets) do
		byId[pet.uid] = pet
	end

	local result: { string } = {}
	for _, uid in ipairs(currentState.profile.EquippedPetIds) do
		local entry = byId[uid]
		if entry then
			table.insert(result, entry.speciesId)
		end
	end
	return result
end

function ClientState.GetTotalPetPassives(): GameConfig.PetPassives
	return GameConfig.CalculatePetPassives(ClientState.GetEquippedPetSpeciesIds())
end

function ClientState.GetBuffRemaining(buffId: string): number
	local expiresAt = currentState.profile.ActiveBuffs[buffId]
	if expiresAt == nil then
		return 0
	end
	return math.max(0, expiresAt - ClientState.GetServerTime())
end

function ClientState.Subscribe(callback: (state: ClientSnapshot) -> ()): () -> ()
	table.insert(stateListeners, callback)
	task.spawn(callback, currentState)
	return function()
		local idx = table.find(stateListeners, callback)
		if idx then
			table.remove(stateListeners, idx)
		end
	end
end

function ClientState.SubscribeEvents(callback: (eventPayload: { [string]: any }) -> ()): () -> ()
	table.insert(eventListeners, callback)
	return function()
		local idx = table.find(eventListeners, callback)
		if idx then
			table.remove(eventListeners, idx)
		end
	end
end

function ClientState.SubscribeWindow(callback: (windowName: WindowName) -> ()): () -> ()
	table.insert(windowListeners, callback)
	task.spawn(callback, activeWindow)
	return function()
		local idx = table.find(windowListeners, callback)
		if idx then
			table.remove(windowListeners, idx)
		end
	end
end

function ClientState.EmitLocalToast(text: string, kind: string?): ()
	local payload: { [string]: any } = {
		type = "Toast",
		text = text,
		kind = kind or "Info",
	}
	for _, cb in ipairs(eventListeners) do
		task.spawn(cb, payload)
	end
end

function ClientState.EmitEvent(eventPayload: { [string]: any }): ()
	for _, cb in ipairs(eventListeners) do
		task.spawn(cb, eventPayload)
	end
end

function ClientState.Init(): ()
	if initialized then
		return
	end
	initialized = true

	Remotes.SyncState.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		if typeof(payload.serverNow) == "number" then
			serverClockOffset = payload.serverNow - Workspace:GetServerTimeNow()
		end

		if typeof(payload.profile) == "table" and typeof(payload.diving) == "table" then
			currentState = {
				profile = payload.profile,
				diving = payload.diving,
				activeExcavation = payload.activeExcavation,
				serverNow = payload.serverNow or Workspace:GetServerTimeNow(),
			}
		end

		for _, cb in ipairs(stateListeners) do
			task.spawn(cb, currentState)
		end

		if typeof(payload.event) == "table" then
			for _, cb in ipairs(eventListeners) do
				task.spawn(cb, payload.event)
			end
		end
	end)

	Remotes.SyncState:FireServer()
end

return ClientState
