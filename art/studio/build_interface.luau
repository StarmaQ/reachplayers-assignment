--[[
	Builds the campaign's UI templates into ServerScriptService.FindJobCampaign.Interface,
	the ScreenGui the client clones its windows from. Run it in Studio once, then edit the
	UI visually and save the place; run it again only to start over from these defaults.

	In this project it's synced to ServerStorage.FindJobTools.BuildInterface, so from the
	command bar:   require(game.ServerStorage.FindJobTools.BuildInterface:Clone())
	(cloned so it runs again each time)

	What the game code relies on (keep these when restyling):
	  - the names it looks up (Dialogue.Line.Body, CodingGame.Window.Tray, ...)
	  - "Face" inside a button gets the press animation, a button named "Exit" closes the campaign
	  - a "Label" next to a "Shadow" text keeps the shadow's text in sync
	  - FitToScreen / MaxScale attributes: the frame is scaled to fit the screen, its Size is
	    the design size
]]

local ServerScriptService = game:GetService("ServerScriptService")

local package = ServerScriptService.FindJobCampaign
local Config = require(package.Libraries.Config)
local Ui = require(package.Client.Ui)
local Theme, Images = Ui.Theme, Ui.Images

-- Helpers ------------------------------------------------------------------------

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
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function fit(frame, maxScale)
	frame:SetAttribute("FitToScreen", true)
	if maxScale then
		frame:SetAttribute("MaxScale", maxScale)
	end
end

local function label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.BodyFont,
		TextColor3 = Theme.Ink,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local text = new("TextLabel", defaults)
	new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = text })
	return text
end

-- Greyscale 9-slice sprites from art/blender/build_ui_sprites.py, tinted with ImageColor3
local function sprite(className, sheet, color, props)
	local image = new(className, {
		BackgroundTransparency = 1,
		Image = sheet.Image,
		ImageColor3 = color,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = sheet.Slice,
	})
	for key, value in props or {} do
		image[key] = value
	end
	return image
end

local function panel(color, props)
	return sprite("ImageLabel", Images.Panel, color or Theme.Panel, props)
end

local function slot(color, props)
	return sprite("ImageLabel", Images.Slot, color, props)
end

-- Text with a soft drop shadow: "Label" on top of "Shadow"
local function shadowText(parent, props)
	local shadow = new("TextLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(0, 0, 0),
		TextTransparency = 0.75,
		Font = Theme.Font,
		Parent = parent,
	})
	local text = new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font,
		Parent = parent,
	})
	for key, value in props do
		text[key] = value
		if key ~= "TextColor3" and key ~= "TextTransparency" and key ~= "Name" then
			shadow[key] = value
		end
	end
	shadow.Position = text.Position + UDim2.fromOffset(0, 2)
	return text
end

-- Push button: tinted sprite, label on the "Face" above the lip
local function button(text, color, props)
	local sheet = Images.Button
	local push = sprite("ImageButton", sheet, color, { AutoButtonColor = false })
	local face = new("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = push })
	shadowText(face, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 1, -sheet.Lip - 8),
		Text = text,
		TextScaled = true,
	})
	new("UITextSizeConstraint", { MaxTextSize = 26, Parent = face.Label })
	new("UITextSizeConstraint", { MaxTextSize = 26, Parent = face.Shadow })
	for key, value in props or {} do
		push[key] = value
	end
	-- Smaller buttons get proportionally smaller corners
	push.SliceScale = math.clamp(push.Size.Y.Offset / 120, 0.35, 1)
	return push
end

-- Same look as a button, not clickable: tags like "YOUR MATCH"
local function pill(text, color, props)
	local sheet = Images.Button
	local tag = sprite("ImageLabel", sheet, color)
	shadowText(tag, {
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -20, 1, -sheet.Lip * 0.5 - 6),
		Text = text,
		TextScaled = true,
	})
	for key, value in props or {} do
		tag[key] = value
	end
	tag.SliceScale = math.clamp(tag.Size.Y.Offset / 120, 0.3, 1)
	return tag
end

-- Round sticker button with a white ring (✓ / X, close buttons)
local function sticker(text, color, props)
	local round = new("ImageButton", {
		BackgroundTransparency = 1,
		Image = Images.Sticker,
		ImageColor3 = color,
		AutoButtonColor = false,
	})
	local face = new("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = round })
	new("ImageLabel", {
		Name = "Ring",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Images.StickerRing,
		Parent = face,
	})
	shadowText(face, {
		Position = UDim2.fromScale(0.15, 0.1),
		Size = UDim2.fromScale(0.7, 0.62),
		Text = text,
		TextScaled = true,
	})
	for key, value in props or {} do
		round[key] = value
	end
	return round
end

-- Round X in the top-right corner of a window
local function exitButton(parent, size, position)
	return sticker("X", Theme.Bad, {
		Name = "Exit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(size or 46, size or 46),
		ZIndex = 20,
		Parent = parent,
	})
end

-- Big "what to do" banner on top of a mission: target icon, goal text, step tag
local function goalBanner(props)
	local banner = panel(Theme.Accent, props)
	banner.Name = "Goal"
	local height = banner.Size.Y.Offset

	local icon = new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.46, 0),
		Size = UDim2.fromOffset(height * 0.62, height * 0.62),
		BackgroundTransparency = 1,
		Image = Images.Sticker,
		ImageColor3 = Color3.new(1, 1, 1),
		Parent = banner,
	})
	for i, color in { Theme.Bad, Color3.new(1, 1, 1), Theme.Bad } do
		local size = 0.78 - (i - 1) * 0.26
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(size, size),
			BackgroundColor3 = color,
			Parent = icon,
		}, { corner(999) })
	end
	pill("", Theme.Brand, {
		Name = "Step",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.46, 0),
		Size = UDim2.fromOffset(96, 48),
		Visible = false,
		Parent = banner,
	})
	new("TextLabel", {
		Name = "Text",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, height * 0.62 + 34, 0.46, 0),
		Size = UDim2.new(1, -(height * 0.62 + 34) - 136, 0.62, 0),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = banner,
	}, {
		new("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 18 }),
		new("UIScale", { Name = "Pop" }),
	})
	return banner
end

-- Templates ------------------------------------------------------------------------

local templates = {}

-- Subtitle-style dialogue along the bottom ------------------------------------------
do
	local portraitSize = 116
	-- The fade is only a picture, clicks go through it to the game's own buttons
	local frame = new("Frame", {
		Name = "Dialogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 190),
		BackgroundTransparency = 1,
	})
	-- One gradient per object: the group fades vertically, the frame inside it horizontally
	local fade = new("CanvasGroup", { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = frame }, {
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.55, 0.4),
				NumberSequenceKeypoint.new(1, 0.15),
			}),
		}),
	})
	new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 22, 30),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = fade,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0),
				NumberSequenceKeypoint.new(0.8, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- The subtitle is the button: click or tap it to continue. Its width keeps it between
	-- the thumbstick and the jump button on phones.
	local line = new("TextButton", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.64, 0, 0, portraitSize),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = frame,
	}, { new("UISizeConstraint", { MaxSize = Vector2.new(820, portraitSize) }) })

	-- Maya's portrait
	local portrait = new("ImageLabel", {
		Name = "Portrait",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(portraitSize, portraitSize),
		BackgroundTransparency = 1,
		Image = Images.Sticker,
		ImageColor3 = Theme.Brand,
		Parent = line,
	})
	local viewport = new("ViewportFrame", {
		Name = "Viewport",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = Color3.fromRGB(214, 228, 255),
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.5, -0.6, -1),
		Parent = portrait,
	}, { corner(portraitSize) })
	new("WorldModel", { Parent = viewport }) -- the game adds Maya and a camera

	new("TextLabel", {
		Name = "Speaker",
		Position = UDim2.fromOffset(portraitSize + 16, 4),
		Size = UDim2.new(1, -portraitSize - 16, 0, 22),
		BackgroundTransparency = 1,
		Text = Config.Recruiter.DisplayName:upper(),
		Font = Theme.Font,
		TextSize = 20,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = line,
	})
	new("TextLabel", {
		Name = "Body",
		Position = UDim2.fromOffset(portraitSize + 16, 30),
		Size = UDim2.new(1, -portraitSize - 48, 1, -30),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "",
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.75,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = line,
	}, {
		-- Long lines shrink instead of spilling out on small screens
		new("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 26 }),
	})
	new("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Text = ">",
		Font = Theme.Font,
		TextSize = 26,
		TextColor3 = Theme.Accent,
		Visible = false,
		Parent = line,
	})
	exitButton(line, 34, UDim2.new(1, 4, 0, 8))
	templates.Dialogue = frame
end

-- Name tag floating over Maya's head (a BillboardGui the game puts on her) -------------
do
	local nameplate = new("BillboardGui", {
		Name = "Nameplate",
		Size = UDim2.fromScale(5.4, 1.9), -- studs
		StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0),
		LightInfluence = 0,
		MaxDistance = 80,
	})
	local name = pill(Config.Recruiter.Name, Theme.Brand, {
		Name = "NameTag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.82, 0.62),
		Parent = nameplate,
	})
	name.SliceScale = 0.5
	-- Scale-sized pill: let the text fill it
	name.Label.Size = UDim2.new(1, -20, 0.8, -4)
	name.Shadow.Size = name.Label.Size
	local role = pill(Config.Recruiter.Role:upper(), Theme.Accent, {
		Name = "RoleTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.42),
		ZIndex = 2,
		Parent = nameplate,
	})
	role.SliceScale = 0.35
	role.Label.Size = UDim2.new(1, -20, 0.78, -2)
	role.Label.TextColor3 = Theme.Ink
	role.Shadow.Size = role.Label.Size
	role.Shadow.TextTransparency = 1
	for _, text in { role.Label, role.Shadow } do
		text.ZIndex = 2
	end
	templates.Nameplate = nameplate
end

-- Clipboard with the questions --------------------------------------------------------
do
	local board = new("ImageLabel", {
		Name = "Clipboard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6), -- slides up into view
		Size = UDim2.fromOffset(480, 640),
		BackgroundTransparency = 1,
		Image = Images.Clipboard,
	})
	fit(board, 1.25)
	-- Area of the image covered by the paper sheet
	local paper = new("Frame", {
		Name = "Paper",
		Position = UDim2.fromScale(0.11, 0.16),
		Size = UDim2.fromScale(0.78, 0.76),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = board,
	})
	label({
		Name = "Brand",
		Size = UDim2.fromScale(1, 0.05),
		Text = Config.Brand:upper() .. "  ·  CAREER MATCH",
		Font = Theme.Font,
		TextColor3 = Theme.Brand,
		MaxTextSize = 18,
		Parent = paper,
	})
	exitButton(board)
	templates.Clipboard = board

	-- One page per question
	local page = new("Frame", {
		Name = "ClipboardPage",
		Position = UDim2.fromScale(0, 0.08),
		Size = UDim2.fromScale(1, 0.92),
		BackgroundTransparency = 1,
	})
	label({
		Name = "Progress",
		Size = UDim2.fromScale(1, 0.05),
		Text = "Question 1 of 2",
		TextColor3 = Color3.fromRGB(130, 130, 140),
		MaxTextSize = 16,
		Parent = page,
	})
	label({
		Name = "Question",
		Position = UDim2.fromScale(0, 0.07),
		Size = UDim2.fromScale(1, 0.2),
		Text = "Question",
		Font = Theme.Font,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 30,
		Parent = page,
	})
	new("Frame", {
		Name = "Answers",
		Position = UDim2.fromScale(0, 0.32),
		Size = UDim2.fromScale(1, 0.66),
		BackgroundTransparency = 1,
		Parent = page,
	}, { new("UIListLayout", { Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
	templates.ClipboardPage = page

	-- An answer: soft push button with a sticker checkbox
	local answer = button("", Color3.fromRGB(236, 242, 255), {
		Name = "ClipboardAnswer",
		Size = UDim2.new(1, 0, 0.2, 0),
	})
	answer.SliceScale = 0.5
	local box = new("ImageLabel", {
		Name = "Box",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.45, 0),
		Size = UDim2.fromScale(0.62, 0.62),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Image = Images.Sticker,
		ImageColor3 = Color3.fromRGB(200, 212, 240),
		Parent = answer.Face,
	})
	new("TextLabel", {
		Name = "Tick",
		Size = UDim2.fromScale(1, 0.85),
		BackgroundTransparency = 1,
		Text = "",
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = box,
	})
	-- Fixed text size so every answer reads the same
	new("TextLabel", {
		Name = "Text",
		Position = UDim2.new(0.15, 0, 0, 0),
		Size = UDim2.new(0.82, 0, 0.88, 0),
		BackgroundTransparency = 1,
		Text = "Answer",
		Font = Theme.BodyFont,
		TextSize = 22,
		TextWrapped = true,
		TextColor3 = Theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = answer.Face,
	})
	templates.ClipboardAnswer = answer
end

-- Software Engineer mission: a computer with a tiny code editor --------------------------
do
	local slotColor = Color3.fromRGB(58, 74, 128)
	local screenColor = Color3.fromRGB(14, 22, 40)
	local standColor = Color3.fromRGB(205, 210, 222)

	local root = new("Frame", {
		Name = "CodingGame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 14, 28),
		BackgroundTransparency = 0.35,
	})
	local window = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1000, 820),
		BackgroundTransparency = 1,
		Parent = root,
	})
	fit(window, 1.25)
	goalBanner({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(860, 104),
		Parent = window,
	})

	-- A chunky cartoon monitor: bezel, dark screen, stand, power light
	local bezel = panel(Color3.fromRGB(236, 239, 246), {
		Name = "Computer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(780, 490),
		Parent = window,
	})
	local screen = new("Frame", {
		Name = "Screen",
		Position = UDim2.fromOffset(40, 36),
		Size = UDim2.new(1, -80, 1, -104),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		Parent = bezel,
	}, { corner(18) })
	new("TextLabel", {
		Name = "Brand",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(200, 26),
		BackgroundTransparency = 1,
		Text = Config.Brand,
		Font = Theme.Font,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(150, 160, 185),
		Parent = bezel,
	})
	new("Frame", {
		Name = "PowerLight",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -52, 1, -40),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(90, 96, 110),
		Parent = bezel,
	}, { corner(7) })
	new("Frame", {
		Name = "StandNeck",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 606),
		Size = UDim2.fromOffset(110, 34),
		BackgroundColor3 = standColor,
		BorderSizePixel = 0,
		Parent = window,
	})
	new("Frame", {
		Name = "StandBase",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 636),
		Size = UDim2.fromOffset(300, 18),
		BackgroundColor3 = standColor,
		Parent = window,
	}, { corner(9) })

	-- The code editor, hidden until the computer has booted
	local editor = new("Frame", {
		Name = "Editor",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = screenColor,
		Visible = false,
		Parent = screen,
	}, {
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150, 170, 220), Color3.new(1, 1, 1)), Rotation = 90 }),
	})
	-- Faint scanlines over the whole screen
	local scanlines = new("Frame", { Name = "Scanlines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = screen })
	for y = 0, 400, 6 do
		new("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = scanlines,
		})
	end
	new("TextLabel", {
		Name = "FileName",
		Position = UDim2.fromOffset(28, 16),
		Size = UDim2.fromOffset(300, 24),
		BackgroundTransparency = 1,
		Text = "game.lua",
		Font = Enum.Font.Code,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(111, 125, 166),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = editor,
	})
	new("Frame", {
		Name = "Code",
		Position = UDim2.fromOffset(34, 50),
		Size = UDim2.new(1, -68, 1, -114),
		BackgroundTransparency = 1,
		Parent = editor,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	new("TextLabel", {
		Name = "Output",
		Position = UDim2.new(0, 34, 1, -58),
		Size = UDim2.new(1, -68, 0, 38),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(120, 240, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = editor,
	})

	-- Instruction and the tray of pieces at the bottom
	shadowText(new("Frame", {
		Name = "Instruction",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 660),
		Size = UDim2.fromOffset(760, 34),
		BackgroundTransparency = 1,
		Parent = window,
	}), {
		Size = UDim2.fromScale(1, 1),
		TextSize = 26,
		Text = "Drag the right piece into the gap",
	})
	local tray = panel(Color3.fromRGB(24, 28, 46), {
		Name = "Tray",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(0, 124),
		AutomaticSize = Enum.AutomaticSize.X,
		ImageTransparency = 0.05,
		Parent = window,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 30),
		PaddingRight = UDim.new(0, 30),
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 28),
		Parent = tray,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tray,
	})
	exitButton(window, 46, UDim2.new(1, -60, 0, 150))
	templates.CodingGame = root

	-- Startup screen laid over the monitor's screen while it boots
	local boot = new("Frame", {
		Name = "CodingBoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	})
	new("TextLabel", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(420, 70),
		BackgroundTransparency = 1,
		Text = Config.Brand .. " OS",
		Font = Theme.Font,
		TextSize = 60,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
		ZIndex = 4,
		Parent = boot,
	})
	local barBack = new("Frame", {
		Name = "BarBack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(300, 14),
		BackgroundColor3 = Color3.fromRGB(40, 52, 90),
		ZIndex = 4,
		Parent = boot,
	}, { corner(7) })
	new("Frame", {
		Name = "Bar",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		ZIndex = 5,
		Parent = barBack,
	}, { corner(7) })
	new("TextLabel", {
		Name = "Log",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(420, 100),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(120, 240, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 4,
		Parent = boot,
	})
	templates.CodingBoot = boot

	-- One line of code, and a piece of text in it
	templates.CodingLine = new("Frame", {
		Name = "CodingLine",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	templates.CodingText = new("TextLabel", {
		Name = "CodingText",
		Size = UDim2.fromOffset(0, 54),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		RichText = true,
		Text = "local",
		Font = Enum.Font.Code,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(226, 236, 255),
	})

	-- A gap in the code, with the piece that sits in it once filled
	local gap = slot(slotColor, {
		Name = "CodingGap",
		Size = UDim2.fromOffset(112, 54),
		SliceScale = 0.6,
	})
	local piece = pill("", Color3.new(1, 1, 1), {
		Name = "Piece",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -4),
		Visible = false,
		Parent = gap,
	})
	piece.Label.Font = Enum.Font.Code
	piece.Shadow.Font = Enum.Font.Code
	new("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 3,
		Parent = gap,
	})
	templates.CodingGap = gap

	-- A piece in the tray (its width follows its text)
	local chip = button("3", Color3.fromRGB(255, 107, 107), {
		Name = "CodingChip",
		Size = UDim2.fromOffset(100, 76),
	})
	chip.Face.Label.Font = Enum.Font.Code
	chip.Face.Shadow.Font = Enum.Font.Code
	templates.CodingChip = chip
end

-- Teacher mission: quizzes to grade ---------------------------------------------------
do
	local redInk = Color3.fromRGB(215, 40, 50)

	local root = new("Frame", {
		Name = "GradingGame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 12, 20),
		BackgroundTransparency = 0.45,
	})
	local window = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 620),
		BackgroundTransparency = 1,
		Parent = root,
	})
	fit(window)
	goalBanner({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(640, 104),
		Parent = window,
	})
	-- The paper, a little crooked like a real one on a desk
	local card = panel(Color3.fromRGB(255, 253, 244), {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(580, 480),
		Rotation = -2,
		Parent = window,
	})
	new("Frame", {
		Name = "Margin",
		Position = UDim2.new(0, 70, 0, 18),
		Size = UDim2.new(0, 3, 1, -40),
		BackgroundColor3 = Color3.fromRGB(240, 130, 130),
		BorderSizePixel = 0,
		Parent = card,
	})
	new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(90, 36),
		Size = UDim2.new(1, -110, 0, 50),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "Sam's math quiz",
		TextSize = 36,
		TextColor3 = Theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	new("TextLabel", {
		Name = "Hint",
		Position = UDim2.fromOffset(90, 86),
		Size = UDim2.new(1, -110, 0, 28),
		BackgroundTransparency = 1,
		Font = Theme.BodyFont,
		Text = "",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	new("Frame", {
		Name = "Lines",
		Position = UDim2.fromOffset(90, 136),
		Size = UDim2.new(1, -124, 1, -176),
		BackgroundTransparency = 1,
		Parent = card,
	}, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local stamp = new("TextLabel", {
		Name = "Stamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.78, 0.16),
		Size = UDim2.fromOffset(150, 110),
		BackgroundTransparency = 1,
		Text = "A+",
		Font = Theme.Font,
		TextSize = 96,
		TextColor3 = redInk,
		Rotation = 14,
		Visible = false,
		ZIndex = 5,
		Parent = card,
	})
	new("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = stamp,
	})
	exitButton(window)
	templates.GradingGame = root

	-- One answer on the quiz, with the two stickers to mark it
	local row = new("Frame", {
		Name = "GradingRow",
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundTransparency = 1,
	})
	new("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(190, 215, 245),
		BorderSizePixel = 0,
		Parent = row,
	})
	new("TextLabel", {
		Name = "Answer",
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(0.58, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "7 x 8 = 56",
		Font = Theme.HandwritingFont,
		TextSize = 46,
		TextColor3 = Color3.fromRGB(35, 55, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	new("TextLabel", {
		Name = "PenMark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.6, 0.45),
		Size = UDim2.fromOffset(60, 70),
		BackgroundTransparency = 1,
		Text = "",
		Font = Theme.HandwritingFont,
		TextSize = 64,
		TextColor3 = redInk,
		Rotation = -10,
		Parent = row,
	})
	for name, look in { Right = { "✓", Theme.Good, 0.78 }, Wrong = { "X", Theme.Bad, 0.93 } } do
		sticker(look[1], look[2], {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(look[3], 0, 0.5, 0),
			Size = UDim2.fromOffset(70, 70),
			Parent = row,
		})
	end
	templates.GradingRow = row
end

-- Feedback cards and toast -----------------------------------------------------------
do
	-- A card is a holder with the white panel on top
	local function card(name, width, height)
		local holder = new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(width, height),
			BackgroundTransparency = 1,
		})
		fit(holder)
		local body = panel(nil, { Name = "Panel", Size = UDim2.fromScale(1, 1), Parent = holder })
		return holder, body
	end
	local function title(parent, name, text, y, size)
		return new("TextLabel", {
			Name = name,
			Position = UDim2.fromOffset(24, y),
			Size = UDim2.new(1, -48, 0, size + 8),
			BackgroundTransparency = 1,
			Text = text,
			Font = Theme.Font,
			TextSize = size,
			TextColor3 = Theme.Ink,
			TextWrapped = true,
			Parent = parent,
		})
	end

	-- "Your match" reveal
	local reveal, revealPanel = card("RevealCard", 500, 230)
	pill("YOUR MATCH", Theme.Brand, {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(200, 48),
		Parent = revealPanel,
	})
	title(revealPanel, "Field", "Software Engineer", 100, 48).Rotation = -3 -- stamped on, a bit crooked
	templates.RevealCard = reveal

	-- Yes / no question
	local ask, askPanel = card("AskCard", 520, 270)
	title(askPanel, "Question", "Did that job feel like you?", 40, 32)
	button("Yes", Theme.Good, {
		Name = "Yes",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 34, 1, -40),
		Size = UDim2.new(0.5, -44, 0, 72),
		Parent = askPanel,
	})
	button("No", Color3.fromRGB(130, 138, 160), {
		Name = "No",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -34, 1, -40),
		Size = UDim2.new(0.5, -44, 0, 72),
		Parent = askPanel,
	})
	templates.AskCard = ask

	-- Short message at the top of the screen
	local toast = pill("Go to the computer!", Theme.Brand, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -90),
		Size = UDim2.fromOffset(480, 64),
		ZIndex = 30,
	})
	toast.SliceScale = 0.5
	fit(toast)
	templates.Toast = toast
end

-- Into the package -----------------------------------------------------------------

local interface = package:FindFirstChild("Interface")
if not interface then
	interface = Instance.new("ScreenGui")
	interface.Name = "Interface"
	interface.Parent = package
end
interface.ResetOnSpawn = false
interface.IgnoreGuiInset = true
interface.DisplayOrder = 10
interface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
interface:ClearAllChildren()
for name, template in templates do
	template.Name = name
	template.Parent = interface
end

print("Interface built:", #interface:GetDescendants(), "instances")
return true
