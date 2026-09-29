-- ModuleScript: ReplicatedStorage/Modules/DataSchema
-- Phase 2 (2026-09-28 atnaujinta Phase 4): DataStore schemos numatytosios reikšmės
-- (PlayerProfile, Student, FighterCareer) -- 5-stat modelis (Power/Speed/Defense/Stamina/Technique)

local DataSchema = {}

DataSchema.PersonalityTypes = {
	"Aggressive", "Defensive", "Hard Worker", "Lazy",
	"Nervous", "Confident", "Disciplined", "Natural Talent",
}

DataSchema.FighterStyles = {
	"Pressure Fighter", "Counter Puncher", "Out-Boxer",
	"Slugger", "Technical Boxer", "Balanced",
}

DataSchema.CoachReputationTiers = {
	{ name = "Local Coach", stars = 1, winsRequired = 0 },
	{ name = "Rising Coach", stars = 2, winsRequired = 5 },
	{ name = "Respected Coach", stars = 3, winsRequired = 15 },
	{ name = "Elite Coach", stars = 4, winsRequired = 35 },
	{ name = "World-Class Coach", stars = 5, winsRequired = 70 },
}

DataSchema.StatIds = { "power", "speed", "defense", "stamina", "technique" }

-- Banga 2: kiekvienas stat turi paslėptą genetinę "lubą" -- fighter gali atrodyti vidutiniškas,
-- bet turėti vieną išskirtinį stat, kuris gali kilti gerokai aukščiau už kitus.
DataSchema.Genetics = {
	NormalMin = 40,
	NormalMax = 72,
	OutlierChance = 0.15,
	OutlierMin = 85,
	OutlierMax = 100,
}

function DataSchema.rollStatPotential()
	local caps = {}
	local g = DataSchema.Genetics
	for _, statId in ipairs(DataSchema.StatIds) do
		if math.random() < g.OutlierChance then
			caps[statId] = math.random(g.OutlierMin, g.OutlierMax)
		else
			caps[statId] = math.random(g.NormalMin, g.NormalMax)
		end
	end
	return caps
end

-- Banga 2, #3: motyvacijos/nuotaikos (morale) sistema -- kinta nuo pergalių/pralaimėjimų ir
-- pertreniravimo, lėtai grįžta prie numatytosios reikšmės laikui bėgant, veikia treniruočių
-- efektyvumą ir kovos rezultatą kai nukrenta žemiau ribos.
DataSchema.Morale = {
	Default = 70,
	Max = 100,
	Min = 0,
	WinGain = 12,
	LossPenalty = 15,
	OvertrainingFatigueThreshold = 65, -- jei fatigue prieš treniruotę >= šios ribos, treniruotė papildomai kenkia nuotaikai
	OvertrainingPenalty = 4,
	PassiveDriftPerTick = 2, -- lėtai grįžta link Default (į abi puses) kol žaidėjas online
	LowMoraleThreshold = 35, -- žemiau šios ribos treniruočių/kovos efektyvumas krenta
	PenaltyMax = 0.25, -- iki -25% efektyvumo kai morale = 0
	EncourageGain = 20,
	EncourageCooldown = 300, -- sekundės tarp "Padrąsinti" paspaudimų tam pačiam nariui
}

-- Grąžina 0..1 daugiklį treniruočių prieaugiui / kovos rezultatui -- 1 = jokio poveikio (morale >= riba),
-- mažėja tiesiškai iki (1 - PenaltyMax) ties morale = 0.
function DataSchema.moraleMultiplier(morale)
	local m = morale or DataSchema.Morale.Default
	local threshold = DataSchema.Morale.LowMoraleThreshold
	if m >= threshold then
		return 1
	end
	local deficit = (threshold - m) / threshold
	return 1 - deficit * DataSchema.Morale.PenaltyMax
end

-- Grubi "Potencialas" etiketė žaidėjui (Common/Rare/Legendary), paskaičiuota iš paslėptų lubų --
-- nerodo tikslių skaičių, tik bendrą įspūdį apie fighter'io viršutinę ribą.
function DataSchema.potentialLabelFromCaps(caps)
	local maxCap = 0
	for _, value in pairs(caps) do
		if value > maxCap then
			maxCap = value
		end
	end
	if maxCap >= 90 then
		return "Legendary"
	elseif maxCap >= 75 then
		return "Rare"
	else
		return "Common"
	end
end

function DataSchema.newPlayerProfile()
	return {
		pinigai = 500,
		followers = 0,
		reputacija = 0, -- bendras patirties/pergalių skaitiklis, naudojamas reputacijos lygiui skaičiuoti
		coachReputationTier = 1, -- indeksas į CoachReputationTiers
		gymLevel = 1,
		studentsList = {},
		unlockedEquipment = { "PunchingBag" },
		reachAccumulated = 0, -- Phase 6: kaupiasi nuo postintos rinkodaros, atkeliavus walk-in resetinama
		walkInThreshold = 80, -- kiek reach reikia sekančiam walk-in (kyla po kiekvieno atėjusio kliento)
		lastPostTimes = {}, -- [contentTypeId] = os.time() paskutinio postinimo, cooldown skaičiavimui
		academyName = "Coach Academy", -- Fazė 8: akademijos pritaikymas
		wallColorIndex = 1, -- indeksas į AcademyConfig.WallColors
		logoIndex = 1, -- indeksas į AcademyConfig.Logos
		staff = {}, -- Banga 3, #1: samdyto personalo roleId sąrašas (žr. StaffConfig.Roles)
		scoutCandidates = {}, -- Banga 3, #2: paskutinio skauto paieškos rasti kandidatai (žr. ScoutConfig)
		lastScoutAt = 0, -- os.time() paskutinio skauto siuntimo, cooldown skaičiavimui
		sponsors = {}, -- Banga 3, #3: aktyvios remimo sutartys {configIndex, acceptedAt, nextCollectAt, expiresAt}
		sponsorOffers = {}, -- pasiulyti remeju configIndex sarasas (dar nepriimti)
		lastSponsorRefresh = 0, -- os.time() kada paskutini karta ieskota remeju

		lastTournamentAt = 0, -- os.time() paskutinio turnyro, cooldown skaiciavimui
	}
end

function DataSchema.newStudent(name)
	local statPotential = DataSchema.rollStatPotential()
	return {
		name = name or "New fighter",
		stats = {
			power = 1,
			speed = 1,
			defense = 1,
			stamina = 1,
			technique = 1,
		},
		fatigue = 0, -- 0-100, aukšta reikšmė = blogesni treniruočių/kovos rezultatai
		morale = DataSchema.Morale.Default, -- Banga 2: 0-100, žema reikšmė = blogesni treniruočių/kovos rezultatai
		lastEncourageAt = 0, -- Banga 2: os.time() paskutinio "Padrąsinti" panaudojimo, cooldown skaičiavimui
		injured = false, -- Banga 2, #4: ar narys šiuo metu susižeidęs (negali treniruotis/kovoti kol nepagis)
		injuryRecoverySeconds = 0, -- liko sekundžių iki pagijimo
		lastRecoveryRoomAt = 0, -- os.time() paskutinio Poilsio kambario panaudojimo, cooldown skaičiavimui
		personality = DataSchema.PersonalityTypes[math.random(1, #DataSchema.PersonalityTypes)],
		style = "Balanced",
		statPotential = statPotential, -- Banga 2: paslėptos per-stat genetinės lubos
		potencialas = DataSchema.potentialLabelFromCaps(statPotential), -- Common / Rare / Legendary (grubi etiketė)
		karjerosStadija = "Trial",
		satisfactionScore = 50,
		trialSessionsCompleted = 0, -- Fazė 5: kiek nemokamų bandomųjų treniruočių jau atlikta
		competitionReady = false, -- Fazė 5: talento riba pasiekta -- paruoštas kovoms (Fazė 7)
		record = { wins = 0, losses = 0, draws = 0 },
		titles = 0,
		careerEarnings = 0,
		memberSince = os.time(),
		careerTier = 1, -- Fazė 7: indeksas į FightConfig.Ladder (1=Local Amateur)
		tierWins = 0, -- Fazė 7: pergalės dabartiniame lygyje (resetinama pakilus į kitą lygį)
	}
end

function DataSchema.newFighterCareer()
	return {
		rank = nil,
		contractStatus = "None", -- None / Offered / Signed
		organizacija = nil, -- pvz. "WBF"
		belts = {},
		wins = 0,
		losses = 0,
	}
end

return DataSchema
