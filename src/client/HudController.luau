--!strict
-- Builds and updates the HUD, Stealth Eye Suspicion Indicator, Toast Alerts,
-- Left-Side Stylized Stash/Shop Buttons, 3-Tab Stash Modal, 2-Tab Shop Modal, and Terminal Unlock Modal.

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
local HudIcons = require(ClientFolder:WaitForChild("HudIcons"))

type StashTabId = "Workbenches" | "Stash" | "Valuables"
type ShopTabId = "Upgrades" | "Items"

type StashedGroup = {
	archetypeId: string,
	displayName: string,
	tier: GameConfig.RarityTier,
	firstUid: string,
	count: number,
}

type LootGroup = {
	itemId: string,
	name: string,
	tier: GameConfig.RarityTier,
	unitValue: number,
	iconText: string,
	count: number,
}

type BenchTracker = {
	statusLabel: TextLabel,
	progressFill: Frame?,
}

type ShopGridCardSpec = {
	order: number,
	title: string,
	accentColor: Color3,
	description: string,
	statusText: string,
	buttonText: string,
	canAfford: boolean,
	isMaxed: boolean,
	buildIcon: (Frame, number) -> (),
	onBuy: (() -> ())?,
}

local HudController = {}

local gui: ScreenGui
local cashValueLabel: TextLabel
local stolenValueLabel: TextLabel
local zoneBadgeLabel: TextLabel

local stealthEyeFrame: Frame
local stealthStatusLabel: TextLabel
local suspicionFill: Frame
local hotBagBanner: Frame
local hotBagText: TextLabel
local backpackBadge: TextLabel

local toastContainer: Frame
local bustFlashFrame: Frame

local activeModal: string? = nil
local activeStashTab: StashTabId = "Workbenches"
local activeShopTab: ShopTabId = "Upgrades"

local screenDimmer: Frame
local modalBackdrop: Frame
local modalTitle: TextLabel
local modalTabBar: Frame
local modalScroll: ScrollingFrame
local modalFooter: Frame
local popupOverlay: Frame
local modalBenchTrackers: { [number]: BenchTracker } = {}

-- Forward-declared modal renderer reference for tab switching callbacks
local requestModalRefresh: ((boolean) -> ())? = nil

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
	zIndex: number?,
	fixedTextSize: number?
): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Font = font
	lbl.Text = text
	lbl.TextColor3 = color
	if fixedTextSize then
		lbl.TextScaled = false
		lbl.TextSize = fixedTextSize
	else
		lbl.TextScaled = true
	end
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
	zIndex: number?,
	fixedTextSize: number?
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
	if fixedTextSize then
		btn.TextScaled = false
		btn.TextSize = fixedTextSize
	else
		btn.TextScaled = true
	end
	btn.ZIndex = zIndex or (if parent:IsA("GuiObject") then parent.ZIndex + 1 else 2)
	btn.Parent = parent
	addCorner(btn, cornerRadius or 10)
	return btn
end

local function closeCrackPopup(): ()
	if popupOverlay then
		for _, child in ipairs(popupOverlay:GetChildren()) do
			child:Destroy()
		end
		popupOverlay.Visible = false
	end
end

local function clearModalContents(resetScrollPos: boolean?): ()
	table.clear(modalBenchTrackers)
	closeCrackPopup()
	for _, child in ipairs(modalScroll:GetChildren()) do
		child:Destroy()
	end
	for _, child in ipairs(modalTabBar:GetChildren()) do
		child:Destroy()
	end
	for _, child in ipairs(modalFooter:GetChildren()) do
		child:Destroy()
	end
	if resetScrollPos then
		modalScroll.CanvasPosition = Vector2.zero
	end
end

local function configureScrollMode(useGrid: boolean, hasTabs: boolean, hasFooter: boolean, cellW: number?, cellH: number?): ()
	local topY = if hasTabs then 96 else 52
	local bottomSpace = if hasFooter then 48 else 14
	modalTabBar.Visible = hasTabs
	modalFooter.Visible = hasFooter
	modalScroll.Position = UDim2.fromOffset(14, topY)
	modalScroll.Size = UDim2.new(1, -28, 1, -(topY + bottomSpace))

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = modalScroll

	if useGrid then
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(cellW or 122, cellH or 134)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
		grid.Parent = modalScroll
	else
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = modalScroll
	end
end

local function buildModalTabs(tabs: { { id: string, label: string } }, activeId: string, onSelect: (string) -> ()): ()
	local count = #tabs
	local gap = 8
	for idx, tab in ipairs(tabs) do
		local isActive = tab.id == activeId
		local wScale = 1 / count
		local xOffset = (idx - 1) * gap
		local btn = makeButton(
			modalTabBar,
			tab.label,
			UDim2.new(wScale, -((count - 1) * gap) / count, 1, 0),
			UDim2.new(wScale * (idx - 1), xOffset, 0, 0),
			if isActive then Color3.fromRGB(54, 152, 245) else Color3.fromRGB(34, 44, 68),
			if isActive then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(182, 198, 224),
			10,
			22,
			15
		)
		addStroke(btn, if isActive then Color3.fromRGB(128, 218, 255) else Color3.fromRGB(58, 74, 106), 1.6)
		btn.Activated:Connect(function()
			if activeId ~= tab.id then
				onSelect(tab.id)
			end
		end)
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
	if not isOpen then
		closeCrackPopup()
	end
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

	-- Keep at most 3 stacked toasts
	local existingCards: { Frame } = {}
	for _, child in ipairs(toastContainer:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(existingCards, child)
		end
	end
	if #existingCards >= 3 then
		existingCards[1]:Destroy()
	end

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 38)
	card.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.ZIndex = 30
	card.Parent = toastContainer
	addCorner(card, 10)
	addStroke(card, accent, 2, 0.1)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card

	local lbl = makeLabel(
		card,
		message,
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0, 0),
		Enum.Font.GothamBold,
		Color3.fromRGB(248, 250, 255),
		Enum.TextXAlignment.Center,
		31,
		17
	)
	lbl.TextWrapped = false
	local lblStroke = addStroke(lbl, Color3.fromRGB(8, 12, 20), 1.8, 0.1)

	task.delay(2.6, function()
		if card and card.Parent then
			local fade = TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			TweenService:Create(lblStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			fade:Play()
			fade.Completed:Connect(function()
				if card then
					card:Destroy()
				end
			end)
		end
	end)
end

local function makeCardRow(order: number, heightPx: number, strokeColor: Color3): Frame
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, heightPx)
	card.BackgroundColor3 = Color3.fromRGB(30, 38, 56)
	card.BorderSizePixel = 0
	card.ZIndex = 22
	card.Parent = modalScroll
	addCorner(card, 12)
	addStroke(card, strokeColor, 1.8, 0.12)
	return card
end

local function makeDuplicateBadge(parent: Instance, count: number, zIndex: number): ()
	if count <= 1 then
		return
	end
	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.fromOffset(36, 20)
	badge.Position = UDim2.new(1, -40, 0, 4)
	badge.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	badge.BorderSizePixel = 0
	badge.Font = Enum.Font.GothamBlack
	badge.Text = "x" .. tostring(count)
	badge.TextColor3 = Color3.fromRGB(255, 224, 96)
	badge.TextSize = 13
	badge.ZIndex = zIndex
	badge.Parent = parent
	addCorner(badge, 7)
	addStroke(badge, Color3.fromRGB(255, 202, 68), 1.4)
end

local function openCrackPopup(group: StashedGroup, snap: ClientState.ClientSnapshot): ()
	closeCrackPopup()
	popupOverlay.Visible = true

	-- Clickable dimmer backing inside the modal
	local dimmerBtn = Instance.new("TextButton")
	dimmerBtn.Size = UDim2.fromScale(1, 1)
	dimmerBtn.BackgroundColor3 = Color3.fromRGB(6, 10, 18)
	dimmerBtn.BackgroundTransparency = 0.35
	dimmerBtn.Text = ""
	dimmerBtn.AutoButtonColor = false
	dimmerBtn.BorderSizePixel = 0
	dimmerBtn.ZIndex = 25
	dimmerBtn.Parent = popupOverlay
	addCorner(dimmerBtn, 16)
	dimmerBtn.Activated:Connect(closeCrackPopup)

	local tierColor = GameConfig.TIER_COLORS[group.tier]
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(400, 272)
	box.Position = UDim2.new(0.5, -200, 0.5, -136)
	box.BackgroundColor3 = Color3.fromRGB(24, 32, 50)
	box.BorderSizePixel = 0
	box.ZIndex = 26
	box.Parent = popupOverlay
	addCorner(box, 14)
	addStroke(box, tierColor, 2.4)

	-- Block clicks passing through box to dimmerBtn
	local blocker = Instance.new("TextButton")
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.ZIndex = 26
	blocker.Parent = box

	local iconHolder = Instance.new("Frame")
	iconHolder.Size = UDim2.fromOffset(58, 58)
	iconHolder.Position = UDim2.fromOffset(14, 14)
	iconHolder.BackgroundColor3 = Color3.fromRGB(34, 44, 68)
	iconHolder.BorderSizePixel = 0
	iconHolder.ZIndex = 27
	iconHolder.Parent = box
	addCorner(iconHolder, 10)
	addStroke(iconHolder, tierColor, 1.5, 0.2)
	HudIcons.CreateLuggageIcon(iconHolder, GameConfig.GetArchetype(group.archetypeId), UDim2.fromScale(0.88, 0.88), UDim2.fromScale(0.06, 0.06), 28)

	makeLabel(box, group.displayName, UDim2.fromOffset(266, 24), UDim2.fromOffset(82, 14), Enum.Font.GothamBlack, Color3.fromRGB(248, 250, 255), nil, 27, 17)
	makeLabel(box, string.format("[%s] Choose a Workbench", group.tier), UDim2.fromOffset(266, 18), UDim2.fromOffset(82, 40), Enum.Font.GothamBold, tierColor, nil, 27, 13)

	local cancelBtn = makeButton(box, "X", UDim2.fromOffset(30, 30), UDim2.new(1, -40, 0, 12), Color3.fromRGB(178, 52, 64), Color3.fromRGB(255, 255, 255), 8, 27, 14)
	cancelBtn.Activated:Connect(closeCrackPopup)

	local canCrack = GameConfig.CanToolCrackTier(snap.UpgradeLevels.Tool, group.tier)
	local toolNoteText = "Select an open bench below:"
	local toolNoteColor = Color3.fromRGB(186, 206, 232)
	if not canCrack then
		local neededTool = GameConfig.GetToolUpgrade(2)
		for _, t in ipairs(GameConfig.CRACKING_TOOLS) do
			if GameConfig.TIER_RANK[t.maxBagTier] >= GameConfig.TIER_RANK[group.tier] then
				neededTool = t
				break
			end
		end
		toolNoteText = string.format("Requires %s (Lv.%d) in Shop!", neededTool.name, neededTool.level)
		toolNoteColor = Color3.fromRGB(255, 132, 118)
	end
	makeLabel(box, toolNoteText, UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 80), Enum.Font.GothamBold, toolNoteColor, Enum.TextXAlignment.Center, 27, 13)

	-- 2x2 grid of Crack #1 .. Crack #4 buttons
	for idx = 1, 4 do
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local bx = 16 + col * 188
		local by = 108 + row * 72

		local slot = snap.WorkbenchSlots[idx]
		local isUnlocked = idx <= snap.UpgradeLevels.WorkbenchCount
		local isBusy = slot ~= nil and slot.bagUid ~= nil

		if not isUnlocked then
			local lockedBtn = makeButton(box, string.format("Crack #%d\nLocked", idx), UDim2.fromOffset(178, 60), UDim2.fromOffset(bx, by), Color3.fromRGB(48, 54, 68), Color3.fromRGB(142, 152, 172), 10, 27, 14)
			lockedBtn.Active = false
			lockedBtn.AutoButtonColor = false
			addStroke(lockedBtn, Color3.fromRGB(74, 82, 102), 1.4)
		elseif isBusy then
			local busyBtn = makeButton(box, string.format("Crack #%d\nBusy", idx), UDim2.fromOffset(178, 60), UDim2.fromOffset(bx, by), Color3.fromRGB(58, 54, 48), Color3.fromRGB(194, 176, 136), 10, 27, 14)
			busyBtn.Active = false
			busyBtn.AutoButtonColor = false
			addStroke(busyBtn, Color3.fromRGB(118, 98, 64), 1.4)
		else
			local goBtn = makeButton(box, string.format("Crack #%d", idx), UDim2.fromOffset(178, 60), UDim2.fromOffset(bx, by), Color3.fromRGB(52, 162, 248), Color3.fromRGB(255, 255, 255), 10, 27, 16)
			addStroke(goBtn, Color3.fromRGB(122, 214, 255), 1.8)
			goBtn.Activated:Connect(function()
				closeCrackPopup()
				ClientState.PlaceOnWorkbench(group.firstUid, idx)
			end)
		end
	end
end

local function buildStashedGroups(list: { ClientState.ClientStashedBag }): { StashedGroup }
	local byArch: { [string]: StashedGroup } = {}
	local groups: { StashedGroup } = {}
	for _, bag in ipairs(list) do
		local g = byArch[bag.archetypeId]
		if g then
			g.count += 1
		else
			local created: StashedGroup = {
				archetypeId = bag.archetypeId,
				displayName = bag.displayName,
				tier = bag.tier,
				firstUid = bag.uid,
				count = 1,
			}
			byArch[bag.archetypeId] = created
			table.insert(groups, created)
		end
	end
	table.sort(groups, function(a: StashedGroup, b: StashedGroup): boolean
		local rA = GameConfig.TIER_RANK[a.tier] or 0
		local rB = GameConfig.TIER_RANK[b.tier] or 0
		if rA ~= rB then
			return rA > rB
		end
		return a.displayName < b.displayName
	end)
	return groups
end

local function buildLootGroups(list: { ClientState.ClientLootEntry }): ({ LootGroup }, number)
	local byItem: { [string]: LootGroup } = {}
	local groups: { LootGroup } = {}
	local totalValue = 0
	for _, entry in ipairs(list) do
		totalValue += entry.value
		local g = byItem[entry.itemId]
		if g then
			g.count += 1
		else
			local created: LootGroup = {
				itemId = entry.itemId,
				name = entry.name,
				tier = entry.tier,
				unitValue = entry.value,
				iconText = entry.iconText,
				count = 1,
			}
			byItem[entry.itemId] = created
			table.insert(groups, created)
		end
	end
	table.sort(groups, function(a: LootGroup, b: LootGroup): boolean
		local rA = GameConfig.TIER_RANK[a.tier] or 0
		local rB = GameConfig.TIER_RANK[b.tier] or 0
		if rA ~= rB then
			return rA > rB
		end
		return a.unitValue > b.unitValue
	end)
	return groups, totalValue
end

local function renderWorkbenchesTab(snap: ClientState.ClientSnapshot): ()
	configureScrollMode(false, true, false)
	local order = 1
	local now = Workspace:GetServerTimeNow()

	if snap.CarriedLuggage then
		local c = snap.CarriedLuggage
		local hotCard = makeCardRow(order, 50, Color3.fromRGB(255, 104, 88))
		order += 1
		makeLabel(hotCard, string.format("CARRYING HOT BAG: [%s] %s", c.tier, c.displayName), UDim2.new(0.95, 0, 0, 22), UDim2.fromOffset(12, 4), Enum.Font.GothamBold, GameConfig.TIER_COLORS[c.tier], nil, 23, 14)
		makeLabel(hotCard, "Run south back into the Smuggler's Hideout to bank it into Stash!", UDim2.new(0.95, 0, 0, 18), UDim2.fromOffset(12, 26), Enum.Font.GothamMedium, Color3.fromRGB(228, 236, 248), nil, 23, 12)
	end

	for idx = 1, 4 do
		local slot = snap.WorkbenchSlots[idx]
		local unlocked = idx <= snap.UpgradeLevels.WorkbenchCount

		local strokeColor = if not unlocked
			then Color3.fromRGB(72, 80, 100)
			elseif slot and slot.isReady then Color3.fromRGB(68, 255, 148)
			elseif slot and slot.bagUid then Color3.fromRGB(255, 196, 56)
			else Color3.fromRGB(72, 206, 255)

		local card = makeCardRow(order, 88, strokeColor)
		order += 1

		-- Left icon frame inside card
		local iconFrame = Instance.new("Frame")
		iconFrame.Size = UDim2.fromOffset(66, 66)
		iconFrame.Position = UDim2.fromOffset(11, 11)
		iconFrame.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
		iconFrame.BorderSizePixel = 0
		iconFrame.ZIndex = 23
		iconFrame.Parent = card
		addCorner(iconFrame, 10)
		addStroke(iconFrame, strokeColor, 1.5, 0.25)

		if not unlocked then
			local nextCost = GameConfig.GetWorkbenchUpgrade(idx).cost
			HudIcons.CreateUpgradeIcon(iconFrame, "WorkbenchCount", Color3.fromRGB(130, 142, 166), UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07), 24)
			makeLabel(card, string.format("Workbench #%d", idx), UDim2.fromOffset(360, 24), UDim2.fromOffset(88, 16), Enum.Font.GothamBold, Color3.fromRGB(190, 200, 218), nil, 23, 16)
			makeLabel(card, string.format("Locked — Unlock in Shop (%s)", GameConfig.FormatCash(nextCost)), UDim2.fromOffset(380, 20), UDim2.fromOffset(88, 44), Enum.Font.GothamMedium, Color3.fromRGB(152, 164, 186), nil, 23, 13)
		elseif slot and slot.bagUid then
			local dur = math.max(1, slot.duration or 10)
			local rem = math.max(0, (slot.endsAt or now) - now)
			local ready = slot.isReady or rem <= 0
			local pct = if ready then 1 else math.clamp(1 - rem / dur, 0, 1)

			local arch = if slot.archetypeId then GameConfig.GetArchetype(slot.archetypeId) else nil
			HudIcons.CreateLuggageIcon(iconFrame, arch, UDim2.fromScale(0.88, 0.88), UDim2.fromScale(0.06, 0.06), 24)

			local tierTag = slot.tier or "Common"
			local tierColor = GameConfig.TIER_COLORS[tierTag]
			makeLabel(card, string.format("Workbench #%d • [%s] %s", idx, tierTag, slot.displayName or "Bag"), UDim2.new(1, -240, 0, 22), UDim2.fromOffset(88, 10), Enum.Font.GothamBold, tierColor, nil, 23, 15)

			local statusLbl = makeLabel(
				card,
				if ready then "READY TO CLAIM!" else string.format("Cracking: %ds left", math.ceil(rem)),
				UDim2.new(1, -240, 0, 20),
				UDim2.fromOffset(88, 34),
				Enum.Font.GothamMedium,
				if ready then Color3.fromRGB(82, 255, 158) else Color3.fromRGB(255, 222, 128),
				nil,
				23,
				13
			)

			-- Smooth visual progress bar (0% -> 100%)
			local barWidth = if ready then UDim2.new(1, -246, 0, 12) else UDim2.new(1, -104, 0, 12)
			local barBg = Instance.new("Frame")
			barBg.Size = barWidth
			barBg.Position = UDim2.fromOffset(88, 60)
			barBg.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
			barBg.BorderSizePixel = 0
			barBg.ZIndex = 23
			barBg.Parent = card
			addCorner(barBg, 6)
			addStroke(barBg, Color3.fromRGB(58, 72, 98), 1.2)

			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(pct, 1)
			barFill.BackgroundColor3 = if ready then Color3.fromRGB(68, 255, 148) else Color3.fromRGB(255, 194, 58)
			barFill.BorderSizePixel = 0
			barFill.ZIndex = 24
			barFill.Parent = barBg
			addCorner(barFill, 6)

			modalBenchTrackers[idx] = {
				statusLabel = statusLbl,
				progressFill = barFill,
			}

			if ready then
				local claimBtn = makeButton(card, "Claim", UDim2.fromOffset(128, 44), UDim2.new(1, -142, 0.5, -22), Color3.fromRGB(52, 214, 118), Color3.fromRGB(10, 24, 16), 10, 23, 16)
				addStroke(claimBtn, Color3.fromRGB(142, 255, 186), 1.6)
				claimBtn.Activated:Connect(function()
					ClientState.ClaimOpenedLuggage(idx)
				end)
			end
		else
			HudIcons.CreateUpgradeIcon(iconFrame, "WorkbenchCount", Color3.fromRGB(72, 206, 255), UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07), 24)
			makeLabel(card, string.format("Workbench #%d", idx), UDim2.fromOffset(360, 24), UDim2.fromOffset(88, 16), Enum.Font.GothamBold, Color3.fromRGB(244, 248, 255), nil, 23, 16)
			makeLabel(card, "Ready (Empty)", UDim2.fromOffset(360, 20), UDim2.fromOffset(88, 44), Enum.Font.GothamBold, Color3.fromRGB(118, 224, 255), nil, 23, 14)
		end
	end
end

local function renderStashTab(snap: ClientState.ClientSnapshot): ()
	local groups = buildStashedGroups(snap.StashedLuggage)
	if #groups == 0 then
		configureScrollMode(false, true, false)
		local emptyCard = makeCardRow(1, 90, Color3.fromRGB(64, 74, 98))
		makeLabel(emptyCard, "Stash is Empty", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 20), Enum.Font.GothamBold, Color3.fromRGB(220, 230, 248), Enum.TextXAlignment.Center, 23, 17)
		makeLabel(emptyCard, "Steal unattended luggage from SkyPort Terminals and return south to the Hideout!", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 48), Enum.Font.GothamMedium, Color3.fromRGB(154, 172, 198), Enum.TextXAlignment.Center, 23, 13)
		return
	end

	configureScrollMode(true, true, false, 122, 134)
	for order, group in ipairs(groups) do
		local tierColor = GameConfig.TIER_COLORS[group.tier]
		local tile = Instance.new("TextButton")
		tile.LayoutOrder = order
		tile.BackgroundColor3 = Color3.fromRGB(30, 38, 56)
		tile.BorderSizePixel = 0
		tile.Text = ""
		tile.AutoButtonColor = true
		tile.ZIndex = 22
		tile.Parent = modalScroll
		addCorner(tile, 12)
		addStroke(tile, tierColor, 2.2)

		-- Soft rarity tint overlay at top
		local glowTop = Instance.new("Frame")
		glowTop.Size = UDim2.new(1, 0, 0.36, 0)
		glowTop.BackgroundColor3 = tierColor
		glowTop.BackgroundTransparency = 0.84
		glowTop.BorderSizePixel = 0
		glowTop.ZIndex = 22
		glowTop.Parent = tile
		addCorner(glowTop, 12)

		makeLabel(tile, group.tier:upper(), UDim2.fromOffset(74, 16), UDim2.fromOffset(8, 6), Enum.Font.GothamBlack, tierColor, Enum.TextXAlignment.Left, 23, 11)
		makeDuplicateBadge(tile, group.count, 24)

		HudIcons.CreateLuggageIcon(tile, GameConfig.GetArchetype(group.archetypeId), UDim2.fromOffset(74, 70), UDim2.fromOffset(24, 24), 23)

		local nameLbl = makeLabel(tile, group.displayName, UDim2.new(1, -12, 0, 32), UDim2.new(0, 6, 1, -36), Enum.Font.GothamBold, Color3.fromRGB(244, 248, 255), Enum.TextXAlignment.Center, 23, 12)
		nameLbl.TextWrapped = true

		tile.Activated:Connect(function()
			openCrackPopup(group, snap)
		end)
	end
end

local function renderValuablesTab(snap: ClientState.ClientSnapshot): ()
	local groups, totalVal = buildLootGroups(snap.RevealedLoot)
	if #groups == 0 then
		configureScrollMode(false, true, false)
		local emptyCard = makeCardRow(1, 90, Color3.fromRGB(64, 74, 98))
		makeLabel(emptyCard, "No Valuables Yet", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 20), Enum.Font.GothamBold, Color3.fromRGB(220, 230, 248), Enum.TextXAlignment.Center, 23, 17)
		makeLabel(emptyCard, "Crack luggage on Workbenches to reveal high-value loot, then sell at Vinnie's Fence!", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 48), Enum.Font.GothamMedium, Color3.fromRGB(154, 172, 198), Enum.TextXAlignment.Center, 23, 13)
		return
	end

	configureScrollMode(true, true, true, 122, 134)
	for order, group in ipairs(groups) do
		local tierColor = GameConfig.TIER_COLORS[group.tier]
		local tile = Instance.new("Frame")
		tile.LayoutOrder = order
		tile.BackgroundColor3 = Color3.fromRGB(30, 38, 56)
		tile.BorderSizePixel = 0
		tile.ZIndex = 22
		tile.Parent = modalScroll
		addCorner(tile, 12)
		addStroke(tile, tierColor, 2.2)

		local glowTop = Instance.new("Frame")
		glowTop.Size = UDim2.new(1, 0, 0.36, 0)
		glowTop.BackgroundColor3 = tierColor
		glowTop.BackgroundTransparency = 0.84
		glowTop.BorderSizePixel = 0
		glowTop.ZIndex = 22
		glowTop.Parent = tile
		addCorner(glowTop, 12)

		makeLabel(tile, group.tier:upper(), UDim2.fromOffset(74, 16), UDim2.fromOffset(8, 6), Enum.Font.GothamBlack, tierColor, Enum.TextXAlignment.Left, 23, 11)
		makeDuplicateBadge(tile, group.count, 24)

		HudIcons.CreateLootIcon(tile, group.itemId, group.tier, group.iconText, UDim2.fromOffset(66, 62), UDim2.fromOffset(28, 22), 23)

		local nameLbl = makeLabel(tile, group.name, UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 1, -44), Enum.Font.GothamBold, Color3.fromRGB(242, 246, 255), Enum.TextXAlignment.Center, 23, 11)
		nameLbl.TextWrapped = true

		makeLabel(tile, GameConfig.FormatCash(group.unitValue), UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 1, -21), Enum.Font.GothamBlack, Color3.fromRGB(108, 255, 164), Enum.TextXAlignment.Center, 23, 13)
	end

	-- Non-clickable info bar reminding player where to sell (zero Sell buttons inside inventory)
	local infoBar = Instance.new("Frame")
	infoBar.Size = UDim2.fromScale(1, 1)
	infoBar.BackgroundColor3 = Color3.fromRGB(28, 38, 56)
	infoBar.BorderSizePixel = 0
	infoBar.ZIndex = 22
	infoBar.Parent = modalFooter
	addCorner(infoBar, 10)
	addStroke(infoBar, Color3.fromRGB(82, 212, 142), 1.5, 0.25)
	makeLabel(
		infoBar,
		string.format("Total Loot Value: %s  •  Sell at Vinnie's Fence [E] in Hideout", GameConfig.FormatCash(totalVal)),
		UDim2.new(1, -16, 1, 0),
		UDim2.fromOffset(8, 0),
		Enum.Font.GothamBold,
		Color3.fromRGB(168, 248, 198),
		Enum.TextXAlignment.Center,
		23,
		14
	)
end

local function renderBackpackModal(snap: ClientState.ClientSnapshot): ()
	modalTitle.Text = "STASH & INVENTORY"
	clearModalContents(false)

	local readyCount = 0
	for _, slot in ipairs(snap.WorkbenchSlots) do
		if slot.isReady then
			readyCount += 1
		end
	end
	local benchLabel = if readyCount > 0 then string.format("Workbenches (%d!)", readyCount) else "Workbenches"

	buildModalTabs({
		{ id = "Workbenches", label = benchLabel },
		{ id = "Stash", label = string.format("Stash (%d)", #snap.StashedLuggage) },
		{ id = "Valuables", label = string.format("Valuables (%d)", #snap.RevealedLoot) },
	}, activeStashTab, function(tabId: string)
		activeStashTab = tabId :: StashTabId
		if requestModalRefresh then
			requestModalRefresh(true)
		end
	end)

	if activeStashTab == "Workbenches" then
		renderWorkbenchesTab(snap)
	elseif activeStashTab == "Stash" then
		renderStashTab(snap)
	else
		renderValuablesTab(snap)
	end
end

local function buildShopGridCard(spec: ShopGridCardSpec): ()
	local card = Instance.new("Frame")
	card.LayoutOrder = spec.order
	card.BackgroundColor3 = Color3.fromRGB(30, 38, 56)
	card.BorderSizePixel = 0
	card.ZIndex = 22
	card.Parent = modalScroll
	addCorner(card, 12)
	addStroke(card, spec.accentColor, 2.2)

	-- Colored header tint bar
	local topBand = Instance.new("Frame")
	topBand.Size = UDim2.new(1, 0, 0, 34)
	topBand.BackgroundColor3 = spec.accentColor
	topBand.BackgroundTransparency = 0.82
	topBand.BorderSizePixel = 0
	topBand.ZIndex = 22
	topBand.Parent = card
	addCorner(topBand, 12)

	makeLabel(card, spec.title, UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 5), Enum.Font.GothamBlack, spec.accentColor, Enum.TextXAlignment.Center, 23, 14)

	local iconHost = Instance.new("Frame")
	iconHost.Size = UDim2.fromOffset(82, 82)
	iconHost.Position = UDim2.new(0.5, -41, 0, 38)
	iconHost.BackgroundTransparency = 1
	iconHost.BorderSizePixel = 0
	iconHost.ZIndex = 23
	iconHost.Parent = card
	spec.buildIcon(iconHost, 23)

	local descLbl = makeLabel(card, spec.description, UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 122), Enum.Font.GothamMedium, Color3.fromRGB(196, 212, 236), Enum.TextXAlignment.Center, 23, 12)
	descLbl.TextWrapped = true

	makeLabel(card, spec.statusText, UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 164), Enum.Font.GothamBold, Color3.fromRGB(238, 244, 255), Enum.TextXAlignment.Center, 23, 12)

	if spec.isMaxed then
		local maxBtn = makeButton(card, "[MAX]", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 1, -44), Color3.fromRGB(46, 178, 108), Color3.fromRGB(14, 26, 18), 9, 23, 15)
		maxBtn.Active = false
		maxBtn.AutoButtonColor = false
		addStroke(maxBtn, Color3.fromRGB(122, 255, 178), 1.4)
	else
		local btnBg = if spec.canAfford then Color3.fromRGB(52, 198, 118) else Color3.fromRGB(58, 66, 86)
		local btnTextCol = if spec.canAfford then Color3.fromRGB(10, 24, 16) else Color3.fromRGB(184, 196, 218)
		local buyBtn = makeButton(card, spec.buttonText, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 1, -44), btnBg, btnTextCol, 9, 23, 15)
		if spec.canAfford then
			addStroke(buyBtn, Color3.fromRGB(132, 255, 186), 1.5)
		end
		buyBtn.Activated:Connect(function()
			if spec.onBuy then
				spec.onBuy()
			end
		end)
	end
end

local function renderShopModal(snap: ClientState.ClientSnapshot): ()
	modalTitle.Text = "BLACK-MARKET SHOP"
	clearModalContents(false)

	buildModalTabs({
		{ id = "Upgrades", label = "Upgrades" },
		{ id = "Items", label = "Items" },
	}, activeShopTab, function(tabId: string)
		activeShopTab = tabId :: ShopTabId
		if requestModalRefresh then
			requestModalRefresh(true)
		end
	end)

	-- 3-column grid (3 x N rows) for both Upgrades & Items tabs
	configureScrollMode(true, true, false, 208, 234)

	if activeShopTab == "Upgrades" then
		local toolLvl = snap.UpgradeLevels.Tool
		local curTool = GameConfig.GetToolUpgrade(toolLvl)
		local isMaxTool = toolLvl >= #GameConfig.CRACKING_TOOLS
		local nextTool = if not isMaxTool then GameConfig.GetToolUpgrade(toolLvl + 1) else curTool
		buildShopGridCard({
			order = 1,
			title = "CRACKING TOOLS",
			accentColor = curTool.color,
			description = if isMaxTool then "3.2x speed & cuts Godly vaults." else nextTool.description,
			statusText = string.format("Lvl. %d/%d • %s", toolLvl, #GameConfig.CRACKING_TOOLS, curTool.name),
			buttonText = GameConfig.FormatCash(nextTool.cost),
			canAfford = snap.Cash >= nextTool.cost,
			isMaxed = isMaxTool,
			buildIcon = function(host: Frame, z: number): ()
				HudIcons.CreateUpgradeIcon(host, "Tool", curTool.color, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), z)
			end,
			onBuy = function()
				ClientState.BuyUpgrade("Tool")
			end,
		})

		local benchLvl = snap.UpgradeLevels.WorkbenchCount
		local curBench = GameConfig.GetWorkbenchUpgrade(benchLvl)
		local isMaxBench = benchLvl >= #GameConfig.WORKBENCH_UPGRADES
		local nextBench = if not isMaxBench then GameConfig.GetWorkbenchUpgrade(benchLvl + 1) else curBench
		buildShopGridCard({
			order = 2,
			title = "EXTRA WORKBENCHES",
			accentColor = Color3.fromRGB(255, 196, 68),
			description = if isMaxBench then "All 4 cracking stations active." else nextBench.description,
			statusText = string.format("Lvl. %d/%d • %s", benchLvl, #GameConfig.WORKBENCH_UPGRADES, curBench.name),
			buttonText = GameConfig.FormatCash(nextBench.cost),
			canAfford = snap.Cash >= nextBench.cost,
			isMaxed = isMaxBench,
			buildIcon = function(host: Frame, z: number): ()
				HudIcons.CreateUpgradeIcon(host, "WorkbenchCount", Color3.fromRGB(255, 196, 68), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), z)
			end,
			onBuy = function()
				ClientState.BuyUpgrade("WorkbenchCount")
			end,
		})

		local snkLvl = snap.UpgradeLevels.Sneakers
		local curSnk = GameConfig.GetSneakerUpgrade(snkLvl)
		local isMaxSnk = snkLvl >= #GameConfig.SNEAKER_UPGRADES
		local nextSnk = if not isMaxSnk then GameConfig.GetSneakerUpgrade(snkLvl + 1) else curSnk
		buildShopGridCard({
			order = 3,
			title = "SNEAKERS",
			accentColor = Color3.fromRGB(82, 232, 152),
			description = if isMaxSnk then string.format("Top %d walk speed!", math.floor(curSnk.walkSpeed)) else string.format("Next: Walk Speed %d (%s)", math.floor(nextSnk.walkSpeed), nextSnk.name),
			statusText = string.format("Lvl. %d/%d • %s", snkLvl, #GameConfig.SNEAKER_UPGRADES, curSnk.name),
			buttonText = GameConfig.FormatCash(nextSnk.cost),
			canAfford = snap.Cash >= nextSnk.cost,
			isMaxed = isMaxSnk,
			buildIcon = function(host: Frame, z: number): ()
				HudIcons.CreateUpgradeIcon(host, "Sneakers", Color3.fromRGB(82, 232, 152), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), z)
			end,
			onBuy = function()
				ClientState.BuyUpgrade("Sneakers")
			end,
		})

		local coatLvl = snap.UpgradeLevels.StealthCoat
		local curCoat = GameConfig.GetStealthCoatUpgrade(coatLvl)
		local isMaxCoat = coatLvl >= #GameConfig.STEALTH_COAT_UPGRADES
		local nextCoat = if not isMaxCoat then GameConfig.GetStealthCoatUpgrade(coatLvl + 1) else curCoat
		buildShopGridCard({
			order = 4,
			title = "STEALTH COATS",
			accentColor = Color3.fromRGB(186, 112, 255),
			description = if isMaxCoat then "Minimal enemy cone & suspicion." else nextCoat.description,
			statusText = string.format("Lvl. %d/%d • %s", coatLvl, #GameConfig.STEALTH_COAT_UPGRADES, curCoat.name),
			buttonText = GameConfig.FormatCash(nextCoat.cost),
			canAfford = snap.Cash >= nextCoat.cost,
			isMaxed = isMaxCoat,
			buildIcon = function(host: Frame, z: number): ()
				HudIcons.CreateUpgradeIcon(host, "StealthCoat", Color3.fromRGB(186, 112, 255), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), z)
			end,
			onBuy = function()
				ClientState.BuyUpgrade("StealthCoat")
			end,
		})
	else
		for order, cid in ipairs(GameConfig.CONSUMABLE_ORDER) do
			local def = GameConfig.CONSUMABLES[cid]
			local owned = snap.Consumables[cid] or 0
			buildShopGridCard({
				order = order,
				title = def.name:upper(),
				accentColor = def.color,
				description = def.description,
				statusText = string.format("Owned: %d • [%s]", owned, def.rarity),
				buttonText = GameConfig.FormatCash(def.cost),
				canAfford = snap.Cash >= def.cost,
				isMaxed = false,
				buildIcon = function(host: Frame, z: number): ()
					HudIcons.CreateItemIcon(host, cid, def.color, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), z)
				end,
				onBuy = function()
					ClientState.BuyConsumable(cid)
				end,
			})
		end
	end
end

local function renderTerminalsModal(snap: ClientState.ClientSnapshot): ()
	modalTitle.Text = "SKYPORT TERMINAL PASSES"
	clearModalContents(false)
	configureScrollMode(false, false, false)

	for order, tid in ipairs(GameConfig.TERMINAL_ORDER) do
		local def = GameConfig.TERMINALS[tid]
		local unlocked = snap.UnlockedTerminals[tid] == true
		local row = makeCardRow(order, 82, def.accentColor)

		makeLabel(row, def.name, UDim2.new(0.64, 0, 0, 24), UDim2.fromOffset(14, 8), Enum.Font.GothamBold, def.accentColor, nil, 23, 16)
		makeLabel(row, string.format("%s | Tiers: %s", def.subtitle, table.concat(def.allowedTiers, ", ")), UDim2.new(0.64, 0, 0, 36), UDim2.fromOffset(14, 36), Enum.Font.GothamMedium, Color3.fromRGB(196, 210, 232), nil, 23, 13)

		if unlocked then
			makeLabel(row, "UNLOCKED", UDim2.fromOffset(130, 32), UDim2.new(1, -144, 0.5, -16), Enum.Font.GothamBlack, Color3.fromRGB(78, 255, 162), Enum.TextXAlignment.Center, 23, 16)
		else
			local btn = makeButton(
				row,
				"UNLOCK " .. GameConfig.FormatCash(def.unlockCost),
				UDim2.fromOffset(148, 44),
				UDim2.new(1, -162, 0.5, -22),
				if snap.Cash >= def.unlockCost then def.accentColor else Color3.fromRGB(62, 68, 84),
				Color3.fromRGB(16, 20, 28),
				9,
				23,
				15
			)
			btn.Activated:Connect(function()
				ClientState.UnlockTerminal(tid)
			end)
		end
	end
end

local function refreshActiveModal(resetScrollPos: boolean?): ()
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
	if resetScrollPos then
		modalScroll.CanvasPosition = Vector2.zero
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

	refreshActiveModal(false)
end

local function buildLeftIconButton(
	parent: Instance,
	name: string,
	labelText: string,
	pos: UDim2,
	cardBg: Color3,
	strokeColor: Color3,
	iconBuilder: (Frame, UDim2, UDim2, number) -> Frame,
	onActivated: () -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.fromOffset(88, 104)
	btn.Position = pos
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 4
	btn.Parent = parent

	local badgeFrame = Instance.new("Frame")
	badgeFrame.Size = UDim2.fromOffset(76, 76)
	badgeFrame.Position = UDim2.fromOffset(6, 0)
	badgeFrame.BackgroundColor3 = cardBg
	badgeFrame.BackgroundTransparency = 0.08
	badgeFrame.BorderSizePixel = 0
	badgeFrame.ZIndex = 4
	badgeFrame.Parent = btn
	addCorner(badgeFrame, 20)
	addStroke(badgeFrame, strokeColor, 2.6)

	iconBuilder(badgeFrame, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07), 5)

	local lbl = makeLabel(
		btn,
		labelText,
		UDim2.fromOffset(88, 22),
		UDim2.fromOffset(0, 79),
		Enum.Font.GothamBlack,
		Color3.fromRGB(255, 255, 255),
		Enum.TextXAlignment.Center,
		6,
		16
	)
	addStroke(lbl, Color3.fromRGB(10, 14, 22), 2.4)

	-- Hover/press squash feel
	btn.MouseEnter:Connect(function()
		TweenService:Create(badgeFrame, TweenInfo.new(0.12), { Size = UDim2.fromOffset(82, 82), Position = UDim2.fromOffset(3, -3) }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(badgeFrame, TweenInfo.new(0.12), { Size = UDim2.fromOffset(76, 76), Position = UDim2.fromOffset(6, 0) }):Play()
	end)
	btn.Activated:Connect(onActivated)

	return btn
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

	local stealthEyeCore = Instance.new("Frame")
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

	-- TOAST STACK (crisp larger bold font with stroke outline)
	toastContainer = Instance.new("Frame")
	toastContainer.Size = UDim2.fromOffset(360, 140)
	toastContainer.Position = UDim2.new(0.5, -180, 0, 112)
	toastContainer.BackgroundTransparency = 1
	toastContainer.ZIndex = 30
	toastContainer.Parent = gui
	local toastList = Instance.new("UIListLayout")
	toastList.Padding = UDim.new(0, 6)
	toastList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toastList.Parent = toastContainer

	-- LEFT-SIDE STYLIZED ICON BUTTONS (STASH & SHOP ONLY)
	local leftRail = Instance.new("Frame")
	leftRail.Name = "LeftActionRail"
	leftRail.Size = UDim2.fromOffset(92, 224)
	leftRail.AnchorPoint = Vector2.new(0, 0.5)
	leftRail.Position = UDim2.new(0, 18, 0.5, 0)
	leftRail.BackgroundTransparency = 1
	leftRail.ZIndex = 4
	leftRail.Parent = gui

	local stashDockBtn = buildLeftIconButton(
		leftRail,
		"StashDockBtn",
		"STASH",
		UDim2.fromOffset(0, 0),
		Color3.fromRGB(22, 42, 78),
		Color3.fromRGB(82, 188, 255),
		HudIcons.CreateStashIcon,
		function()
			setModalOpen("Backpack")
			refreshActiveModal(true)
		end
	)

	backpackBadge = Instance.new("TextLabel")
	backpackBadge.Size = UDim2.fromOffset(24, 24)
	backpackBadge.Position = UDim2.fromOffset(62, -4)
	backpackBadge.BackgroundColor3 = Color3.fromRGB(255, 78, 126)
	backpackBadge.Font = Enum.Font.GothamBlack
	backpackBadge.Text = "0"
	backpackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	backpackBadge.TextSize = 13
	backpackBadge.ZIndex = 8
	backpackBadge.Visible = false
	backpackBadge.Parent = stashDockBtn
	addCorner(backpackBadge, 12)
	addStroke(backpackBadge, Color3.fromRGB(255, 255, 255), 1.5)

	buildLeftIconButton(
		leftRail,
		"ShopDockBtn",
		"SHOP",
		UDim2.fromOffset(0, 118),
		Color3.fromRGB(64, 22, 34),
		Color3.fromRGB(255, 92, 112),
		HudIcons.CreateShopIcon,
		function()
			setModalOpen("Shop")
			refreshActiveModal(true)
		end
	)

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

	-- CENTER MODAL CONTAINER (ZIndex 20+, bright contrast)
	modalBackdrop = Instance.new("Frame")
	modalBackdrop.Size = UDim2.fromOffset(700, 500)
	modalBackdrop.Position = UDim2.new(0.5, -350, 0.5, -250)
	modalBackdrop.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
	modalBackdrop.BackgroundTransparency = 0.01
	modalBackdrop.Visible = false
	modalBackdrop.ZIndex = 20
	modalBackdrop.BorderSizePixel = 0
	modalBackdrop.Parent = gui
	addCorner(modalBackdrop, 16)
	addStroke(modalBackdrop, Color3.fromRGB(82, 198, 255), 2.2, 0.1)

	modalTitle = makeLabel(modalBackdrop, "MENU", UDim2.new(1, -76, 0, 32), UDim2.fromOffset(18, 12), Enum.Font.GothamBlack, Color3.fromRGB(245, 248, 255), nil, 21, 22)
	local closeBtn = makeButton(modalBackdrop, "X", UDim2.fromOffset(36, 36), UDim2.new(1, -48, 0, 10), Color3.fromRGB(196, 52, 66), Color3.fromRGB(255, 255, 255), 10, 21, 18)
	addStroke(closeBtn, Color3.fromRGB(255, 146, 158), 1.4)
	closeBtn.Activated:Connect(function()
		setModalOpen(nil)
	end)

	modalTabBar = Instance.new("Frame")
	modalTabBar.Size = UDim2.new(1, -28, 0, 36)
	modalTabBar.Position = UDim2.fromOffset(14, 52)
	modalTabBar.BackgroundTransparency = 1
	modalTabBar.ZIndex = 21
	modalTabBar.Parent = modalBackdrop

	modalScroll = Instance.new("ScrollingFrame")
	modalScroll.Size = UDim2.new(1, -28, 1, -110)
	modalScroll.Position = UDim2.fromOffset(14, 96)
	modalScroll.BackgroundTransparency = 1
	modalScroll.BorderSizePixel = 0
	modalScroll.CanvasSize = UDim2.fromOffset(0, 0)
	modalScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	modalScroll.ScrollBarThickness = 6
	modalScroll.ZIndex = 21
	modalScroll.Parent = modalBackdrop

	modalFooter = Instance.new("Frame")
	modalFooter.Size = UDim2.new(1, -28, 0, 36)
	modalFooter.Position = UDim2.new(0, 14, 1, -44)
	modalFooter.BackgroundTransparency = 1
	modalFooter.ZIndex = 21
	modalFooter.Parent = modalBackdrop

	popupOverlay = Instance.new("Frame")
	popupOverlay.Size = UDim2.fromScale(1, 1)
	popupOverlay.BackgroundTransparency = 1
	popupOverlay.Visible = false
	popupOverlay.ZIndex = 25
	popupOverlay.Parent = modalBackdrop

	requestModalRefresh = refreshActiveModal
end

function HudController.Start(): ()
	buildGui()

	ClientState.OnStateChanged(updateHudFromSnapshot)
	ClientState.OnToast(pushToast)
	ClientState.OnOpenModal(function(modalName: string)
		setModalOpen(modalName)
		refreshActiveModal(true)
	end)
	WorldVisualsController.SetModalCallback(function(modalName: string)
		setModalOpen(modalName)
		refreshActiveModal(true)
	end)

	RunService.RenderStepped:Connect(function()
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
			stealthStatusLabel.Text = "HIDDEN"
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

		-- Smoothly animate Workbenches tab countdowns and progress bars (0% -> 100%)
		local snap = ClientState.GetSnapshot()
		if activeModal == "Backpack" and activeStashTab == "Workbenches" and snap then
			local now = Workspace:GetServerTimeNow()
			for idx, tracker in pairs(modalBenchTrackers) do
				local slot = snap.WorkbenchSlots[idx]
				if slot and slot.bagUid then
					local dur = math.max(1, slot.duration or 10)
					local rem = math.max(0, (slot.endsAt or now) - now)
					local ready = slot.isReady or rem <= 0
					local pct = if ready then 1 else math.clamp(1 - rem / dur, 0, 1)

					if ready then
						tracker.statusLabel.Text = "READY TO CLAIM!"
						tracker.statusLabel.TextColor3 = Color3.fromRGB(82, 255, 158)
					else
						tracker.statusLabel.Text = string.format("Cracking: %ds left", math.ceil(rem))
					end

					if tracker.progressFill then
						tracker.progressFill.Size = UDim2.fromScale(pct, 1)
						if ready then
							tracker.progressFill.BackgroundColor3 = Color3.fromRGB(68, 255, 148)
						end
					end
				end
			end
		end
	end)
end

return HudController
