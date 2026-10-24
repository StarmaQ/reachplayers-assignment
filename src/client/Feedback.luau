-- Small feedback pieces around the missions.
--
--     Feedback.toast("Head to the computer!")         -- short message at the top, doesn't block
--     Feedback.reveal("Software Engineer")            -- "Your match" card, yields ~2.5s
--     Feedback.reward(reward)                         -- reward card, yields until collected
--     local agreed = Feedback.ask(question, yes, no)  -- yields, true / false / nil if closed

local Ui = require(script.Parent.Ui)

local Feedback = {}

function Feedback.toast(text, color)
	local toast = Ui.new("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.fromOffset(460, 52),
		BackgroundColor3 = color or Ui.Theme.Brand,
		Text = text,
		Font = Ui.Theme.Font,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 30,
		Parent = Ui.root(),
	}, { Ui.corner(26), Ui.padding(10) })

	Ui.tween(toast, 0.35, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		Ui.tween(toast, 0.25, { Position = UDim2.new(0.5, 0, 0, -80) }).Completed:Wait()
		toast:Destroy()
	end)
end

local function card(height)
	return Ui.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(440, height),
		BackgroundColor3 = Ui.Theme.Panel,
	}, { Ui.corner(20), Ui.stroke(Ui.Theme.Brand, 4) })
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
	local window = card(200)
	Ui.label({
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "YOUR MATCH",
		Font = Ui.Theme.Font,
		TextColor3 = Ui.Theme.Brand,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 22,
		Parent = window,
	})
	local name = Ui.label({
		Position = UDim2.fromOffset(20, 72),
		Size = UDim2.new(1, -40, 0, 70),
		Text = fieldName,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 48,
		Parent = window,
	})
	-- Stamp effect on the field name
	name.Rotation = -12
	name.TextTransparency = 1
	Ui.tween(name, 0.4, { Rotation = -3, TextTransparency = 0 }, Enum.EasingStyle.Back)

	local resolve, waitClosed = waitForCard(window)
	task.delay(2.5, resolve)
	return waitClosed()
end

function Feedback.reward(reward)
	local window = card(260)
	Ui.label({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 34),
		Text = "Shift complete!",
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 32,
		Parent = window,
	})
	local amount = Ui.label({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 70),
		Text = reward.DisplayText,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Ui.Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 56,
		Parent = window,
	})
	Ui.new("UIStroke", { Color = Color3.fromRGB(120, 80, 0), Thickness = 3, Parent = amount })

	local collect = Ui.button("Collect", Ui.Theme.Good, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(200, 54),
		Parent = window,
	})

	local resolve, waitClosed = waitForCard(window)
	collect.Activated:Connect(function()
		resolve(true)
	end)
	return waitClosed()
end

function Feedback.ask(question, yesText, noText)
	local window = card(230)
	Ui.label({
		Position = UDim2.fromOffset(24, 28),
		Size = UDim2.new(1, -48, 0, 70),
		Text = question,
		Font = Ui.Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 28,
		Parent = window,
	})
	local yes = Ui.button(yesText, Ui.Theme.Good, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.new(0.5, -32, 0, 56),
		Parent = window,
	})
	local no = Ui.button(noText, Color3.fromRGB(120, 126, 145), {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.new(0.5, -32, 0, 56),
		Parent = window,
	})

	local resolve, waitClosed = waitForCard(window)
	yes.Activated:Connect(function()
		resolve(true)
	end)
	no.Activated:Connect(function()
		resolve(false)
	end)
	return waitClosed()
end

return Feedback
