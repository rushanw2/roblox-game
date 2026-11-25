--!strict
-- Central configuration for Deep Trench Excavation & Anime Companion game

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Godly"
export type ZoneId = "ShallowReef" | "SunkenRuins" | "AbyssalTrench"
export type RelicCategory = "Treasure" | "Ruin" | "Fossil"
export type UpgradeId = "Oxygen" | "SwimSpeed" | "LightStrength"
export type ShopItemId = "OxygenCanister" | "SpeedPotion" | "TreasureLuckCharm" | "AutoScrubberBoost"
export type EggId = "CoralEgg" | "SunkenShrineEgg" | "AbyssalPearlEgg" | "CelestialStarEgg"
export type HairStyle = "TwinTails" | "LongWave" | "BobCut" | "SideTail" | "RoyalBraid"
export type AccessoryType = "None" | "Ribbon" | "ShellCrown" | "Halo" | "AngelWings" | "StarHaloAndWings" | "DivineAura"

export type RarityMeta = {
	name: Rarity,
	order: number,
	color: Color3,
	glowColor: Color3,
	badgeBg: Color3,
}

export type ZoneConfig = {
	id: ZoneId,
	name: string,
	minDepth: number,
	maxDepth: number,
	minY: number,
	maxY: number,
	oxygenDrainMultiplier: number,
	accentColor: Color3,
	fogColor: Color3,
	fogStart: number,
	fogEnd: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	colorShiftTop: Color3,
	brightness: number,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	atmosphereDensity: number,
	excavationRarityWeights: { [Rarity]: number },
}

export type RelicConfig = {
	id: string,
	name: string,
	category: RelicCategory,
	rarity: Rarity,
	zones: { ZoneId },
	findable: boolean,
	requiresCleaning: boolean,
	cleanDuration: number,
	revealedItemId: string?,
	sellValue: number,
	color: Color3,
	description: string,
}

export type PetPassives = {
	oxygenCapacityBonus: number,
	swimSpeedBonus: number,
	excavationSpeedBonus: number,
	cleaningSpeedBonus: number,
	coinMultiplierBonus: number,
}

export type PetSpeciesConfig = {
	id: string,
	name: string,
	title: string,
	rarity: Rarity,
	hairColor: Color3,
	outfitColor: Color3,
	accentColor: Color3,
	eyeColor: Color3,
	skinColor: Color3,
	hairStyle: HairStyle,
	accessoryType: AccessoryType,
	hasHalo: boolean,
	hasWings: boolean,
	hasAura: boolean,
	passives: PetPassives,
}

export type EggConfig = {
	id: EggId,
	name: string,
	cost: number,
	description: string,
	primaryColor: Color3,
	secondaryColor: Color3,
	pedestalIndex: number,
	rarityWeights: { [Rarity]: number },
}

export type OxygenTierConfig = {
	level: number,
	name: string,
	cost: number,
	maxOxygen: number,
}

export type SwimSpeedTierConfig = {
	level: number,
	name: string,
	cost: number,
	swimSpeed: number,
}

export type LightStrengthTierConfig = {
	level: number,
	name: string,
	cost: number,
	brightness: number,
	range: number,
	angle: number,
	color: Color3,
}

export type ShopItemConfig = {
	id: ShopItemId,
	name: string,
	cost: number,
	duration: number,
	description: string,
	accentColor: Color3,
}

local GameConfig = {}

GameConfig.WATER_SURFACE_Y = 0
GameConfig.SPAWN_POSITION = Vector3.new(0, 8.5, -150)
GameConfig.PIER_RESCUE_POSITION = Vector3.new(0, 8.0, -108)
GameConfig.CLEANING_STATION_POSITION = Vector3.new(-34, 6.0, -138)
GameConfig.APPRAISAL_COUNTER_POSITION = Vector3.new(-34, 6.0, -162)
GameConfig.SHOP_STALL_POSITION = Vector3.new(34, 6.0, -138)
GameConfig.EGG_SHRINE_POSITION = Vector3.new(34, 6.0, -166)

GameConfig.MAX_EQUIPPED_PETS = 4
GameConfig.MAX_OWNED_PETS = 250
GameConfig.MAX_RELICS_PER_BUCKET = 250
GameConfig.CLEANING_SLOT_COUNT = 3
GameConfig.STARTING_COINS = 100

GameConfig.BASE_OXYGEN_DRAIN_PER_SEC = 3.2
GameConfig.SURFACE_OXYGEN_REFILL_PER_SEC = 42.0
GameConfig.LAND_WALK_SPEED = 24.0
GameConfig.BASE_DIG_DURATION = 2.6

GameConfig.RARITY_ORDER = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Godly",
} :: { Rarity }

GameConfig.RARITY_META = {
	Common = {
		name = "Common",
		order = 1,
		color = Color3.fromRGB(205, 214, 224),
		glowColor = Color3.fromRGB(165, 178, 194),
		badgeBg = Color3.fromRGB(58, 66, 78),
	},
	Uncommon = {
		name = "Uncommon",
		order = 2,
		color = Color3.fromRGB(102, 232, 152),
		glowColor = Color3.fromRGB(62, 200, 118),
		badgeBg = Color3.fromRGB(28, 78, 52),
	},
	Rare = {
		name = "Rare",
		order = 3,
		color = Color3.fromRGB(88, 186, 255),
		glowColor = Color3.fromRGB(56, 146, 240),
		badgeBg = Color3.fromRGB(26, 62, 102),
	},
	Epic = {
		name = "Epic",
		order = 4,
		color = Color3.fromRGB(202, 120, 255),
		glowColor = Color3.fromRGB(172, 74, 245),
		badgeBg = Color3.fromRGB(68, 30, 102),
	},
	Legendary = {
		name = "Legendary",
		order = 5,
		color = Color3.fromRGB(255, 204, 72),
		glowColor = Color3.fromRGB(255, 165, 36),
		badgeBg = Color3.fromRGB(102, 70, 18),
	},
	Godly = {
		name = "Godly",
		order = 6,
		color = Color3.fromRGB(255, 118, 216),
		glowColor = Color3.fromRGB(255, 70, 180),
		badgeBg = Color3.fromRGB(106, 22, 82),
	},
} :: { [Rarity]: RarityMeta }

GameConfig.ZONE_ORDER = {
	"ShallowReef",
	"SunkenRuins",
	"AbyssalTrench",
} :: { ZoneId }

GameConfig.ZONES = {
	ShallowReef = {
		id = "ShallowReef",
		name = "Shallow Reef",
		minDepth = 0,
		maxDepth = 85,
		minY = -85,
		maxY = 0,
		oxygenDrainMultiplier = 1.0,
		accentColor = Color3.fromRGB(70, 222, 218),
		fogColor = Color3.fromRGB(28, 134, 162),
		fogStart = 32,
		fogEnd = 220,
		ambient = Color3.fromRGB(72, 138, 158),
		outdoorAmbient = Color3.fromRGB(92, 164, 182),
		colorShiftTop = Color3.fromRGB(115, 220, 232),
		brightness = 1.9,
		atmosphereColor = Color3.fromRGB(56, 178, 204),
		atmosphereDecay = Color3.fromRGB(24, 96, 128),
		atmosphereDensity = 0.34,
		excavationRarityWeights = {
			Common = 48,
			Uncommon = 30,
			Rare = 15,
			Epic = 6,
			Legendary = 1,
			Godly = 0,
		},
	},
	SunkenRuins = {
		id = "SunkenRuins",
		name = "Sunken Ruins",
		minDepth = 85,
		maxDepth = 185,
		minY = -185,
		maxY = -85,
		oxygenDrainMultiplier = 1.65,
		accentColor = Color3.fromRGB(82, 160, 255),
		fogColor = Color3.fromRGB(16, 62, 112),
		fogStart = 16,
		fogEnd = 140,
		ambient = Color3.fromRGB(38, 72, 118),
		outdoorAmbient = Color3.fromRGB(44, 86, 134),
		colorShiftTop = Color3.fromRGB(58, 126, 188),
		brightness = 1.15,
		atmosphereColor = Color3.fromRGB(26, 88, 148),
		atmosphereDecay = Color3.fromRGB(10, 38, 78),
		atmosphereDensity = 0.48,
		excavationRarityWeights = {
			Common = 12,
			Uncommon = 28,
			Rare = 33,
			Epic = 18,
			Legendary = 8,
			Godly = 1,
		},
	},
	AbyssalTrench = {
		id = "AbyssalTrench",
		name = "Abyssal Trench",
		minDepth = 185,
		maxDepth = 300,
		minY = -300,
		maxY = -185,
		oxygenDrainMultiplier = 2.6,
		accentColor = Color3.fromRGB(184, 98, 255),
		fogColor = Color3.fromRGB(7, 11, 32),
		fogStart = 5,
		fogEnd = 74,
		ambient = Color3.fromRGB(14, 16, 40),
		outdoorAmbient = Color3.fromRGB(16, 20, 48),
		colorShiftTop = Color3.fromRGB(30, 24, 68),
		brightness = 0.35,
		atmosphereColor = Color3.fromRGB(12, 16, 48),
		atmosphereDecay = Color3.fromRGB(4, 6, 20),
		atmosphereDensity = 0.68,
		excavationRarityWeights = {
			Common = 0,
			Uncommon = 8,
			Rare = 26,
			Epic = 36,
			Legendary = 22,
			Godly = 8,
		},
	},
} :: { [ZoneId]: ZoneConfig }

GameConfig.SURFACE_ATMOSPHERE = {
	fogColor = Color3.fromRGB(186, 224, 248),
	fogStart = 180,
	fogEnd = 1200,
	ambient = Color3.fromRGB(132, 148, 168),
	outdoorAmbient = Color3.fromRGB(154, 174, 196),
	colorShiftTop = Color3.fromRGB(255, 244, 224),
	brightness = 2.5,
	atmosphereColor = Color3.fromRGB(190, 226, 250),
	atmosphereDecay = Color3.fromRGB(120, 168, 210),
	atmosphereDensity = 0.24,
}

GameConfig.RELICS = {
	-- Shallow & Common / Uncommon Findable + Revealed
	SeaGlassDoubloon = {
		id = "SeaGlassDoubloon",
		name = "Sea-Glass Doubloon",
		category = "Treasure",
		rarity = "Common",
		zones = { "ShallowReef" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 28,
		color = Color3.fromRGB(122, 224, 208),
		description = "A smooth ocean-tumbled coin shimmering with teal sea glass.",
	},
	DriftwoodCompass = {
		id = "DriftwoodCompass",
		name = "Driftwood Pocket Compass",
		category = "Treasure",
		rarity = "Common",
		zones = { "ShallowReef" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 34,
		color = Color3.fromRGB(186, 142, 92),
		description = "A brass mariner compass nestled inside carved driftwood.",
	},
	CoralPearlPin = {
		id = "CoralPearlPin",
		name = "Coral Pearl Hairpin",
		category = "Treasure",
		rarity = "Common",
		zones = { "ShallowReef" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 32,
		color = Color3.fromRGB(255, 168, 178),
		description = "A delicate reef pearl mounted on tarnished silver.",
	},
	BarnaclePebble = {
		id = "BarnaclePebble",
		name = "Barnacle-Crusted Fossil Stone",
		category = "Fossil",
		rarity = "Common",
		zones = { "ShallowReef", "SunkenRuins" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 5,
		revealedItemId = "AmmoniteAmberGem",
		sellValue = 14,
		color = Color3.fromRGB(142, 138, 128),
		description = "Thick barnacles hide something spiral inside. Scrub at the Cleaning Station!",
	},
	AmmoniteAmberGem = {
		id = "AmmoniteAmberGem",
		name = "Polished Ammonite Gem",
		category = "Fossil",
		rarity = "Common",
		zones = { "ShallowReef" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 62,
		color = Color3.fromRGB(238, 184, 86),
		description = "Uncovered golden ammonite fossil sparkling cleanly after scrubbing.",
	},
	SiltCoatedSherd = {
		id = "SiltCoatedSherd",
		name = "Silt-Coated Clay Vessel",
		category = "Ruin",
		rarity = "Common",
		zones = { "ShallowReef", "SunkenRuins" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 6,
		revealedItemId = "PaintedSeawaveAmphora",
		sellValue = 16,
		color = Color3.fromRGB(134, 118, 102),
		description = "Caked in thick reef silt. Needs scrubbing to reveal its glaze.",
	},
	PaintedSeawaveAmphora = {
		id = "PaintedSeawaveAmphora",
		name = "Painted Seawave Amphora",
		category = "Ruin",
		rarity = "Uncommon",
		zones = { "ShallowReef", "SunkenRuins" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 86,
		color = Color3.fromRGB(98, 202, 224),
		description = "An intact ancient painted vase uncovered beneath layers of silt.",
	},

	-- Uncommon
	BrassAstrolabe = {
		id = "BrassAstrolabe",
		name = "Mariner Brass Astrolabe",
		category = "Treasure",
		rarity = "Uncommon",
		zones = { "ShallowReef", "SunkenRuins" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 80,
		color = Color3.fromRGB(224, 184, 96),
		description = "A finely engraved navigation ring used by old ocean explorers.",
	},
	SilverMarinerGoblet = {
		id = "SilverMarinerGoblet",
		name = "Silver Tide Goblet",
		category = "Treasure",
		rarity = "Uncommon",
		zones = { "ShallowReef", "SunkenRuins" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 88,
		color = Color3.fromRGB(214, 226, 240),
		description = "A gleaming chalice etched with cresting wave patterns.",
	},
	EncrustedTrilobiteSlab = {
		id = "EncrustedTrilobiteSlab",
		name = "Encrusted Trilobite Slab",
		category = "Fossil",
		rarity = "Uncommon",
		zones = { "ShallowReef", "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 8,
		revealedItemId = "GildedTrilobiteFossil",
		sellValue = 42,
		color = Color3.fromRGB(118, 126, 118),
		description = "Heavy limestone crust conceals prehistoric ridges. Clean to uncover!",
	},
	GildedTrilobiteFossil = {
		id = "GildedTrilobiteFossil",
		name = "Pyrite-Gilded Trilobite",
		category = "Fossil",
		rarity = "Rare",
		zones = { "SunkenRuins" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 175,
		color = Color3.fromRGB(246, 212, 92),
		description = "Rare golden-pyrite fossilized trilobite revealed in pristine detail.",
	},
	AlgaeRuneTablet = {
		id = "AlgaeRuneTablet",
		name = "Algae-Covered Rune Slate",
		category = "Ruin",
		rarity = "Uncommon",
		zones = { "ShallowReef", "SunkenRuins" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 9,
		revealedItemId = "LuminousAtlanteanTablet",
		sellValue = 46,
		color = Color3.fromRGB(78, 128, 96),
		description = "Thick sea moss blankets glowing carvings. Scrub it clean on the dock!",
	},
	LuminousAtlanteanTablet = {
		id = "LuminousAtlanteanTablet",
		name = "Luminous Atlantean Tablet",
		category = "Ruin",
		rarity = "Rare",
		zones = { "SunkenRuins" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 195,
		color = Color3.fromRGB(92, 224, 255),
		description = "Glowing turquoise temple glyphs shimmer across polished marble.",
	},

	-- Rare
	SunkenSapphireMedallion = {
		id = "SunkenSapphireMedallion",
		name = "Sunken Sapphire Medallion",
		category = "Treasure",
		rarity = "Rare",
		zones = { "ShallowReef", "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 185,
		color = Color3.fromRGB(72, 168, 255),
		description = "A royal sapphire pendant resting intact inside coral sand.",
	},
	CalcifiedNautilusCore = {
		id = "CalcifiedNautilusCore",
		name = "Calcified Nautilus Shell",
		category = "Fossil",
		rarity = "Rare",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 11,
		revealedItemId = "OpalizedNautilusCrown",
		sellValue = 95,
		color = Color3.fromRGB(168, 162, 154),
		description = "Chalky mineral deposits coat an iridescent chambered spiral.",
	},
	OpalizedNautilusCrown = {
		id = "OpalizedNautilusCrown",
		name = "Opalized Nautilus Crown",
		category = "Fossil",
		rarity = "Epic",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 390,
		color = Color3.fromRGB(196, 146, 255),
		description = "Every chamber glimmers with rainbow sea opal once scrubbed clean!",
	},
	BasaltPillarFragment = {
		id = "BasaltPillarFragment",
		name = "Mossy Temple Idol",
		category = "Ruin",
		rarity = "Rare",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 12,
		revealedItemId = "CarvedTidePriestIdol",
		sellValue = 105,
		color = Color3.fromRGB(88, 112, 128),
		description = "An encrusted temple statue waiting to be restored at the Cleaning Station.",
	},
	CarvedTidePriestIdol = {
		id = "CarvedTidePriestIdol",
		name = "Carved Tide-Priestess Idol",
		category = "Ruin",
		rarity = "Epic",
		zones = { "SunkenRuins" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 425,
		color = Color3.fromRGB(132, 232, 255),
		description = "A serene jade-and-gold shrine figurine uncovered in gleaming condition.",
	},
	TarSealedPirateCoffer = {
		id = "TarSealedPirateCoffer",
		name = "Tar-Sealed Pirate Coffer",
		category = "Treasure",
		rarity = "Rare",
		zones = { "ShallowReef", "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 12,
		revealedItemId = "EmeraldCaptainSignet",
		sellValue = 110,
		color = Color3.fromRGB(92, 82, 78),
		description = "Black pitch seals this mini coffer shut. Scrub it at the Cleaning Station!",
	},
	EmeraldCaptainSignet = {
		id = "EmeraldCaptainSignet",
		name = "Emerald Admiral's Signet",
		category = "Treasure",
		rarity = "Rare",
		zones = { "ShallowReef", "SunkenRuins" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 310,
		color = Color3.fromRGB(82, 240, 148),
		description = "A heavy gold ring set with an uncut sea-emerald hidden inside the coffer.",
	},

	-- Epic
	AbyssalRubyChalice = {
		id = "AbyssalRubyChalice",
		name = "Abyssal Ruby Chalice",
		category = "Treasure",
		rarity = "Epic",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 440,
		color = Color3.fromRGB(255, 86, 134),
		description = "A crimson jewel cup glowing softly against the trench darkness.",
	},
	SaltCrustedMosasaurFang = {
		id = "SaltCrustedMosasaurFang",
		name = "Salt-Crusted Mosasaur Fang",
		category = "Fossil",
		rarity = "Epic",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 15,
		revealedItemId = "CrystalizedMosasaurFang",
		sellValue = 220,
		color = Color3.fromRGB(172, 168, 162),
		description = "A colossal prehistoric tooth locked inside dense abyssal salt crust.",
	},
	CrystalizedMosasaurFang = {
		id = "CrystalizedMosasaurFang",
		name = "Crystalized Mosasaur Fang",
		category = "Fossil",
		rarity = "Legendary",
		zones = { "AbyssalTrench" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 890,
		color = Color3.fromRGB(255, 212, 102),
		description = "Translucent amethyst quartz fused inside a giant marine predator's fang!",
	},
	SiltSealedStarAstrolabe = {
		id = "SiltSealedStarAstrolabe",
		name = "Mud-Caked Star Astrolabe",
		category = "Ruin",
		rarity = "Epic",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 16,
		revealedItemId = "AstralSunstoneAstrolabe",
		sellValue = 235,
		color = Color3.fromRGB(118, 106, 132),
		description = "Ancient celestial rings jammed with abyssal clay. Scrub to restore!",
	},
	AstralSunstoneAstrolabe = {
		id = "AstralSunstoneAstrolabe",
		name = "Astral Sunstone Astrolabe",
		category = "Ruin",
		rarity = "Epic",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 680,
		color = Color3.fromRGB(218, 132, 255),
		description = "Spinning celestial rings cast golden-violet starlight across the harbor.",
	},

	-- Legendary
	VoidCrustedLeviathanScale = {
		id = "VoidCrustedLeviathanScale",
		name = "Void-Crusted Leviathan Scale",
		category = "Fossil",
		rarity = "Legendary",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 20,
		revealedItemId = "PrismaticLeviathanScale",
		sellValue = 480,
		color = Color3.fromRGB(88, 72, 108),
		description = "Hardened volcanic sediment hides iridescent armor of an ancient leviathan.",
	},
	PrismaticLeviathanScale = {
		id = "PrismaticLeviathanScale",
		name = "Prismatic Leviathan Scale",
		category = "Fossil",
		rarity = "Legendary",
		zones = { "AbyssalTrench" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 1520,
		color = Color3.fromRGB(255, 198, 66),
		description = "A radiant dragon-scale fossil shimmering with golden bioluminescence.",
	},
	SunlessTempleScepter = {
		id = "SunlessTempleScepter",
		name = "Tarnished Abyss Scepter",
		category = "Ruin",
		rarity = "Legendary",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 22,
		revealedItemId = "SovereignTideScepter",
		sellValue = 520,
		color = Color3.fromRGB(106, 98, 122),
		description = "Encrusted in deep-sea minerals. Clean it on the surface to awaken its glow!",
	},
	SovereignTideScepter = {
		id = "SovereignTideScepter",
		name = "Sovereign Tide Scepter",
		category = "Ruin",
		rarity = "Godly",
		zones = { "AbyssalTrench" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 2500,
		color = Color3.fromRGB(255, 126, 224),
		description = "A mythic royal sea-staff pulsing with radiant pink-gold abyssal energy!",
	},

	-- Godly
	CrownOfTheAbyss = {
		id = "CrownOfTheAbyss",
		name = "Crown of the Abyss",
		category = "Treasure",
		rarity = "Godly",
		zones = { "AbyssalTrench" },
		findable = true,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 2750,
		color = Color3.fromRGB(255, 112, 214),
		description = "A pristine sunken diadem studded with glowing deep-trench star diamonds.",
	},
	ObsidianEggOfPoseidon = {
		id = "ObsidianEggOfPoseidon",
		name = "Obsidian-Crusted Relic Core",
		category = "Ruin",
		rarity = "Godly",
		zones = { "SunkenRuins", "AbyssalTrench" },
		findable = true,
		requiresCleaning = true,
		cleanDuration = 26,
		revealedItemId = "CelestialAbyssalHeart",
		sellValue = 1250,
		color = Color3.fromRGB(58, 42, 74),
		description = "Volcanic basalt locks away a mythic heart of the deep. Scrub to reveal!",
	},
	CelestialAbyssalHeart = {
		id = "CelestialAbyssalHeart",
		name = "Celestial Heart of the Trench",
		category = "Treasure",
		rarity = "Godly",
		zones = { "AbyssalTrench" },
		findable = false,
		requiresCleaning = false,
		cleanDuration = 0,
		revealedItemId = nil,
		sellValue = 4500,
		color = Color3.fromRGB(255, 146, 240),
		description = "The rarest ocean jewel known — a swirling prism crystal born at -300 studs!",
	},
} :: { [string]: RelicConfig }

GameConfig.PETS = {
	-- Common (4)
	Mina = {
		id = "Mina",
		name = "Mina",
		title = "Tidepool Diver",
		rarity = "Common",
		hairColor = Color3.fromRGB(148, 214, 255),
		outfitColor = Color3.fromRGB(246, 248, 255),
		accentColor = Color3.fromRGB(86, 178, 245),
		eyeColor = Color3.fromRGB(64, 152, 236),
		skinColor = Color3.fromRGB(255, 228, 212),
		hairStyle = "BobCut",
		accessoryType = "Ribbon",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 15,
			swimSpeedBonus = 2,
			excavationSpeedBonus = 0.05,
			cleaningSpeedBonus = 0.05,
			coinMultiplierBonus = 0.05,
		},
	},
	Kokoa = {
		id = "Kokoa",
		name = "Kokoa",
		title = "Sandy Beach Scout",
		rarity = "Common",
		hairColor = Color3.fromRGB(255, 194, 168),
		outfitColor = Color3.fromRGB(255, 236, 224),
		accentColor = Color3.fromRGB(255, 134, 128),
		eyeColor = Color3.fromRGB(214, 102, 92),
		skinColor = Color3.fromRGB(255, 225, 208),
		hairStyle = "TwinTails",
		accessoryType = "Ribbon",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 12,
			swimSpeedBonus = 2.5,
			excavationSpeedBonus = 0.06,
			cleaningSpeedBonus = 0.06,
			coinMultiplierBonus = 0.04,
		},
	},
	Sora = {
		id = "Sora",
		name = "Sora",
		title = "Seafoam Apprentice",
		rarity = "Common",
		hairColor = Color3.fromRGB(162, 244, 222),
		outfitColor = Color3.fromRGB(238, 255, 250),
		accentColor = Color3.fromRGB(74, 212, 184),
		eyeColor = Color3.fromRGB(54, 176, 156),
		skinColor = Color3.fromRGB(255, 230, 215),
		hairStyle = "SideTail",
		accessoryType = "None",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 18,
			swimSpeedBonus = 1.5,
			excavationSpeedBonus = 0.05,
			cleaningSpeedBonus = 0.07,
			coinMultiplierBonus = 0.05,
		},
	},
	Yuzu = {
		id = "Yuzu",
		name = "Yuzu",
		title = "Lemonade Swimmer",
		rarity = "Common",
		hairColor = Color3.fromRGB(255, 232, 148),
		outfitColor = Color3.fromRGB(255, 250, 228),
		accentColor = Color3.fromRGB(255, 198, 76),
		eyeColor = Color3.fromRGB(218, 154, 48),
		skinColor = Color3.fromRGB(255, 228, 212),
		hairStyle = "LongWave",
		accessoryType = "Ribbon",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 14,
			swimSpeedBonus = 2.0,
			excavationSpeedBonus = 0.07,
			cleaningSpeedBonus = 0.05,
			coinMultiplierBonus = 0.06,
		},
	},

	-- Uncommon (4)
	Haruka = {
		id = "Haruka",
		name = "Haruka",
		title = "Coral Reef Dancer",
		rarity = "Uncommon",
		hairColor = Color3.fromRGB(255, 166, 206),
		outfitColor = Color3.fromRGB(255, 234, 244),
		accentColor = Color3.fromRGB(246, 112, 172),
		eyeColor = Color3.fromRGB(224, 78, 142),
		skinColor = Color3.fromRGB(255, 230, 215),
		hairStyle = "TwinTails",
		accessoryType = "ShellCrown",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 28,
			swimSpeedBonus = 3.5,
			excavationSpeedBonus = 0.11,
			cleaningSpeedBonus = 0.12,
			coinMultiplierBonus = 0.10,
		},
	},
	Aoi = {
		id = "Aoi",
		name = "Aoi",
		title = "Lagoon Flutist",
		rarity = "Uncommon",
		hairColor = Color3.fromRGB(162, 182, 255),
		outfitColor = Color3.fromRGB(228, 238, 255),
		accentColor = Color3.fromRGB(98, 134, 246),
		eyeColor = Color3.fromRGB(72, 108, 228),
		skinColor = Color3.fromRGB(255, 229, 214),
		hairStyle = "LongWave",
		accessoryType = "Ribbon",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 32,
			swimSpeedBonus = 4.0,
			excavationSpeedBonus = 0.10,
			cleaningSpeedBonus = 0.10,
			coinMultiplierBonus = 0.12,
		},
	},
	Natsuki = {
		id = "Natsuki",
		name = "Natsuki",
		title = "Shell Collector",
		rarity = "Uncommon",
		hairColor = Color3.fromRGB(212, 176, 255),
		outfitColor = Color3.fromRGB(246, 238, 255),
		accentColor = Color3.fromRGB(168, 118, 244),
		eyeColor = Color3.fromRGB(142, 92, 224),
		skinColor = Color3.fromRGB(255, 227, 212),
		hairStyle = "BobCut",
		accessoryType = "ShellCrown",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 26,
			swimSpeedBonus = 3.5,
			excavationSpeedBonus = 0.14,
			cleaningSpeedBonus = 0.12,
			coinMultiplierBonus = 0.11,
		},
	},
	Rina = {
		id = "Rina",
		name = "Rina",
		title = "Current Rider",
		rarity = "Uncommon",
		hairColor = Color3.fromRGB(128, 232, 246),
		outfitColor = Color3.fromRGB(222, 248, 255),
		accentColor = Color3.fromRGB(54, 188, 228),
		eyeColor = Color3.fromRGB(36, 152, 204),
		skinColor = Color3.fromRGB(255, 228, 212),
		hairStyle = "SideTail",
		accessoryType = "ShellCrown",
		hasHalo = false,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 30,
			swimSpeedBonus = 4.5,
			excavationSpeedBonus = 0.12,
			cleaningSpeedBonus = 0.11,
			coinMultiplierBonus = 0.10,
		},
	},

	-- Rare (4)
	Shiori = {
		id = "Shiori",
		name = "Shiori",
		title = "Sunken Shrine Maiden",
		rarity = "Rare",
		hairColor = Color3.fromRGB(218, 186, 255),
		outfitColor = Color3.fromRGB(255, 246, 248),
		accentColor = Color3.fromRGB(238, 92, 126),
		eyeColor = Color3.fromRGB(178, 78, 224),
		skinColor = Color3.fromRGB(255, 230, 216),
		hairStyle = "LongWave",
		accessoryType = "Halo",
		hasHalo = true,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 48,
			swimSpeedBonus = 6.0,
			excavationSpeedBonus = 0.18,
			cleaningSpeedBonus = 0.22,
			coinMultiplierBonus = 0.18,
		},
	},
	Sakura = {
		id = "Sakura",
		name = "Sakura",
		title = "Blossom Siren",
		rarity = "Rare",
		hairColor = Color3.fromRGB(255, 178, 218),
		outfitColor = Color3.fromRGB(255, 236, 246),
		accentColor = Color3.fromRGB(255, 118, 178),
		eyeColor = Color3.fromRGB(242, 86, 154),
		skinColor = Color3.fromRGB(255, 231, 217),
		hairStyle = "TwinTails",
		accessoryType = "Halo",
		hasHalo = true,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 45,
			swimSpeedBonus = 6.5,
			excavationSpeedBonus = 0.20,
			cleaningSpeedBonus = 0.20,
			coinMultiplierBonus = 0.20,
		},
	},
	Fuyuka = {
		id = "Fuyuka",
		name = "Fuyuka",
		title = "Pearl Lantern Keeper",
		rarity = "Rare",
		hairColor = Color3.fromRGB(214, 238, 255),
		outfitColor = Color3.fromRGB(240, 248, 255),
		accentColor = Color3.fromRGB(112, 198, 255),
		eyeColor = Color3.fromRGB(82, 168, 244),
		skinColor = Color3.fromRGB(255, 232, 220),
		hairStyle = "RoyalBraid",
		accessoryType = "Halo",
		hasHalo = true,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 54,
			swimSpeedBonus = 5.5,
			excavationSpeedBonus = 0.19,
			cleaningSpeedBonus = 0.21,
			coinMultiplierBonus = 0.19,
		},
	},
	Kaede = {
		id = "Kaede",
		name = "Kaede",
		title = "Amber Ruin Scholar",
		rarity = "Rare",
		hairColor = Color3.fromRGB(255, 198, 152),
		outfitColor = Color3.fromRGB(234, 252, 242),
		accentColor = Color3.fromRGB(92, 214, 158),
		eyeColor = Color3.fromRGB(64, 178, 128),
		skinColor = Color3.fromRGB(255, 228, 214),
		hairStyle = "SideTail",
		accessoryType = "Halo",
		hasHalo = true,
		hasWings = false,
		hasAura = false,
		passives = {
			oxygenCapacityBonus = 46,
			swimSpeedBonus = 6.0,
			excavationSpeedBonus = 0.24,
			cleaningSpeedBonus = 0.24,
			coinMultiplierBonus = 0.17,
		},
	},

	-- Epic (3)
	Yume = {
		id = "Yume",
		name = "Yume",
		title = "Dreamtide Idol",
		rarity = "Epic",
		hairColor = Color3.fromRGB(238, 168, 255),
		outfitColor = Color3.fromRGB(250, 234, 255),
		accentColor = Color3.fromRGB(196, 98, 255),
		eyeColor = Color3.fromRGB(178, 72, 246),
		skinColor = Color3.fromRGB(255, 231, 218),
		hairStyle = "TwinTails",
		accessoryType = "AngelWings",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 78,
			swimSpeedBonus = 9.0,
			excavationSpeedBonus = 0.32,
			cleaningSpeedBonus = 0.34,
			coinMultiplierBonus = 0.32,
		},
	},
	Kaguya = {
		id = "Kaguya",
		name = "Kaguya",
		title = "Moonlit Kelp Princess",
		rarity = "Epic",
		hairColor = Color3.fromRGB(236, 242, 255),
		outfitColor = Color3.fromRGB(218, 246, 252),
		accentColor = Color3.fromRGB(92, 218, 238),
		eyeColor = Color3.fromRGB(120, 146, 255),
		skinColor = Color3.fromRGB(255, 233, 222),
		hairStyle = "LongWave",
		accessoryType = "AngelWings",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 86,
			swimSpeedBonus = 8.5,
			excavationSpeedBonus = 0.30,
			cleaningSpeedBonus = 0.36,
			coinMultiplierBonus = 0.34,
		},
	},
	Nyxie = {
		id = "Nyxie",
		name = "Nyxie",
		title = "Abyssal Neon Witch",
		rarity = "Epic",
		hairColor = Color3.fromRGB(192, 146, 255),
		outfitColor = Color3.fromRGB(48, 42, 76),
		accentColor = Color3.fromRGB(255, 108, 224),
		eyeColor = Color3.fromRGB(255, 92, 206),
		skinColor = Color3.fromRGB(255, 229, 218),
		hairStyle = "RoyalBraid",
		accessoryType = "AngelWings",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 80,
			swimSpeedBonus = 9.5,
			excavationSpeedBonus = 0.35,
			cleaningSpeedBonus = 0.32,
			coinMultiplierBonus = 0.35,
		},
	},

	-- Legendary (3)
	Hoshiko = {
		id = "Hoshiko",
		name = "Hoshiko",
		title = "Starlight Reef Guardian",
		rarity = "Legendary",
		hairColor = Color3.fromRGB(255, 232, 162),
		outfitColor = Color3.fromRGB(234, 244, 255),
		accentColor = Color3.fromRGB(255, 198, 66),
		eyeColor = Color3.fromRGB(82, 168, 255),
		skinColor = Color3.fromRGB(255, 232, 220),
		hairStyle = "TwinTails",
		accessoryType = "StarHaloAndWings",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 120,
			swimSpeedBonus = 13.0,
			excavationSpeedBonus = 0.48,
			cleaningSpeedBonus = 0.50,
			coinMultiplierBonus = 0.52,
		},
	},
	Seraphina = {
		id = "Seraphina",
		name = "Seraphina",
		title = "Pearl Angel of the Trench",
		rarity = "Legendary",
		hairColor = Color3.fromRGB(255, 206, 230),
		outfitColor = Color3.fromRGB(255, 250, 244),
		accentColor = Color3.fromRGB(255, 186, 98),
		eyeColor = Color3.fromRGB(244, 128, 178),
		skinColor = Color3.fromRGB(255, 233, 221),
		hairStyle = "LongWave",
		accessoryType = "StarHaloAndWings",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 128,
			swimSpeedBonus = 12.5,
			excavationSpeedBonus = 0.46,
			cleaningSpeedBonus = 0.54,
			coinMultiplierBonus = 0.50,
		},
	},
	Tsukuyomi = {
		id = "Tsukuyomi",
		name = "Tsukuyomi",
		title = "Tidal Eclipse Empress",
		rarity = "Legendary",
		hairColor = Color3.fromRGB(168, 228, 255),
		outfitColor = Color3.fromRGB(44, 52, 98),
		accentColor = Color3.fromRGB(255, 212, 96),
		eyeColor = Color3.fromRGB(255, 198, 72),
		skinColor = Color3.fromRGB(255, 231, 220),
		hairStyle = "RoyalBraid",
		accessoryType = "StarHaloAndWings",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 118,
			swimSpeedBonus = 14.0,
			excavationSpeedBonus = 0.52,
			cleaningSpeedBonus = 0.48,
			coinMultiplierBonus = 0.55,
		},
	},

	-- Godly (2)
	Celestia = {
		id = "Celestia",
		name = "Celestia",
		title = "Divine Ocean Goddess",
		rarity = "Godly",
		hairColor = Color3.fromRGB(255, 198, 244),
		outfitColor = Color3.fromRGB(255, 252, 255),
		accentColor = Color3.fromRGB(255, 118, 222),
		eyeColor = Color3.fromRGB(112, 218, 255),
		skinColor = Color3.fromRGB(255, 234, 224),
		hairStyle = "LongWave",
		accessoryType = "DivineAura",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 180,
			swimSpeedBonus = 18.0,
			excavationSpeedBonus = 0.72,
			cleaningSpeedBonus = 0.75,
			coinMultiplierBonus = 0.85,
		},
	},
	Astrid = {
		id = "Astrid",
		name = "Astrid",
		title = "Eternal Abyssal Sovereign",
		rarity = "Godly",
		hairColor = Color3.fromRGB(218, 206, 255),
		outfitColor = Color3.fromRGB(236, 246, 255),
		accentColor = Color3.fromRGB(142, 228, 255),
		eyeColor = Color3.fromRGB(255, 126, 224),
		skinColor = Color3.fromRGB(255, 234, 224),
		hairStyle = "TwinTails",
		accessoryType = "DivineAura",
		hasHalo = true,
		hasWings = true,
		hasAura = true,
		passives = {
			oxygenCapacityBonus = 190,
			swimSpeedBonus = 19.0,
			excavationSpeedBonus = 0.75,
			cleaningSpeedBonus = 0.70,
			coinMultiplierBonus = 0.90,
		},
	},
} :: { [string]: PetSpeciesConfig }

GameConfig.EGG_ORDER = {
	"CoralEgg",
	"SunkenShrineEgg",
	"AbyssalPearlEgg",
	"CelestialStarEgg",
} :: { EggId }

GameConfig.EGGS = {
	CoralEgg = {
		id = "CoralEgg",
		name = "Coral Egg",
		cost = 250,
		description = "Warm reef shell hatching playful coastal companions.",
		primaryColor = Color3.fromRGB(255, 152, 166),
		secondaryColor = Color3.fromRGB(122, 234, 222),
		pedestalIndex = 1,
		rarityWeights = {
			Common = 55,
			Uncommon = 30,
			Rare = 12,
			Epic = 3,
			Legendary = 0,
			Godly = 0,
		},
	},
	SunkenShrineEgg = {
		id = "SunkenShrineEgg",
		name = "Sunken Shrine Egg",
		cost = 1200,
		description = "Ancient temple relic infused with shrine maiden blessings.",
		primaryColor = Color3.fromRGB(98, 206, 255),
		secondaryColor = Color3.fromRGB(236, 246, 255),
		pedestalIndex = 2,
		rarityWeights = {
			Common = 0,
			Uncommon = 45,
			Rare = 33,
			Epic = 17,
			Legendary = 5,
			Godly = 0,
		},
	},
	AbyssalPearlEgg = {
		id = "AbyssalPearlEgg",
		name = "Abyssal Pearl Egg",
		cost = 5000,
		description = "Luminous deep-trench pearl glowing with mystic violet power.",
		primaryColor = Color3.fromRGB(186, 112, 255),
		secondaryColor = Color3.fromRGB(82, 212, 255),
		pedestalIndex = 3,
		rarityWeights = {
			Common = 0,
			Uncommon = 0,
			Rare = 42,
			Epic = 36,
			Legendary = 19,
			Godly = 3,
		},
	},
	CelestialStarEgg = {
		id = "CelestialStarEgg",
		name = "Celestial Star Egg",
		cost = 18000,
		description = "Radiant star-blessed egg housing Legendary & Godly companions!",
		primaryColor = Color3.fromRGB(255, 132, 226),
		secondaryColor = Color3.fromRGB(255, 222, 108),
		pedestalIndex = 4,
		rarityWeights = {
			Common = 0,
			Uncommon = 0,
			Rare = 0,
			Epic = 44,
			Legendary = 42,
			Godly = 14,
		},
	},
} :: { [EggId]: EggConfig }

GameConfig.OXYGEN_TIERS = {
	{ level = 1, name = "Starter Bamboo Tank", cost = 0, maxOxygen = 100 },
	{ level = 2, name = "Copper Diver Tank", cost = 140, maxOxygen = 145 },
	{ level = 3, name = "Reef Aluminum Cylinder", cost = 360, maxOxygen = 200 },
	{ level = 4, name = "Twin-Valve Steel Tank", cost = 850, maxOxygen = 270 },
	{ level = 5, name = "Atlantean Rebreather", cost = 2100, maxOxygen = 360 },
	{ level = 6, name = "Hydro-Core Compressor", cost = 4800, maxOxygen = 470 },
	{ level = 7, name = "Abyssal Titanium Rig", cost = 10500, maxOxygen = 600 },
	{ level = 8, name = "Celestial Infinity Lung", cost = 22000, maxOxygen = 780 },
} :: { OxygenTierConfig }

GameConfig.SWIM_SPEED_TIERS = {
	{ level = 1, name = "Barefoot Fins", cost = 0, swimSpeed = 22 },
	{ level = 2, name = "Rubber Reef Flippers", cost = 120, swimSpeed = 26 },
	{ level = 3, name = "Carbon Split Fins", cost = 320, swimSpeed = 31 },
	{ level = 4, name = "Hydro-Jet Anklets", cost = 780, swimSpeed = 36 },
	{ level = 5, name = "Atlantean Stream Blades", cost = 1900, swimSpeed = 42 },
	{ level = 6, name = "Turbo Vortex Thrusters", cost = 4400, swimSpeed = 49 },
	{ level = 7, name = "Abyssal Slipstream Fins", cost = 9800, swimSpeed = 57 },
	{ level = 8, name = "Starlight Surge Wings", cost = 20000, swimSpeed = 66 },
} :: { SwimSpeedTierConfig }

GameConfig.LIGHT_STRENGTH_TIERS = {
	{ level = 1, name = "Pocket Torch", cost = 0, brightness = 1.6, range = 40, angle = 44, color = Color3.fromRGB(255, 242, 206) },
	{ level = 2, name = "Halogen Diver Lamp", cost = 110, brightness = 2.4, range = 54, angle = 50, color = Color3.fromRGB(255, 246, 220) },
	{ level = 3, name = "Quartz Reef Beam", cost = 290, brightness = 3.3, range = 70, angle = 56, color = Color3.fromRGB(238, 250, 255) },
	{ level = 4, name = "Dual-Lens LED Rig", cost = 720, brightness = 4.4, range = 88, angle = 62, color = Color3.fromRGB(220, 248, 255) },
	{ level = 5, name = "Ruins Flare Beacon", cost = 1750, brightness = 5.6, range = 108, angle = 68, color = Color3.fromRGB(205, 244, 255) },
	{ level = 6, name = "Abyssal Arc Projector", cost = 4100, brightness = 7.0, range = 130, angle = 74, color = Color3.fromRGB(218, 236, 255) },
	{ level = 7, name = "Prism Trench Floodlight", cost = 9200, brightness = 8.6, range = 154, angle = 80, color = Color3.fromRGB(235, 240, 255) },
	{ level = 8, name = "Solar Starlight Halo-Beam", cost = 18500, brightness = 10.5, range = 180, angle = 88, color = Color3.fromRGB(255, 248, 240) },
} :: { LightStrengthTierConfig }

GameConfig.SHOP_ITEM_ORDER = {
	"OxygenCanister",
	"SpeedPotion",
	"TreasureLuckCharm",
	"AutoScrubberBoost",
} :: { ShopItemId }

GameConfig.SHOP_ITEMS = {
	OxygenCanister = {
		id = "OxygenCanister",
		name = "Oxygen Canister Refill",
		cost = 75,
		duration = 60,
		description = "Instantly refills O2 to 100% and cuts O2 drain by 35% for 60s.",
		accentColor = Color3.fromRGB(82, 224, 255),
	},
	SpeedPotion = {
		id = "SpeedPotion",
		name = "Current Speed Potion",
		cost = 180,
		duration = 180,
		description = "Grants +35% Swim Speed and +25% Excavation Speed for 3 minutes.",
		accentColor = Color3.fromRGB(112, 248, 178),
	},
	TreasureLuckCharm = {
		id = "TreasureLuckCharm",
		name = "Treasure Luck Charm",
		cost = 320,
		duration = 180,
		description = "Boosts rare-to-godly excavation drop odds by +45% for 3 minutes.",
		accentColor = Color3.fromRGB(255, 206, 86),
	},
	AutoScrubberBoost = {
		id = "AutoScrubberBoost",
		name = "Auto-Scrubber Boost",
		cost = 240,
		duration = 180,
		description = "Supercharges Cleaning Station washbasins with +150% scrub speed for 3m.",
		accentColor = Color3.fromRGB(234, 146, 255),
	},
} :: { [ShopItemId]: ShopItemConfig }

function GameConfig.GetDepthAtY(y: number): number
	if y >= GameConfig.WATER_SURFACE_Y then
		return 0
	end
	return GameConfig.WATER_SURFACE_Y - y
end

function GameConfig.GetZoneAtY(y: number): ZoneConfig?
	if y > GameConfig.WATER_SURFACE_Y then
		return nil
	end
	for _, zoneId in ipairs(GameConfig.ZONE_ORDER) do
		local zone = GameConfig.ZONES[zoneId]
		if y <= zone.maxY and y >= zone.minY then
			return zone
		end
	end
	return GameConfig.ZONES.AbyssalTrench
end

function GameConfig.GetMaxGearLevel(upgradeId: UpgradeId): number
	if upgradeId == "Oxygen" then
		return #GameConfig.OXYGEN_TIERS
	elseif upgradeId == "SwimSpeed" then
		return #GameConfig.SWIM_SPEED_TIERS
	elseif upgradeId == "LightStrength" then
		return #GameConfig.LIGHT_STRENGTH_TIERS
	end
	return 1
end

function GameConfig.GetOxygenTier(level: number): OxygenTierConfig
	local clamped = math.clamp(math.floor(level), 1, #GameConfig.OXYGEN_TIERS)
	return GameConfig.OXYGEN_TIERS[clamped]
end

function GameConfig.GetSwimSpeedTier(level: number): SwimSpeedTierConfig
	local clamped = math.clamp(math.floor(level), 1, #GameConfig.SWIM_SPEED_TIERS)
	return GameConfig.SWIM_SPEED_TIERS[clamped]
end

function GameConfig.GetLightStrengthTier(level: number): LightStrengthTierConfig
	local clamped = math.clamp(math.floor(level), 1, #GameConfig.LIGHT_STRENGTH_TIERS)
	return GameConfig.LIGHT_STRENGTH_TIERS[clamped]
end

function GameConfig.GetPetsByRarity(rarity: Rarity): { PetSpeciesConfig }
	local results: { PetSpeciesConfig } = {}
	for _, pet in pairs(GameConfig.PETS) do
		if pet.rarity == rarity then
			table.insert(results, pet)
		end
	end
	table.sort(results, function(a: PetSpeciesConfig, b: PetSpeciesConfig): boolean
		return a.id < b.id
	end)
	return results
end

function GameConfig.CalculatePetPassives(equippedSpeciesIds: { string }): PetPassives
	local totals: PetPassives = {
		oxygenCapacityBonus = 0,
		swimSpeedBonus = 0,
		excavationSpeedBonus = 0,
		cleaningSpeedBonus = 0,
		coinMultiplierBonus = 0,
	}

	for _, speciesId in ipairs(equippedSpeciesIds) do
		local pet = GameConfig.PETS[speciesId]
		if pet then
			totals.oxygenCapacityBonus += pet.passives.oxygenCapacityBonus
			totals.swimSpeedBonus += pet.passives.swimSpeedBonus
			totals.excavationSpeedBonus += pet.passives.excavationSpeedBonus
			totals.cleaningSpeedBonus += pet.passives.cleaningSpeedBonus
			totals.coinMultiplierBonus += pet.passives.coinMultiplierBonus
		end
	end

	return totals
end

function GameConfig.FormatNumber(value: number): string
	local rounded = math.floor(value + 0.5)
	local formatted = tostring(rounded)
	while true do
		local nextStr, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = nextStr
		if count == 0 then
			break
		end
	end
	return formatted
end

return GameConfig
