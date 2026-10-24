-- Every RemoteEvent the campaign uses. The server creates them, clients wait for them.
-- Anything coming from the client is a request, never a fact: the server decides.

local RunService = game:GetService("RunService")

local NAMES = {
	-- Server -> Client
	"OpenDialogue", -- ()                         player triggered the recruiter's prompt
	"FieldAssigned", -- (fieldId)                 answers were classified, show the field + guide to the station
	"MissionStarted", -- (missionId, puzzle)      puzzle data WITHOUT the answers
	"MissionResult", -- (result)                  { success, mistakes, feedback, reward? }
	"CloseAll", -- ()                             server ended the campaign for this player (Exit / Disable)

	-- Client -> Server
	"SubmitAnswers", -- (answerIndexes)           { [questionIndex] = answerIndex }
	"SubmitMission", -- (submission)              coding: { blockId, ... } / grading: { [lineId] = isCorrect }
	"SubmitFitFeedback", -- (agreed)              "did this job feel like you?" after the mission
	"RequestExit", -- ()                          player closed the campaign themselves
	"Track", -- (eventName, data)                 client-only analytics (whitelisted on the server)
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = script.Parent
else
	folder = script.Parent:WaitForChild("Remotes")
end

local remotes = {}
for _, name in NAMES do
	remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return remotes
