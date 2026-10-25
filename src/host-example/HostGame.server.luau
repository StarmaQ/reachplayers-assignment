--[[
	Stand-in for the game the campaign is dropped into. Not part of the campaign package.
	Shows how a host follows the campaign and toggles it. The reward is handled on its own,
	in RewardPopup.server.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Campaign = require(ServerScriptService.FindJobCampaign.Server)

-- Where players are in the campaign (a real host could pause a round timer, close shops...)
Campaign.MissionStarted:Connect(function(player, fieldId, missionId)
	print("[Host]", player.Name, "started the", missionId, "mission as", fieldId)
end)
Campaign.CampaignFinished:Connect(function(player, fieldId, agreed)
	print("[Host]", player.Name, "finished FindJob as", fieldId, "- liked it:", agreed)
end)

-- Load / unload button (simulates a campaign being switched on and off live)
local toggleRemote = ReplicatedStorage.HostToggleCampaign

toggleRemote.OnServerEvent:Connect(function()
	-- A real host would restrict this to admins
	if Campaign:IsEnabled() then
		Campaign:Disable()
	else
		Campaign:Enable()
	end
end)

Campaign.EnabledChanged:Connect(function(isEnabled)
	ReplicatedStorage:SetAttribute("FindJobEnabled", isEnabled)
end)
ReplicatedStorage:SetAttribute("FindJobEnabled", Campaign:IsEnabled())
