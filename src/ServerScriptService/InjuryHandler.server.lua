-- Script: ServerScriptService/InjuryHandler
-- Banga 2, #4: "Poilsio kambario" (Recovery Room) veiksmas -- mokamas pagijimo pagreitinimas

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InjuryConfig = require(ReplicatedStorage.Modules.InjuryConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RecoveryRequest = Remotes:WaitForChild("RecoveryRequest")
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

RecoveryRequest.OnServerEvent:Connect(function(player, studentIndex)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("InjuryHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end

	local student = profile.studentsList[studentIndex]
	if not student then
		return
	end

	if not student.injured or (student.injuryRecoverySeconds or 0) <= 0 then
		pushUpdate(player, profile, student.name .. " is not injured.")
		return
	end

	local now = os.time()
	local lastUse = student.lastRecoveryRoomAt or 0
	if now - lastUse < InjuryConfig.RecoveryRoomCooldown then
		local waitSeconds = InjuryConfig.RecoveryRoomCooldown - (now - lastUse)
		pushUpdate(player, profile, string.format("The Recovery Room is busy for %ds.", waitSeconds))
		return
	end

	if profile.pinigai < InjuryConfig.RecoveryRoomCost then
		pushUpdate(player, profile, string.format("Not enough money for the Recovery Room ($%d).", InjuryConfig.RecoveryRoomCost))
		return
	end

	profile.pinigai -= InjuryConfig.RecoveryRoomCost
	student.lastRecoveryRoomAt = now
	student.injuryRecoverySeconds = math.max(0, (student.injuryRecoverySeconds or 0) - InjuryConfig.RecoveryRoomReduceSeconds)

	local msg
	if student.injuryRecoverySeconds <= 0 then
		student.injured = false
		msg = string.format("%s is fully healed after the Recovery Room! (-$%d)", student.name, InjuryConfig.RecoveryRoomCost)
	else
		msg = string.format(
			"%s: the Recovery Room sped up healing, ~%d min left. (-$%d)",
			student.name, math.ceil(student.injuryRecoverySeconds / 60), InjuryConfig.RecoveryRoomCost
		)
	end

	pushUpdate(player, profile, msg)
end)

print("InjuryHandler paruoštas.")
