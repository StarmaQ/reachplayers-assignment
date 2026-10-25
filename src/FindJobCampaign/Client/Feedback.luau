-- Small feedback pieces around the missions.
--
--     Feedback.toast("Head to the computer!")         -- short message at the top, doesn't block
--     Feedback.reveal("Software Engineer")            -- "Your match" card, yields ~2.5s, nil if closed
--     local agreed = Feedback.ask(question, yes, no)  -- yields, true / false / nil if closed

local Ui = require(script.Parent.Ui)

local Feedback = {}

function Feedback.toast(text, color)
	local toast = Ui.template("Toast")
	toast.Label.Text = text
	if color then
		toast.ImageColor3 = color
	end
	local shown = toast.Position
	local hidden = UDim2.new(shown.X.Scale, shown.X.Offset, 0, -90)
	toast.Position = hidden
	toast.Parent = Ui.root()
	Ui.tween(toast, 0.4, { Position = UDim2.new(shown.X.Scale, shown.X.Offset, 0, 64) }, Enum.EasingStyle.Back)
	task.delay(2.8, function()
		Ui.tween(toast, 0.25, { Position = hidden }).Completed:Wait()
		toast:Destroy()
	end)
end

-- Waits until the window closes; resolve() closes it with a value
local function waitForCard(window)
	local thread = coroutine.running()
	local result = nil
	Ui.open(window, function()
		task.spawn(thread, result)
	end)
	Ui.popIn(window)
	return function(value)
		result = value
		Ui.close(window)
	end, coroutine.yield
end

function Feedback.reveal(fieldName)
	local window = Ui.template("RevealCard")
	local name = window.Panel.Field
	name.Text = fieldName
	-- Stamp effect on the field name
	local resting = name.Rotation
	name.Rotation = resting - 9
	name.TextTransparency = 1
	Ui.tween(name, 0.4, { Rotation = resting, TextTransparency = 0 }, Enum.EasingStyle.Back)

	local resolve, waitClosed = waitForCard(window)
	task.delay(2.6, resolve, true)
	return waitClosed()
end

function Feedback.ask(question, yesText, noText)
	local window = Ui.template("AskCard")
	local panel = window.Panel
	panel.Question.Text = question
	panel.Yes.Face.Label.Text = yesText
	panel.No.Face.Label.Text = noText

	local resolve, waitClosed = waitForCard(window)
	panel.Yes.Activated:Connect(function()
		resolve(true)
	end)
	panel.No.Activated:Connect(function()
		resolve(false)
	end)
	return waitClosed()
end

return Feedback
