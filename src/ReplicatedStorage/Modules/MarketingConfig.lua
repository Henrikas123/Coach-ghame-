-- ModuleScript: ReplicatedStorage/Modules/MarketingConfig
-- Fazė 6: Rinkodaros (telefono) turinio tipai -- postinimas augina followers/reach,
-- o reach pritraukia naujus walk-in klientus į akademiją.

local MarketingConfig = {}

MarketingConfig.Items = {
	SparringClip = {
		id = "SparringClip",
		label = "Sparring clip",
		description = "A short sparring clip from your gym.",
		followersMin = 5,
		followersMax = 15,
		reachMin = 10,
		reachMax = 25,
		cooldown = 300, -- 5 min
		locked = false,
	},
	AcademyTour = {
		id = "AcademyTour",
		label = "Gym tour",
		description = "Show off your gym and equipment.",
		followersMin = 3,
		followersMax = 10,
		reachMin = 15,
		reachMax = 30,
		cooldown = 600, -- 10 min
		locked = false,
	},
	TransformationPost = {
		id = "TransformationPost",
		label = "Transformation story",
		description = "A before/after story of a fighter's progress.",
		followersMin = 8,
		followersMax = 20,
		reachMin = 20,
		reachMax = 40,
		cooldown = 900, -- 15 min
		locked = false,
	},
	CompetitionHighlight = {
		id = "CompetitionHighlight",
		label = "Fight highlights",
		description = "Best fight moments — unlocks once your fighters start competing.",
		followersMin = 20,
		followersMax = 50,
		reachMin = 40,
		reachMax = 80,
		cooldown = 1200, -- 20 min
		locked = true, -- Fazė 7: atrakinama su kovų sistema
	},
}

MarketingConfig.Order = { "SparringClip", "AcademyTour", "TransformationPost", "CompetitionHighlight" }

-- Kiek pakyla walkInThreshold po kiekvieno atėjusio walk-in kliento (sunkėja progresyviai)
MarketingConfig.WalkInThresholdStep = 40

-- Vardų sąrašas naujiems walk-in klientams generuoti
MarketingConfig.WalkInNames = {
	"Jake K.", "Mason R.", "Tyler B.", "Diego P.", "Lucas V.",
	"Emily S.", "Grace M.", "Chloe L.", "Ryan J.", "Maya D.",
	"Matt A.", "Owen N.", "Victor G.", "Ava Z.", "Noah T.",
}

return MarketingConfig
