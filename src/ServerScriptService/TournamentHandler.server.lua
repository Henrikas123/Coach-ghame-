-- Script: ServerScriptService/TournamentHandler
-- Banga 3, #4: Turnyru sistema

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)
local TournamentConfig = require(ReplicatedStorage.Modules.TournamentConfig)
local FightConfig = require(ReplicatedStorage.Modules.FightConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TournamentRefreshRequest = Remotes:WaitForChild("TournamentRefreshRequest")
local TournamentEnterRequest = Remotes:WaitForChild("TournamentEnterRequest")
local TournamentUpdate = Remotes:WaitForChild("TournamentUpdate")

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

local function getFightSim()
	local tries = 0
	while not _G.CoachAcademyFightSim and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyFightSim
end
local fightSim = getFightSim()

local activeTournament = {}

local function currentStars(profile)
	local stars = 1
	for _, tier in ipairs(DataSchema.CoachReputationTiers) do
		if (profile.reputacija or 0) >= (tier.winsRequired or 0) then
			stars = math.max(stars, tier.stars)
		end
	end
	return stars
end

local function pushUpdate(player, data)
	TournamentUpdate:FireClient(player, data)
end

local function buildStudentsPayload(profile)
	local list = {}
	for i, student in ipairs(profile.studentsList or {}) do
		list[#list + 1] = {
			index = i,
			name = student.name,
			careerTier = student.careerTier or 1,
			wins = student.record and student.record.wins or 0,
			losses = student.record and student.record.losses or 0,
			injured = student.injured or false,
			fatigue = student.fatigue or 0,
			tournamentWins = student.tournamentWins or 0,
		}
	end
	return list
end

local function sendList(player, profile, message)
	pushUpdate(player, {
		phase = "list",
		pinigai = profile.pinigai,
		reputacija = profile.reputacija,
		stars = currentStars(profile),
		students = buildStudentsPayload(profile),
		lastTournamentAt = profile.lastTournamentAt or 0,
		message = message,
	})
end

Players.PlayerAdded:Connect(function(player)
	local profile = getProfile(player)
	if profile then
		sendList(player, profile, nil)
	end
end)

TournamentRefreshRequest.OnServerEvent:Connect(function(player)
	local profile = getProfile(player)
	if not profile then
		return
	end
	sendList(player, profile, nil)
end)

TournamentEnterRequest.OnServerEvent:Connect(function(player, studentIndex, tournamentIndex)
	if activeTournament[player] then
		return
	end
	local profile = getProfile(player)
	if not profile then
		return
	end

	local tournament = TournamentConfig.Tournaments[tournamentIndex]
	if not tournament then
		pushUpdate(player, { phase = "error", message = "Neteisingas turnyras." })
		return
	end

	local student = profile.studentsList and profile.studentsList[studentIndex]
	if not student then
		pushUpdate(player, { phase = "error", message = "Neteisingas mokinys." })
		return
	end

	if student.injured then
		pushUpdate(player, { phase = "error", message = "Sis mokinys susizeides ir negali dalyvauti turnyre." })
		return
	end

	local stars = currentStars(profile)
	if stars < (tournament.minStars or 1) then
		pushUpdate(player, { phase = "error", message = "Reikia daugiau reputacijos zvaigdziu siam turnyrui." })
		return
	end

	local now = os.time()
	local lastAt = profile.lastTournamentAt or 0
	if now - lastAt < (TournamentConfig.EntryCooldown or 0) then
		pushUpdate(player, { phase = "error", message = "Palauk pries dalyvaudamas kitame turnyre." })
		return
	end

	if (profile.pinigai or 0) < (tournament.entryFee or 0) then
		pushUpdate(player, { phase = "error", message = "Nepakanka pinigu dalyvio mokesciui." })
		return
	end

	if not fightSim then
		pushUpdate(player, { phase = "error", message = "Turnyru sistema dar kraunasi, bandykite veliau." })
		return
	end

	activeTournament[player] = true
	profile.pinigai -= tournament.entryFee
	profile.lastTournamentAt = now

	local ladderIndex = math.clamp(tournament.opponentTier or 1, 1, #FightConfig.Ladder)
	local tier = FightConfig.Ladder[ladderIndex]

	local roundLog = {}
	local roundsWon = 0
	local eliminated = false

	for round = 1, tournament.rounds do
		if eliminated then
			break
		end
		local opponentName = TournamentConfig.OpponentNamePool[math.random(1, #TournamentConfig.OpponentNamePool)]
		local opponentStats = fightSim.randomOpponentStats(tier)
		local opponentStyle = fightSim.randomOpponentStyle()
		local myStyleMult = fightSim.styleMultiplier(student.style, opponentStyle)
		local oppStyleMult = fightSim.styleMultiplier(opponentStyle, student.style)
		local fatiguePenalty = math.clamp((student.fatigue or 0) / 100, 0, 0.5)

		local studentScore = fightSim.weightedScore(student.stats, nil, 1, fatiguePenalty, myStyleMult)
		local opponentScore = fightSim.weightedScore(opponentStats, nil, 1, 0, oppStyleMult)

		local won = studentScore >= opponentScore
		roundLog[#roundLog + 1] = {
			round = round,
			opponentName = opponentName,
			won = won,
		}
		if won then
			roundsWon += 1
		else
			eliminated = true
		end

		student.fatigue = math.clamp((student.fatigue or 0) + 4, 0, 100)
	end

	local champion = roundsWon >= tournament.rounds
	local rewardMoney = roundsWon * (tournament.rewardPerRoundWin or 0)
	local rewardReputation = roundsWon * (tournament.reputationPerRoundWin or 0)
	if champion then
		rewardMoney = rewardMoney + (tournament.championBonusMoney or 0)
		rewardReputation = rewardReputation + (tournament.championBonusReputation or 0)
		student.tournamentWins = (student.tournamentWins or 0) + 1
		-- Profilio panelės trofėjų lentyna: laimėti turnyrai pagal pavadinimą
		profile.trophies = profile.trophies or {}
		profile.trophies[tournament.name] = (profile.trophies[tournament.name] or 0) + 1
	end

	profile.pinigai += rewardMoney
	profile.reputacija += rewardReputation

	local message
	if champion then
		message = string.format("%s tapo %s čempionu! (+$%d, +%d reputacijos)", student.name, tournament.name, rewardMoney, rewardReputation)
	elseif roundsWon > 0 then
		message = string.format("%s iskrito is %s po %d pergale(-iu). (+$%d, +%d reputacijos)", student.name, tournament.name, roundsWon, rewardMoney, rewardReputation)
	else
		message = string.format("%s pralaimejo pirmame %s ture.", student.name, tournament.name)
	end

	activeTournament[player] = false

	pushUpdate(player, {
		phase = "result",
		pinigai = profile.pinigai,
		reputacija = profile.reputacija,
		tournamentName = tournament.name,
		roundsWon = roundsWon,
		totalRounds = tournament.rounds,
		champion = champion,
		rewardMoney = rewardMoney,
		rewardReputation = rewardReputation,
		rounds = roundLog,
		message = message,
	})
end)

print("TournamentHandler paleistas.")
