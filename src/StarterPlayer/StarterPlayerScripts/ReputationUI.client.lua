-- LocalScript: StarterPlayer/StarterPlayerScripts/ReputationUI
-- Fazė: Trenerio reputacijos (žvaigždučių) lygio rodymas HUD'e

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ReputationUpdate = Remotes:WaitForChild("ReputationUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainHud = playerGui:WaitForChild("MainHUD")
local repLabel = mainHud:WaitForChild("ReputationLabel")

local function starString(stars)
	local filled = string.rep("★", stars)
	local empty = string.rep("☆", 5 - stars)
	return filled .. empty
end

ReputationUpdate.OnClientEvent:Connect(function(data)
	local text = starString(data.stars) .. " " .. data.tierName
	if data.nextTierWinsRequired then
		text = text .. string.format("  (%d/%d)", data.reputacija, data.nextTierWinsRequired)
	end
	repLabel.Text = text
end)

print("ReputationUI paruoštas.")
