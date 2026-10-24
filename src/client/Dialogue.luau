-- Dialogue box at the bottom of the screen with a typewriter effect, and the
-- recruiter talking in a viewport on the right.
--
--     local completed, skips = Dialogue.say({ "Hi!", "Second line" }, "Wave")
--
-- Yields until the player clicked through every line. completed is false if the
-- dialogue was closed early (X button, CloseAllUi).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("FindJobCampaign")
local Config = require(Shared.Config)

local Ui = require(script.Parent.Ui)

local Dialogue = {}

local function buildViewport(parent)
	local viewport = Ui.new("ViewportFrame", {
		Name = "Portrait",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Color3.fromRGB(214, 228, 255),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	}, { Ui.corner(16), Ui.stroke(Ui.Theme.Brand, 3) })

	local world = Ui.new("WorldModel", { Parent = viewport })
	local template = Shared.Assets:FindFirstChild(Config.World.RecruiterName)
	if not template then
		return viewport, nil
	end

	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = world

	-- Frame the head and shoulders
	local head = model:FindFirstChild("Head")
	local focus = head.Position - Vector3.new(0, 0.4, 0)
	local camera = Ui.new("Camera", {
		FieldOfView = 30,
		CFrame = CFrame.lookAt(focus + head.CFrame.LookVector * 7 + Vector3.new(0, 0.3, 0), focus),
		Parent = viewport,
	})
	viewport.CurrentCamera = camera
	return viewport, model
end

local function playOn(model, animationName)
	local animator = model and model:FindFirstChildWhichIsA("Animator", true)
	local id = Config.Recruiter.Animations[animationName]
	if not animator or not id then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	animator:LoadAnimation(animation):Play(0.2)
end

local function build()
	local frame = Ui.new("Frame", {
		Name = "Dialogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.7, 0, 0, 180),
		BackgroundTransparency = 1,
	}, { Ui.new("UISizeConstraint", { MaxSize = Vector2.new(980, 180) }) })

	local panel = Ui.new("TextButton", {
		Name = "Panel",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, -196, 1, 0),
		BackgroundColor3 = Ui.Theme.Panel,
		Parent = frame,
	}, { Ui.corner(16), Ui.stroke(Ui.Theme.Brand, 3) })

	Ui.new("TextLabel", {
		Name = "NameTag",
		Position = UDim2.fromOffset(18, -18),
		Size = UDim2.fromOffset(230, 36),
		BackgroundColor3 = Ui.Theme.Brand,
		Text = Config.Recruiter.DisplayName,
		Font = Ui.Theme.Font,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = panel,
	}, { Ui.corner(18) })

	local text = Ui.label({
		Name = "Body",
		Position = UDim2.fromOffset(22, 30),
		Size = UDim2.new(1, -44, 1, -64),
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 26,
		Parent = panel,
	})

	local hint = Ui.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -10),
		Size = UDim2.fromOffset(220, 20),
		Text = "Click to continue ▸",
		TextColor3 = Ui.Theme.Brand,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Ui.Theme.Font,
		MaxTextSize = 16,
		Visible = false,
		Parent = panel,
	})

	local _, model = buildViewport(frame)
	Ui.exitButton(frame)

	return frame, panel, text, hint, model
end

function Dialogue.say(lines, animationName)
	local frame, panel, text, hint, model = build()
	local thread = coroutine.running()
	local connections = {}
	local completed = false
	local skips = 0
	local lineIndex = 0
	local typing = false
	local basePivot = model and model:GetPivot()

	local function showLine()
		text.Text = lines[lineIndex]
		text.MaxVisibleGraphemes = 0
		hint.Visible = false
		typing = true

		local length = utf8.len(text.ContentText) or #text.ContentText
		local startedAt = os.clock()
		task.spawn(function()
			while typing and frame.Parent do
				local elapsed = os.clock() - startedAt
				local shown = math.floor(elapsed * Config.Recruiter.TypewriterSpeed)
				text.MaxVisibleGraphemes = shown
				if model then
					-- Small bounce while "talking"
					model:PivotTo(basePivot * CFrame.new(0, math.abs(math.sin(elapsed * 14)) * 0.05, 0))
				end
				if shown >= length then
					break
				end
				task.wait()
			end
			typing = false
			text.MaxVisibleGraphemes = -1
			hint.Visible = true
			if model then
				model:PivotTo(basePivot)
			end
		end)
	end

	local function advance()
		if typing then
			typing = false
			skips += 1
		elseif lineIndex < #lines then
			lineIndex += 1
			showLine()
		else
			completed = true
			Ui.close(frame)
		end
	end

	table.insert(connections, panel.Activated:Connect(advance))
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
				advance()
			end
		end)
	)

	Ui.open(frame, function()
		typing = false
		for _, connection in connections do
			connection:Disconnect()
		end
		task.spawn(thread, completed, skips)
	end)
	Ui.popIn(frame)
	playOn(model, animationName or "Talk")
	advance()

	return coroutine.yield()
end

return Dialogue
