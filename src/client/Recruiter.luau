-- Client-side recruiter behaviour: notices the player walking by, turns to face them,
-- waves and shows the guide. Animations played here are local to this player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FindJobCampaign")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local Guide = require(script.Parent.Guide)

local CHECK_INTERVAL = 0.2
local WAVE_COOLDOWN = 6

local Recruiter = {}

Recruiter.Seen = Signal.new() -- first time this player comes near the recruiter

local busy = false -- talking or on a mission, don't wave or point at the recruiter
local hasBeenSeen = false
local tracks = {} -- [animationName] = AnimationTrack, for the current model
local trackedModel = nil
local lastWave = 0
local wasNear = false

function Recruiter.getModel()
	local container = Workspace:FindFirstChild("FindJobCampaign")
	return container and container:FindFirstChild(Config.World.RecruiterName)
end

local function loadTracks(model)
	tracks = {}
	trackedModel = model
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return
	end
	for name, id in Config.Recruiter.Animations do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		tracks[name] = animator:LoadAnimation(animation)
	end
end

function Recruiter.play(name)
	local model = Recruiter.getModel()
	if not model then
		return
	end
	if model ~= trackedModel then
		loadTracks(model)
	end
	local track = tracks[name]
	if track then
		track:Play(0.2)
	end
end

function Recruiter.setBusy(isBusy)
	busy = isBusy
	if busy and Guide.target() == Recruiter.getModel() then
		Guide.hide()
	end
end

-- Turns the recruiter (locally) to look at a position, only around the Y axis
local function face(model, position)
	local root = model.PrimaryPart
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		local goal = CFrame.lookAt(root.Position, flat)
		TweenService:Create(root, TweenInfo.new(CHECK_INTERVAL), { CFrame = goal }):Play()
	end
end

local function update()
	local model = Recruiter.getModel()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not model or not model.PrimaryPart or not root then
		wasNear = false
		return
	end

	local distance = (root.Position - model.PrimaryPart.Position).Magnitude
	local near = distance <= Config.World.GreetRadius

	if near then
		face(model, root.Position)

		if not wasNear and not busy and os.clock() - lastWave > WAVE_COOLDOWN then
			lastWave = os.clock()
			Recruiter.play("Wave")
		end
		if not busy and Guide.target() ~= model then
			Guide.show(model)
		end
		if not hasBeenSeen then
			hasBeenSeen = true
			Recruiter.Seen:Fire(distance)
		end
	elseif wasNear and Guide.target() == model then
		Guide.hide()
	end

	wasNear = near
end

function Recruiter.start()
	task.spawn(function()
		while true do
			update()
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return Recruiter
