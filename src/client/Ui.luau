-- Shared UI helpers: one ScreenGui for the whole campaign, small builders,
-- and a list of open windows so everything can be closed in one call.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("FindJobCampaign")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local Ui = {}

Ui.Opened = Signal.new() -- first campaign window opened
Ui.Closed = Signal.new() -- last campaign window closed
Ui.ExitRequested = Signal.new() -- player pressed an X button

Ui.Theme = Config.Ui

local screenGui = nil
local windows = {} -- [frame] = onClose callback
local windowCount = 0

function Ui.root()
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "FindJobCampaign"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 10
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	return screenGui
end

-- Ui.new("Frame", { Size = ..., Parent = ... }, { child1, child2 })
function Ui.new(className, props, children)
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

function Ui.corner(radius)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Ui.stroke(color, thickness)
	return Ui.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(pixels)
	local p = UDim.new(0, pixels)
	return Ui.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Ui.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.Theme.BodyFont,
		TextColor3 = Ui.Theme.Ink,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = Ui.new("TextLabel", defaults)
	-- Keep scaled text from getting huge on big screens
	Ui.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = label })
	return label
end

function Ui.tween(instance, seconds, props, style)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function Ui.button(text, color, props)
	local button = Ui.new("TextButton", {
		Text = text,
		Font = Ui.Theme.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color,
		AutoButtonColor = false,
	}, { Ui.corner(10), Ui.padding(8) })
	Ui.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = button })
	for key, value in props or {} do
		button[key] = value
	end

	local scale = Ui.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Ui.tween(scale, 0.06, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		Ui.tween(scale, 0.1, { Scale = 1.05 })
	end)
	return button
end

-- Round X in the top-right corner of a window
function Ui.exitButton(parent)
	local button = Ui.button("X", Ui.Theme.Bad, {
		Name = "Exit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 20,
		Parent = parent,
	})
	button.UICorner.CornerRadius = UDim.new(1, 0)
	button.Activated:Connect(function()
		Ui.ExitRequested:Fire()
	end)
	return button
end

-- Grows a window in from nothing
function Ui.popIn(frame)
	local scale = frame:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = frame })
	scale.Scale = 0.6
	Ui.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Ui.shake(frame)
	local origin = frame.Position
	for _, dx in { -10, 10, -6, 6, 0 } do
		Ui.tween(frame, 0.05, { Position = origin + UDim2.fromOffset(dx, 0) }).Completed:Wait()
	end
	frame.Position = origin
end

-- Converts an input position to the same space as AbsolutePosition (our ScreenGui ignores the topbar)
function Ui.pointer(input)
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end

function Ui.contains(guiObject, point)
	local min = guiObject.AbsolutePosition
	local max = min + guiObject.AbsoluteSize
	return point.X >= min.X and point.X <= max.X and point.Y >= min.Y and point.Y <= max.Y
end

-- Window bookkeeping ---------------------------------------------------------

-- Registers a window. onClose runs when it closes for any reason (button, CloseAllUi...).
function Ui.open(frame, onClose)
	frame.Parent = Ui.root()
	windows[frame] = onClose or false
	windowCount += 1
	if windowCount == 1 then
		Ui.Opened:Fire()
	end
end

function Ui.close(frame)
	local onClose = windows[frame]
	if onClose == nil then
		return
	end
	windows[frame] = nil
	windowCount -= 1

	if onClose then
		onClose()
	end
	frame:Destroy()
	if windowCount == 0 then
		Ui.Closed:Fire()
	end
end

function Ui.closeAll()
	for frame in windows do
		Ui.close(frame)
	end
end

return Ui
