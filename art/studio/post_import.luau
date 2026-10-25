--[[
	Run once in the Studio command bar after inserting the uploaded stand
	(art/upload.py prints its asset id) or importing art/export/FindJob.fbx.

	Turns the imported meshes into Workspace.FindJobCampaign.Stand (replacing the old one in
	place, or at Config.World.Origin the first time).
	Mesh names come from Blender as Group_Name__palette:
		Stand_*                  solid scenery
		Decor_*                  no collision
		PcPedestal_*, ExamPedestal_*   the mission pedestals (ComputerPedestal / ExamPedestal models)
		ExamItem_*               the floating exam stack, grouped into an "Item" model inside its pedestal
		Marker_*                 replaced by invisible helper parts (recruiter spot, screens, computer spot)

	The computer floating over the programmer pedestal is the game's own model:
	put it in the workspace as "monitor02" before running this.

	The stand is modelled big in Blender and scaled down here (STAND_SCALE) so it fits a
	Roblox character: desk at waist height, pedestals at hand height.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Keep in sync with PALETTE in art/blender/build_findjob.py
local PALETTE = {
	platform = Color3.fromRGB(226, 230, 238),
	panel = Color3.fromRGB(246, 247, 250),
	frame = Color3.fromRGB(45, 49, 66),
	screenOff = Color3.fromRGB(22, 26, 40),
	blue = Color3.fromRGB(47, 111, 237),
	teal = Color3.fromRGB(46, 196, 182),
	coral = Color3.fromRGB(255, 107, 107),
	sun = Color3.fromRGB(255, 201, 60),
	carpet = Color3.fromRGB(38, 72, 160),
	leaf = Color3.fromRGB(123, 211, 137),
	leafDark = Color3.fromRGB(59, 170, 92),
	white = Color3.fromRGB(255, 255, 255),
	paper = Color3.fromRGB(252, 250, 240),
	screen = Color3.fromRGB(90, 170, 255),
	glow = Color3.fromRGB(90, 170, 255), -- trims and LED strips (plain, no neon)
	red = Color3.fromRGB(225, 50, 60),
	chrome = Color3.fromRGB(196, 204, 216),
	inlay = Color3.fromRGB(212, 218, 230),
	glass = Color3.fromRGB(170, 225, 255),
}
-- No neon on the trims: only the screens light up
local MATERIALS = {
	screen = Enum.Material.Neon,
	carpet = Enum.Material.Fabric,
	chrome = Enum.Material.Metal,
	glass = Enum.Material.Glass,
}

local STAND_SCALE = 0.72

-- The computer model and where its glass is, as fractions of its size (measured on monitor02)
local COMPUTER_NAME = "monitor02"
local COMPUTER_SCALE = 1.35
local COMPUTER_SCREEN = { width = 0.81, height = 0.64, up = 0.097, front = 0.46 }

-- Groups that become their own model, and where they go
local PEDESTALS = { PcPedestal = "ComputerPedestal", ExamPedestal = "ExamPedestal" }
local ITEMS = { ExamItem = "ExamPedestal" }

-- Must match build_findjob.py: the back wall is 34 studs wide, centered on x = 0
local WALL_WIDTH = 34
local WALL_CENTER = Vector3.new(0, 7, -8)

local imported = nil
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("MeshPart") and descendant.Name:find("^Stand_BackWall") then
		imported = descendant:FindFirstAncestorWhichIsA("Model")
		break
	end
end
assert(imported, "Insert the uploaded stand (or import art/export/FindJob.fbx) into the workspace first")

local function find(prefix)
	for _, descendant in imported:GetDescendants() do
		if descendant:IsA("MeshPart") and descendant.Name:sub(1, #prefix) == prefix then
			return descendant
		end
	end
	return nil
end

-- Imported meshes carry their own axis conversions, so rebuild the design's frame from the
-- geometry: the platform and the back wall are both centered on x = 0, so the line between
-- them is the design's Z axis. Origin = design (0, 0, 0) on the ground.
local wall = find("Stand_BackWall")
local platform = find("Stand_Platform")
local scale = WALL_WIDTH / math.max(wall.Size.X, wall.Size.Y, wall.Size.Z)
local forward = Vector3.new(platform.Position.X - wall.Position.X, 0, platform.Position.Z - wall.Position.Z).Unit
local designFrame = CFrame.lookAt(wall.Position, wall.Position - forward) * CFrame.new(-WALL_CENTER * scale)

local function helperPart(name, size, cframe, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- Screens are flat panels facing the visitors; the totems are turned towards the middle.
-- Importing bakes rotations into the mesh, so the turn is mirrored from build_findjob.py.
local SCREEN_TURN = { TotemLeft = 22, TotemRight = -22 }

-- Size of a part measured along the design's axes, whatever its mesh axes are
local function extentAlong(part, axis)
	local cframe, size = part.CFrame, part.Size
	return math.abs(cframe.RightVector:Dot(axis)) * size.X
		+ math.abs(cframe.UpVector:Dot(axis)) * size.Y
		+ math.abs(cframe.LookVector:Dot(axis)) * size.Z
end

-- A flat marker becomes a helper part whose Back face (+Z) looks at the visitors, Y up,
-- so SurfaceGuis on it are upright
local function screenHelper(name, marker, parent)
	local turn = math.rad(SCREEN_TURN[name] or 0)
	local across = extentAlong(marker, designFrame.RightVector)
	local depth = extentAlong(marker, designFrame.LookVector)
	local width = math.sqrt(across ^ 2 + depth ^ 2) -- the panel is thin, so this is its width
	local height = extentAlong(marker, designFrame.UpVector)
	local cframe = CFrame.new(marker.Position) * designFrame.Rotation * CFrame.Angles(0, turn, 0)
	return helperPart(name, Vector3.new(width, height, 0.05), cframe, parent)
end

local stand = Instance.new("Model")
stand.Name = "Stand"
local screens = Instance.new("Folder")
screens.Name = "Screens"
screens.Parent = stand

local pedestals = {}
for _, name in PEDESTALS do
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = stand
	local item = Instance.new("Model")
	item.Name = "Item"
	item.Parent = model
	pedestals[name] = model
end

local markers = {}
for _, part in imported:GetDescendants() do
	if not part:IsA("MeshPart") then
		continue
	end
	local group, rest = part.Name:match("^(%a+)_(.+)$")
	local name, paletteKey = rest:match("^(.-)__(%a+)$")
	part.Name = group .. "_" .. name

	if group == "Marker" then
		markers[name] = part
		continue
	end

	part.Anchored = true
	part.Color = PALETTE[paletteKey] or Color3.new(1, 0, 1)
	part.Material = MATERIALS[paletteKey] or Enum.Material.SmoothPlastic
	part.CanCollide = group ~= "Decor" and not ITEMS[group]
	part.CanQuery = part.CanCollide
	part.CanTouch = false
	part.CastShadow = part.Material ~= Enum.Material.Neon
	-- The platform is round, a box would add invisible corners to stand on
	part.CollisionFidelity = if part.Name == "Stand_Platform"
		then Enum.CollisionFidelity.Hull
		else Enum.CollisionFidelity.Box

	if PEDESTALS[group] then
		part.Parent = pedestals[PEDESTALS[group]]
	elseif ITEMS[group] then
		part.Parent = pedestals[ITEMS[group]].Item
	else
		part.Parent = stand
	end
end

pedestals.ComputerPedestal.PrimaryPart = pedestals.ComputerPedestal.PcPedestal_Top
pedestals.ExamPedestal.PrimaryPart = pedestals.ExamPedestal.ExamPedestal_Top

-- Markers -> helper parts
local spot = markers.RecruiterSpot
-- Faces out of the stand
helperPart(
	"RecruiterSpot",
	Vector3.new(2, 0.2, 2),
	CFrame.new(spot.Position) * designFrame.Rotation * CFrame.Angles(0, math.pi, 0),
	stand
)
helperPart("ItemSpot", Vector3.one, CFrame.new(markers.PcItemSpot.Position) * designFrame.Rotation, pedestals.ComputerPedestal)
for name, marker in markers do
	local screenName = name:match("^Screen(%a+)$")
	if screenName then
		screenHelper(screenName, marker, screens)
	end
end

imported:Destroy()

-- No PrimaryPart: the pivot stays at the design origin, where Config.World.Origin puts it
stand.WorldPivot = designFrame
stand:ScaleTo(scale * STAND_SCALE) -- scale also fixes imports that used other units than studs

-- The game's computer model floats over the programmer pedestal, screen towards the visitors
local itemSpot = pedestals.ComputerPedestal.ItemSpot
local computer = assert(workspace:FindFirstChild(COMPUTER_NAME), "Put the computer model in the workspace as " .. COMPUTER_NAME):Clone()
computer.Name = "Computer"
computer.Anchored = true
computer.CanCollide = false
computer.CanQuery = false
computer.Size *= COMPUTER_SCALE
-- Its glass is on its Front face (-Z), so LookVector points where the screen faces
-- (lifted a little so its bobbing never touches the pedestal)
local position = itemSpot.Position + Vector3.new(0, 0.35, 0)
computer.CFrame = CFrame.lookAt(position, position - itemSpot.CFrame.LookVector)
computer.Parent = pedestals.ComputerPedestal.Item
local size = computer.Size
helperPart(
	"Screen",
	Vector3.new(size.X * COMPUTER_SCREEN.width, size.Y * COMPUTER_SCREEN.height, 0.02),
	-- Helper parts show their SurfaceGui on the Back face, so turn it around to face out
	computer.CFrame * CFrame.new(0, size.Y * COMPUTER_SCREEN.up, -size.Z * COMPUTER_SCREEN.front) * CFrame.Angles(0, math.pi, 0),
	pedestals.ComputerPedestal.Item
)
itemSpot:Destroy()

-- Items spin around their own center, upright
for _, model in pedestals do
	local cframe = model.Item:GetBoundingBox()
	model.Item.WorldPivot = CFrame.new(cframe.Position) * designFrame.Rotation
end

local Config = require(ReplicatedStorage.FindJobCampaign.Config:Clone())
local folder = workspace:FindFirstChild(Config.World.FolderName)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = Config.World.FolderName
	folder.Parent = workspace
end
local old = folder:FindFirstChild("Stand")
stand:PivotTo(if old then old:GetPivot() else Config.World.Origin)
if old then
	-- The letters on the grass are their own import (place_sign.luau): keep them
	local sign = old:FindFirstChild("Sign")
	if sign then
		sign.Parent = stand
	end
	old:Destroy()
end
stand.Name = "Stand"
stand.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
stand.Parent = folder

print("Stand ready:", #stand:GetDescendants(), "instances")
