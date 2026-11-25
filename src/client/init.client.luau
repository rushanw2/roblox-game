--!strict
-- Thin client entry point wiring ClientState, VisionConeRenderer, WorldVisualsController, and HudController

local ClientState = require(script:WaitForChild("ClientState"))
local VisionConeRenderer = require(script:WaitForChild("VisionConeRenderer"))
local WorldVisualsController = require(script:WaitForChild("WorldVisualsController"))
local HudController = require(script:WaitForChild("HudController"))

ClientState.Init()
VisionConeRenderer.Start()
WorldVisualsController.Start()
HudController.Start()
