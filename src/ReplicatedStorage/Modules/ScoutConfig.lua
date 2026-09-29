-- ModuleScript: ReplicatedStorage/Modules/ScoutConfig
-- Banga 3, #2: skautų/talentų paieškos sistema -- už mokestį siunčiame skautą ieškoti talentingų kandidatų,
-- kurių potencialas atskleidžiamas iš anksto (skirtingai nei atsitiktiniai "walk-in" klientai iš rinkodaros),
-- o samdymas kainuoja daugiau už aukštesnį potencialą.

local ScoutConfig = {}

ScoutConfig.ScoutCost = 100
ScoutConfig.ScoutCooldown = 300 -- 5 min tarp paieškų
ScoutConfig.CandidateCount = 3

-- HUD Skautų panelė: "Scout Report" -- atskleidžia kandidato genetines statistikos lubas
ScoutConfig.ReportCost = 40

ScoutConfig.RecruitCostByPotential = {
	Common = 100,
	Rare = 250,
	Legendary = 600,
}

ScoutConfig.PotentialColors = {
	Common = Color3.fromRGB(190, 190, 190),
	Rare = Color3.fromRGB(100, 170, 235),
	Legendary = Color3.fromRGB(235, 185, 60),
}

return ScoutConfig
