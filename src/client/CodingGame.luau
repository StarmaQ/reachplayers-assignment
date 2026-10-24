-- Software Engineer minigame: a Scratch-like editor. Drag blocks from the palette
-- on the right into the program slots on the left, then press Run.
--
--     CodingGame.open(puzzle, function(blockIds) ... end)  -- called when the player runs the code
--     CodingGame.showResult(result)                         -- { success, feedback = { [slot] = bool }, message? }
--     CodingGame.close()

local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)

local KIND_COLORS = {
	Input = Color3.fromRGB(76, 151, 255),
	Logic = Color3.fromRGB(255, 171, 25),
	Output = Color3.fromRGB(153, 102, 255),
	Action = Color3.fromRGB(89, 192, 89),
}
local EVENT_COLOR = Color3.fromRGB(255, 191, 0)
local EDITOR_BG = Color3.fromRGB(30, 34, 48)
local PANEL_BG = Color3.fromRGB(38, 43, 58)
local MUTED = Color3.fromRGB(150, 156, 175)

local CodingGame = {}

local editor = nil -- state of the open editor, nil when closed

local function blockById(id)
	for _, block in editor.puzzle.blocks do
		if block.Id == id then
			return block
		end
	end
	return nil
end

local function makeBlock(block)
	local color = KIND_COLORS[block.Kind] or KIND_COLORS.Action
	local button = Ui.new("TextButton", {
		Name = block.Id,
		Text = block.Text,
		Font = Ui.Theme.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = UDim2.new(1, 0, 0, 44),
	}, {
		Ui.corner(8),
		Ui.stroke(color:Lerp(Color3.new(0, 0, 0), 0.3), 2),
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
		Ui.new("UITextSizeConstraint", { MaxTextSize = 18 }),
	})
	-- Little Scratch-style notch on top
	Ui.new("Frame", {
		Name = "Notch",
		Position = UDim2.fromOffset(4, -14),
		Size = UDim2.fromOffset(18, 6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = button,
	}, { Ui.corner(2) })
	return button
end

local function log(text, color)
	editor.console.Text = text
	editor.console.TextColor3 = color or Color3.fromRGB(120, 230, 140)
end

local function allSlotsFilled()
	for i = 1, editor.puzzle.slotCount do
		if not editor.slots[i] then
			return false
		end
	end
	return true
end

local render -- forward declared, drag handlers re-render after every drop

local function slotUnder(point)
	for i, slotFrame in editor.slotFrames do
		if Ui.contains(slotFrame, point) then
			return i
		end
	end
	return nil
end

local function startDrag(blockGui, blockId, fromSlot, input)
	if editor.locked then
		return
	end

	local grabOffset = Ui.pointer(input) - blockGui.AbsolutePosition
	local ghost = makeBlock(blockById(blockId))
	ghost.Size = UDim2.fromOffset(blockGui.AbsoluteSize.X, blockGui.AbsoluteSize.Y)
	ghost.ZIndex = 50
	ghost.Rotation = -3
	ghost.Parent = Ui.root()
	blockGui.Visible = false

	local function moveTo(point)
		local topLeft = point - grabOffset
		ghost.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
		local hovered = slotUnder(point)
		for i, slotFrame in editor.slotFrames do
			slotFrame.UIStroke.Color = if i == hovered then Ui.Theme.Accent else MUTED
		end
	end
	moveTo(Ui.pointer(input))

	local moveConnection, endConnection
	moveConnection = UserInputService.InputChanged:Connect(function(changed)
		if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
			moveTo(Ui.pointer(changed))
		end
	end)
	endConnection = UserInputService.InputEnded:Connect(function(ended)
		if ended.UserInputType ~= Enum.UserInputType.MouseButton1 and ended.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		moveConnection:Disconnect()
		endConnection:Disconnect()
		ghost:Destroy()
		if not editor then
			return
		end

		local target = slotUnder(Ui.pointer(ended))
		if fromSlot then
			editor.slots[fromSlot] = nil
		end
		if target then
			-- Whatever was in the target slot goes back where the dragged block came from
			local displaced = editor.slots[target]
			editor.slots[target] = blockId
			if displaced and fromSlot then
				editor.slots[fromSlot] = displaced
			end
		end
		render()
	end)
	editor.dragConnections = { moveConnection, endConnection }
end

render = function()
	local placed = {}
	for i = 1, editor.puzzle.slotCount do
		local slotFrame = editor.slotFrames[i]
		slotFrame.UIStroke.Color = MUTED
		local existing = slotFrame:FindFirstChild("Block")
		if existing then
			existing:Destroy()
		end

		local blockId = editor.slots[i]
		slotFrame.Placeholder.Visible = blockId == nil
		if blockId then
			placed[blockId] = true
			local blockGui = makeBlock(blockById(blockId))
			blockGui.Name = "Block"
			blockGui.Size = UDim2.fromScale(1, 1)
			blockGui.Parent = slotFrame
			blockGui.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					startDrag(blockGui, blockId, i, input)
				end
			end)
		end
	end

	for _, child in editor.palette:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for order, block in editor.puzzle.blocks do
		if not placed[block.Id] then
			local blockGui = makeBlock(block)
			blockGui.LayoutOrder = order
			blockGui.Parent = editor.palette
			blockGui.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					startDrag(blockGui, block.Id, nil, input)
				end
			end)
		end
	end

	local ready = allSlotsFilled() and not editor.locked
	editor.runButton.BackgroundColor3 = if ready then Ui.Theme.Good else Color3.fromRGB(80, 86, 104)
	editor.runButton.Active = ready
end

local function build(puzzle)
	local window = Ui.new("Frame", {
		Name = "CodingGame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.82),
		BackgroundColor3 = EDITOR_BG,
	}, {
		Ui.corner(16),
		Ui.stroke(Ui.Theme.Brand, 3),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(1060, 680) }),
	})

	-- Title bar like a code editor
	local titleBar = Ui.new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(21, 24, 35),
		Parent = window,
	}, { Ui.corner(16) })
	for i, color in { Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) } do
		Ui.new("Frame", {
			Position = UDim2.fromOffset(16 + (i - 1) * 20, 14),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = color,
			Parent = titleBar,
		}, { Ui.corner(6) })
	end
	Ui.label({
		Position = UDim2.fromOffset(84, 10),
		Size = UDim2.new(1, -140, 0, 20),
		Text = "login.lua  —  FindJob Studio",
		Font = Enum.Font.Code,
		TextColor3 = MUTED,
		MaxTextSize = 16,
		Parent = titleBar,
	})

	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(24, 54),
		Size = UDim2.new(1, -48, 0, 30),
		Text = puzzle.title,
		Font = Ui.Theme.Font,
		TextColor3 = Color3.new(1, 1, 1),
		MaxTextSize = 26,
		Parent = window,
	})
	Ui.label({
		Name = "Brief",
		Position = UDim2.fromOffset(24, 86),
		Size = UDim2.new(1, -48, 0, 22),
		Text = puzzle.brief,
		TextColor3 = MUTED,
		MaxTextSize = 18,
		Parent = window,
	})

	-- Program area (left)
	local program = Ui.new("Frame", {
		Name = "Program",
		Position = UDim2.fromOffset(20, 122),
		Size = UDim2.new(0.56, -30, 1, -200),
		BackgroundColor3 = PANEL_BG,
		Parent = window,
	}, {
		Ui.corner(12),
		Ui.padding(14),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	Ui.new("TextLabel", {
		Name = "Event",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = EVENT_COLOR,
		Text = "  when  [Login]  is clicked",
		Font = Ui.Theme.Font,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(60, 40, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = program,
	}, { Ui.corner(14) })

	local slotFrames = {}
	for i = 1, puzzle.slotCount do
		local slotFrame = Ui.new("Frame", {
			Name = "Slot" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, -24, 0, 44),
			BackgroundColor3 = Color3.fromRGB(46, 52, 70),
			Parent = program,
		}, { Ui.corner(8), Ui.stroke(MUTED, 2) })
		slotFrame.UIStroke.Transparency = 0.3
		Ui.label({
			Name = "Placeholder",
			Size = UDim2.fromScale(1, 1),
			Text = ("  %d.  drop a block here"):format(i),
			Font = Enum.Font.Code,
			TextColor3 = MUTED,
			MaxTextSize = 16,
			Parent = slotFrame,
		})
		slotFrames[i] = slotFrame
	end

	-- Palette (right)
	Ui.label({
		Name = "PaletteTitle",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 122),
		Size = UDim2.new(0.44, -10, 0, 20),
		Text = "BLOCKS",
		Font = Ui.Theme.Font,
		TextColor3 = MUTED,
		MaxTextSize = 14,
		Parent = window,
	})
	local palette = Ui.new("Frame", {
		Name = "Palette",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 150),
		Size = UDim2.new(0.44, -10, 1, -228),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 10) }),
	})

	-- Bottom bar: console + buttons
	local console = Ui.label({
		Name = "Console",
		Position = UDim2.new(0, 24, 1, -60),
		Size = UDim2.new(0.6, 0, 0, 40),
		Text = "> Waiting for your code...",
		Font = Enum.Font.Code,
		TextColor3 = Color3.fromRGB(120, 230, 140),
		MaxTextSize = 18,
		Parent = window,
	})

	local runButton = Ui.button("▶  Run", Ui.Theme.Good, {
		Name = "Run",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -18),
		Size = UDim2.fromOffset(150, 48),
		Parent = window,
	})
	local resetButton = Ui.button("Reset", Color3.fromRGB(80, 86, 104), {
		Name = "Reset",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -184, 1, -18),
		Size = UDim2.fromOffset(110, 48),
		Parent = window,
	})

	Ui.exitButton(window)

	return {
		window = window,
		slotFrames = slotFrames,
		palette = palette,
		console = console,
		runButton = runButton,
		resetButton = resetButton,
	}
end

function CodingGame.open(puzzle, onSubmit)
	CodingGame.close()

	editor = build(puzzle)
	editor.puzzle = puzzle
	editor.slots = {}
	editor.locked = false

	editor.runButton.Activated:Connect(function()
		if editor.locked or not allSlotsFilled() then
			return
		end
		editor.locked = true
		render()

		-- Step through the program like a debugger before sending it off
		log("> Running...", Color3.fromRGB(255, 220, 120))
		for _, slotFrame in editor.slotFrames do
			slotFrame.UIStroke.Color = Ui.Theme.Accent
			task.wait(0.18)
			if not editor then
				return
			end
			slotFrame.UIStroke.Color = MUTED
		end

		local order = {}
		for i = 1, puzzle.slotCount do
			order[i] = editor.slots[i]
		end
		onSubmit(order)
	end)

	editor.resetButton.Activated:Connect(function()
		if not editor.locked then
			editor.slots = {}
			render()
		end
	end)

	Ui.open(editor.window, function()
		for _, connection in editor.dragConnections or {} do
			connection:Disconnect()
		end
		editor = nil
	end)
	Ui.popIn(editor.window)
	render()
end

function CodingGame.showResult(result)
	if not editor then
		return
	end

	local wrongCount = 0
	for i, slotFrame in editor.slotFrames do
		local correct = result.feedback and result.feedback[i]
		slotFrame.UIStroke.Color = if correct then Ui.Theme.Good else Ui.Theme.Bad
		slotFrame.UIStroke.Transparency = 0
		if not correct then
			wrongCount += 1
		end
	end

	if result.success then
		log(result.message or "> Login works! Welcome screen shown ✔")
		return
	end

	log(
		result.message or ("> Bug found: %d block%s in the wrong place"):format(wrongCount, wrongCount == 1 and "" or "s"),
		Ui.Theme.Bad
	)
	task.spawn(Ui.shake, editor.window)

	-- Give the wrong blocks back so the player can try again
	task.delay(1.2, function()
		if not editor then
			return
		end
		for i = 1, editor.puzzle.slotCount do
			if not (result.feedback and result.feedback[i]) then
				editor.slots[i] = nil
			end
		end
		editor.locked = false
		log("> Fix the highlighted lines and run again")
		render()
	end)
end

function CodingGame.close()
	if editor then
		Ui.close(editor.window)
	end
end

return CodingGame
