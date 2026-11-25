--!strict
-- Main HUD: Oxygen bar, Depth meter, Coin counter, Active Buffs, Excavation bar, Toasts & Quick Buttons

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientFolder = script.Parent
local ClientState = require(ClientFolder:WaitForChild("ClientState"))

local HUDController = {}

local screenGui: ScreenGui
local oxygenFill: Frame
local oxygenText: TextLabel
local oxygenStroke: UIStroke
local depthLabel: TextLabel
local zoneBadge: Frame
local zoneLabel: TextLabel
local coinsLabel: TextLabel
local coinsCard: Frame
local buffsContainer: Frame
local flashlightBtn: TextButton
local flashlightSub: TextLabel
local backpackBtn: TextButton
local cleaningBtn: TextButton
local excavationBarFrame: Frame
local excavationFill: Frame
local excavationText: TextLabel
local toastContainer: Frame
local blackoutFrame: Frame
local blackoutTitle: TextLabel
local blackoutSub: TextLabel
local lowO2Vignette: Frame

local displayedOxygenRatio = 1
local lastCoins = -1

local function addCorner(inst: GuiObject, radiusPx: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radiusPx)
	c.Parent = inst
	return c
end

local function addStroke(inst: GuiObject, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = inst
	return s
end

local function formatSeconds(sec: number): string
	local rounded = math.max(0, math.ceil(sec))
	local mins = math.floor(rounded / 60)
	local rem = rounded % 60
	if mins > 0 then
		return string.format("%dm %02ds", mins, rem)
	end
	return string.format("%ds", rem)
end

local function showToast(text: string, accentColor: Color3): ()
	if not toastContainer then
		return
	end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 36)
	toast.BackgroundColor3 = Color3.fromRGB(16, 26, 46)
	toast.BackgroundTransparency = 0.08
	toast.BorderSizePixel = 0
	toast.Parent = toastContainer
	addCorner(toast, 10)
	addStroke(toast, accentColor, 2)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(0.94, 0.9)
	lbl.Position = UDim2.fromScale(0.03, 0.05)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = accentColor
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = toast

	task.delay(3.2, function()
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
			local lblTween = TweenService:Create(lbl, TweenInfo.new(0.35), { TextTransparency = 1 })
			tween:Play()
			lblTween:Play()
			tween.Completed:Connect(function()
				if toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

local function makeDockButton(parent: Instance, title: string, subText: string, accent: Color3, order: number): (TextButton, TextLabel)
	local btn = Instance.new("TextButton")
	btn.Name = title .. "Button"
	btn.Size = UDim2.fromOffset(118, 52)
	btn.LayoutOrder = order
	btn.BackgroundColor3 = Color3.fromRGB(18, 28, 50)
	btn.BackgroundTransparency = 0.08
	btn.AutoButtonColor = true
	btn.Text = ""
	btn.Parent = parent
	addCorner(btn, 12)
	addStroke(btn, accent, 2)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "Title"
	titleLbl.Position = UDim2.fromScale(0.06, 0.1)
	titleLbl.Size = UDim2.fromScale(0.88, 0.48)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = Color3.fromRGB(242, 248, 255)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.Parent = btn

	local subLbl = Instance.new("TextLabel")
	subLbl.Name = "Subtitle"
	subLbl.Position = UDim2.fromScale(0.06, 0.56)
	subLbl.Size = UDim2.fromScale(0.88, 0.36)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = subText
	subLbl.TextColor3 = accent
	subLbl.TextScaled = true
	subLbl.Font = Enum.Font.GothamMedium
	subLbl.Parent = btn

	return btn, subLbl
end

local function buildUI(playerGui: PlayerGui): ()
	local existing = playerGui:FindFirstChild("AbyssalHarborHUD")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AbyssalHarborHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui

	-- Low-Oxygen subtle screen edge warning
	lowO2Vignette = Instance.new("Frame")
	lowO2Vignette.Name = "LowO2Warning"
	lowO2Vignette.Size = UDim2.fromScale(1, 1)
	lowO2Vignette.BackgroundColor3 = Color3.fromRGB(215, 28, 46)
	lowO2Vignette.BackgroundTransparency = 1
	lowO2Vignette.BorderSizePixel = 0
	lowO2Vignette.ZIndex = 1
	lowO2Vignette.Parent = gui

	-- Top Center: Oxygen Bar + Depth & Zone Pill
	local topCenter = Instance.new("Frame")
	topCenter.Name = "TopCenterCluster"
	topCenter.AnchorPoint = Vector2.new(0.5, 0)
	topCenter.Position = UDim2.new(0.5, 0, 0, 14)
	topCenter.Size = UDim2.fromOffset(380, 92)
	topCenter.BackgroundTransparency = 1
	topCenter.Parent = gui

	local o2Panel = Instance.new("Frame")
	o2Panel.Name = "OxygenPanel"
	o2Panel.Size = UDim2.new(1, 0, 0, 44)
	o2Panel.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
	o2Panel.BackgroundTransparency = 0.12
	o2Panel.Parent = topCenter
	addCorner(o2Panel, 12)
	oxygenStroke = addStroke(o2Panel, Color3.fromRGB(72, 218, 255), 2)

	local o2Bg = Instance.new("Frame")
	o2Bg.Position = UDim2.new(0, 8, 0, 8)
	o2Bg.Size = UDim2.new(1, -16, 1, -16)
	o2Bg.BackgroundColor3 = Color3.fromRGB(28, 40, 68)
	o2Bg.BorderSizePixel = 0
	o2Bg.Parent = o2Panel
	addCorner(o2Bg, 8)

	oxygenFill = Instance.new("Frame")
	oxygenFill.Size = UDim2.fromScale(1, 1)
	oxygenFill.BackgroundColor3 = Color3.fromRGB(68, 224, 255)
	oxygenFill.BorderSizePixel = 0
	oxygenFill.Parent = o2Bg
	addCorner(oxygenFill, 8)

	oxygenText = Instance.new("TextLabel")
	oxygenText.Size = UDim2.fromScale(1, 1)
	oxygenText.BackgroundTransparency = 1
	oxygenText.Text = "O2  100 / 100"
	oxygenText.TextColor3 = Color3.fromRGB(255, 255, 255)
	oxygenText.TextStrokeTransparency = 0.45
	oxygenText.TextScaled = true
	oxygenText.Font = Enum.Font.GothamBold
	oxygenText.ZIndex = 3
	oxygenText.Parent = o2Bg

	zoneBadge = Instance.new("Frame")
	zoneBadge.Name = "ZoneBadge"
	zoneBadge.AnchorPoint = Vector2.new(0.5, 0)
	zoneBadge.Position = UDim2.new(0.5, 0, 0, 50)
	zoneBadge.Size = UDim2.fromOffset(310, 34)
	zoneBadge.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
	zoneBadge.BackgroundTransparency = 0.14
	zoneBadge.Parent = topCenter
	addCorner(zoneBadge, 10)
	addStroke(zoneBadge, Color3.fromRGB(98, 204, 245), 1.5)

	depthLabel = Instance.new("TextLabel")
	depthLabel.Position = UDim2.fromScale(0.04, 0.1)
	depthLabel.Size = UDim2.fromScale(0.28, 0.8)
	depthLabel.BackgroundTransparency = 1
	depthLabel.Text = "0m"
	depthLabel.TextColor3 = Color3.fromRGB(240, 248, 255)
	depthLabel.TextScaled = true
	depthLabel.Font = Enum.Font.GothamBold
	depthLabel.Parent = zoneBadge

	zoneLabel = Instance.new("TextLabel")
	zoneLabel.Position = UDim2.fromScale(0.34, 0.1)
	zoneLabel.Size = UDim2.fromScale(0.62, 0.8)
	zoneLabel.BackgroundTransparency = 1
	zoneLabel.Text = "HARBOR SURFACE"
	zoneLabel.TextColor3 = Color3.fromRGB(124, 232, 255)
	zoneLabel.TextScaled = true
	zoneLabel.Font = Enum.Font.GothamBold
	zoneLabel.Parent = zoneBadge

	-- Top Right: Coins & Active Buffs
	local topRight = Instance.new("Frame")
	topRight.Name = "TopRightCluster"
	topRight.AnchorPoint = Vector2.new(1, 0)
	topRight.Position = UDim2.new(1, -18, 0, 14)
	topRight.Size = UDim2.fromOffset(220, 260)
	topRight.BackgroundTransparency = 1
	topRight.Parent = gui

	coinsCard = Instance.new("Frame")
	coinsCard.Size = UDim2.new(1, 0, 0, 48)
	coinsCard.BackgroundColor3 = Color3.fromRGB(22, 30, 52)
	coinsCard.BackgroundTransparency = 0.1
	coinsCard.Parent = topRight
	addCorner(coinsCard, 12)
	addStroke(coinsCard, Color3.fromRGB(255, 206, 72), 2)

	local coinIcon = Instance.new("Frame")
	coinIcon.Position = UDim2.new(0, 10, 0.5, -14)
	coinIcon.Size = UDim2.fromOffset(28, 28)
	coinIcon.BackgroundColor3 = Color3.fromRGB(255, 204, 68)
	coinIcon.Parent = coinsCard
	addCorner(coinIcon, 14)

	local coinLetter = Instance.new("TextLabel")
	coinLetter.Size = UDim2.fromScale(1, 1)
	coinLetter.BackgroundTransparency = 1
	coinLetter.Text = "C"
	coinLetter.TextColor3 = Color3.fromRGB(98, 56, 8)
	coinLetter.TextScaled = true
	coinLetter.Font = Enum.Font.GothamBold
	coinLetter.Parent = coinIcon

	coinsLabel = Instance.new("TextLabel")
	coinsLabel.Position = UDim2.new(0, 46, 0, 6)
	coinsLabel.Size = UDim2.new(1, -56, 1, -12)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "100"
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.TextColor3 = Color3.fromRGB(255, 224, 114)
	coinsLabel.TextScaled = true
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Parent = coinsCard

	buffsContainer = Instance.new("Frame")
	buffsContainer.Position = UDim2.new(0, 0, 0, 56)
	buffsContainer.Size = UDim2.new(1, 0, 1, -56)
	buffsContainer.BackgroundTransparency = 1
	buffsContainer.Parent = topRight

	local buffLayout = Instance.new("UIListLayout")
	buffLayout.FillDirection = Enum.FillDirection.Vertical
	buffLayout.Padding = UDim.new(0, 6)
	buffLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	buffLayout.Parent = buffsContainer

	-- Bottom Left/Center Quick Dock
	local dock = Instance.new("Frame")
	dock.Name = "QuickDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -16)
	dock.Size = UDim2.fromOffset(630, 56)
	dock.BackgroundTransparency = 1
	dock.Parent = gui

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.Padding = UDim.new(0, 10)
	dockLayout.Parent = dock

	local btnFlash, subFlash = makeDockButton(dock, "Flashlight [F]", "OFF (Lv.1)", Color3.fromRGB(255, 224, 128), 1)
	flashlightBtn = btnFlash
	flashlightSub = subFlash
	flashlightBtn.MouseButton1Click:Connect(function()
		Remotes.ToggleFlashlight:FireServer()
	end)

	local btnBag, _ = makeDockButton(dock, "Backpack [B]", "Relics & Pets", Color3.fromRGB(108, 224, 255), 2)
	backpackBtn = btnBag
	backpackBtn.MouseButton1Click:Connect(function()
		ClientState.SetActiveWindow("Inventory")
	end)

	local btnShop, _ = makeDockButton(dock, "Dive Shop", "Gear & Buffs", Color3.fromRGB(112, 248, 178), 3)
	btnShop.MouseButton1Click:Connect(function()
		ClientState.SetActiveWindow("Shop")
	end)

	local btnClean, _ = makeDockButton(dock, "Washbasins", "0 / 3 Busy", Color3.fromRGB(168, 214, 255), 4)
	cleaningBtn = btnClean
	cleaningBtn.MouseButton1Click:Connect(function()
		ClientState.SetActiveWindow("Cleaning")
	end)

	local btnEggs, _ = makeDockButton(dock, "Egg Shrine", "Anime Pets", Color3.fromRGB(255, 152, 232), 5)
	btnEggs.MouseButton1Click:Connect(function()
		ClientState.SetActiveWindow("Eggs")
	end)

	-- Excavation Progress Bar
	excavationBarFrame = Instance.new("Frame")
	excavationBarFrame.Name = "ExcavationBar"
	excavationBarFrame.AnchorPoint = Vector2.new(0.5, 1)
	excavationBarFrame.Position = UDim2.new(0.5, 0, 1, -86)
	excavationBarFrame.Size = UDim2.fromOffset(340, 44)
	excavationBarFrame.BackgroundColor3 = Color3.fromRGB(16, 28, 52)
	excavationBarFrame.BackgroundTransparency = 0.08
	excavationBarFrame.Visible = false
	excavationBarFrame.Parent = gui
	addCorner(excavationBarFrame, 12)
	addStroke(excavationBarFrame, Color3.fromRGB(92, 234, 255), 2)

	local excBg = Instance.new("Frame")
	excBg.Position = UDim2.new(0, 8, 0, 8)
	excBg.Size = UDim2.new(1, -84, 1, -16)
	excBg.BackgroundColor3 = Color3.fromRGB(30, 44, 74)
	excBg.BorderSizePixel = 0
	excBg.Parent = excavationBarFrame
	addCorner(excBg, 8)

	excavationFill = Instance.new("Frame")
	excavationFill.Size = UDim2.fromScale(0, 1)
	excavationFill.BackgroundColor3 = Color3.fromRGB(92, 238, 198)
	excavationFill.BorderSizePixel = 0
	excavationFill.Parent = excBg
	addCorner(excavationFill, 8)

	excavationText = Instance.new("TextLabel")
	excavationText.Size = UDim2.fromScale(1, 1)
	excavationText.BackgroundTransparency = 1
	excavationText.Text = "Excavating..."
	excavationText.TextColor3 = Color3.fromRGB(255, 255, 255)
	excavationText.TextStrokeTransparency = 0.4
	excavationText.TextScaled = true
	excavationText.Font = Enum.Font.GothamBold
	excavationText.ZIndex = 3
	excavationText.Parent = excBg

	local cancelDigBtn = Instance.new("TextButton")
	cancelDigBtn.AnchorPoint = Vector2.new(1, 0.5)
	cancelDigBtn.Position = UDim2.new(1, -8, 0.5, 0)
	cancelDigBtn.Size = UDim2.fromOffset(62, 28)
	cancelDigBtn.BackgroundColor3 = Color3.fromRGB(196, 68, 86)
	cancelDigBtn.Text = "Stop"
	cancelDigBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelDigBtn.TextScaled = true
	cancelDigBtn.Font = Enum.Font.GothamBold
	cancelDigBtn.Parent = excavationBarFrame
	addCorner(cancelDigBtn, 8)
	cancelDigBtn.MouseButton1Click:Connect(function()
		pcall(function()
			Remotes.ExcavateNode:InvokeServer("__CANCEL__")
		end)
	end)

	-- Toast Notifications Container
	toastContainer = Instance.new("Frame")
	toastContainer.Name = "ToastFeed"
	toastContainer.AnchorPoint = Vector2.new(0.5, 1)
	toastContainer.Position = UDim2.new(0.5, 0, 1, -140)
	toastContainer.Size = UDim2.fromOffset(420, 160)
	toastContainer.BackgroundTransparency = 1
	toastContainer.Parent = gui

	local toastLayout = Instance.new("UIListLayout")
	toastLayout.FillDirection = Enum.FillDirection.Vertical
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	toastLayout.Padding = UDim.new(0, 6)
	toastLayout.Parent = toastContainer

	-- Blackout Rescue Screen Fade Overlay
	blackoutFrame = Instance.new("Frame")
	blackoutFrame.Name = "BlackoutOverlay"
	blackoutFrame.Size = UDim2.fromScale(1, 1)
	blackoutFrame.BackgroundColor3 = Color3.fromRGB(4, 8, 18)
	blackoutFrame.BackgroundTransparency = 1
	blackoutFrame.Visible = false
	blackoutFrame.ZIndex = 80
	blackoutFrame.Parent = gui

	blackoutTitle = Instance.new("TextLabel")
	blackoutTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	blackoutTitle.Position = UDim2.fromScale(0.5, 0.45)
	blackoutTitle.Size = UDim2.fromScale(0.75, 0.1)
	blackoutTitle.BackgroundTransparency = 1
	blackoutTitle.Text = "OXYGEN DEPLETED!"
	blackoutTitle.TextColor3 = Color3.fromRGB(255, 92, 112)
	blackoutTitle.TextScaled = true
	blackoutTitle.Font = Enum.Font.GothamBold
	blackoutTitle.ZIndex = 81
	blackoutTitle.Parent = blackoutFrame

	blackoutSub = Instance.new("TextLabel")
	blackoutSub.AnchorPoint = Vector2.new(0.5, 0.5)
	blackoutSub.Position = UDim2.fromScale(0.5, 0.55)
	blackoutSub.Size = UDim2.fromScale(0.75, 0.06)
	blackoutSub.BackgroundTransparency = 1
	blackoutSub.Text = "Emergency rescue back to Harbor Pier..."
	blackoutSub.TextColor3 = Color3.fromRGB(232, 240, 255)
	blackoutSub.TextScaled = true
	blackoutSub.Font = Enum.Font.GothamMedium
	blackoutSub.ZIndex = 81
	blackoutSub.Parent = blackoutFrame
end

local function refreshBuffBadges(): ()
	if not buffsContainer then
		return
	end
	for _, child in ipairs(buffsContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, itemId in ipairs(GameConfig.SHOP_ITEM_ORDER) do
		local rem = ClientState.GetBuffRemaining(itemId)
		if rem > 0.5 then
			local cfg = GameConfig.SHOP_ITEMS[itemId]
			local badge = Instance.new("Frame")
			badge.Size = UDim2.new(1, 0, 0, 28)
			badge.BackgroundColor3 = Color3.fromRGB(16, 26, 48)
			badge.BackgroundTransparency = 0.14
			badge.Parent = buffsContainer
			addCorner(badge, 8)
			addStroke(badge, cfg.accentColor, 1.5)

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(0.92, 0.85)
			lbl.Position = UDim2.fromScale(0.04, 0.08)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.format("%s  %s", cfg.name, formatSeconds(rem))
			lbl.TextColor3 = cfg.accentColor
			lbl.TextScaled = true
			lbl.Font = Enum.Font.GothamBold
			lbl.Parent = badge
		end
	end
end

local function onStateUpdated(state: ClientState.ClientSnapshot): ()
	if not screenGui then
		return
	end

	-- Coins
	if state.profile.Coins ~= lastCoins then
		local gained = lastCoins >= 0 and state.profile.Coins > lastCoins
		lastCoins = state.profile.Coins
		coinsLabel.Text = GameConfig.FormatNumber(state.profile.Coins)
		if gained then
			coinsCard.Size = UDim2.fromOffset(230, 52)
			TweenService:Create(coinsCard, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(220, 48) }):Play()
		end
	end

	-- Flashlight button
	local lightLv = state.profile.GearLevels.LightStrength
	if state.diving.flashlightOn then
		flashlightSub.Text = string.format("ON (Lv.%d)", lightLv)
		flashlightSub.TextColor3 = Color3.fromRGB(255, 224, 108)
	else
		flashlightSub.Text = string.format("OFF (Lv.%d)", lightLv)
		flashlightSub.TextColor3 = Color3.fromRGB(168, 184, 210)
	end

	-- Backpack badge count
	local bagSub = backpackBtn:FindFirstChild("Subtitle")
	if bagSub and bagSub:IsA("TextLabel") then
		local totalRelics = #state.profile.RawRelics + #state.profile.CleanedRelics
		bagSub.Text = string.format("%d Relics • %d Pets", totalRelics, #state.profile.OwnedPets)
	end

	-- Washbasins badge count
	local cleanSub = cleaningBtn:FindFirstChild("Subtitle")
	if cleanSub and cleanSub:IsA("TextLabel") then
		local busyCount = 0
		local readyCount = 0
		local now = ClientState.GetServerTime()
		for i = 1, GameConfig.CLEANING_SLOT_COUNT do
			local slot = state.profile.CleaningSlots[tostring(i)]
			if slot then
				busyCount += 1
				if now >= slot.endsAt then
					readyCount += 1
				end
			end
		end
		if readyCount > 0 then
			cleanSub.Text = string.format("%d READY!", readyCount)
			cleanSub.TextColor3 = Color3.fromRGB(112, 255, 168)
		else
			cleanSub.Text = string.format("%d / %d Scrubbing", busyCount, GameConfig.CLEANING_SLOT_COUNT)
			cleanSub.TextColor3 = Color3.fromRGB(168, 214, 255)
		end
	end

	refreshBuffBadges()
end

local function handleEventNotification(ev: { [string]: any }): ()
	local evType = ev.type
	if evType == "ExcavationComplete" then
		local cfg = GameConfig.RELICS[ev.itemId]
		if cfg then
			local meta = GameConfig.RARITY_META[cfg.rarity]
			local suffix = if ev.isRaw then " (Needs Cleaning!)" else " (Ready to Sell!)"
			showToast(string.format("[%s] Found %s%s", cfg.rarity, cfg.name, suffix), meta.color)
		end
	elseif evType == "CleanedClaimed" then
		local cfg = GameConfig.RELICS[ev.itemId]
		if cfg then
			local meta = GameConfig.RARITY_META[cfg.rarity]
			showToast(string.format("Uncovered [%s] %s (%s Coins)!", cfg.rarity, cfg.name, GameConfig.FormatNumber(cfg.sellValue)), meta.color)
		end
	elseif evType == "RelicsSold" then
		showToast(string.format("Sold %d relics for +%s Coins!", ev.soldCount or 0, GameConfig.FormatNumber(ev.coinsEarned or 0)), Color3.fromRGB(255, 224, 96))
	elseif evType == "UpgradePurchased" then
		showToast("Gear Upgraded: " .. tostring(ev.tierName), Color3.fromRGB(112, 248, 178))
	elseif evType == "ShopItemBought" then
		local cfg = (GameConfig.SHOP_ITEMS :: { [string]: GameConfig.ShopItemConfig })[ev.itemId]
		if cfg then
			showToast("Activated: " .. cfg.name, cfg.accentColor)
		end
	elseif evType == "Blackout" then
		blackoutFrame.Visible = true
		blackoutFrame.BackgroundTransparency = 1
		local lost = ev.lostCount or 0
		blackoutSub.Text = if lost > 0
			then string.format("Dropped %d uncleaned relic(s)! Rescuing to Harbor Pier...", lost)
			else "Emergency rescue back to Harbor Pier..."
		TweenService:Create(blackoutFrame, TweenInfo.new(0.45), { BackgroundTransparency = 0.08 }):Play()
	elseif evType == "BlackoutRescued" then
		local fadeOut = TweenService:Create(blackoutFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			blackoutFrame.Visible = false
		end)
		local lost = ev.lostCount or 0
		if lost > 0 then
			showToast(string.format("Rescued to Harbor! Lost %d uncleaned relic(s).", lost), Color3.fromRGB(255, 118, 132))
		else
			showToast("Rescued safely back to Harbor Pier!", Color3.fromRGB(128, 224, 255))
		end
	elseif evType == "Toast" then
		local color = if ev.kind == "Warn" then Color3.fromRGB(255, 186, 98) else Color3.fromRGB(142, 232, 255)
		showToast(tostring(ev.text or ""), color)
	end
end

function HUDController.Init(): ()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	buildUI(playerGui)

	ClientState.Subscribe(onStateUpdated)
	ClientState.SubscribeEvents(handleEventNotification)

	local buffRefreshAccum = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local state = ClientState.GetState()
		local maxO2 = math.max(1, state.diving.maxOxygen)
		local targetRatio = math.clamp(state.diving.oxygen / maxO2, 0, 1)
		displayedOxygenRatio += (targetRatio - displayedOxygenRatio) * math.clamp(10 * dt, 0.05, 1)

		oxygenFill.Size = UDim2.fromScale(displayedOxygenRatio, 1)
		oxygenText.Text = string.format("O2  %d / %d", math.floor(state.diving.oxygen + 0.5), math.floor(maxO2))

		if displayedOxygenRatio < 0.25 then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
			oxygenFill.BackgroundColor3 = Color3.fromRGB(255, 72, 92)
			oxygenStroke.Color = Color3.fromRGB(255, 72, 92)
			lowO2Vignette.BackgroundTransparency = 0.78 + pulse * 0.16
		elseif displayedOxygenRatio < 0.5 then
			oxygenFill.BackgroundColor3 = Color3.fromRGB(255, 198, 76)
			oxygenStroke.Color = Color3.fromRGB(255, 198, 76)
			lowO2Vignette.BackgroundTransparency = 1
		else
			oxygenFill.BackgroundColor3 = Color3.fromRGB(68, 224, 255)
			oxygenStroke.Color = Color3.fromRGB(72, 218, 255)
			lowO2Vignette.BackgroundTransparency = 1
		end

		-- Depth & Zone display
		if state.diving.isUnderwater then
			local d = math.floor(state.diving.depth + 0.5)
			depthLabel.Text = string.format("-%dm", d)
			local zone = if state.diving.zoneId then GameConfig.ZONES[state.diving.zoneId] else nil
			if zone then
				zoneLabel.Text = string.upper(zone.name)
				zoneLabel.TextColor3 = zone.accentColor
			end
		else
			depthLabel.Text = "0m"
			zoneLabel.Text = "HARBOR SURFACE"
			zoneLabel.TextColor3 = Color3.fromRGB(124, 232, 255)
		end

		-- Excavation progress bar
		local exc = state.activeExcavation
		if exc then
			local now = ClientState.GetServerTime()
			local progress = math.clamp((now - exc.startedAt) / math.max(0.1, exc.duration), 0, 1)
			local rem = math.max(0, exc.endsAt - now)
			excavationBarFrame.Visible = true
			excavationFill.Size = UDim2.fromScale(progress, 1)
			excavationText.Text = string.format("Excavating... %.1fs", rem)
		else
			excavationBarFrame.Visible = false
		end

		buffRefreshAccum += dt
		if buffRefreshAccum >= 0.5 then
			buffRefreshAccum = 0
			refreshBuffBadges()
			onStateUpdated(state)
		end
	end)
end

return HUDController
