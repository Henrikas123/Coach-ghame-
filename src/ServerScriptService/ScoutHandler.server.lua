-- Script: ServerScriptService/ScoutHandler
-- Banga 3, #2: skautų siuntimas ieškoti talentų + rastų kandidatų samdymas

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)
local ScoutConfig = require(ReplicatedStorage.Modules.ScoutConfig)
local StaffConfig = require(ReplicatedStorage.Modules.StaffConfig)
local MarketingConfig = require(ReplicatedStorage.Modules.MarketingConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ScoutSearchRequest = Remotes:WaitForChild("ScoutSearchRequest")
local ScoutRecruitRequest = Remotes:WaitForChild("ScoutRecruitRequest")
local ScoutUpdate = Remotes:WaitForChild("ScoutUpdate")
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

-- HUD Skautų panelė: genetinės lubos (statPotential) klientui siunčiamos tik nupirkus Scout Report
local function publicCandidates(candidates)
	local list = {}
	for index, candidate in ipairs(candidates or {}) do
		list[index] = {
			name = candidate.name,
			potencialas = candidate.potencialas,
			personality = candidate.personality,
			recruitCost = candidate.recruitCost,
			reportPurchased = candidate.reportPurchased == true,
			statPotential = candidate.reportPurchased and candidate.statPotential or nil,
		}
	end
	return list
end

local function pushScoutUpdate(player, profile, message)
	ScoutUpdate:FireClient(player, {
		pinigai = profile.pinigai,
		scoutCandidates = publicCandidates(profile.scoutCandidates),
		lastScoutAt = profile.lastScoutAt,
		message = message,
	})
end

Players.PlayerAdded:Connect(function(player)
	if not dataApi then
		dataApi = getDataApi()
	end
	task.wait(0.6)
	local profile = getProfile(player)
	if not profile then
		warn("ScoutHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end
	if not profile.scoutCandidates then
		profile.scoutCandidates = {}
	end
	pushScoutUpdate(player, profile, nil)
end)

-- Sugeneruoja vieną kandidatą su iš anksto atskleistu potencialu (skirtingai nei atsitiktiniai walk-in klientai)
local function rollCandidate()
	local name = MarketingConfig.WalkInNames[math.random(1, #MarketingConfig.WalkInNames)]
	local statPotential = DataSchema.rollStatPotential()
	local potencialas = DataSchema.potentialLabelFromCaps(statPotential)
	local personality = DataSchema.PersonalityTypes[math.random(1, #DataSchema.PersonalityTypes)]
	return {
		name = name,
		statPotential = statPotential,
		potencialas = potencialas,
		personality = personality,
		recruitCost = ScoutConfig.RecruitCostByPotential[potencialas] or 150,
	}
end

ScoutSearchRequest.OnServerEvent:Connect(function(player)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("ScoutHandler: nepavyko rasti profilio paieškos metu", player.Name)
		return
	end
	if not profile.scoutCandidates then
		profile.scoutCandidates = {}
	end

	-- HUD Personalo panelė: pasamdytas Skautas pigina paiešką ir trumpina laukimą
	local scoutCost = math.floor(ScoutConfig.ScoutCost * StaffConfig.combinedMultiplier(profile.staff, "scoutCostMultiplier") + 0.5)
	local scoutCooldown = math.floor(ScoutConfig.ScoutCooldown * StaffConfig.combinedMultiplier(profile.staff, "scoutCooldownMultiplier") + 0.5)

	local now = os.time()
	local lastScout = profile.lastScoutAt or 0
	if now - lastScout < scoutCooldown then
		local waitSeconds = scoutCooldown - (now - lastScout)
		pushScoutUpdate(player, profile, string.format("Your scout is resting — wait %ds.", waitSeconds))
		return
	end

	if profile.pinigai < scoutCost then
		pushScoutUpdate(player, profile, string.format("Not enough money to send the scout ($%d).", scoutCost))
		return
	end

	profile.pinigai -= scoutCost
	profile.lastScoutAt = now

	local candidates = {}
	for _ = 1, ScoutConfig.CandidateCount do
		table.insert(candidates, rollCandidate())
	end
	profile.scoutCandidates = candidates

	if _G.CoachAcademyRetention then _G.CoachAcademyRetention.track(player, "scout", 1) end -- kasdienes uzduotys
	pushScoutUpdate(player, profile, string.format("Your scout found %d prospects!", #candidates))
end)

ScoutRecruitRequest.OnServerEvent:Connect(function(player, candidateIndex)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("ScoutHandler: nepavyko rasti profilio samdymo metu", player.Name)
		return
	end
	if not profile.scoutCandidates then
		profile.scoutCandidates = {}
	end

	local candidate = profile.scoutCandidates[candidateIndex]
	if not candidate then
		pushScoutUpdate(player, profile, "This prospect is no longer available.")
		return
	end

	local cost = candidate.recruitCost or ScoutConfig.RecruitCostByPotential[candidate.potencialas] or 150
	if profile.pinigai < cost then
		pushScoutUpdate(player, profile, string.format("Not enough money to sign %s ($%d).", candidate.name, cost))
		return
	end

	profile.pinigai -= cost
	table.remove(profile.scoutCandidates, candidateIndex)

	local student = DataSchema.newStudent(candidate.name)
	student.statPotential = candidate.statPotential
	student.potencialas = candidate.potencialas
	student.personality = candidate.personality
	student.karjerosStadija = "Member" -- skautas atveda jau paruoštą narį, be bandomojo laikotarpio
	student.satisfactionScore = 80
	table.insert(profile.studentsList, student)

	pushScoutUpdate(player, profile, string.format("Signed: %s (%s)! -$%d", student.name, student.potencialas, cost))

	-- Atnaujinam ir TrainingUpdate, kad naujas narys iškart atsirastų treniruočių sąraše
	TrainingUpdate:FireClient(player, {
		pinigai = profile.pinigai,
		studentsList = profile.studentsList,
		message = string.format("%s joined your academy through your scout!", student.name),
	})
end)

-- HUD Skautų panelė: Scout Report pirkimas
local ScoutReportRequest = Remotes:FindFirstChild("ScoutReportRequest")
if not ScoutReportRequest then
	ScoutReportRequest = Instance.new("RemoteEvent")
	ScoutReportRequest.Name = "ScoutReportRequest"
	ScoutReportRequest.Parent = Remotes
end

ScoutReportRequest.OnServerEvent:Connect(function(player, candidateIndex)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile or type(candidateIndex) ~= "number" then
		return
	end
	local candidate = profile.scoutCandidates and profile.scoutCandidates[candidateIndex]
	if not candidate then
		pushScoutUpdate(player, profile, "This prospect is no longer available.")
		return
	end
	if candidate.reportPurchased then
		pushScoutUpdate(player, profile, string.format("You already have the report on %s.", candidate.name))
		return
	end
	local cost = ScoutConfig.ReportCost or 40
	if profile.pinigai < cost then
		pushScoutUpdate(player, profile, string.format("Not enough money for the scout report ($%d).", cost))
		return
	end
	profile.pinigai -= cost
	candidate.reportPurchased = true
	pushScoutUpdate(player, profile, string.format("Scout report: %s's potential ceiling revealed! -$%d", candidate.name, cost))
end)

_G.CoachAcademyScoutPublic = publicCandidates

print("ScoutHandler paruoštas.")
