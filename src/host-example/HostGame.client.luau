-- Host game's load/unload button. Not part of the campaign package.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local toggleRemote = ReplicatedStorage:WaitForChild("HostToggleCampaign")

local gui = Instance.new("ScreenGui")
gui.Name = "HostCampaignToggle"
gui.ResetOnSpawn = false

local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0, 1)
button.Position = UDim2.new(0, 16, 1, -16)
button.Size = UDim2.fromOffset(180, 44)
button.Font = Enum.Font.GothamBold
button.TextSize = 16
button.TextColor3 = Color3.new(1, 1, 1)
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local function refresh()
	local isEnabled = ReplicatedStorage:GetAttribute("FindJobEnabled")
	button.Text = if isEnabled then "Unload FindJob" else "Load FindJob"
	button.BackgroundColor3 = if isEnabled then Color3.fromRGB(200, 70, 70) else Color3.fromRGB(60, 160, 90)
end

button.Activated:Connect(function()
	toggleRemote:FireServer()
end)
ReplicatedStorage:GetAttributeChangedSignal("FindJobEnabled"):Connect(refresh)
refresh()

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
