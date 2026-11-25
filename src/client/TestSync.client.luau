--!strict

local Players = game:GetService("Players")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

if Players.LocalPlayer == nil then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end

local localPlayer: Player? = Players.LocalPlayer
if localPlayer then
	print("[Client] Local player loaded and connected!")
end
