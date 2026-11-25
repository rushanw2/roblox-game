--!strict
-- Thin client entry point wiring state sync, ocean atmosphere, chibi-anime companions, interactions & UI

local ClientState = require(script:WaitForChild("ClientState"))
local AtmosphereController = require(script:WaitForChild("AtmosphereController"))
local PetFollowerController = require(script:WaitForChild("PetFollowerController"))
local HUDController = require(script:WaitForChild("HUDController"))
local InventoryUI = require(script:WaitForChild("InventoryUI"))
local ShopAndStationUI = require(script:WaitForChild("ShopAndStationUI"))
local InteractionController = require(script:WaitForChild("InteractionController"))

AtmosphereController.Init()
PetFollowerController.Init()
HUDController.Init()
InventoryUI.Init()
ShopAndStationUI.Init()
InteractionController.Init()
ClientState.Init()
