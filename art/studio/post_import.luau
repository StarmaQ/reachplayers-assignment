--[[
	Run once in the Studio command bar after inserting the uploaded building
	(art/upload.py prints its asset id) or importing art/export/FindJob.fbx.

	Turns the imported meshes into ReplicatedStorage.FindJobCampaign.Assets.Building:
	fixes scale, colors and materials by name, sets collisions, groups the two
	stations into their own models and adds the recruiter spot + a ceiling light.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Must match build_findjob.py
local FLOOR_WIDTH = 28
local FLOOR_THICKNESS = 0.4

local LOOKS = {
	-- name prefix = { color, material, collide }
	Building_Floor = { Color3.fromRGB(185, 138, 94), Enum.Material.WoodPlanks, true },
	Building_Wall = { Color3.fromRGB(245, 235, 222), Enum.Material.SmoothPlastic, true },
	Building_Window = { Color3.fromRGB(168, 216, 255), Enum.Material.Glass, true },
	Building_DoorTrim = { Color3.fromRGB(255, 196, 0), Enum.Material.SmoothPlastic, true },
	Building_RoofTrim = { Color3.fromRGB(47, 111, 237), Enum.Material.SmoothPlastic, true },
	Building_Roof = { Color3.fromRGB(58, 63, 75), Enum.Material.Concrete, true },
	Building_Awning = { Color3.fromRGB(47, 111, 237), Enum.Material.Fabric, true },
	Building_SignPosts = { Color3.fromRGB(58, 63, 75), Enum.Material.Metal, true },
	Building_SignBoard = { Color3.fromRGB(47, 111, 237), Enum.Material.SmoothPlastic, true },
	Building_SignText = { Color3.fromRGB(255, 255, 255), Enum.Material.Neon, false },
	Building_KioskTop = { Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, true },
	Building_Kiosk = { Color3.fromRGB(47, 111, 237), Enum.Material.SmoothPlastic, true },
	Building_PlantPot = { Color3.fromRGB(192, 98, 63), Enum.Material.Slate, true },
	Building_PlantLeaves = { Color3.fromRGB(62, 142, 65), Enum.Material.Grass, false },
	Building_ChalkboardFrame = { Color3.fromRGB(139, 106, 74), Enum.Material.Wood, true },
	Building_ChalkText = { Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, false },
	Building_Chalkboard = { Color3.fromRGB(47, 93, 70), Enum.Material.Slate, true },

	Computer_Desk = { Color3.fromRGB(139, 106, 74), Enum.Material.Wood, true },
	Computer_Monitor = { Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic, true },
	Computer_Screen = { Color3.fromRGB(77, 163, 255), Enum.Material.Neon, false },
	Computer_Keyboard = { Color3.fromRGB(42, 42, 48), Enum.Material.SmoothPlastic, false },
	Computer_Chair = { Color3.fromRGB(47, 59, 102), Enum.Material.Fabric, true },

	TeacherDesk_Desk = { Color3.fromRGB(139, 106, 74), Enum.Material.Wood, true },
	TeacherDesk_Papers = { Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false },
	TeacherDesk_Apple = { Color3.fromRGB(211, 47, 47), Enum.Material.SmoothPlastic, false },
	TeacherDesk_Pencil = { Color3.fromRGB(255, 196, 0), Enum.Material.SmoothPlastic, false },
	TeacherDesk_Chair = { Color3.fromRGB(47, 59, 102), Enum.Material.Fabric, true },
}

-- Longest prefix wins, so Building_RoofTrim doesn't match Building_Roof
local function lookFor(name)
	local best, bestLength = nil, 0
	for prefix, look in LOOKS do
		if name:sub(1, #prefix) == prefix and #prefix > bestLength then
			best, bestLength = look, #prefix
		end
	end
	return best
end

-- Find the import: the model that contains Building_Floor
local floor = nil
for _, descendant in workspace:GetDescendants() do
	if descendant.Name == "Building_Floor" and descendant:IsA("MeshPart") then
		floor = descendant
		break
	end
end
assert(floor, "Import art/export/FindJob.fbx into the workspace first")

local imported = floor:FindFirstAncestorWhichIsA("Model")

-- Imported meshes carry their own axis conversions, so rebuild the design's frame from the
-- geometry instead: origin at the floor's bottom center, +Z pointing out the front door.
local scale = FLOOR_WIDTH / floor.Size.X
local back = imported:FindFirstChild("Building_WallBack", true).Position
local front = imported:FindFirstChild("Building_WallFrontTop", true).Position
local forward = Vector3.new(front.X - back.X, 0, front.Z - back.Z).Unit
local origin = floor.Position - Vector3.new(0, FLOOR_THICKNESS * scale / 2, 0)
local designFrame = CFrame.lookAt(origin, origin - forward)

local parts = {}
for _, descendant in imported:GetDescendants() do
	if descendant:IsA("MeshPart") then
		table.insert(parts, descendant)
	end
end

local building = Instance.new("Model")
building.Name = "Building"
local computer = Instance.new("Model")
computer.Name = "Computer"
computer.Parent = building
local teacherDesk = Instance.new("Model")
teacherDesk.Name = "TeacherDesk"
teacherDesk.Parent = building

for _, part in parts do
	part.Anchored = true
	local look = lookFor(part.Name)
	if look then
		part.Color, part.Material, part.CanCollide = look[1], look[2], look[3]
	else
		warn("No look for " .. part.Name)
	end
	part.CanQuery = part.CanCollide
	part.CastShadow = part.Material ~= Enum.Material.Neon
	-- Walls with window holes need real collision, everything else is box-ish
	part.CollisionFidelity = if part.Name:find("WallFront")
		then Enum.CollisionFidelity.PreciseConvexDecomposition
		else Enum.CollisionFidelity.Box
	if part.Material == Enum.Material.Glass then
		part.Transparency = 0.5
	end

	if part.Name:sub(1, 9) == "Computer_" then
		part.Parent = computer
	elseif part.Name:sub(1, 12) == "TeacherDesk_" then
		part.Parent = teacherDesk
	else
		part.Parent = building
	end
end
imported:Destroy()

computer.PrimaryPart = computer.Computer_Monitor
teacherDesk.PrimaryPart = teacherDesk.TeacherDesk_Desk

-- No PrimaryPart: the pivot stays at the floor's bottom center, where Config.World.Origin puts it
building.WorldPivot = designFrame
if math.abs(scale - 1) > 0.01 then
	building:ScaleTo(scale) -- import used other units than studs
end

local function localPart(name, size, offset)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = building.WorldPivot * offset
	part.Parent = building
	return part
end

-- Behind the kiosk, facing out of the building (+Z)
localPart("RecruiterSpot", Vector3.new(2, 0.2, 2), CFrame.new(-8, 0.1, 12.3) * CFrame.Angles(0, math.pi, 0))

-- Some code on the computer screen. A separate display part keeps the text upright
-- whatever axes the screen mesh came in with; its Back face looks into the room.
local display = localPart("ScreenDisplay", Vector3.new(3.5, 2.1, 0.05), CFrame.new(-9, 6, -8.68))
display.Parent = computer
local screenGui = Instance.new("SurfaceGui")
screenGui.Face = Enum.NormalId.Back
screenGui.PixelsPerStud = 60
screenGui.LightInfluence = 0
screenGui.Parent = display
local code = Instance.new("TextLabel")
code.Size = UDim2.fromScale(1, 1)
code.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
code.TextColor3 = Color3.fromRGB(120, 230, 140)
code.Font = Enum.Font.Code
code.TextSize = 16
code.TextXAlignment = Enum.TextXAlignment.Left
code.TextYAlignment = Enum.TextYAlignment.Top
code.Text = " -- login.lua
 function login(user)
   ???
 end

 > 1 bug found"
code.Parent = screenGui

local light = localPart("CeilingLight", Vector3.one, CFrame.new(0, 11, 0))
local pointLight = Instance.new("PointLight")
pointLight.Range = 30
pointLight.Brightness = 1.2
pointLight.Color = Color3.fromRGB(255, 244, 225)
pointLight.Parent = light

local assets = ReplicatedStorage.FindJobCampaign.Assets
local old = assets:FindFirstChild("Building")
if old then
	old:Destroy()
end
building:PivotTo(CFrame.new())
building.Parent = assets

print("Building ready:", #building:GetDescendants(), "instances")
