-- Brings the stand to life on the client: live UI on every screen, spinning pedestal items,
-- and livening up the pedestal that matches the player's field.
-- Everything here is local and cosmetic; the server never sees it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Libraries = script.Parent.Parent.Libraries
local Config = require(Libraries.Config)

local Ui = require(script.Parent.Ui)

local SPIN_SPEED = 0.8 -- radians per second
local BOB_HEIGHT = 0.15
local ACTIVE_DISTANCE = 150 -- only animate when the player is this close
local SIGN_WAVE_EVERY = 6 -- seconds between two hops running through the sign letters
local SIGN_HOP_DELAY = 0.12
local SIGN_HOP_SECONDS = 0.45
local SIGN_HOP_HEIGHT = 0.8
local CODE_SNIPPETS = {
	'local job = "Programmer"',
	"coins = coins + 2",
	'print("Hello, FindJob!")',
	"if happy then smile() end",
}

local Stand = {}

local currentStand = nil
local pedestals = {} -- [fieldId] = { model, item, home, angle, speed }
local held = {} -- [item] = CFrame it is held at instead of spinning
local highlighted = nil
local animated = {} -- [frame] = function(t) called every frame while the stand is near

local white = Color3.new(1, 1, 1)
local navy = Color3.fromRGB(16, 24, 52)

-- The screens are live UI drawn on the stand's parts, built here rather than templated: they
-- follow the stand's screen parts and are mostly animation.

-- new("Frame", { Size = ..., Parent = ... }, { child1, child2 })
local function new(className, props, children)
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

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

-- Rounded tag drawn with the button sprite, like the ones in the windows
local function pill(text, color, props)
	local sheet = Ui.Images.Button
	local tag = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = sheet.Image,
		ImageColor3 = color,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = sheet.Slice,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -20, 1, -sheet.Lip * 0.5 - 6),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = Ui.Theme.Font,
		TextColor3 = white,
		Parent = tag,
	})
	for key, value in props do
		tag[key] = value
	end
	return tag
end

-- Screen helpers -------------------------------------------------------------

-- A SurfaceGui laid out at a fixed design width, whatever size the screen ends up in the world
local function surface(part, designWidth)
	local gui = new("SurfaceGui", {
		Name = "Display",
		Face = Enum.NormalId.Back, -- helper parts face the visitors with their Back face
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = designWidth / part.Size.X,
		LightInfluence = 0,
		Brightness = 1.4,
		Parent = part,
	})
	local root = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	return root
end

local function gradient(parent, from, to, rotation)
	return new("UIGradient", {
		Color = ColorSequence.new(from, to),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

local function text(parent, props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.Theme.Font,
		TextColor3 = white,
		TextScaled = true,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	defaults.Parent = parent
	return new("TextLabel", defaults)
end

local function animate(frame, update)
	animated[frame] = update
	frame.Destroying:Connect(function()
		animated[frame] = nil
	end)
end

-- Magnifying glass logo drawn with frames
local function logo(parent, size, position)
	local holder = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	new("Frame", {
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1,
		Parent = holder,
	}, { corner(size), new("UIStroke", { Color = Ui.Theme.Accent, Thickness = size * 0.1 }) })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.82, 0.82),
		Size = UDim2.fromScale(0.42, 0.12),
		Rotation = 45,
		BackgroundColor3 = Ui.Theme.Accent,
		BorderSizePixel = 0,
		Parent = holder,
	}, { corner(size) })
	return holder
end

-- Text that scrolls sideways forever, like a news ticker
local function ticker(parent, messages, props)
	local strip = new("Frame", {
		BackgroundColor3 = props.BackgroundColor3 or navy,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = props.Position,
		Size = props.Size,
		Parent = parent,
	})
	local line = "   " .. table.concat(messages, "   •   ") .. "   •"
	local labels = {}
	for i = 1, 2 do
		labels[i] = text(strip, {
			Size = UDim2.fromScale(0, 0.8),
			Position = UDim2.fromScale(0, 0.1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextScaled = false,
			TextWrapped = false,
			TextSize = props.TextSize or 28,
			TextColor3 = props.TextColor3 or white,
			Text = line,
		})
	end
	local offset = 0
	animate(strip, function(_, deltaTime)
		local width = labels[1].TextBounds.X
		if width <= 0 then
			return
		end
		offset = (offset + deltaTime * (props.Speed or 80)) % width
		labels[1].Position = UDim2.new(0, -offset, 0.1, 0)
		labels[2].Position = UDim2.new(0, width - offset, 0.1, 0)
	end)
	return strip
end

-- A light network of dots and lines, like the reference stand's wallpaper
local function network(parent, size, color, count, seed)
	local random = Random.new(seed)
	local points = {}
	for i = 1, count do
		points[i] = Vector2.new(random:NextNumber(), random:NextNumber())
	end
	for i, a in points do
		for j = i + 1, #points do
			local b = points[j]
			local delta = (b - a) * size
			if delta.Magnitude < size.X * 0.16 then
				new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2),
					Size = UDim2.fromOffset(delta.Magnitude, 2),
					Rotation = math.deg(math.atan2(delta.Y, delta.X)),
					BackgroundColor3 = color,
					BackgroundTransparency = 0.55,
					BorderSizePixel = 0,
					Parent = parent,
				})
			end
		end
		local dot = random:NextInteger(6, 14)
		local node = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(a.X, a.Y),
			Size = UDim2.fromOffset(dot, dot),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Parent = parent,
		}, { corner(dot) })
		-- Nodes gently pulse at their own pace
		local phase = random:NextNumber() * math.pi * 2
		animate(node, function(t)
			node.BackgroundTransparency = 0.25 + (math.sin(t * 1.5 + phase) + 1) * 0.25
		end)
	end
end

-- Things drifting up and fading out, forever
local function drifters(parent, glyphs, color, count, size)
	for i = 1, count do
		local label = text(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			Text = glyphs[(i - 1) % #glyphs + 1],
			TextColor3 = color,
			TextTransparency = 1,
		})
		local x = math.random()
		local speed = math.random(6, 12) / 100
		local phase = math.random()
		animate(label, function(t)
			local progress = (t * speed + phase) % 1
			label.Position = UDim2.fromScale(x + math.sin(t * 0.7 + phase * 6) * 0.02, 1.1 - progress * 1.2)
			label.TextTransparency = 0.55 + math.abs(progress - 0.5) * 0.9
			label.Rotation = math.sin(t + phase * 6) * 10
		end)
	end
end

-- The local player's own avatar as a picture, so the screens say "this could be you".
-- (ViewportFrames don't render on SurfaceGuis, avatar thumbnails do.)
local function avatarImage(parent, kind, position, size)
	local userId = math.max(Players.LocalPlayer.UserId, 1) -- Studio test players have negative ids
	local image = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Image = ("rbxthumb://type=%s&id=%d&w=420&h=420"):format(kind, userId),
		ScaleType = Enum.ScaleType.Fit,
		Parent = parent,
	})
	-- Gentle idle sway, like they're happy to be there
	local base = position
	animate(image, function(t)
		image.Position = base + UDim2.fromOffset(0, -math.abs(math.sin(t * 2.2)) * 6)
		image.Rotation = math.sin(t * 1.1) * 3
	end)
	return image
end

-- Screens --------------------------------------------------------------------

local function buildHeader(part)
	local root = surface(part, 1000)
	gradient(root, Ui.Theme.Brand, Color3.fromRGB(46, 196, 182), 0)

	logo(root, 104, UDim2.fromOffset(28, 14))
	text(root, {
		Position = UDim2.fromOffset(146, 20),
		Size = UDim2.new(0.3, 0, 0, 84),
		Text = Config.Brand,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	text(root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 14),
		Size = UDim2.new(0.48, 0, 0, 58),
		Text = Config.Screens.Headline,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	text(root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 76),
		Size = UDim2.new(0.48, 0, 0, 30),
		Text = Config.Screens.Tagline,
		TextColor3 = Ui.Theme.Accent,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	ticker(root, Config.Screens.Ticker, {
		Position = UDim2.new(0, 0, 1, -42),
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(14, 22, 52),
		TextColor3 = Ui.Theme.Accent,
		TextSize = 26,
	})

	-- A shine sweeping across now and then
	local shine = new("Frame", {
		Size = UDim2.new(0.25, 0, 1, 0),
		Position = UDim2.fromScale(-0.3, 0),
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		Parent = root,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 20,
		Parent = shine,
	})
	animate(shine, function(t)
		local cycle = (t % 5) / 1.4 -- sweep for 1.4s every 5s
		shine.Position = UDim2.fromScale(-0.3 + math.min(cycle, 1) * 1.35, 0)
	end)
end

local function buildWall(part)
	local root = surface(part, 1000)
	gradient(root, white, Color3.fromRGB(218, 234, 255), 90)
	network(root, Vector2.new(1000, 1000 * part.Size.Y / part.Size.X), Color3.fromRGB(120, 175, 235), 30, 7)
	drifters(root, { "</>", "A+", "{ }", "123", "?", "abc" }, Color3.fromRGB(90, 140, 220), 12, 64)
	text(root, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -24),
		Size = UDim2.fromOffset(380, 110),
		Text = Config.Brand,
		TextColor3 = Ui.Theme.Brand,
		TextTransparency = 0.82,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end

local function buildTotem(part, caption)
	local root = surface(part, 240)
	gradient(root, Color3.fromRGB(28, 44, 110), Ui.Theme.Brand, 90)
	drifters(root, { "o", "O", "o" }, white, 8, 30)

	text(root, {
		Position = UDim2.new(0.08, 0, 0, 20),
		Size = UDim2.new(0.84, 0, 0, 56),
		Text = Config.Screens.TotemTop,
	})

	avatarImage(root, "Avatar", UDim2.new(0.5, 0, 0, 392), UDim2.new(1.35, 0, 0, 330))

	text(root, {
		Position = UDim2.new(0.08, 0, 0, 384),
		Size = UDim2.new(0.84, 0, 0, 36),
		Text = caption,
		TextColor3 = Ui.Theme.Accent,
	})

	-- "I want to be a ..." flipping through jobs
	text(root, {
		Position = UDim2.new(0.08, 0, 0, 428),
		Size = UDim2.new(0.84, 0, 0, 20),
		Text = "I want to be a...",
		Font = Ui.Theme.BodyFont,
		TextColor3 = Color3.fromRGB(190, 210, 255),
	})
	local job = text(root, {
		Position = UDim2.new(0.08, 0, 0, 450),
		Size = UDim2.new(0.84, 0, 0, 30),
		Text = Config.Screens.DreamJobs[1],
	})
	local shown = 1
	animate(job, function(t)
		local index = math.floor(t / 1.6) % #Config.Screens.DreamJobs + 1
		if index ~= shown then
			shown = index
			job.Text = Config.Screens.DreamJobs[index]
			job.TextTransparency = 1
			job.Position = UDim2.new(0.08, 0, 0, 462)
			Ui.tween(job, 0.3, { TextTransparency = 0, Position = UDim2.new(0.08, 0, 0, 450) }, Enum.EasingStyle.Back)
		end
	end)

	-- Pulsing call to action
	local button = pill(Config.Screens.CallToAction, Color3.fromRGB(255, 107, 107), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 516),
		Size = UDim2.new(0.86, 0, 0, 54),
		Parent = root,
	})
	button.SliceScale = 0.45
	local pulse = new("UIScale", { Parent = button })
	animate(button, function(t)
		pulse.Scale = 1 + math.max(0, math.sin(t * 4)) * 0.06
	end)
end

local function buildDesk(part)
	local root = surface(part, 800)
	gradient(root, white, Color3.fromRGB(214, 232, 255), 0)
	network(root, Vector2.new(800, 800 * part.Size.Y / part.Size.X), Color3.fromRGB(140, 190, 240), 12, 3)
	local title = text(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.62, 0.6),
		Text = Config.Screens.Desk,
		TextColor3 = Color3.fromRGB(46, 160, 90),
	})
	-- Shimmer running through the title
	local shimmer = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, white),
			ColorSequenceKeypoint.new(0.45, white),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 255, 200)),
			ColorSequenceKeypoint.new(0.55, white),
			ColorSequenceKeypoint.new(1, white),
		}),
		Parent = title,
	})
	animate(title, function(t)
		shimmer.Offset = Vector2.new(((t * 0.5) % 2) - 1, 0)
	end)
	ticker(root, Config.Screens.DreamJobs, {
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(46, 160, 90),
		TextSize = 24,
		Speed = 60,
	})
end

local function buildMonitor(part)
	local root = surface(part, 320)
	gradient(root, Color3.fromRGB(46, 196, 182), Ui.Theme.Brand, 0)
	text(root, {
		Position = UDim2.fromScale(0.06, 0.16),
		Size = UDim2.fromScale(0.5, 0.48),
		Text = Config.Screens.Monitor,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	text(root, {
		Position = UDim2.fromScale(0.06, 0.72),
		Size = UDim2.fromScale(0.4, 0.16),
		Text = Config.Screens.CallToAction,
		Font = Ui.Theme.BodyFont,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Blinking LIVE badge
	local live = text(root, {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(52, 20),
		BackgroundColor3 = Color3.fromRGB(230, 50, 60),
		BackgroundTransparency = 0,
		Text = "LIVE",
	})
	animate(live, function(t)
		live.BackgroundTransparency = if math.floor(t * 1.5) % 2 == 0 then 0 else 0.5
	end)
	avatarImage(root, "AvatarBust", UDim2.fromScale(0.78, 1), UDim2.fromScale(0.44, 0.95))
end

-- The computer on the pedestal types little snippets of code when nobody is using it
local function buildPcScreen(part)
	local root = surface(part, 320)
	root.BackgroundColor3 = navy
	local label = text(root, {
		Position = UDim2.fromScale(0.07, 0.12),
		Size = UDim2.fromScale(0.86, 0.5),
		Font = Enum.Font.Code,
		TextScaled = false,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(120, 230, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
	animate(label, function(t)
		local cycle = t % (#CODE_SNIPPETS * 3)
		local snippet = CODE_SNIPPETS[math.floor(cycle / 3) + 1]
		local typed = math.floor((cycle % 3) * 14)
		local cursor = if math.floor(t * 2) % 2 == 0 then "_" else " "
		label.Text = "> " .. snippet:sub(1, typed) .. cursor
	end)
end

-- Ground sign -----------------------------------------------------------------

-- The big FindJob letters twinkle, and every few seconds a hop runs through them with a
-- puff of sparks, like a crowd doing the wave
local function decorateSign(sign)
	local letters = {}
	for _, letter in sign:GetChildren() do
		local index = tonumber(letter.Name:match("^Letter(%d+)$"))
		local front = letter:FindFirstChild("Front")
		if index and front then
			local sparks = new("ParticleEmitter", {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Color3.new(1, 1, 1), Ui.Theme.Accent),
				LightEmission = 0.6,
				Rate = 1.5,
				Lifetime = NumberRange.new(0.6, 1.2),
				Speed = NumberRange.new(1.5, 3),
				SpreadAngle = Vector2.new(70, 70),
				EmissionDirection = Enum.NormalId.Top,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-180, 180),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.2, 0.45),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Parent = front,
			})
			letters[index] = { model = letter, home = letter:GetPivot(), sparks = sparks }
		end
	end

	animate(sign, function(t)
		local wave = math.floor(t / SIGN_WAVE_EVERY)
		local since = t - wave * SIGN_WAVE_EVERY
		for index, letter in letters do
			-- Each letter starts its hop a little after the one before it
			local phase = (since - index * SIGN_HOP_DELAY) / SIGN_HOP_SECONDS
			local hop = if phase > 0 and phase < 1 then math.sin(phase * math.pi) else 0
			local lean = hop * 0.08 * (if index % 2 == 0 then 1 else -1)
			letter.model:PivotTo(letter.home * CFrame.new(0, hop * SIGN_HOP_HEIGHT, 0) * CFrame.Angles(0, 0, lean))
			-- Sparks puff out at the top of the hop, once per wave
			if phase >= 0.5 and letter.burstWave ~= wave then
				letter.burstWave = wave
				letter.sparks:Emit(10)
			end
		end
	end)
end

-- Pedestals -------------------------------------------------------------------

local function decoratePedestal(fieldId, model)
	local item = model:FindFirstChild("Item")
	pedestals[fieldId] = {
		model = model,
		item = item,
		home = item and item:GetPivot(),
		angle = 0,
		speed = 1,
	}
end

local function setup(stand)
	pedestals = {}
	held = {}

	-- Streaming can deliver the stand's contents a moment after the model itself
	local screens = stand:WaitForChild("Screens", 10)
	if screens then
		local builders = {
			Header = buildHeader,
			Wall = buildWall,
			Desk = buildDesk,
			Monitor = buildMonitor,
		}
		for name, build in builders do
			local part = screens:FindFirstChild(name)
			if part then
				build(part)
			end
		end
		local left, right = screens:FindFirstChild("TotemLeft"), screens:FindFirstChild("TotemRight")
		if left then
			buildTotem(left, Config.Screens.TotemLeft)
		end
		if right then
			buildTotem(right, Config.Screens.TotemRight)
		end
	end

	local sign = stand:WaitForChild("Sign", 10)
	if sign then
		decorateSign(sign)
	end

	for fieldId, field in Config.Fields do
		local model = stand:WaitForChild(field.StationName, 10)
		local waited = 0
		while model and not model.PrimaryPart and waited < 10 do
			waited += task.wait()
		end
		if model and model.PrimaryPart then
			decoratePedestal(fieldId, model)
			local screen = model:FindFirstChild("Item") and model.Item:FindFirstChild("Screen")
			if screen then
				buildPcScreen(screen)
			end
		end
	end
	Stand.highlight(highlighted)
end

-- Public -------------------------------------------------------------------------

-- Makes one pedestal stand out (nil = both normal): its item spins faster and bobs higher,
-- the other one slows down
function Stand.highlight(fieldId)
	highlighted = fieldId
	for id, pedestal in pedestals do
		pedestal.speed = if fieldId == nil then 1 elseif id == fieldId then 3 else 0.3
	end
end

function Stand.getItem(fieldId)
	local pedestal = pedestals[fieldId]
	return pedestal and pedestal.item, pedestal and pedestal.home
end

-- Stops an item spinning and keeps it at `cframe` until released
function Stand.holdItem(item, cframe)
	held[item] = cframe
	item:PivotTo(cframe)
end

function Stand.releaseItem(item)
	held[item] = nil
end

function Stand.start()
	RunService.RenderStepped:Connect(function(deltaTime)
		local stand = Workspace:FindFirstChild(Config.World.FolderName)
		stand = stand and stand:FindFirstChild("Stand")
		if stand ~= currentStand then
			currentStand = stand
			pedestals = {}
			if stand then
				task.spawn(setup, stand)
			end
		end
		if not stand then
			return
		end

		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - stand:GetPivot().Position).Magnitude > ACTIVE_DISTANCE then
			return
		end

		local t = os.clock()
		for _, pedestal in pedestals do
			local item = pedestal.item
			if item and pedestal.home then
				pedestal.angle += deltaTime * SPIN_SPEED * pedestal.speed
				local bob = math.sin(t * 2) * BOB_HEIGHT * math.min(pedestal.speed, 2)
				item:PivotTo(held[item] or pedestal.home * CFrame.new(0, bob, 0) * CFrame.Angles(0, pedestal.angle, 0))
			end
		end
		for _, update in animated do
			update(t, deltaTime)
		end
	end)
end

return Stand
