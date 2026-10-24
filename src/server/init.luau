--[[
	FindJob campaign, server side. This is what the host game talks to.

		local Campaign = require(ServerScriptService.FindJobCampaign)

		Campaign.RewardGranted:Connect(function(player, reward) ... end)
		Campaign.MissionCompleted:Connect(function(player, fieldId) ... end)
		Campaign.PlayerExited:Connect(function(player, step) ... end)
		Campaign.EnabledChanged:Connect(function(isEnabled) ... end)

		Campaign:Exit(player)   -- stop the campaign for one player, back to the normal game
		Campaign:Disable()      -- remove the campaign from the game (building, UI, everything)
		Campaign:Enable()       -- bring it back
		Campaign:IsEnabled()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.FindJobCampaign
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local ServerConfig = require(script.ServerConfig)
local Classifier = require(script.Classifier)
local Tracker = require(script.Tracker)
local World = require(script.World)

local Missions = {
	Coding = require(script.Missions.Coding),
	Grading = require(script.Missions.Grading),
}

local Campaign = {}

Campaign.RewardGranted = Signal.new() -- (player, reward)
Campaign.MissionCompleted = Signal.new() -- (player, fieldId)
Campaign.PlayerExited = Signal.new() -- (player, step)
Campaign.EnabledChanged = Signal.new() -- (isEnabled)

-- Where a player is in the flow. Requests that don't match the current step are ignored.
local Step = {
	Talking = "Talking",
	GoingToStation = "GoingToStation",
	InMission = "InMission",
	FitCheck = "FitCheck",
	Done = "Done",
}
Campaign.Step = Step

local started = false
local enabled = false
local sessions = {} -- [player] = session, see newSession
local rewardedUserIds = {} -- one reward per player per server, even if they replay
local lastRequest = {} -- [player] = { [remoteName] = os.clock() }

local function newSession()
	return {
		step = Step.Talking,
		fieldId = nil,
		startedAt = os.clock(),
		stepStartedAt = os.clock(),
		attempts = 0,
	}
end

local function setStep(session, step)
	session.step = step
	session.stepStartedAt = os.clock()
end

-- Announces the reward to the host game. Returns false if it was already given.
local function grantReward(player)
	if rewardedUserIds[player.UserId] then
		return false
	end
	rewardedUserIds[player.UserId] = true

	local hostListening = Campaign.RewardGranted:HasConnections()
	if not hostListening then
		warn("[FindJob] Nothing is connected to Campaign.RewardGranted, the reward goes nowhere")
	end

	local reward = table.clone(Config.Reward)
	Tracker.track(player, "RewardGranted", { reward = reward.Id, amount = reward.Amount, hostListening = hostListening })
	Campaign.RewardGranted:Fire(player, reward)
	return true
end

-- Wraps a client -> server remote: drops requests while disabled or spammed
local function onRequest(remote, handler)
	remote.OnServerEvent:Connect(function(player, ...)
		if not enabled then
			return
		end

		local times = lastRequest[player]
		if not times then
			times = {}
			lastRequest[player] = times
		end
		local now = os.clock()
		if times[remote.Name] and now - times[remote.Name] < ServerConfig.RemoteCooldown then
			return
		end
		times[remote.Name] = now

		handler(player, ...)
	end)
end

-- Proximity prompt handlers -------------------------------------------------

local function onRecruiterTriggered(player)
	--[[
		TODO:
		- ignore if the player already has a session that isn't Done
		- sessions[player] = newSession()
		- track ConversationStarted
		- Remotes.OpenDialogue:FireClient(player)
	]]
end

local function onStationTriggered(player, fieldId)
	--[[
		TODO:
		- session must exist, be at Step.GoingToStation and have this fieldId
		- setStep(session, Step.InMission)
		- local missionId = Config.Fields[fieldId].MissionId
		- Remotes.MissionStarted:FireClient(player, missionId, Missions[missionId].buildPuzzle())
		- track MissionStarted
	]]
end

-- Client requests ------------------------------------------------------------

local function onSubmitAnswers(player, answerIndexes)
	--[[
		TODO:
		- session must be at Step.Talking
		- Classifier.isValid(answerIndexes), then Classifier.classify(answerIndexes)
		- store fieldId, setStep(session, Step.GoingToStation)
		- track QuestionAnswered / Classified (include the score margin)
		- Remotes.FieldAssigned:FireClient(player, fieldId)
	]]
end

local function onSubmitMission(player, submission)
	--[[
		TODO:
		- session must be at Step.InMission
		- reject submissions faster than ServerConfig.MinMissionSeconds
		- result = Missions[missionId].validate(submission), session.attempts += 1
		- track MissionAttempt
		- on success: setStep(session, Step.FitCheck), grantReward(player),
		  Campaign.MissionCompleted:Fire(player, fieldId), track MissionCompleted
		- Remotes.MissionResult:FireClient(player, result)
	]]
end

local function onSubmitFitFeedback(player, agreed)
	--[[
		TODO:
		- session must be at Step.FitCheck, agreed must be a boolean
		- track FitFeedback with the field, attempts and classification margin
		- setStep(session, Step.Done), track SessionEnded
	]]
end

local function onRequestExit(player)
	Campaign:Exit(player)
end

local function onTrack(player, eventName, data)
	--[[
		TODO:
		- only accept names in Tracker.ClientEvents
		- don't forward raw client tables, pick the fields you expect
	]]
end

-- Public API ----------------------------------------------------------------

function Campaign:Exit(player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil

	if session.step ~= Step.Done then
		Tracker.track(player, "Exited", { step = session.step, seconds = os.clock() - session.startedAt })
	end
	if player.Parent then
		Remotes.CloseAll:FireClient(player)
	end
	self.PlayerExited:Fire(player, session.step)
end

function Campaign:Enable()
	if enabled then
		return
	end
	enabled = true

	World.spawn()

	local recruiterPrompt = World.addPrompt(Config.World.RecruiterName, Config.Recruiter.PromptText)
	if recruiterPrompt then
		recruiterPrompt.Triggered:Connect(onRecruiterTriggered)
	end

	for fieldId, field in Config.Fields do
		local stationPrompt = World.addPrompt(field.StationName, field.PromptText)
		if stationPrompt then
			stationPrompt.Triggered:Connect(function(player)
				onStationTriggered(player, fieldId)
			end)
		end
	end

	self.EnabledChanged:Fire(true)
end

function Campaign:Disable()
	if not enabled then
		return
	end
	enabled = false

	for player in sessions do
		self:Exit(player)
	end
	-- Prompts are destroyed with the building, so their connections go too
	World.despawn()

	self.EnabledChanged:Fire(false)
end

function Campaign:IsEnabled()
	return enabled
end

-- Called once by FindJobCampaignLoader
function Campaign:Start()
	if started then
		return
	end
	started = true

	onRequest(Remotes.SubmitAnswers, onSubmitAnswers)
	onRequest(Remotes.SubmitMission, onSubmitMission)
	onRequest(Remotes.SubmitFitFeedback, onSubmitFitFeedback)
	onRequest(Remotes.RequestExit, onRequestExit)
	onRequest(Remotes.Track, onTrack)

	Players.PlayerRemoving:Connect(function(player)
		self:Exit(player)
		lastRequest[player] = nil
	end)

	if Config.EnabledOnStart then
		self:Enable()
	end
end

return Campaign
