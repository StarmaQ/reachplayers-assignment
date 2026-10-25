-- Subtitle-style dialogue: one line at the bottom of the screen over a grey gradient
-- that fades out towards the top, with a typewriter effect.
--
--     local completed, skips = Dialogue.say({ "Hi!", "Second line" })
--
-- Yields until the player clicked through every line. completed is false if the
-- dialogue was closed early (X button, CloseAllUi).

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Package = script.Parent.Parent
local Config = require(Package.Libraries.Config)

local TYPEWRITER_SPEED = 45 -- characters per second

local Ui = require(script.Parent.Ui)

local Dialogue = {}

-- Puts a copy of Maya (as she stands in the world, or from Assets) in the portrait
local function fillPortrait(viewport)
	local folder = Workspace:FindFirstChild(Config.World.FolderName)
	local template = folder and folder:FindFirstChild("Recruiter")
		or Package.Assets:FindFirstChild("Recruiter")
	if not template then
		return nil
	end
	local model = template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BillboardGui") then
			descendant:Destroy() -- her name tag doesn't belong in the portrait
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = viewport.WorldModel

	local head = model:FindFirstChild("Head")
	local focus = head.Position - Vector3.new(0, 0.5, 0)
	-- Cameras don't replicate, so this one can't come with the template
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(focus + head.CFrame.LookVector * 7, focus)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return model
end

local function build()
	local frame = Ui.template("Dialogue")
	local line = frame.Line
	line.Speaker.Text = Config.Recruiter.DisplayName:upper()
	return frame, line, line.Body, line.Hint, fillPortrait(line.Portrait.Viewport)
end

function Dialogue.say(lines)
	local frame, line, body, hint, portrait = build()
	local portraitPivot = portrait and portrait:GetPivot()
	local thread = coroutine.running()
	local connections = {}
	local completed = false
	local skips = 0
	local lineIndex = 0
	local typing = false

	-- Little nudge on the "continue" arrow so players know they can click
	local nudge = TweenService:Create(hint, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(1, 5, 1, 0),
	})
	nudge:Play()

	local function showLine()
		body.Text = lines[lineIndex]
		body.MaxVisibleGraphemes = 0
		hint.Visible = false
		typing = true

		local length = utf8.len(body.ContentText) or #body.ContentText
		local startedAt = os.clock()
		task.spawn(function()
			while typing and frame.Parent do
				local shown = math.floor((os.clock() - startedAt) * TYPEWRITER_SPEED)
				body.MaxVisibleGraphemes = shown
				if portrait then
					-- Little bounce while she talks
					portrait:PivotTo(portraitPivot * CFrame.new(0, math.abs(math.sin(os.clock() * 14)) * 0.06, 0))
				end
				if shown >= length then
					break
				end
				task.wait()
			end
			typing = false
			body.MaxVisibleGraphemes = -1
			hint.Visible = true
			if portrait then
				portrait:PivotTo(portraitPivot)
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

	table.insert(connections, line.Activated:Connect(advance))
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
		nudge:Cancel()
		for _, connection in connections do
			connection:Disconnect()
		end
		task.spawn(thread, completed, skips)
	end)

	-- Slide up from the bottom
	local resting = frame.Position
	frame.Position = resting + UDim2.fromOffset(0, 200)
	Ui.tween(frame, 0.3, { Position = resting })
	advance()

	return coroutine.yield()
end

return Dialogue
