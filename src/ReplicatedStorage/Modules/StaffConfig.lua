-- ModuleScript: ReplicatedStorage/Modules/StaffConfig
-- Banga 3, #1: padėjėjų trenerių (personalo) apibrėžimai -- vienkartinė samdymo kaina + periodinis
-- atlyginimas, mainais į pasyvius bonusus treniruotėms/atsigavimui.

local StaffConfig = {}

-- HUD Personalo panelė: samdymo sąraše rodomi 5 koncepcijos tipai.
-- SpeedCoach ir MentalCoach lieka Roles lentelėje (esami išsaugoti profiliai ir TrainingHandler
-- juos naudoja), bet naujai nebesamdomi.
StaffConfig.Order = { "AssistantCoach", "StrengthCoach", "Physio", "TalentScout", "NutritionCoach" }

StaffConfig.Roles = {
	AssistantCoach = {
		label = "Assistant Coach",
		description = "+10% gains from all training",
		hireCost = 150,
		salary = 10,
		focus = { "Power", "Speed", "Defense", "Conditioning", "Technique" },
		trainingMultiplier = 1.1,
	},
	StrengthCoach = {
		label = "Strength Coach",
		description = "+20% gains from Power and Defense training",
		hireCost = 200,
		salary = 15, -- $ kas atlyginimo periodą (žr. PayrollIntervalSeconds)
		focus = { "Power", "Defense" },
		trainingMultiplier = 1.2,
	},
	SpeedCoach = {
		label = "Speed Coach",
		description = "+20% gains from Speed and Technique training",
		hireCost = 200,
		salary = 15,
		focus = { "Speed", "Technique" },
		trainingMultiplier = 1.2,
	},
	Physio = {
		label = "Physio",
		description = "+50% faster recovery from fatigue and injuries",
		hireCost = 250,
		salary = 20,
		fatigueRecoveryMultiplier = 1.5,
		injuryRecoveryMultiplier = 1.5,
	},
	TalentScout = {
		label = "Talent Scout",
		description = "-30% scouting cost and half the waiting time",
		hireCost = 220,
		salary = 15,
		scoutCostMultiplier = 0.7,
		scoutCooldownMultiplier = 0.5,
	},
	NutritionCoach = {
		label = "Nutritionist",
		description = "-25% fatigue after every session",
		hireCost = 180,
		salary = 12,
		fatigueGainMultiplier = 0.75,
	},
	MentalCoach = {
		label = "Sports Psychologist",
		description = "+50% faster morale recovery, -50% overtraining penalty",
		hireCost = 250,
		salary = 20,
		moraleDriftMultiplier = 1.5,
		overtrainingPenaltyMultiplier = 0.5,
	},
}

StaffConfig.PayrollIntervalSeconds = 300 -- 5 min tarp atlyginimų nurašymo

-- Visų pasamdytų darbuotojų bendras daugiklis pagal lauką (pvz. "scoutCostMultiplier")
function StaffConfig.combinedMultiplier(staffList, field)
	local multiplier = 1
	for _, roleId in ipairs(staffList or {}) do
		local role = StaffConfig.Roles[roleId]
		if role and type(role[field]) == "number" then
			multiplier *= role[field]
		end
	end
	return multiplier
end

return StaffConfig
