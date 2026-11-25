--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local _Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.DataManager)
local TrafficManager = require(script.TrafficManager)
local WorldBuilder = require(script.WorldBuilder)

local function onPlayerAdded(player: Player)
	DataManager.LoadPlayer(player)

	local plot = WorldBuilder.ClaimPlot(player)
	if plot then
		DataManager.SetAssignedPlot(player, plot.index)
	end

	player.CharacterAdded:Connect(function(character: Model)
		local playerPlot = WorldBuilder.GetPlayerPlot(player)
		if playerPlot and playerPlot.spawnLocation then
			-- Wait one heartbeat so Roblox finishes placing character joints before pivoting if needed.
			task.defer(function()
				if character.Parent and playerPlot.spawnLocation then
					character:PivotTo(playerPlot.spawnLocation.CFrame + Vector3.new(0, 3.5, 0))
				end
			end)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	WorldBuilder.ReleasePlot(player)
	DataManager.UnloadPlayer(player)
end

WorldBuilder.Init()
TrafficManager.Init()
DataManager.BindRemotes()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
