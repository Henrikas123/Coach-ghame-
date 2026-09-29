local SponsorConfig = {}

SponsorConfig.RefreshCooldown = 900 -- s, tarp naujos remeju paieskos
SponsorConfig.MaxActiveSponsors = 3
SponsorConfig.OfferCount = 2
SponsorConfig.CollectCycleSeconds = 300 -- s, kas kiek kaupiasi pajamos

SponsorConfig.Sponsors = {
	{ name = "Hercules Sports", minStars = 1, signingBonus = 200, incomePerCycle = 25, durationSeconds = 3600, color = Color3.fromRGB(70,130,180) },
	{ name = "Oak Nutrition", minStars = 1, signingBonus = 220, incomePerCycle = 28, durationSeconds = 3600, color = Color3.fromRGB(150,110,60) },
	{ name = "Viking Apparel", minStars = 2, signingBonus = 400, incomePerCycle = 55, durationSeconds = 5400, color = Color3.fromRGB(150,40,40) },
	{ name = "Energy Plus", minStars = 2, signingBonus = 430, incomePerCycle = 60, durationSeconds = 5400, color = Color3.fromRGB(230,180,20) },
	{ name = "Ironclad Gear", minStars = 3, signingBonus = 700, incomePerCycle = 95, durationSeconds = 7200, color = Color3.fromRGB(90,90,100) },
	{ name = "Champions Studio", minStars = 3, signingBonus = 750, incomePerCycle = 105, durationSeconds = 7200, color = Color3.fromRGB(180,140,20) },
	{ name = "National Arena", minStars = 4, signingBonus = 1200, incomePerCycle = 170, durationSeconds = 9000, color = Color3.fromRGB(40,120,200) },
	{ name = "Legend Media", minStars = 5, signingBonus = 2000, incomePerCycle = 280, durationSeconds = 10800, color = Color3.fromRGB(200,30,120) },
}

return SponsorConfig
