-- Script: ServerScriptService/MoraleHandler
-- Banga 2, #3: leidžia žaidėjui "Padrąsinti" (Encourage) narį -- nemokamas, bet su cooldown, pakelia nuotaiką

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EncourageRequest = Remotes:WaitForChild("EncourageRequest")
local TrainingUpdate = Remotes:WaitForChild("TrainingUpdate")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end

local dataApi = getDataApi()

local function getProfile(player)
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 1200 do -- iki 60 s: profilis gali krautis su pakartojimais
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	return profile
end

local function pushUpdate(player, profile, message)
	TrainingUpdate:FireClient(player, {
		pinigai = profile.pinigai,
		studentsList = profile.studentsList,
		message = message,
	})
end

EncourageRequest.OnServerEvent:Connect(function(player, studentIndex)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("MoraleHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end

	local student = profile.studentsList[studentIndex]
	if not student then
		return
	end

	local now = os.time()
	local elapsed = now - (student.lastEncourageAt or 0)
	if elapsed < DataSchema.Morale.EncourageCooldown then
		local waitSeconds = DataSchema.Morale.EncourageCooldown - elapsed
		pushUpdate(player, profile, string.format("%s was encouraged recently — wait %ds.", student.name, waitSeconds))
		return
	end

	student.lastEncourageAt = now
	student.morale = math.clamp((student.morale or DataSchema.Morale.Default) + DataSchema.Morale.EncourageGain, DataSchema.Morale.Min, DataSchema.Morale.Max)
	if _G.CoachAcademyRetention then _G.CoachAcademyRetention.track(player, "encourage", 1) end -- kasdienes uzduotys
	pushUpdate(player, profile, string.format("You encouraged %s! Morale +%d (now %d)", student.name, DataSchema.Morale.EncourageGain, student.morale))
end)

print("MoraleHandler paruoštas.")
