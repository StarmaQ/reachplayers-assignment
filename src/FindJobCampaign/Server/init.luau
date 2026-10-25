--[[
	FindJob campaign, server side. This is what the host game talks to.

		local Campaign = require(ServerScriptService.FindJobCampaign.Server)

		Campaign.RewardGranted:Connect(function(player, reward) ... end)   -- grant it in the host's own currency

		-- Where each player is in the campaign
		Campaign.ConversationStarted:Connect(function(player) ... end)
		Campaign.MissionStarted:Connect(function(player, fieldId, missionId) ... end)
		Campaign.MissionCompleted:Connect(function(player, fieldId) ... end)
		Campaign.CampaignFinished:Connect(function(player, fieldId, agreed) ... end)
		Campaign.PlayerExited:Connect(function(player, step) ... end)   -- left before the end
		Campaign.EnabledChanged:Connect(function(isEnabled) ... end)

		Campaign:Exit(player)   -- stop the campaign for one player, back to the normal game
		Campaign:Disable()      -- remove the campaign from the game (stand, UI, everything)
		Campaign:Enable()       -- bring it back
		Campaign:IsEnabled()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Package = ReplicatedStorage:WaitForChild("FindJobCampaign") -- moved there by the Loader
local Config = require(Package.Libraries.Config)
local Signal = require(Package.Libraries.Signal)
local Remotes = Package.Remotes

local Classifier = require(script.Classifier)
local Tracker = require(script.Tracker)
local World = require(script.World)

local Missions = {
	Coding = require(script.Missions.Coding),
	Grading = require(script.Missions.Grading),
}

local Campaign = {}

Campaign.RewardGranted = Signal.new() -- (player, reward)
Campaign.ConversationStarted = Signal.new() -- (player)
Campaign.MissionStarted = Signal.new() -- (player, fieldId, missionId)
Campaign.MissionCompleted = Signal.new() -- (player, fieldId)
Campaign.CampaignFinished = Signal.new() -- (player, fieldId, agreed)
Campaign.PlayerExited = Signal.new() -- (player, step)
Campaign.EnabledChanged = Signal.new() -- (isEnabled)

-- Where a player is in the flow. Requests that don't match the current step are ignored.
local Step = {
	Talking = "Talking",
	GoingToStation = "GoingToStation",
	InMission = "InMission",
	FitCheck = "FitCheck",
}
Campaign.Step = Step

local started = false
local enabled = false
local sessions = {} -- [player] = session, see newSession
local rewardedUserIds = {} -- one reward per player per server, even if they replay

local function newSession()
	return {
		step = Step.Talking,
		startedAt = os.clock(),
		stepStartedAt = os.clock(),
		fieldId = nil,
		missionId = nil,
		missionStep = 1, -- which exercise / paper the player is on
		margin = 0, -- how far ahead the winning field was, low = unsure classification
		attempts = 0,
		mistakes = 0,
	}
end

local function setStep(session, step)
	session.step = step
	session.stepStartedAt = os.clock()
end

local function secondsIn(session)
	return math.round((os.clock() - session.stepStartedAt) * 10) / 10
end

-- Announces the reward to the host game. Returns the reward, or nil if it was already given.
local function grantReward(player)
	if rewardedUserIds[player.UserId] then
		return nil
	end
	rewardedUserIds[player.UserId] = true

	local hostListening = Campaign.RewardGranted:HasConnections()
	if not hostListening then
		warn("[FindJob] Nothing is connected to Campaign.RewardGranted, the reward goes nowhere")
	end

	local reward = table.clone(Config.Reward)
	Tracker.track(player, "RewardGranted", { reward = reward.Id, amount = reward.Amount, hostListening = hostListening })
	Campaign.RewardGranted:Fire(player, reward)
	return reward
end

-- Wraps a client -> server remote: drops requests while disabled or spammed
local function onRequest(remote, handler)
	remote.OnServerEvent:Connect(function(player, ...)
		if enabled then
			handler(player, ...)
		end
	end)
end

-- Proximity prompt handlers -------------------------------------------------

local function onRecruiterTriggered(player)
	if sessions[player] then
		return -- already in the middle of the campaign
	end

	sessions[player] = newSession()
	Tracker.track(player, "ConversationStarted", { returning = rewardedUserIds[player.UserId] == true })
	Remotes.OpenDialogue:FireClient(player)
	Campaign.ConversationStarted:Fire(player)
end

local function onStationTriggered(player, fieldId)
	local session = sessions[player]
	if not session or session.step ~= Step.GoingToStation or session.fieldId ~= fieldId then
		return
	end

	local missionId = Config.Fields[fieldId].MissionId
	Tracker.track(player, "MissionStarted", { field = fieldId, secondsToStation = secondsIn(session) })
	session.missionId = missionId
	session.missionStep = 1
	setStep(session, Step.InMission)
	Remotes.MissionStarted:FireClient(player, missionId, Missions[missionId].buildPuzzle())
	Campaign.MissionStarted:Fire(player, fieldId, missionId)
end

-- Client requests ------------------------------------------------------------

-- answerIndexes = { [questionIndex] = answerIndex }, seconds = { [questionIndex] = number } (only for tracking)
local function onSubmitAnswers(player, answerIndexes, seconds)
	local session = sessions[player]
	if not session or session.step ~= Step.Talking or not Classifier.isValid(answerIndexes) then
		return
	end

	local fieldId, scores = Classifier.classify(answerIndexes)
	local runnerUp = 0
	for otherId, score in scores do
		if otherId ~= fieldId then
			runnerUp = math.max(runnerUp, score)
		end
	end

	for questionIndex, question in Config.Questions do
		local answerIndex = answerIndexes[questionIndex]
		local thinking = typeof(seconds) == "table" and seconds[questionIndex]
		Tracker.track(player, "QuestionAnswered", {
			question = questionIndex,
			answer = answerIndex,
			answerText = question.Answers[answerIndex].Text,
			seconds = if typeof(thinking) == "number" then math.clamp(thinking, 0, 600) else nil,
		})
	end

	session.fieldId = fieldId
	session.margin = scores[fieldId] - runnerUp
	Tracker.track(player, "Classified", { field = fieldId, scores = scores, margin = session.margin })

	setStep(session, Step.GoingToStation)
	Remotes.FieldAssigned:FireClient(player, fieldId)
end

-- Missions are a few steps (exercises / papers); each answer is checked on its own
local function onSubmitMission(player, step, answer)
	local session = sessions[player]
	if not session or session.step ~= Step.InMission or step ~= session.missionStep then
		return
	end
	local mission = Missions[session.missionId]
	local result = mission.validateStep(step, answer)
	if not result then
		Tracker.track(player, "SubmissionRejected", { field = session.fieldId, reason = "malformed" })
		return
	end

	session.attempts += 1
	session.mistakes += result.mistakes
	Tracker.track(player, "MissionAttempt", {
		field = session.fieldId,
		step = step,
		attempt = session.attempts,
		mistakes = result.mistakes,
		falseTicks = result.falseTicks,
		falseCrosses = result.falseCrosses,
		seconds = secondsIn(session),
	})

	result.step = step
	if result.correct then
		session.missionStep += 1
		result.done = session.missionStep > mission.stepCount
	end

	if result.done then
		Tracker.track(player, "MissionCompleted", {
			field = session.fieldId,
			attempts = session.attempts,
			totalMistakes = session.mistakes,
			perfect = session.mistakes == 0,
			seconds = secondsIn(session),
		})
		setStep(session, Step.FitCheck)
		result.reward = grantReward(player)
		Campaign.MissionCompleted:Fire(player, session.fieldId)
	end
	Remotes.MissionResult:FireClient(player, result)
end

-- Was the field we picked actually right? Combines what the player says with how
-- sure the questions were and how well they did at the job.
local function matchVerdict(session, agreed)
	if agreed then
		return if session.mistakes == 0 then "confirmed" else "likely"
	end
	return if session.margin <= 1 then "unsure_questions" else "mismatch"
end

local function onSubmitFitFeedback(player, agreed)
	local session = sessions[player]
	if not session or session.step ~= Step.FitCheck or typeof(agreed) ~= "boolean" then
		return
	end

	Tracker.track(player, "FitFeedback", {
		field = session.fieldId,
		agreed = agreed,
		margin = session.margin,
		attempts = session.attempts,
		totalMistakes = session.mistakes,
		verdict = matchVerdict(session, agreed),
	})
	Tracker.track(player, "SessionEnded", {
		field = session.fieldId,
		completed = true,
		seconds = math.round(os.clock() - session.startedAt),
	})
	sessions[player] = nil
	Campaign.CampaignFinished:Fire(player, session.fieldId, agreed)
end

local function onRequestExit(player)
	Campaign:Exit(player)
end

local function onTrack(player, eventName, data)
	if typeof(eventName) ~= "string" or not Tracker.ClientEvents[eventName] then
		return
	end

	-- Never forward client tables as they are: keep short keys with plain values
	local clean = {}
	if typeof(data) == "table" then
		for key, value in data do
			if typeof(key) == "string" and #key <= 32 and (typeof(value) == "number" or typeof(value) == "boolean") then
				clean[key] = value
			end
		end
	end
	Tracker.track(player, eventName, clean)
end

-- Public API ----------------------------------------------------------------

function Campaign:Exit(player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil

	Tracker.track(player, "Exited", { step = session.step, seconds = math.round(os.clock() - session.startedAt) })
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

	local recruiterPrompt = World.addPrompt("Recruiter", Config.Recruiter.PromptText)
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
	-- Prompts are destroyed with the stand, so their connections go too
	World.despawn()

	self.EnabledChanged:Fire(false)
end

function Campaign:IsEnabled()
	return enabled
end

-- Called once by the Loader
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
	end)

	if Config.EnabledOnStart then
		self:Enable()
	end
end

return Campaign
