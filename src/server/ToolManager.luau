--!strict
-- Server-authoritative manager that synchronizes stackable consumable Tools
-- into each player's Backpack (and cleans up or updates names dynamically).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerFolder = script.Parent
local DataManager = require(ServerFolder:WaitForChild("DataManager"))

local ToolManager = {}

local function formatToolName(name: string, count: number): string
	return string.format("%s (x%d)", name, count)
end

local function findConsumableTool(player: Player, cid: GameConfig.ConsumableId): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("ConsumableId") == cid then
				return child
			end
		end
	end

	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("ConsumableId") == cid then
				return child
			end
		end
	end

	return nil
end

local function buildConsumableTool(def: GameConfig.ConsumableDef, count: number): Tool
	local tool = Instance.new("Tool")
	tool.Name = formatToolName(def.name, count)
	tool.ToolTip = string.format("[%s] %s", def.rarity, def.description)
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("ConsumableId", def.id)
	tool:SetAttribute("Rarity", def.rarity)
	tool:SetAttribute("StackCount", count)
	return tool
end

function ToolManager.UnequipConsumables(player: Player): ()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("ConsumableId") ~= nil then
				child.Parent = backpack
			end
		end
	end
end

function ToolManager.SyncTools(player: Player): ()
	if not player.Parent then
		return
	end
	local profile = DataManager.GetProfile(player)
	if not profile then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or (player:WaitForChild("Backpack", 2) :: Backpack?)
	if not backpack or not player.Parent then
		return
	end

	for _, cid in ipairs(GameConfig.CONSUMABLE_ORDER) do
		local def = GameConfig.CONSUMABLES[cid]
		local count = math.max(0, math.floor(profile.Consumables[cid] or 0))
		local existing = findConsumableTool(player, cid)

		if count <= 0 then
			if existing then
				existing:Destroy()
			end
		elseif existing then
			existing.Name = formatToolName(def.name, count)
			existing.ToolTip = string.format("[%s] %s", def.rarity, def.description)
			existing:SetAttribute("Rarity", def.rarity)
			existing:SetAttribute("StackCount", count)
			if existing.Parent ~= backpack then
				existing.Parent = backpack
			end
		else
			local created = buildConsumableTool(def, count)
			created.Parent = backpack
		end
	end
end

return ToolManager
