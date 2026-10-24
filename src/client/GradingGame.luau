-- Teacher minigame: go through the students' quizzes and mark every answer
-- as right or wrong, then hand them back.
--
--     GradingGame.open(puzzle, function(marks) ... end)  -- marks = { [lineId] = true/false }
--     GradingGame.showResult(result)                      -- { success, feedback = { [lineId] = bool }, message? }
--     GradingGame.close()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FindJobCampaign").Config)

local Ui = require(script.Parent.Ui)

local RED_INK = Color3.fromRGB(210, 40, 40)
local BLUE_INK = Color3.fromRGB(30, 50, 140)
local DESK = Color3.fromRGB(139, 106, 74)

-- Where things sit on the exam paper image (fractions of the image)
local FIRST_ROW_Y = 0.2
local ROW_HEIGHT = 0.1

local GradingGame = {}

local grading = nil -- state of the open game, nil when closed

local function countMarked()
	local marked, total = 0, 0
	for _, paper in grading.puzzle.papers do
		for _, line in paper.Lines do
			total += 1
			if grading.marks[line.Id] ~= nil then
				marked += 1
			end
		end
	end
	return marked, total
end

local render

local function buildRow(sheet, line, index)
	local row = Ui.new("Frame", {
		Name = line.Id,
		Position = UDim2.fromScale(0.16, FIRST_ROW_Y + (index - 1) * ROW_HEIGHT),
		Size = UDim2.fromScale(0.78, ROW_HEIGHT * 0.9),
		BackgroundColor3 = Ui.Theme.Bad,
		BackgroundTransparency = 1,
		Parent = sheet,
	}, { Ui.corner(8) })

	Ui.label({
		Name = "Answer",
		Size = UDim2.fromScale(0.5, 1),
		Text = ("%d)  %s = %s"):format(index, line.Question, line.Answer),
		Font = Ui.Theme.HandwritingFont,
		TextColor3 = BLUE_INK,
		MaxTextSize = 34,
		Parent = row,
	})

	-- The teacher's red pen mark next to the answer
	Ui.label({
		Name = "PenMark",
		Position = UDim2.fromScale(0.5, -0.1),
		Size = UDim2.fromScale(0.14, 1.2),
		Text = "",
		Font = Ui.Theme.HandwritingFont,
		TextColor3 = RED_INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = -8,
		MaxTextSize = 48,
		Parent = row,
	})

	local function markButton(name, text, isCorrect, x)
		local button = Ui.button(text, Color3.fromRGB(235, 235, 235), {
			Name = name,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(0.14, 0.8),
			TextColor3 = Ui.Theme.Ink,
			Parent = row,
		})
		button.Activated:Connect(function()
			if grading and not grading.locked then
				grading.marks[line.Id] = isCorrect
				render()
			end
		end)
		return button
	end
	markButton("Right", "✓", true, 0.68)
	markButton("Wrong", "✗", false, 0.84)

	return row
end

local function showPaper(index)
	local sheet = grading.sheet
	for _, child in sheet:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	grading.paperIndex = index
	grading.rows = {}

	local paper = grading.puzzle.papers[index]
	Ui.label({
		Name = "Header",
		Position = UDim2.fromScale(0.18, 0.055),
		Size = UDim2.fromScale(0.5, 0.08),
		Text = "Math Quiz",
		Font = Ui.Theme.HandwritingFont,
		TextColor3 = BLUE_INK,
		MaxTextSize = 40,
		Parent = sheet,
	})
	Ui.label({
		Name = "Student",
		Position = UDim2.fromScale(0.6, 0.065),
		Size = UDim2.fromScale(0.34, 0.06),
		Text = "Name: " .. paper.Student,
		Font = Ui.Theme.HandwritingFont,
		TextColor3 = BLUE_INK,
		MaxTextSize = 30,
		Parent = sheet,
	})
	Ui.label({
		Name = "Score",
		Position = UDim2.fromScale(0.62, 0.8),
		Size = UDim2.fromScale(0.3, 0.1),
		Text = "",
		Font = Ui.Theme.HandwritingFont,
		TextColor3 = RED_INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = -6,
		MaxTextSize = 56,
		Parent = sheet,
	})

	for i, line in paper.Lines do
		grading.rows[line.Id] = buildRow(sheet, line, i)
	end
	render()
end

render = function()
	local paper = grading.puzzle.papers[grading.paperIndex]
	local allMarked, rightCount = true, 0

	for _, line in paper.Lines do
		local row = grading.rows[line.Id]
		local mark = grading.marks[line.Id]
		row.PenMark.Text = if mark == true then "✓" elseif mark == false then "✗" else ""
		row.Right.BackgroundColor3 = if mark == true then Ui.Theme.Good else Color3.fromRGB(235, 235, 235)
		row.Wrong.BackgroundColor3 = if mark == false then Ui.Theme.Bad else Color3.fromRGB(235, 235, 235)
		if mark == nil then
			allMarked = false
		elseif mark then
			rightCount += 1
		end
	end
	-- Like a real teacher, write the score once the whole paper is marked
	grading.sheet.Score.Text = if allMarked then ("%d / %d"):format(rightCount, #paper.Lines) else ""

	local marked, total = countMarked()
	grading.progress.Text = ("Marked %d / %d"):format(marked, total)
	grading.pageLabel.Text = ("Paper %d of %d"):format(grading.paperIndex, #grading.puzzle.papers)

	local ready = marked == total and not grading.locked
	grading.handBack.BackgroundColor3 = if ready then Ui.Theme.Good else Color3.fromRGB(150, 150, 150)
end

local function build(puzzle)
	local window = Ui.new("Frame", {
		Name = "GradingGame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.86),
		BackgroundColor3 = DESK,
	}, {
		Ui.corner(18),
		Ui.stroke(DESK:Lerp(Color3.new(0, 0, 0), 0.35), 4),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(1000, 720) }),
	})

	local sheet = Ui.new("ImageLabel", {
		Name = "Sheet",
		Position = UDim2.fromScale(0.03, 0.04),
		Size = UDim2.fromScale(1, 0.92),
		BackgroundTransparency = 1,
		Image = Config.Images.ExamPaper,
		Parent = window,
	}, {
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 0.75, DominantAxis = Enum.DominantAxis.Height }),
	})

	local side = Ui.new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 30),
		Size = UDim2.new(0.34, 0, 1, -60),
		BackgroundColor3 = Color3.fromRGB(255, 250, 235),
		Parent = window,
	}, { Ui.corner(14), Ui.padding(16) })

	Ui.label({
		Name = "Title",
		Size = UDim2.fromScale(1, 0.12),
		Text = puzzle.title,
		Font = Ui.Theme.Font,
		MaxTextSize = 26,
		Parent = side,
	})
	Ui.label({
		Name = "Brief",
		Position = UDim2.fromScale(0, 0.13),
		Size = UDim2.fromScale(1, 0.16),
		Text = puzzle.brief,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 18,
		Parent = side,
	})

	local progress = Ui.label({
		Name = "Progress",
		Position = UDim2.fromScale(0, 0.34),
		Size = UDim2.fromScale(1, 0.07),
		Font = Ui.Theme.Font,
		TextColor3 = Ui.Theme.Brand,
		MaxTextSize = 22,
		Parent = side,
	})

	local pageLabel = Ui.label({
		Name = "Page",
		Position = UDim2.fromScale(0.2, 0.47),
		Size = UDim2.fromScale(0.6, 0.07),
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 20,
		Parent = side,
	})
	local previous = Ui.button("◀", Ui.Theme.Brand, {
		Position = UDim2.fromScale(0, 0.46),
		Size = UDim2.fromScale(0.18, 0.09),
		Parent = side,
	})
	local nextButton = Ui.button("▶", Ui.Theme.Brand, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0.46),
		Size = UDim2.fromScale(0.18, 0.09),
		Parent = side,
	})

	local feedback = Ui.label({
		Name = "Feedback",
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.14),
		Text = "",
		Font = Ui.Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 20,
		Parent = side,
	})

	local handBack = Ui.button("Hand back", Ui.Theme.Good, {
		Name = "HandBack",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.13),
		Parent = side,
	})

	Ui.exitButton(window)

	return {
		window = window,
		sheet = sheet,
		progress = progress,
		pageLabel = pageLabel,
		previous = previous,
		nextButton = nextButton,
		feedback = feedback,
		handBack = handBack,
	}
end

function GradingGame.open(puzzle, onSubmit)
	GradingGame.close()

	grading = build(puzzle)
	grading.puzzle = puzzle
	grading.marks = {}
	grading.locked = false

	grading.previous.Activated:Connect(function()
		if grading.paperIndex > 1 then
			showPaper(grading.paperIndex - 1)
		end
	end)
	grading.nextButton.Activated:Connect(function()
		if grading.paperIndex < #puzzle.papers then
			showPaper(grading.paperIndex + 1)
		end
	end)
	grading.handBack.Activated:Connect(function()
		local marked, total = countMarked()
		if grading.locked or marked < total then
			grading.feedback.Text = "Mark every answer first!"
			grading.feedback.TextColor3 = Ui.Theme.Bad
			return
		end
		grading.locked = true
		grading.feedback.Text = "Checking..."
		grading.feedback.TextColor3 = Ui.Theme.Ink
		render()
		onSubmit(table.clone(grading.marks))
	end)

	Ui.open(grading.window, function()
		grading = nil
	end)
	Ui.popIn(grading.window)
	showPaper(1)
end

function GradingGame.showResult(result)
	if not grading then
		return
	end

	if result.success then
		grading.feedback.Text = result.message or "All graded! Great job ✔"
		grading.feedback.TextColor3 = Ui.Theme.Good
		return
	end

	-- Find the wrong marks, jump to the first paper that has one, and clear them
	local wrongIds = {}
	local firstPaper = nil
	for paperIndex, paper in grading.puzzle.papers do
		for _, line in paper.Lines do
			if result.feedback and result.feedback[line.Id] == false then
				wrongIds[line.Id] = true
				firstPaper = firstPaper or paperIndex
			end
		end
	end

	local wrongCount = 0
	for _ in wrongIds do
		wrongCount += 1
	end
	grading.feedback.Text = result.message
		or ("%d mark%s need another look"):format(wrongCount, wrongCount == 1 and "" or "s")
	grading.feedback.TextColor3 = Ui.Theme.Bad
	task.spawn(Ui.shake, grading.window)

	if firstPaper and firstPaper ~= grading.paperIndex then
		showPaper(firstPaper)
	end
	for id in wrongIds do
		grading.marks[id] = nil
		local row = grading.rows[id]
		if row then
			row.BackgroundTransparency = 0.6
			Ui.tween(row, 1.5, { BackgroundTransparency = 1 })
		end
	end
	grading.locked = false
	render()
end

function GradingGame.close()
	if grading then
		Ui.close(grading.window)
	end
end

return GradingGame
