-- Turns the player's answers into a field. Pure logic, driven entirely by Config.Questions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.FindJobCampaign.Config)

local Classifier = {}

-- Returns true if answerIndexes has exactly one valid answer per question
function Classifier.isValid(answerIndexes)
	if typeof(answerIndexes) ~= "table" then
		return false
	end

	for questionIndex, question in Config.Questions do
		local answerIndex = answerIndexes[questionIndex]
		if typeof(answerIndex) ~= "number" or not question.Answers[answerIndex] then
			return false
		end
	end
	return #answerIndexes == #Config.Questions
end

-- Expects answers already checked with isValid.
-- Returns the winning field id, plus the scores so tracking can see how close it was.
function Classifier.classify(answerIndexes)
	local scores = {}
	for fieldId in Config.Fields do
		scores[fieldId] = 0
	end

	for questionIndex, question in Config.Questions do
		local answer = question.Answers[answerIndexes[questionIndex]]
		for fieldId, points in answer.Scores do
			scores[fieldId] += points
		end
	end

	local bestField = Config.TieBreakField
	for fieldId, score in scores do
		if score > scores[bestField] then
			bestField = fieldId
		end
	end

	return bestField, scores
end

return Classifier
