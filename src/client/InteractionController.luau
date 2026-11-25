--!strict
-- Handles world ProximityPrompts, Diving Flashlight keybind (F), and live Washbasin animations

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientFolder = script.Parent
local ClientState = require(ClientFolder:WaitForChild("ClientState"))

local InteractionController = {}

local attachedNodeIds: { [string]: boolean } = {}
local washbasinModels: { [number]: Model } = {}
local brushBasePosBySlot: { [number]: Vector3 } = {}
local eggParts: { { part: BasePart, baseY: number, phase: number } } = {}
local hatchBusy = false

local function setupExcavationNode(nodeModel: Model): ()
	local nodeIdAttr = nodeModel:GetAttribute("NodeId")
	if typeof(nodeIdAttr) ~= "string" or attachedNodeIds[nodeIdAttr] then
		return
	end
	attachedNodeIds[nodeIdAttr] = true

	local primary = nodeModel.PrimaryPart or nodeModel:FindFirstChildWhichIsA("BasePart")
	if not primary then
		return
	end

	local displayName = nodeModel:GetAttribute("NodeDisplayName")
	local zoneIdAttr = nodeModel:GetAttribute("ZoneId")
	local zoneLabel = if typeof(zoneIdAttr) == "string" and GameConfig.ZONES[zoneIdAttr :: GameConfig.ZoneId]
		then GameConfig.ZONES[zoneIdAttr :: GameConfig.ZoneId].name
		else "Ocean"

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExcavatePrompt"
	prompt.ObjectText = if typeof(displayName) == "string" then displayName else "Excavation Site"
	prompt.ActionText = "Excavate (" .. zoneLabel .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Enabled = nodeModel:GetAttribute("IsAvailable") == true
	prompt.Parent = primary

	nodeModel:GetAttributeChangedSignal("IsAvailable"):Connect(function()
		prompt.Enabled = nodeModel:GetAttribute("IsAvailable") == true
	end)

	prompt.Triggered:Connect(function()
		local ok, res = pcall(function(): any
			return Remotes.ExcavateNode:InvokeServer(nodeIdAttr)
		end)
		if ok and typeof(res) == "table" and not res.success and typeof(res.message) == "string" then
			ClientState.EmitLocalToast(res.message, "Warn")
		end
	end)
end

local function attachStationPrompt(part: BasePart, objectText: string, actionText: string, maxDist: number, onTrigger: () -> ()): ()
	local existing = part:FindFirstChild("StationPrompt")
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = maxDist
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(onTrigger)
end

local function triggerEggHatch(eggId: GameConfig.EggId): ()
	if hatchBusy then
		return
	end
	hatchBusy = true
	local ok, res = pcall(function(): any
		return Remotes.HatchEgg:InvokeServer(eggId)
	end)
	hatchBusy = false

	if not ok then
		ClientState.EmitLocalToast("Failed to hatch egg.", "Warn")
		return
	end
	if typeof(res) == "table" and not res.success then
		ClientState.EmitLocalToast(res.message or "Cannot hatch egg right now.", "Warn")
	end
end

local function wireHarborInteractables(oceanWorld: Instance): ()
	local hub = oceanWorld:WaitForChild("HarborHub", 10)
	if not hub then
		return
	end

	for _, desc in ipairs(hub:GetDescendants()) do
		if desc:IsA("BasePart") then
			local interactType = desc:GetAttribute("InteractType")
			if interactType == "CleaningStation" then
				attachStationPrompt(desc, "Relic Cleaning Station", "Open Washbasins", 18, function()
					ClientState.OpenWindow("Cleaning")
				end)
			elseif interactType == "AppraisalCounter" then
				attachStationPrompt(desc, "Appraisal & Sell Counter", "Appraise & Sell Relics", 16, function()
					ClientState.OpenWindow("Appraisal")
				end)
			elseif interactType == "GearShop" then
				attachStationPrompt(desc, "Dive Gear & Buff Shop", "Browse Upgrades & Buffs", 16, function()
					ClientState.OpenWindow("Shop")
				end)
			elseif interactType == "EggPedestal" then
				local eggIdAttr = desc:GetAttribute("EggId")
				if typeof(eggIdAttr) == "string" then
					local eggCfg = (GameConfig.EGGS :: { [string]: GameConfig.EggConfig })[eggIdAttr]
					if eggCfg then
						table.insert(eggParts, {
							part = desc,
							baseY = desc.Position.Y,
							phase = eggCfg.pedestalIndex * 1.2,
						})
						attachStationPrompt(
							desc,
							eggCfg.name,
							string.format("Hatch (%s Coins)", GameConfig.FormatNumber(eggCfg.cost)),
							12,
							function()
								triggerEggHatch(eggCfg.id)
							end
						)
					end
				end
			end
		elseif desc:IsA("Model") then
			local slotAttr = desc:GetAttribute("SlotIndex")
			if typeof(slotAttr) == "number" then
				washbasinModels[slotAttr] = desc
				local brush = desc:FindFirstChild("ScrubBrush")
				if brush and brush:IsA("Model") then
					local basePosAttr = brush:GetAttribute("BasePos")
					if typeof(basePosAttr) == "Vector3" then
						brushBasePosBySlot[slotAttr] = basePosAttr
					end
				end
			end
		end
	end
end

local function updateCleaningBasinsVisuals(elapsed: number): ()
	local state = ClientState.GetState()
	local now = ClientState.GetServerTime()

	for slotIndex = 1, GameConfig.CLEANING_SLOT_COUNT do
		local basin = washbasinModels[slotIndex]
		if basin then
			local slotData = state.profile.CleaningSlots[tostring(slotIndex)]
			local relicPreview = basin:FindFirstChild("RelicPreview")
			local brush = basin:FindFirstChild("ScrubBrush")
			local bGui = basin:FindFirstChild("SlotProgressGui")
			local container = if bGui then bGui:FindFirstChild("Container") else nil

			if slotData then
				local relicCfg = GameConfig.RELICS[slotData.rawItemId]
				local totalDur = math.max(0.1, slotData.duration)
				local progress = math.clamp((now - slotData.startedAt) / totalDur, 0, 1)
				local remaining = math.max(0, slotData.endsAt - now)
				local isReady = remaining <= 0.05

				if relicPreview and relicPreview:IsA("BasePart") then
					relicPreview.Transparency = 0
					if relicCfg then
						relicPreview.Color = relicCfg.color
					end
				end

				if brush and brush:IsA("Model") and brush.PrimaryPart then
					local basePos = brushBasePosBySlot[slotIndex]
					if basePos then
						if isReady then
							brush:PivotTo(CFrame.new(basePos + Vector3.new(0, 0.55, 0)))
						else
							local scrubX = math.sin(elapsed * 14 + slotIndex) * 0.65
							local scrubZ = math.cos(elapsed * 10 + slotIndex) * 0.45
							brush:PivotTo(CFrame.new(basePos + Vector3.new(scrubX, -0.1, scrubZ)) * CFrame.Angles(0, math.sin(elapsed * 7) * 0.25, 0))
						end
					end
				end

				if container and container:IsA("Frame") then
					local statusLbl = container:FindFirstChild("StatusLabel")
					local barBg = container:FindFirstChild("BarBg")
					local barFill = if barBg then barBg:FindFirstChild("BarFill") else nil
					local stroke = container:FindFirstChild("BorderStroke")

					if statusLbl and statusLbl:IsA("TextLabel") then
						if isReady then
							statusLbl.Text = string.format("Basin %d: READY TO CLAIM!", slotIndex)
							statusLbl.TextColor3 = Color3.fromRGB(116, 255, 168)
						else
							local itemName = if relicCfg then relicCfg.name else "Relic"
							statusLbl.Text = string.format("%s (%.1fs)", itemName, remaining)
							statusLbl.TextColor3 = Color3.fromRGB(228, 244, 255)
						end
					end
					if barFill and barFill:IsA("Frame") then
						barFill.Size = UDim2.fromScale(progress, 1)
						barFill.BackgroundColor3 = if isReady then Color3.fromRGB(92, 248, 152) else Color3.fromRGB(78, 224, 255)
					end
					if stroke and stroke:IsA("UIStroke") then
						stroke.Color = if isReady then Color3.fromRGB(92, 248, 152) else Color3.fromRGB(82, 186, 244)
					end
				end
			else
				if relicPreview and relicPreview:IsA("BasePart") then
					relicPreview.Transparency = 1
				end
				if brush and brush:IsA("Model") and brush.PrimaryPart then
					local basePos = brushBasePosBySlot[slotIndex]
					if basePos then
						brush:PivotTo(CFrame.new(basePos))
					end
				end
				if container and container:IsA("Frame") then
					local statusLbl = container:FindFirstChild("StatusLabel")
					local barBg = container:FindFirstChild("BarBg")
					local barFill = if barBg then barBg:FindFirstChild("BarFill") else nil
					local stroke = container:FindFirstChild("BorderStroke")
					if statusLbl and statusLbl:IsA("TextLabel") then
						statusLbl.Text = string.format("Basin %d: Empty", slotIndex)
						statusLbl.TextColor3 = Color3.fromRGB(178, 198, 224)
					end
					if barFill and barFill:IsA("Frame") then
						barFill.Size = UDim2.fromScale(0, 1)
					end
					if stroke and stroke:IsA("UIStroke") then
						stroke.Color = Color3.fromRGB(82, 186, 244)
					end
				end
			end
		end
	end
end

function InteractionController.Init(): ()
	task.spawn(function()
		local oceanWorld = Workspace:WaitForChild("OceanWorld", 15)
		if not oceanWorld then
			return
		end

		wireHarborInteractables(oceanWorld)

		local nodesFolder = oceanWorld:WaitForChild("ExcavationNodes", 10)
		if nodesFolder then
			for _, child in ipairs(nodesFolder:GetChildren()) do
				if child:IsA("Model") then
					setupExcavationNode(child)
				end
			end
			nodesFolder.ChildAdded:Connect(function(child: Instance)
				if child:IsA("Model") then
					task.defer(function()
						setupExcavationNode(child)
					end)
				end
			end)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			Remotes.ToggleFlashlight:FireServer()
		elseif input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.I then
			ClientState.SetActiveWindow("Inventory")
		elseif input.KeyCode == Enum.KeyCode.Escape then
			ClientState.CloseWindows()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local elapsed = os.clock()
		updateCleaningBasinsVisuals(elapsed)

		for _, eggEntry in ipairs(eggParts) do
			if eggEntry.part.Parent then
				local pos = eggEntry.part.Position
				local newY = eggEntry.baseY + math.sin(elapsed * 2.2 + eggEntry.phase) * 0.35
				eggEntry.part.CFrame = CFrame.new(pos.X, newY, pos.Z) * CFrame.Angles(0, elapsed * 0.8 + eggEntry.phase, 0)
			end
		end
	end)
end

return InteractionController
