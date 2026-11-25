--!strict
-- Central RemoteEvents and RemoteFunctions registry in ReplicatedStorage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteRegistry = {
	Folder: Folder,
	ExcavateNode: RemoteFunction,
	StartCleaning: RemoteFunction,
	ClaimCleaned: RemoteFunction,
	SellAllRelics: RemoteFunction,
	BuyUpgrade: RemoteFunction,
	BuyShopItem: RemoteFunction,
	HatchEgg: RemoteFunction,
	EquipPets: RemoteFunction,
	ToggleFlashlight: RemoteEvent,
	SyncState: RemoteEvent,
}

local FOLDER_NAME = "GameRemotes"

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	local awaited = parent:WaitForChild(name)
	return awaited :: RemoteFunction
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	local awaited = parent:WaitForChild(name)
	return awaited :: RemoteEvent
end

local function resolveFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	local awaited = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return awaited :: Folder
end

local folder = resolveFolder()

local Remotes: RemoteRegistry = {
	Folder = folder,
	ExcavateNode = ensureRemoteFunction(folder, "ExcavateNode"),
	StartCleaning = ensureRemoteFunction(folder, "StartCleaning"),
	ClaimCleaned = ensureRemoteFunction(folder, "ClaimCleaned"),
	SellAllRelics = ensureRemoteFunction(folder, "SellAllRelics"),
	BuyUpgrade = ensureRemoteFunction(folder, "BuyUpgrade"),
	BuyShopItem = ensureRemoteFunction(folder, "BuyShopItem"),
	HatchEgg = ensureRemoteFunction(folder, "HatchEgg"),
	EquipPets = ensureRemoteFunction(folder, "EquipPets"),
	ToggleFlashlight = ensureRemoteEvent(folder, "ToggleFlashlight"),
	SyncState = ensureRemoteEvent(folder, "SyncState"),
}

return Remotes
