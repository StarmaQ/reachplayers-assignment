--[[
	The campaign's settings. The main part is what decides how the campaign plays and
	performs; below it are placement and text.
	Visual tuning lives in the module that draws it, tracking settings in Tracker.
]]

local Config = {}

Config.Brand = "FindJob"
Config.EnabledOnStart = true

-------------------------------------------------------------------------------
-- MAIN CAMPAIGN SETTINGS (EDIT FOR CAMPAIGN PERFORMANCE AND SPECIFICATIONS) --
-------------------------------------------------------------------------------

-- Questions on the clipboard. Each answer gives points to one or more fields;
-- the field with the most points is the player's match.
Config.Questions = {
	{
		Text = "It's a free afternoon. What sounds the most fun?", -- player hobby preference
		Answers = {
			{ Text = "Building my own game", Scores = { SoftwareEngineer = 2 } },
			{ Text = "Showing a friend how to beat a level", Scores = { Teacher = 2 } },
			{ Text = "Cracking a tricky puzzle", Scores = { SoftwareEngineer = 1 } },
			{ Text = "Organizing a group hangout", Scores = { Teacher = 1 } },
		},
	},
	{
		Text = "Your friends usually come to you when...", -- player's usual real life skills
		Answers = {
			{ Text = "Something on their computer is broken", Scores = { SoftwareEngineer = 2 } },
			{ Text = "They don't understand their homework", Scores = { Teacher = 2 } },
			{ Text = "They have issues in their lives", Scores = {  Teacher = 3 } },
		},
	},
	{
		Text = "When approaching a problem...", -- problem solving mindset
		Answers = {
			{ Text = "You solve it via trial and error", Scores = { SoftwareEngineer = 2 } },
			{ Text = "You educate yourself on the subject first", Scores = { Teacher = 2 } },
			{ Text = "You look for someone else's available solution", Scores = { SoftwareEngineer = 3 } },
		},
	},
	{
		Text = "When explaining something to a teammate...", -- emotional intelligence vs effeciency
		Answers = {
			{ Text = "You have a long conversation about it", Scores = { Teacher = 3 } },
			{ Text = "You send them your notes", Scores = { SoftwareEngineer = 3 } },
		},
	},

	{
		Text = "When learning about a concept...", -- emotional intelligence vs objectivity
		Answers = {
			{ Text = "You prefer deconstruct it down into seperate abstract ideas", Scores = { Teacher = 3 } },
			{ Text = "You find a way to explain it to a 5-year-old", Scores = { SoftwareEngineer = 3 } },
		},
	},
}

-- When the points tie, this field wins
Config.TieBreakField = "Teacher"

-- The jobs a player can be matched to. Each one has a pedestal at the stand and a mission.
Config.Fields = {
	SoftwareEngineer = {
		DisplayName = "Software Engineer",
		StationName = "ComputerPedestal",
		PromptText = "Start coding",
		Hint = "Go to the computer!",
		MissionId = "Coding",
		Reveal = {
			"You approach problems effeciently and pragmatically.",
			"You think like a builder. That's a Software Engineer!",
			"Try it out: the computer over there has a little coding job for you.",
		},
	},
	Teacher = {
		DisplayName = "Teacher",
		StationName = "ExamPedestal",
		PromptText = "Grade exams",
		Hint = "Go to the exams!",
		MissionId = "Grading",
		Reveal = {
			"You value emotional intelligence!",
			"You love helping people get it. That's a Teacher!",
			"Try it out: grab the exams over there and grade them.",
		},
	},
}

-- The missions, with their answers. The server checks answers against this and only
-- sends the puzzles (without answers) to players.
Config.Missions = {
	-- Fill-the-gap exercises on the computer. {1}, {2} in a line are the gaps, Chips are
	-- the pieces to drag in, Answer is the chip for each gap and Output is what the
	-- screen prints once it's solved.
	Coding = {
		Exercises = {
			{
				Goal = "Give the player 3 lives",
				Lines = { "local lives = {1}" },
				Chips = { "3", "lives", "true" },
				Answer = { "3" },
				Hint = "Lives is a number. Which piece is a number?",
				Output = "lives is now 3",
			},
			{
				Goal = "You found 2 coins. Add them!",
				Lines = { "local coins = 5", "coins = coins {1} {2}" },
				Chips = { "+", "-", "2", "10" },
				Answer = { "+", "2" },
				Hint = "Adding uses +. How many coins did you find?",
				Output = "coins is now 7",
			},
			{
				Goal = "What will the computer print?",
				Lines = { "local a = 4", "local b = 5", "local c = a + b", "print(c)", "-- the screen shows: {1}" },
				Chips = { "9", "45", "ab" },
				Answer = { "9" },
				Hint = "a + b means 4 + 5.",
				Output = "9",
			},
		},
	},

	-- Quizzes to grade, one paper at a time. Correct says whether the student's answer is right.
	Grading = {
		Brief = "Tap ✓ or X for each answer",
		Papers = {
			{
				Student = "Sam",
				Lines = {
					{ Id = "sam1", Question = "7 x 8", Answer = "56", Correct = true },
					{ Id = "sam2", Question = "45 + 17", Answer = "52", Correct = false },
					{ Id = "sam3", Question = "81 / 9", Answer = "9", Correct = true },
				},
			},
			{
				Student = "Lina",
				Lines = {
					{ Id = "lina1", Question = "12 x 3", Answer = "36", Correct = true },
					{ Id = "lina2", Question = "100 - 37", Answer = "73", Correct = false },
					{ Id = "lina3", Question = "6 x 7", Answer = "42", Correct = true },
				},
			},
			{
				Student = "Noah",
				Lines = {
					{ Id = "noah1", Question = "9 + 6", Answer = "15", Correct = true },
					{ Id = "noah2", Question = "8 x 4", Answer = "36", Correct = false },
					{ Id = "noah3", Question = "50 - 18", Answer = "32", Correct = true },
				},
			},
			
		},
	},
}

-- Asked after the mission, to check whether the match was right (see Tracker: FitFeedback)
Config.FitCheck = {
	Question = "Did that job feel like you?",
	Yes = "Yes, I liked it!",
	No = "Not really",
	ThanksYes = "Awesome! Come back anytime to try another shift.",
	ThanksNo = "Thanks! Talk to Maya again to try the other job.",
}

-- What the host game should give the player. The campaign only announces it
-- through Campaign.RewardGranted, the host decides how to actually grant it, or discard it and grant something else.
Config.Reward = {
	Id = "findjob_coins",
	Type = "Currency",
	Amount = 100,
	DisplayText = "+100 Coins",
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- The stand and Maya sit in the place, in a Workspace folder named FolderName: move them
-- around in Studio like any model. Without that folder they're spawned from Assets at Origin.
Config.World = {
	FolderName = "FindJobCampaign",
	Origin = CFrame.new(0, 0, -20),
	GreetRadius = 25, -- Maya starts waving and the guide appears
	PromptDistance = 10,
}

Config.Recruiter = {
	Name = "Maya", -- on his name tag
	Role = "FindJob Recruiter",
	DisplayName = "Maya from FindJob", -- over her subtitles
	PromptText = "Talk",
	Greeting = {
		"Hey! Ever wondered what job would actually fit you?",
		"Here at FindJob, we help you find what career best suits you!",
		"Answer these quick questions and I'll set you up with a trial shift.",
	},
}

-- Text on the stand's screens
Config.Screens = {
	Headline = "Find the job that fits you",
	Tagline = "TWO QUESTIONS. ONE TRIAL SHIFT. ZERO BORING.",
	Desk = "Careers",
	TotemTop = "This could be you!",
	TotemLeft = "Future Programmer",
	TotemRight = "Future Teacher",
	CallToAction = "Talk to Maya!",
	Monitor = "Your next job is one quiz away",
	Ticker = { "Find the job that fits you", "Programmers wanted", "Teachers wanted", "Win coins" },
	DreamJobs = { "Programmer", "Teacher", "Designer", "Vet", "Chef", "Pilot", "Scientist", "Artist" },
}

return Config
