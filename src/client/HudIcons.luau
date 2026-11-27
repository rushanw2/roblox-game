--!strict
-- Procedural 2D vector icon builders (Frames, UICorners, UIStrokes only — no external image IDs)
-- for left HUD buttons, Luggage tiles, Valuables tiles, Shop Upgrades, and Consumable Items.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local HudIcons = {}

local function addCorner(parent: Instance, radius: UDim): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
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

local function makeBox(
	parent: Instance,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	zIndex: number,
	corner: UDim?,
	rotation: number?
): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zIndex
	if rotation then
		f.Rotation = rotation
	end
	f.Parent = parent
	if corner then
		addCorner(f, corner)
	end
	return f
end

local function makeContainer(parent: Instance, name: string, size: UDim2, pos: UDim2, zIndex: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = zIndex
	f.Parent = parent
	return f
end

-- Blue backpack/duffle HUD button icon for STASH
function HudIcons.CreateStashIcon(parent: Instance, size: UDim2, pos: UDim2, zIndex: number): Frame
	local root = makeContainer(parent, "StashIcon", size, pos, zIndex)
	local darkOutline = Color3.fromRGB(16, 26, 48)

	-- Top carry strap
	local handle = makeBox(root, UDim2.fromScale(0.36, 0.22), UDim2.fromScale(0.32, 0.04), Color3.fromRGB(32, 108, 214), zIndex + 1, UDim.new(0.45, 0))
	addStroke(handle, darkOutline, 2.2)

	-- Side accent pockets
	local sideL = makeBox(root, UDim2.fromScale(0.14, 0.42), UDim2.fromScale(0.08, 0.42), Color3.fromRGB(32, 102, 206), zIndex + 1, UDim.new(0.35, 0))
	addStroke(sideL, darkOutline, 2)
	local sideR = makeBox(root, UDim2.fromScale(0.14, 0.42), UDim2.fromScale(0.78, 0.42), Color3.fromRGB(32, 102, 206), zIndex + 1, UDim.new(0.35, 0))
	addStroke(sideR, darkOutline, 2)

	-- Main rounded pack body
	local body = makeBox(root, UDim2.fromScale(0.68, 0.72), UDim2.fromScale(0.16, 0.18), Color3.fromRGB(52, 152, 255), zIndex + 2, UDim.new(0.24, 0))
	addStroke(body, darkOutline, 2.5)

	-- Upper flap
	local flap = makeBox(body, UDim2.fromScale(1.04, 0.42), UDim2.fromScale(-0.02, -0.02), Color3.fromRGB(98, 190, 255), zIndex + 3, UDim.new(0.28, 0))
	addStroke(flap, darkOutline, 2)

	-- Front zipper pocket
	local pocket = makeBox(body, UDim2.fromScale(0.76, 0.36), UDim2.fromScale(0.12, 0.52), Color3.fromRGB(30, 98, 198), zIndex + 3, UDim.new(0.22, 0))
	addStroke(pocket, darkOutline, 1.8)
	makeBox(pocket, UDim2.fromScale(0.72, 0.14), UDim2.fromScale(0.14, 0.24), Color3.fromRGB(224, 240, 255), zIndex + 4, UDim.new(0.5, 0))

	-- Gold center clasp
	local clasp = makeBox(body, UDim2.fromScale(0.22, 0.18), UDim2.fromScale(0.39, 0.33), Color3.fromRGB(255, 208, 66), zIndex + 4, UDim.new(0.3, 0))
	addStroke(clasp, darkOutline, 1.5)

	return root
end

-- Crimson shopping basket HUD button icon for SHOP
function HudIcons.CreateShopIcon(parent: Instance, size: UDim2, pos: UDim2, zIndex: number): Frame
	local root = makeContainer(parent, "ShopIcon", size, pos, zIndex)
	local darkOutline = Color3.fromRGB(48, 14, 22)

	-- Twin angled basket handles
	local hL = makeBox(root, UDim2.fromScale(0.11, 0.38), UDim2.fromScale(0.28, 0.08), Color3.fromRGB(244, 248, 255), zIndex + 1, UDim.new(0.5, 0), 22)
	addStroke(hL, darkOutline, 2)
	local hR = makeBox(root, UDim2.fromScale(0.11, 0.38), UDim2.fromScale(0.61, 0.08), Color3.fromRGB(244, 248, 255), zIndex + 1, UDim.new(0.5, 0), -22)
	addStroke(hR, darkOutline, 2)

	-- Basket body
	local body = makeBox(root, UDim2.fromScale(0.76, 0.46), UDim2.fromScale(0.12, 0.42), Color3.fromRGB(238, 56, 76), zIndex + 2, UDim.new(0.22, 0))
	addStroke(body, darkOutline, 2.5)

	-- Top thick rim
	local rim = makeBox(root, UDim2.fromScale(0.88, 0.16), UDim2.fromScale(0.06, 0.34), Color3.fromRGB(255, 108, 124), zIndex + 3, UDim.new(0.4, 0))
	addStroke(rim, darkOutline, 2.2)

	-- 3 vertical basket cut slots
	for i = 1, 3 do
		local xFrac = 0.18 + (i - 1) * 0.25
		makeBox(body, UDim2.fromScale(0.14, 0.56), UDim2.fromScale(xFrac, 0.26), Color3.fromRGB(148, 22, 38), zIndex + 3, UDim.new(0.45, 0))
	end

	return root
end

-- Archetype-matched 2D luggage vector icon for Stash & Workbenches
function HudIcons.CreateLuggageIcon(
	parent: Instance,
	archetype: GameConfig.ArchetypeDef?,
	size: UDim2,
	pos: UDim2,
	zIndex: number
): Frame
	local root = makeContainer(parent, "LuggageIcon", size, pos, zIndex)
	local primary = if archetype then archetype.primaryColor else Color3.fromRGB(78, 108, 72)
	local secondary = if archetype then archetype.secondaryColor else Color3.fromRGB(194, 162, 112)
	local trim = if archetype then archetype.trimColor else Color3.fromRGB(108, 74, 48)
	local tag = if archetype then archetype.tagColor else Color3.fromRGB(255, 184, 48)
	local style: GameConfig.BagStyle = if archetype then archetype.bagStyle else "Hardcase"
	local outline = Color3.fromRGB(12, 16, 26)

	if style == "Duffle" then
		local grip = makeBox(root, UDim2.fromScale(0.32, 0.16), UDim2.fromScale(0.34, 0.20), trim, zIndex + 1, UDim.new(0.45, 0))
		addStroke(grip, outline, 1.5)
		local body = makeBox(root, UDim2.fromScale(0.78, 0.44), UDim2.fromScale(0.11, 0.34), primary, zIndex + 2, UDim.new(0.32, 0))
		addStroke(body, outline, 2)
		makeBox(body, UDim2.fromScale(0.24, 1), UDim2.fromScale(0.38, 0), secondary, zIndex + 3)
		makeBox(body, UDim2.fromScale(0.09, 1), UDim2.fromScale(0.20, 0), trim, zIndex + 3)
		makeBox(body, UDim2.fromScale(0.09, 1), UDim2.fromScale(0.71, 0), trim, zIndex + 3)
		local tagBox = makeBox(root, UDim2.fromScale(0.14, 0.20), UDim2.fromScale(0.76, 0.40), tag, zIndex + 4, UDim.new(0.2, 0), -14)
		addStroke(tagBox, outline, 1.2)
	elseif style == "Trunk" then
		local handle = makeBox(root, UDim2.fromScale(0.28, 0.12), UDim2.fromScale(0.36, 0.18), trim, zIndex + 1, UDim.new(0.3, 0))
		addStroke(handle, outline, 1.4)
		local body = makeBox(root, UDim2.fromScale(0.76, 0.56), UDim2.fromScale(0.12, 0.28), primary, zIndex + 2, UDim.new(0.12, 0))
		addStroke(body, outline, 2)
		makeBox(body, UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0.22), secondary, zIndex + 3)
		makeBox(body, UDim2.fromScale(0.12, 1), UDim2.fromScale(0.18, 0), trim, zIndex + 3)
		makeBox(body, UDim2.fromScale(0.12, 1), UDim2.fromScale(0.70, 0), trim, zIndex + 3)
		local tagBox = makeBox(root, UDim2.fromScale(0.14, 0.22), UDim2.fromScale(0.77, 0.34), tag, zIndex + 4, UDim.new(0.2, 0), -12)
		addStroke(tagBox, outline, 1.2)
	elseif style == "Briefcase" then
		local handle = makeBox(root, UDim2.fromScale(0.28, 0.14), UDim2.fromScale(0.36, 0.18), trim, zIndex + 1, UDim.new(0.35, 0))
		addStroke(handle, outline, 1.5)
		local body = makeBox(root, UDim2.fromScale(0.76, 0.50), UDim2.fromScale(0.12, 0.30), primary, zIndex + 2, UDim.new(0.14, 0))
		addStroke(body, outline, 2)
		makeBox(body, UDim2.fromScale(1, 0.16), UDim2.fromScale(0, 0.36), secondary, zIndex + 3)
		makeBox(body, UDim2.fromScale(0.18, 0.20), UDim2.fromScale(0.41, 0.34), trim, zIndex + 4, UDim.new(0.25, 0))
		local tagBox = makeBox(root, UDim2.fromScale(0.12, 0.20), UDim2.fromScale(0.76, 0.36), tag, zIndex + 4, UDim.new(0.2, 0), -10)
		addStroke(tagBox, outline, 1.2)
	elseif style == "VaultCase" then
		local handle = makeBox(root, UDim2.fromScale(0.32, 0.13), UDim2.fromScale(0.34, 0.14), trim, zIndex + 1, UDim.new(0.35, 0))
		addStroke(handle, outline, 1.5)
		local body = makeBox(root, UDim2.fromScale(0.72, 0.60), UDim2.fromScale(0.14, 0.24), primary, zIndex + 2, UDim.new(0.16, 0))
		addStroke(body, outline, 2)
		makeBox(body, UDim2.fromScale(0.92, 0.14), UDim2.fromScale(0.04, 0.20), secondary, zIndex + 3, UDim.new(0.5, 0))
		makeBox(body, UDim2.fromScale(0.22, 0.26), UDim2.fromScale(0.39, 0.44), trim, zIndex + 3, UDim.new(0.5, 0))
		local tagBox = makeBox(root, UDim2.fromScale(0.14, 0.22), UDim2.fromScale(0.76, 0.32), tag, zIndex + 4, UDim.new(0.2, 0), -14)
		addStroke(tagBox, outline, 1.2)
	else
		-- Hardcase (upright rolling suitcase)
		local pullRod = makeBox(root, UDim2.fromScale(0.28, 0.20), UDim2.fromScale(0.36, 0.06), trim, zIndex + 1, UDim.new(0.25, 0))
		addStroke(pullRod, outline, 1.5)
		makeBox(pullRod, UDim2.fromScale(0.52, 0.60), UDim2.fromScale(0.24, 0.32), Color3.fromRGB(22, 28, 42), zIndex + 2)
		-- Wheels
		makeBox(root, UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.25, 0.84), Color3.fromRGB(24, 28, 36), zIndex + 1, UDim.new(0.5, 0))
		makeBox(root, UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.63, 0.84), Color3.fromRGB(24, 28, 36), zIndex + 1, UDim.new(0.5, 0))
		-- Body
		local body = makeBox(root, UDim2.fromScale(0.56, 0.64), UDim2.fromScale(0.22, 0.22), primary, zIndex + 2, UDim.new(0.18, 0))
		addStroke(body, outline, 2)
		makeBox(body, UDim2.fromScale(0.24, 1), UDim2.fromScale(0.38, 0), secondary, zIndex + 3)
		makeBox(body, UDim2.fromScale(0.10, 1), UDim2.fromScale(0.16, 0), trim, zIndex + 3)
		makeBox(body, UDim2.fromScale(0.10, 1), UDim2.fromScale(0.74, 0), trim, zIndex + 3)
		local tagBox = makeBox(root, UDim2.fromScale(0.15, 0.22), UDim2.fromScale(0.66, 0.30), tag, zIndex + 4, UDim.new(0.2, 0), -14)
		addStroke(tagBox, outline, 1.2)
	end

	return root
end

-- Stylized 2D vector icon for revealed Valuables tiles
function HudIcons.CreateLootIcon(
	parent: Instance,
	itemId: string,
	tier: GameConfig.RarityTier,
	iconText: string,
	size: UDim2,
	pos: UDim2,
	zIndex: number
): Frame
	local root = makeContainer(parent, "LootIcon", size, pos, zIndex)
	local tierColor = GameConfig.TIER_COLORS[tier]
	local outline = Color3.fromRGB(14, 18, 28)

	-- Soft halo disc behind item
	local halo = makeBox(root, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.11, 0.11), tierColor, zIndex + 1, UDim.new(0.5, 0))
	halo.BackgroundTransparency = 0.72
	addStroke(halo, tierColor, 1.5, 0.3)

	if itemId == "DiamondNecklace" or itemId == "SapphireCufflinks" or itemId == "CrownJewelBrooch" or itemId == "FabergeTravelEgg" then
		-- Faceted gem icon
		local gem = makeBox(root, UDim2.fromScale(0.46, 0.46), UDim2.fromScale(0.27, 0.27), tierColor, zIndex + 2, UDim.new(0.16, 0), 45)
		addStroke(gem, outline, 2)
		makeBox(root, UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.39, 0.39), Color3.fromRGB(235, 248, 255), zIndex + 3, UDim.new(0.2, 0), 45)
	elseif itemId == "SolidGoldBar" or itemId == "BearerBonds" or itemId == "CryptoHardwareVault" or itemId == "QuantumCoreChip" then
		-- Gold/tech bullion ingot or circuit wafer
		local mainColor = if itemId == "SolidGoldBar" then Color3.fromRGB(255, 206, 62) elseif itemId == "BearerBonds" then Color3.fromRGB(92, 224, 146) else tierColor
		local bar = makeBox(root, UDim2.fromScale(0.64, 0.38), UDim2.fromScale(0.18, 0.31), mainColor, zIndex + 2, UDim.new(0.22, 0), -10)
		addStroke(bar, outline, 2)
		makeBox(bar, UDim2.fromScale(0.70, 0.34), UDim2.fromScale(0.15, 0.18), Color3.fromRGB(255, 248, 210), zIndex + 3, UDim.new(0.3, 0))
	elseif itemId == "ChampionshipTrophy" or itemId == "DiamondScepter" or itemId == "RoyalGoldPassport" then
		-- Crown / Trophy cup
		local cup = makeBox(root, UDim2.fromScale(0.46, 0.38), UDim2.fromScale(0.27, 0.20), Color3.fromRGB(255, 204, 58), zIndex + 2, UDim.new(0.24, 0))
		addStroke(cup, outline, 2)
		makeBox(root, UDim2.fromScale(0.14, 0.22), UDim2.fromScale(0.43, 0.56), Color3.fromRGB(232, 174, 42), zIndex + 2)
		local base = makeBox(root, UDim2.fromScale(0.40, 0.14), UDim2.fromScale(0.30, 0.72), Color3.fromRGB(168, 122, 34), zIndex + 3, UDim.new(0.25, 0))
		addStroke(base, outline, 1.5)
	else
		-- Crisp medallion tile with clear 3-letter item monogram
		local badge = makeBox(root, UDim2.fromScale(0.60, 0.52), UDim2.fromScale(0.20, 0.24), Color3.fromRGB(36, 46, 70), zIndex + 2, UDim.new(0.26, 0))
		addStroke(badge, tierColor, 2.2)
		local mono = Instance.new("TextLabel")
		mono.Size = UDim2.fromScale(0.84, 0.64)
		mono.Position = UDim2.fromScale(0.08, 0.18)
		mono.BackgroundTransparency = 1
		mono.Font = Enum.Font.GothamBlack
		mono.Text = iconText
		mono.TextColor3 = Color3.fromRGB(244, 248, 255)
		mono.TextScaled = true
		mono.ZIndex = zIndex + 3
		mono.Parent = badge
	end

	return root
end

-- Custom 2D vector icon for Shop Upgrades (Tool, WorkbenchCount, Sneakers, StealthCoat)
function HudIcons.CreateUpgradeIcon(
	parent: Instance,
	category: string,
	accentColor: Color3,
	size: UDim2,
	pos: UDim2,
	zIndex: number
): Frame
	local root = makeContainer(parent, "UpgradeIcon_" .. category, size, pos, zIndex)
	local outline = Color3.fromRGB(12, 18, 30)

	local halo = makeBox(root, UDim2.fromScale(0.84, 0.84), UDim2.fromScale(0.08, 0.08), accentColor, zIndex + 1, UDim.new(0.28, 0))
	halo.BackgroundTransparency = 0.80
	addStroke(halo, accentColor, 1.5, 0.35)

	if category == "Tool" then
		-- Crowbar / lockpick angled metal shaft + curved hook head
		local shaft = makeBox(root, UDim2.fromScale(0.16, 0.66), UDim2.fromScale(0.42, 0.20), accentColor, zIndex + 2, UDim.new(0.3, 0), 32)
		addStroke(shaft, outline, 2)
		local hook = makeBox(root, UDim2.fromScale(0.32, 0.15), UDim2.fromScale(0.44, 0.16), Color3.fromRGB(224, 236, 255), zIndex + 3, UDim.new(0.35, 0), 12)
		addStroke(hook, outline, 1.8)
		local tip = makeBox(root, UDim2.fromScale(0.22, 0.12), UDim2.fromScale(0.22, 0.68), Color3.fromRGB(224, 236, 255), zIndex + 3, UDim.new(0.3, 0), -58)
		addStroke(tip, outline, 1.5)
	elseif category == "WorkbenchCount" then
		-- Stylized Workbench table with status strip
		local top = makeBox(root, UDim2.fromScale(0.68, 0.18), UDim2.fromScale(0.16, 0.34), Color3.fromRGB(218, 168, 86), zIndex + 2, UDim.new(0.22, 0))
		addStroke(top, outline, 2)
		makeBox(root, UDim2.fromScale(0.56, 0.08), UDim2.fromScale(0.22, 0.26), accentColor, zIndex + 3, UDim.new(0.4, 0))
		local legL = makeBox(root, UDim2.fromScale(0.12, 0.34), UDim2.fromScale(0.22, 0.50), Color3.fromRGB(110, 122, 146), zIndex + 2, UDim.new(0.2, 0))
		addStroke(legL, outline, 1.6)
		local legR = makeBox(root, UDim2.fromScale(0.12, 0.34), UDim2.fromScale(0.66, 0.50), Color3.fromRGB(110, 122, 146), zIndex + 2, UDim.new(0.2, 0))
		addStroke(legR, outline, 1.6)
	elseif category == "Sneakers" then
		-- Running shoe profile + speed stripe
		local upper = makeBox(root, UDim2.fromScale(0.52, 0.36), UDim2.fromScale(0.18, 0.30), accentColor, zIndex + 2, UDim.new(0.32, 0))
		addStroke(upper, outline, 2)
		local toe = makeBox(root, UDim2.fromScale(0.36, 0.22), UDim2.fromScale(0.48, 0.44), accentColor, zIndex + 2, UDim.new(0.45, 0))
		addStroke(toe, outline, 1.8)
		local sole = makeBox(root, UDim2.fromScale(0.72, 0.14), UDim2.fromScale(0.14, 0.62), Color3.fromRGB(242, 248, 255), zIndex + 3, UDim.new(0.4, 0))
		addStroke(sole, outline, 1.8)
		makeBox(root, UDim2.fromScale(0.24, 0.08), UDim2.fromScale(0.28, 0.44), Color3.fromRGB(242, 248, 255), zIndex + 3, UDim.new(0.5, 0), -22)
	else
		-- StealthCoat: draped cloak & hood
		local cape = makeBox(root, UDim2.fromScale(0.62, 0.46), UDim2.fromScale(0.19, 0.36), Color3.fromRGB(68, 46, 108), zIndex + 2, UDim.new(0.24, 0))
		addStroke(cape, outline, 2)
		local hood = makeBox(root, UDim2.fromScale(0.38, 0.34), UDim2.fromScale(0.31, 0.14), accentColor, zIndex + 3, UDim.new(0.48, 0))
		addStroke(hood, outline, 2)
		makeBox(hood, UDim2.fromScale(0.54, 0.54), UDim2.fromScale(0.23, 0.28), Color3.fromRGB(20, 24, 38), zIndex + 4, UDim.new(0.5, 0))
	end

	return root
end

-- Custom 2D vector icon for Shop Items (Consumables)
function HudIcons.CreateItemIcon(
	parent: Instance,
	itemId: GameConfig.ConsumableId,
	accentColor: Color3,
	size: UDim2,
	pos: UDim2,
	zIndex: number
): Frame
	local root = makeContainer(parent, "ItemIcon_" .. itemId, size, pos, zIndex)
	local outline = Color3.fromRGB(12, 18, 30)

	local halo = makeBox(root, UDim2.fromScale(0.84, 0.84), UDim2.fromScale(0.08, 0.08), accentColor, zIndex + 1, UDim.new(0.28, 0))
	halo.BackgroundTransparency = 0.80
	addStroke(halo, accentColor, 1.5, 0.35)

	if itemId == "SmokeBomb" then
		-- Spherical bomb casing + top neck + puff rings
		local sphere = makeBox(root, UDim2.fromScale(0.48, 0.48), UDim2.fromScale(0.26, 0.36), Color3.fromRGB(72, 92, 118), zIndex + 2, UDim.new(0.5, 0))
		addStroke(sphere, outline, 2.2)
		makeBox(sphere, UDim2.fromScale(0.94, 0.20), UDim2.fromScale(0.03, 0.40), accentColor, zIndex + 3, UDim.new(0.4, 0))
		local neck = makeBox(root, UDim2.fromScale(0.18, 0.14), UDim2.fromScale(0.41, 0.24), Color3.fromRGB(224, 182, 72), zIndex + 3, UDim.new(0.2, 0))
		addStroke(neck, outline, 1.6)
		local puffL = makeBox(root, UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.18, 0.12), Color3.fromRGB(228, 240, 255), zIndex + 4, UDim.new(0.5, 0))
		addStroke(puffL, outline, 1.4)
		local puffR = makeBox(root, UDim2.fromScale(0.20, 0.20), UDim2.fromScale(0.54, 0.10), Color3.fromRGB(210, 228, 248), zIndex + 4, UDim.new(0.5, 0))
		addStroke(puffR, outline, 1.4)
	elseif itemId == "DistractionAlarm" then
		-- Twin-bell sonic decoy alarm
		local bellL = makeBox(root, UDim2.fromScale(0.20, 0.20), UDim2.fromScale(0.20, 0.18), accentColor, zIndex + 2, UDim.new(0.5, 0), -20)
		addStroke(bellL, outline, 1.6)
		local bellR = makeBox(root, UDim2.fromScale(0.20, 0.20), UDim2.fromScale(0.60, 0.18), accentColor, zIndex + 2, UDim.new(0.5, 0), 20)
		addStroke(bellR, outline, 1.6)
		local dial = makeBox(root, UDim2.fromScale(0.50, 0.50), UDim2.fromScale(0.25, 0.28), Color3.fromRGB(48, 56, 76), zIndex + 3, UDim.new(0.5, 0))
		addStroke(dial, accentColor, 2.2)
		makeBox(dial, UDim2.fromScale(0.14, 0.36), UDim2.fromScale(0.43, 0.18), accentColor, zIndex + 4, UDim.new(0.5, 0))
		makeBox(dial, UDim2.fromScale(0.32, 0.14), UDim2.fromScale(0.46, 0.44), accentColor, zIndex + 4, UDim.new(0.5, 0))
	else
		local badge = makeBox(root, UDim2.fromScale(0.52, 0.52), UDim2.fromScale(0.24, 0.24), accentColor, zIndex + 2, UDim.new(0.3, 0))
		addStroke(badge, outline, 2)
	end

	return root
end

return HudIcons
