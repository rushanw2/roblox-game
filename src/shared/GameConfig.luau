--!strict
-- Shared game configuration for "Steal a Luggage"
-- Defines terminals, passenger/luggage archetypes, loot tables, tools, upgrades, and stealth gear.

export type RarityTier = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Godly"
export type TerminalId = "Domestic" | "International" | "FirstClass" | "Celebrity"
export type BagStyle = "Duffle" | "Hardcase" | "Trunk" | "Briefcase" | "VaultCase"
export type AccessoryType = "Hat" | "Glasses" | "Headset" | "Crown" | "Scarf" | "Beret"
export type ConsumableId = "SmokeBomb" | "DistractionAlarm"

export type TerminalBounds = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

export type TerminalDef = {
	id: TerminalId,
	order: number,
	name: string,
	shortName: string,
	subtitle: string,
	unlockCost: number,
	accentColor: Color3,
	floorColor: Color3,
	detectionMultiplier: number,
	awarenessSpeedMultiplier: number,
	visionRangeBonus: number,
	maxActiveBags: number,
	allowedTiers: { RarityTier },
	spawnBounds: TerminalBounds,
	gateReturnPosition: Vector3,
}

export type ArchetypeDef = {
	id: string,
	displayName: string,
	npcTitle: string,
	tier: RarityTier,
	bagStyle: BagStyle,
	primaryColor: Color3,
	secondaryColor: Color3,
	trimColor: Color3,
	tagColor: Color3,
	skinTone: Color3,
	hairColor: Color3,
	accessoryType: AccessoryType,
	baseOpenTime: number,
	requiredToolLevel: number,
	visionRange: number,
	visionAngleDeg: number,
	suspicionRate: number,
	lootRolls: number,
}

export type LootItemDef = {
	id: string,
	name: string,
	tier: RarityTier,
	value: number,
	iconText: string,
	description: string,
}

export type ToolUpgradeDef = {
	level: number,
	id: string,
	name: string,
	cost: number,
	speedMultiplier: number,
	maxBagTier: RarityTier,
	description: string,
	color: Color3,
}

export type WorkbenchUpgradeDef = {
	level: number,
	name: string,
	cost: number,
	description: string,
}

export type SneakerUpgradeDef = {
	level: number,
	name: string,
	cost: number,
	walkSpeed: number,
	description: string,
}

export type StealthCoatUpgradeDef = {
	level: number,
	name: string,
	cost: number,
	rangeMultiplier: number,
	angleMultiplier: number,
	suspicionMultiplier: number,
	description: string,
}

export type ConsumableDef = {
	id: ConsumableId,
	name: string,
	rarity: RarityTier,
	cost: number,
	cooldown: number,
	radius: number,
	duration: number,
	color: Color3,
	description: string,
}

local GameConfig = {}

GameConfig.GAME_TITLE = "Steal a Luggage"

local TIER_ORDER: { RarityTier } = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Godly",
}
GameConfig.TIER_ORDER = TIER_ORDER

local TIER_RANK: { [RarityTier]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Godly = 6,
}
GameConfig.TIER_RANK = TIER_RANK

local TIER_COLORS: { [RarityTier]: Color3 } = {
	Common = Color3.fromRGB(168, 178, 192),
	Uncommon = Color3.fromRGB(72, 204, 128),
	Rare = Color3.fromRGB(64, 156, 255),
	Epic = Color3.fromRGB(178, 92, 255),
	Legendary = Color3.fromRGB(255, 184, 48),
	Godly = Color3.fromRGB(255, 78, 146),
}
GameConfig.TIER_COLORS = TIER_COLORS

local TIER_UNLOCK_SECONDS: { [RarityTier]: number } = {
	Common = 8,
	Uncommon = 14,
	Rare = 22,
	Epic = 34,
	Legendary = 48,
	Godly = 64,
}
GameConfig.TIER_UNLOCK_SECONDS = TIER_UNLOCK_SECONDS

-- Hideout safe-zone bounds (Z >= 102 inside Smuggler's Hideout)
GameConfig.HIDEOUT_BOUNDS = {
	minX = -68,
	maxX = 68,
	minZ = 102,
	maxZ = 162,
}

-- Safe respawn point just outside Airport Terminal doors in the courtyard
GameConfig.BUST_RESPAWN_POSITION = Vector3.new(0, 3.5, 84)
GameConfig.SPAWN_POSITION = Vector3.new(0, 3.5, 96)

GameConfig.BUST_STUN_SECONDS = 1.6
GameConfig.STEAL_RANGE = 11.5
GameConfig.WORKBENCH_INTERACT_RANGE = 12
GameConfig.OWNER_WATCH_BAG_RADIUS = 16

local TERMINAL_ORDER: { TerminalId } = {
	"Domestic",
	"International",
	"FirstClass",
	"Celebrity",
}
GameConfig.TERMINAL_ORDER = TERMINAL_ORDER

local TERMINALS: { [TerminalId]: TerminalDef } = {
	Domestic = {
		id = "Domestic",
		order = 1,
		name = "Domestic Baggage Claim",
		shortName = "Domestic",
		subtitle = "Casual flyers & looping carousels",
		unlockCost = 0,
		accentColor = Color3.fromRGB(78, 178, 255),
		floorColor = Color3.fromRGB(205, 212, 222),
		detectionMultiplier = 1.0,
		awarenessSpeedMultiplier = 1.0,
		visionRangeBonus = 0,
		maxActiveBags = 8,
		allowedTiers = { "Common", "Uncommon" },
		spawnBounds = { minX = -85, maxX = 85, minZ = -57, maxZ = 64 },
		gateReturnPosition = Vector3.new(0, 3.5, 84),
	},
	International = {
		id = "International",
		order = 2,
		name = "International Concourse",
		shortName = "International",
		subtitle = "Duty-free travelers & sharper eyes",
		unlockCost = 500,
		accentColor = Color3.fromRGB(68, 214, 152),
		floorColor = Color3.fromRGB(186, 172, 148),
		detectionMultiplier = 1.15,
		awarenessSpeedMultiplier = 1.25,
		visionRangeBonus = 4,
		maxActiveBags = 8,
		allowedTiers = { "Uncommon", "Rare" },
		spawnBounds = { minX = -207, maxX = -87, minZ = -57, maxZ = 64 },
		gateReturnPosition = Vector3.new(-74, 3.5, -12),
	},
	FirstClass = {
		id = "FirstClass",
		order = 3,
		name = "First-Class VIP Lounge",
		shortName = "First-Class",
		subtitle = "High-rollers, champagne bars & tight security",
		unlockCost = 2500,
		accentColor = Color3.fromRGB(255, 194, 64),
		floorColor = Color3.fromRGB(48, 56, 86),
		detectionMultiplier = 1.3,
		awarenessSpeedMultiplier = 1.45,
		visionRangeBonus = 7,
		maxActiveBags = 8,
		allowedTiers = { "Rare", "Epic", "Legendary" },
		spawnBounds = { minX = 87, maxX = 207, minZ = -57, maxZ = 64 },
		gateReturnPosition = Vector3.new(74, 3.5, -12),
	},
	Celebrity = {
		id = "Celebrity",
		order = 4,
		name = "Celebrity Private Terminal",
		shortName = "Celebrity",
		subtitle = "Billionaires, royalty & elite private jets",
		unlockCost = 10000,
		accentColor = Color3.fromRGB(255, 86, 152),
		floorColor = Color3.fromRGB(36, 34, 46),
		detectionMultiplier = 1.45,
		awarenessSpeedMultiplier = 1.75,
		visionRangeBonus = 10,
		maxActiveBags = 7,
		allowedTiers = { "Epic", "Legendary", "Godly" },
		spawnBounds = { minX = -115, maxX = 115, minZ = -193, maxZ = -59 },
		gateReturnPosition = Vector3.new(0, 3.5, -48),
	},
}
GameConfig.TERMINALS = TERMINALS

-- 18 distinct Passenger + Luggage pairs with matched outfits, accessories, stripes, tags, and trims
local ARCHETYPES: { ArchetypeDef } = {
	-- COMMON (3)
	{
		id = "Backpacker",
		displayName = "Trail Duffle",
		npcTitle = "Backpacker",
		tier = "Common",
		bagStyle = "Duffle",
		primaryColor = Color3.fromRGB(78, 108, 72),
		secondaryColor = Color3.fromRGB(194, 162, 112),
		trimColor = Color3.fromRGB(108, 74, 48),
		tagColor = Color3.fromRGB(255, 134, 42),
		skinTone = Color3.fromRGB(234, 192, 162),
		hairColor = Color3.fromRGB(92, 60, 36),
		accessoryType = "Hat",
		baseOpenTime = 8,
		requiredToolLevel = 1,
		visionRange = 26,
		visionAngleDeg = 72,
		suspicionRate = 32,
		lootRolls = 1,
	},
	{
		id = "CollegeStudent",
		displayName = "Campus Roller",
		npcTitle = "College Student",
		tier = "Common",
		bagStyle = "Hardcase",
		primaryColor = Color3.fromRGB(48, 102, 204),
		secondaryColor = Color3.fromRGB(240, 244, 250),
		trimColor = Color3.fromRGB(162, 174, 190),
		tagColor = Color3.fromRGB(255, 214, 52),
		skinTone = Color3.fromRGB(210, 164, 128),
		hairColor = Color3.fromRGB(34, 28, 26),
		accessoryType = "Headset",
		baseOpenTime = 8,
		requiredToolLevel = 1,
		visionRange = 25,
		visionAngleDeg = 70,
		suspicionRate = 30,
		lootRolls = 1,
	},
	{
		id = "WeekendTourist",
		displayName = "Resort Hardcase",
		npcTitle = "Sunny Tourist",
		tier = "Common",
		bagStyle = "Hardcase",
		primaryColor = Color3.fromRGB(242, 106, 122),
		secondaryColor = Color3.fromRGB(72, 210, 206),
		trimColor = Color3.fromRGB(245, 245, 245),
		tagColor = Color3.fromRGB(255, 232, 72),
		skinTone = Color3.fromRGB(244, 202, 172),
		hairColor = Color3.fromRGB(214, 168, 86),
		accessoryType = "Glasses",
		baseOpenTime = 9,
		requiredToolLevel = 1,
		visionRange = 24,
		visionAngleDeg = 68,
		suspicionRate = 28,
		lootRolls = 1,
	},

	-- UNCOMMON (3)
	{
		id = "FlightCrew",
		displayName = "Flight Crew Case",
		npcTitle = "Off-Duty Pilot",
		tier = "Uncommon",
		bagStyle = "Hardcase",
		primaryColor = Color3.fromRGB(28, 46, 84),
		secondaryColor = Color3.fromRGB(224, 184, 72),
		trimColor = Color3.fromRGB(196, 160, 56),
		tagColor = Color3.fromRGB(232, 62, 62),
		skinTone = Color3.fromRGB(226, 182, 152),
		hairColor = Color3.fromRGB(64, 56, 52),
		accessoryType = "Hat",
		baseOpenTime = 14,
		requiredToolLevel = 1,
		visionRange = 30,
		visionAngleDeg = 78,
		suspicionRate = 38,
		lootRolls = 1,
	},
	{
		id = "BusinessTraveler",
		displayName = "Executive Briefcase",
		npcTitle = "Business Traveler",
		tier = "Uncommon",
		bagStyle = "Briefcase",
		primaryColor = Color3.fromRGB(54, 60, 72),
		secondaryColor = Color3.fromRGB(178, 42, 54),
		trimColor = Color3.fromRGB(205, 214, 226),
		tagColor = Color3.fromRGB(228, 234, 242),
		skinTone = Color3.fromRGB(196, 148, 116),
		hairColor = Color3.fromRGB(42, 34, 30),
		accessoryType = "Glasses",
		baseOpenTime = 15,
		requiredToolLevel = 1,
		visionRange = 31,
		visionAngleDeg = 80,
		suspicionRate = 40,
		lootRolls = 1,
	},
	{
		id = "SkierPro",
		displayName = "Alpine Gear Pack",
		npcTitle = "Alpine Skier",
		tier = "Uncommon",
		bagStyle = "Duffle",
		primaryColor = Color3.fromRGB(44, 182, 224),
		secondaryColor = Color3.fromRGB(242, 248, 255),
		trimColor = Color3.fromRGB(150, 166, 184),
		tagColor = Color3.fromRGB(156, 255, 58),
		skinTone = Color3.fromRGB(238, 194, 166),
		hairColor = Color3.fromRGB(174, 108, 54),
		accessoryType = "Glasses",
		baseOpenTime = 14,
		requiredToolLevel = 1,
		visionRange = 29,
		visionAngleDeg = 76,
		suspicionRate = 36,
		lootRolls = 1,
	},

	-- RARE (3)
	{
		id = "FashionBuyer",
		displayName = "Couture Trunk",
		npcTitle = "Runway Stylist",
		tier = "Rare",
		bagStyle = "Trunk",
		primaryColor = Color3.fromRGB(128, 26, 56),
		secondaryColor = Color3.fromRGB(242, 218, 178),
		trimColor = Color3.fromRGB(232, 172, 152),
		tagColor = Color3.fromRGB(255, 240, 224),
		skinTone = Color3.fromRGB(166, 114, 84),
		hairColor = Color3.fromRGB(26, 20, 22),
		accessoryType = "Beret",
		baseOpenTime = 22,
		requiredToolLevel = 2,
		visionRange = 34,
		visionAngleDeg = 84,
		suspicionRate = 46,
		lootRolls = 1,
	},
	{
		id = "EsportsPro",
		displayName = "RGB Rig Case",
		npcTitle = "Esports Pro",
		tier = "Rare",
		bagStyle = "VaultCase",
		primaryColor = Color3.fromRGB(30, 32, 42),
		secondaryColor = Color3.fromRGB(0, 238, 255),
		trimColor = Color3.fromRGB(84, 92, 110),
		tagColor = Color3.fromRGB(172, 72, 255),
		skinTone = Color3.fromRGB(232, 192, 164),
		hairColor = Color3.fromRGB(48, 146, 220),
		accessoryType = "Headset",
		baseOpenTime = 22,
		requiredToolLevel = 2,
		visionRange = 33,
		visionAngleDeg = 82,
		suspicionRate = 45,
		lootRolls = 1,
	},
	{
		id = "ChefMaestro",
		displayName = "Culinary Chest",
		npcTitle = "Master Chef",
		tier = "Rare",
		bagStyle = "Trunk",
		primaryColor = Color3.fromRGB(242, 242, 244),
		secondaryColor = Color3.fromRGB(168, 42, 48),
		trimColor = Color3.fromRGB(210, 134, 72),
		tagColor = Color3.fromRGB(232, 148, 78),
		skinTone = Color3.fromRGB(216, 168, 132),
		hairColor = Color3.fromRGB(84, 58, 42),
		accessoryType = "Scarf",
		baseOpenTime = 23,
		requiredToolLevel = 2,
		visionRange = 34,
		visionAngleDeg = 84,
		suspicionRate = 47,
		lootRolls = 1,
	},

	-- EPIC (3)
	{
		id = "PopIdol",
		displayName = "Starlight Tour Case",
		npcTitle = "Pop Idol",
		tier = "Epic",
		bagStyle = "Hardcase",
		primaryColor = Color3.fromRGB(232, 54, 152),
		secondaryColor = Color3.fromRGB(186, 132, 255),
		trimColor = Color3.fromRGB(236, 242, 250),
		tagColor = Color3.fromRGB(255, 166, 224),
		skinTone = Color3.fromRGB(242, 206, 186),
		hairColor = Color3.fromRGB(255, 148, 212),
		accessoryType = "Glasses",
		baseOpenTime = 34,
		requiredToolLevel = 3,
		visionRange = 38,
		visionAngleDeg = 90,
		suspicionRate = 54,
		lootRolls = 2,
	},
	{
		id = "DiamondDealer",
		displayName = "Antwerp Jewel Vault",
		npcTitle = "Diamond Dealer",
		tier = "Epic",
		bagStyle = "VaultCase",
		primaryColor = Color3.fromRGB(22, 92, 68),
		secondaryColor = Color3.fromRGB(218, 232, 240),
		trimColor = Color3.fromRGB(200, 216, 232),
		tagColor = Color3.fromRGB(98, 224, 255),
		skinTone = Color3.fromRGB(224, 178, 148),
		hairColor = Color3.fromRGB(168, 168, 174),
		accessoryType = "Glasses",
		baseOpenTime = 35,
		requiredToolLevel = 3,
		visionRange = 40,
		visionAngleDeg = 92,
		suspicionRate = 56,
		lootRolls = 2,
	},
	{
		id = "CyberCollector",
		displayName = "Synthwave Archive",
		npcTitle = "Retro Collector",
		tier = "Epic",
		bagStyle = "Briefcase",
		primaryColor = Color3.fromRGB(88, 36, 156),
		secondaryColor = Color3.fromRGB(255, 122, 42),
		trimColor = Color3.fromRGB(218, 224, 236),
		tagColor = Color3.fromRGB(255, 226, 62),
		skinTone = Color3.fromRGB(184, 136, 102),
		hairColor = Color3.fromRGB(40, 26, 56),
		accessoryType = "Glasses",
		baseOpenTime = 34,
		requiredToolLevel = 3,
		visionRange = 38,
		visionAngleDeg = 90,
		suspicionRate = 54,
		lootRolls = 2,
	},

	-- LEGENDARY (3)
	{
		id = "TechBillionaire",
		displayName = "Titan Quantum Case",
		npcTitle = "Tech Billionaire",
		tier = "Legendary",
		bagStyle = "VaultCase",
		primaryColor = Color3.fromRGB(72, 78, 88),
		secondaryColor = Color3.fromRGB(48, 168, 255),
		trimColor = Color3.fromRGB(118, 198, 255),
		tagColor = Color3.fromRGB(22, 26, 34),
		skinTone = Color3.fromRGB(234, 194, 164),
		hairColor = Color3.fromRGB(122, 118, 116),
		accessoryType = "Glasses",
		baseOpenTime = 48,
		requiredToolLevel = 3,
		visionRange = 42,
		visionAngleDeg = 96,
		suspicionRate = 64,
		lootRolls = 2,
	},
	{
		id = "FilmDirector",
		displayName = "Palme d'Or Trunk",
		npcTitle = "Auteur Director",
		tier = "Legendary",
		bagStyle = "Trunk",
		primaryColor = Color3.fromRGB(38, 26, 46),
		secondaryColor = Color3.fromRGB(244, 164, 52),
		trimColor = Color3.fromRGB(228, 184, 68),
		tagColor = Color3.fromRGB(204, 38, 62),
		skinTone = Color3.fromRGB(208, 160, 128),
		hairColor = Color3.fromRGB(202, 202, 210),
		accessoryType = "Scarf",
		baseOpenTime = 48,
		requiredToolLevel = 3,
		visionRange = 42,
		visionAngleDeg = 94,
		suspicionRate = 62,
		lootRolls = 2,
	},
	{
		id = "RacingChamp",
		displayName = "Grand Prix Flight Case",
		npcTitle = "Racing Champion",
		tier = "Legendary",
		bagStyle = "Hardcase",
		primaryColor = Color3.fromRGB(208, 28, 36),
		secondaryColor = Color3.fromRGB(246, 246, 248),
		trimColor = Color3.fromRGB(238, 190, 58),
		tagColor = Color3.fromRGB(255, 212, 54),
		skinTone = Color3.fromRGB(230, 184, 152),
		hairColor = Color3.fromRGB(68, 44, 28),
		accessoryType = "Hat",
		baseOpenTime = 49,
		requiredToolLevel = 3,
		visionRange = 43,
		visionAngleDeg = 96,
		suspicionRate = 65,
		lootRolls = 2,
	},

	-- GODLY (3)
	{
		id = "RoyalEnvoy",
		displayName = "Sovereign Crown Chest",
		npcTitle = "Royal Envoy",
		tier = "Godly",
		bagStyle = "Trunk",
		primaryColor = Color3.fromRGB(88, 28, 138),
		secondaryColor = Color3.fromRGB(255, 206, 62),
		trimColor = Color3.fromRGB(255, 218, 86),
		tagColor = Color3.fromRGB(196, 24, 58),
		skinTone = Color3.fromRGB(238, 198, 170),
		hairColor = Color3.fromRGB(54, 42, 36),
		accessoryType = "Crown",
		baseOpenTime = 64,
		requiredToolLevel = 4,
		visionRange = 46,
		visionAngleDeg = 104,
		suspicionRate = 76,
		lootRolls = 2,
	},
	{
		id = "SecretMogul",
		displayName = "Obsidian Cipher Vault",
		npcTitle = "Shadow Magnate",
		tier = "Godly",
		bagStyle = "VaultCase",
		primaryColor = Color3.fromRGB(20, 22, 28),
		secondaryColor = Color3.fromRGB(36, 232, 146),
		trimColor = Color3.fromRGB(242, 198, 72),
		tagColor = Color3.fromRGB(52, 255, 168),
		skinTone = Color3.fromRGB(178, 130, 98),
		hairColor = Color3.fromRGB(24, 24, 28),
		accessoryType = "Hat",
		baseOpenTime = 64,
		requiredToolLevel = 4,
		visionRange = 48,
		visionAngleDeg = 106,
		suspicionRate = 78,
		lootRolls = 2,
	},
	{
		id = "GalacticIcon",
		displayName = "Prismatic Couture Safe",
		npcTitle = "Starlight Icon",
		tier = "Godly",
		bagStyle = "VaultCase",
		primaryColor = Color3.fromRGB(242, 234, 214),
		secondaryColor = Color3.fromRGB(68, 238, 255),
		trimColor = Color3.fromRGB(255, 212, 92),
		tagColor = Color3.fromRGB(255, 96, 194),
		skinTone = Color3.fromRGB(228, 186, 158),
		hairColor = Color3.fromRGB(255, 232, 168),
		accessoryType = "Crown",
		baseOpenTime = 65,
		requiredToolLevel = 4,
		visionRange = 47,
		visionAngleDeg = 105,
		suspicionRate = 78,
		lootRolls = 2,
	},
}
GameConfig.ARCHETYPES = ARCHETYPES

-- 28 distinct inside-luggage sellable items across all 6 tiers
local LOOT_ITEMS: { LootItemDef } = {
	-- Common (5)
	{ id = "SouvenirKeychain", name = "Souvenir Keychain", tier = "Common", value = 30, iconText = "KEY", description = "Glossy airport tower keychain." },
	{ id = "DutyFreeChocolates", name = "Duty-Free Chocolates", tier = "Common", value = 42, iconText = "CHC", description = "Gold-foil Swiss airport truffle box." },
	{ id = "TravelNeckPillow", name = "Memory-Foam Pillow", tier = "Common", value = 48, iconText = "PLW", description = "Plush first-row neck pillow." },
	{ id = "PolaroidCamera", name = "Instant Film Camera", tier = "Common", value = 65, iconText = "CAM", description = "Retro pastel instant camera." },
	{ id = "TravelEspresso", name = "Portable Espresso Kit", tier = "Common", value = 78, iconText = "ESP", description = "Pocket press & roast pods." },

	-- Uncommon (5)
	{ id = "NoiseHeadphones", name = "ANC Studio Headphones", tier = "Uncommon", value = 125, iconText = "HDP", description = "Matte-black noise canceling cans." },
	{ id = "DesignerShades", name = "Designer Aviators", tier = "Uncommon", value = 155, iconText = "SHD", description = "Polarized titanium sunglasses." },
	{ id = "SilkNecktieSet", name = "Italian Silk Tie Box", tier = "Uncommon", value = 180, iconText = "TIE", description = "Hand-stitched Milanese silk set." },
	{ id = "VintageWatch", name = "Vintage Field Watch", tier = "Uncommon", value = 225, iconText = "WTC", description = "Mechanical timepiece in leather pouch." },
	{ id = "RetroHandheld", name = "Modded Retro Handheld", tier = "Uncommon", value = 260, iconText = "GME", description = "IPS-screen pocket gaming console." },

	-- Rare (5)
	{ id = "AnimeFigurine", name = "Rare Anime Figurine", tier = "Rare", value = 420, iconText = "FIG", description = "Numbered Akihabara collector edition." },
	{ id = "HypeSneakers", name = "Deadstock Collab Kicks", tier = "Rare", value = 520, iconText = "SNK", description = "Unworn limited runway sneakers." },
	{ id = "SwissChronograph", name = "Swiss Chronograph", tier = "Rare", value = 660, iconText = "CHR", description = "Automatic sapphire-crystal watch." },
	{ id = "GoldFountainPen", name = "18k Gold Fountain Pen", tier = "Rare", value = 790, iconText = "PEN", description = "Lacquered executive signing pen." },
	{ id = "SapphireCufflinks", name = "Sapphire Cufflinks", tier = "Rare", value = 920, iconText = "CUF", description = "Velvet-boxed royal blue cufflinks." },

	-- Epic (5)
	{ id = "SolidGoldBar", name = "Stamped Gold Bar", tier = "Epic", value = 1450, iconText = "GLD", description = "Heavy 999.9 bullion ingot." },
	{ id = "DiamondNecklace", name = "Diamond Tennis Necklace", tier = "Epic", value = 1850, iconText = "DMD", description = "Dazzling platinum-set diamonds." },
	{ id = "HoloTradingCard", name = "PSA-10 Holo Card", tier = "Epic", value = 2200, iconText = "CRD", description = "Slabbed holographic championship card." },
	{ id = "CryptoHardwareVault", name = "Cold-Storage Hardware Key", tier = "Epic", value = 2600, iconText = "BTC", description = "Encrypted titanium seed-phrase vault." },
	{ id = "CoutureHandbag", name = "Atelier Velvet Clutch", tier = "Epic", value = 3050, iconText = "BAG", description = "Waitlist-only Paris couture bag." },

	-- Legendary (4)
	{ id = "PrototypeTech", name = "Prototype Holo-Phone", tier = "Legendary", value = 4800, iconText = "HLO", description = "Unreleased holographic flagship device." },
	{ id = "BearerBonds", name = "Unmarked Bearer Bonds", tier = "Legendary", value = 6200, iconText = "BND", description = "High-denomination international bonds." },
	{ id = "ChampionshipTrophy", name = "Solid Gold Paddock Cup", tier = "Legendary", value = 7600, iconText = "TRP", description = "Engraved motorsport championship cup." },
	{ id = "FabergeTravelEgg", name = "Jeweled Travel Egg", tier = "Legendary", value = 9200, iconText = "EGG", description = "Enameled gold collector artifact." },

	-- Godly (4)
	{ id = "CrownJewelBrooch", name = "Crown Jewel Brooch", tier = "Godly", value = 15000, iconText = "CRN", description = "Museum-grade emerald & diamond crest." },
	{ id = "DiamondScepter", name = "Sovereign Miniature Scepter", tier = "Godly", value = 21000, iconText = "SCP", description = "Diplomatic ceremonial gold artifact." },
	{ id = "QuantumCoreChip", name = "Orbital Quantum Wafer", tier = "Godly", value = 28500, iconText = "QNT", description = "Experimental room-temp quantum chip." },
	{ id = "RoyalGoldPassport", name = "Platinum-Gold Diplomatic Case", tier = "Godly", value = 36000, iconText = "VIP", description = "Ultra-rare sovereign clearance folio." },
}
GameConfig.LOOT_ITEMS = LOOT_ITEMS

-- Rarity weights when cracking a bag of a given tier
local TIER_LOOT_WEIGHTS: { [RarityTier]: { [RarityTier]: number } } = {
	Common = { Common = 78, Uncommon = 20, Rare = 2, Epic = 0, Legendary = 0, Godly = 0 },
	Uncommon = { Common = 22, Uncommon = 62, Rare = 15, Epic = 1, Legendary = 0, Godly = 0 },
	Rare = { Common = 0, Uncommon = 24, Rare = 60, Epic = 15, Legendary = 1, Godly = 0 },
	Epic = { Common = 0, Uncommon = 0, Rare = 25, Epic = 58, Legendary = 16, Godly = 1 },
	Legendary = { Common = 0, Uncommon = 0, Rare = 0, Epic = 26, Legendary = 62, Godly = 12 },
	Godly = { Common = 0, Uncommon = 0, Rare = 0, Epic = 8, Legendary = 34, Godly = 58 },
}
GameConfig.TIER_LOOT_WEIGHTS = TIER_LOOT_WEIGHTS

local CRACKING_TOOLS: { ToolUpgradeDef } = {
	{
		level = 1,
		id = "BobbyPin",
		name = "Rusty Bobby Pin",
		cost = 0,
		speedMultiplier = 1.0,
		maxBagTier = "Uncommon",
		description = "Cracks Common & Uncommon bags at base speed.",
		color = Color3.fromRGB(168, 174, 184),
	},
	{
		level = 2,
		id = "LockpickSet",
		name = "Lockpick Set",
		cost = 350,
		speedMultiplier = 1.45,
		maxBagTier = "Rare",
		description = "1.45x crack speed & unlocks Rare luggage.",
		color = Color3.fromRGB(78, 174, 255),
	},
	{
		level = 3,
		id = "HydraulicCrowbar",
		name = "Hydraulic Crowbar",
		cost = 1600,
		speedMultiplier = 2.1,
		maxBagTier = "Legendary",
		description = "2.1x crack speed & pries open Epic & Legendary cases.",
		color = Color3.fromRGB(255, 180, 52),
	},
	{
		level = 4,
		id = "LaserCutter",
		name = "Laser Cutter",
		cost = 6500,
		speedMultiplier = 3.2,
		maxBagTier = "Godly",
		description = "3.2x crack speed & cuts open Godly vaults.",
		color = Color3.fromRGB(255, 76, 146),
	},
}
GameConfig.CRACKING_TOOLS = CRACKING_TOOLS

local WORKBENCH_UPGRADES: { WorkbenchUpgradeDef } = {
	{ level = 1, name = "Starter Workbench", cost = 0, description = "1 passive cracking bench." },
	{ level = 2, name = "Twin Cracking Bench", cost = 400, description = "Unlocks Workbench Slot #2." },
	{ level = 3, name = "Workshop Expansion", cost = 1800, description = "Unlocks Workbench Slot #3." },
	{ level = 4, name = "Master Vault Lab", cost = 5500, description = "Unlocks all 4 Workbench Slots." },
}
GameConfig.WORKBENCH_UPGRADES = WORKBENCH_UPGRADES

local SNEAKER_UPGRADES: { SneakerUpgradeDef } = {
	{ level = 1, name = "Canvas Slip-Ons", cost = 0, walkSpeed = 16, description = "Standard terminal footwear." },
	{ level = 2, name = "Rubber-Sole Runners", cost = 300, walkSpeed = 19, description = "+19% sprint agility." },
	{ level = 3, name = "Silent Aero Trainers", cost = 1400, walkSpeed = 22.5, description = "Whisper-quiet soles for quick getaways." },
	{ level = 4, name = "Phantom Carbon Kicks", cost = 5000, walkSpeed = 26, description = "Max getaway sprint speed." },
}
GameConfig.SNEAKER_UPGRADES = SNEAKER_UPGRADES

local STEALTH_COAT_UPGRADES: { StealthCoatUpgradeDef } = {
	{ level = 1, name = "Hooded Windbreaker", cost = 0, rangeMultiplier = 1.0, angleMultiplier = 1.0, suspicionMultiplier = 1.0, description = "Baseline disguise." },
	{ level = 2, name = "Traveler Trench", cost = 450, rangeMultiplier = 0.88, angleMultiplier = 0.88, suspicionMultiplier = 0.85, description = "-12% enemy cone range & angle." },
	{ level = 3, name = "Chameleon Coat", cost = 2000, rangeMultiplier = 0.74, angleMultiplier = 0.76, suspicionMultiplier = 0.70, description = "-26% enemy cone range & -30% suspicion." },
	{ level = 4, name = "Optical Stealth Cloak", cost = 7500, rangeMultiplier = 0.58, angleMultiplier = 0.62, suspicionMultiplier = 0.52, description = "Elite camouflage against VIP & Royal guards." },
}
GameConfig.STEALTH_COAT_UPGRADES = STEALTH_COAT_UPGRADES

local CONSUMABLES: { [ConsumableId]: ConsumableDef } = {
	SmokeBomb = {
		id = "SmokeBomb",
		name = "Smoke Bomb",
		rarity = "Common",
		cost = 150,
		cooldown = 10,
		radius = 22,
		duration = 6.5,
		color = Color3.fromRGB(165, 190, 215),
		description = "Drops a dense smoke cloud blocking NPC line-of-sight for 6.5s.",
	},
	DistractionAlarm = {
		id = "DistractionAlarm",
		name = "Distraction Alarm",
		rarity = "Common",
		cost = 220,
		cooldown = 12,
		radius = 38,
		duration = 7.5,
		color = Color3.fromRGB(255, 168, 48),
		description = "Chirping decoy pulls nearby passengers to turn away for 7.5s.",
	},
}
GameConfig.CONSUMABLES = CONSUMABLES

local CONSUMABLE_ORDER: { ConsumableId } = {
	"SmokeBomb",
	"DistractionAlarm",
}
GameConfig.CONSUMABLE_ORDER = CONSUMABLE_ORDER

-- Lookup helpers
local archetypeById: { [string]: ArchetypeDef } = {}
local archetypesByTier: { [RarityTier]: { ArchetypeDef } } = {
	Common = {},
	Uncommon = {},
	Rare = {},
	Epic = {},
	Legendary = {},
	Godly = {},
}
for _, arch in ipairs(GameConfig.ARCHETYPES) do
	archetypeById[arch.id] = arch
	table.insert(archetypesByTier[arch.tier], arch)
end

local lootById: { [string]: LootItemDef } = {}
local lootByTier: { [RarityTier]: { LootItemDef } } = {
	Common = {},
	Uncommon = {},
	Rare = {},
	Epic = {},
	Legendary = {},
	Godly = {},
}
for _, item in ipairs(GameConfig.LOOT_ITEMS) do
	lootById[item.id] = item
	table.insert(lootByTier[item.tier], item)
end

function GameConfig.GetArchetype(archetypeId: string): ArchetypeDef?
	return archetypeById[archetypeId]
end

function GameConfig.GetArchetypesForTier(tier: RarityTier): { ArchetypeDef }
	return archetypesByTier[tier]
end

function GameConfig.GetLootItem(itemId: string): LootItemDef?
	return lootById[itemId]
end

function GameConfig.GetLootItemsForTier(tier: RarityTier): { LootItemDef }
	return lootByTier[tier]
end

function GameConfig.GetToolUpgrade(level: number): ToolUpgradeDef
	local clamped = math.clamp(level, 1, #GameConfig.CRACKING_TOOLS)
	return GameConfig.CRACKING_TOOLS[clamped]
end

function GameConfig.GetWorkbenchUpgrade(level: number): WorkbenchUpgradeDef
	local clamped = math.clamp(level, 1, #GameConfig.WORKBENCH_UPGRADES)
	return GameConfig.WORKBENCH_UPGRADES[clamped]
end

function GameConfig.GetSneakerUpgrade(level: number): SneakerUpgradeDef
	local clamped = math.clamp(level, 1, #GameConfig.SNEAKER_UPGRADES)
	return GameConfig.SNEAKER_UPGRADES[clamped]
end

function GameConfig.GetStealthCoatUpgrade(level: number): StealthCoatUpgradeDef
	local clamped = math.clamp(level, 1, #GameConfig.STEALTH_COAT_UPGRADES)
	return GameConfig.STEALTH_COAT_UPGRADES[clamped]
end

function GameConfig.CanToolCrackTier(toolLevel: number, tier: RarityTier): boolean
	local tool = GameConfig.GetToolUpgrade(toolLevel)
	return GameConfig.TIER_RANK[tool.maxBagTier] >= GameConfig.TIER_RANK[tier]
end

function GameConfig.GetTerminalBustFine(terminalId: TerminalId): number
	if terminalId == "Domestic" then
		return 30
	elseif terminalId == "International" then
		return 90
	elseif terminalId == "FirstClass" then
		return 250
	else
		return 650
	end
end

function GameConfig.IsPointInHideout(position: Vector3): boolean
	local b = GameConfig.HIDEOUT_BOUNDS
	return position.X >= b.minX and position.X <= b.maxX and position.Z >= b.minZ and position.Z <= b.maxZ
end

function GameConfig.GetTerminalAtPosition(position: Vector3): TerminalId?
	for _, terminalId in ipairs(GameConfig.TERMINAL_ORDER) do
		local def = GameConfig.TERMINALS[terminalId]
		local b = def.spawnBounds
		if position.X >= b.minX and position.X <= b.maxX and position.Z >= b.minZ and position.Z <= b.maxZ then
			return terminalId
		end
	end
	return nil
end

function GameConfig.FormatCash(amount: number): string
	local rounded = math.floor(amount + 0.5)
	local formatted = tostring(rounded)
	local k: number
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return "$" .. formatted
end

return GameConfig
