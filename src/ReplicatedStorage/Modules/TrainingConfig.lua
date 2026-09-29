-- ModuleScript: ReplicatedStorage/Modules/TrainingConfig
-- Phase 4: treniruočių fokusų apibrėžimai -- aktyvus pasirinkimas su fatigue kaina

local TrainingConfig = {}

-- Kiekvienas fokusas: pagrindinė statistika +delta, antrinė statistika +delta, fatigue kaina (%)
TrainingConfig.Focuses = {
	Power = {
		label = "Power Training",
		primary = "power", primaryDelta = 2,
		secondary = "stamina", secondaryDelta = 1,
		fatigueCost = 9,
	},
	Speed = {
		label = "Speed Training",
		primary = "speed", primaryDelta = 2,
		secondary = "technique", secondaryDelta = 1,
		fatigueCost = 7,
	},
	Defense = {
		label = "Defense Training",
		primary = "defense", primaryDelta = 2,
		secondary = "stamina", secondaryDelta = 1,
		fatigueCost = 8,
	},
	Conditioning = {
		label = "Conditioning",
		primary = "stamina", primaryDelta = 2,
		secondary = "defense", secondaryDelta = 1,
		fatigueCost = 5,
	},
	Technique = {
		label = "Technique",
		primary = "technique", primaryDelta = 2,
		secondary = "speed", secondaryDelta = 1,
		fatigueCost = 6,
	},
}

-- Stočių numatytas (rekomenduojamas, bet nesaistantis) fokusas -- vien UI paaiškinimui
TrainingConfig.StationDefaultFocus = {
	PunchingBag = "Power",
	SpeedBag = "Speed",
	Treadmill = "Conditioning",
	DumbbellRack = "Defense",
	WeightBench = "Technique",
}

TrainingConfig.SessionTypes = {
	Private = {
		label = "Private session",
		cost = 50,
		statMultiplier = 1.5,
		fatigueMultiplier = 1.2,
	},
	Group = {
		label = "Group session",
		cost = 0,
		statMultiplier = 0.8,
		fatigueMultiplier = 0.8,
	},
}

TrainingConfig.MaxStat = 100
TrainingConfig.MaxFatigue = 100
TrainingConfig.FatigueTrainingBlockThreshold = 90 -- virš šios ribos treniruotis nebegalima kol nepailsi

-- Fazė 5: Bandomojo laikotarpio (Trial) nustatymai walk-in klientams
TrainingConfig.Trial = {
	maxSessions = 5, -- po kiek nemokamų treniruočių sprendžiama konvertuoti/palikti
	satisfactionGainPerSession = 12, -- bazinis pasitenkinimo prieaugis už treniruotę
	convertThreshold = 60, -- >= šios ribos po maxSessions -> tampa nariu
	membershipFeeIncome = 40, -- $ gaunama kai bandomasis narys tampa nuolatiniu
	convertReputationBonus = 2,
	leaveReputationPenalty = 1,
	competitionReadyStatThreshold = 15, -- vidutinis stat lygis nuo kurio narys laikomas "kovai paruoštas"
}

return TrainingConfig
