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
	{ name = "Klasikinės", color = Color3.fromRGB(150, 150, 150), material = "Plastic" },
	{ name = "Ąžuolo parketas", color = Color3.fromRGB(156, 112, 72), material = "WoodPlanks" },
	{ name = "Ringo kilimas", color = Color3.fromRGB(46, 72, 128), material = "Carpet" },
	{ name = "Raudonas tatamis", color = Color3.fromRGB(140, 36, 44), material = "Fabric" },
	{ name = "Juoda guma", color = Color3.fromRGB(38, 38, 42), material = "Rubber" },
	{ name = "Betonas", color = Color3.fromRGB(118, 116, 112), material = "Concrete" },
}

AcademyConfig.MaxNameLength = 24
AcademyConfig.DefaultName = "Coach Academy"

return AcademyConfig
