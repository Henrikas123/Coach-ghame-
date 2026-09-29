-- ModuleScript: ReplicatedStorage/Modules/AcademyConfig
-- Fazė 8: Akademijos pritaikymo (sienų spalva, logotipas, pavadinimas) nustatymai

local AcademyConfig = {}

AcademyConfig.WallColors = {
	Color3.fromRGB(200, 195, 185), -- numatytoji (pilka)
	Color3.fromRGB(180, 60, 60), -- raudona
	Color3.fromRGB(60, 100, 180), -- mėlyna
	Color3.fromRGB(70, 150, 90), -- žalia
	Color3.fromRGB(210, 175, 55), -- auksinė
	Color3.fromRGB(60, 60, 70), -- juoda
}

AcademyConfig.Logos = { "🥊", "⭐", "🔥", "🛡️", "🏆" }

-- HUD Akademijos panelė: grindų pasirinkimai (GymLayout.Floor spalva + medžiaga).
-- 1-as variantas atitinka pradines grindis, todėl esami žaidėjai nieko nepastebės, kol nepasirinks kitų.
AcademyConfig.FloorOptions = {
	{ name = "Classic", color = Color3.fromRGB(150, 150, 150), material = "Plastic" },
	{ name = "Oak parquet", color = Color3.fromRGB(156, 112, 72), material = "WoodPlanks" },
	{ name = "Ring canvas", color = Color3.fromRGB(46, 72, 128), material = "Carpet" },
	{ name = "Red tatami", color = Color3.fromRGB(140, 36, 44), material = "Fabric" },
	{ name = "Black rubber", color = Color3.fromRGB(38, 38, 42), material = "Rubber" },
	{ name = "Concrete", color = Color3.fromRGB(118, 116, 112), material = "Concrete" },
}

AcademyConfig.MaxNameLength = 24
AcademyConfig.DefaultName = "Coach Academy"

return AcademyConfig
