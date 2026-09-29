-- Script: ServerScriptService/MarketingHandler
-- Fazė 6: Rinkodaros (telefono) postinimo apdorojimas -- followers/reach augimas,
-- cooldown validacija, walk-in klientų generavimas kai reachAccumulated pasiekia walkInThreshold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)
local MarketingConfig = require(ReplicatedStorage.Modules.MarketingConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MarketingPostContent = Remotes:WaitForChild("MarketingPostContent")
local MarketingUpdate = Remotes:WaitForChild("MarketingUpdate")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end

local dataApi = getDataApi()

local function pushMarketingUpdate(player, profile, message)
	MarketingUpdate:FireClient(player, {
		followers = profile.followers,
		reachAccumulated = profile.reachAccumulated,
		walkInThreshold = profile.walkInThreshold,
		lastPostTimes = profile.lastPostTimes,
		studentsCount = #profile.studentsList,
		message = message,
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
		warn("MarketingHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end
	pushMarketingUpdate(player, profile, nil)
end)

local function generateWalkIn(profile)
	local name = MarketingConfig.WalkInNames[math.random(1, #MarketingConfig.WalkInNames)]
	local student = DataSchema.newStudent(name)
	student.karjerosStadija = "Trial"
	table.insert(profile.studentsList, student)
	return student
end

MarketingPostContent.OnServerEvent:Connect(function(player, contentTypeId)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = waitForProfile(player)
	if not profile then
		warn("MarketingHandler: nepavyko rasti profilio postinimo metu", player.Name)
		return
	end

	local item = MarketingConfig.Items[contentTypeId]
	if not item then
		warn("MarketingHandler: nežinomas contentTypeId iš", player.Name, contentTypeId)
		return
	end

	if item.locked then
		pushMarketingUpdate(player, profile, item.label .. " — coming soon!")
		return
	end

	local lastPost = profile.lastPostTimes[contentTypeId]
	local now = os.time()
	if lastPost and (now - lastPost) < item.cooldown then
		local remaining = item.cooldown - (now - lastPost)
		pushMarketingUpdate(player, profile, string.format("%s — wait %d s before posting again.", item.label, remaining))
		return
	end

	local followersGain = math.random(item.followersMin, item.followersMax)
	local reachGain = math.random(item.reachMin, item.reachMax)

	profile.followers += followersGain
	profile.reachAccumulated += reachGain
	profile.lastPostTimes[contentTypeId] = now

	local message = string.format("%s posted! +%d followers, +%d reach.", item.label, followersGain, reachGain)
	if _G.CoachAcademyRetention then _G.CoachAcademyRetention.track(player, "post", 1) end -- kasdienes uzduotys

	local newWalkIns = 0
	while profile.reachAccumulated >= profile.walkInThreshold do
		profile.reachAccumulated -= profile.walkInThreshold
		profile.walkInThreshold += MarketingConfig.WalkInThresholdStep
		local student = generateWalkIn(profile)
		newWalkIns += 1
		message = message .. string.format(" New client walked in: %s!", student.name)
	end

	pushMarketingUpdate(player, profile, message)
end)

print("MarketingHandler paruoštas.")
