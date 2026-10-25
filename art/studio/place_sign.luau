--[[
	Run once in the Studio command bar after inserting the uploaded letters
	(art/blender/build_sign.py, then art/upload.py prints the asset id).

	Puts the FindJob letters on the grass at the front-left of the stand, turned towards the
	path visitors come from, as Workspace.FindJobCampaign.Stand.Sign:
		Sign
			Letter1 .. Letter7    one model per letter (pivot at its foot, for the hop effect)
				Front             the colored letter
				Back              the white outline shell
	Replaces the old sign (plinth, logo, letters) if there is one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.FindJobCampaign.Config:Clone())

-- Where the letters stand, in the stand's design units (build_findjob.py) and how they're turned
local SIGN_SPOT = Vector3.new(-18.5, 0, 28)
local SIGN_TURN = 15
local STAND_SCALE = 0.72 -- keep in sync with post_import.luau
local SIGN_SCALE = 1.25 -- letters about 4 studs tall, up to a character's shoulders

-- Keep in sync with PALETTE in art/blender/build_sign.py
local PALETTE = {
	blue = Color3.fromRGB(47, 111, 237),
	teal = Color3.fromRGB(46, 196, 182),
	coral = Color3.fromRGB(255, 107, 107),
	sun = Color3.fromRGB(255, 201, 60),
	white = Color3.fromRGB(255, 255, 255),
}

local imported = nil
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("MeshPart") and descendant.Name:find("^Letter1_Front") then
		imported = descendant:FindFirstAncestorWhichIsA("Model")
		break
	end
end
assert(imported, "Insert the uploaded sign letters into the workspace first")

local stand = workspace:FindFirstChild(Config.World.FolderName):FindFirstChild("Stand")

-- Sort the meshes into letters
local letters = {}
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") then
		local index, side, paletteKey = part.Name:match("^Letter(%d+)_(%a+)__(%a+)$")
		index = tonumber(index)
		letters[index] = letters[index] or {}
		letters[index][side] = part
		part.Color = PALETTE[paletteKey]
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CastShadow = true
		-- The shell is the solid part; the colored front sits on it
		part.CanCollide = side == "Back"
		part.CanQuery = side == "Back"
		part.CanTouch = false
		part.Name = side
	end
end

-- The import may come in turned any way: rebuild the letters' own frame from the geometry.
-- Across = reading direction, forward = from the shell to the front (towards the visitors).
local first, last = letters[1], letters[#letters]
local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z).Unit
end
local across = flat(last.Front.Position - first.Front.Position)
local forward = flat(first.Front.Position - first.Back.Position)

local low, high, bottom = math.huge, -math.huge, math.huge
for _, letter in letters do
	local back = letter.Back
	local along = back.Position:Dot(across)
	local half = math.abs(back.CFrame.RightVector:Dot(across)) * back.Size.X / 2
		+ math.abs(back.CFrame.LookVector:Dot(across)) * back.Size.Z / 2
	low = math.min(low, along - half)
	high = math.max(high, along + half)
	bottom = math.min(bottom, back.Position.Y - back.Size.Y / 2)
end
local anyPosition = first.Back.Position
local middle = anyPosition + across * ((low + high) / 2 - anyPosition:Dot(across))
local from = CFrame.fromMatrix(Vector3.new(middle.X, bottom, middle.Z), across, Vector3.yAxis, forward)

-- The stand's pivot is its design origin; its +Z points at the visitors
local to = stand:GetPivot()
	* CFrame.new(SIGN_SPOT * STAND_SCALE)
	* CFrame.Angles(0, math.rad(SIGN_TURN), 0)

-- Old sign pieces
for _, descendant in stand:GetDescendants() do
	if descendant:IsA("BasePart") and (descendant.Name:find("^Stand_Sign") or descendant.Name:find("^Decor_SignPlinth")) then
		descendant:Destroy()
	end
end
local oldSign = stand:FindFirstChild("Sign")
if oldSign then
	oldSign:Destroy()
end

local sign = Instance.new("Model")
sign.Name = "Sign"
for index, letter in letters do
	local model = Instance.new("Model")
	model.Name = "Letter" .. index
	for _, part in { letter.Back, letter.Front } do
		part.CFrame = to * from:ToObjectSpace(part.CFrame)
		part.Parent = model
	end
	model.PrimaryPart = letter.Back
	local back = letter.Back
	model.WorldPivot = CFrame.new(back.Position.X, to.Position.Y, back.Position.Z) * to.Rotation
	model.Parent = sign
end
sign.WorldPivot = to
sign:ScaleTo(SIGN_SCALE)
sign.Parent = stand
imported:Destroy()

print("Sign placed:", #sign:GetChildren(), "letters")
