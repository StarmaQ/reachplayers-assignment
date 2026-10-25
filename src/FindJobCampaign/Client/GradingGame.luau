-- Teacher minigame: one quiz at a time, tap a sticker to say if each answer is right or wrong.
-- When the paper is fully marked it gets checked; a correct paper gets an A+ stamp.
--
--     GradingGame.open(puzzle, function(step, marks) ... end)  -- marks = { [lineId] = true/false }
--     GradingGame.showResult(result)                         -- { step, correct, feedback = { [lineId] = bool }, done }
--     GradingGame.close()

local Ui = require(script.Parent.Ui)

local STICKER_IDLE = 0.55 -- transparency of the sticker that wasn't picked

local GradingGame = {}

local current = nil -- state of the open game, nil when closed

local function paper()
	return current.puzzle.papers[current.step]
end

local render

local function buildRow(list, line, index)
	local row = Ui.template("GradingRow")
	row.Name = line.Id
	row.LayoutOrder = index
	row.Answer.Text = ("%s = %s"):format(line.Question, line.Answer)
	row.Parent = list

	for button, isCorrect in { [row.Right] = true, [row.Wrong] = false } do
		button.Activated:Connect(function()
			if current and not current.locked then
				current.marks[line.Id] = isCorrect
				render()
				Ui.popIn(row.PenMark)
			end
		end)
	end
	return row
end

render = function()
	local allMarked = true
	for _, line in paper().Lines do
		local row = current.rows[line.Id]
		local mark = current.marks[line.Id]
		row.PenMark.Text = if mark == true then "✓" elseif mark == false then "X" else ""
		-- The sticker that wasn't picked fades back
		row.Right.ImageTransparency = if mark == false then STICKER_IDLE else 0
		row.Wrong.ImageTransparency = if mark == true then STICKER_IDLE else 0
		if mark == nil then
			allMarked = false
		end
	end

	-- The whole paper is marked: hand it in
	if allMarked and not current.locked then
		current.locked = true
		local step = current.step
		task.delay(0.45, function()
			if current and current.step == step then
				local marks = {}
				for _, line in paper().Lines do
					marks[line.Id] = current.marks[line.Id]
				end
				current.onSubmit(step, marks)
			end
		end)
	end
end

local function showPaper()
	local ui = current.ui
	for _, child in ui.list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	ui.stamp.Visible = false
	Ui.setGoal(ui.goal, current.puzzle.brief, current.step, #current.puzzle.papers)
	ui.hint.Text = ""
	ui.title.Text = paper().Student .. "'s math quiz"

	current.marks = {}
	current.rows = {}
	current.locked = false
	for index, line in paper().Lines do
		current.rows[line.Id] = buildRow(ui.list, line, index)
	end
	render()

	-- Slide the new paper in
	ui.card.Position = UDim2.fromScale(1.6, ui.cardY)
	Ui.tween(ui.card, 0.45, { Position = UDim2.fromScale(0.5, ui.cardY) }, Enum.EasingStyle.Back)
end

-- The window comes from the GradingGame template; these are the parts the game drives
local function build()
	local root = Ui.template("GradingGame")
	local window = root.Window
	local card = window.Card
	return {
		root = root,
		goal = window.Goal,
		card = card,
		cardY = card.Position.Y.Scale, -- papers slide in and out at this height
		title = card.Title,
		hint = card.Hint,
		list = card.Lines,
		stamp = card.Stamp,
	}
end

function GradingGame.open(puzzle, onSubmit)
	GradingGame.close()

	current = {
		puzzle = puzzle,
		onSubmit = onSubmit,
		step = 1,
		ui = build(),
	}
	local state = current
	Ui.open(current.ui.root, function()
		if current == state then
			current = nil
		end
	end)
	showPaper()
end

function GradingGame.showResult(result)
	if not current or result.step ~= current.step then
		return
	end
	local ui = current.ui
	local step = current.step

	if result.correct then
		-- Stamp it!
		ui.stamp.Visible = true
		ui.stamp.TextTransparency = 1
		ui.stamp.Size = UDim2.fromOffset(300, 220)
		Ui.tween(ui.stamp, 0.25, { TextTransparency = 0, Size = UDim2.fromOffset(150, 110) }, Enum.EasingStyle.Back)
		ui.hint.Text = if result.done then "All quizzes graded. Great teaching!" else "Perfect grading!"
		ui.hint.TextColor3 = Ui.Theme.Good

		if not result.done then
			task.delay(1.3, function()
				if current and current.step == step then
					Ui.tween(ui.card, 0.3, { Position = UDim2.fromScale(-0.6, ui.cardY) }).Completed:Wait()
					current.step += 1
					showPaper()
				end
			end)
		end
		return
	end

	-- Some marks were wrong: wiggle those rows and let the player try them again
	local wrong = 0
	for lineId, ok in result.feedback or {} do
		if not ok then
			wrong += 1
			local row = current.rows[lineId]
			if row then
				task.spawn(Ui.wiggle, row.Answer)
			end
		end
	end
	ui.hint.Text = if wrong == 1 then "One mark is off. Check the math again!" else "Some marks are off. Check the math again!"
	ui.hint.TextColor3 = Ui.Theme.Bad

	task.delay(0.9, function()
		if not current or current.step ~= step then
			return
		end
		for lineId, ok in result.feedback or {} do
			if not ok then
				current.marks[lineId] = nil
			end
		end
		current.locked = false
		render()
	end)
end

function GradingGame.close()
	if current then
		Ui.close(current.ui.root)
	end
end

return GradingGame
