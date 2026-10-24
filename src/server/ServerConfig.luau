-- Server-only settings. Never move these into the replicated Config.

local ServerConfig = {}

ServerConfig.Solutions = {
	-- Correct order of block ids
	Coding = { "readInput", "ifCorrect", "showWelcome", "elseError" },

	-- [lineId] = is the student's answer correct
	Grading = {
		sam1 = true,
		sam2 = false, -- 62
		sam3 = true,
		lina1 = true,
		lina2 = false, -- 63
		lina3 = true,
	},
}

-- Minimum seconds between two requests on the same remote, per player
ServerConfig.RemoteCooldown = 0.5

-- A mission submitted faster than this is treated as suspicious
ServerConfig.MinMissionSeconds = 3

return ServerConfig
