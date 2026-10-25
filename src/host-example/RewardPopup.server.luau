--[[
	The host game's reward, kept apart from the campaign: it listens to the campaign's
	RewardGranted and tells that player's client to show the host's own reward popup.
	A real game would also add the reward to its currency or inventory here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Campaign = require(ServerScriptService.FindJobCampaign.Server)

local showReward = ReplicatedStorage.HostRewardGranted

Campaign.RewardGranted:Connect(function(player, reward)
	showReward:FireClient(player, reward)
end)
