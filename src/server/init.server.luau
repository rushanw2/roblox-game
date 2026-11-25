--!strict
-- Thin server entry point wiring world generation, diving physics, gameplay systems & player lifecycle

local Players = game:GetService("Players")

local DataManager = require(script:WaitForChild("DataManager"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local DivingManager = require(script:WaitForChild("DivingManager"))
local GameplayManager = require(script:WaitForChild("GameplayManager"))

WorldBuilder.Build()
DataManager.Init()
DivingManager.Init()
GameplayManager.Init()

Players.PlayerAdded:Connect(function(player: Player)
	GameplayManager.OnPlayerJoined(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	GameplayManager.OnPlayerLeaving(player)
end)

for _, existingPlayer in ipairs(Players:GetPlayers()) do
	GameplayManager.OnPlayerJoined(existingPlayer)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager.SaveProfile(player)
	end
end)
