--!strict
-- Client-side replicated state store, event dispatchers, gate barrier updates, and remote wrappers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

export type RarityTier = GameConfig.RarityTier
export type TerminalId = GameConfig.TerminalId
export type ConsumableId = GameConfig.ConsumableId

export type ClientCarriedBag = {
	uid: string,
	worldBagId: string,
	archetypeId: string,
	tier: RarityTier,
	displayName: string,
	sourceTerminal: TerminalId,
	stolenAt: number,
}

export type ClientStashedBag = {
	uid: string,
	archetypeId: string,
	tier: RarityTier,
	displayName: string,
	sourceTerminal: TerminalId,
}

export type ClientLootEntry = {
	uid: string,
	itemId: string,
	name: string,
	tier: RarityTier,
	value: number,
	iconText: string,
}

export type ClientWorkbenchSlot = {
	slotIndex: number,
	bagUid: string?,
	archetypeId: string?,
	tier: RarityTier?,
	displayName: string?,
	startedAt: number?,
	duration: number?,
	endsAt: number?,
	isReady: boolean,
	pendingLoot: { ClientLootEntry }?,
}

export type ClientSnapshot = {
	Cash: number,
	TotalStolen: number,
	CarriedLuggage: ClientCarriedBag?,
	StashedLuggage: { ClientStashedBag },
	WorkbenchSlots: { ClientWorkbenchSlot },
	RevealedLoot: { ClientLootEntry },
	UnlockedTerminals: { [TerminalId]: boolean },
	UpgradeLevels: {
		Tool: number,
		Sneakers: number,
		StealthCoat: number,
		WorkbenchCount: number,
	},
	Consumables: { [ConsumableId]: number },
	ServerNow: number,
}

local ClientState = {}

local remotes: Remotes.RemoteSet
local currentSnapshot: ClientSnapshot? = nil
local isCrouching = false
local selectedGadget: ConsumableId = "SmokeBomb"
local gadgetCooldownEnds: { [ConsumableId]: number } = {
	SmokeBomb = 0,
	DistractionAlarm = 0,
}

local stateCallbacks: { (ClientSnapshot) -> () } = {}
local toastCallbacks: { (string, string, { [string]: any }?) -> () } = {}
local modalCallbacks: { (string) -> () } = {}
local crouchCallbacks: { (boolean) -> () } = {}

local function updateTerminalBarriers(snapshot: ClientSnapshot)
	local airport = Workspace:FindFirstChild("AirportWorld")
	if not airport then
		return
	end
	local windows = airport:FindFirstChild("Windows")
	if not windows then
		return
	end

	for _, terminalId in ipairs(GameConfig.TERMINAL_ORDER) do
		if terminalId == "Domestic" then
			continue
		end
		local barrier = windows:FindFirstChild(terminalId .. "_Barrier")
		if barrier and barrier:IsA("BasePart") then
			local unlocked = snapshot.UnlockedTerminals[terminalId] == true
			barrier.CanCollide = not unlocked
			if unlocked then
				barrier.Color = Color3.fromRGB(72, 255, 162)
				barrier.Transparency = 0.88
			else
				barrier.Color = GameConfig.TERMINALS[terminalId].accentColor
				barrier.Transparency = 0.45
			end
		end
	end
end

function ClientState.Init()
	remotes = Remotes.WaitForClient()

	remotes.SyncPlayerState.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		if typeof(payload.snapshot) == "table" then
			currentSnapshot = payload.snapshot :: ClientSnapshot
			updateTerminalBarriers(currentSnapshot :: ClientSnapshot)
			for _, cb in ipairs(stateCallbacks) do
				cb(currentSnapshot :: ClientSnapshot)
			end
		end

		if typeof(payload.toast) == "string" then
			local tone = if typeof(payload.tone) == "string" then payload.tone else "info"
			for _, cb in ipairs(toastCallbacks) do
				cb(payload.toast, tone, payload.extra)
			end
		end

		if payload.kind == "OpenModal" and typeof(payload.modal) == "string" then
			for _, cb in ipairs(modalCallbacks) do
				cb(payload.modal)
			end
		end
	end)

	-- Re-apply barrier states whenever AirportWorld replicates on join
	task.spawn(function()
		Workspace:WaitForChild("AirportWorld", 15)
		if currentSnapshot then
			updateTerminalBarriers(currentSnapshot)
		end
	end)

	-- Reset local crouch visual when server clears attribute (e.g., busted or respawn)
	Players.LocalPlayer:GetAttributeChangedSignal("IsCrouching"):Connect(function()
		local attr = Players.LocalPlayer:GetAttribute("IsCrouching") == true
		if attr ~= isCrouching then
			isCrouching = attr
			for _, cb in ipairs(crouchCallbacks) do
				cb(isCrouching)
			end
		end
	end)
end

function ClientState.GetSnapshot(): ClientSnapshot?
	return currentSnapshot
end

function ClientState.IsCrouching(): boolean
	return isCrouching
end

function ClientState.GetSelectedGadget(): ConsumableId
	return selectedGadget
end

function ClientState.SetSelectedGadget(cid: ConsumableId)
	selectedGadget = cid
end

function ClientState.GetGadgetCooldownRemaining(cid: ConsumableId): number
	return math.max(0, (gadgetCooldownEnds[cid] or 0) - os.clock())
end

function ClientState.OnStateChanged(cb: (ClientSnapshot) -> ())
	table.insert(stateCallbacks, cb)
	if currentSnapshot then
		cb(currentSnapshot)
	end
end

function ClientState.OnToast(cb: (string, string, { [string]: any }?) -> ())
	table.insert(toastCallbacks, cb)
end

function ClientState.OnOpenModal(cb: (string) -> ())
	table.insert(modalCallbacks, cb)
end

function ClientState.OnCrouchChanged(cb: (boolean) -> ())
	table.insert(crouchCallbacks, cb)
end

function ClientState.ToggleCrouch()
	isCrouching = not isCrouching
	remotes.ToggleCrouch:FireServer(isCrouching)
	for _, cb in ipairs(crouchCallbacks) do
		cb(isCrouching)
	end
end

function ClientState.UseGadget(itemId: ConsumableId?)
	local chosen = itemId or selectedGadget
	local snap = currentSnapshot
	if snap then
		local count = snap.Consumables[chosen] or 0
		if count <= 0 and itemId == nil then
			-- Auto-fallback to the other gadget if the selected one is empty
			local fallback: ConsumableId = if chosen == "SmokeBomb" then "DistractionAlarm" else "SmokeBomb"
			if (snap.Consumables[fallback] or 0) > 0 then
				chosen = fallback
			end
		end
	end

	local def = GameConfig.CONSUMABLES[chosen]
	if ClientState.GetGadgetCooldownRemaining(chosen) <= 0 and snap and (snap.Consumables[chosen] or 0) > 0 then
		gadgetCooldownEnds[chosen] = os.clock() + def.cooldown
	end
	remotes.UseDistraction:FireServer(chosen)
end

function ClientState.PlaceOnWorkbench(bagUid: string?, slotIndex: number)
	remotes.PlaceOnWorkbench:FireServer(bagUid or "", slotIndex)
end

function ClientState.ClaimOpenedLuggage(slotIndex: number)
	remotes.ClaimOpenedLuggage:FireServer(slotIndex)
end

function ClientState.SellAllLoot()
	remotes.SellAllLoot:FireServer()
end

function ClientState.BuyUpgrade(category: string)
	remotes.BuyUpgrade:FireServer(category)
end

function ClientState.BuyConsumable(itemId: ConsumableId)
	remotes.BuyConsumable:FireServer(itemId)
end

function ClientState.UnlockTerminal(terminalId: TerminalId)
	remotes.UnlockTerminal:FireServer(terminalId)
end

return ClientState
