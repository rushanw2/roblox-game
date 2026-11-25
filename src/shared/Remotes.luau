--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.GameConfig)

export type OwnedWorkerData = {
	id: string,
	archetypeId: string,
	name: string,
	rarity: GameConfig.StaffRarity,
	workSpeedMultiplier: number,
}

export type PlayerStateSnapshot = {
	yen: number,
	totalServed: number,
	ingredients: { [string]: number },
	ownedWorkers: { OwnedWorkerData },
	equippedWorkers: { [GameConfig.StationSlot]: string? },
	assignedPlotIndex: number?,
}

export type RemoteActionResult = {
	success: boolean,
	message: string,
	data: any?,
}

export type RemotesTable = {
	Folder: Folder,
	RestockSupplies: RemoteFunction,
	RollWorkerGacha: RemoteFunction,
	AssignWorker: RemoteFunction,
	PlayerStateSync: RemoteEvent,
}

local FOLDER_NAME = "Remotes"

local function ensureRemoteFunction(parent: Folder, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemoteEvent(parent: Folder, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getRemotesFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	else
		return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
end

local folder = getRemotesFolder()

local Remotes: RemotesTable
if RunService:IsServer() then
	Remotes = {
		Folder = folder,
		RestockSupplies = ensureRemoteFunction(folder, "RestockSupplies"),
		RollWorkerGacha = ensureRemoteFunction(folder, "RollWorkerGacha"),
		AssignWorker = ensureRemoteFunction(folder, "AssignWorker"),
		PlayerStateSync = ensureRemoteEvent(folder, "PlayerStateSync"),
	}
else
	Remotes = {
		Folder = folder,
		RestockSupplies = folder:WaitForChild("RestockSupplies") :: RemoteFunction,
		RollWorkerGacha = folder:WaitForChild("RollWorkerGacha") :: RemoteFunction,
		AssignWorker = folder:WaitForChild("AssignWorker") :: RemoteFunction,
		PlayerStateSync = folder:WaitForChild("PlayerStateSync") :: RemoteEvent,
	}
end

return Remotes
