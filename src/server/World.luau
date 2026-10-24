-- Puts the FindJob building into the host world and takes it out again.
-- Everything spawned lives under one folder so Disable() leaves no trace.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.FindJobCampaign
local Config = require(Shared.Config)

local World = {}

local container = nil

function World.spawn()
	if container then
		return
	end

	container = Instance.new("Folder")
	container.Name = "FindJobCampaign"

	local buildingTemplate = Shared.Assets:FindFirstChild(Config.World.BuildingName)
	local recruiterTemplate = Shared.Assets:FindFirstChild(Config.World.RecruiterName)
	if not buildingTemplate or not recruiterTemplate then
		warn("[FindJob] Assets are missing the building or the recruiter, spawning an empty campaign")
		container.Parent = Workspace
		return
	end

	local building = buildingTemplate:Clone()
	building:PivotTo(Config.World.Origin)
	building.Parent = container

	-- The spot is a flat part on the floor, lift the recruiter so their feet touch it
	local spot = building:FindFirstChild(Config.World.RecruiterSpotName, true)
	local recruiter = recruiterTemplate:Clone()
	local humanoid = recruiter:FindFirstChildOfClass("Humanoid")
	local lift = humanoid.HipHeight + recruiter.PrimaryPart.Size.Y / 2 + spot.Size.Y / 2
	recruiter:PivotTo(spot.CFrame * CFrame.new(0, lift, 0))
	recruiter.Parent = container

	container.Parent = Workspace
end

function World.despawn()
	if container then
		container:Destroy()
		container = nil
	end
end

-- Finds a named model/part inside the spawned building (recruiter, stations...)
function World.find(name)
	return container and container:FindFirstChild(name, true)
end

function World.addPrompt(targetName, actionText)
	local target = World.find(targetName)
	if not target then
		warn("[FindJob] Can't add prompt, " .. targetName .. " not found in the building")
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = "FindJob"
	prompt.MaxActivationDistance = Config.World.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = if target:IsA("Model") then target.PrimaryPart else target
	return prompt
end

return World
