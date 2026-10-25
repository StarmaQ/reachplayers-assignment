-- Spinning dashed circle on the ground, pointing the player at a model, and optionally a
-- path of arrows on the ground leading from the player to it.
-- Everything is created locally, so each player only sees their own guide.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local COLOR = Color3.fromRGB(255, 196, 0)
local RING_RADIUS = 2.4
local DASH_COUNT = 18
local PATH_TEXTURE = "rbxassetid://77603583850118" -- white chevron (art/blender/build_ui_sprites.py)
local PATH_WIDTH = 2.2
local PATH_SPEED = 1.5 -- studs per second the arrows crawl towards the target

local Guide = {}

local folder = nil
local ring = nil
local spinner = nil
local connection = nil
local currentTarget = nil
local path = nil -- { beam, from, to }: the arrow beam and its two attachments

-- The ring is UI: rounded dashes on a SurfaceGui lying flat on the ground, so it stays crisp
-- at any distance and spins by just turning the frame
local function buildRing()
	local radius = RING_RADIUS
	local size = radius * 2 + 1

	ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Size = Vector3.new(size, 0.05, size)
	ring.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = ring

	-- Soft disc in the middle
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(radius * 2 / size, radius * 2 / size)
	disc.BackgroundColor3 = COLOR
	disc.BackgroundTransparency = 0.8
	disc.Parent = gui
	Instance.new("UICorner", disc).CornerRadius = UDim.new(0.5, 0)

	spinner = Instance.new("Frame")
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Size = UDim2.fromScale(1, 1)
	spinner.BackgroundTransparency = 1
	spinner.Parent = gui

	local dashLength = (2 * math.pi * radius / DASH_COUNT) * 0.55 / size
	for i = 1, DASH_COUNT do
		local angle = i / DASH_COUNT * math.pi * 2
		local dash = Instance.new("Frame")
		dash.AnchorPoint = Vector2.new(0.5, 0.5)
		dash.Position = UDim2.fromScale(0.5 + math.cos(angle) * radius / size, 0.5 + math.sin(angle) * radius / size)
		dash.Size = UDim2.new(dashLength, 0, 0, 22)
		dash.Rotation = math.deg(angle) + 90
		dash.BackgroundColor3 = COLOR
		dash.BorderSizePixel = 0
		dash.Parent = spinner
		Instance.new("UICorner", dash).CornerRadius = UDim.new(0.5, 0)
	end
end

-- Arrows on the ground: a Beam from the player's feet to the edge of the ring, its chevron
-- texture scrolling towards the target
local function buildPath()
	local from = Instance.new("Attachment")
	from.Name = "PathStart"
	local to = Instance.new("Attachment")
	to.Name = "PathEnd"
	to.Parent = ring

	local beam = Instance.new("Beam")
	beam.Name = "Path"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Texture = PATH_TEXTURE
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = PATH_WIDTH
	beam.TextureSpeed = PATH_SPEED / PATH_WIDTH
	beam.Width0 = PATH_WIDTH
	beam.Width1 = PATH_WIDTH
	beam.FaceCamera = false
	beam.Segments = 1
	beam.Color = ColorSequence.new(COLOR)
	beam.LightInfluence = 0
	-- Fades in near the player, so it doesn't start abruptly under their feet
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	beam.Parent = ring
	path = { beam = beam, from = from, to = to }
end

local function build()
	folder = Instance.new("Folder")
	folder.Name = "FindJobGuide"
	buildRing()
	buildPath()
end

-- Lays the path flat on the ground between the player's feet and the ring
local function updatePath(center)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		path.beam.Enabled = false
		return
	end

	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight - 0.15, 0)
	local flat = Vector3.new(center.X - feet.X, 0, center.Z - feet.Z)
	local distance = flat.Magnitude
	-- Standing in the ring: nothing left to point at
	path.beam.Enabled = distance > RING_RADIUS + 0.5
	if not path.beam.Enabled then
		return
	end

	local direction = flat.Unit
	local finish = Vector3.new(center.X, center.Y + 0.15, center.Z) - direction * RING_RADIUS
	-- Attachments' X axis points up so the beam's width lies along the ground
	local side = direction:Cross(Vector3.yAxis)
	path.from.Parent = Workspace.Terrain
	path.from.WorldCFrame = CFrame.fromMatrix(feet, Vector3.yAxis, side)
	path.to.WorldCFrame = CFrame.fromMatrix(finish, Vector3.yAxis, side)
end

-- Where the ring goes: on the ground under the model's root part (or its middle). Measured
-- once when the guide is shown, so animations (waving arms, spinning items) don't move it.
-- The box can be rotated any way (imported meshes often are), so measure its height in world space.
local function groundPoint(target)
	local cframe, size
	if target:IsA("Model") then
		cframe, size = target:GetBoundingBox()
	else
		cframe, size = target.CFrame, target.Size
	end
	local height = math.abs(cframe.RightVector.Y) * size.X
		+ math.abs(cframe.UpVector.Y) * size.Y
		+ math.abs(cframe.LookVector.Y) * size.Z
	local center = if target:IsA("Model") and target.PrimaryPart then target.PrimaryPart.Position else cframe.Position
	return Vector3.new(center.X, cframe.Position.Y - height / 2, center.Z)
end

-- showPath: also draw the arrows from the player to the target
function Guide.show(target, showPath)
	Guide.hide()
	if not target or not target:IsDescendantOf(Workspace) then
		return
	end
	if not folder then
		build()
	end

	currentTarget = target
	folder.Parent = Workspace

	local center = groundPoint(target)
	ring.CFrame = CFrame.new(center + Vector3.new(0, 0.08, 0))
	path.beam.Enabled = false

	local started = os.clock()
	connection = RunService.RenderStepped:Connect(function()
		-- Gone from the world (unloaded, streamed out): the whole folder may have moved, so
		-- check the Workspace rather than the target's own parent
		if not currentTarget:IsDescendantOf(Workspace) then
			Guide.hide()
			return
		end
		spinner.Rotation = (os.clock() - started) * 35
		if showPath then
			updatePath(center)
		end
	end)
end

function Guide.hide()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	currentTarget = nil
	if folder then
		folder.Parent = nil
		path.from.Parent = nil
	end
end

function Guide.target()
	return currentTarget
end

return Guide
