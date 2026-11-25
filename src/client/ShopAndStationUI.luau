--!strict
-- Interactive Dive Gear & Buff Shop, Cleaning Station Panel, Appraisal Counter, Egg Shrine & Hatching Reveal Popup

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientFolder = script.Parent
local ClientState = require(ClientFolder:WaitForChild("ClientState"))

local ShopAndStationUI = {}

local mainGui: ScreenGui
local modalFrame: Frame
local modalTitle: TextLabel
local modalStroke: UIStroke
local modalBody: ScrollingFrame

-- Hatching Reveal Popup elements
local hatchOverlay: Frame
local eggStage: Frame
local eggShellTop: Frame
local eggShellRing: Frame
local eggNameStageLbl: TextLabel
local revealStage: Frame
local revealRarityLbl: TextLabel
local revealNameLbl: TextLabel
local revealTitleLbl: TextLabel
local revealStatsLbl: TextLabel
local revealAutoLbl: TextLabel
local revealPortrait: Frame
local revealHair: Frame
local revealFace: Frame
local revealEyeL: Frame
local revealEyeR: Frame
local revealHaloBadge: Frame

local currentModal: ClientState.WindowName = "None"
local cleaningSlotProgressBars: { [number]: { barFill: Frame, statusLbl: TextLabel, btn: TextButton } } = {}

local function addCorner(inst: GuiObject, radiusPx: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radiusPx)
	c.Parent = inst
end

local function addStroke(inst: GuiObject, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = inst
	return s
end

local function clearModalBody(): ()
	cleaningSlotProgressBars = {}
	for _, child in ipairs(modalBody:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function createSectionHeader(text: string, order: number, color: Color3): ()
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -12, 0, 28)
	lbl.LayoutOrder = order
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = modalBody
end

local function renderShopModal(state: ClientState.ClientSnapshot): ()
	modalTitle.Text = "DIVE GEAR & CONSUMABLE BUFF SHOP"
	modalStroke.Color = Color3.fromRGB(112, 248, 178)

	local order = 1
	createSectionHeader("GEAR UPGRADES", order, Color3.fromRGB(122, 232, 255))
	order += 1

	local upgradeSpecs: { { id: GameConfig.UpgradeId, label: string, color: Color3 } } = {
		{ id = "Oxygen", label = "Oxygen Tank", color = Color3.fromRGB(78, 224, 255) },
		{ id = "SwimSpeed", label = "Swim Propulsion Fins", color = Color3.fromRGB(112, 248, 178) },
		{ id = "LightStrength", label = "Diving Flashlight", color = Color3.fromRGB(255, 224, 108) },
	}

	for _, spec in ipairs(upgradeSpecs) do
		local lv = state.profile.GearLevels[spec.id]
		local maxLv = GameConfig.GetMaxGearLevel(spec.id)
		local isMax = lv >= maxLv

		local curDesc = ""
		local nextDesc = "MAX LEVEL"
		local cost = 0

		if spec.id == "Oxygen" then
			local curT = GameConfig.GetOxygenTier(lv)
			curDesc = string.format("%s (%d O2)", curT.name, curT.maxOxygen)
			if not isMax then
				local nextT = GameConfig.GetOxygenTier(lv + 1)
				nextDesc = string.format("Next: %s (%d O2)", nextT.name, nextT.maxOxygen)
				cost = nextT.cost
			end
		elseif spec.id == "SwimSpeed" then
			local curT = GameConfig.GetSwimSpeedTier(lv)
			curDesc = string.format("%s (%d Speed)", curT.name, curT.swimSpeed)
			if not isMax then
				local nextT = GameConfig.GetSwimSpeedTier(lv + 1)
				nextDesc = string.format("Next: %s (%d Speed)", nextT.name, nextT.swimSpeed)
				cost = nextT.cost
			end
		else
			local curT = GameConfig.GetLightStrengthTier(lv)
			curDesc = string.format("%s (Range %d)", curT.name, curT.range)
			if not isMax then
				local nextT = GameConfig.GetLightStrengthTier(lv + 1)
				nextDesc = string.format("Next: %s (Range %d)", nextT.name, nextT.range)
				cost = nextT.cost
			end
		end

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -10, 0, 74)
		card.LayoutOrder = order
		order += 1
		card.BackgroundColor3 = Color3.fromRGB(24, 34, 60)
		card.Parent = modalBody
		addCorner(card, 10)
		addStroke(card, spec.color, 1.5)

		local title = Instance.new("TextLabel")
		title.Position = UDim2.new(0, 14, 0, 8)
		title.Size = UDim2.new(0.65, 0, 0, 26)
		title.BackgroundTransparency = 1
		title.Text = string.format("%s (Lv.%d / %d) — %s", spec.label, lv, maxLv, curDesc)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = spec.color
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = card

		local sub = Instance.new("TextLabel")
		sub.Position = UDim2.new(0, 14, 0, 38)
		sub.Size = UDim2.new(0.65, 0, 0, 24)
		sub.BackgroundTransparency = 1
		sub.Text = nextDesc
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Color3.fromRGB(196, 214, 240)
		sub.TextScaled = true
		sub.Font = Enum.Font.GothamMedium
		sub.Parent = card

		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -12, 0.5, 0)
		btn.Size = UDim2.fromOffset(142, 42)
		btn.BackgroundColor3 = if isMax
			then Color3.fromRGB(70, 82, 102)
			elseif state.profile.Coins >= cost then Color3.fromRGB(64, 192, 128)
			else Color3.fromRGB(132, 68, 82)
		btn.Text = if isMax then "MAXED" else (GameConfig.FormatNumber(cost) .. " Coins")
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = card
		addCorner(btn, 8)

		if not isMax then
			btn.MouseButton1Click:Connect(function()
				local ok, res = pcall(function(): any
					return Remotes.BuyUpgrade:InvokeServer(spec.id)
				end)
				if ok and typeof(res) == "table" and not res.success then
					ClientState.EmitLocalToast(res.message or "Upgrade failed.", "Warn")
				end
			end)
		end
	end

	createSectionHeader("CONSUMABLES & TIMED BUFFS", order, Color3.fromRGB(255, 212, 102))
	order += 1

	for _, itemId in ipairs(GameConfig.SHOP_ITEM_ORDER) do
		local item = GameConfig.SHOP_ITEMS[itemId]
		local rem = ClientState.GetBuffRemaining(itemId)

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -10, 0, 74)
		card.LayoutOrder = order
		order += 1
		card.BackgroundColor3 = Color3.fromRGB(24, 34, 60)
		card.Parent = modalBody
		addCorner(card, 10)
		addStroke(card, item.accentColor, 1.5)

		local title = Instance.new("TextLabel")
		title.Position = UDim2.new(0, 14, 0, 8)
		title.Size = UDim2.new(0.66, 0, 0, 26)
		title.BackgroundTransparency = 1
		title.Text = if rem > 0
			then string.format("%s (Active: %ds)", item.name, math.ceil(rem))
			else item.name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = item.accentColor
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = card

		local sub = Instance.new("TextLabel")
		sub.Position = UDim2.new(0, 14, 0, 38)
		sub.Size = UDim2.new(0.66, 0, 0, 24)
		sub.BackgroundTransparency = 1
		sub.Text = item.description
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Color3.fromRGB(196, 214, 240)
		sub.TextScaled = true
		sub.Font = Enum.Font.GothamMedium
		sub.Parent = card

		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -12, 0.5, 0)
		btn.Size = UDim2.fromOffset(142, 42)
		btn.BackgroundColor3 = if state.profile.Coins >= item.cost
			then Color3.fromRGB(64, 152, 224)
			else Color3.fromRGB(132, 68, 82)
		btn.Text = GameConfig.FormatNumber(item.cost) .. " Coins"
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = card
		addCorner(btn, 8)

		btn.MouseButton1Click:Connect(function()
			local ok, res = pcall(function(): any
				return Remotes.BuyShopItem:InvokeServer(item.id)
			end)
			if ok and typeof(res) == "table" and not res.success then
				ClientState.EmitLocalToast(res.message or "Purchase failed.", "Warn")
			end
		end)
	end
end

local function renderCleaningModal(state: ClientState.ClientSnapshot): ()
	modalTitle.Text = "RELIC CLEANING STATION (3 WASHBASINS)"
	modalStroke.Color = Color3.fromRGB(108, 224, 255)

	local order = 1
	createSectionHeader("ACTIVE WASHBASIN SLOTS", order, Color3.fromRGB(118, 232, 255))
	order += 1

	local now = ClientState.GetServerTime()
	for slotIndex = 1, GameConfig.CLEANING_SLOT_COUNT do
		local slot = state.profile.CleaningSlots[tostring(slotIndex)]

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -10, 0, 74)
		card.LayoutOrder = order
		order += 1
		card.BackgroundColor3 = Color3.fromRGB(22, 34, 60)
		card.Parent = modalBody
		addCorner(card, 10)
		addStroke(card, Color3.fromRGB(78, 198, 245), 1.5)

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Position = UDim2.new(0, 14, 0, 8)
		statusLbl.Size = UDim2.new(0.65, 0, 0, 26)
		statusLbl.BackgroundTransparency = 1
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.TextScaled = true
		statusLbl.Font = Enum.Font.GothamBold
		statusLbl.Parent = card

		local barBg = Instance.new("Frame")
		barBg.Position = UDim2.new(0, 14, 0, 42)
		barBg.Size = UDim2.new(0.65, 0, 0, 18)
		barBg.BackgroundColor3 = Color3.fromRGB(36, 48, 78)
		barBg.BorderSizePixel = 0
		barBg.Parent = card
		addCorner(barBg, 8)

		local barFill = Instance.new("Frame")
		barFill.Size = UDim2.fromScale(0, 1)
		barFill.BackgroundColor3 = Color3.fromRGB(78, 224, 255)
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg
		addCorner(barFill, 8)

		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -12, 0.5, 0)
		btn.Size = UDim2.fromOffset(146, 42)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = card
		addCorner(btn, 8)

		if slot then
			local cfg = GameConfig.RELICS[slot.rawItemId]
			local progress = math.clamp((now - slot.startedAt) / math.max(0.1, slot.duration), 0, 1)
			local remaining = math.max(0, slot.endsAt - now)
			local isReady = remaining <= 0.05

			statusLbl.Text = if isReady
				then string.format("Basin %d: %s READY!", slotIndex, if cfg then cfg.name else "Relic")
				else string.format("Basin %d: Scrubbing %s (%.1fs)", slotIndex, if cfg then cfg.name else "Relic", remaining)
			statusLbl.TextColor3 = if isReady then Color3.fromRGB(116, 255, 168) else Color3.fromRGB(224, 242, 255)
			barFill.Size = UDim2.fromScale(progress, 1)
			barFill.BackgroundColor3 = if isReady then Color3.fromRGB(92, 248, 152) else Color3.fromRGB(78, 224, 255)
			btn.BackgroundColor3 = if isReady then Color3.fromRGB(64, 198, 128) else Color3.fromRGB(68, 86, 118)
			btn.Text = if isReady then "Claim Treasure!" else "Scrubbing..."

			btn.MouseButton1Click:Connect(function()
				local ok, res = pcall(function(): any
					return Remotes.ClaimCleaned:InvokeServer(slotIndex)
				end)
				if ok and typeof(res) == "table" and not res.success then
					ClientState.EmitLocalToast(res.message or "Still scrubbing!", "Warn")
				end
			end)
		else
			statusLbl.Text = string.format("Basin %d: Empty Washbasin", slotIndex)
			statusLbl.TextColor3 = Color3.fromRGB(168, 188, 214)
			btn.BackgroundColor3 = Color3.fromRGB(50, 62, 88)
			btn.Text = "Empty"
		end

		cleaningSlotProgressBars[slotIndex] = {
			barFill = barFill,
			statusLbl = statusLbl,
			btn = btn,
		}
	end

	createSectionHeader("RAW / ENCRUSTED RELICS TO CLEAN", order, Color3.fromRGB(255, 206, 98))
	order += 1

	if #state.profile.RawRelics == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -12, 0, 44)
		empty.LayoutOrder = order
		empty.BackgroundTransparency = 1
		empty.Text = "No raw relics in your backpack. Excavate underwater finds to scrub here!"
		empty.TextColor3 = Color3.fromRGB(178, 196, 220)
		empty.TextScaled = true
		empty.Font = Enum.Font.GothamMedium
		empty.Parent = modalBody
		return
	end

	for _, entry in ipairs(state.profile.RawRelics) do
		local cfg = GameConfig.RELICS[entry.itemId]
		if cfg then
			local meta = GameConfig.RARITY_META[cfg.rarity]
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 62)
			row.LayoutOrder = order
			order += 1
			row.BackgroundColor3 = Color3.fromRGB(24, 34, 60)
			row.Parent = modalBody
			addCorner(row, 10)
			addStroke(row, meta.color, 1.5)

			local lbl = Instance.new("TextLabel")
			lbl.Position = UDim2.new(0, 14, 0, 10)
			lbl.Size = UDim2.new(0.65, 0, 0, 40)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.format("[%s] %s (%ds scrub)", cfg.rarity, cfg.name, cfg.cleanDuration)
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = meta.color
			lbl.TextScaled = true
			lbl.Font = Enum.Font.GothamBold
			lbl.Parent = row

			local startBtn = Instance.new("TextButton")
			startBtn.AnchorPoint = Vector2.new(1, 0.5)
			startBtn.Position = UDim2.new(1, -12, 0.5, 0)
			startBtn.Size = UDim2.fromOffset(146, 38)
			startBtn.BackgroundColor3 = Color3.fromRGB(54, 162, 224)
			startBtn.Text = "Start Scrubbing"
			startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			startBtn.TextScaled = true
			startBtn.Font = Enum.Font.GothamBold
			startBtn.Parent = row
			addCorner(startBtn, 8)

			startBtn.MouseButton1Click:Connect(function()
				local ok, res = pcall(function(): any
					return Remotes.StartCleaning:InvokeServer(entry.uid, nil)
				end)
				if ok and typeof(res) == "table" and not res.success then
					ClientState.EmitLocalToast(res.message or "Cannot start scrubbing.", "Warn")
				end
			end)
		end
	end
end

local function renderAppraisalModal(state: ClientState.ClientSnapshot): ()
	modalTitle.Text = "APPRAISAL & SELL COUNTER"
	modalStroke.Color = Color3.fromRGB(255, 212, 88)

	local passives = ClientState.GetTotalPetPassives()
	local baseSum = 0
	for _, entry in ipairs(state.profile.CleanedRelics) do
		local cfg = GameConfig.RELICS[entry.itemId]
		if cfg then
			baseSum += cfg.sellValue
		end
	end
	local finalCoins = math.floor(baseSum * (1 + passives.coinMultiplierBonus) + 0.5)

	local summaryCard = Instance.new("Frame")
	summaryCard.Size = UDim2.new(1, -10, 0, 92)
	summaryCard.LayoutOrder = 1
	summaryCard.BackgroundColor3 = Color3.fromRGB(36, 34, 48)
	summaryCard.Parent = modalBody
	addCorner(summaryCard, 12)
	addStroke(summaryCard, Color3.fromRGB(255, 212, 88), 2)

	local sumTitle = Instance.new("TextLabel")
	sumTitle.Position = UDim2.new(0, 16, 0, 10)
	sumTitle.Size = UDim2.new(0.62, 0, 0, 32)
	sumTitle.BackgroundTransparency = 1
	sumTitle.Text = string.format("Cleaned Relics: %d  •  Payout: %s Coins", #state.profile.CleanedRelics, GameConfig.FormatNumber(finalCoins))
	sumTitle.TextXAlignment = Enum.TextXAlignment.Left
	sumTitle.TextColor3 = Color3.fromRGB(255, 224, 108)
	sumTitle.TextScaled = true
	sumTitle.Font = Enum.Font.GothamBold
	sumTitle.Parent = summaryCard

	local bonusSub = Instance.new("TextLabel")
	bonusSub.Position = UDim2.new(0, 16, 0, 48)
	bonusSub.Size = UDim2.new(0.62, 0, 0, 26)
	bonusSub.BackgroundTransparency = 1
	bonusSub.Text = string.format("Includes +%d%% Anime Companion Coin Multiplier!", math.floor(passives.coinMultiplierBonus * 100 + 0.5))
	bonusSub.TextXAlignment = Enum.TextXAlignment.Left
	bonusSub.TextColor3 = Color3.fromRGB(168, 240, 200)
	bonusSub.TextScaled = true
	bonusSub.Font = Enum.Font.GothamMedium
	bonusSub.Parent = summaryCard

	local sellBtn = Instance.new("TextButton")
	sellBtn.AnchorPoint = Vector2.new(1, 0.5)
	sellBtn.Position = UDim2.new(1, -14, 0.5, 0)
	sellBtn.Size = UDim2.fromOffset(178, 52)
	sellBtn.BackgroundColor3 = if #state.profile.CleanedRelics > 0
		then Color3.fromRGB(240, 178, 42)
		else Color3.fromRGB(78, 86, 104)
	sellBtn.Text = if #state.profile.CleanedRelics > 0 then "Sell All Relics" else "Nothing to Sell"
	sellBtn.TextColor3 = Color3.fromRGB(32, 22, 10)
	sellBtn.TextScaled = true
	sellBtn.Font = Enum.Font.GothamBold
	sellBtn.Parent = summaryCard
	addCorner(sellBtn, 10)

	sellBtn.MouseButton1Click:Connect(function()
		local ok, res = pcall(function(): any
			return Remotes.SellAllRelics:InvokeServer()
		end)
		if ok and typeof(res) == "table" and not res.success then
			ClientState.EmitLocalToast(res.message or "Cannot sell relics right now.", "Warn")
		end
	end)

	local order = 2
	for _, entry in ipairs(state.profile.CleanedRelics) do
		local cfg = GameConfig.RELICS[entry.itemId]
		if cfg then
			local meta = GameConfig.RARITY_META[cfg.rarity]
			local val = math.floor(cfg.sellValue * (1 + passives.coinMultiplierBonus) + 0.5)
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 52)
			row.LayoutOrder = order
			order += 1
			row.BackgroundColor3 = Color3.fromRGB(22, 30, 54)
			row.Parent = modalBody
			addCorner(row, 8)
			addStroke(row, meta.color, 1.2)

			local lbl = Instance.new("TextLabel")
			lbl.Position = UDim2.new(0, 14, 0, 8)
			lbl.Size = UDim2.new(0.68, 0, 0, 34)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.format("[%s] %s", cfg.rarity, cfg.name)
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = meta.color
			lbl.TextScaled = true
			lbl.Font = Enum.Font.GothamBold
			lbl.Parent = row

			local vLbl = Instance.new("TextLabel")
			vLbl.AnchorPoint = Vector2.new(1, 0.5)
			vLbl.Position = UDim2.new(1, -14, 0.5, 0)
			vLbl.Size = UDim2.fromOffset(120, 30)
			vLbl.BackgroundTransparency = 1
			vLbl.Text = GameConfig.FormatNumber(val) .. " C"
			vLbl.TextXAlignment = Enum.TextXAlignment.Right
			vLbl.TextColor3 = Color3.fromRGB(255, 224, 108)
			vLbl.TextScaled = true
			vLbl.Font = Enum.Font.GothamBold
			vLbl.Parent = row
		end
	end
end

local function renderEggsModal(state: ClientState.ClientSnapshot): ()
	modalTitle.Text = "ANIME COMPANION EGG SHRINE"
	modalStroke.Color = Color3.fromRGB(255, 146, 228)

	local order = 1
	for _, eggId in ipairs(GameConfig.EGG_ORDER) do
		local egg = GameConfig.EGGS[eggId]
		local oddsParts: { string } = {}
		for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
			local w = egg.rarityWeights[rarity] or 0
			if w > 0 then
				table.insert(oddsParts, string.format("%s %d%%", rarity, w))
			end
		end

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -10, 0, 96)
		card.LayoutOrder = order
		order += 1
		card.BackgroundColor3 = Color3.fromRGB(26, 28, 56)
		card.Parent = modalBody
		addCorner(card, 12)
		addStroke(card, egg.primaryColor, 2)

		local eggIcon = Instance.new("Frame")
		eggIcon.Position = UDim2.new(0, 14, 0.5, -28)
		eggIcon.Size = UDim2.fromOffset(44, 56)
		eggIcon.BackgroundColor3 = egg.primaryColor
		eggIcon.Parent = card
		addCorner(eggIcon, 22)
		addStroke(eggIcon, egg.secondaryColor, 2.5)

		local title = Instance.new("TextLabel")
		title.Position = UDim2.new(0, 72, 0, 8)
		title.Size = UDim2.new(0.62, 0, 0, 26)
		title.BackgroundTransparency = 1
		title.Text = egg.name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = egg.primaryColor
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 72, 0, 36)
		desc.Size = UDim2.new(0.64, 0, 0, 22)
		desc.BackgroundTransparency = 1
		desc.Text = egg.description
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextColor3 = Color3.fromRGB(214, 224, 246)
		desc.TextScaled = true
		desc.Font = Enum.Font.GothamMedium
		desc.Parent = card

		local odds = Instance.new("TextLabel")
		odds.Position = UDim2.new(0, 72, 0, 62)
		odds.Size = UDim2.new(0.66, 0, 0, 24)
		odds.BackgroundTransparency = 1
		odds.Text = "Odds: " .. table.concat(oddsParts, "  •  ")
		odds.TextXAlignment = Enum.TextXAlignment.Left
		odds.TextColor3 = Color3.fromRGB(255, 224, 138)
		odds.TextScaled = true
		odds.Font = Enum.Font.GothamMedium
		odds.Parent = card

		local hatchBtn = Instance.new("TextButton")
		hatchBtn.AnchorPoint = Vector2.new(1, 0.5)
		hatchBtn.Position = UDim2.new(1, -14, 0.5, 0)
		hatchBtn.Size = UDim2.fromOffset(146, 48)
		hatchBtn.BackgroundColor3 = if state.profile.Coins >= egg.cost
			then Color3.fromRGB(224, 98, 206)
			else Color3.fromRGB(116, 64, 92)
		hatchBtn.Text = "Hatch " .. GameConfig.FormatNumber(egg.cost)
		hatchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		hatchBtn.TextScaled = true
		hatchBtn.Font = Enum.Font.GothamBold
		hatchBtn.Parent = card
		addCorner(hatchBtn, 10)

		hatchBtn.MouseButton1Click:Connect(function()
			local ok, res = pcall(function(): any
				return Remotes.HatchEgg:InvokeServer(egg.id)
			end)
			if ok and typeof(res) == "table" and not res.success then
				ClientState.EmitLocalToast(res.message or "Cannot hatch egg right now.", "Warn")
			end
		end)
	end
end

local function refreshCurrentModal(): ()
	if not modalFrame or not modalFrame.Visible then
		return
	end
	clearModalBody()
	local state = ClientState.GetState()
	if currentModal == "Shop" then
		renderShopModal(state)
	elseif currentModal == "Cleaning" then
		renderCleaningModal(state)
	elseif currentModal == "Appraisal" then
		renderAppraisalModal(state)
	elseif currentModal == "Eggs" then
		renderEggsModal(state)
	end
end

local function playHatchAnimation(eggId: string, petEntry: ClientState.ClientOwnedPet, autoEquipped: boolean): ()
	local eggCfg = (GameConfig.EGGS :: { [string]: GameConfig.EggConfig })[eggId] or GameConfig.EGGS.CoralEgg
	local species = GameConfig.PETS[petEntry.speciesId]
	if not species then
		return
	end
	local meta = GameConfig.RARITY_META[species.rarity]

	hatchOverlay.Visible = true
	eggStage.Visible = true
	revealStage.Visible = false

	eggShellTop.BackgroundColor3 = eggCfg.primaryColor
	eggShellRing.BackgroundColor3 = eggCfg.secondaryColor
	eggNameStageLbl.Text = "Hatching " .. eggCfg.name .. "..."
	eggStage.Rotation = 0
	eggStage.Size = UDim2.fromOffset(180, 220)

	-- Shake & wobble animation
	task.spawn(function()
		for step = 1, 6 do
			local angle = if step % 2 == 0 then 14 else -14
			local t = TweenService:Create(eggStage, TweenInfo.new(0.11, Enum.EasingStyle.Sine), {
				Rotation = angle,
				Size = UDim2.fromOffset(180 + step * 5, 220 + step * 5),
			})
			t:Play()
			t.Completed:Wait()
		end

		eggStage.Visible = false
		revealStage.Visible = true
		revealStage.Size = UDim2.fromOffset(120, 140)

		revealRarityLbl.Text = string.upper(species.rarity) .. " COMPANION!"
		revealRarityLbl.TextColor3 = meta.color
		revealNameLbl.Text = species.name
		revealTitleLbl.Text = species.title
		revealStatsLbl.Text = string.format(
			"+%d O2 Cap  •  +%d Swim Speed\n+%d%% Excavation  •  +%d%% Scrubbing  •  +%d%% Coins",
			species.passives.oxygenCapacityBonus,
			species.passives.swimSpeedBonus,
			math.floor(species.passives.excavationSpeedBonus * 100 + 0.5),
			math.floor(species.passives.cleaningSpeedBonus * 100 + 0.5),
			math.floor(species.passives.coinMultiplierBonus * 100 + 0.5)
		)
		revealAutoLbl.Visible = autoEquipped

		revealPortrait.BackgroundColor3 = meta.badgeBg
		revealHair.BackgroundColor3 = species.hairColor
		revealFace.BackgroundColor3 = species.skinColor
		revealEyeL.BackgroundColor3 = species.eyeColor
		revealEyeR.BackgroundColor3 = species.eyeColor
		revealHaloBadge.Visible = species.hasHalo
		revealHaloBadge.BackgroundColor3 = if species.rarity == "Godly" or species.rarity == "Legendary"
			then Color3.fromRGB(255, 224, 96)
			else species.accentColor

		local revealStroke = revealStage:FindFirstChildOfClass("UIStroke")
		if revealStroke then
			revealStroke.Color = meta.color
		end

		TweenService:Create(revealStage, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(440, 400),
		}):Play()
	end)
end

local function buildUI(playerGui: PlayerGui): ()
	local existing = playerGui:FindFirstChild("AbyssalShopStationUI")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AbyssalShopStationUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	mainGui = gui

	modalFrame = Instance.new("Frame")
	modalFrame.Name = "StationModal"
	modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	modalFrame.Position = UDim2.fromScale(0.5, 0.5)
	modalFrame.Size = UDim2.fromScale(0.64, 0.68)
	modalFrame.BackgroundColor3 = Color3.fromRGB(14, 22, 42)
	modalFrame.BackgroundTransparency = 0.04
	modalFrame.Visible = false
	modalFrame.Parent = gui
	addCorner(modalFrame, 16)
	modalStroke = addStroke(modalFrame, Color3.fromRGB(108, 224, 255), 2.5)

	modalTitle = Instance.new("TextLabel")
	modalTitle.Position = UDim2.new(0, 20, 0, 14)
	modalTitle.Size = UDim2.new(0.78, 0, 0, 34)
	modalTitle.BackgroundTransparency = 1
	modalTitle.Text = "STATION"
	modalTitle.TextXAlignment = Enum.TextXAlignment.Left
	modalTitle.TextColor3 = Color3.fromRGB(242, 248, 255)
	modalTitle.TextScaled = true
	modalTitle.Font = Enum.Font.GothamBold
	modalTitle.Parent = modalFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -14, 0, 12)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = Color3.fromRGB(186, 62, 82)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = modalFrame
	addCorner(closeBtn, 10)
	closeBtn.MouseButton1Click:Connect(function()
		ClientState.CloseWindows()
	end)

	modalBody = Instance.new("ScrollingFrame")
	modalBody.Position = UDim2.new(0, 18, 0, 58)
	modalBody.Size = UDim2.new(1, -36, 1, -74)
	modalBody.BackgroundTransparency = 1
	modalBody.BorderSizePixel = 0
	modalBody.ScrollBarThickness = 6
	modalBody.AutomaticCanvasSize = Enum.AutomaticSize.Y
	modalBody.CanvasSize = UDim2.new(0, 0, 0, 0)
	modalBody.Parent = modalFrame

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.FillDirection = Enum.FillDirection.Vertical
	bodyLayout.Padding = UDim.new(0, 10)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = modalBody

	-- Animated Egg Hatching Reveal Overlay
	hatchOverlay = Instance.new("Frame")
	hatchOverlay.Name = "EggHatchRevealOverlay"
	hatchOverlay.Size = UDim2.fromScale(1, 1)
	hatchOverlay.BackgroundColor3 = Color3.fromRGB(6, 10, 24)
	hatchOverlay.BackgroundTransparency = 0.22
	hatchOverlay.Visible = false
	hatchOverlay.ZIndex = 50
	hatchOverlay.Parent = gui

	eggStage = Instance.new("Frame")
	eggStage.AnchorPoint = Vector2.new(0.5, 0.5)
	eggStage.Position = UDim2.fromScale(0.5, 0.5)
	eggStage.Size = UDim2.fromOffset(180, 220)
	eggStage.BackgroundTransparency = 1
	eggStage.ZIndex = 51
	eggStage.Parent = hatchOverlay

	eggShellTop = Instance.new("Frame")
	eggShellTop.AnchorPoint = Vector2.new(0.5, 0.5)
	eggShellTop.Position = UDim2.fromScale(0.5, 0.44)
	eggShellTop.Size = UDim2.fromOffset(132, 166)
	eggShellTop.BackgroundColor3 = Color3.fromRGB(255, 168, 206)
	eggShellTop.ZIndex = 52
	eggShellTop.Parent = eggStage
	addCorner(eggShellTop, 66)
	addStroke(eggShellTop, Color3.fromRGB(255, 255, 255), 4)

	eggShellRing = Instance.new("Frame")
	eggShellRing.AnchorPoint = Vector2.new(0.5, 0.5)
	eggShellRing.Position = UDim2.fromScale(0.5, 0.5)
	eggShellRing.Size = UDim2.new(1.06, 0, 0, 18)
	eggShellRing.BackgroundColor3 = Color3.fromRGB(122, 234, 222)
	eggShellRing.ZIndex = 53
	eggShellRing.Parent = eggShellTop
	addCorner(eggShellRing, 9)

	eggNameStageLbl = Instance.new("TextLabel")
	eggNameStageLbl.AnchorPoint = Vector2.new(0.5, 1)
	eggNameStageLbl.Position = UDim2.fromScale(0.5, 1.04)
	eggNameStageLbl.Size = UDim2.fromOffset(300, 36)
	eggNameStageLbl.BackgroundTransparency = 1
	eggNameStageLbl.Text = "Hatching..."
	eggNameStageLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	eggNameStageLbl.TextScaled = true
	eggNameStageLbl.Font = Enum.Font.GothamBold
	eggNameStageLbl.ZIndex = 53
	eggNameStageLbl.Parent = eggStage

	revealStage = Instance.new("Frame")
	revealStage.AnchorPoint = Vector2.new(0.5, 0.5)
	revealStage.Position = UDim2.fromScale(0.5, 0.5)
	revealStage.Size = UDim2.fromOffset(440, 400)
	revealStage.BackgroundColor3 = Color3.fromRGB(18, 26, 52)
	revealStage.Visible = false
	revealStage.ZIndex = 55
	revealStage.Parent = hatchOverlay
	addCorner(revealStage, 20)
	addStroke(revealStage, Color3.fromRGB(255, 168, 238), 3)

	revealRarityLbl = Instance.new("TextLabel")
	revealRarityLbl.Position = UDim2.fromScale(0.08, 0.05)
	revealRarityLbl.Size = UDim2.fromScale(0.84, 0.09)
	revealRarityLbl.BackgroundTransparency = 1
	revealRarityLbl.Text = "RARE COMPANION!"
	revealRarityLbl.TextColor3 = Color3.fromRGB(120, 210, 255)
	revealRarityLbl.TextScaled = true
	revealRarityLbl.Font = Enum.Font.GothamBold
	revealRarityLbl.ZIndex = 56
	revealRarityLbl.Parent = revealStage

	revealPortrait = Instance.new("Frame")
	revealPortrait.AnchorPoint = Vector2.new(0.5, 0)
	revealPortrait.Position = UDim2.fromScale(0.5, 0.16)
	revealPortrait.Size = UDim2.fromOffset(118, 118)
	revealPortrait.BackgroundColor3 = Color3.fromRGB(36, 48, 86)
	revealPortrait.ZIndex = 56
	revealPortrait.Parent = revealStage
	addCorner(revealPortrait, 59)
	addStroke(revealPortrait, Color3.fromRGB(255, 255, 255), 2.5)

	revealHaloBadge = Instance.new("Frame")
	revealHaloBadge.AnchorPoint = Vector2.new(0.5, 0)
	revealHaloBadge.Position = UDim2.fromScale(0.5, 0.04)
	revealHaloBadge.Size = UDim2.fromOffset(58, 10)
	revealHaloBadge.BackgroundColor3 = Color3.fromRGB(255, 224, 96)
	revealHaloBadge.ZIndex = 58
	revealHaloBadge.Parent = revealPortrait
	addCorner(revealHaloBadge, 5)

	revealHair = Instance.new("Frame")
	revealHair.AnchorPoint = Vector2.new(0.5, 0.5)
	revealHair.Position = UDim2.fromScale(0.5, 0.54)
	revealHair.Size = UDim2.fromOffset(82, 82)
	revealHair.BackgroundColor3 = Color3.fromRGB(255, 178, 218)
	revealHair.ZIndex = 57
	revealHair.Parent = revealPortrait
	addCorner(revealHair, 41)

	revealFace = Instance.new("Frame")
	revealFace.AnchorPoint = Vector2.new(0.5, 0.5)
	revealFace.Position = UDim2.fromScale(0.5, 0.56)
	revealFace.Size = UDim2.fromOffset(52, 48)
	revealFace.BackgroundColor3 = Color3.fromRGB(255, 231, 217)
	revealFace.ZIndex = 58
	revealFace.Parent = revealHair
	addCorner(revealFace, 24)

	revealEyeL = Instance.new("Frame")
	revealEyeL.Position = UDim2.fromScale(0.24, 0.38)
	revealEyeL.Size = UDim2.fromOffset(9, 12)
	revealEyeL.BackgroundColor3 = Color3.fromRGB(82, 168, 255)
	revealEyeL.ZIndex = 59
	revealEyeL.Parent = revealFace
	addCorner(revealEyeL, 5)

	revealEyeR = Instance.new("Frame")
	revealEyeR.Position = UDim2.fromScale(0.60, 0.38)
	revealEyeR.Size = UDim2.fromOffset(9, 12)
	revealEyeR.BackgroundColor3 = Color3.fromRGB(82, 168, 255)
	revealEyeR.ZIndex = 59
	revealEyeR.Parent = revealFace
	addCorner(revealEyeR, 5)

	revealNameLbl = Instance.new("TextLabel")
	revealNameLbl.Position = UDim2.fromScale(0.08, 0.48)
	revealNameLbl.Size = UDim2.fromScale(0.84, 0.1)
	revealNameLbl.BackgroundTransparency = 1
	revealNameLbl.Text = "Sakura"
	revealNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	revealNameLbl.TextScaled = true
	revealNameLbl.Font = Enum.Font.GothamBold
	revealNameLbl.ZIndex = 56
	revealNameLbl.Parent = revealStage

	revealTitleLbl = Instance.new("TextLabel")
	revealTitleLbl.Position = UDim2.fromScale(0.08, 0.58)
	revealTitleLbl.Size = UDim2.fromScale(0.84, 0.07)
	revealTitleLbl.BackgroundTransparency = 1
	revealTitleLbl.Text = "Blossom Siren"
	revealTitleLbl.TextColor3 = Color3.fromRGB(204, 224, 250)
	revealTitleLbl.TextScaled = true
	revealTitleLbl.Font = Enum.Font.GothamMedium
	revealTitleLbl.ZIndex = 56
	revealTitleLbl.Parent = revealStage

	revealAutoLbl = Instance.new("TextLabel")
	revealAutoLbl.Position = UDim2.fromScale(0.18, 0.65)
	revealAutoLbl.Size = UDim2.fromScale(0.64, 0.06)
	revealAutoLbl.BackgroundTransparency = 1
	revealAutoLbl.Text = "AUTO-EQUIPPED TO YOUR TEAM!"
	revealAutoLbl.TextColor3 = Color3.fromRGB(112, 248, 178)
	revealAutoLbl.TextScaled = true
	revealAutoLbl.Font = Enum.Font.GothamBold
	revealAutoLbl.ZIndex = 56
	revealAutoLbl.Parent = revealStage

	revealStatsLbl = Instance.new("TextLabel")
	revealStatsLbl.Position = UDim2.fromScale(0.08, 0.72)
	revealStatsLbl.Size = UDim2.fromScale(0.84, 0.13)
	revealStatsLbl.BackgroundTransparency = 1
	revealStatsLbl.Text = "+45 O2 • +6.5 Swim • +20% Dig"
	revealStatsLbl.TextColor3 = Color3.fromRGB(255, 230, 142)
	revealStatsLbl.TextScaled = true
	revealStatsLbl.Font = Enum.Font.GothamMedium
	revealStatsLbl.ZIndex = 56
	revealStatsLbl.Parent = revealStage

	local okBtn = Instance.new("TextButton")
	okBtn.AnchorPoint = Vector2.new(0.5, 1)
	okBtn.Position = UDim2.fromScale(0.5, 0.96)
	okBtn.Size = UDim2.fromOffset(180, 42)
	okBtn.BackgroundColor3 = Color3.fromRGB(72, 198, 134)
	okBtn.Text = "Awesome!"
	okBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	okBtn.TextScaled = true
	okBtn.Font = Enum.Font.GothamBold
	okBtn.ZIndex = 56
	okBtn.Parent = revealStage
	addCorner(okBtn, 10)
	okBtn.MouseButton1Click:Connect(function()
		hatchOverlay.Visible = false
	end)
end

function ShopAndStationUI.Init(): ()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	buildUI(playerGui)

	ClientState.SubscribeWindow(function(windowName: ClientState.WindowName)
		currentModal = windowName
		local shouldShow = windowName == "Shop" or windowName == "Cleaning" or windowName == "Appraisal" or windowName == "Eggs"
		modalFrame.Visible = shouldShow
		if shouldShow then
			refreshCurrentModal()
		end
	end)

	ClientState.Subscribe(function()
		if modalFrame.Visible then
			refreshCurrentModal()
		end
	end)

	ClientState.SubscribeEvents(function(ev: { [string]: any })
		if ev.type == "PetHatched" and typeof(ev.pet) == "table" then
			playHatchAnimation(tostring(ev.eggId or "CoralEgg"), ev.pet, ev.autoEquipped == true)
		end
	end)

	-- Live progress bar ticks for Cleaning Station modal while open
	RunService.RenderStepped:Connect(function()
		if not modalFrame.Visible or currentModal ~= "Cleaning" then
			return
		end
		local state = ClientState.GetState()
		local now = ClientState.GetServerTime()
		for slotIndex, widgets in pairs(cleaningSlotProgressBars) do
			local slot = state.profile.CleaningSlots[tostring(slotIndex)]
			if slot then
				local cfg = GameConfig.RELICS[slot.rawItemId]
				local progress = math.clamp((now - slot.startedAt) / math.max(0.1, slot.duration), 0, 1)
				local remaining = math.max(0, slot.endsAt - now)
				local isReady = remaining <= 0.05
				widgets.barFill.Size = UDim2.fromScale(progress, 1)
				widgets.barFill.BackgroundColor3 = if isReady then Color3.fromRGB(92, 248, 152) else Color3.fromRGB(78, 224, 255)
				widgets.statusLbl.Text = if isReady
					then string.format("Basin %d: %s READY!", slotIndex, if cfg then cfg.name else "Relic")
					else string.format("Basin %d: Scrubbing %s (%.1fs)", slotIndex, if cfg then cfg.name else "Relic", remaining)
				widgets.statusLbl.TextColor3 = if isReady then Color3.fromRGB(116, 255, 168) else Color3.fromRGB(224, 242, 255)
				widgets.btn.BackgroundColor3 = if isReady then Color3.fromRGB(64, 198, 128) else Color3.fromRGB(68, 86, 118)
				widgets.btn.Text = if isReady then "Claim Treasure!" else "Scrubbing..."
			end
		end
	end)
end

return ShopAndStationUI
