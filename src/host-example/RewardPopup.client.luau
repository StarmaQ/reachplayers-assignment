-- The host game's reward popup (StarterGui.RewardPopup, made in Studio): slides in from the
-- top when the server says a reward was granted, then slides away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SHOWN_SECONDS = 3.5

local showReward = ReplicatedStorage:WaitForChild("HostRewardGranted")
local popup = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("RewardPopup")
local card = popup.Card
local hidden = card.Position
local shown = UDim2.new(hidden.X.Scale, hidden.X.Offset, 0, 24)

local function tween(instance, seconds, goal, style)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal)
	t:Play()
	return t
end

showReward.OnClientEvent:Connect(function(reward)
	card.Panel.Amount.Text = reward.DisplayText
	card.Position = hidden
	tween(card, 0.45, { Position = shown }, Enum.EasingStyle.Back)

	-- The coin spins in
	local coin = card.Panel.Coin
	coin.Rotation = -180
	tween(coin, 0.6, { Rotation = -10 }, Enum.EasingStyle.Back)

	task.wait(SHOWN_SECONDS)
	tween(card, 0.3, { Position = hidden })
end)
