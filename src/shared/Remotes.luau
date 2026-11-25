--!strict
-- Central RemoteEvents setup and typed accessors for "Steal a Luggage"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteSet = {
	Folder: Folder,
	AttemptStealLuggage: RemoteEvent,
	PlaceOnWorkbench: RemoteEvent,
	ClaimOpenedLuggage: RemoteEvent,
	SellAllLoot: RemoteEvent,
	BuyUpgrade: RemoteEvent,
	BuyConsumable: RemoteEvent,
	UnlockTerminal: RemoteEvent,
	UseDistraction: RemoteEvent,
	SyncPlayerState: RemoteEvent,
	ToggleCrouch: RemoteEvent,
}

local FOLDER_NAME = "GameRemotes"

local REQUIRED_EVENT_NAMES = {
	"AttemptStealLuggage",
	"PlaceOnWorkbench",
	"ClaimOpenedLuggage",
	"SellAllLoot",
	"BuyUpgrade",
	"BuyConsumable",
	"UnlockTerminal",
	"UseDistraction",
	"SyncPlayerState",
	"ToggleCrouch",
}

local Remotes = {}

local function buildRemoteSet(folder: Folder): RemoteSet
	return {
		Folder = folder,
		AttemptStealLuggage = folder:WaitForChild("AttemptStealLuggage") :: RemoteEvent,
		PlaceOnWorkbench = folder:WaitForChild("PlaceOnWorkbench") :: RemoteEvent,
		ClaimOpenedLuggage = folder:WaitForChild("ClaimOpenedLuggage") :: RemoteEvent,
		SellAllLoot = folder:WaitForChild("SellAllLoot") :: RemoteEvent,
		BuyUpgrade = folder:WaitForChild("BuyUpgrade") :: RemoteEvent,
		BuyConsumable = folder:WaitForChild("BuyConsumable") :: RemoteEvent,
		UnlockTerminal = folder:WaitForChild("UnlockTerminal") :: RemoteEvent,
		UseDistraction = folder:WaitForChild("UseDistraction") :: RemoteEvent,
		SyncPlayerState = folder:WaitForChild("SyncPlayerState") :: RemoteEvent,
		ToggleCrouch = folder:WaitForChild("ToggleCrouch") :: RemoteEvent,
	}
end

-- Called once by the server during startup
function Remotes.InitServer(): RemoteSet
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local folder: Folder
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, eventName in ipairs(REQUIRED_EVENT_NAMES) do
		if not folder:FindFirstChild(eventName) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = eventName
			remote.Parent = folder
		end
	end

	return buildRemoteSet(folder)
end

-- Called by the client; yields safely until server creates GameRemotes
function Remotes.WaitForClient(): RemoteSet
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	return buildRemoteSet(folder)
end

return Remotes
