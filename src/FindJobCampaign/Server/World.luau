-- Puts the FindJob stand into the host world and takes it out again.
--
-- The stand and the recruiter normally sit in the place already, in a Workspace folder
-- named Config.World.FolderName, so they can be seen and moved around in Studio.
-- Disable() parks that folder in ServerStorage and Enable() brings it back.
-- If the folder isn't there, they're spawned from Assets at Config.World.Origin instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Package = ReplicatedStorage:WaitForChild("FindJobCampaign") -- moved there by the Loader
local Config = require(Package.Libraries.Config)

local World = {}

local container = nil
local placed = nil -- the folder that came with the place, kept while disabled
local prompts = {}

-- Host games may use streaming: send the stand and the recruiter as one piece each,
-- so clients never see half of them
local function streamAsOnePiece(folder)
	for _, name in { "Stand", "Recruiter" } do
		local model = folder:FindFirstChild(name)
		if model then
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		end
	end
end

local function spawnFromAssets()
	local folder = Instance.new("Folder")
	folder.Name = Config.World.FolderName

	local standTemplate = Package.Assets:FindFirstChild("Stand")
	local recruiterTemplate = Package.Assets:FindFirstChild("Recruiter")
	if not standTemplate or not recruiterTemplate then
		warn("[FindJob] No stand in the Workspace or in Assets, spawning an empty campaign")
		return folder
	end

	local stand = standTemplate:Clone()
	stand:PivotTo(Config.World.Origin)
	stand.Parent = folder

	-- The spot is a flat part on the floor, lift the recruiter so their feet touch it
	local spot = stand:FindFirstChild("RecruiterSpot", true)
	local recruiter = recruiterTemplate:Clone()
	local humanoid = recruiter:FindFirstChildOfClass("Humanoid")
	local lift = humanoid.HipHeight + recruiter.PrimaryPart.Size.Y / 2 + spot.Size.Y / 2
	recruiter:PivotTo(spot.CFrame * CFrame.new(0, lift, 0))
	recruiter.Parent = folder
	return folder
end

function World.spawn()
	if container then
		return
	end
	placed = placed or Workspace:FindFirstChild(Config.World.FolderName)
	container = placed or spawnFromAssets()
	streamAsOnePiece(container)
	container.Parent = Workspace
end

function World.despawn()
	for _, prompt in prompts do
		prompt:Destroy()
	end
	prompts = {}
	if not container then
		return
	end
	if container == placed then
		container.Parent = ServerStorage
	else
		container:Destroy()
	end
	container = nil
end

-- Finds a named model/part inside the stand (recruiter, pedestals...)
function World.find(name)
	return container and container:FindFirstChild(name, true)
end

function World.addPrompt(targetName, actionText)
	local target = World.find(targetName)
	if not target then
		warn("[FindJob] Can't add prompt, " .. targetName .. " not found in the stand")
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = "FindJob"
	prompt.MaxActivationDistance = Config.World.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = if target:IsA("Model") then target.PrimaryPart else target
	table.insert(prompts, prompt)
	return prompt
end

return World
