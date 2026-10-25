-- Shared UI runtime: the campaign's ScreenGui, the window templates, and a list of open
-- windows so everything can be closed in one call.
--
-- Every window is a template in the package's Interface ScreenGui (made in Studio, see
-- art/studio/build_interface.luau). Ui.template(name) clones one and wires it up:
--   - a button with a "Face" gets the press animation, a button named "Exit" closes the campaign
--   - a "Label" next to a "Shadow" keeps the shadow's text in sync
--   - a frame with the FitToScreen attribute is scaled to fit the screen (MaxScale caps it)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Package = script.Parent.Parent
local Signal = require(Package.Libraries.Signal)

local Ui = {}

Ui.Opened = Signal.new() -- first campaign window opened
Ui.Closed = Signal.new() -- last campaign window closed
Ui.ExitRequested = Signal.new() -- player pressed an X button

Ui.Theme = {
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.GothamMedium,
	HandwritingFont = Enum.Font.PatrickHand,
	Brand = Color3.fromRGB(47, 111, 237),
	Accent = Color3.fromRGB(255, 196, 0),
	Good = Color3.fromRGB(60, 180, 90),
	Bad = Color3.fromRGB(225, 70, 70),
	Ink = Color3.fromRGB(35, 38, 48),
	Panel = Color3.fromRGB(255, 255, 255),
}

-- Rendered in Blender (art/blender/build_ui_images.py and build_ui_sprites.py) and uploaded.
-- Sprites are greyscale 9-slice images, tinted in game. Slice rects match build_ui_sprites.py.
Ui.Images = {
	Clipboard = "rbxassetid://92010944905268",
	Button = { Image = "rbxassetid://89972459529007", Slice = Rect.new(40, 40, 88, 92), Lip = 12 },
	Panel = { Image = "rbxassetid://107534440495243", Slice = Rect.new(56, 56, 104, 104) },
	Slot = { Image = "rbxassetid://83619144691969", Slice = Rect.new(36, 36, 92, 60) },
	Sticker = "rbxassetid://92548457721989",
	StickerRing = "rbxassetid://77979458497348",
}

local screenGui = nil
local windows = {} -- [frame] = onClose callback
local windowCount = 0

-- The campaign's ScreenGui in the player's PlayerGui: the Interface's settings, no templates
function Ui.root()
	if not screenGui then
		screenGui = Package:WaitForChild("Interface"):Clone()
		screenGui.Name = "FindJobCampaign"
		screenGui:ClearAllChildren()
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	return screenGui
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

-- Grows a little on hover; the face (label) sinks into the lip when pressed
local function pressFeedback(button, face)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1 })
		face.Position = UDim2.fromOffset(0, 0)
	end)
	button.MouseButton1Down:Connect(function()
		Ui.tween(scale, 0.06, { Scale = 0.97 })
		face.Position = UDim2.fromOffset(0, 3)
	end)
	button.MouseButton1Up:Connect(function()
		Ui.tween(scale, 0.1, { Scale = 1.04 })
		face.Position = UDim2.fromOffset(0, 0)
	end)
end

local function wire(gui)
	if gui:IsA("GuiButton") then
		local face = gui:FindFirstChild("Face")
		if face then
			pressFeedback(gui, face)
		end
		if gui.Name == "Exit" then
			gui.Activated:Connect(function()
				Ui.ExitRequested:Fire()
			end)
		end
	elseif gui:IsA("TextLabel") and gui.Name == "Label" then
		local shadow = gui.Parent:FindFirstChild("Shadow")
		if shadow then
			gui:GetPropertyChangedSignal("Text"):Connect(function()
				shadow.Text = gui.Text
			end)
		end
	end
	if gui:GetAttribute("FitToScreen") then
		Ui.fitToScreen(gui, gui:GetAttribute("MaxScale"))
	end
end

-- A ready-to-use copy of one of the Interface templates
function Ui.template(name)
	local copy = Package:WaitForChild("Interface"):WaitForChild(name):Clone()
	wire(copy)
	for _, descendant in copy:GetDescendants() do
		wire(descendant)
	end
	return copy
end

-- The yellow goal banner on top of a mission: new goal text, and the step tag if given
function Ui.setGoal(banner, goal, step, total)
	banner.Text.Text = goal
	banner.Step.Visible = step ~= nil
	if step then
		banner.Step.Label.Text = ("%d / %d"):format(step, total)
	end
	local pop = banner.Text.Pop
	pop.Scale = 0.85
	Ui.tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Scales a frame laid out at a fixed design size (its Size) to fit the screen, so layouts look
-- the same on a phone and on a monitor. maxScale lets it grow on big screens (default 1).
function Ui.fitToScreen(frame, maxScale)
	local designSize = Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset)
	local scale = frame:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = frame
	end
	local camera = Workspace.CurrentCamera

	local function update()
		local viewport = camera.ViewportSize
		local fit = math.min(maxScale or 1, viewport.X * 0.94 / designSize.X, viewport.Y * 0.92 / designSize.Y)
		frame:SetAttribute("FitScale", fit)
		scale.Scale = fit
	end
	update()

	local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	frame.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

-- Grows a window in from nothing
function Ui.popIn(frame)
	local scale = frame:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = frame
	end
	local target = frame:GetAttribute("FitScale") or 1
	scale.Scale = target * 0.6
	Ui.tween(scale, 0.35, { Scale = target }, Enum.EasingStyle.Back)
end

-- Shakes by rotating, which also works inside list layouts (they ignore Position)
function Ui.wiggle(gui)
	for _, angle in { -8, 8, -5, 5, 0 } do
		Ui.tween(gui, 0.05, { Rotation = angle }).Completed:Wait()
	end
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
