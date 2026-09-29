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
		label = "Asistentas treneris",
		description = "+10% naudos iš visų treniruočių",
		hireCost = 150,
		salary = 10,
		focus = { "Power", "Speed", "Defense", "Conditioning", "Technique" },
		trainingMultiplier = 1.1,
	},
	StrengthCoach = {
		label = "Jėgos treneris",
		description = "+20% naudos iš jėgos ir gynybos treniruočių",
		hireCost = 200,
		salary = 15, -- $ kas atlyginimo periodą (žr. PayrollIntervalSeconds)
		focus = { "Power", "Defense" },
		trainingMultiplier = 1.2,
	},
	SpeedCoach = {
		label = "Greičio treneris",
		description = "+20% naudos iš greičio ir technikos treniruočių",
		hireCost = 200,
		salary = 15,
		focus = { "Speed", "Technique" },
		trainingMultiplier = 1.2,
	},
	Physio = {
		label = "Fizioterapeutas",
		description = "+50% greitesnis pavargimo poilsis ir traumų atsigavimas",
		hireCost = 250,
		salary = 20,
		fatigueRecoveryMultiplier = 1.5,
		injuryRecoveryMultiplier = 1.5,
	},
	TalentScout = {
		label = "Skautas",
		description = "-30% talentų paieškos kaina, perpus trumpesnis laukimas",
		hireCost = 220,
		salary = 15,
		scoutCostMultiplier = 0.7,
		scoutCooldownMultiplier = 0.5,
	},
	NutritionCoach = {
		label = "Mitybos specialistas",
		description = "-25% nuovargio po kiekvienos treniruotės",
		hireCost = 180,
		salary = 12,
		fatigueGainMultiplier = 0.75,
	},
	MentalCoach = {
		label = "Psichologas",
		description = "+50% greitesnis nuotaikos atsistatymas, -50% pertreniravimo bausmė",
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
