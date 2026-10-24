-- Teacher mission: mark each student answer as right or wrong.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.FindJobCampaign.Config)
local ServerConfig = require(script.Parent.Parent.ServerConfig)

local mission = Config.Missions.Grading
local answerKey = ServerConfig.Solutions.Grading

local Grading = {}

-- What gets sent to the client: the papers, no answer key
function Grading.buildPuzzle()
	return {
		title = mission.Title,
		brief = mission.Brief,
		papers = mission.Papers,
	}
end

--[[
	TODO: compare the player's marks with `answerKey`.

	submission = { [lineId] = boolean } (comes from the client, check its shape)

	Return { success = boolean, mistakes = number, feedback = { [lineId] = boolean } }
	It's worth tracking false ticks and false crosses separately.
]]
function Grading.validate(submission)
	error("Grading.validate is not implemented yet")
end

return Grading
