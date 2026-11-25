--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PART_NAME = "TestSyncPart"
local PART_POSITION = Vector3.new(0, 10, 0)
local PART_SIZE = Vector3.new(6, 6, 6)
local INITIAL_COLOR = Color3.fromRGB(0, 255, 0)
local TOUCH_DEBOUNCE_SECONDS = 0.3

local rng = Random.new()
local lastTouchByPlayer: { [Player]: number } = {}

local function createTestPart(): (Part, PointLight)
	local part = Instance.new("Part")
	part.Name = PART_NAME
	part.Size = PART_SIZE
	part.Position = PART_POSITION
	part.Anchored = true
	part.Material = Enum.Material.Neon
	part.Color = INITIAL_COLOR
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local light = Instance.new("PointLight")
	light.Color = INITIAL_COLOR
	light.Range = 16
	light.Brightness = 2
	light.Parent = part

	part.Parent = Workspace
	return part, light
end

local function getRandomColor(): Color3
	return Color3.fromRGB(rng:NextInteger(0, 255), rng:NextInteger(0, 255), rng:NextInteger(0, 255))
end

local testPart, partLight = createTestPart()
print("[Server] TestSyncPart spawned!")

testPart.Touched:Connect(function(hit: BasePart)
	local character: Model? = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player: Player? = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	local lastTouch = lastTouchByPlayer[player]
	if lastTouch and (now - lastTouch) < TOUCH_DEBOUNCE_SECONDS then
		return
	end
	lastTouchByPlayer[player] = now

	local newColor = getRandomColor()
	testPart.Color = newColor
	partLight.Color = newColor
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastTouchByPlayer[player] = nil
end)
