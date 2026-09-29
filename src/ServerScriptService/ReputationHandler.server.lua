-- Script: ServerScriptService/ReputationHandler
-- Fazė: Trenerio reputacijos (žvaigždučių) lygio skaičiavimas ir siuntimas klientui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ReputationUpdate = Remotes:WaitForChild("ReputationUpdate")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end

local dataApi = getDataApi()

-- Randame aukščiausią lygį, kurio winsRequired <= reputacija
local function computeTierIndex(reputacija)
	local tierIndex = 1
	for i, tier in ipairs(DataSchema.CoachReputationTiers) do
		if reputacija >= tier.winsRequired then
			tierIndex = i
		end
	end
	return tierIndex
end

local function pushReputationUpdate(player, profile)
	local tier = DataSchema.CoachReputationTiers[profile.coachReputationTier]
	local nextTier = DataSchema.CoachReputationTiers[profile.coachReputationTier + 1]
	ReputationUpdate:FireClient(player, {
		reputacija = profile.reputacija,
		tierIndex = profile.coachReputationTier,
		tierName = tier.name,
		stars = tier.stars,
		nextTierWinsRequired = nextTier and nextTier.winsRequired or nil,
		nextTierName = nextTier and nextTier.name or nil,
	})
end

local function waitForProfile(player)
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 1200 do -- iki 60 s: profilis gali krautis su pakartojimais
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	return profile
end

Players.PlayerAdded:Connect(function(player)
	if not dataApi then
		dataApi = getDataApi()
	end
	task.wait(0.6)
	local profile = waitForProfile(player)
	if not profile then
		warn("ReputationHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end
	profile.coachReputationTier = computeTierIndex(profile.reputacija)
	pushReputationUpdate(player, profile)
end)

-- Periodiškai tikriname ar reputacija peraugo naują lygį. Reputacija keičiasi keliose vietose
-- (TrainingHandler'yje dabar per Trial konversiją, Fights sistemoje vėliau) -- šis polling
-- metodas veikia nepriklausomai nuo to, kur reputacija buvo pakeista.
task.spawn(function()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = dataApi and dataApi.getProfile(player)
			if profile then
				local newTier = computeTierIndex(profile.reputacija)
				if newTier ~= profile.coachReputationTier then
					profile.coachReputationTier = newTier
					pushReputationUpdate(player, profile)
				end
			end
		end
	end
end)

print("ReputationHandler paruoštas.")
