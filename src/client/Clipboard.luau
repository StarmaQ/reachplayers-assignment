-- Clipboard with the career questions, one page per question.
--
--     local answers, seconds = Clipboard.ask(Config.Questions)
--
-- answers = { [questionIndex] = answerIndex }, seconds = time spent on each question.
-- Returns nil if the clipboard was closed before the last answer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FindJobCampaign")
local Config = require(Shared.Config)

local Ui = require(script.Parent.Ui)

local Clipboard = {}

local function build()
	local board = Ui.new("ImageLabel", {
		Name = "Clipboard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromScale(1, 0.86),
		BackgroundTransparency = 1,
		Image = Config.Images.Clipboard,
	}, {
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 0.75, DominantAxis = Enum.DominantAxis.Height }),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(600, 800) }),
	})

	-- Area of the image covered by the paper sheet
	local paper = Ui.new("Frame", {
		Name = "Paper",
		Position = UDim2.fromScale(0.11, 0.16),
		Size = UDim2.fromScale(0.78, 0.76),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = board,
	})

	Ui.label({
		Name = "Brand",
		Size = UDim2.fromScale(1, 0.05),
		Text = "FINDJOB  ·  CAREER MATCH",
		Font = Ui.Theme.Font,
		TextColor3 = Ui.Theme.Brand,
		MaxTextSize = 18,
		Parent = paper,
	})

	Ui.exitButton(board)
	return board, paper
end

local function buildPage(paper, question, index, total, onPick)
	local page = Ui.new("Frame", {
		Name = "Page",
		Position = UDim2.fromScale(0, 0.08),
		Size = UDim2.fromScale(1, 0.92),
		BackgroundTransparency = 1,
		Parent = paper,
	})

	Ui.label({
		Name = "Progress",
		Size = UDim2.fromScale(1, 0.05),
		Text = ("Question %d of %d"):format(index, total),
		TextColor3 = Color3.fromRGB(130, 130, 140),
		MaxTextSize = 16,
		Parent = page,
	})

	Ui.label({
		Name = "Question",
		Position = UDim2.fromScale(0, 0.07),
		Size = UDim2.fromScale(1, 0.2),
		Text = question.Text,
		Font = Ui.Theme.Font,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 30,
		Parent = page,
	})

	local list = Ui.new("Frame", {
		Name = "Answers",
		Position = UDim2.fromScale(0, 0.32),
		Size = UDim2.fromScale(1, 0.66),
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local picked = false
	for answerIndex, answer in question.Answers do
		local row = Ui.new("TextButton", {
			Name = "Answer" .. answerIndex,
			LayoutOrder = answerIndex,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 0.2),
			BackgroundColor3 = Color3.fromRGB(246, 248, 255),
			Parent = list,
		}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(200, 210, 235), 2) })

		local box = Ui.new("TextLabel", {
			Name = "Box",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromScale(0.55, 0.55),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			Font = Ui.Theme.Font,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = row,
		}, { Ui.corner(6), Ui.stroke(Ui.Theme.Brand, 2) })

		Ui.label({
			Name = "Text",
			Position = UDim2.new(0.13, 0, 0.1, 0),
			Size = UDim2.new(0.84, 0, 0.8, 0),
			Text = answer.Text,
			MaxTextSize = 22,
			Parent = row,
		})

		row.MouseEnter:Connect(function()
			if not picked then
				Ui.tween(row, 0.1, { BackgroundColor3 = Color3.fromRGB(228, 236, 255) })
			end
		end)
		row.MouseLeave:Connect(function()
			if not picked then
				Ui.tween(row, 0.1, { BackgroundColor3 = Color3.fromRGB(246, 248, 255) })
			end
		end)
		row.Activated:Connect(function()
			if picked then
				return
			end
			picked = true
			box.Text = "✓"
			Ui.tween(box, 0.15, { BackgroundColor3 = Ui.Theme.Brand })
			Ui.tween(row, 0.15, { BackgroundColor3 = Color3.fromRGB(214, 228, 255) })
			onPick(answerIndex)
		end)
	end

	return page
end

function Clipboard.ask(questions)
	local board, paper = build()
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
			Ui.tween(page, 0.25, { Position = UDim2.fromScale(-1.1, 0.08) })
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
