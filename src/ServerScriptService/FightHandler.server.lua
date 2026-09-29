-- Script: ServerScriptService/FightHandler
-- Fazė 7+8: Auto-battle kovų variklis, korner koučingas tarp raundų, karjeros kopėčios, arenų teleportacija

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)
local TrainingConfig = require(ReplicatedStorage.Modules.TrainingConfig)
local FightConfig = require(ReplicatedStorage.Modules.FightConfig)
local InjuryConfig = require(ReplicatedStorage.Modules.InjuryConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FightRequest = Remotes:WaitForChild("FightRequest")
local FightUpdate = Remotes:WaitForChild("FightUpdate")
local CornerChoice = Remotes:WaitForChild("CornerChoice")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end

local dataApi = getDataApi()

local activeFight = {} -- [player] = true kol kova vyksta -- apsauga nuo dvigubo FightRequest
local waitingForChoice = {} -- [player] = true kol laukiame CornerChoice
local chosenBoost = {} -- [player] = statId arba nil

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

local function push(player, data)
	FightUpdate:FireClient(player, data)
end

local function getTier(student)
	local index = math.clamp(student.careerTier or 1, 1, #FightConfig.Ladder)
	return FightConfig.Ladder[index], index
end

local function randomOpponentStats(tier)
	return {
		power = math.random(tier.opponentStatMin, tier.opponentStatMax),
		speed = math.random(tier.opponentStatMin, tier.opponentStatMax),
		defense = math.random(tier.opponentStatMin, tier.opponentStatMax),
		stamina = math.random(tier.opponentStatMin, tier.opponentStatMax),
		technique = math.random(tier.opponentStatMin, tier.opponentStatMax),
	}
end

local function weightedScore(stats, boostStat, boostMultiplier, fatiguePenalty, styleMult)
	local total = 0
	for statId, weight in pairs(FightConfig.StatWeights) do
		local value = stats[statId] or 0
		if boostStat == statId then
			value *= boostMultiplier
		end
		total += value * weight
	end
	if fatiguePenalty then
		total *= (1 - fatiguePenalty)
	end
	if styleMult then
		total *= styleMult
	end
	local randMult = FightConfig.RandomMin + math.random() * (FightConfig.RandomMax - FightConfig.RandomMin)
	return total * randMult
end

-- Banga 2: grąžina daugiklį myStyle vs opponentStyle -- pranašumas/silpnybė pagal FightConfig.StyleAdvantage ciklą,
-- "Balanced" (arba nežinomas stilius) visada neutralus.
local function styleMultiplier(myStyle, opponentStyle)
	if not myStyle or not opponentStyle or myStyle == opponentStyle then
		return 1
	end
	if FightConfig.StyleAdvantage[myStyle] == opponentStyle then
		return FightConfig.StyleAdvantageMultiplier
	elseif FightConfig.StyleAdvantage[opponentStyle] == myStyle then
		return FightConfig.StyleDisadvantageMultiplier
	end
	return 1
end

local function randomOpponentStyle()
	return DataSchema.FighterStyles[math.random(1, #DataSchema.FighterStyles)]
end

local function teleportTo(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 5, 0)))
	end
end

local function waitForCornerChoice(player)
	chosenBoost[player] = nil
	waitingForChoice[player] = true
	local elapsed = 0
	while waitingForChoice[player] and elapsed < FightConfig.CornerChoiceTimeout do
		task.wait(0.1)
		elapsed += 0.1
	end
	waitingForChoice[player] = false
	local choice = chosenBoost[player]
	chosenBoost[player] = nil
	return choice
end

CornerChoice.OnServerEvent:Connect(function(player, choiceId)
	if not waitingForChoice[player] then
		return
	end
	local option = FightConfig.CornerOptions[choiceId]
	if option then
		chosenBoost[player] = option.statBoost
	end
	waitingForChoice[player] = false
end)

local function runFight(player, profile, student, studentIndex)
	local tier, tierIndex = getTier(student)
	local opponentName = FightConfig.OpponentNames[math.random(1, #FightConfig.OpponentNames)]
	local opponentStats = randomOpponentStats(tier)
	local opponentStyle = randomOpponentStyle()
	local myStyleMult = styleMultiplier(student.style, opponentStyle)
	local oppStyleMult = styleMultiplier(opponentStyle, student.style)

	local styleNote = nil
	if myStyleMult > 1 then
		styleNote = string.format("Your style (%s) has the edge over %s (%s)!", student.style, opponentName, opponentStyle)
	elseif oppStyleMult > 1 then
		styleNote = string.format("%s's style (%s) has the edge over yours (%s)!", opponentName, opponentStyle, student.style)
	end

	local gymSpawnPos = Vector3.new(0, 1, 28)
	local arenaPos = FightConfig.ArenaPositions[tierIndex] or FightConfig.ArenaPositions[1]
	teleportTo(player, arenaPos)

	push(player, {
		phase = "start",
		tierName = tier.name,
		opponentName = opponentName,
		studentName = student.name,
		opponentStyle = opponentStyle,
		studentStyle = student.style,
		styleNote = styleNote,
	})
	task.wait(1.5)

	local studentRounds, opponentRounds = 0, 0
	local nextBoostStat = nil
	local fatiguePenalty = math.clamp((student.fatigue or 0) / 100, 0, 1) * FightConfig.FatiguePenaltyMax
	-- Banga 2: žema nuotaika sumažina kovos rezultatą, kaip ir stiliaus daugiklis
	local moraleMult = DataSchema.moraleMultiplier(student.morale)

	for round = 1, FightConfig.Rounds do
		local studentScore = weightedScore(student.stats, nextBoostStat, 1.35, fatiguePenalty, myStyleMult * moraleMult)
		local opponentScore = weightedScore(opponentStats, nil, 1, nil, oppStyleMult)
		nextBoostStat = nil

		local roundWinner
		if studentScore >= opponentScore then
			studentRounds += 1
			roundWinner = "student"
		else
			opponentRounds += 1
			roundWinner = "opponent"
		end

		push(player, {
			phase = "round",
			round = round,
			totalRounds = FightConfig.Rounds,
			studentScore = math.round(studentScore * 10) / 10,
			opponentScore = math.round(opponentScore * 10) / 10,
			roundWinner = roundWinner,
			studentRounds = studentRounds,
			opponentRounds = opponentRounds,
		})

		if round < FightConfig.Rounds then
			push(player, {
				phase = "corner",
				round = round,
				options = FightConfig.CornerOptionOrder,
			})
			local choice = waitForCornerChoice(player)
			nextBoostStat = choice
		end
	end

	local won = studentRounds > opponentRounds
	student.fatigue = math.clamp((student.fatigue or 0) + 15, 0, TrainingConfig.MaxFatigue)

	local resultMsg
	if won then
		student.record.wins += 1
		student.tierWins = (student.tierWins or 0) + 1
		student.careerEarnings = (student.careerEarnings or 0) + tier.payoutWin
		profile.pinigai += tier.payoutWin
		profile.reputacija += tier.reputationWin
		student.morale = math.clamp((student.morale or DataSchema.Morale.Default) + DataSchema.Morale.WinGain, DataSchema.Morale.Min, DataSchema.Morale.Max)
		resultMsg = string.format(
			"%s beat %s! (+$%d, +%d reputation, morale +%d)",
			student.name, opponentName, tier.payoutWin, tier.reputationWin, DataSchema.Morale.WinGain
		)

		local promoted = false
		if student.tierWins >= tier.winsToPromote and tierIndex < #FightConfig.Ladder then
			student.careerTier = tierIndex + 1
			student.tierWins = 0
			promoted = true
			resultMsg = resultMsg .. string.format(" | Promoted to %s!", FightConfig.Ladder[tierIndex + 1].name)
		end

		-- Banga 2, #4: net ir laimėjus yra maža rizika susižeisti, didesnė jei kova buvo sunki (aukštas fatigue)
		local winInjuryChance = InjuryConfig.ChanceOnFightWin
			+ (fatiguePenalty / FightConfig.FatiguePenaltyMax) * InjuryConfig.FatigueChanceBonusMax
		if math.random() < winInjuryChance then
			student.injured = true
			student.injuryRecoverySeconds = math.random(InjuryConfig.MinRecoverySeconds, InjuryConfig.MaxRecoverySeconds)
			resultMsg = resultMsg .. string.format(
				" | %s: %s (~%d min to heal).",
				InjuryConfig.severityLabel(student.injuryRecoverySeconds), student.name,
				math.ceil(student.injuryRecoverySeconds / 60)
			)
		end

		profile.lifetimeFightsWon = (profile.lifetimeFightsWon or 0) + 1
		if _G.CoachAcademyRetention then _G.CoachAcademyRetention.track(player, "fightWon", 1) end -- kasdienes uzduotys
		if _G.CoachAcademyRetention then _G.CoachAcademyRetention.track(player, "fightDone", 1) end -- pamoka
		push(player, {
			phase = "result",
			won = true,
			message = resultMsg,
			studentRounds = studentRounds,
			opponentRounds = opponentRounds,
			promoted = promoted,
			record = student.record,
			careerTier = student.careerTier,
		})
	else
		student.record.losses += 1
		profile.pinigai += tier.payoutLoss
		student.morale = math.clamp((student.morale or DataSchema.Morale.Default) - DataSchema.Morale.LossPenalty, DataSchema.Morale.Min, DataSchema.Morale.Max)
		resultMsg = string.format(
			"%s lost to %s. (+$%d for taking part, morale -%d)",
			student.name, opponentName, tier.payoutLoss, DataSchema.Morale.LossPenalty
		)

		-- Banga 2, #4: pralaimėjus rizika susižeisti didesnė, dar labiau auga jei fatigue buvo aukštas
		local lossInjuryChance = InjuryConfig.ChanceOnFightLoss
			+ (fatiguePenalty / FightConfig.FatiguePenaltyMax) * InjuryConfig.FatigueChanceBonusMax
		if math.random() < lossInjuryChance then
			student.injured = true
			student.injuryRecoverySeconds = math.random(InjuryConfig.MinRecoverySeconds, InjuryConfig.MaxRecoverySeconds)
			resultMsg = resultMsg .. string.format(
				" | %s: %s (~%d min to heal).",
				InjuryConfig.severityLabel(student.injuryRecoverySeconds), student.name,
				math.ceil(student.injuryRecoverySeconds / 60)			)
		end

		if _G.CoachAcademyRetention then _G.CoachAcademyRetention.track(player, "fightDone", 1) end -- pamoka
		push(player, {
			phase = "result",
			won = false,
			message = resultMsg,
			studentRounds = studentRounds,
			opponentRounds = opponentRounds,
			promoted = false,
			record = student.record,
			careerTier = student.careerTier,
		})
	end

	task.wait(2)
	teleportTo(player, gymSpawnPos)
end

FightRequest.OnServerEvent:Connect(function(player, studentIndex)
	if activeFight[player] then
		return
	end
	local profile = getProfile(player)
	if not profile then
		warn("FightHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end

	local student = profile.studentsList[studentIndex]
	if not student then
		push(player, { phase = "error", message = "Invalid fighter." })
		return
	end
	if not student.competitionReady then
		push(player, { phase = "error", message = student.name .. " is not ready to fight yet." })
		return
	end
	if (student.fatigue or 0) >= TrainingConfig.FatigueTrainingBlockThreshold then
		push(player, { phase = "error", message = student.name .. " is too tired to fight — needs rest!" })
		return
	end
	-- Banga 2, #4: susižeidęs narys negali kovoti kol nepagis (arba nueina į Poilsio kambarį)
	if student.injured then
		push(player, { phase = "error", message = student.name .. " is injured and can't fight until healed (see Recovery Room in the Academy)." })
		return
	end

	activeFight[player] = true
	local ok, err = pcall(runFight, player, profile, student, studentIndex)
	if not ok then
		warn("FightHandler: klaida kovos metu", err)
	end
	activeFight[player] = false
end)

Players.PlayerRemoving:Connect(function(player)
	activeFight[player] = nil
	waitingForChoice[player] = nil
	chosenBoost[player] = nil
end)

print("FightHandler paruoštas.")


-- Banga 3, #4: Turnyru sistemai eksportuojame kovos matematikos funkcijas
_G.CoachAcademyFightSim = {
	weightedScore = weightedScore,
	styleMultiplier = styleMultiplier,
	randomOpponentStats = randomOpponentStats,
	randomOpponentStyle = randomOpponentStyle,
	getTier = getTier,
}
