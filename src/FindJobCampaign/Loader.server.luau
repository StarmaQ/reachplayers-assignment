-- Installs the campaign. The whole package lives in ServerScriptService, where players can't
-- see it; this moves the parts players need (Client, Libraries, Remotes, Assets, Interface) into
-- ReplicatedStorage.FindJobCampaign, then starts the server. Server stays private.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = script.Parent

if ReplicatedStorage:FindFirstChild(package.Name) then
	warn("[FindJob] ReplicatedStorage already has a " .. package.Name .. ", replacing it")
	ReplicatedStorage[package.Name]:Destroy()
end

-- Parented last so clients receive everything in one go
local replicated = Instance.new("Folder")
replicated.Name = package.Name
for _, name in { "Libraries", "Remotes", "Assets", "Interface", "Client" } do
	package[name].Parent = replicated
end
replicated.Parent = ReplicatedStorage

require(package.Server):Start()
