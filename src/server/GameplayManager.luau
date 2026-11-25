--!strict
-- Orchestrates server RemoteEvent handlers, Workbench timers, Shop/Fence/Terminal transactions,
-- and periodic player state synchronization.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ServerFolder = script.Parent
local DataManager = require(ServerFolder:WaitForChild("DataManager"))
local WorldBuilder = require(ServerFolder:WaitForChild("WorldBuilder"))
local StealthManager = require(ServerFolder:WaitForChild("StealthManager"))

local GameplayManager = {}

local worldRefs: WorldBuilder.WorldRefs
local remotes: Remotes.RemoteSet

local function syncPlayer(player: Player, toast: string?, tone: string?, extra: { [string]: any }?)
	local snapshot = DataManager.BuildClientSnapshot(player)
	if not snapshot then
		return
	end
	remotes.SyncPlayerState:FireClient(player, {
		kind = if toast then "StateAndAlert" else "StateSync",
		snapshot = snapshot,
		toast = toast,
		tone = tone or "info",
		extra = extra,
	})
end

local function isNearWorldPoint(player: Player, targetPos: Vector3, maxDist: number): boolean
	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not hrp then
		return false
	end
	return (hrp.Position - targetPos).Magnitude <= maxDist
end

local function handleWorkbenchInteract(player: Player, slotIndex: number)
	local profile = DataManager.GetProfile(player)
	if not profile then
		return
	end
	local bench = worldRefs.Workbenches[slotIndex]
	if not bench then
		return
	end

	local slot = profile.WorkbenchSlots[slotIndex]
	if not slot then
		return
	end

	if slotIndex > profile.UpgradeLevels.WorkbenchCount then
		local nextBench = GameConfig.GetWorkbenchUpgrade(profile.UpgradeLevels.WorkbenchCount + 1)
		syncPlayer(
			player,
			string.format("Workbench #%d is locked! Buy %s (%s) in the Shop.", slotIndex, nextBench.name, GameConfig.FormatCash(nextBench.cost)),
			"warning"
		)
		return
	end

	if slot.bagUid == nil then
		-- Auto-place best crackable bag from Stash
		local ok, msg = DataManager.PlaceStashedOnWorkbench(player, nil, slotIndex)
		syncPlayer(player, msg, if ok then "success" else "warning")
	else
		local now = Workspace:GetServerTimeNow()
		if slot.isReady or (slot.endsAt and now >= slot.endsAt) then
			local ok, loot, msg = DataManager.ClaimWorkbenchSlot(player, slotIndex)
			if ok and loot and #loot > 0 then
				local names = {}
				local totalVal = 0
				for _, entry in ipairs(loot) do
					table.insert(names, string.format("[%s] %s", entry.tier, entry.name))
					totalVal += entry.value
				end
				syncPlayer(
					player,
					string.format("Cracked open: %s (Worth %s)! Sell at Vinnie's Fence!", table.concat(names, " + "), GameConfig.FormatCash(totalVal)),
					"success",
					{ claimedLoot = loot }
				)
			else
				syncPlayer(player, msg, "warning")
			end
		else
			local rem = math.ceil(math.max(0, (slot.endsAt or now) - now))
			syncPlayer(player, string.format("Cracking %s — %ds remaining!", slot.displayName or "Bag", rem), "info")
		end
	end
end

local function connectWorldPrompts()
	for _, bench in ipairs(worldRefs.Workbenches) do
		bench.prompt.Triggered:Connect(function(player: Player)
			handleWorkbenchInteract(player, bench.slotIndex)
		end)
	end

	worldRefs.FencePrompt.Triggered:Connect(function(player: Player)
		local ok, earned, count = DataManager.SellAllLoot(player)
		if ok then
			syncPlayer(player, string.format("Sold %d valuables to Vinnie's Fence for +%s!", count, GameConfig.FormatCash(earned)), "success", { soldAmount = earned })
		else
			syncPlayer(player, "No revealed loot to sell! Crack stolen bags on a Workbench first.", "warning")
		end
	end)

	worldRefs.ShopPrompt.Triggered:Connect(function(player: Player)
		remotes.SyncPlayerState:FireClient(player, {
			kind = "OpenModal",
			modal = "Shop",
			snapshot = DataManager.BuildClientSnapshot(player),
		})
	end)

	worldRefs.TerminalKioskPrompt.Triggered:Connect(function(player: Player)
		remotes.SyncPlayerState:FireClient(player, {
			kind = "OpenModal",
			modal = "Terminals",
			snapshot = DataManager.BuildClientSnapshot(player),
		})
	end)

	for terminalId, prompt in pairs(worldRefs.GatePrompts) do
		prompt.Triggered:Connect(function(player: Player)
			local profile = DataManager.GetProfile(player)
			if not profile then
				return
			end
			if profile.UnlockedTerminals[terminalId] then
				syncPlayer(player, string.format("%s is already unlocked — walk right through!", GameConfig.TERMINALS[terminalId].name), "info")
				return
			end
			local ok, msg = DataManager.UnlockTerminal(player, terminalId)
			syncPlayer(player, msg, if ok then "success" else "warning")
		end)
	end
end

local function connectRemotes()
	remotes.AttemptStealLuggage.OnServerEvent:Connect(function(player: Player, bagId: unknown)
		if typeof(bagId) ~= "string" or #bagId > 80 then
			return
		end
		StealthManager.AttemptSteal(player, bagId)
	end)

	remotes.PlaceOnWorkbench.OnServerEvent:Connect(function(player: Player, bagUid: unknown, slotIndex: unknown)
		if typeof(slotIndex) ~= "number" then
			return
		end
		local uidStr: string? = if typeof(bagUid) == "string" and #bagUid <= 80 then bagUid else nil
		local idx = math.floor(slotIndex)
		local bench = worldRefs.Workbenches[idx]
		if not bench then
			return
		end
		-- Validate player is inside Hideout or near bench
		local character = player.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if not hrp or not GameConfig.IsPointInHideout(hrp.Position) then
			syncPlayer(player, "Return to your Hideout to use Workbenches!", "warning")
			return
		end
		local ok, msg = DataManager.PlaceStashedOnWorkbench(player, uidStr, idx)
		syncPlayer(player, msg, if ok then "success" else "warning")
	end)

	remotes.ClaimOpenedLuggage.OnServerEvent:Connect(function(player: Player, slotIndex: unknown)
		if typeof(slotIndex) ~= "number" then
			return
		end
		local idx = math.floor(slotIndex)
		local character = player.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if not hrp or not GameConfig.IsPointInHideout(hrp.Position) then
			syncPlayer(player, "Return to your Hideout to claim cracked loot!", "warning")
			return
		end
		local ok, loot, msg = DataManager.ClaimWorkbenchSlot(player, idx)
		if ok and loot and #loot > 0 then
			local names = {}
			local totalVal = 0
			for _, entry in ipairs(loot) do
				table.insert(names, string.format("[%s] %s", entry.tier, entry.name))
				totalVal += entry.value
			end
			syncPlayer(player, string.format("Claimed: %s (+%s value)!", table.concat(names, " + "), GameConfig.FormatCash(totalVal)), "success", { claimedLoot = loot })
		else
			syncPlayer(player, msg, "warning")
		end
	end)

	remotes.SellAllLoot.OnServerEvent:Connect(function(player: Player)
		local fenceDesk = worldRefs.FencePrompt.Parent
		if fenceDesk and fenceDesk:IsA("BasePart") then
			if not isNearWorldPoint(player, fenceDesk.Position, 20) then
				syncPlayer(player, "Walk up to Vinnie's Fence Counter in the Hideout to sell!", "warning")
				return
			end
		end
		local ok, earned, count = DataManager.SellAllLoot(player)
		if ok then
			syncPlayer(player, string.format("Sold %d items for +%s!", count, GameConfig.FormatCash(earned)), "success", { soldAmount = earned })
		else
			syncPlayer(player, "You have no revealed valuables to sell yet!", "warning")
		end
	end)

	remotes.BuyUpgrade.OnServerEvent:Connect(function(player: Player, category: unknown)
		if typeof(category) ~= "string" then
			return
		end
		local ok, msg = DataManager.BuyUpgrade(player, category)
		if ok and category == "Sneakers" then
			StealthManager.ApplyMovementStats(player)
		end
		syncPlayer(player, msg, if ok then "success" else "warning")
	end)

	remotes.BuyConsumable.OnServerEvent:Connect(function(player: Player, itemId: unknown)
		if typeof(itemId) ~= "string" then
			return
		end
		local ok, msg = DataManager.BuyConsumable(player, itemId)
		syncPlayer(player, msg, if ok then "success" else "warning")
	end)

	remotes.UnlockTerminal.OnServerEvent:Connect(function(player: Player, terminalId: unknown)
		if typeof(terminalId) ~= "string" then
			return
		end
		local ok, msg = DataManager.UnlockTerminal(player, terminalId)
		syncPlayer(player, msg, if ok then "success" else "warning")
	end)

	remotes.UseDistraction.OnServerEvent:Connect(function(player: Player, itemId: unknown)
		if typeof(itemId) ~= "string" then
			return
		end
		StealthManager.UseDistraction(player, itemId)
	end)

	remotes.ToggleCrouch.OnServerEvent:Connect(function(player: Player, wantsCrouch: unknown)
		if typeof(wantsCrouch) ~= "boolean" then
			return
		end
		StealthManager.SetCrouch(player, wantsCrouch)
	end)
end

function GameplayManager.Start()
	remotes = Remotes.InitServer()
	worldRefs = WorldBuilder.Build()

	StealthManager.Init(worldRefs, remotes)
	connectWorldPrompts()
	connectRemotes()

	local function onPlayerJoin(player: Player)
		DataManager.LoadProfile(player)
		StealthManager.OnPlayerAdded(player)
		task.defer(function()
			syncPlayer(player, "Welcome to Steal a Luggage! Match bags to owners, watch their cones, and swipe when they look away!", "info")
		end)
	end

	Players.PlayerAdded:Connect(onPlayerJoin)
	for _, existingPlayer in ipairs(Players:GetPlayers()) do
		onPlayerJoin(existingPlayer)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		StealthManager.OnPlayerRemoving(player)
		DataManager.UnloadProfile(player)
	end)

	game:BindToClose(function()
		DataManager.SaveAll()
	end)

	local timerAcc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		StealthManager.Step(dt)

		timerAcc += dt
		if timerAcc >= 0.5 then
			timerAcc = 0
			local completedPlayers = DataManager.UpdateWorkbenchTimers(Workspace:GetServerTimeNow())
			for _, player in ipairs(completedPlayers) do
				syncPlayer(player, "A Workbench finished cracking luggage! Head back to claim your loot!", "success")
			end
		end
	end)
end

return GameplayManager
