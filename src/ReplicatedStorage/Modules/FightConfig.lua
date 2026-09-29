-- ModuleScript: ReplicatedStorage/Modules/FightConfig
-- Fazė 7+8: Kovų (auto-battle) sistemos ir karjeros kopėčių (Local Amateur -> Regional -> WBF) nustatymai

local FightConfig = {}

FightConfig.Rounds = 3

-- Statistikos svoriai skaičiuojant rango tašką per raundą
FightConfig.StatWeights = {
	power = 0.30,
	speed = 0.20,
	defense = 0.20,
	stamina = 0.15,
	technique = 0.15,
}

-- Kiek fatigue mažina studento efektyvumą (0-100 fatigue -> iki -30% efektyvumo)
FightConfig.FatiguePenaltyMax = 0.30

-- Atsitiktinumo diapazonas kiekvienam raundo taškui (85%-115%)
FightConfig.RandomMin = 0.85
FightConfig.RandomMax = 1.15

FightConfig.Ladder = {
	{
		id = "LocalAmateur",
		name = "Local Amateur",
		winsToPromote = 3,
		opponentStatMin = 6,
		opponentStatMax = 16,
		payoutWin = 30,
		payoutLoss = 10,
		reputationWin = 2,
	},
	{
		id = "Regional",
		name = "Regional",
		winsToPromote = 5,
		opponentStatMin = 16,
		opponentStatMax = 30,
		payoutWin = 70,
		payoutLoss = 20,
		reputationWin = 4,
	},
	{
		id = "WBF",
		name = "WBF",
		winsToPromote = math.huge, -- aukščiausias lygis -- toliau kaupia titulus/pergales
		opponentStatMin = 30,
		opponentStatMax = 55,
		payoutWin = 150,
		payoutLoss = 40,
		reputationWin = 8,
	},
}

FightConfig.OpponentNames = {
	"Marek Wolski", "Diego Ramos", "Sammy Cruz", "Viktor Orlov",
	"Kevin Brooks", "Big Tony Russo", "Hassan Ali", "Bruno Silva",
	"Artem Volkov", "Kurt Becker", "Jamal Carter", "Erik Lindqvist",
}

-- Korner koučingo pasirinkimai tarp raundų -- laikinas +boost pasirinktai statistikai kitam raundui
FightConfig.CornerOptions = {
	Power = { label = "Press forward", statBoost = "power", multiplier = 1.35 },
	Defense = { label = "Tight defense", statBoost = "defense", multiplier = 1.35 },
	Stamina = { label = "Breathe", statBoost = "stamina", multiplier = 1.35 },
	Technique = { label = "Clean technique", statBoost = "technique", multiplier = 1.35 },
}
FightConfig.CornerOptionOrder = { "Power", "Defense", "Stamina", "Technique" }

FightConfig.CornerChoiceTimeout = 20 -- sek. kiek laukiame žaidėjo pasirinkimo tarp raundų

-- Banga 2: kovos stiliaus dinamika -- kiekvienas stilius turi pranašumą prieš vieną kitą (5-stilių ciklas),
-- "Balanced" lieka neutralus (nei pranašumo, nei silpnybės niekam).
FightConfig.StyleAdvantage = {
	["Pressure Fighter"] = "Out-Boxer",
	["Out-Boxer"] = "Counter Puncher",
	["Counter Puncher"] = "Slugger",
	["Slugger"] = "Technical Boxer",
	["Technical Boxer"] = "Pressure Fighter",
}
FightConfig.StyleAdvantageMultiplier = 1.12
FightConfig.StyleDisadvantageMultiplier = 0.90
FightConfig.StyleChangeCost = 50 -- kaina pakeisti nario kovos stilių

-- 3 atskiros grey-box arenos -- Workspace pozicijos pagal ladder indeksą
FightConfig.ArenaPositions = {
	Vector3.new(150, 0, 0), -- Local Amateur
	Vector3.new(300, 0, 0), -- Regional
	Vector3.new(500, 0, 0), -- WBF
}

return FightConfig
