-- Software Engineer mission: put the code blocks in the right order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.FindJobCampaign.Config)
local ServerConfig = require(script.Parent.Parent.ServerConfig)

local mission = Config.Missions.Coding
local solution = ServerConfig.Solutions.Coding

local Coding = {}

-- What gets sent to the client: shuffled blocks, no solution
function Coding.buildPuzzle()
	local blocks = table.clone(mission.Blocks)
	for i = #blocks, 2, -1 do
		local j = math.random(i)
		blocks[i], blocks[j] = blocks[j], blocks[i]
	end

	return {
		title = mission.Title,
		brief = mission.Brief,
		slotCount = mission.SlotCount,
		blocks = blocks,
	}
end

--[[
	TODO: validate the player's block order against `solution`.

	submission = { blockId, blockId, ... } in slot order (comes from the client, check its shape)

	Return { success = boolean, mistakes = number, feedback = { [slotIndex] = boolean } }
]]
function Coding.validate(submission)
	error("Coding.validate is not implemented yet")
end

return Coding
