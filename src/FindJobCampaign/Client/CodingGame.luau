-- Software Engineer minigame. A computer pops up on screen, boots up, and opens a tiny
-- code editor. Drag (or tap) the right piece into each gap.
--
--     CodingGame.open(puzzle, function(step, chips) ... end)  -- called when every gap is filled
--     CodingGame.showResult(result)                         -- { step, correct, feedback = { [gap] = bool }, done }
--     CodingGame.close()

local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)

local CHIP_COLORS = {
	Color3.fromRGB(255, 107, 107),
	Color3.fromRGB(255, 176, 32),
	Color3.fromRGB(46, 196, 182),
	Color3.fromRGB(124, 108, 245),
}
local BOOT_LINES = {
	"Loading code editor...    OK",
	"Waking up the robots...   OK",
	"Checking snacks...        OK",
}

local CodingGame = {}

local current = nil -- state of the open game, nil when closed

-- Code with a bit of color: keywords pink, print blue, comments grey. Spaces become
-- non-breaking spaces first, so the label keeps them when it sizes itself around the text.
local function highlight(code)
	code = code:gsub(" ", "\u{00A0}")
	code = code:gsub("^local", '<font color="#ff8fc7">local</font>')
	code = code:gsub("print", '<font color="#7fd0ff">print</font>')
	code = code:gsub("(%-%-.*)$", '<font color="#6f7da6">%1</font>')
	return code
end

-- "coins = coins {1} {2}" -> { "coins = coins ", 1, " ", 2 }
local function parseLine(line)
	local pieces = {}
	local position = 1
	for start, gap, finish in line:gmatch("()%{(%d+)%}()") do
		if start > position then
			table.insert(pieces, line:sub(position, start - 1))
		end
		table.insert(pieces, tonumber(gap))
		position = finish
	end
	if position <= #line then
		table.insert(pieces, line:sub(position))
	end
	return pieces
end

-- Layout ------------------------------------------------------------------------

-- The window comes from the CodingGame template; these are the parts the game drives
local function build()
	local root = Ui.template("CodingGame")
	local window = root.Window
	local computer = window.Computer
	Ui.setGoal(window.Goal, "Starting the computer...")
	window.Instruction.Label.Text = "" -- shown once the editor is up
	return {
		root = root,
		window = window,
		goal = window.Goal,
		screen = computer.Screen,
		powerLight = computer.PowerLight,
		editor = computer.Screen.Editor,
		code = computer.Screen.Editor.Code,
		output = computer.Screen.Editor.Output,
		instruction = window.Instruction.Label,
		tray = window.Tray,
	}
end

-- A piece for the tray (or the copy that follows the pointer); its width follows its text
local function makeChip(text, color)
	local chip = Ui.template("CodingChip")
	chip.Size = UDim2.fromOffset(math.max(100, #text * 22 + 56), chip.Size.Y.Offset)
	chip.ImageColor3 = color
	chip.Face.Label.Text = text
	return chip
end

-- Startup -----------------------------------------------------------------------

-- Power on, logo with a loading bar, a few boot lines, then the editor.
-- Returns false if the game was closed while booting.
local function bootUp(state)
	local ui = state.ui
	local screen = ui.screen

	local function alive()
		return current == state
	end

	task.wait(0.35)
	ui.powerLight.BackgroundColor3 = Color3.fromRGB(80, 230, 120)

	-- Flicker on
	local boot = Ui.template("CodingBoot")
	boot.Parent = screen
	Ui.tween(boot, 0.25, { BackgroundColor3 = ui.editor.BackgroundColor3 })
	task.wait(0.3)
	if not alive() then
		return false
	end

	Ui.tween(boot.Logo, 0.4, { TextTransparency = 0 })
	Ui.tween(boot.BarBack.Bar, 1.1, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad)

	local log = boot.Log
	for _, line in BOOT_LINES do
		task.wait(0.35)
		if not alive() then
			return false
		end
		log.Text ..= line .. "\n"
	end
	task.wait(0.35)
	if not alive() then
		return false
	end

	-- Hand over to the editor
	ui.editor.Visible = true
	Ui.tween(boot, 0.25, { BackgroundTransparency = 1 })
	for _, child in boot:GetDescendants() do
		if child:IsA("TextLabel") then
			Ui.tween(child, 0.2, { TextTransparency = 1 })
		elseif child:IsA("Frame") then
			Ui.tween(child, 0.2, { BackgroundTransparency = 1 })
		end
	end
	task.delay(0.3, function()
		boot:Destroy()
	end)
	return true
end

-- Exercise rendering ----------------------------------------------------------

local render -- forward declared, input handlers re-render after changes

local function exercise()
	return current.puzzle.exercises[current.step]
end

-- Each piece keeps its color, in the tray and in a gap
local function chipColor(text)
	for order, chip in exercise().chips do
		if chip == text then
			return CHIP_COLORS[(order - 1) % #CHIP_COLORS + 1]
		end
	end
	return CHIP_COLORS[1]
end

local function gapUnder(point)
	for index, gap in current.gaps do
		if Ui.contains(gap, point) then
			return index
		end
	end
	return nil
end

local function placeChip(text, gapIndex)
	if current.locked then
		return
	end
	if not gapIndex then
		-- A tap fills the first empty gap
		for index in current.gaps do
			if not current.filled[index] then
				gapIndex = index
				break
			end
		end
	end
	if gapIndex then
		current.filled[gapIndex] = text
		render()
	end
end

-- Dragging works in "how far did the pointer move" only: the copy starts exactly on top of
-- the chip and follows the movement, and it lands in the gap under its own center.
-- No screen <-> UI coordinate conversion, so it can't drift (top bar insets, scaling, touch).
local function startDrag(chip, text, input)
	if current.locked then
		return
	end
	local root = Ui.root()
	local start = Vector2.new(input.Position.X, input.Position.Y)
	local origin = chip.AbsolutePosition - root.AbsolutePosition
	local ghost = makeChip(text, chipColor(text))
	ghost.Size = UDim2.fromOffset(chip.AbsoluteSize.X, chip.AbsoluteSize.Y)
	ghost.Position = UDim2.fromOffset(origin.X, origin.Y)
	ghost.ZIndex = 50
	ghost.Parent = root
	chip.Visible = false
	Ui.tween(ghost, 0.1, { Rotation = -4 })

	local moved = 0
	local function follow(position)
		local delta = Vector2.new(position.X, position.Y) - start
		moved = math.max(moved, delta.Magnitude)
		ghost.Position = UDim2.fromOffset(origin.X + delta.X, origin.Y + delta.Y)
		-- Light up the gap the piece would land in
		local hovered = gapUnder(ghost.AbsolutePosition + ghost.AbsoluteSize / 2)
		for index, gap in current.gaps do
			gap.ImageColor3 = if index == hovered then Ui.Theme.Accent else current.slotColor
		end
	end

	-- Only the finger (or mouse) that picked the chip moves it: on phones the other thumb is
	-- usually on the thumbstick, and its touches must not drag the piece around
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	local function isOurs(other, mouseType)
		return if isTouch then other == input else other.UserInputType == mouseType
	end

	local moveConnection, endConnection
	moveConnection = UserInputService.InputChanged:Connect(function(changed)
		if isOurs(changed, Enum.UserInputType.MouseMovement) then
			follow(changed.Position)
		end
	end)
	endConnection = UserInputService.InputEnded:Connect(function(ended)
		if not isOurs(ended, Enum.UserInputType.MouseButton1) then
			return
		end
		moveConnection:Disconnect()
		endConnection:Disconnect()
		if not current then
			ghost:Destroy()
			return
		end

		local gapIndex = gapUnder(ghost.AbsolutePosition + ghost.AbsoluteSize / 2)
		ghost:Destroy()
		for _, gap in current.gaps do
			gap.ImageColor3 = current.slotColor
		end
		if gapIndex or moved < 10 then
			placeChip(text, gapIndex) -- dropped on a gap, or just tapped
		else
			render() -- dropped somewhere else: back to the tray
		end
	end)
	current.dragConnections = { moveConnection, endConnection }
end

local function buildCode()
	for _, child in current.ui.code:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	current.gaps = {}

	for lineIndex, line in exercise().lines do
		local row = Ui.template("CodingLine")
		row.LayoutOrder = lineIndex
		row.Parent = current.ui.code
		for order, piece in parseLine(line) do
			if type(piece) == "string" then
				local text = Ui.template("CodingText")
				text.LayoutOrder = order
				text.Text = highlight(piece)
				text.Parent = row
			else
				local gap = Ui.template("CodingGap")
				current.slotColor = gap.ImageColor3 -- hovering lights gaps up, then they go back to this
				gap.Name = "Gap" .. piece
				gap.LayoutOrder = order
				gap.Parent = row
				gap.Button.Activated:Connect(function()
					-- Tapping a filled gap gives the piece back
					if current and not current.locked and current.filled[piece] then
						current.filled[piece] = nil
						render()
					end
				end)
				current.gaps[piece] = gap
			end
		end
	end
end

render = function()
	local placed = {}
	for index, gap in current.gaps do
		local text = current.filled[index]
		gap.Piece.Visible = text ~= nil
		if text then
			placed[text] = true
			gap.Piece.Label.Text = text
			gap.Piece.ImageColor3 = chipColor(text)
		end
	end

	for _, child in current.ui.tray:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for order, text in exercise().chips do
		if not placed[text] then
			local chip = makeChip(text, chipColor(text))
			chip.Name = "Chip_" .. text
			chip.LayoutOrder = order
			chip.Parent = current.ui.tray
			chip.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					startDrag(chip, text, input)
				end
			end)
		end
	end

	-- Every gap filled: check it
	local allFilled = next(current.gaps) ~= nil
	for index in current.gaps do
		if not current.filled[index] then
			allFilled = false
		end
	end
	if allFilled and not current.locked then
		current.locked = true
		current.ui.instruction.Text = "Checking..."
		local step = current.step
		task.delay(0.35, function()
			if current and current.step == step then
				local answer = {}
				for index = 1, #current.gaps do
					answer[index] = current.filled[index]
				end
				current.onSubmit(step, answer)
			end
		end)
	end
end

local function showExercise()
	current.filled = {}
	current.locked = false
	Ui.setGoal(current.ui.goal, exercise().goal, current.step, #current.puzzle.exercises)
	current.ui.output.Text = ""
	current.ui.instruction.Text = "Drag the right piece into the gap"
	current.ui.instruction.TextColor3 = Color3.new(1, 1, 1)
	buildCode()
	render()
end

-- Public ----------------------------------------------------------------------------

function CodingGame.open(puzzle, onSubmit)
	CodingGame.close()

	current = {
		puzzle = puzzle,
		onSubmit = onSubmit,
		step = 1,
		gaps = {},
		filled = {},
		locked = true, -- until the computer has booted
		ui = build(),
	}

	local state = current
	Ui.open(current.ui.root, function()
		for _, connection in state.dragConnections or {} do
			connection:Disconnect()
		end
		if current == state then
			current = nil
		end
	end)
	Ui.popIn(current.ui.window)

	task.spawn(function()
		if bootUp(state) then
			showExercise()
		end
	end)
end

function CodingGame.showResult(result)
	if not current or result.step ~= current.step then
		return
	end
	local step = current.step

	if result.correct then
		for _, gap in current.gaps do
			gap.Piece.ImageColor3 = Ui.Theme.Good
			Ui.popIn(gap)
		end
		current.ui.output.Text = "> " .. exercise().output
		current.ui.instruction.Text = if result.done then "You did it!" else "Nice!"
		current.ui.instruction.TextColor3 = Ui.Theme.Accent

		if not result.done then
			task.delay(1.4, function()
				if current and current.step == step then
					current.step += 1
					showExercise()
				end
			end)
		end
		return
	end

	-- Wrong: wiggle the wrong gaps, show the hint, give those pieces back
	for index, gap in current.gaps do
		if result.feedback and result.feedback[index] == false then
			gap.Piece.ImageColor3 = Ui.Theme.Bad
			task.spawn(Ui.wiggle, gap)
		end
	end
	current.ui.instruction.Text = "Hint: " .. exercise().hint
	current.ui.instruction.TextColor3 = Color3.fromRGB(255, 190, 190)

	task.delay(1, function()
		if not current or current.step ~= step then
			return
		end
		for index in current.gaps do
			if result.feedback and result.feedback[index] == false then
				current.filled[index] = nil
			end
		end
		current.locked = false
		render()
	end)
end

function CodingGame.close()
	if current then
		Ui.close(current.ui.root)
	end
end

return CodingGame
