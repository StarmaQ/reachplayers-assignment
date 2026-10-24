-- Dashed circle on the ground + bouncing arrow, pointing the player at a model.
-- Everything is created locally, so each player only sees their own guide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("FindJobCampaign").Config)

local DASH_COUNT = 18

local Guide = {}

local folder = nil
local ring = nil
local arrowAnchor = nil
local connection = nil
local currentTarget = nil

local function makeDash(index)
	local radius = Config.Guide.CircleRadius
	local angle = index / DASH_COUNT * math.pi * 2
	local dashLength = (2 * math.pi * radius / DASH_COUNT) * 0.55

	local dash = Instance.new("Part")
	dash.Anchored = true
	dash.CanCollide = false
	dash.CanQuery = false
	dash.CanTouch = false
	dash.CastShadow = false
	dash.Material = Enum.Material.Neon
	dash.Color = Config.Guide.Color
	dash.Size = Vector3.new(0.35, 0.08, dashLength)
	dash.CFrame = CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0, 0)
	return dash
end

local function build()
	folder = Instance.new("Folder")
	folder.Name = "FindJobGuide"

	ring = Instance.new("Model")
	ring.Name = "Ring"
	for i = 1, DASH_COUNT do
		makeDash(i).Parent = ring
	end
	ring.WorldPivot = CFrame.new()
	ring.Parent = folder

	-- The arrow is a billboard so it reads from any angle and through walls
	arrowAnchor = Instance.new("Part")
	arrowAnchor.Name = "ArrowAnchor"
	arrowAnchor.Anchored = true
	arrowAnchor.CanCollide = false
	arrowAnchor.CanQuery = false
	arrowAnchor.Transparency = 1
	arrowAnchor.Size = Vector3.one * 0.2
	arrowAnchor.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(70, 70)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = arrowAnchor

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextColor3 = Config.Guide.Color
	arrow.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(60, 40, 0)
	stroke.Parent = arrow
end

-- Feet position of a model (bottom-center of its bounding box) and its height
local function measure(target)
	local cframe, size
	if target:IsA("Model") then
		cframe, size = target:GetBoundingBox()
	else
		cframe, size = target.CFrame, target.Size
	end
	local bottom = cframe.Position - Vector3.new(0, size.Y / 2, 0)
	return bottom, size.Y
end

function Guide.show(target)
	Guide.hide()
	if not target or not target.Parent then
		return
	end
	if not folder then
		build()
	end

	currentTarget = target
	folder.Parent = Workspace

	local started = os.clock()
	connection = RunService.RenderStepped:Connect(function()
		if not currentTarget.Parent then
			Guide.hide()
			return
		end

		local t = os.clock() - started
		local bottom, height = measure(currentTarget)
		ring:PivotTo(CFrame.new(bottom + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, t * 0.6, 0))

		local bob = math.sin(t * Config.Guide.BobSpeed * math.pi) * 0.6
		arrowAnchor.Position = bottom + Vector3.new(0, height + Config.Guide.ArrowHeight - 4 + bob, 0)
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
	end
end

function Guide.target()
	return currentTarget
end

return Guide
