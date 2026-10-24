--[[
	FindJob campaign, client side.

		local Campaign = require(ReplicatedStorage.FindJobCampaign.Client)

		Campaign.CloseAllUi:Fire()               -- host can close every campaign UI (e.g. on death / round end)
		Campaign.CloseAllUi:Connect(fn)          -- or react when the campaign closes its UI
		Campaign.UiOpened:Connect(fn)            -- hide the host HUD while the campaign is on screen
		Campaign.UiClosed:Connect(fn)
		Campaign.RewardReceived:Connect(fn)      -- (reward) show a host-styled popup if wanted

		Campaign:Exit()                          -- leave the campaign and go back to the normal game
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FindJobCampaign")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Ui = require(script.Ui)
local Guide = require(script.Guide)
local Recruiter = require(script.Recruiter)
local Dialogue = require(script.Dialogue)
local Clipboard = require(script.Clipboard)
local CodingGame = require(script.CodingGame)
local GradingGame = require(script.GradingGame)
local Feedback = require(script.Feedback)

local Campaign = {}

Campaign.CloseAllUi = Signal.new()
Campaign.UiOpened = Signal.new()
Campaign.UiClosed = Signal.new()
Campaign.RewardReceived = Signal.new() -- (reward)

local MissionGames = {
	Coding = CodingGame,
	Grading = GradingGame,
}

local started = false

local function findStation(fieldId)
	local container = Workspace:FindFirstChild("FindJobCampaign")
	return container and container:FindFirstChild(Config.Fields[fieldId].StationName, true)
end

function Campaign:Exit()
	Remotes.RequestExit:FireServer()
	self.CloseAllUi:Fire()
end

-- Called once by FindJobCampaignLoader
function Campaign:Start()
	if started then
		return
	end
	started = true

	self.CloseAllUi:Connect(function()
		Ui.closeAll()
		Guide.hide()
		Recruiter.setBusy(false)
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

	Recruiter.start()
	Recruiter.Seen:Connect(function(distance)
		-- TODO: Remotes.Track:FireServer("NpcSeen", { distance = distance })
	end)

	Remotes.CloseAll.OnClientEvent:Connect(function()
		self.CloseAllUi:Fire()
	end)

	--[[
		TODO: the flow below is yours to wire. Every UI call that waits for the player
		yields and returns nil/false if the player closed it, so bail out in that case.

		OpenDialogue      -> Recruiter.setBusy(true)
		                     Dialogue.say(Config.Recruiter.Greeting, "Wave")
		                     local answers, seconds = Clipboard.ask(Config.Questions)
		                     Remotes.SubmitAnswers:FireServer(answers)

		FieldAssigned     -> Feedback.reveal(Config.Fields[fieldId].DisplayName)
		                     Dialogue.say(Config.Fields[fieldId].Reveal, "Cheer")
		                     Guide.show(findStation(fieldId))

		MissionStarted    -> Guide.hide()
		                     MissionGames[missionId].open(puzzle, function(submission)
		                         Remotes.SubmitMission:FireServer(submission)
		                     end)

		MissionResult     -> MissionGames[missionId].showResult(result)
		                     on success: Feedback.reward(Config.Reward), self.RewardReceived:Fire(...)
		                                 local agreed = Feedback.ask(Config.FitCheck.Question, Config.FitCheck.Yes, Config.FitCheck.No)
		                                 Remotes.SubmitFitFeedback:FireServer(agreed)
		                                 Recruiter.setBusy(false)
	]]
	Remotes.OpenDialogue.OnClientEvent:Connect(function() end)
	Remotes.FieldAssigned.OnClientEvent:Connect(function(fieldId) end)
	Remotes.MissionStarted.OnClientEvent:Connect(function(missionId, puzzle) end)
	Remotes.MissionResult.OnClientEvent:Connect(function(result) end)
end

return Campaign
