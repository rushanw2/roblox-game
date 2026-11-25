--!strict
-- Shared stylized luggage model builder used by WorldBuilder (world bags & workbenches) and client carried-prop visuals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

export type LuggageBuildOptions = {
	scale: number?,
	anchored: boolean?,
	withHingedLid: boolean?,
	withRarityGlow: boolean?,
}

local LuggageVisuals = {}

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	anchored: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = anchored
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function getDimensionsForStyle(style: GameConfig.BagStyle): Vector3
	if style == "Duffle" then
		return Vector3.new(3.0, 1.8, 1.8)
	elseif style == "Trunk" then
		return Vector3.new(3.4, 2.0, 2.2)
	elseif style == "Briefcase" then
		return Vector3.new(2.6, 1.9, 0.9)
	elseif style == "VaultCase" then
		return Vector3.new(2.9, 2.3, 1.55)
	else
		-- Hardcase
		return Vector3.new(2.4, 2.9, 1.4)
	end
end

function LuggageVisuals.BuildModel(archetype: GameConfig.ArchetypeDef, origin: CFrame, options: LuggageBuildOptions?): Model
	local opts = options or {}
	local scale = opts.scale or 1
	local anchored = if opts.anchored ~= nil then opts.anchored else true
	local withLid = opts.withHingedLid == true
	local withRarityGlow = opts.withRarityGlow == true

	local dims = getDimensionsForStyle(archetype.bagStyle) * scale
	local w, h, d = dims.X, dims.Y, dims.Z
	local wheelHeight = if archetype.bagStyle == "Hardcase" or archetype.bagStyle == "Trunk" then 0.28 * scale else 0

	local model = Instance.new("Model")
	model.Name = "Luggage_" .. archetype.id

	local bodyHeight = if withLid then h * 0.68 else h
	local bodyCenterOffset = Vector3.new(0, wheelHeight + bodyHeight * 0.5, 0)
	local bodyCF = origin * CFrame.new(bodyCenterOffset)

	local shellMaterial = if archetype.bagStyle == "Duffle"
		then Enum.Material.Fabric
		elseif archetype.bagStyle == "VaultCase" then Enum.Material.Metal
		else Enum.Material.SmoothPlastic

	local body = createPart(model, "Body", Vector3.new(w, bodyHeight, d), bodyCF, archetype.primaryColor, shellMaterial, anchored)
	model.PrimaryPart = body

	-- Center matching stripe
	createPart(
		model,
		"Stripe",
		Vector3.new(w * 0.24, bodyHeight + 0.04 * scale, d + 0.05 * scale),
		bodyCF,
		archetype.secondaryColor,
		Enum.Material.SmoothPlastic,
		anchored
	)

	-- Trim frame / straps
	local trimMaterial = if GameConfig.TIER_RANK[archetype.tier] >= 4 then Enum.Material.Metal else Enum.Material.SmoothPlastic
	createPart(
		model,
		"TrimBandLeft",
		Vector3.new(0.14 * scale, bodyHeight + 0.06 * scale, d + 0.08 * scale),
		bodyCF * CFrame.new(-w * 0.34, 0, 0),
		archetype.trimColor,
		trimMaterial,
		anchored
	)
	createPart(
		model,
		"TrimBandRight",
		Vector3.new(0.14 * scale, bodyHeight + 0.06 * scale, d + 0.08 * scale),
		bodyCF * CFrame.new(w * 0.34, 0, 0),
		archetype.trimColor,
		trimMaterial,
		anchored
	)

	-- Optional hinged lid for workbench showcase
	if withLid then
		local lidHeight = h * 0.32
		local lidModel = Instance.new("Model")
		lidModel.Name = "LidGroup"
		lidModel.Parent = model

		local hingeCF = origin * CFrame.new(0, wheelHeight + bodyHeight, -d * 0.5)
		local hinge = createPart(lidModel, "LidHinge", Vector3.new(0.2 * scale, 0.2 * scale, 0.2 * scale), hingeCF, archetype.trimColor, Enum.Material.Metal, anchored)
		hinge.Transparency = 1
		lidModel.PrimaryPart = hinge

		local lidCF = origin * CFrame.new(0, wheelHeight + bodyHeight + lidHeight * 0.5, 0)
		createPart(lidModel, "LidShell", Vector3.new(w, lidHeight, d), lidCF, archetype.primaryColor, shellMaterial, anchored)
		createPart(
			lidModel,
			"LidStripe",
			Vector3.new(w * 0.24, lidHeight + 0.04 * scale, d + 0.05 * scale),
			lidCF,
			archetype.secondaryColor,
			Enum.Material.SmoothPlastic,
			anchored
		)
	end

	-- Top grip / telescoping handle
	local topY = wheelHeight + h
	createPart(
		model,
		"TopHandle",
		Vector3.new(w * 0.42, 0.16 * scale, 0.24 * scale),
		origin * CFrame.new(0, topY + 0.22 * scale, 0),
		archetype.trimColor,
		Enum.Material.Metal,
		anchored
	)
	createPart(
		model,
		"HandlePostL",
		Vector3.new(0.12 * scale, 0.32 * scale, 0.14 * scale),
		origin * CFrame.new(-w * 0.16, topY + 0.08 * scale, 0),
		archetype.trimColor,
		Enum.Material.Metal,
		anchored
	)
	createPart(
		model,
		"HandlePostR",
		Vector3.new(0.12 * scale, 0.32 * scale, 0.14 * scale),
		origin * CFrame.new(w * 0.16, topY + 0.08 * scale, 0),
		archetype.trimColor,
		Enum.Material.Metal,
		anchored
	)

	-- Oversized matching luggage tag (key visual clue matching NPC hat/scarf/glasses!)
	local tagOffset = CFrame.new(w * 0.36, topY - 0.15 * scale, d * 0.5 + 0.12 * scale) * CFrame.Angles(0, 0, math.rad(-14))
	local tagMat = if GameConfig.TIER_RANK[archetype.tier] >= 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	createPart(
		model,
		"LuggageTag",
		Vector3.new(0.46 * scale, 0.68 * scale, 0.1 * scale),
		origin * tagOffset,
		archetype.tagColor,
		tagMat,
		anchored
	)

	-- Caster wheels if wheeled case
	if wheelHeight > 0 then
		for _, xSign in ipairs({ -1, 1 }) do
			for _, zSign in ipairs({ -1, 1 }) do
				createPart(
					model,
					"Wheel",
					Vector3.new(0.24 * scale, wheelHeight, 0.24 * scale),
					origin * CFrame.new(xSign * (w * 0.38), wheelHeight * 0.5, zSign * (d * 0.34)),
					Color3.fromRGB(32, 34, 38),
					Enum.Material.SmoothPlastic,
					anchored
				)
			end
		end
	end

	-- Luxury neon accent strips for Epic+ bags
	if GameConfig.TIER_RANK[archetype.tier] >= 4 then
		createPart(
			model,
			"LuxuryGlowEdge",
			Vector3.new(w + 0.06 * scale, 0.1 * scale, d + 0.06 * scale),
			origin * CFrame.new(0, wheelHeight + h * 0.85, 0),
			archetype.secondaryColor,
			Enum.Material.Neon,
			anchored
		)
	end

	if withRarityGlow then
		local tierColor = GameConfig.TIER_COLORS[archetype.tier]
		local hl = Instance.new("Highlight")
		hl.Name = "RarityOutline"
		hl.FillTransparency = 0.92
		hl.OutlineColor = tierColor
		hl.OutlineTransparency = 0.35
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
	end

	return model
end

return LuggageVisuals
