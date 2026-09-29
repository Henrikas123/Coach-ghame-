-- Script: ServerScriptService/TutorialHandler
-- Tracks the first-5-minutes guide (TutorialConfig.Steps) in profile.tutorial = { step, counter, done }.
-- Returning players with progress skip it automatically. Events arrive through
-- _G.CoachAcademyTutorial.onEvent (forwarded by RetentionHandler.track).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TutorialConfig = require(Modules:WaitForChild("TutorialConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function remote(name)
	local existing = Remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = Remotes
	return created
end
local TutorialUpdate = remote("TutorialUpdate")
local TutorialRequest = remote("TutorialRequest")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end
local dataApi = getDataApi()

local STEPS = TutorialConfig.Steps

local function tutorialOf(profile)
	if type(profile.tutorial) ~= "table" then
		profile.tutorial = { step = 0, done = false }
	end
	return profile.tutorial
end

-- anything that shows the player has already played
local function hasProgress(profile)
	return (profile.reputacija or 0) > 0
		or (profile.lifetimeFightsWon or 0) > 0
		or (profile.followers or 0) > 0
		or #(profile.studentsList or {}) > 1
		or #(profile.staff or {}) > 0
end

local function push(player, profile, message)
	local t = tutorialOf(profile)
	TutorialUpdate:FireClient(player, {
		step = t.step or 0,
		counter = t.counter or 0,
		done = t.done == true,
		pinigai = profile.pinigai,
		message = message,
	})
end

local function finish(player, profile, rewarded)
	local t = tutorialOf(profile)
	t.done = true
	t.step = #STEPS + 1
	t.counter = 0
	local message = nil
	if rewarded then
		profile.pinigai += TutorialConfig.CompletionReward
		message = string.format("You're ready, Coach! Rookie bonus +$%d", TutorialConfig.CompletionReward)
	end
	push(player, profile, message)
	if _G.CoachAcademyRetention then
		_G.CoachAcademyRetention.push(player) -- the daily reward popup waits for the tutorial
	end
	if dataApi.saveNow then
		dataApi.saveNow(player)
	end
end

local function advance(player, profile)
	local t = tutorialOf(profile)
	t.step = (t.step or 0) + 1
	t.counter = 0
	if t.step > #STEPS then
		finish(player, profile, true)
	else
		push(player, profile)
	end
end

local function currentStep(profile)
	local t = tutorialOf(profile)
	if t.done then
		return nil
	end
	return STEPS[t.step or 0]
end

local function onEvent(player, event, amount)
	local profile = dataApi and dataApi.getProfile(player)
	if not profile then
		return
	end
	local step = currentStep(profile)
	if not step or step.kind ~= "event" or step.event ~= event then
		return
	end
	local t = tutorialOf(profile)
	t.counter = (t.counter or 0) + (amount or 1)
	if t.counter >= (step.count or 1) then
		advance(player, profile)
	else
		push(player, profile)
	end
end

TutorialRequest.OnServerEvent:Connect(function(player, action, argument)
	local profile = dataApi and dataApi.getProfile(player)
	if not profile or type(action) ~= "string" then
		return
	end
	local step = currentStep(profile)
	if action == "sync" then
		push(player, profile)
	elseif action == "skip" then
		if not tutorialOf(profile).done then
			finish(player, profile, false)
		end
	elseif step and action == "ack" and step.kind == "ack" then
		advance(player, profile)
	elseif step and action == "panel" and step.kind == "panel" and step.panel == argument then
		advance(player, profile)
	end
end)

local function onPlayerAdded(player)
	local profile = dataApi and dataApi.waitForProfile and dataApi.waitForProfile(player, 60)
	if not profile then
		return
	end
	local t = tutorialOf(profile)
	if not t.done and (t.step or 0) == 0 then
		if hasProgress(profile) then
			t.done = true
			if _G.CoachAcademyRetention then
				_G.CoachAcademyRetention.push(player)
			end
		else
			t.step = 1
			t.counter = 0
		end
	end
	push(player, profile)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

_G.CoachAcademyTutorial = {
	onEvent = onEvent,
}

print("TutorialHandler paruoštas.")
