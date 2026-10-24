--[[
	Everything about the campaign that can be tweaked lives here: placement, dialogue,
	questions, missions, reward, visuals and tracking.

	This file replicates to clients, so it must not contain answers.
	Mission answer keys live in ServerScriptService.FindJobCampaign.ServerConfig.
]]

local Config = {}

Config.CampaignId = "findjob_career_match"
Config.Version = "1.0.0"
Config.EnabledOnStart = true

-- Where the FindJob building goes in the host world. Every host game sets this.
Config.World = {
	Origin = CFrame.new(0, 0, -30),
	GreetRadius = 25, -- recruiter starts waving and the guide appears
	PromptDistance = 10,

	-- Names inside Assets (must match the Blender export / Studio setup)
	BuildingName = "Building",
	RecruiterName = "Recruiter",
	RecruiterSpotName = "RecruiterSpot", -- invisible part in the building where the recruiter stands
}

-- Dashed circle + arrow that point the player to where they need to go
Config.Guide = {
	Color = Color3.fromRGB(255, 196, 0),
	CircleRadius = 3.5,
	ArrowHeight = 7,
	BobSpeed = 2,
}

Config.Recruiter = {
	DisplayName = "Maya from FindJob",
	PromptText = "Talk",
	TypewriterSpeed = 45, -- characters per second

	-- Roblox's own R15 emotes, so they work in any game without uploading anything
	Animations = {
		Wave = "rbxassetid://507770239",
		Talk = "rbxassetid://507770453", -- point
		Cheer = "rbxassetid://507770677",
	},

	Greeting = {
		"Hey! Ever wondered what job would actually fit you?",
		"Answer two quick questions and I'll set you up with a trial shift.",
	},
}

-- Each field gets a station inside the building and a mission
Config.Fields = {
	SoftwareEngineer = {
		DisplayName = "Software Engineer",
		StationName = "Computer",
		PromptText = "Start coding",
		MissionId = "Coding",
		Reveal = {
			"You think like a builder. That's a Software Engineer!",
			"Head to the computer, our login screen is broken and we need you.",
		},
	},
	Teacher = {
		DisplayName = "Teacher",
		StationName = "TeacherDesk",
		PromptText = "Grade exams",
		MissionId = "Grading",
		Reveal = {
			"You love helping people get it. That's a Teacher!",
			"The math quizzes just came in. Grab a pen at the desk.",
		},
	},
}

-- When scores tie, this field wins
Config.TieBreakField = "Teacher"

-- Each answer adds points to one or more fields. The field with the most points wins.
-- Adding a field or a question only needs changes here.
Config.Questions = {
	{
		Text = "It's a free afternoon. What sounds the most fun?",
		Answers = {
			{ Text = "Building my own game", Scores = { SoftwareEngineer = 2 } },
			{ Text = "Showing a friend how to beat a level", Scores = { Teacher = 2 } },
			{ Text = "Cracking a tricky puzzle", Scores = { SoftwareEngineer = 1 } },
			{ Text = "Organizing a group hangout", Scores = { Teacher = 1 } },
		},
	},
	{
		Text = "Your friends usually come to you when...",
		Answers = {
			{ Text = "Something on their computer is broken", Scores = { SoftwareEngineer = 2 } },
			{ Text = "They don't understand their homework", Scores = { Teacher = 2 } },
			{ Text = "They need a plan that actually works", Scores = { SoftwareEngineer = 1, Teacher = 1 } },
		},
	},
}

-- What the client needs to draw each mission. Answer keys are in ServerConfig.
Config.Missions = {
	Coding = {
		Title = "Fix the login screen",
		Brief = "Players can't log in! Drag the blocks into the right order.",
		SlotCount = 4,
		-- Kind only picks the block color: Input, Logic, Output or Action
		Blocks = {
			{ Id = "readInput", Text = "Read username and password", Kind = "Input" },
			{ Id = "ifCorrect", Text = "If the password is correct", Kind = "Logic" },
			{ Id = "showWelcome", Text = "Show the welcome screen", Kind = "Output" },
			{ Id = "elseError", Text = "Else show \"Wrong password\"", Kind = "Logic" },
			{ Id = "deleteAccount", Text = "Delete the account", Kind = "Action" },
			{ Id = "makeJump", Text = "Make the player jump", Kind = "Action" },
		},
	},

	Grading = {
		Title = "Grade the math quizzes",
		Brief = "Tick the right answers and cross out the wrong ones.",
		Papers = {
			{
				Student = "Sam",
				Lines = {
					{ Id = "sam1", Question = "7 x 8", Answer = "56" },
					{ Id = "sam2", Question = "45 + 17", Answer = "52" },
					{ Id = "sam3", Question = "81 / 9", Answer = "9" },
				},
			},
			{
				Student = "Lina",
				Lines = {
					{ Id = "lina1", Question = "12 x 3", Answer = "36" },
					{ Id = "lina2", Question = "100 - 37", Answer = "73" },
					{ Id = "lina3", Question = "6 x 7", Answer = "42" },
				},
			},
		},
	},
}

-- Asked after the mission to check whether the classification was right
Config.FitCheck = {
	Question = "Did that job feel like you?",
	Yes = "Yes, I liked it!",
	No = "Not really",
}

-- What the host game should give the player. The campaign only announces it
-- through Campaign.RewardGranted, the host decides how to actually grant it.
Config.Reward = {
	Id = "findjob_coins",
	Type = "Currency",
	Amount = 100,
	DisplayText = "+100 Coins",
}

-- Rendered in Blender (art/blender/build_ui_images.py) and uploaded to Roblox
Config.Images = {
	Clipboard = "rbxassetid://92010944905268",
	ExamPaper = "rbxassetid://93216377341597",
}

Config.Ui = {
	Font = Enum.Font.GothamBold,
	BodyFont = Enum.Font.Gotham,
	HandwritingFont = Enum.Font.PatrickHand,
	Brand = Color3.fromRGB(47, 111, 237),
	Accent = Color3.fromRGB(255, 196, 0),
	Good = Color3.fromRGB(60, 180, 90),
	Bad = Color3.fromRGB(225, 70, 70),
	Ink = Color3.fromRGB(35, 38, 48),
	Panel = Color3.fromRGB(255, 255, 255),
}

Config.Tracking = {
	Enabled = true,
	PrintToConsole = true,
}

return Config
