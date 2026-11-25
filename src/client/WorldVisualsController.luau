--!strict
-- Manages client-side 3D visuals and physical controls:
-- 1. Visible carried luggage prop attached to player characters
-- 2. Live Hideout Workbench 3D suitcase props, progress bars & lid-opening reveals
-- 3. Crouch camera/pose feedback & stealth/gadget hotkeys

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LuggageVisuals = require(Shared:WaitForChild("LuggageVisuals"))

local ClientFolder = script.Parent
local ClientState = require(ClientFolder:WaitForChild("ClientState"))

type BenchShowcase = {
	bagUid: string,
	archetypeId: string,
	model: Model,
	lidPivotCFrame: CFrame?,
	lidGroup: Model?,
	lidOpenProgress: number,
}

local WorldVisualsController = {}

local carriedPropsByPlayer: { [Player]: { archetypeId: string, model: Model } } = {}
local benchShowcases: { [number]: BenchShowcase } = {}
local modalOpenRequestCb: ((string) -> ())? = nil

local function removeCarriedProp(player: Player)
	local rec = carriedPropsByPlayer[player]
	if rec then
		if rec.model and rec.model.Parent then
			rec.model:Destroy()
		end
		carriedPropsByPlayer[player] = nil
	end
end

local function refreshCarriedPropForPlayer(player: Player)
	local archId = player:GetAttribute("CarriedArchetype")
	if typeof(archId) ~= "string" or archId == "" then
		removeCarriedProp(player)
		return
	end

	local character = player.Character
	if not character then
		removeCarriedProp(player)
		return
	end

	local attachPart = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not attachPart then
		return
	end

	local existing = carriedPropsByPlayer[player]
	if existing and existing.archetypeId == archId and existing.model.Parent == character then
		return
	end

	removeCarriedProp(player)

	local arch = GameConfig.GetArchetype(archId)
	if not arch then
		return
	end

	local bagOffset = attachPart.CFrame * CFrame.new(0, -0.5, 1.15)
	local model = LuggageVisuals.BuildModel(arch, bagOffset, {
		scale = 0.72,
		anchored = false,
		withHingedLid = false,
		withRarityGlow = true,
	})
	model.Name = "CarriedLuggageProp"

	local primary = model.PrimaryPart
	if primary then
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.CanCollide = false
				desc.Massless = true
				if desc ~= primary then
					local w = Instance.new("WeldConstraint")
					w.Part0 = primary
					w.Part1 = desc
					w.Parent = primary
				end
			end
		end

		local backWeld = Instance.new("WeldConstraint")
		backWeld.Part0 = attachPart
		backWeld.Part1 = primary
		backWeld.Parent = primary
	end

	model.Parent = character
	carriedPropsByPlayer[player] = {
		archetypeId = archId,
		model = model,
	}
end

local function watchPlayerProps(player: Player)
	player:GetAttributeChangedSignal("CarriedArchetype"):Connect(function()
		refreshCarriedPropForPlayer(player)
	end)
	player.CharacterAdded:Connect(function()
		removeCarriedProp(player)
		task.wait(0.25)
		refreshCarriedPropForPlayer(player)
	end)
	if player.Character then
		task.defer(function()
			refreshCarriedPropForPlayer(player)
		end)
	end
end

local function updateWorkbenchVisuals(dt: number)
	local snap = ClientState.GetSnapshot()
	if not snap then
		return
	end
	local airport = Workspace:FindFirstChild("AirportWorld")
	if not airport then
		return
	end
	local decor = airport:FindFirstChild("Decor")
	if not decor then
		return
	end

	local now = Workspace:GetServerTimeNow()

	for slotIndex = 1, 4 do
		local benchModel = decor:FindFirstChild("Workbench_" .. slotIndex)
		if not benchModel or not benchModel:IsA("Model") then
			continue
		end

		local slot = snap.WorkbenchSlots[slotIndex]
		local isUnlocked = slotIndex <= snap.UpgradeLevels.WorkbenchCount

		local strip = benchModel:FindFirstChild("StatusStrip") :: BasePart?
		local anchor = benchModel:FindFirstChild("PromptAnchor") :: BasePart?
		local deskTop = benchModel:FindFirstChild("DeskTop") :: BasePart?
		local prompt = if anchor then anchor:FindFirstChild("WorkbenchPrompt") :: ProximityPrompt? else nil
		local bb = if anchor then anchor:FindFirstChild("WorkbenchStatusGui") :: BillboardGui? else nil
		local card = if bb then bb:FindFirstChildOfClass("Frame") else nil

		local titleLabel = if card then card:FindFirstChildOfClass("TextLabel") else nil
		local subLabel: TextLabel? = nil
		local progressFill: Frame? = nil
		if card then
			local labels = {}
			for _, c in ipairs(card:GetChildren()) do
				if c:IsA("TextLabel") then
					table.insert(labels, c)
				elseif c:IsA("Frame") then
					progressFill = c:FindFirstChildOfClass("Frame")
				end
			end
			if #labels >= 2 then
				titleLabel = labels[1]
				subLabel = labels[2]
			end
		end

		local existingShowcase = benchShowcases[slotIndex]
		local hasBag = slot ~= nil and slot.bagUid ~= nil and slot.archetypeId ~= nil

		if not hasBag then
			if existingShowcase then
				if existingShowcase.model and existingShowcase.model.Parent then
					existingShowcase.model:Destroy()
				end
				benchShowcases[slotIndex] = nil
			end
		else
			local bagUid = slot.bagUid :: string
			local archId = slot.archetypeId :: string
			if not existingShowcase or existingShowcase.bagUid ~= bagUid then
				if existingShowcase and existingShowcase.model and existingShowcase.model.Parent then
					existingShowcase.model:Destroy()
				end
				local arch = GameConfig.GetArchetype(archId)
				if arch and deskTop then
					local originCF = CFrame.new(deskTop.Position.X, deskTop.Position.Y + deskTop.Size.Y * 0.5, deskTop.Position.Z)
						* CFrame.Angles(0, math.pi, 0)
					local bagModel = LuggageVisuals.BuildModel(arch, originCF, {
						scale = 0.92,
						anchored = true,
						withHingedLid = true,
						withRarityGlow = true,
					})
					bagModel.Name = "WorkbenchShowcase_" .. slotIndex
					bagModel.Parent = benchModel
					local lidGroup = bagModel:FindFirstChild("LidGroup") :: Model?
					local lidPivot: CFrame? = if lidGroup and lidGroup.PrimaryPart then lidGroup:GetPivot() else nil
					existingShowcase = {
						bagUid = bagUid,
						archetypeId = archId,
						model = bagModel,
						lidGroup = lidGroup,
						lidPivotCFrame = lidPivot,
						lidOpenProgress = 0,
					}
					benchShowcases[slotIndex] = existingShowcase
				end
			end
		end

		if not isUnlocked then
			local nextCost = GameConfig.GetWorkbenchUpgrade(slotIndex).cost
			if strip then
				strip.Color = Color3.fromRGB(95, 102, 118)
			end
			if titleLabel then
				titleLabel.Text = "WORKBENCH #" .. slotIndex .. " [LOCKED]"
			end
			if subLabel then
				subLabel.Text = "Unlock in Shop: " .. GameConfig.FormatCash(nextCost)
				subLabel.TextColor3 = Color3.fromRGB(255, 190, 88)
			end
			if progressFill then
				progressFill.Size = UDim2.fromScale(0, 1)
			end
			if prompt then
				prompt.ActionText = "Locked (" .. GameConfig.FormatCash(nextCost) .. ")"
			end
		elseif not hasBag then
			if strip then
				strip.Color = Color3.fromRGB(72, 224, 255)
			end
			if titleLabel then
				titleLabel.Text = "WORKBENCH #" .. slotIndex .. " [READY]"
			end
			if subLabel then
				if #snap.StashedLuggage > 0 then
					subLabel.Text = string.format("Press E to Crack (%d in Stash)", #snap.StashedLuggage)
				else
					subLabel.Text = "Steal a bag & return to crack!"
				end
				subLabel.TextColor3 = Color3.fromRGB(160, 228, 255)
			end
			if progressFill then
				progressFill.Size = UDim2.fromScale(0, 1)
			end
			if prompt then
				prompt.ActionText = if #snap.StashedLuggage > 0 then "Place Stashed Bag" else "Workbench Empty"
			end
		else
			local dur = math.max(1, slot.duration or 10)
			local rem = math.max(0, (slot.endsAt or now) - now)
			local ready = slot.isReady or rem <= 0
			local pct = if ready then 1 else math.clamp(1 - rem / dur, 0, 1)

			if ready then
				if strip then
					strip.Color = Color3.fromRGB(68, 255, 148)
				end
				if titleLabel then
					titleLabel.Text = (slot.displayName or "Bag") .. " [OPEN!]"
				end
				if subLabel then
					subLabel.Text = "PRESS E TO CLAIM LOOT!"
					subLabel.TextColor3 = Color3.fromRGB(82, 255, 158)
				end
				if progressFill then
					progressFill.Size = UDim2.fromScale(1, 1)
					progressFill.BackgroundColor3 = Color3.fromRGB(68, 255, 148)
				end
				if prompt then
					prompt.ActionText = "Claim Revealed Loot!"
				end

				-- Animate suitcase lid flipping open!
				if existingShowcase and existingShowcase.lidGroup and existingShowcase.lidPivotCFrame then
					existingShowcase.lidOpenProgress = math.min(1, existingShowcase.lidOpenProgress + dt * 3.8)
					local openAngle = math.rad(-108 * existingShowcase.lidOpenProgress)
					existingShowcase.lidGroup:PivotTo(existingShowcase.lidPivotCFrame * CFrame.Angles(openAngle, 0, 0))
				end
			else
				if strip then
					strip.Color = Color3.fromRGB(255, 186, 56)
				end
				if titleLabel then
					titleLabel.Text = string.format("[%s] %s", slot.tier or "Bag", slot.displayName or "Luggage")
				end
				if subLabel then
					subLabel.Text = string.format("Cracking... %ds remaining", math.ceil(rem))
					subLabel.TextColor3 = Color3.fromRGB(255, 224, 130)
				end
				if progressFill then
					progressFill.Size = UDim2.fromScale(pct, 1)
					progressFill.BackgroundColor3 = Color3.fromRGB(255, 192, 56)
				end
				if prompt then
					prompt.ActionText = string.format("Cracking (%ds)", math.ceil(rem))
				end
			end
		end
	end
end

local function updateCrouchCamera(dt: number)
	local char = Players.LocalPlayer.Character
	local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end
	local targetOffsetY = if ClientState.IsCrouching() then -1.25 else 0
	local current = humanoid.CameraOffset
	local nextY = current.Y + (targetOffsetY - current.Y) * math.min(1, dt * 12)
	humanoid.CameraOffset = Vector3.new(0, nextY, 0)
end

function WorldVisualsController.SetModalCallback(cb: (string) -> ())
	modalOpenRequestCb = cb
end

function WorldVisualsController.Start()
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayerProps(p)
	end
	Players.PlayerAdded:Connect(watchPlayerProps)
	Players.PlayerRemoving:Connect(removeCarriedProp)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
			ClientState.ToggleCrouch()
		elseif input.KeyCode == Enum.KeyCode.G then
			ClientState.UseGadget()
		elseif input.KeyCode == Enum.KeyCode.H then
			ClientState.UseGadget("DistractionAlarm")
		elseif input.KeyCode == Enum.KeyCode.B then
			if modalOpenRequestCb then
				modalOpenRequestCb("Backpack")
			end
		elseif input.KeyCode == Enum.KeyCode.U then
			if modalOpenRequestCb then
				modalOpenRequestCb("Shop")
			end
		elseif input.KeyCode == Enum.KeyCode.T then
			if modalOpenRequestCb then
				modalOpenRequestCb("Terminals")
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		updateWorkbenchVisuals(dt)
		updateCrouchCamera(dt)
	end)
end

return WorldVisualsController
