-- Client-side recruiter behaviour: her name tag and idle animation, noticing the player
-- walking by, turning to face them, waving and showing the guide. All local to this player.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Libraries = script.Parent.Parent.Libraries
local Config = require(Libraries.Config)
local Signal = require(Libraries.Signal)

local Guide = require(script.Parent.Guide)
local Ui = require(script.Parent.Ui)

local CHECK_INTERVAL = 0.2
local WAVE_COOLDOWN = 6
local LOOPED_SECONDS = 4
-- Roblox's own R15 animations, so they work in any game without uploading anything
local IDLE = "rbxassetid://507766666" -- breathing, loops under everything else
local ANIMATIONS = {
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
	Cheer = "rbxassetid://507770677",
	Laugh = "rbxassetid://507770818",
	Dance = "rbxassetid://507771019",
}
-- While a player is around and nothing is going on, she does one of these now and then
local AMBIENT_EMOTES = { "Laugh", "Point", "Wave" }
local AMBIENT_EVERY = NumberRange.new(9, 15) -- seconds

local Recruiter = {}

Recruiter.Seen = Signal.new() -- first time this player comes near the recruiter

-- Which emote she plays at each moment of the conversation
Recruiter.Moments = {
	Greeting = "Wave", -- player walks up, and when she starts talking
	Reveal = "Cheer", -- telling the player their match
	SendToStation = "Point", -- pointing at the mission pedestal
	MissionDone = "Dance",
	FitCheckYes = "Cheer",
	FitCheckNo = "Laugh",
}

local busy = false -- talking or on a mission, don't wave or point at the recruiter
local hasBeenSeen = false
local tracks = {} -- [animationName] = AnimationTrack, for the current model
local preparedModel = nil -- the model the tracks and name tag belong to
local lastWave = 0
local wasNear = false
local nextEmoteAt = 0

function Recruiter.getModel()
	local container = Workspace:FindFirstChild(Config.World.FolderName)
	return container and container:FindFirstChild("Recruiter")
end

local function loadTrack(animator, id, priority)
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	return track
end

-- Runs once per model (it comes back as a new one after the campaign is re-enabled):
-- name tag over her head instead of the plain Humanoid name, idle loop, emote tracks
local function prepare(model)
	preparedModel = model
	tracks = {}

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local head = model:FindFirstChild("Head")
	if head then
		local nameplate = Ui.template("Nameplate")
		nameplate.Adornee = head
		nameplate.Parent = head
		-- Gentle float
		local resting = nameplate.StudsOffsetWorldSpace
		TweenService:Create(nameplate, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			StudsOffsetWorldSpace = resting + Vector3.new(0, 0.15, 0),
		}):Play()
	end

	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return
	end
	local idle = loadTrack(animator, IDLE, Enum.AnimationPriority.Idle)
	idle.Looped = true
	idle:Play()
	for name, id in ANIMATIONS do
		tracks[name] = loadTrack(animator, id, Enum.AnimationPriority.Action)
	end
end

function Recruiter.play(name)
	local model = Recruiter.getModel()
	if not model then
		return
	end
	if model ~= preparedModel then
		prepare(model)
	end
	local track = tracks[name]
	if not track then
		return
	end
	for _, other in tracks do
		if other ~= track and other.IsPlaying then
			other:Stop(0.2)
		end
	end
	track:Play(0.2)
	-- Some emotes (dances) loop forever: keep them short
	if track.Looped then
		task.delay(LOOPED_SECONDS, function()
			track:Stop(0.4)
		end)
	end
end

function Recruiter.setBusy(isBusy)
	busy = isBusy
	if busy and Guide.target() == Recruiter.getModel() then
		Guide.hide()
	end
end

local function randomEmoteDelay()
	return AMBIENT_EVERY.Min + math.random() * (AMBIENT_EVERY.Max - AMBIENT_EVERY.Min)
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
	if model and model ~= preparedModel and model.PrimaryPart then
		prepare(model)
	end
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
			Recruiter.play(Recruiter.Moments.Greeting)
		end
		-- Little emotes now and then keep her lively while the player hangs around
		local now = os.clock()
		if not wasNear or busy then
			nextEmoteAt = now + randomEmoteDelay()
		elseif now >= nextEmoteAt then
			nextEmoteAt = now + randomEmoteDelay()
			Recruiter.play(AMBIENT_EMOTES[math.random(#AMBIENT_EMOTES)])
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
