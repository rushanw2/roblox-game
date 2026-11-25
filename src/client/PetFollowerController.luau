--!strict
-- Spawns and smoothly animates equipped chibi-anime girl companions behind every player on land and underwater

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

type CompanionRig = {
	speciesId: string,
	model: Model,
	rootPart: Part,
	leftWing: Part?,
	rightWing: Part?,
	haloPart: Part?,
	leftArm: Part?,
	rightArm: Part?,
	currentCFrame: CFrame,
	slotIndex: number,
}

local PetFollowerController = {}

local SLOT_OFFSETS: { Vector3 } = {
	Vector3.new(-2.8, 1.9, 2.9),
	Vector3.new(2.8, 1.9, 2.9),
	Vector3.new(-4.3, 3.1, 4.4),
	Vector3.new(4.3, 3.1, 4.4),
}

local companionFolder: Folder
local rigsByUserId: { [number]: { CompanionRig } } = {}

local function makePart(props: {
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	shape: Enum.PartType?,
	parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.name
	part.Size = props.size
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = props.parent
	return part
end

local function attachWeldedPart(root: Part, relCFrame: CFrame, part: Part): Part
	part.Anchored = false
	part.CFrame = root.CFrame * relCFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addSphereMesh(part: Part, scale: Vector3?): ()
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	if scale then
		mesh.Scale = scale
	end
	mesh.Parent = part
end

local function buildHairStyle(root: Part, model: Model, species: GameConfig.PetSpeciesConfig): ()
	local hairColor = species.hairColor
	local accent = species.accentColor

	-- Rounded hair crown cap
	local crown = attachWeldedPart(root, CFrame.new(0, 1.04, 0.08), makePart({
		name = "HairCrown",
		size = Vector3.new(1.36, 1.18, 1.32),
		color = hairColor,
		parent = model,
	}))
	addSphereMesh(crown, Vector3.new(1, 1, 1))

	-- Cute anime front bangs & cheek framing side locks
	attachWeldedPart(root, CFrame.new(0, 1.18, -0.58) * CFrame.Angles(0.18, 0, 0), makePart({
		name = "FrontBangs",
		size = Vector3.new(1.12, 0.42, 0.28),
		color = hairColor,
		parent = model,
	}))
	for _, side in ipairs({ -1, 1 }) do
		attachWeldedPart(root, CFrame.new(side * 0.54, 0.78, -0.32) * CFrame.Angles(0, 0, side * -0.14), makePart({
			name = "SideLock",
			size = Vector3.new(0.24, 0.72, 0.34),
			color = hairColor,
			parent = model,
		}))
	end

	if species.hairStyle == "TwinTails" then
		for _, side in ipairs({ -1, 1 }) do
			attachWeldedPart(root, CFrame.new(side * 0.72, 1.05, 0.14), makePart({
				name = "HairTie",
				size = Vector3.new(0.24, 0.24, 0.24),
				color = accent,
				shape = Enum.PartType.Ball,
				parent = model,
			}))
			local tail = attachWeldedPart(root, CFrame.new(side * 0.96, 0.35, 0.34) * CFrame.Angles(0.22, 0, side * 0.35), makePart({
				name = "TwinTail",
				size = Vector3.new(0.46, 1.48, 0.46),
				color = hairColor,
				parent = model,
			}))
			addSphereMesh(tail, Vector3.new(1, 1, 1))
		end
	elseif species.hairStyle == "LongWave" then
		local back = attachWeldedPart(root, CFrame.new(0, 0.12, 0.56) * CFrame.Angles(0.18, 0, 0), makePart({
			name = "LongHair",
			size = Vector3.new(1.26, 1.75, 0.52),
			color = hairColor,
			parent = model,
		}))
		addSphereMesh(back, Vector3.new(1, 1, 1))
	elseif species.hairStyle == "SideTail" then
		attachWeldedPart(root, CFrame.new(0.68, 1.02, 0.25), makePart({
			name = "SideBow",
			size = Vector3.new(0.32, 0.26, 0.24),
			color = accent,
			parent = model,
		}))
		local tail = attachWeldedPart(root, CFrame.new(0.88, 0.32, 0.38) * CFrame.Angles(0.25, 0, 0.34), makePart({
			name = "SidePonytail",
			size = Vector3.new(0.48, 1.38, 0.48),
			color = hairColor,
			parent = model,
		}))
		addSphereMesh(tail, Vector3.new(1, 1, 1))
	elseif species.hairStyle == "RoyalBraid" then
		for seg = 1, 4 do
			local scale = 0.54 - seg * 0.08
			local bead = attachWeldedPart(root, CFrame.new(0, 0.72 - seg * 0.32, 0.58 + seg * 0.06), makePart({
				name = "BraidSeg_" .. tostring(seg),
				size = Vector3.new(scale, scale * 1.15, scale),
				color = if seg % 2 == 0 then accent else hairColor,
				shape = Enum.PartType.Ball,
				parent = model,
			}))
			bead:SetAttribute("Braid", true)
		end
	else
		-- BobCut
		local bob = attachWeldedPart(root, CFrame.new(0, 0.65, 0.38), makePart({
			name = "BobHair",
			size = Vector3.new(1.32, 0.76, 0.68),
			color = hairColor,
			parent = model,
		}))
		addSphereMesh(bob, Vector3.new(1, 1, 1))
	end
end

local function buildChibiCompanionRig(species: GameConfig.PetSpeciesConfig, spawnCFrame: CFrame, slotIndex: number): CompanionRig
	local rarityMeta = GameConfig.RARITY_META[species.rarity]

	local model = Instance.new("Model")
	model.Name = "Companion_" .. species.id .. "_" .. tostring(slotIndex)
	model.Parent = companionFolder

	-- Root anchor part (invisible torso center)
	local root = makePart({
		name = "CompanionRoot",
		size = Vector3.new(0.8, 0.85, 0.56),
		color = species.outfitColor,
		parent = model,
	})
	root.CFrame = spawnCFrame
	model.PrimaryPart = root

	-- Flared Chibi Dress Skirt
	local skirt = attachWeldedPart(root, CFrame.new(0, -0.34, 0), makePart({
		name = "Skirt",
		size = Vector3.new(1.18, 0.66, 1.18),
		color = species.outfitColor,
		parent = model,
	}))
	addSphereMesh(skirt, Vector3.new(1, 0.95, 1))

	attachWeldedPart(root, CFrame.new(0, -0.52, 0), makePart({
		name = "SkirtTrim",
		size = Vector3.new(1.22, 0.14, 1.22),
		color = species.accentColor,
		parent = model,
	}))

	-- Sailor / Shrine Ribbon Bow on Chest
	attachWeldedPart(root, CFrame.new(0, 0.22, -0.32), makePart({
		name = "ChestBow",
		size = Vector3.new(0.42, 0.22, 0.14),
		color = species.accentColor,
		parent = model,
	}))

	-- Chibi Head
	local head = attachWeldedPart(root, CFrame.new(0, 0.94, 0), makePart({
		name = "Head",
		size = Vector3.new(1.24, 1.12, 1.14),
		color = species.skinColor,
		parent = model,
	}))
	addSphereMesh(head, Vector3.new(1, 1, 1))

	-- Expressive Anime Eyes (Sclera, Iris, Pupil, Starlight Shine, Blush)
	for _, side in ipairs({ -1, 1 }) do
		attachWeldedPart(root, CFrame.new(side * 0.26, 0.92, -0.53), makePart({
			name = "EyeWhite",
			size = Vector3.new(0.24, 0.30, 0.08),
			color = Color3.fromRGB(255, 255, 255),
			parent = model,
		}))
		attachWeldedPart(root, CFrame.new(side * 0.25, 0.90, -0.55), makePart({
			name = "EyeIris",
			size = Vector3.new(0.18, 0.24, 0.08),
			color = species.eyeColor,
			parent = model,
		}))
		attachWeldedPart(root, CFrame.new(side * 0.25, 0.89, -0.565), makePart({
			name = "EyePupil",
			size = Vector3.new(0.10, 0.13, 0.08),
			color = Color3.fromRGB(22, 24, 38),
			parent = model,
		}))
		attachWeldedPart(root, CFrame.new(side * 0.29, 0.97, -0.58), makePart({
			name = "EyeShine",
			size = Vector3.new(0.07, 0.07, 0.06),
			color = Color3.fromRGB(255, 255, 255),
			material = Enum.Material.Neon,
			parent = model,
		}))
		attachWeldedPart(root, CFrame.new(side * 0.36, 0.74, -0.51), makePart({
			name = "CheekBlush",
			size = Vector3.new(0.18, 0.09, 0.06),
			color = Color3.fromRGB(255, 164, 186),
			transparency = 0.2,
			parent = model,
		}))
	end

	-- Hair
	buildHairStyle(root, model, species)

	-- Cute Chibi Arms & Legs
	local leftArm = attachWeldedPart(root, CFrame.new(-0.56, 0.06, 0) * CFrame.Angles(0, 0, 0.38), makePart({
		name = "LeftArm",
		size = Vector3.new(0.24, 0.62, 0.24),
		color = species.skinColor,
		parent = model,
	}))
	local rightArm = attachWeldedPart(root, CFrame.new(0.56, 0.06, 0) * CFrame.Angles(0, 0, -0.38), makePart({
		name = "RightArm",
		size = Vector3.new(0.24, 0.62, 0.24),
		color = species.skinColor,
		parent = model,
	}))

	for _, side in ipairs({ -0.20, 0.20 }) do
		attachWeldedPart(root, CFrame.new(side, -0.78, 0), makePart({
			name = "Leg",
			size = Vector3.new(0.24, 0.48, 0.24),
			color = species.skinColor,
			parent = model,
		}))
		attachWeldedPart(root, CFrame.new(side, -1.02, -0.05), makePart({
			name = "Shoe",
			size = Vector3.new(0.27, 0.18, 0.34),
			color = species.accentColor,
			parent = model,
		}))
	end

	-- Optional Head Accessories (Ribbon / ShellCrown)
	if species.accessoryType == "Ribbon" then
		attachWeldedPart(root, CFrame.new(-0.36, 1.52, -0.15) * CFrame.Angles(0, 0, 0.3), makePart({
			name = "HeadRibbon",
			size = Vector3.new(0.46, 0.26, 0.22),
			color = species.accentColor,
			parent = model,
		}))
	elseif species.accessoryType == "ShellCrown" then
		attachWeldedPart(root, CFrame.new(0, 1.56, -0.22), makePart({
			name = "ShellCrown",
			size = Vector3.new(0.52, 0.32, 0.24),
			color = Color3.fromRGB(255, 240, 210),
			material = Enum.Material.Neon,
			parent = model,
		}))
	end

	-- Higher Rarity Halo
	local haloPart: Part? = nil
	if species.hasHalo then
		local halo = attachWeldedPart(root, CFrame.new(0, 1.88, 0.04) * CFrame.Angles(0, 0, math.rad(90)), makePart({
			name = "Halo",
			size = Vector3.new(0.12, 1.05, 1.05),
			color = if species.rarity == "Godly" or species.rarity == "Legendary"
				then Color3.fromRGB(255, 226, 112)
				else species.accentColor,
			material = Enum.Material.Neon,
			transparency = 0.1,
			shape = Enum.PartType.Cylinder,
			parent = model,
		}))
		local haloLight = Instance.new("PointLight")
		haloLight.Color = rarityMeta.glowColor
		haloLight.Range = 10
		haloLight.Brightness = 0.85
		haloLight.Parent = halo
		haloPart = halo
	end

	-- Higher Rarity Translucent Wings
	local leftWing: Part? = nil
	local rightWing: Part? = nil
	if species.hasWings then
		leftWing = attachWeldedPart(root, CFrame.new(-0.78, 0.24, 0.44) * CFrame.Angles(0.1, 0.45, 0.22), makePart({
			name = "LeftWing",
			size = Vector3.new(1.18, 0.92, 0.08),
			color = species.accentColor,
			material = Enum.Material.Neon,
			transparency = 0.28,
			parent = model,
		}))
		rightWing = attachWeldedPart(root, CFrame.new(0.78, 0.24, 0.44) * CFrame.Angles(0.1, -0.45, -0.22), makePart({
			name = "RightWing",
			size = Vector3.new(1.18, 0.92, 0.08),
			color = species.accentColor,
			material = Enum.Material.Neon,
			transparency = 0.28,
			parent = model,
		}))
	end

	-- Epic / Legendary / Godly Aura Particles
	if species.hasAura then
		local auraAtt = Instance.new("Attachment")
		auraAtt.Parent = root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = if species.rarity == "Godly" then 14 else 7
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1.0, 2.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.14),
			NumberSequenceKeypoint.new(0.5, 0.24),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Color = ColorSequence.new(rarityMeta.color, Color3.fromRGB(255, 255, 255))
		emitter.LightEmission = 0.9
		emitter.Parent = auraAtt
	end

	-- Crisp Nameplate
	local tag = Instance.new("BillboardGui")
	tag.Name = "CompanionTag"
	tag.Adornee = head
	tag.Size = UDim2.fromOffset(120, 32)
	tag.StudsOffset = Vector3.new(0, 1.25, 0)
	tag.MaxDistance = 30
	tag.Parent = model

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.fromScale(1, 1)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = species.name
	nameLbl.TextColor3 = rarityMeta.color
	nameLbl.TextStrokeTransparency = 0.35
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.Parent = tag

	return {
		speciesId = species.id,
		model = model,
		rootPart = root,
		leftWing = leftWing,
		rightWing = rightWing,
		haloPart = haloPart,
		leftArm = leftArm,
		rightArm = rightArm,
		currentCFrame = spawnCFrame,
		slotIndex = slotIndex,
	}
end

local function clearPlayerRigs(userId: number): ()
	local existing = rigsByUserId[userId]
	if existing then
		for _, rig in ipairs(existing) do
			if rig.model.Parent then
				rig.model:Destroy()
			end
		end
		rigsByUserId[userId] = nil
	end
end

local function rebuildPlayerCompanions(player: Player): ()
	clearPlayerRigs(player.UserId)

	local rawAttr = player:GetAttribute("EquippedPetSpecies")
	if typeof(rawAttr) ~= "string" or rawAttr == "" then
		return
	end

	local character = player.Character
	local charRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local baseCf = if charRoot and charRoot:IsA("BasePart")
		then charRoot.CFrame
		else CFrame.new(GameConfig.SPAWN_POSITION)

	local rigs: { CompanionRig } = {}
	local slotIndex = 0
	for speciesId in string.gmatch(rawAttr, "[^,]+") do
		local species = GameConfig.PETS[speciesId]
		if species then
			slotIndex += 1
			if slotIndex <= GameConfig.MAX_EQUIPPED_PETS then
				local offset = SLOT_OFFSETS[slotIndex]
				local spawnCf = baseCf * CFrame.new(offset)
				table.insert(rigs, buildChibiCompanionRig(species, spawnCf, slotIndex))
			end
		end
	end

	rigsByUserId[player.UserId] = rigs
end

local function watchPlayer(player: Player): ()
	player:GetAttributeChangedSignal("EquippedPetSpecies"):Connect(function()
		rebuildPlayerCompanions(player)
	end)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			rebuildPlayerCompanions(player)
		end)
	end)
	rebuildPlayerCompanions(player)
end

function PetFollowerController.Init(): ()
	local existing = Workspace:FindFirstChild("ClientCompanions")
	if existing and existing:IsA("Folder") then
		companionFolder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "ClientCompanions"
		created.Parent = Workspace
		companionFolder = created
	end

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		clearPlayerRigs(player.UserId)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local elapsed = os.clock()
		local lerpAlpha = math.clamp(1 - math.exp(-7.5 * dt), 0.02, 1)

		for userId, rigs in pairs(rigsByUserId) do
			local player = Players:GetPlayerByUserId(userId)
			local character = if player then player.Character else nil
			local charRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil

			if charRoot and charRoot:IsA("BasePart") then
				for _, rig in ipairs(rigs) do
					if rig.model.Parent then
						local offset = SLOT_OFFSETS[rig.slotIndex] or SLOT_OFFSETS[1]
						local bobY = math.sin(elapsed * 2.8 + rig.slotIndex * 1.6) * 0.42
						local swayX = math.cos(elapsed * 1.9 + rig.slotIndex * 1.1) * 0.22
						local tiltZ = math.sin(elapsed * 2.4 + rig.slotIndex) * 0.08
						local targetCf = charRoot.CFrame
							* CFrame.new(offset.X + swayX, offset.Y + bobY, offset.Z)
							* CFrame.Angles(0, 0, tiltZ)

						rig.currentCFrame = rig.currentCFrame:Lerp(targetCf, lerpAlpha)
						rig.rootPart.CFrame = rig.currentCFrame
					end
				end
			end
		end
	end)
end

return PetFollowerController
