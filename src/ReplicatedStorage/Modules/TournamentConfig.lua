local TournamentConfig = {}

TournamentConfig.EntryCooldown = 20 -- s tarp turnyru (apsauga nuo spam)

TournamentConfig.Tournaments = {
	{ name = "City Cup", minStars = 1, entryFee = 150, rounds = 3, opponentTier = 1,
	  rewardPerRoundWin = 70, reputationPerRoundWin = 3, championBonusMoney = 300, championBonusReputation = 12,
	  color = Color3.fromRGB(80, 150, 80) },
	{ name = "Regional Championship", minStars = 2, entryFee = 350, rounds = 3, opponentTier = 3,
	  rewardPerRoundWin = 150, reputationPerRoundWin = 6, championBonusMoney = 600, championBonusReputation = 20,
	  color = Color3.fromRGB(70, 110, 190) },
	{ name = "National Tournament", minStars = 3, entryFee = 700, rounds = 4, opponentTier = 5,
	  rewardPerRoundWin = 260, reputationPerRoundWin = 10, championBonusMoney = 1100, championBonusReputation = 32,
	  color = Color3.fromRGB(190, 150, 40) },
	{ name = "World Cup", minStars = 4, entryFee = 1400, rounds = 4, opponentTier = 7,
	  rewardPerRoundWin = 420, reputationPerRoundWin = 16, championBonusMoney = 2000, championBonusReputation = 50,
	  color = Color3.fromRGB(190, 60, 60) },
	{ name = "Legends Arena", minStars = 5, entryFee = 2800, rounds = 5, opponentTier = 9,
	  rewardPerRoundWin = 650, reputationPerRoundWin = 25, championBonusMoney = 4000, championBonusReputation = 90,
	  color = Color3.fromRGB(150, 40, 180) },
}

TournamentConfig.OpponentNamePool = {
	"Danny Cole", "Marcus Stone", "Tommy Reyes", "Rocco Vega", "Leon Price",
	"Jason Hart", "Andre Knox", "Marco Diaz", "Nate Steele", "Victor Oakes",
}

return TournamentConfig
