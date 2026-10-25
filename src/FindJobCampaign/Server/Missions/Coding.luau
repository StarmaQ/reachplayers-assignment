-- Software Engineer mission: a few tiny fill-the-gap exercises, checked one at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FindJobCampaign").Libraries.Config)

local mission = Config.Missions.Coding

local Coding = {}

Coding.stepCount = #mission.Exercises

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- What gets sent to the client: the exercises with their chips shuffled, no solutions
function Coding.buildPuzzle()
	local exercises = {}
	for i, exercise in mission.Exercises do
		exercises[i] = {
			goal = exercise.Goal,
			lines = exercise.Lines,
			chips = shuffled(exercise.Chips),
			hint = exercise.Hint,
			output = exercise.Output,
		}
	end
	return { exercises = exercises }
end

-- answer = { chip, chip, ... } one per gap, straight from the client.
-- Returns nil if it isn't shaped like an answer, otherwise { correct, mistakes, feedback = { [gap] = bool } }
function Coding.validateStep(step, answer)
	local exercise = mission.Exercises[step]
	local solution = exercise and exercise.Answer
	if not solution or typeof(answer) ~= "table" or #answer ~= #solution then
		return nil
	end

	local feedback = {}
	local mistakes = 0
	for gap, expected in solution do
		if typeof(answer[gap]) ~= "string" then
			return nil
		end
		feedback[gap] = answer[gap] == expected
		if not feedback[gap] then
			mistakes += 1
		end
	end

	return { correct = mistakes == 0, mistakes = mistakes, feedback = feedback }
end

return Coding
