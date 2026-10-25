-- Teacher mission: mark each answer on the students' quizzes as right or wrong,
-- one paper at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FindJobCampaign").Libraries.Config)

local mission = Config.Missions.Grading

local Grading = {}

Grading.stepCount = #mission.Papers

-- What gets sent to the client: the papers without the Correct flags
function Grading.buildPuzzle()
	local papers = {}
	for i, paper in mission.Papers do
		local lines = {}
		for j, line in paper.Lines do
			lines[j] = { Id = line.Id, Question = line.Question, Answer = line.Answer }
		end
		papers[i] = { Student = paper.Student, Lines = lines }
	end
	return { brief = mission.Brief, papers = papers }
end

-- answer = { [lineId] = markedAsCorrect } for the lines of paper `step`, straight from the client.
-- Returns nil if a line is missing or isn't a boolean, otherwise
-- { correct, mistakes, feedback = { [lineId] = markWasRight }, falseTicks, falseCrosses }
function Grading.validateStep(step, answer)
	local paper = mission.Papers[step]
	if not paper or typeof(answer) ~= "table" then
		return nil
	end

	local feedback = {}
	local mistakes, falseTicks, falseCrosses = 0, 0, 0
	for _, line in paper.Lines do
		local mark = answer[line.Id]
		if typeof(mark) ~= "boolean" then
			return nil
		end
		local isCorrect = line.Correct
		feedback[line.Id] = mark == isCorrect
		if mark ~= isCorrect then
			mistakes += 1
			-- A wrong answer ticked as right is a worse teaching mistake than the opposite
			if mark then
				falseTicks += 1
			else
				falseCrosses += 1
			end
		end
	end

	return {
		correct = mistakes == 0,
		mistakes = mistakes,
		feedback = feedback,
		falseTicks = falseTicks,
		falseCrosses = falseCrosses,
	}
end

return Grading
