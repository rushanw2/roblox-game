--!strict

export type StationSlot = "Prep" | "Stove" | "Server" | "Cashier"
export type StaffRarity = "Common" | "Rare" | "Epic" | "Mythic"

export type IngredientConfig = {
	id: string,
	name: string,
	boxCost: number,
	bundleAmount: number,
	color: Color3,
	description: string,
}

export type RecipeConfig = {
	id: string,
	name: string,
	ingredients: { [string]: number },
	prepTime: number,
	cookTime: number,
	payoutYen: number,
	color: Color3,
}

export type StaffArchetype = {
	id: string,
	name: string,
	title: string,
	rarity: StaffRarity,
	rollWeight: number,
	workSpeedMultiplier: number,
	hairColor: Color3,
	outfitColor: Color3,
	accentColor: Color3,
	favoriteStation: StationSlot,
}

export type CustomerArchetype = {
	id: string,
	name: string,
	walkSpeed: number,
	hairColor: Color3,
	outfitColor: Color3,
	accentColor: Color3,
	tipBonus: number,
}

export type RarityStyle = {
	displayName: string,
	color: Color3,
}

local GameConfig = {}

GameConfig.STARTING_YEN = 250
GameConfig.GACHA_ROLL_COST = 100
GameConfig.MAX_RESTOCK_BOXES_PER_REQUEST = 50
GameConfig.MAX_PLOT_COUNT = 4

GameConfig.StationSlots = {
	"Prep",
	"Stove",
	"Server",
	"Cashier",
} :: { StationSlot }

GameConfig.StationSlotSet = {
	Prep = true,
	Stove = true,
	Server = true,
	Cashier = true,
} :: { [string]: boolean }

GameConfig.RarityStyles = {
	Common = {
		displayName = "Common",
		color = Color3.fromRGB(168, 198, 224),
	},
	Rare = {
		displayName = "Rare",
		color = Color3.fromRGB(122, 206, 255),
	},
	Epic = {
		displayName = "Epic",
		color = Color3.fromRGB(205, 138, 255),
	},
	Mythic = {
		displayName = "Mythic",
		color = Color3.fromRGB(255, 184, 108),
	},
} :: { [StaffRarity]: RarityStyle }

GameConfig.Ingredients = {
	Rice = {
		id = "Rice",
		name = "Fluffy Koshihikari Rice",
		boxCost = 30,
		bundleAmount = 6,
		color = Color3.fromRGB(250, 246, 236),
		description = "Fresh steamed rice base for onigiri and curry bowls.",
	},
	Noodles = {
		id = "Noodles",
		name = "Artisan Ramen Noodles",
		boxCost = 40,
		bundleAmount = 5,
		color = Color3.fromRGB(255, 225, 148),
		description = "Springy hand-pulled wheat noodles.",
	},
	Matcha = {
		id = "Matcha",
		name = "Uji Matcha Powder",
		boxCost = 50,
		bundleAmount = 5,
		color = Color3.fromRGB(134, 212, 136),
		description = "Ceremonial-grade Kyoto green tea for parfaits.",
	},
	Wagyu = {
		id = "Wagyu",
		name = "A5 Wagyu Cutlet",
		boxCost = 90,
		bundleAmount = 4,
		color = Color3.fromRGB(242, 145, 152),
		description = "Premium marbled beef for ramen and katsu curry.",
	},
	SakuraMochi = {
		id = "SakuraMochi",
		name = "Sakura Mochi Sweets",
		boxCost = 45,
		bundleAmount = 5,
		color = Color3.fromRGB(255, 188, 214),
		description = "Blossom-wrapped sweet rice cakes.",
	},
	CurrySauce = {
		id = "CurrySauce",
		name = "Golden Café Curry Roux",
		boxCost = 45,
		bundleAmount = 5,
		color = Color3.fromRGB(224, 158, 76),
		description = "Rich savory-sweet Japanese curry blend.",
	},
} :: { [string]: IngredientConfig }

GameConfig.Recipes = {
	Onigiri = {
		id = "Onigiri",
		name = "Kawaii Onigiri Trio",
		ingredients = {
			Rice = 1,
		},
		prepTime = 2.5,
		cookTime = 1.5,
		payoutYen = 25,
		color = Color3.fromRGB(245, 245, 240),
	},
	SakuraMochiPlate = {
		id = "SakuraMochiPlate",
		name = "Sakura Mochi Plate",
		ingredients = {
			SakuraMochi = 1,
		},
		prepTime = 2.0,
		cookTime = 1.0,
		payoutYen = 35,
		color = Color3.fromRGB(255, 196, 220),
	},
	MatchaParfait = {
		id = "MatchaParfait",
		name = "Matcha Berry Parfait",
		ingredients = {
			Matcha = 1,
			SakuraMochi = 1,
		},
		prepTime = 3.5,
		cookTime = 1.0,
		payoutYen = 60,
		color = Color3.fromRGB(160, 226, 156),
	},
	RamenBowl = {
		id = "RamenBowl",
		name = "Shoyu Wagyu Ramen",
		ingredients = {
			Noodles = 1,
			Wagyu = 1,
		},
		prepTime = 3.0,
		cookTime = 4.0,
		payoutYen = 75,
		color = Color3.fromRGB(255, 210, 130),
	},
	KatsuCurry = {
		id = "KatsuCurry",
		name = "Wagyu Katsu Curry",
		ingredients = {
			Rice = 1,
			CurrySauce = 1,
			Wagyu = 1,
		},
		prepTime = 3.5,
		cookTime = 4.5,
		payoutYen = 95,
		color = Color3.fromRGB(235, 170, 88),
	},
} :: { [string]: RecipeConfig }

GameConfig.StaffCatalog = {
	{
		id = "CozyMaid",
		name = "Cozy Maid",
		title = "Sweet Ribbon Server",
		rarity = "Common",
		rollWeight = 25,
		workSpeedMultiplier = 1.20,
		hairColor = Color3.fromRGB(210, 188, 255),
		outfitColor = Color3.fromRGB(255, 245, 250),
		accentColor = Color3.fromRGB(255, 168, 205),
		favoriteStation = "Server",
	},
	{
		id = "BentoApprentice",
		name = "Bento Apprentice",
		title = "Hearty Prep Trainee",
		rarity = "Common",
		rollWeight = 25,
		workSpeedMultiplier = 1.25,
		hairColor = Color3.fromRGB(255, 204, 178),
		outfitColor = Color3.fromRGB(188, 242, 220),
		accentColor = Color3.fromRGB(255, 248, 225),
		favoriteStation = "Prep",
	},
	{
		id = "CatgirlBarista",
		name = "Catgirl Barista",
		title = "Neko Latte Crafter",
		rarity = "Common",
		rollWeight = 22,
		workSpeedMultiplier = 1.30,
		hairColor = Color3.fromRGB(246, 188, 164),
		outfitColor = Color3.fromRGB(242, 224, 200),
		accentColor = Color3.fromRGB(255, 164, 186),
		favoriteStation = "Cashier",
	},
	{
		id = "ShrineMaiden",
		name = "Shrine Maiden",
		title = "Sakura Miko Keeper",
		rarity = "Rare",
		rollWeight = 14,
		workSpeedMultiplier = 1.55,
		hairColor = Color3.fromRGB(110, 108, 152),
		outfitColor = Color3.fromRGB(255, 250, 250),
		accentColor = Color3.fromRGB(255, 118, 138),
		favoriteStation = "Cashier",
	},
	{
		id = "PatissiereSenpai",
		name = "Patissiere Senpai",
		title = "Whipped Cream Virtuoso",
		rarity = "Rare",
		rollWeight = 13,
		workSpeedMultiplier = 1.65,
		hairColor = Color3.fromRGB(255, 198, 216),
		outfitColor = Color3.fromRGB(255, 232, 240),
		accentColor = Color3.fromRGB(255, 224, 146),
		favoriteStation = "Prep",
	},
	{
		id = "NeonWaitress",
		name = "Neon Arcade Waitress",
		title = "Pop Roller Dasher",
		rarity = "Rare",
		rollWeight = 12,
		workSpeedMultiplier = 1.75,
		hairColor = Color3.fromRGB(145, 232, 255),
		outfitColor = Color3.fromRGB(218, 248, 255),
		accentColor = Color3.fromRGB(255, 145, 214),
		favoriteStation = "Server",
	},
	{
		id = "MagicalIdol",
		name = "Magical Idol",
		title = "Starlight Stage Star",
		rarity = "Epic",
		rollWeight = 6,
		workSpeedMultiplier = 2.25,
		hairColor = Color3.fromRGB(255, 168, 222),
		outfitColor = Color3.fromRGB(232, 202, 255),
		accentColor = Color3.fromRGB(255, 238, 142),
		favoriteStation = "Server",
	},
	{
		id = "FoxSpiritChef",
		name = "Fox Spirit Chef",
		title = "Kitsune Flame Master",
		rarity = "Epic",
		rollWeight = 5,
		workSpeedMultiplier = 2.50,
		hairColor = Color3.fromRGB(246, 244, 255),
		outfitColor = Color3.fromRGB(255, 148, 148),
		accentColor = Color3.fromRGB(255, 216, 128),
		favoriteStation = "Stove",
	},
	{
		id = "SakuraValkyrie",
		name = "Sakura Blossom Diva",
		title = "Petal Breeze Prodigy",
		rarity = "Mythic",
		rollWeight = 1.5,
		workSpeedMultiplier = 3.15,
		hairColor = Color3.fromRGB(255, 178, 208),
		outfitColor = Color3.fromRGB(255, 242, 248),
		accentColor = Color3.fromRGB(255, 206, 138),
		favoriteStation = "Prep",
	},
	{
		id = "CelestialEmpress",
		name = "Celestial Empress",
		title = "Astral Banquet Sovereign",
		rarity = "Mythic",
		rollWeight = 0.8,
		workSpeedMultiplier = 3.50,
		hairColor = Color3.fromRGB(186, 208, 255),
		outfitColor = Color3.fromRGB(252, 248, 255),
		accentColor = Color3.fromRGB(255, 214, 118),
		favoriteStation = "Stove",
	},
} :: { StaffArchetype }

GameConfig.StaffById = {} :: { [string]: StaffArchetype }
for _, archetype in GameConfig.StaffCatalog do
	GameConfig.StaffById[archetype.id] = archetype
end

GameConfig.CustomerArchetypes = {
	{
		id = "Schoolgirl",
		name = "After-School Regular",
		walkSpeed = 13,
		hairColor = Color3.fromRGB(128, 108, 104),
		outfitColor = Color3.fromRGB(238, 242, 255),
		accentColor = Color3.fromRGB(255, 152, 176),
		tipBonus = 0,
	},
	{
		id = "CozyGamer",
		name = "Cozy Hoodie Gamer",
		walkSpeed = 11.5,
		hairColor = Color3.fromRGB(172, 214, 255),
		outfitColor = Color3.fromRGB(205, 192, 255),
		accentColor = Color3.fromRGB(178, 255, 224),
		tipBonus = 5,
	},
	{
		id = "SakuraTourist",
		name = "Sakura Sightseer",
		walkSpeed = 12.5,
		hairColor = Color3.fromRGB(255, 198, 218),
		outfitColor = Color3.fromRGB(255, 244, 222),
		accentColor = Color3.fromRGB(255, 158, 192),
		tipBonus = 8,
	},
	{
		id = "IdolFan",
		name = "Superstar Idol Fan",
		walkSpeed = 15,
		hairColor = Color3.fromRGB(255, 232, 168),
		outfitColor = Color3.fromRGB(255, 196, 230),
		accentColor = Color3.fromRGB(168, 234, 255),
		tipBonus = 10,
	},
	{
		id = "KawaiiStreamer",
		name = "Pastel Food Vlogger",
		walkSpeed = 14,
		hairColor = Color3.fromRGB(184, 245, 220),
		outfitColor = Color3.fromRGB(255, 234, 246),
		accentColor = Color3.fromRGB(255, 208, 146),
		tipBonus = 12,
	},
	{
		id = "GourmetSenpai",
		name = "Gourmet Critic Senpai",
		walkSpeed = 12,
		hairColor = Color3.fromRGB(198, 184, 226),
		outfitColor = Color3.fromRGB(246, 242, 238),
		accentColor = Color3.fromRGB(255, 194, 112),
		tipBonus = 18,
	},
} :: { CustomerArchetype }

function GameConfig.GetTotalStaffWeight(): number
	local total = 0
	for _, archetype in GameConfig.StaffCatalog do
		total += archetype.rollWeight
	end
	return total
end

function GameConfig.RollStaffArchetype(rng: Random): StaffArchetype
	local totalWeight = GameConfig.GetTotalStaffWeight()
	local roll = rng:NextNumber(0, totalWeight)
	local cumulative = 0

	for _, archetype in GameConfig.StaffCatalog do
		cumulative += archetype.rollWeight
		if roll <= cumulative then
			return archetype
		end
	end

	return GameConfig.StaffCatalog[#GameConfig.StaffCatalog]
end

return GameConfig
