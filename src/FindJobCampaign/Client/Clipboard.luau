-- Clipboard with the career questions, one page per question.
--
--     local answers, seconds = Clipboard.ask(Config.Questions)
--
-- answers = { [questionIndex] = answerIndex }, seconds = time spent on each question.
-- Returns nil if the clipboard was closed before the last answer.

local Ui = require(script.Parent.Ui)

local Clipboard = {}

local function buildPage(paper, question, index, total, onPick)
	local page = Ui.template("ClipboardPage")
	page.Name = "Page" .. index
	page.Progress.Text = ("Question %d of %d"):format(index, total)
	page.Question.Text = question.Text
	page.Parent = paper

	local picked = false
	for answerIndex, answer in question.Answers do
		local row = Ui.template("ClipboardAnswer")
		row.Name = "Answer" .. answerIndex
		row.LayoutOrder = answerIndex
		row.Face.Text.Text = answer.Text
		row.Parent = page.Answers

		local box = row.Face.Box
		row.Activated:Connect(function()
			if picked then
				return
			end
			picked = true
			box.Tick.Text = "✓"
			box.ImageColor3 = Ui.Theme.Brand
			Ui.popIn(box)
			row.ImageColor3 = Color3.fromRGB(205, 222, 255)
			onPick(answerIndex)
		end)
	end

	return page
end

function Clipboard.ask(questions)
	local board = Ui.template("Clipboard")
	local paper = board.Paper
	local thread = coroutine.running()
	local answers = {}
	local seconds = {}
	local finished = false

	Ui.open(board, function()
		task.spawn(thread, if finished then answers else nil, seconds)
	end)
	Ui.tween(board, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)

	local function showQuestion(index)
		local shownAt = os.clock()
		local page
		page = buildPage(paper, questions[index], index, #questions, function(answerIndex)
			answers[index] = answerIndex
			seconds[index] = math.round((os.clock() - shownAt) * 10) / 10

			task.wait(0.4)
			if not board.Parent then
				return
			end
			Ui.tween(page, 0.25, { Position = UDim2.fromScale(-1.1, 0.08) }).Completed:Connect(function()
				page:Destroy()
			end)
			if index < #questions then
				showQuestion(index + 1)
			else
				finished = true
				task.wait(0.25)
				Ui.tween(board, 0.3, { Position = UDim2.fromScale(0.5, 1.6) }).Completed:Wait()
				Ui.close(board)
			end
		end)
		if index > 1 then
			page.Position = UDim2.fromScale(1.1, 0.08)
			Ui.tween(page, 0.25, { Position = UDim2.fromScale(0, 0.08) })
		end
	end

	showQuestion(1)
	return coroutine.yield()
end

return Clipboard
