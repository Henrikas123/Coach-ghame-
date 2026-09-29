-- Script: ServerScriptService/StyleHandler
-- Banga 2, #2: leidžia žaidėjui pakeisti nario kovos stilių (už mokestį), validuoja ir išsaugo

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)
local FightConfig = require(ReplicatedStorage.Modules.FightConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StyleChangeRequest = Remotes:WaitForChild("StyleChangeRequest")
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
	while not profile and tries < 100 do
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

local function isValidStyle(styleId)
	for _, id in ipairs(DataSchema.FighterStyles) do
		if id == styleId then
			return true
		end
	end
	return false
end

StyleChangeRequest.OnServerEvent:Connect(function(player, studentIndex, newStyle)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("StyleHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end

	local student = profile.studentsList[studentIndex]
	if not student then
		return
	end

	if type(newStyle) ~= "string" or not isValidStyle(newStyle) then
		return
	end

	if student.style == newStyle then
		return
	end

	if profile.pinigai < FightConfig.StyleChangeCost then
		pushUpdate(player, profile, string.format("Not enough money to change style ($%d)", FightConfig.StyleChangeCost))
		return
	end

	profile.pinigai -= FightConfig.StyleChangeCost
	local oldStyle = student.style
	student.style = newStyle
	pushUpdate(player, profile, string.format("%s switched style: %s -> %s (-$%d)", student.name, oldStyle, newStyle, FightConfig.StyleChangeCost))
end)

print("StyleHandler paruoštas.")
