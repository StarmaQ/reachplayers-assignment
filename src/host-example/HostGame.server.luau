--[[
	Stand-in for the game the campaign is dropped into. Not part of the campaign package.
	Shows the only integration a host needs: grant the reward, and optionally toggle the campaign.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Campaign = require(ServerScriptService.FindJobCampaign)

-- The host's own currency
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	leaderstats.Parent = player
end)

Campaign.RewardGranted:Connect(function(player, reward)
	local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value += reward.Amount
	end
end)

-- Load / unload button (simulates a campaign being switched on and off live)
local toggleRemote = Instance.new("RemoteEvent")
toggleRemote.Name = "HostToggleCampaign"
toggleRemote.Parent = ReplicatedStorage

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
