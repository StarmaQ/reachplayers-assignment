--[[
	FindJob campaign, client side.

		local Campaign = require(ReplicatedStorage.FindJobCampaign.Client)

		Campaign.CloseAllUi:Fire()               -- host can close every campaign UI (e.g. on death / round end)
		Campaign.CloseAllUi:Connect(fn)          -- or react when the campaign closes its UI
		Campaign.UiOpened:Connect(fn)            -- hide the host HUD while the campaign is on screen
		Campaign.UiClosed:Connect(fn)

		-- Where the player is in the campaign, e.g. close the host's own menus when a mission starts
		Campaign.ConversationStarted:Connect(fn) -- () talking to Maya
		Campaign.MissionStarted:Connect(fn)      -- (fieldId, missionId) the minigame opens
		Campaign.MissionCompleted:Connect(fn)    -- (fieldId) minigame solved
		Campaign.CampaignFinished:Connect(fn)    -- (fieldId, agreed) answered the last question, all done

		Campaign:Exit()                          -- leave the campaign and go back to the normal game
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Package = script.Parent
local Config = require(Package.Libraries.Config)
local Signal = require(Package.Libraries.Signal)
local Remotes = Package.Remotes

local Ui = require(script.Ui)
local Guide = require(script.Guide)
local Recruiter = require(script.Recruiter)
local Dialogue = require(script.Dialogue)
local Clipboard = require(script.Clipboard)
local CodingGame = require(script.CodingGame)
local GradingGame = require(script.GradingGame)
local Feedback = require(script.Feedback)
local Stand = require(script.Stand)

local Moments = Recruiter.Moments

local Campaign = {}

Campaign.CloseAllUi = Signal.new()
Campaign.UiOpened = Signal.new()
Campaign.UiClosed = Signal.new()
Campaign.ConversationStarted = Signal.new() -- ()
Campaign.MissionStarted = Signal.new() -- (fieldId, missionId)
Campaign.MissionCompleted = Signal.new() -- (fieldId)
Campaign.CampaignFinished = Signal.new() -- (fieldId, agreed)

local MissionGames = {
	Coding = CodingGame,
	Grading = GradingGame,
}

-- Where this player is in the flow, only used to decide what to show.
-- The server keeps its own copy and is the one that decides anything.
local state = "Idle" -- Idle, Talking, GoingToStation, InMission
local fieldId = nil
local missionId = nil
local started = false

local function container()
	return Workspace:FindFirstChild(Config.World.FolderName)
end

local function findStation(id)
	local folder = container()
	return folder and folder:FindFirstChild(Config.Fields[id].StationName, true)
end

-- Only the prompt that makes sense right now is shown: the recruiter when idle,
-- and your own station once you know your field
local function promptShouldShow(prompt)
	if prompt:FindFirstAncestor("Recruiter") then
		return state == "Idle"
	end
	for id, field in Config.Fields do
		if prompt:FindFirstAncestor(field.StationName) then
			return state == "GoingToStation" and fieldId == id
		end
	end
	return true
end

local function refreshPrompts()
	local folder = container()
	if not folder then
		return
	end
	for _, prompt in folder:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = promptShouldShow(prompt)
		end
	end
end

local function setState(newState)
	state = newState
	Recruiter.setBusy(state ~= "Idle")
	refreshPrompts()
end

local function track(eventName, data)
	Remotes.Track:FireServer(eventName, data)
end

-- Maya plays an emote in the world while the subtitles run
local function talk(lines, animation)
	Recruiter.play(animation)
	local completed, skips = Dialogue.say(lines)
	if skips > 0 then
		track("DialogueSkipped", { lines = #lines, skips = skips })
	end
	return completed
end

-- Server -> client steps -------------------------------------------------------

local function onOpenDialogue()
	setState("Talking")
	Campaign.ConversationStarted:Fire()

	if not talk(Config.Recruiter.Greeting, Moments.Greeting) then
		return
	end
	local answers, seconds = Clipboard.ask(Config.Questions)
	if not answers then
		return
	end
	Remotes.SubmitAnswers:FireServer(answers, seconds)
end

local function onFieldAssigned(newFieldId)
	fieldId = newFieldId
	local field = Config.Fields[fieldId]

	if not Feedback.reveal(field.DisplayName) then
		return
	end
	if not talk(field.Reveal, Moments.Reveal) then
		return
	end
	Recruiter.play(Moments.SendToStation)

	setState("GoingToStation")
	Stand.highlight(fieldId)
	Guide.show(findStation(fieldId), true) -- with the arrow path
	Feedback.toast(field.Hint)
end

local function onMissionStarted(newMissionId, puzzle)
	missionId = newMissionId
	setState("InMission")
	Guide.hide()
	Campaign.MissionStarted:Fire(fieldId, missionId)

	MissionGames[missionId].open(puzzle, function(step, answer)
		Remotes.SubmitMission:FireServer(step, answer)
	end)
end

local function onMissionResult(result)
	local missionGame = MissionGames[missionId]
	missionGame.showResult(result)
	if not result.done then
		return
	end
	Campaign.MissionCompleted:Fire(fieldId)

	task.wait(1.6)
	if state ~= "InMission" then
		return -- left during the pause
	end
	missionGame.close()
	Stand.highlight(nil)
	Recruiter.play(Moments.MissionDone)

	-- The reward itself is the host game's: it hears Campaign.RewardGranted on the server
	-- and shows its own popup. The campaign moves straight on to the fit check.
	local agreed = Feedback.ask(Config.FitCheck.Question, Config.FitCheck.Yes, Config.FitCheck.No)
	if agreed == nil then
		return
	end
	Remotes.SubmitFitFeedback:FireServer(agreed)
	Recruiter.play(if agreed then Moments.FitCheckYes else Moments.FitCheckNo)
	Feedback.toast(if agreed then Config.FitCheck.ThanksYes else Config.FitCheck.ThanksNo)
	setState("Idle")
	Campaign.CampaignFinished:Fire(fieldId, agreed)
end

-- Public API ------------------------------------------------------------------

function Campaign:Exit()
	Remotes.RequestExit:FireServer()
	self.CloseAllUi:Fire()
end

-- Called once by the Start script next to this module
function Campaign:Start()
	if started then
		return
	end
	started = true

	self.CloseAllUi:Connect(function()
		Ui.closeAll()
		Guide.hide()
		Stand.highlight(nil)
		setState("Idle")
	end)
	Ui.ExitRequested:Connect(function()
		self:Exit()
	end)
	Ui.Opened:Connect(function()
		self.UiOpened:Fire()
	end)
	Ui.Closed:Connect(function()
		self.UiClosed:Fire()
	end)

	Stand.start()
	Recruiter.start()
	Recruiter.Seen:Connect(function(distance)
		track("NpcSeen", { distance = math.round(distance) })
	end)

	-- Prompts get recreated when the campaign is re-enabled, hide the ones that don't apply
	ProximityPromptService.PromptShown:Connect(function(prompt)
		local folder = container()
		if folder and prompt:IsDescendantOf(folder) and not promptShouldShow(prompt) then
			prompt.Enabled = false
		end
	end)

	Remotes.CloseAll.OnClientEvent:Connect(function()
		self.CloseAllUi:Fire()
	end)
	Remotes.OpenDialogue.OnClientEvent:Connect(onOpenDialogue)
	Remotes.FieldAssigned.OnClientEvent:Connect(onFieldAssigned)
	Remotes.MissionStarted.OnClientEvent:Connect(onMissionStarted)
	Remotes.MissionResult.OnClientEvent:Connect(onMissionResult)
end

return Campaign
