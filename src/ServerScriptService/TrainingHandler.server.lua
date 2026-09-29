-- Script: ServerScriptService/TrainingHandler
-- Phase 4: Aktyvi treniruočių sistema (5 stats + fatigue), Private/Group sesijos
-- Fazė: pridėtas įrangos (EquipmentConfig) treniruočių efektyvumo bonusas

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)
local TrainingConfig = require(ReplicatedStorage.Modules.TrainingConfig)
local EquipmentConfig = require(ReplicatedStorage.Modules.EquipmentConfig)
local InjuryConfig = require(ReplicatedStorage.Modules.InjuryConfig)
local StaffConfig = require(ReplicatedStorage.Modules.StaffConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TrainingRequest = Remotes:WaitForChild("TrainingRequest")
local TrainingUpdate = Remotes:WaitForChild("TrainingUpdate")

-- Palaukiam kol DataStoreHandler užregistruoja _G.CoachAcademyData (Script vykdymo tvarka nėra garantuota)
local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end

local dataApi = getDataApi()

-- Fazė 5: pradinis "Alex Martin" narys -- jau įsteigtas (Member), ne bandomasis (Trial) klientas
local function ensureStarterStudent(profile)
	if #profile.studentsList == 0 then
		local starter = DataSchema.newStudent("Alex Martin")
		starter.karjerosStadija = "Member"
		starter.satisfactionScore = 100
		starter.morale = 100
		table.insert(profile.studentsList, starter)
	end
end

-- Grąžina treniruojamą studentą pagal indeksą (numatytasis: pirmas), su ribų patikra
local function getStudent(profile, studentIndex)
	ensureStarterStudent(profile)
	local index = studentIndex
	if type(index) ~= "number" or index < 1 or index > #profile.studentsList then
		index = 1
	end
	return profile.studentsList[index], index
end

local function pushUpdate(player, profile, message)
	TrainingUpdate:FireClient(player, {
		pinigai = profile.pinigai,
		studentsList = profile.studentsList,
		message = message,
	})
end

local function getEquipmentMultiplier(profile, focusName)
	local multiplier = 1
	for _, itemId in ipairs(profile.unlockedEquipment) do
		local item = EquipmentConfig.Items[itemId]
		if item and item.focus == focusName then
			multiplier *= item.multiplier
		end
	end
	return multiplier
end

-- Banga 3, #1: ar profilis turi pasamdytą tam tikro roleId personalą
local function hasStaffRole(profile, roleId)
	for _, id in ipairs(profile.staff or {}) do
		if id == roleId then
			return true
		end
	end
	return false
end

-- Banga 3, #1: pasamdytas personalas (Jėgos/Greičio treneris) prideda papildomą treniruočių daugiklį
-- pasirinktam fokusui, panašiai kaip įranga.
local function getStaffTrainingMultiplier(profile, focusName)
	local multiplier = 1
	for _, roleId in ipairs(profile.staff or {}) do
		local role = StaffConfig.Roles[roleId]
		if role and role.focus and table.find(role.focus, focusName) then
			multiplier *= role.trainingMultiplier
		end
	end
	return multiplier
end

-- Banga 2: prieaugis ribojamas paslėpta genetine "luba" -- kuo arčiau lubos, tuo mažesnis efektyvumas
-- (natūraliai lėtėja, ne staigiai sustoja), ir niekada neviršija lubos.
local function statCapFor(student, statId)
	return (student.statPotential and student.statPotential[statId]) or TrainingConfig.MaxStat
end

local function trainedGain(currentValue, rawGain, cap)
	if rawGain <= 0 then
		return 0, false
	end
	local remaining = cap - currentValue
	if remaining <= 0 then
		return 0, true
	end
	local proximity = currentValue / cap
	local efficiency = 1
	if proximity >= 0.7 then
		efficiency = math.clamp(1 - (proximity - 0.7) / 0.3 * 0.8, 0.2, 1)
	end
	local gain = math.round(rawGain * efficiency)
	if gain < 1 then
		gain = 1
	end
	gain = math.min(gain, remaining)
	return gain, (currentValue + gain) >= cap
end

Players.PlayerAdded:Connect(function(player)
	if not dataApi then
		dataApi = getDataApi()
	end
	-- profilis įkeliamas DataStoreHandler.lua PlayerAdded (kita funkcija, kita eilė) -- palaukiam kol atsiras
	task.wait(0.5)
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 1200 do -- iki 60 s: profilis gali krautis su pakartojimais
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	if not profile then
		warn("TrainingHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end
	ensureStarterStudent(profile)
	pushUpdate(player, profile, "Welcome to your academy!")
end)

-- Lėtas fatigue "poilsis" ir morale drift laikui bėgant (kol žaidėjas online)
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = dataApi and dataApi.getProfile(player)
			if profile then
				-- Banga 3, #1: Fizioterapeutas pagreitina fatigue/traumos atsigavimą, Psichologas -- nuotaikos atsistatymą
				local physioMult = hasStaffRole(profile, "Physio") and (StaffConfig.Roles.Physio.fatigueRecoveryMultiplier or 1) or 1
				local physioInjuryMult = hasStaffRole(profile, "Physio") and (StaffConfig.Roles.Physio.injuryRecoveryMultiplier or 1) or 1
				local moraleDriftMult = hasStaffRole(profile, "MentalCoach") and (StaffConfig.Roles.MentalCoach.moraleDriftMultiplier or 1) or 1

				for _, student in ipairs(profile.studentsList) do
					student.fatigue = math.max(0, (student.fatigue or 0) - 3 * physioMult)

					-- Banga 2: morale lėtai grįžta link Default (į abi puses) kol niekas dramatiško nevyksta
					local default = DataSchema.Morale.Default
					local step = DataSchema.Morale.PassiveDriftPerTick * moraleDriftMult
					local morale = student.morale or default
					if morale < default then
						student.morale = math.min(default, morale + step)
					elseif morale > default then
						student.morale = math.max(default, morale - step)
					end

					-- Banga 2, #4: susižeidęs narys pasyviai gyja laikui bėgant
					if student.injured then
						student.injuryRecoverySeconds = math.max(0, (student.injuryRecoverySeconds or 0) - InjuryConfig.PassiveRecoveryPerTick * physioInjuryMult)
						if student.injuryRecoverySeconds <= 0 then
							student.injured = false
						end
					end
				end
			end
		end
	end
end)

TrainingRequest.OnServerEvent:Connect(function(player, focusName, sessionTypeName, studentIndex)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 1200 do -- iki 60 s: profilis gali krautis su pakartojimais
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	if not profile then
		warn("TrainingHandler: nepavyko rasti profilio treniruotės metu", player.Name)
		return
	end

	local focus = TrainingConfig.Focuses[focusName]
	local sessionType = TrainingConfig.SessionTypes[sessionTypeName]
	if not focus or not sessionType then
		warn("TrainingHandler: neteisingi treniruotės parametrai iš", player.Name, focusName, sessionTypeName)
		return
	end

	local student, index = getStudent(profile, studentIndex)

	if (student.fatigue or 0) >= TrainingConfig.FatigueTrainingBlockThreshold then
		pushUpdate(player, profile, student.name .. " is too tired to train — needs rest!")
		return
	end
	-- Banga 2, #4: susižeidęs narys negali treniruotis kol nepagis (arba nueina į Poilsio kambarį)
	if student.injured then
		pushUpdate(player, profile, student.name .. " is injured and can't train until healed (see Recovery Room in the Academy).")
		return
	end

	local isTrial = student.karjerosStadija == "Trial"

	-- Bandomojo laikotarpio (Trial) nariai treniruojasi nemokamai net ir pasirinkę Private sesiją
	if sessionTypeName == "Private" and not isTrial then
		if profile.pinigai < sessionType.cost then
			pushUpdate(player, profile, "Not enough money for a private session ($" .. sessionType.cost .. ")")
			return
		end
		profile.pinigai -= sessionType.cost
	end

	local equipmentMultiplier = getEquipmentMultiplier(profile, focusName)
	-- Banga 3, #1: pasamdytas Jėgos/Greičio treneris papildomai kelia treniruočių efektyvumą pagal fokusą
	local staffMultiplier = getStaffTrainingMultiplier(profile, focusName)

	-- Banga 2: žema nuotaika mažina treniruočių efektyvumą; taip pat pažymim ar narys jau buvo
	-- pervargęs PRIEŠ šią treniruotę (pertreniravimo nuotaikos bausmei žemiau)
	local moraleMultiplier = DataSchema.moraleMultiplier(student.morale)
	local wasOvertraining = (student.fatigue or 0) >= DataSchema.Morale.OvertrainingFatigueThreshold

	local stats = student.stats
	local rawPrimaryGain = math.round(focus.primaryDelta * sessionType.statMultiplier * equipmentMultiplier * staffMultiplier * moraleMultiplier)
	local rawSecondaryGain = math.round(focus.secondaryDelta * sessionType.statMultiplier * equipmentMultiplier * staffMultiplier * moraleMultiplier)
	-- HUD Personalo panelė: Mitybos specialistas mažina treniruočių nuovargį
	local nutritionMultiplier = StaffConfig.combinedMultiplier and StaffConfig.combinedMultiplier(profile.staff, "fatigueGainMultiplier") or 1
	local fatigueGain = math.round(focus.fatigueCost * sessionType.fatigueMultiplier * nutritionMultiplier)

	local primaryCap = statCapFor(student, focus.primary)
	local secondaryCap = statCapFor(student, focus.secondary)
	local primaryGain, primaryHitCap = trainedGain(stats[focus.primary], rawPrimaryGain, primaryCap)
	local secondaryGain, secondaryHitCap = trainedGain(stats[focus.secondary], rawSecondaryGain, secondaryCap)

	stats[focus.primary] = math.clamp(stats[focus.primary] + primaryGain, 0, TrainingConfig.MaxStat)
	stats[focus.secondary] = math.clamp(stats[focus.secondary] + secondaryGain, 0, TrainingConfig.MaxStat)
	student.fatigue = math.clamp((student.fatigue or 0) + fatigueGain, 0, TrainingConfig.MaxFatigue)

	local msg = string.format(
		"%s: %s +%d (now %d), %s +%d, Fatigue +%d%% (now %d%%)",
		student.name, focus.primary, primaryGain, stats[focus.primary],
		focus.secondary, secondaryGain, fatigueGain, student.fatigue
	)

	-- Banga 2: pertreniravimas (treniruotasi jau būnant labai pavargusiam) šiek tiek kenkia nuotaikai
	-- Banga 3, #1: Psichologas sumažina šią bausmę
	if wasOvertraining then
		local overtrainingMult = hasStaffRole(profile, "MentalCoach") and (StaffConfig.Roles.MentalCoach.overtrainingPenaltyMultiplier or 1) or 1
		local penalty = math.round(DataSchema.Morale.OvertrainingPenalty * overtrainingMult)
		student.morale = math.clamp((student.morale or DataSchema.Morale.Default) - penalty, DataSchema.Morale.Min, DataSchema.Morale.Max)
		msg = msg .. string.format(" | Overtrained — morale -%d (now %d)", penalty, student.morale)
	end

	-- Banga 2: kai stat pasiekia paslėptą genetinę lubą, žaidėjas tai sužino organiškai per pranešimą
	if primaryHitCap then
		msg = msg .. string.format(" | %s reached their natural %s limit.", student.name, focus.primary)
	end
	if secondaryHitCap and focus.secondary ~= focus.primary then
		msg = msg .. string.format(" | %s reached their natural %s limit.", student.name, focus.secondary)
	end

	-- Fazė 5: bandomojo laikotarpio pažanga -- pasitenkinimas, konversija arba pasitraukimas
	if isTrial then
		local trial = TrainingConfig.Trial
		student.trialSessionsCompleted = (student.trialSessionsCompleted or 0) + 1
		local gain = trial.satisfactionGainPerSession * (1 + (profile.gymLevel - 1) * 0.1)
		student.satisfactionScore = math.clamp((student.satisfactionScore or 50) + math.round(gain), 0, 100)
		msg = msg .. string.format(
			" | Trial: %d/%d sessions, satisfaction %d%%",
			student.trialSessionsCompleted, trial.maxSessions, student.satisfactionScore
		)

		if student.trialSessionsCompleted >= trial.maxSessions then
			if student.satisfactionScore >= trial.convertThreshold then
				student.karjerosStadija = "Member"
				profile.pinigai += trial.membershipFeeIncome
				profile.reputacija += trial.convertReputationBonus
				msg = msg .. string.format(
					" | %s became a full member! (+$%d, +%d reputation)",
					student.name, trial.membershipFeeIncome, trial.convertReputationBonus
				)
			else
				table.remove(profile.studentsList, index)
				profile.reputacija = math.max(0, profile.reputacija - trial.leaveReputationPenalty)
				msg = msg .. string.format(
					" | %s was unhappy and left the academy. (-%d reputation)",
					student.name, trial.leaveReputationPenalty
				)
			end
		end
	end

	-- Fazė 5: talento riba -- pažymime kaip "kovai paruoštas" (naudos Fazė 7 kovų sistema)
	if not student.competitionReady then
		local avgStat = (stats.power + stats.speed + stats.defense + stats.stamina + stats.technique) / 5
		if avgStat >= TrainingConfig.Trial.competitionReadyStatThreshold then
			student.competitionReady = true
			msg = msg .. string.format(" | %s is now ready to fight!", student.name)
		end
	end

	pushUpdate(player, profile, msg)
end)

print("TrainingHandler paruoštas.")
