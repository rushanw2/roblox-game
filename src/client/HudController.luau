--!strict
-- Builds and updates the HUD, Stealth Eye Suspicion Indicator, Toast Alerts,
-- Backpack/Stash Drawer, Black-Market Shop Modal, and Terminal Unlock Modal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ClientFolder = script.Parent
local ClientState = require(ClientFolder:WaitForChild("ClientState"))
local WorldVisualsController = require(ClientFolder:WaitForChild("WorldVisualsController"))

local HudController = {}

local gui: ScreenGui
local cashValueLabel: TextLabel
local stolenValueLabel: TextLabel
local zoneBadgeLabel: TextLabel

local stealthEyeFrame: Frame
local stealthEyeCore: Frame
local stealthStatusLabel: TextLabel
local suspicionFill: Frame
local hotBagBanner: Frame
local hotBagText: TextLabel

local crouchBtn: TextButton
local smokeBtn: TextButton
local alarmBtn: TextButton
local backpackBadge: TextLabel

local toastContainer: Frame
local bustFlashFrame: Frame

local activeModal: string? = nil
local screenDimmer: Frame
local modalBackdrop: Frame
local modalTitle: TextLabel
local modalScroll: ScrollingFrame
local modalFooter: Frame
local modalBenchLabels: { [number]: TextLabel } = {}

-- UI Helpers declared before callers

local function addCorner(parent: Instance, radiusPx: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radiusPx)
	c.Parent = parent
	return c
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function makeLabel(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	font: Enum.Font,
	color: Color3,
	align: Enum.TextXAlignment?,
	zIndex: number?
): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Font = font
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.TextXAlignment = align or Enum.TextXAlignment.Left
	lbl.ZIndex = zIndex or (if parent:IsA("GuiObject") then parent.ZIndex + 1 else 2)
	lbl.Parent = parent
	return lbl
end

local function makeButton(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	bgColor: Color3,
	textColor: Color3,
	cornerRadius: number?,
	zIndex: number?
): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = bgColor
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.Text = text
	btn.TextColor3 = textColor
	btn.TextScaled = true
	btn.ZIndex = zIndex or (if parent:IsA("GuiObject") then parent.ZIndex + 1 else 2)
	btn.Parent = parent
	addCorner(btn, cornerRadius or 10)
	return btn
end

local function clearModalContents(): ()
	table.clear(modalBenchLabels)
	for _, child in ipairs(modalScroll:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	for _, child in ipairs(modalFooter:GetChildren()) do
		child:Destroy()
	end
end

local function setModalOpen(modalName: string?): ()
	if modalName ~= nil and activeModal == modalName then
		activeModal = nil
	else
		activeModal = modalName
	end
	local isOpen = activeModal ~= nil
	screenDimmer.Visible = isOpen
	modalBackdrop.Visible = isOpen
end

local function pushToast(message: string, tone: string, extra: { [string]: any }?): ()
	local accent = if tone == "success"
		then Color3.fromRGB(68, 232, 146)
		elseif tone == "warning" then Color3.fromRGB(255, 196, 58)
		elseif tone == "danger" then Color3.fromRGB(255, 68, 86)
		else Color3.fromRGB(82, 198, 255)

	if extra and extra.busted then
		bustFlashFrame.BackgroundTransparency = 0.48
		TweenService:Create(bustFlashFrame, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end

	-- Keep at most 3 stacked toasts so notifications stay compact
	local existingCards = {}
	for _, child in ipairs(toastContainer:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(existingCards, child)
		end
	end
	if #existingCards >= 3 then
		existingCards[1]:Destroy()
	end

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 34)
	card.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.ZIndex = 30
	card.Parent = toastContainer
	addCorner(card, 9)
	addStroke(card, accent, 1.5, 0.12)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = card

	local lbl = makeLabel(card, message, UDim2.fromScale(1, 0.76), UDim2.fromScale(0, 0.12), Enum.Font.GothamBold, Color3.fromRGB(244, 248, 255), Enum.TextXAlignment.Center, 31)
	lbl.TextWrapped = false

	task.delay(2.6, function()
		if card and card.Parent then
			local fade = TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			fade:Play()
			fade.Completed:Connect(function()
				if card then
					card:Destroy()
				end
			end)
		end
	end)
end

local function makeSectionHeader(text: string, color: Color3, order: number): ()
	local hdr = Instance.new("TextLabel")
	hdr.LayoutOrder = order
	hdr.Size = UDim2.new(1, 0, 0, 26)
	hdr.BackgroundTransparency = 1
	hdr.Font = Enum.Font.GothamBlack
	hdr.Text = text
	hdr.TextColor3 = color
	hdr.TextScaled = true
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	hdr.ZIndex = 22
	hdr.Parent = modalScroll
end

local function makeCardRow(order: number, heightPx: number, strokeColor: Color3): Frame
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, heightPx)
	card.BackgroundColor3 = Color3.fromRGB(28, 36, 52)
	card.BorderSizePixel = 0
	card.ZIndex = 22
	card.Parent = modalScroll
	addCorner(card, 10)
	addStroke(card, strokeColor, 1.5, 0.18)
	return card
end

local function renderBackpackModal(snap: ClientState.ClientSnapshot): ()
	modalTitle.Text = "STASH, WORKBENCHES & LOOT"
	clearModalContents()
	local order = 1
	local now = Workspace:GetServerTimeNow()

	-- 1. Carried Hot Bag
	makeSectionHeader("CARRIED HOT BAG", Color3.fromRGB(255, 198, 68), order)
	order += 1
	local carriedCard = makeCardRow(order, 54, if snap.CarriedLuggage then Color3.fromRGB(255, 104, 88) else Color3.fromRGB(64, 76, 98))
	order += 1
	if snap.CarriedLuggage then
		local c = snap.CarriedLuggage
		makeLabel(carriedCard, string.format("[%s] %s — HOT!", c.tier, c.displayName), UDim2.new(0.95, 0, 0, 24), UDim2.fromOffset(12, 5), Enum.Font.GothamBold, GameConfig.TIER_COLORS[c.tier])
		makeLabel(carriedCard, "Run south back into the Smuggler's Hideout to secure this bag!", UDim2.new(0.95, 0, 0, 18), UDim2.fromOffset(12, 30), Enum.Font.GothamMedium, Color3.fromRGB(228, 234, 244))
	else
		makeLabel(carriedCard, "Hands Empty — Sneak into SkyPort Terminal & grab unattended bags!", UDim2.new(0.95, 0, 0, 26), UDim2.fromOffset(12, 14), Enum.Font.GothamMedium, Color3.fromRGB(168, 184, 206))
	end

	-- 2. Workbenches (1..4)
	makeSectionHeader("HIDEOUT WORKBENCHES", Color3.fromRGB(82, 212, 255), order)
	order += 1
	local freeSlotIndex: number? = nil
	for idx = 1, 4 do
		local slot = snap.WorkbenchSlots[idx]
		local unlocked = idx <= snap.UpgradeLevels.WorkbenchCount
		if unlocked and slot and slot.bagUid == nil and freeSlotIndex == nil then
			freeSlotIndex = idx
		end

		local cardColor = if not unlocked
			then Color3.fromRGB(72, 78, 94)
			elseif slot and slot.isReady then Color3.fromRGB(68, 255, 148)
			elseif slot and slot.bagUid then Color3.fromRGB(255, 196, 56)
			else Color3.fromRGB(72, 212, 255)

		local row = makeCardRow(order, 58, cardColor)
		order += 1

		if not unlocked then
			local nextCost = GameConfig.GetWorkbenchUpgrade(idx).cost
			makeLabel(row, string.format("Workbench #%d — Locked (%s in Shop)", idx, GameConfig.FormatCash(nextCost)), UDim2.new(0.94, 0, 0, 26), UDim2.fromOffset(12, 16), Enum.Font.GothamBold, Color3.fromRGB(162, 170, 188))
		elseif slot and slot.bagUid then
			local rem = math.max(0, (slot.endsAt or now) - now)
			local ready = slot.isReady or rem <= 0
			makeLabel(row, string.format("#%d: [%s] %s", idx, slot.tier or "Bag", slot.displayName or "Bag"), UDim2.new(0.62, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, Color3.fromRGB(244, 248, 255))
			local statusLbl = makeLabel(
				row,
				if ready then "READY TO CLAIM!" else string.format("Cracking: %ds remaining", math.ceil(rem)),
				UDim2.new(0.62, 0, 0, 18),
				UDim2.fromOffset(12, 32),
				Enum.Font.GothamMedium,
				if ready then Color3.fromRGB(82, 255, 158) else Color3.fromRGB(255, 214, 110)
			)
			modalBenchLabels[idx] = statusLbl
			if ready then
				local claimBtn = makeButton(row, "CLAIM LOOT", UDim2.fromOffset(126, 36), UDim2.new(1, -138, 0.5, -18), Color3.fromRGB(48, 206, 118), Color3.fromRGB(14, 22, 18), 8)
				claimBtn.Activated:Connect(function()
					ClientState.ClaimOpenedLuggage(idx)
				end)
			end
		else
			makeLabel(row, string.format("Workbench #%d — Empty & Ready", idx), UDim2.new(0.94, 0, 0, 26), UDim2.fromOffset(12, 16), Enum.Font.GothamMedium, Color3.fromRGB(148, 224, 255))
		end
	end

	-- 3. Stashed Unopened Bags
	makeSectionHeader(string.format("STASHED LUGGAGE (%d)", #snap.StashedLuggage), Color3.fromRGB(196, 158, 255), order)
	order += 1
	if #snap.StashedLuggage == 0 then
		local emptyRow = makeCardRow(order, 44, Color3.fromRGB(58, 66, 86))
		order += 1
		makeLabel(emptyRow, "No unopened bags stashed.", UDim2.new(0.9, 0, 0, 22), UDim2.fromOffset(12, 11), Enum.Font.GothamMedium, Color3.fromRGB(154, 166, 188))
	else
		for _, bag in ipairs(snap.StashedLuggage) do
			local tierColor = GameConfig.TIER_COLORS[bag.tier]
			local canCrack = GameConfig.CanToolCrackTier(snap.UpgradeLevels.Tool, bag.tier)
			local row = makeCardRow(order, 54, tierColor)
			order += 1

			makeLabel(row, string.format("[%s] %s", bag.tier, bag.displayName), UDim2.new(0.6, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, tierColor)
			makeLabel(row, if canCrack then "Ready for Workbench" else "Requires Higher Cracking Tool!", UDim2.new(0.6, 0, 0, 18), UDim2.fromOffset(12, 31), Enum.Font.GothamMedium, if canCrack then Color3.fromRGB(190, 204, 222) else Color3.fromRGB(255, 120, 110))

			if canCrack and freeSlotIndex then
				local targetSlot = freeSlotIndex
				local crackBtn = makeButton(row, "CRACK #" .. targetSlot, UDim2.fromOffset(118, 34), UDim2.new(1, -130, 0.5, -17), Color3.fromRGB(64, 164, 255), Color3.fromRGB(12, 20, 32), 8)
				crackBtn.Activated:Connect(function()
					ClientState.PlaceOnWorkbench(bag.uid, targetSlot)
				end)
			end
		end
	end

	-- 4. Revealed Valuables
	local totalLootValue = 0
	for _, item in ipairs(snap.RevealedLoot) do
		totalLootValue += item.value
	end
	makeSectionHeader(string.format("REVEALED VALUABLES (%d • %s)", #snap.RevealedLoot, GameConfig.FormatCash(totalLootValue)), Color3.fromRGB(108, 255, 164), order)
	order += 1
	if #snap.RevealedLoot == 0 then
		local emptyLoot = makeCardRow(order, 44, Color3.fromRGB(58, 66, 86))
		order += 1
		makeLabel(emptyLoot, "Crack luggage on Workbenches to reveal items to sell!", UDim2.new(0.92, 0, 0, 22), UDim2.fromOffset(12, 11), Enum.Font.GothamMedium, Color3.fromRGB(154, 166, 188))
	else
		for _, item in ipairs(snap.RevealedLoot) do
			local tierColor = GameConfig.TIER_COLORS[item.tier]
			local row = makeCardRow(order, 46, tierColor)
			order += 1
			makeLabel(row, string.format("[%s] %s", item.tier, item.name), UDim2.new(0.68, 0, 0, 24), UDim2.fromOffset(12, 11), Enum.Font.GothamBold, tierColor)
			makeLabel(row, GameConfig.FormatCash(item.value), UDim2.new(0.26, 0, 0, 24), UDim2.new(0.71, 0, 0, 11), Enum.Font.GothamBlack, Color3.fromRGB(108, 255, 164), Enum.TextXAlignment.Right)
		end

		local sellBtn = makeButton(
			modalFooter,
			string.format("SELL ALL AT FENCE (+%s)", GameConfig.FormatCash(totalLootValue)),
			UDim2.fromScale(1, 1),
			UDim2.fromScale(0, 0),
			Color3.fromRGB(54, 212, 126),
			Color3.fromRGB(10, 22, 16),
			10
		)
		sellBtn.Activated:Connect(function()
			ClientState.SellAllLoot()
		end)
	end
end

local function renderShopModal(snap: ClientState.ClientSnapshot): ()
	modalTitle.Text = "BLACK-MARKET GEAR & UPGRADES"
	clearModalContents()
	local order = 1

	makeSectionHeader("PERMANENT UPGRADES", Color3.fromRGB(78, 224, 255), order)
	order += 1

	-- Cracking Tool
	local toolLvl = snap.UpgradeLevels.Tool
	local curTool = GameConfig.GetToolUpgrade(toolLvl)
	local isMaxTool = toolLvl >= #GameConfig.CRACKING_TOOLS
	local nextTool = if not isMaxTool then GameConfig.GetToolUpgrade(toolLvl + 1) else curTool
	local toolRow = makeCardRow(order, 68, curTool.color)
	order += 1
	makeLabel(toolRow, string.format("Cracking Tool: %s (Lv.%d/%d)", curTool.name, toolLvl, #GameConfig.CRACKING_TOOLS), UDim2.new(0.66, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, Color3.fromRGB(245, 248, 255))
	makeLabel(toolRow, if isMaxTool then "MAXED! Slices all tiers at 3.2x speed." else string.format("Next: %s — %s", nextTool.name, nextTool.description), UDim2.new(0.66, 0, 0, 28), UDim2.fromOffset(12, 32), Enum.Font.GothamMedium, Color3.fromRGB(182, 198, 220))
	if not isMaxTool then
		local btn = makeButton(toolRow, "BUY " .. GameConfig.FormatCash(nextTool.cost), UDim2.fromOffset(140, 40), UDim2.new(1, -152, 0.5, -20), if snap.Cash >= nextTool.cost then Color3.fromRGB(64, 172, 255) else Color3.fromRGB(62, 68, 84), Color3.fromRGB(245, 248, 255), 8)
		btn.Activated:Connect(function()
			ClientState.BuyUpgrade("Tool")
		end)
	else
		makeLabel(toolRow, "MAXED", UDim2.fromOffset(110, 30), UDim2.new(1, -122, 0.5, -15), Enum.Font.GothamBlack, Color3.fromRGB(92, 255, 162), Enum.TextXAlignment.Center)
	end

	-- Workbench Slots
	local benchLvl = snap.UpgradeLevels.WorkbenchCount
	local curBench = GameConfig.GetWorkbenchUpgrade(benchLvl)
	local isMaxBench = benchLvl >= #GameConfig.WORKBENCH_UPGRADES
	local nextBench = if not isMaxBench then GameConfig.GetWorkbenchUpgrade(benchLvl + 1) else curBench
	local benchRow = makeCardRow(order, 68, Color3.fromRGB(255, 196, 68))
	order += 1
	makeLabel(benchRow, string.format("Hideout Workbenches: %d / 4 Slots", benchLvl), UDim2.new(0.66, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, Color3.fromRGB(245, 248, 255))
	makeLabel(benchRow, if isMaxBench then "MAXED! 4 simultaneous cracking stations." else string.format("Next: %s — %s", nextBench.name, nextBench.description), UDim2.new(0.66, 0, 0, 28), UDim2.fromOffset(12, 32), Enum.Font.GothamMedium, Color3.fromRGB(182, 198, 220))
	if not isMaxBench then
		local btn = makeButton(benchRow, "BUY " .. GameConfig.FormatCash(nextBench.cost), UDim2.fromOffset(140, 40), UDim2.new(1, -152, 0.5, -20), if snap.Cash >= nextBench.cost then Color3.fromRGB(255, 186, 52) else Color3.fromRGB(62, 68, 84), Color3.fromRGB(18, 20, 26), 8)
		btn.Activated:Connect(function()
			ClientState.BuyUpgrade("WorkbenchCount")
		end)
	else
		makeLabel(benchRow, "MAXED", UDim2.fromOffset(110, 30), UDim2.new(1, -122, 0.5, -15), Enum.Font.GothamBlack, Color3.fromRGB(92, 255, 162), Enum.TextXAlignment.Center)
	end

	-- Sneakers
	local snkLvl = snap.UpgradeLevels.Sneakers
	local curSnk = GameConfig.GetSneakerUpgrade(snkLvl)
	local isMaxSnk = snkLvl >= #GameConfig.SNEAKER_UPGRADES
	local nextSnk = if not isMaxSnk then GameConfig.GetSneakerUpgrade(snkLvl + 1) else curSnk
	local snkRow = makeCardRow(order, 68, Color3.fromRGB(82, 232, 152))
	order += 1
	makeLabel(snkRow, string.format("Sneakers: %s (Lv.%d/%d)", curSnk.name, snkLvl, #GameConfig.SNEAKER_UPGRADES), UDim2.new(0.66, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, Color3.fromRGB(245, 248, 255))
	makeLabel(snkRow, if isMaxSnk then "MAXED! Top sprint & sneak velocity." else string.format("Next: %s (Walk %d / Crouch %.1f)", nextSnk.name, nextSnk.walkSpeed, nextSnk.crouchSpeed), UDim2.new(0.66, 0, 0, 28), UDim2.fromOffset(12, 32), Enum.Font.GothamMedium, Color3.fromRGB(182, 198, 220))
	if not isMaxSnk then
		local btn = makeButton(snkRow, "BUY " .. GameConfig.FormatCash(nextSnk.cost), UDim2.fromOffset(140, 40), UDim2.new(1, -152, 0.5, -20), if snap.Cash >= nextSnk.cost then Color3.fromRGB(64, 212, 136) else Color3.fromRGB(62, 68, 84), Color3.fromRGB(14, 22, 18), 8)
		btn.Activated:Connect(function()
			ClientState.BuyUpgrade("Sneakers")
		end)
	else
		makeLabel(snkRow, "MAXED", UDim2.fromOffset(110, 30), UDim2.new(1, -122, 0.5, -15), Enum.Font.GothamBlack, Color3.fromRGB(92, 255, 162), Enum.TextXAlignment.Center)
	end

	-- Stealth Coat
	local coatLvl = snap.UpgradeLevels.StealthCoat
	local curCoat = GameConfig.GetStealthCoatUpgrade(coatLvl)
	local isMaxCoat = coatLvl >= #GameConfig.STEALTH_COAT_UPGRADES
	local nextCoat = if not isMaxCoat then GameConfig.GetStealthCoatUpgrade(coatLvl + 1) else curCoat
	local coatRow = makeCardRow(order, 68, Color3.fromRGB(186, 112, 255))
	order += 1
	makeLabel(coatRow, string.format("Stealth Coat: %s (Lv.%d/%d)", curCoat.name, coatLvl, #GameConfig.STEALTH_COAT_UPGRADES), UDim2.new(0.66, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, Color3.fromRGB(245, 248, 255))
	makeLabel(coatRow, if isMaxCoat then "MAXED! Minimal enemy detection footprint." else string.format("Next: %s — %s", nextCoat.name, nextCoat.description), UDim2.new(0.66, 0, 0, 28), UDim2.fromOffset(12, 32), Enum.Font.GothamMedium, Color3.fromRGB(182, 198, 220))
	if not isMaxCoat then
		local btn = makeButton(coatRow, "BUY " .. GameConfig.FormatCash(nextCoat.cost), UDim2.fromOffset(140, 40), UDim2.new(1, -152, 0.5, -20), if snap.Cash >= nextCoat.cost then Color3.fromRGB(172, 92, 255) else Color3.fromRGB(62, 68, 84), Color3.fromRGB(245, 248, 255), 8)
		btn.Activated:Connect(function()
			ClientState.BuyUpgrade("StealthCoat")
		end)
	else
		makeLabel(coatRow, "MAXED", UDim2.fromOffset(110, 30), UDim2.new(1, -122, 0.5, -15), Enum.Font.GothamBlack, Color3.fromRGB(92, 255, 162), Enum.TextXAlignment.Center)
	end

	-- Gadgets
	makeSectionHeader("STEALTH CONSUMABLES (HOTKEYS G / H)", Color3.fromRGB(255, 178, 68), order)
	order += 1
	for _, cid in ipairs(GameConfig.CONSUMABLE_ORDER) do
		local def = GameConfig.CONSUMABLES[cid]
		local count = snap.Consumables[cid] or 0
		local row = makeCardRow(order, 64, def.color)
		order += 1
		makeLabel(row, string.format("[%s] %s (%d/%d)", def.hotkeyLabel, def.name, count, def.maxStack), UDim2.new(0.66, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, def.color)
		makeLabel(row, def.description, UDim2.new(0.66, 0, 0, 26), UDim2.fromOffset(12, 31), Enum.Font.GothamMedium, Color3.fromRGB(190, 206, 226))
		local full = count >= def.maxStack
		local btn = makeButton(
			row,
			if full then "STACK FULL" else "BUY " .. GameConfig.FormatCash(def.cost),
			UDim2.fromOffset(140, 38),
			UDim2.new(1, -152, 0.5, -19),
			if (not full and snap.Cash >= def.cost) then def.color else Color3.fromRGB(62, 68, 84),
			Color3.fromRGB(16, 20, 28),
			8
		)
		if not full then
			btn.Activated:Connect(function()
				ClientState.BuyConsumable(cid)
			end)
		end
	end
end

local function renderTerminalsModal(snap: ClientState.ClientSnapshot): ()
	modalTitle.Text = "SKYPORT TERMINAL PASSES"
	clearModalContents()
	local order = 1

	makeSectionHeader("UNLOCK HIGHER-VALUE AIRPORT WINGS", Color3.fromRGB(255, 204, 68), order)
	order += 1

	for _, tid in ipairs(GameConfig.TERMINAL_ORDER) do
		local def = GameConfig.TERMINALS[tid]
		local unlocked = snap.UnlockedTerminals[tid] == true
		local row = makeCardRow(order, 78, def.accentColor)
		order += 1

		makeLabel(row, def.name, UDim2.new(0.64, 0, 0, 24), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, def.accentColor)
		makeLabel(row, string.format("%s | Tiers: %s", def.subtitle, table.concat(def.allowedTiers, ", ")), UDim2.new(0.64, 0, 0, 34), UDim2.fromOffset(12, 34), Enum.Font.GothamMedium, Color3.fromRGB(196, 210, 232))

		if unlocked then
			makeLabel(row, "UNLOCKED", UDim2.fromOffset(130, 32), UDim2.new(1, -142, 0.5, -16), Enum.Font.GothamBlack, Color3.fromRGB(78, 255, 162), Enum.TextXAlignment.Center)
		else
			local btn = makeButton(
				row,
				"UNLOCK " .. GameConfig.FormatCash(def.unlockCost),
				UDim2.fromOffset(144, 42),
				UDim2.new(1, -156, 0.5, -21),
				if snap.Cash >= def.unlockCost then def.accentColor else Color3.fromRGB(62, 68, 84),
				Color3.fromRGB(16, 20, 28),
				8
			)
			btn.Activated:Connect(function()
				ClientState.UnlockTerminal(tid)
			end)
		end
	end
end

local function refreshActiveModal(): ()
	local snap = ClientState.GetSnapshot()
	if not snap or not activeModal then
		return
	end
	if activeModal == "Backpack" then
		renderBackpackModal(snap)
	elseif activeModal == "Shop" then
		renderShopModal(snap)
	elseif activeModal == "Terminals" then
		renderTerminalsModal(snap)
	end
end

local function updateHudFromSnapshot(snap: ClientState.ClientSnapshot): ()
	cashValueLabel.Text = GameConfig.FormatCash(snap.Cash)
	stolenValueLabel.Text = tostring(snap.TotalStolen)

	local readyCount = 0
	for _, slot in ipairs(snap.WorkbenchSlots) do
		if slot.isReady then
			readyCount += 1
		end
	end
	local totalItems = #snap.StashedLuggage + #snap.RevealedLoot + readyCount
	backpackBadge.Visible = totalItems > 0
	backpackBadge.Text = tostring(totalItems)

	if snap.CarriedLuggage then
		hotBagBanner.Visible = true
		hotBagText.Text = string.format("HOT BAG: %s — ESCAPE!", snap.CarriedLuggage.tier:upper())
	else
		hotBagBanner.Visible = false
	end

	local smokeCount = snap.Consumables.SmokeBomb or 0
	local alarmCount = snap.Consumables.DistractionAlarm or 0
	smokeBtn.Text = string.format("[G] Smoke (%d)", smokeCount)
	alarmBtn.Text = string.format("[H] Alarm (%d)", alarmCount)

	refreshActiveModal()
end

local function buildGui(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("StealALuggageHUD")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "StealALuggageHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Bust red screen flash overlay
	bustFlashFrame = Instance.new("Frame")
	bustFlashFrame.Size = UDim2.fromScale(1, 1)
	bustFlashFrame.BackgroundColor3 = Color3.fromRGB(255, 36, 52)
	bustFlashFrame.BackgroundTransparency = 1
	bustFlashFrame.BorderSizePixel = 0
	bustFlashFrame.ZIndex = 1
	bustFlashFrame.Parent = gui

	-- TOP-LEFT STAT PILLS
	local statsRow = Instance.new("Frame")
	statsRow.Size = UDim2.fromOffset(330, 56)
	statsRow.Position = UDim2.fromOffset(18, 16)
	statsRow.BackgroundTransparency = 1
	statsRow.ZIndex = 2
	statsRow.Parent = gui

	local cashCard = Instance.new("Frame")
	cashCard.Size = UDim2.fromOffset(172, 54)
	cashCard.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
	cashCard.BackgroundTransparency = 0.12
	cashCard.BorderSizePixel = 0
	cashCard.ZIndex = 2
	cashCard.Parent = statsRow
	addCorner(cashCard, 12)
	addStroke(cashCard, Color3.fromRGB(68, 224, 146), 2, 0.2)
	makeLabel(cashCard, "CASH", UDim2.fromOffset(80, 14), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, Color3.fromRGB(140, 228, 180))
	cashValueLabel = makeLabel(cashCard, "$0", UDim2.fromOffset(148, 26), UDim2.fromOffset(12, 22), Enum.Font.GothamBlack, Color3.fromRGB(244, 250, 255))

	local stolenCard = Instance.new("Frame")
	stolenCard.Size = UDim2.fromOffset(144, 54)
	stolenCard.Position = UDim2.fromOffset(182, 0)
	stolenCard.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
	stolenCard.BackgroundTransparency = 0.12
	stolenCard.BorderSizePixel = 0
	stolenCard.ZIndex = 2
	stolenCard.Parent = statsRow
	addCorner(stolenCard, 12)
	addStroke(stolenCard, Color3.fromRGB(82, 198, 255), 2, 0.2)
	makeLabel(stolenCard, "BAGS STOLEN", UDim2.fromOffset(120, 14), UDim2.fromOffset(12, 6), Enum.Font.GothamBold, Color3.fromRGB(148, 208, 244))
	stolenValueLabel = makeLabel(stolenCard, "0", UDim2.fromOffset(120, 26), UDim2.fromOffset(12, 22), Enum.Font.GothamBlack, Color3.fromRGB(244, 250, 255))

	local zonePill = Instance.new("Frame")
	zonePill.Size = UDim2.fromOffset(326, 28)
	zonePill.Position = UDim2.fromOffset(18, 76)
	zonePill.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
	zonePill.BackgroundTransparency = 0.2
	zonePill.BorderSizePixel = 0
	zonePill.ZIndex = 2
	zonePill.Parent = gui
	addCorner(zonePill, 8)
	zoneBadgeLabel = makeLabel(zonePill, "Courtyard", UDim2.new(1, -16, 1, -4), UDim2.fromOffset(8, 2), Enum.Font.GothamBold, Color3.fromRGB(214, 226, 245))

	-- TOP-CENTER STEALTH EYE & SUSPICION METER
	local stealthCard = Instance.new("Frame")
	stealthCard.Size = UDim2.fromOffset(290, 56)
	stealthCard.Position = UDim2.new(0.5, -145, 0, 16)
	stealthCard.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	stealthCard.BackgroundTransparency = 0.1
	stealthCard.BorderSizePixel = 0
	stealthCard.ZIndex = 2
	stealthCard.Parent = gui
	addCorner(stealthCard, 14)
	addStroke(stealthCard, Color3.fromRGB(82, 128, 168), 2, 0.25)

	stealthEyeFrame = Instance.new("Frame")
	stealthEyeFrame.Size = UDim2.fromOffset(38, 24)
	stealthEyeFrame.Position = UDim2.fromOffset(12, 10)
	stealthEyeFrame.BackgroundColor3 = Color3.fromRGB(48, 208, 142)
	stealthEyeFrame.BorderSizePixel = 0
	stealthEyeFrame.ZIndex = 3
	stealthEyeFrame.Parent = stealthCard
	addCorner(stealthEyeFrame, 12)

	stealthEyeCore = Instance.new("Frame")
	stealthEyeCore.Size = UDim2.fromOffset(14, 14)
	stealthEyeCore.Position = UDim2.fromOffset(12, 5)
	stealthEyeCore.BackgroundColor3 = Color3.fromRGB(14, 20, 28)
	stealthEyeCore.BorderSizePixel = 0
	stealthEyeCore.ZIndex = 4
	stealthEyeCore.Parent = stealthEyeFrame
	addCorner(stealthEyeCore, 7)

	stealthStatusLabel = makeLabel(stealthCard, "HIDDEN", UDim2.fromOffset(216, 22), UDim2.fromOffset(60, 8), Enum.Font.GothamBlack, Color3.fromRGB(86, 242, 164), nil, 3)

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.fromOffset(266, 10)
	barBg.Position = UDim2.fromOffset(12, 38)
	barBg.BackgroundColor3 = Color3.fromRGB(36, 44, 62)
	barBg.BorderSizePixel = 0
	barBg.ZIndex = 3
	barBg.Parent = stealthCard
	addCorner(barBg, 5)

	suspicionFill = Instance.new("Frame")
	suspicionFill.Size = UDim2.fromScale(0, 1)
	suspicionFill.BackgroundColor3 = Color3.fromRGB(72, 232, 148)
	suspicionFill.BorderSizePixel = 0
	suspicionFill.ZIndex = 4
	suspicionFill.Parent = barBg
	addCorner(suspicionFill, 5)

	-- HOT BAG ESCAPE BANNER
	hotBagBanner = Instance.new("Frame")
	hotBagBanner.Size = UDim2.fromOffset(300, 28)
	hotBagBanner.Position = UDim2.new(0.5, -150, 0, 78)
	hotBagBanner.BackgroundColor3 = Color3.fromRGB(198, 48, 42)
	hotBagBanner.Visible = false
	hotBagBanner.BorderSizePixel = 0
	hotBagBanner.ZIndex = 3
	hotBagBanner.Parent = gui
	addCorner(hotBagBanner, 8)
	hotBagText = makeLabel(hotBagBanner, "HOT BAG!", UDim2.new(1, -16, 1, -4), UDim2.fromOffset(8, 2), Enum.Font.GothamBlack, Color3.fromRGB(255, 248, 238), Enum.TextXAlignment.Center, 4)

	-- COMPACT TOAST STACK
	toastContainer = Instance.new("Frame")
	toastContainer.Size = UDim2.fromOffset(290, 130)
	toastContainer.Position = UDim2.new(0.5, -145, 0, 112)
	toastContainer.BackgroundTransparency = 1
	toastContainer.ZIndex = 30
	toastContainer.Parent = gui
	local toastList = Instance.new("UIListLayout")
	toastList.Padding = UDim.new(0, 5)
	toastList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toastList.Parent = toastContainer

	-- BOTTOM ACTION & GADGET BAR
	local dock = Instance.new("Frame")
	dock.Size = UDim2.fromOffset(660, 56)
	dock.Position = UDim2.new(0.5, -330, 1, -72)
	dock.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	dock.BackgroundTransparency = 0.14
	dock.BorderSizePixel = 0
	dock.ZIndex = 3
	dock.Parent = gui
	addCorner(dock, 14)
	addStroke(dock, Color3.fromRGB(68, 84, 112), 2, 0.25)

	crouchBtn = makeButton(dock, "[C] Stand", UDim2.fromOffset(112, 40), UDim2.fromOffset(10, 8), Color3.fromRGB(36, 46, 64), Color3.fromRGB(232, 240, 255), 10)
	crouchBtn.Activated:Connect(function()
		ClientState.ToggleCrouch()
	end)

	smokeBtn = makeButton(dock, "[G] Smoke (1)", UDim2.fromOffset(124, 40), UDim2.fromOffset(130, 8), Color3.fromRGB(48, 66, 86), Color3.fromRGB(218, 238, 255), 10)
	smokeBtn.Activated:Connect(function()
		ClientState.SetSelectedGadget("SmokeBomb")
		ClientState.UseGadget("SmokeBomb")
	end)

	alarmBtn = makeButton(dock, "[H] Alarm (1)", UDim2.fromOffset(124, 40), UDim2.fromOffset(262, 8), Color3.fromRGB(72, 54, 34), Color3.fromRGB(255, 224, 168), 10)
	alarmBtn.Activated:Connect(function()
		ClientState.SetSelectedGadget("DistractionAlarm")
		ClientState.UseGadget("DistractionAlarm")
	end)

	local bagBtn = makeButton(dock, "[B] Stash", UDim2.fromOffset(96, 40), UDim2.fromOffset(394, 8), Color3.fromRGB(64, 52, 98), Color3.fromRGB(234, 220, 255), 10)
	bagBtn.Activated:Connect(function()
		setModalOpen("Backpack")
		refreshActiveModal()
	end)
	backpackBadge = Instance.new("TextLabel")
	backpackBadge.Size = UDim2.fromOffset(22, 22)
	backpackBadge.Position = UDim2.new(1, -16, 0, -6)
	backpackBadge.BackgroundColor3 = Color3.fromRGB(255, 86, 128)
	backpackBadge.Font = Enum.Font.GothamBlack
	backpackBadge.Text = "0"
	backpackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	backpackBadge.TextScaled = true
	backpackBadge.ZIndex = 6
	backpackBadge.Visible = false
	backpackBadge.Parent = bagBtn
	addCorner(backpackBadge, 11)

	local shopBtn = makeButton(dock, "[U] Shop", UDim2.fromOffset(72, 40), UDim2.fromOffset(498, 8), Color3.fromRGB(36, 74, 112), Color3.fromRGB(216, 240, 255), 10)
	shopBtn.Activated:Connect(function()
		setModalOpen("Shop")
		refreshActiveModal()
	end)

	local termBtn = makeButton(dock, "[T] Wings", UDim2.fromOffset(74, 40), UDim2.fromOffset(576, 8), Color3.fromRGB(76, 62, 30), Color3.fromRGB(255, 228, 152), 10)
	termBtn.Activated:Connect(function()
		setModalOpen("Terminals")
		refreshActiveModal()
	end)

	-- SCREEN DIMMER (ZIndex 10 sits strictly behind modal window & cards at ZIndex 20+)
	screenDimmer = Instance.new("Frame")
	screenDimmer.Size = UDim2.fromScale(1, 1)
	screenDimmer.BackgroundColor3 = Color3.fromRGB(6, 10, 18)
	screenDimmer.BackgroundTransparency = 0.48
	screenDimmer.Visible = false
	screenDimmer.Active = false
	screenDimmer.ZIndex = 10
	screenDimmer.BorderSizePixel = 0
	screenDimmer.Parent = gui

	-- CENTER MODAL CONTAINER (ZIndex 20+, crisp bright contrast)
	modalBackdrop = Instance.new("Frame")
	modalBackdrop.Size = UDim2.fromOffset(580, 440)
	modalBackdrop.Position = UDim2.new(0.5, -290, 0.5, -220)
	modalBackdrop.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	modalBackdrop.BackgroundTransparency = 0.02
	modalBackdrop.Visible = false
	modalBackdrop.ZIndex = 20
	modalBackdrop.BorderSizePixel = 0
	modalBackdrop.Parent = gui
	addCorner(modalBackdrop, 16)
	addStroke(modalBackdrop, Color3.fromRGB(82, 198, 255), 2, 0.1)

	modalTitle = makeLabel(modalBackdrop, "MENU", UDim2.new(1, -76, 0, 32), UDim2.fromOffset(18, 12), Enum.Font.GothamBlack, Color3.fromRGB(245, 248, 255), nil, 21)
	local closeBtn = makeButton(modalBackdrop, "X", UDim2.fromOffset(36, 36), UDim2.new(1, -48, 0, 10), Color3.fromRGB(186, 52, 62), Color3.fromRGB(255, 255, 255), 9, 21)
	closeBtn.Activated:Connect(function()
		setModalOpen(nil)
	end)

	modalScroll = Instance.new("ScrollingFrame")
	modalScroll.Size = UDim2.new(1, -28, 1, -116)
	modalScroll.Position = UDim2.fromOffset(14, 54)
	modalScroll.BackgroundTransparency = 1
	modalScroll.BorderSizePixel = 0
	modalScroll.CanvasSize = UDim2.fromOffset(0, 0)
	modalScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	modalScroll.ScrollBarThickness = 6
	modalScroll.ZIndex = 21
	modalScroll.Parent = modalBackdrop

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.Padding = UDim.new(0, 8)
	scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrollLayout.Parent = modalScroll

	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingRight = UDim.new(0, 8)
	scrollPad.Parent = modalScroll

	modalFooter = Instance.new("Frame")
	modalFooter.Size = UDim2.new(1, -28, 0, 44)
	modalFooter.Position = UDim2.new(0, 14, 1, -54)
	modalFooter.BackgroundTransparency = 1
	modalFooter.ZIndex = 21
	modalFooter.Parent = modalBackdrop
end

function HudController.Start(): ()
	buildGui()

	ClientState.OnStateChanged(updateHudFromSnapshot)
	ClientState.OnToast(pushToast)
	ClientState.OnOpenModal(function(modalName: string)
		setModalOpen(modalName)
		refreshActiveModal()
	end)
	WorldVisualsController.SetModalCallback(function(modalName: string)
		setModalOpen(modalName)
		refreshActiveModal()
	end)
	ClientState.OnCrouchChanged(function(crouching: boolean)
		if crouching then
			crouchBtn.Text = "[C] Sneaking"
			crouchBtn.BackgroundColor3 = Color3.fromRGB(48, 152, 224)
		else
			crouchBtn.Text = "[C] Stand"
			crouchBtn.BackgroundColor3 = Color3.fromRGB(36, 46, 64)
		end
	end)

	local modalTimerAcc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local lp = Players.LocalPlayer
		local susp = (lp:GetAttribute("Suspicion") :: number?) or 0
		local status = (lp:GetAttribute("StealthStatus") :: string?) or "Safe"

		suspicionFill.Size = UDim2.fromScale(math.clamp(susp / 100, 0, 1), 1)
		if status == "Busted" then
			stealthStatusLabel.Text = "COOKED! BUSTED!"
			stealthStatusLabel.TextColor3 = Color3.fromRGB(255, 72, 86)
			stealthEyeFrame.BackgroundColor3 = Color3.fromRGB(255, 62, 74)
			suspicionFill.BackgroundColor3 = Color3.fromRGB(255, 62, 74)
		elseif status == "Safe" then
			stealthStatusLabel.Text = "HIDEOUT SAFE ZONE"
			stealthStatusLabel.TextColor3 = Color3.fromRGB(78, 255, 162)
			stealthEyeFrame.BackgroundColor3 = Color3.fromRGB(68, 232, 146)
			suspicionFill.BackgroundColor3 = Color3.fromRGB(68, 232, 146)
		elseif status == "Danger" or susp >= 65 then
			stealthStatusLabel.Text = string.format("SPOTTED! %d%%", susp)
			stealthStatusLabel.TextColor3 = Color3.fromRGB(255, 76, 86)
			stealthEyeFrame.BackgroundColor3 = Color3.fromRGB(255, 68, 82)
			suspicionFill.BackgroundColor3 = Color3.fromRGB(255, 68, 82)
		elseif status == "Caution" or susp >= 20 then
			stealthStatusLabel.Text = string.format("SUSPICIOUS %d%%", susp)
			stealthStatusLabel.TextColor3 = Color3.fromRGB(255, 214, 52)
			stealthEyeFrame.BackgroundColor3 = Color3.fromRGB(255, 214, 52)
			suspicionFill.BackgroundColor3 = Color3.fromRGB(255, 214, 52)
		elseif status == "Hot" then
			stealthStatusLabel.Text = "HOT BAG — ESCAPE!"
			stealthStatusLabel.TextColor3 = Color3.fromRGB(255, 162, 58)
			stealthEyeFrame.BackgroundColor3 = Color3.fromRGB(255, 152, 56)
			suspicionFill.BackgroundColor3 = Color3.fromRGB(255, 152, 56)
		else
			stealthStatusLabel.Text = if ClientState.IsCrouching() then "SNEAKING (HIDDEN)" else "HIDDEN"
			stealthStatusLabel.TextColor3 = Color3.fromRGB(96, 224, 255)
			stealthEyeFrame.BackgroundColor3 = Color3.fromRGB(72, 206, 255)
			suspicionFill.BackgroundColor3 = Color3.fromRGB(72, 206, 255)
		end

		-- Update Zone Badge from player position
		local char = lp.Character
		local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if hrp then
			if GameConfig.IsPointInHideout(hrp.Position) then
				zoneBadgeLabel.Text = "Smuggler's Hideout (Safe Zone)"
				zoneBadgeLabel.TextColor3 = Color3.fromRGB(78, 255, 162)
			else
				local tid = GameConfig.GetTerminalAtPosition(hrp.Position)
				if tid then
					local tdef = GameConfig.TERMINALS[tid]
					zoneBadgeLabel.Text = tdef.name
					zoneBadgeLabel.TextColor3 = tdef.accentColor
				else
					zoneBadgeLabel.Text = "Airport Courtyard"
					zoneBadgeLabel.TextColor3 = Color3.fromRGB(204, 218, 238)
				end
			end
		end

		-- Live countdown tick & gadget cooldown labels without rebuilding DOM
		local snap = ClientState.GetSnapshot()
		if snap then
			local smokeCount = snap.Consumables.SmokeBomb or 0
			local smokeCd = ClientState.GetGadgetCooldownRemaining("SmokeBomb")
			smokeBtn.Text = if smokeCd > 0.1
				then string.format("[G] %.1fs (%d)", smokeCd, smokeCount)
				else string.format("[G] Smoke (%d)", smokeCount)

			local alarmCount = snap.Consumables.DistractionAlarm or 0
			local alarmCd = ClientState.GetGadgetCooldownRemaining("DistractionAlarm")
			alarmBtn.Text = if alarmCd > 0.1
				then string.format("[H] %.1fs (%d)", alarmCd, alarmCount)
				else string.format("[H] Alarm (%d)", alarmCount)
		end

		if activeModal == "Backpack" and snap then
			modalTimerAcc += dt
			if modalTimerAcc >= 0.25 then
				modalTimerAcc = 0
				local now = Workspace:GetServerTimeNow()
				for idx, lbl in pairs(modalBenchLabels) do
					local slot = snap.WorkbenchSlots[idx]
					if slot and slot.bagUid then
						local rem = math.max(0, (slot.endsAt or now) - now)
						if slot.isReady or rem <= 0 then
							lbl.Text = "READY TO CLAIM!"
							lbl.TextColor3 = Color3.fromRGB(82, 255, 158)
						else
							lbl.Text = string.format("Cracking: %ds remaining", math.ceil(rem))
						end
					end
				end
			end
		end
	end)
end

return HudController
