-- ModuleScript: ReplicatedStorage/Modules/EquipmentConfig
-- Fazė: Įrangos parduotuvė -- nusipirkta įranga duoda treniruočių efektyvumo bonusą pasirinktam fokusui

local EquipmentConfig = {}

EquipmentConfig.Order = { "PunchingBag2", "ProTreadmill", "HeavyDumbbells" }

EquipmentConfig.Items = {
	PunchingBag2 = {
		label = "Second heavy bag",
		description = "+20% gains from Power training",
		cost = 300,
		focus = "Power",
		multiplier = 1.2,
	},
	ProTreadmill = {
		label = "Pro treadmill",
		description = "+20% gains from Conditioning training",
		cost = 400,
		focus = "Conditioning",
		multiplier = 1.2,
	},
	HeavyDumbbells = {
		label = "Heavy dumbbells",
		description = "+20% gains from Defense training",
		cost = 350,
		focus = "Defense",
		multiplier = 1.2,
	},
}

return EquipmentConfig
