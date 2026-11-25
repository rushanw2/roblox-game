--!strict
-- Tabbed Backpack & Anime Girl Companion Management Drawer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientFolder = script.Parent
local ClientState = require(ClientFolder:WaitForChild("ClientState"))

type InventoryTab = "Raw" | "Cleaned" | "Pets"

local InventoryUI = {}

local panelFrame: Frame
local scrollList: ScrollingFrame
local summaryBanner: TextLabel
local tabButtons: { [InventoryTab]: TextButton } = {}
local activeTab: InventoryTab = "Raw"

local function addCorner(inst: GuiObject, radiusPx: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radiusPx)
	c.Parent = inst
end

local function addStroke(inst: GuiObject, color: Color3, thickness: number): ()
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = inst
end

local function clearScrollContents(): ()
	for _, child in ipairs(scrollList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function updateTabButtonStyles(): ()
	for tabName, btn in pairs(tabButtons) do
		local selected = tabName == activeTab
		btn.BackgroundColor3 = if selected then Color3.fromRGB(48, 128, 196) else Color3.fromRGB(24, 36, 64)
		btn.TextColor3 = if selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(168, 192, 224)
	end
end

local function createEmptyNotice(message: string): ()
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -12, 0, 72)
	lbl.BackgroundTransparency = 1
	lbl.Text = message
	lbl.TextColor3 = Color3.fromRGB(168, 188, 214)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamMedium
	lbl.Parent = scrollList
end

local function renderRawRelics(state: ClientState.ClientSnapshot): ()
	summaryBanner.Text = string.format(
		"Uncleaned Relics (%d) — Scrub at the Harbor Cleaning Station! Watch out: Blackouts drop uncleaned finds.",
		#state.profile.RawRelics
	)

	if #state.profile.RawRelics == 0 then
		createEmptyNotice("No raw encrusted relics right now. Dive into the ocean and excavate!")
		return
	end

	for index, entry in ipairs(state.profile.RawRelics) do
		local cfg = GameConfig.RELICS[entry.itemId]
		if cfg then
			local meta = GameConfig.RARITY_META[cfg.rarity]
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 68)
			row.LayoutOrder = index
			row.BackgroundColor3 = Color3.fromRGB(24, 34, 60)
			row.Parent = scrollList
			addCorner(row, 10)
			addStroke(row, meta.color, 1.5)

			local swatch = Instance.new("Frame")
			swatch.Position = UDim2.new(0, 10, 0.5, -20)
			swatch.Size = UDim2.fromOffset(40, 40)
			swatch.BackgroundColor3 = cfg.color
			swatch.Parent = row
			addCorner(swatch, 8)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 60, 0, 8)
			nameLbl.Size = UDim2.new(0.56, -40, 0, 26)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = string.format("[%s] %s", cfg.rarity, cfg.name)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextColor3 = meta.color
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.Parent = row

			local descLbl = Instance.new("TextLabel")
			descLbl.Position = UDim2.new(0, 60, 0, 36)
			descLbl.Size = UDim2.new(0.60, -40, 0, 24)
			descLbl.BackgroundTransparency = 1
			descLbl.Text = string.format("%s • Scrub Time: %ds", cfg.category, cfg.cleanDuration)
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.TextColor3 = Color3.fromRGB(192, 210, 236)
			descLbl.TextScaled = true
			descLbl.Font = Enum.Font.GothamMedium
			descLbl.Parent = row

			local cleanBtn = Instance.new("TextButton")
			cleanBtn.AnchorPoint = Vector2.new(1, 0.5)
			cleanBtn.Position = UDim2.new(1, -12, 0.5, 0)
			cleanBtn.Size = UDim2.fromOffset(124, 38)
			cleanBtn.BackgroundColor3 = Color3.fromRGB(54, 162, 224)
			cleanBtn.Text = "Clean Relic"
			cleanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			cleanBtn.TextScaled = true
			cleanBtn.Font = Enum.Font.GothamBold
			cleanBtn.Parent = row
			addCorner(cleanBtn, 8)

			cleanBtn.MouseButton1Click:Connect(function()
				local ok, res = pcall(function(): any
					return Remotes.StartCleaning:InvokeServer(entry.uid, nil)
				end)
				if ok and typeof(res) == "table" then
					if res.success then
						ClientState.EmitLocalToast(res.message or "Started cleaning!", "Info")
					else
						ClientState.EmitLocalToast(res.message or "Walk to Cleaning Station!", "Warn")
					end
				end
			end)
		end
	end
end

local function renderCleanedRelics(state: ClientState.ClientSnapshot): ()
	local passives = ClientState.GetTotalPetPassives()
	local totalBase = 0
	for _, entry in ipairs(state.profile.CleanedRelics) do
		local cfg = GameConfig.RELICS[entry.itemId]
		if cfg then
			totalBase += cfg.sellValue
		end
	end
	local boostedTotal = math.floor(totalBase * (1 + passives.coinMultiplierBonus) + 0.5)

	summaryBanner.Text = string.format(
		"Appraised Treasures (%d) — Est. Payout: %s Coins (+%d%% Companion Bonus)",
		#state.profile.CleanedRelics,
		GameConfig.FormatNumber(boostedTotal),
		math.floor(passives.coinMultiplierBonus * 100 + 0.5)
	)

	if #state.profile.CleanedRelics == 0 then
		createEmptyNotice("No cleaned relics yet! Clean raw relics or find clean treasures underwater.")
		return
	end

	for index, entry in ipairs(state.profile.CleanedRelics) do
		local cfg = GameConfig.RELICS[entry.itemId]
		if cfg then
			local meta = GameConfig.RARITY_META[cfg.rarity]
			local boostedVal = math.floor(cfg.sellValue * (1 + passives.coinMultiplierBonus) + 0.5)

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 64)
			row.LayoutOrder = index
			row.BackgroundColor3 = Color3.fromRGB(24, 34, 60)
			row.Parent = scrollList
			addCorner(row, 10)
			addStroke(row, meta.color, 1.5)

			local swatch = Instance.new("Frame")
			swatch.Position = UDim2.new(0, 10, 0.5, -18)
			swatch.Size = UDim2.fromOffset(36, 36)
			swatch.BackgroundColor3 = cfg.color
			swatch.Parent = row
			addCorner(swatch, 8)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 56, 0, 8)
			nameLbl.Size = UDim2.new(0.62, -40, 0, 26)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = string.format("[%s] %s", cfg.rarity, cfg.name)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextColor3 = meta.color
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.Parent = row

			local descLbl = Instance.new("TextLabel")
			descLbl.Position = UDim2.new(0, 56, 0, 34)
			descLbl.Size = UDim2.new(0.66, -40, 0, 22)
			descLbl.BackgroundTransparency = 1
			descLbl.Text = cfg.category .. " • " .. cfg.description
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.TextColor3 = Color3.fromRGB(186, 204, 228)
			descLbl.TextScaled = true
			descLbl.Font = Enum.Font.GothamMedium
			descLbl.Parent = row

			local valLbl = Instance.new("TextLabel")
			valLbl.AnchorPoint = Vector2.new(1, 0.5)
			valLbl.Position = UDim2.new(1, -12, 0.5, 0)
			valLbl.Size = UDim2.fromOffset(128, 32)
			valLbl.BackgroundTransparency = 1
			valLbl.Text = GameConfig.FormatNumber(boostedVal) .. " Coins"
			valLbl.TextXAlignment = Enum.TextXAlignment.Right
			valLbl.TextColor3 = Color3.fromRGB(255, 218, 92)
			valLbl.TextScaled = true
			valLbl.Font = Enum.Font.GothamBold
			valLbl.Parent = row
		end
	end
end

local function renderPets(state: ClientState.ClientSnapshot): ()
	local passives = ClientState.GetTotalPetPassives()
	summaryBanner.Text = string.format(
		"Equipped %d/%d  |  +%d O2  •  +%d Swim  •  +%d%% Dig  •  +%d%% Clean  •  +%d%% Coins",
		#state.profile.EquippedPetIds,
		GameConfig.MAX_EQUIPPED_PETS,
		math.floor(passives.oxygenCapacityBonus),
		math.floor(passives.swimSpeedBonus),
		math.floor(passives.excavationSpeedBonus * 100 + 0.5),
		math.floor(passives.cleaningSpeedBonus * 100 + 0.5),
		math.floor(passives.coinMultiplierBonus * 100 + 0.5)
	)

	if #state.profile.OwnedPets == 0 then
		createEmptyNotice("No anime companions yet! Visit the Egg Hatching Shrine on Harbor Island.")
		return
	end

	local equippedSet: { [string]: boolean } = {}
	for _, uid in ipairs(state.profile.EquippedPetIds) do
		equippedSet[uid] = true
	end

	local sorted: { ClientState.ClientOwnedPet } = {}
	for _, pet in ipairs(state.profile.OwnedPets) do
		table.insert(sorted, pet)
	end
	table.sort(sorted, function(a: ClientState.ClientOwnedPet, b: ClientState.ClientOwnedPet): boolean
		local aEq = equippedSet[a.uid] == true
		local bEq = equippedSet[b.uid] == true
		if aEq ~= bEq then
			return aEq
		end
		local aOrd = GameConfig.RARITY_META[a.rarity].order
		local bOrd = GameConfig.RARITY_META[b.rarity].order
		if aOrd ~= bOrd then
			return aOrd > bOrd
		end
		return a.speciesId < b.speciesId
	end)

	for index, petEntry in ipairs(sorted) do
		local species = GameConfig.PETS[petEntry.speciesId]
		if species then
			local meta = GameConfig.RARITY_META[species.rarity]
			local isEquipped = equippedSet[petEntry.uid] == true

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 82)
			row.LayoutOrder = index
			row.BackgroundColor3 = if isEquipped then Color3.fromRGB(32, 48, 82) else Color3.fromRGB(22, 30, 54)
			row.Parent = scrollList
			addCorner(row, 10)
			addStroke(row, if isEquipped then Color3.fromRGB(112, 248, 178) else meta.color, if isEquipped then 2 else 1.5)

			-- Stylized pastel chibi avatar icon
			local avatar = Instance.new("Frame")
			avatar.Position = UDim2.new(0, 10, 0.5, -26)
			avatar.Size = UDim2.fromOffset(52, 52)
			avatar.BackgroundColor3 = species.hairColor
			avatar.Parent = row
			addCorner(avatar, 26)
			addStroke(avatar, species.accentColor, 2)

			local faceDot = Instance.new("Frame")
			faceDot.AnchorPoint = Vector2.new(0.5, 0.5)
			faceDot.Position = UDim2.fromScale(0.5, 0.56)
			faceDot.Size = UDim2.fromOffset(28, 26)
			faceDot.BackgroundColor3 = species.skinColor
			faceDot.Parent = avatar
			addCorner(faceDot, 13)

			local eyeL = Instance.new("Frame")
			eyeL.Position = UDim2.fromScale(0.24, 0.36)
			eyeL.Size = UDim2.fromOffset(5, 7)
			eyeL.BackgroundColor3 = species.eyeColor
			eyeL.Parent = faceDot
			addCorner(eyeL, 3)

			local eyeR = Instance.new("Frame")
			eyeR.Position = UDim2.fromScale(0.60, 0.36)
			eyeR.Size = UDim2.fromOffset(5, 7)
			eyeR.BackgroundColor3 = species.eyeColor
			eyeR.Parent = faceDot
			addCorner(eyeR, 3)

			local titleLbl = Instance.new("TextLabel")
			titleLbl.Position = UDim2.new(0, 74, 0, 8)
			titleLbl.Size = UDim2.new(0.64, -40, 0, 26)
			titleLbl.BackgroundTransparency = 1
			titleLbl.Text = string.format("[%s] %s — %s", species.rarity, species.name, species.title)
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.TextColor3 = meta.color
			titleLbl.TextScaled = true
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.Parent = row

			local statsLbl = Instance.new("TextLabel")
			statsLbl.Position = UDim2.new(0, 74, 0, 38)
			statsLbl.Size = UDim2.new(0.68, -40, 0, 32)
			statsLbl.BackgroundTransparency = 1
			statsLbl.Text = string.format(
				"+%d O2 | +%d Swim | +%d%% Dig | +%d%% Clean | +%d%% Coins",
				species.passives.oxygenCapacityBonus,
				species.passives.swimSpeedBonus,
				math.floor(species.passives.excavationSpeedBonus * 100 + 0.5),
				math.floor(species.passives.cleaningSpeedBonus * 100 + 0.5),
				math.floor(species.passives.coinMultiplierBonus * 100 + 0.5)
			)
			statsLbl.TextXAlignment = Enum.TextXAlignment.Left
			statsLbl.TextColor3 = Color3.fromRGB(212, 228, 248)
			statsLbl.TextScaled = true
			statsLbl.Font = Enum.Font.GothamMedium
			statsLbl.Parent = row

			local equipBtn = Instance.new("TextButton")
			equipBtn.AnchorPoint = Vector2.new(1, 0.5)
			equipBtn.Position = UDim2.new(1, -12, 0.5, 0)
			equipBtn.Size = UDim2.fromOffset(112, 40)
			equipBtn.BackgroundColor3 = if isEquipped then Color3.fromRGB(214, 92, 112) else Color3.fromRGB(72, 198, 134)
			equipBtn.Text = if isEquipped then "Unequip" else "Equip"
			equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			equipBtn.TextScaled = true
			equipBtn.Font = Enum.Font.GothamBold
			equipBtn.Parent = row
			addCorner(equipBtn, 8)

			equipBtn.MouseButton1Click:Connect(function()
				local nextList: { string } = {}
				if isEquipped then
					for _, uid in ipairs(state.profile.EquippedPetIds) do
						if uid ~= petEntry.uid then
							table.insert(nextList, uid)
						end
					end
				else
					if #state.profile.EquippedPetIds >= GameConfig.MAX_EQUIPPED_PETS then
						ClientState.EmitLocalToast("Max 4 companions equipped! Unequip one first.", "Warn")
						return
					end
					for _, uid in ipairs(state.profile.EquippedPetIds) do
						table.insert(nextList, uid)
					end
					table.insert(nextList, petEntry.uid)
				end

				local ok, res = pcall(function(): any
					return Remotes.EquipPets:InvokeServer(nextList)
				end)
				if ok and typeof(res) == "table" and not res.success then
					ClientState.EmitLocalToast(res.message or "Cannot update companions.", "Warn")
				end
			end)
		end
	end
end

local function renderActiveTab(): ()
	if not panelFrame or not panelFrame.Visible then
		return
	end
	updateTabButtonStyles()
	clearScrollContents()

	local state = ClientState.GetState()
	if activeTab == "Raw" then
		renderRawRelics(state)
	elseif activeTab == "Cleaned" then
		renderCleanedRelics(state)
	else
		renderPets(state)
	end
end

local function buildUI(playerGui: PlayerGui): ()
	local existing = playerGui:FindFirstChild("AbyssalInventoryUI")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AbyssalInventoryUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	panelFrame = Instance.new("Frame")
	panelFrame.Name = "InventoryPanel"
	panelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	panelFrame.Position = UDim2.fromScale(0.5, 0.5)
	panelFrame.Size = UDim2.fromScale(0.62, 0.68)
	panelFrame.BackgroundColor3 = Color3.fromRGB(14, 22, 42)
	panelFrame.BackgroundTransparency = 0.04
	panelFrame.Visible = false
	panelFrame.Parent = gui
	addCorner(panelFrame, 16)
	addStroke(panelFrame, Color3.fromRGB(92, 208, 255), 2.5)

	local header = Instance.new("TextLabel")
	header.Position = UDim2.new(0, 20, 0, 12)
	header.Size = UDim2.new(0.75, 0, 0, 34)
	header.BackgroundTransparency = 1
	header.Text = "DIVER BACKPACK & ANIME COMPANIONS"
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(238, 248, 255)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBold
	header.Parent = panelFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -14, 0, 12)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = Color3.fromRGB(186, 62, 82)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panelFrame
	addCorner(closeBtn, 10)
	closeBtn.MouseButton1Click:Connect(function()
		ClientState.CloseWindows()
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Position = UDim2.new(0, 18, 0, 54)
	tabBar.Size = UDim2.new(1, -36, 0, 38)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panelFrame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabBar

	local tabs: { { id: InventoryTab, label: string } } = {
		{ id = "Raw", label = "Raw / Encrusted Relics" },
		{ id = "Cleaned", label = "Cleaned Treasures" },
		{ id = "Pets", label = "Anime Companions" },
	}
	for _, info in ipairs(tabs) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.32, 0, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(24, 36, 64)
		btn.Text = info.label
		btn.TextColor3 = Color3.fromRGB(200, 220, 245)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = tabBar
		addCorner(btn, 10)
		tabButtons[info.id] = btn
		btn.MouseButton1Click:Connect(function()
			activeTab = info.id
			renderActiveTab()
		end)
	end

	summaryBanner = Instance.new("TextLabel")
	summaryBanner.Position = UDim2.new(0, 20, 0, 98)
	summaryBanner.Size = UDim2.new(1, -40, 0, 26)
	summaryBanner.BackgroundTransparency = 1
	summaryBanner.Text = ""
	summaryBanner.TextXAlignment = Enum.TextXAlignment.Left
	summaryBanner.TextColor3 = Color3.fromRGB(142, 228, 255)
	summaryBanner.TextScaled = true
	summaryBanner.Font = Enum.Font.GothamMedium
	summaryBanner.Parent = panelFrame

	scrollList = Instance.new("ScrollingFrame")
	scrollList.Position = UDim2.new(0, 18, 0, 130)
	scrollList.Size = UDim2.new(1, -36, 1, -146)
	scrollList.BackgroundTransparency = 1
	scrollList.BorderSizePixel = 0
	scrollList.ScrollBarThickness = 6
	scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollList.Parent = panelFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollList
end

function InventoryUI.Init(): ()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	buildUI(playerGui)

	ClientState.SubscribeWindow(function(windowName: ClientState.WindowName)
		panelFrame.Visible = windowName == "Inventory"
		if panelFrame.Visible then
			renderActiveTab()
		end
	end)

	ClientState.Subscribe(function()
		if panelFrame.Visible then
			renderActiveTab()
		end
	end)
end

return InventoryUI
