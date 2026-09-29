--!nocheck
-- Preview scenarios: seed data + UI actions.

local S = {}

local function student(name, opts)
	local s = {
		name = name,
		stats = opts.stats or { power = 1, speed = 1, defense = 1, stamina = 1, technique = 1 },
		fatigue = opts.fatigue or 0,
		morale = opts.morale or 70,
		lastEncourageAt = opts.lastEncourageAt or 0,
		injured = opts.injured or false,
		injuryRecoverySeconds = opts.injuryRecoverySeconds or 0,
		lastRecoveryRoomAt = opts.lastRecoveryRoomAt or 0,
		personality = opts.personality or "Hard Worker",
		style = opts.style or "Balanced",
		statPotential = opts.statPotential or { power = 60, speed = 60, defense = 60, stamina = 60, technique = 60 },
		potencialas = opts.potencialas or "Common",
		karjerosStadija = opts.stage or "Member",
		satisfactionScore = opts.satisfaction or 80,
		trialSessionsCompleted = opts.sessions or 0,
		competitionReady = opts.ready or false,
		record = opts.record or { wins = 0, losses = 0, draws = 0 },
		titles = 0,
		careerEarnings = opts.earnings or 0,
		memberSince = opts.memberSince or 1789000000,
		careerTier = opts.tier or 1,
		tierWins = opts.tierWins or 0,
		tournamentWins = opts.tournamentWins or 0,
	}
	return s
end

local function richSeed(profile, now)
	profile.pinigai = 2450
	profile.reputacija = 22
	profile.followers = 1340
	profile.reachAccumulated = 95
	profile.walkInThreshold = 160
	profile.lastPostTimes = {
		SparringClip = now - 120,
		AcademyTour = now - 2000,
		TransformationPost = now - 400,
	}
	profile.academyName = "Vilniaus Kovos Akademija"
	profile.logoIndex = 3
	profile.wallColorIndex = 2
	profile.floorColorIndex = 2
	profile.gymLevel = 2
	profile.unlockedEquipment = { "PunchingBag", "PunchingBag2" }
	profile.staff = { "StrengthCoach", "Physio" }
	profile.sponsors = {
		{ configIndex = 1, acceptedAt = now - 600, nextCollectAt = now - 10, expiresAt = now + 3000 },
		{ configIndex = 3, acceptedAt = now - 300, nextCollectAt = now + 120, expiresAt = now + 5100 },
	}
	profile.sponsorOffers = { 4, 5 }
	profile.lastSponsorRefresh = now - 200
	profile.scoutCandidates = {}
	profile.lastScoutAt = now - 100
	profile.trophies = { ["Miesto Taure"] = 2, ["Regiono Cempionatas"] = 1 }
	profile.lifetimeEarned = 6420
	profile.lifetimeSpent = 3970
	profile.studentsList = {
		student("Alex Martin", {
			stats = { power = 34, speed = 28, defense = 30, stamina = 26, technique = 31 },
			statPotential = { power = 72, speed = 64, defense = 30, stamina = 58, technique = 70 },
			potencialas = "Rare", personality = "Disciplined", style = "Pressure Fighter",
			ready = true, record = { wins = 7, losses = 2, draws = 0 }, tier = 2, tierWins = 2,
			tournamentWins = 1, morale = 82, fatigue = 24, earnings = 540, memberSince = 1788000000,
		}),
		student("Mantas R.", {
			stats = { power = 19, speed = 22, defense = 15, stamina = 17, technique = 16 },
			statPotential = { power = 95, speed = 70, defense = 66, stamina = 61, technique = 58 },
			potencialas = "Legendary", personality = "Natural Talent", style = "Counter Puncher",
			ready = true, record = { wins = 3, losses = 1, draws = 0 }, tier = 1, tierWins = 2,
			morale = 31, fatigue = 72, lastEncourageAt = now - 100, memberSince = 1788500000,
		}),
		student("Gabija M.", {
			stats = { power = 14, speed = 17, defense = 16, stamina = 15, technique = 18 },
			potencialas = "Common", personality = "Nervous", style = "Out-Boxer",
			ready = true, record = { wins = 1, losses = 2, draws = 0 }, morale = 55, fatigue = 40,
			injured = true, injuryRecoverySeconds = 320, memberSince = 1788600000,
		}),
		student("Lukas V.", {
			stats = { power = 6, speed = 5, defense = 4, stamina = 7, technique = 5 },
			potencialas = "Rare", personality = "Hard Worker", stage = "Trial", sessions = 3, satisfaction = 64,
			memberSince = 1789900000,
		}),
		student("Ugnė D.", {
			stats = { power = 3, speed = 4, defense = 3, stamina = 2, technique = 4 },
			potencialas = "Common", personality = "Lazy", stage = "Trial", sessions = 1, satisfaction = 38,
			memberSince = 1789950000,
		}),
	}
end

local function freshSeed(profile, now)
	-- DataSchema.newPlayerProfile() + TrainingHandler starter student (Alex Martin)
end

-- ============================================================
-- PROFILE
-- ============================================================
S.profile = { seed = richSeed, run = function(api) api.open("Profile") end }
S.profile_scrolled = {
	seed = richSeed,
	run = function(api)
		api.open("Profile")
		api.scroll("Panel_Profile/Content", 400)
	end,
}
S.profile_fresh = { seed = freshSeed, run = function(api) api.open("Profile") end }
S.profile_hd = { seed = richSeed, viewport = "hd", run = function(api) api.open("Profile") end }
S.profile_phone = { seed = richSeed, viewport = "phone", run = function(api) api.open("Profile") end }
S.profile_small = { seed = richSeed, viewport = "small", run = function(api) api.open("Profile") end }

-- ============================================================
-- ACADEMY
-- ============================================================
S.academy = { seed = richSeed, run = function(api) api.open("Academy") end }
S.academy_scrolled = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.scroll("Panel_Academy/DetailColumn/Detail", 330)
	end,
}
S.academy_mantas = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/RosterList/Fighter_2")
		api.hover("Panel_Academy/StyleGrid/Style_4")
		api.click("Panel_Academy/StyleGrid/Style_1")
		api.scroll("Panel_Academy/DetailColumn/Detail", 380)
	end,
}
S.academy_injured = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/RosterList/Fighter_3")
		api.scroll("Panel_Academy/DetailColumn/Detail", 230)
	end,
}
S.academy_trial = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/RosterList/Fighter_4")
		api.scroll("Panel_Academy/DetailColumn/Detail", 230)
	end,
}
S.academy_equipment = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/Tabs/Tab_equipment")
	end,
}
S.academy_style = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/Tabs/Tab_style")
		api.click("Panel_Academy/SwatchRow4/Choice3")
	end,
}
S.academy_fresh = { seed = freshSeed, run = function(api) api.open("Academy") end }
S.academy_phone = { seed = richSeed, viewport = "phone", run = function(api) api.open("Academy") end }
S.academy_phone_detail = {
	seed = richSeed,
	viewport = "phone",
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/RosterList/Fighter_1")
	end,
}

-- Integration flows (real server handlers)
S.flow_buy_equipment = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/Tabs/Tab_equipment")
		api.click("Panel_Academy/Item_ProTreadmill/BuyButton")
		api.wait(1)
	end,
	check = function(api)
		local owned = api.profile().unlockedEquipment
		assert(table.find(owned, "ProTreadmill"), "ProTreadmill not bought")
		assert(api.profile().pinigai == 2450 - 400, "money not deducted: " .. api.profile().pinigai)
	end,
}
S.flow_style_change = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/StyleGrid/Style_4")
		api.click("Panel_Academy/StyleCard/ChangeStyleButton")
		api.wait(1)
	end,
	check = function(api)
		assert(api.profile().studentsList[1].style == "Slugger", "style not changed: " .. api.profile().studentsList[1].style)
	end,
}
S.flow_encourage = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/ConditionCard/EncourageButton")
		api.wait(1)
	end,
	check = function(api)
		assert(api.profile().studentsList[1].morale == 100, "morale not raised: " .. api.profile().studentsList[1].morale)
	end,
}
S.flow_recovery = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/RosterList/Fighter_3")
		api.click("Panel_Academy/InjuryCard/RecoveryButton")
		api.wait(1)
	end,
	check = function(api)
		local g = api.profile().studentsList[3]
		assert(g.injuryRecoverySeconds == 80, "recovery not applied: " .. g.injuryRecoverySeconds)
	end,
}
S.flow_customize = {
	seed = richSeed,
	run = function(api)
		api.open("Academy")
		api.click("Panel_Academy/Tabs/Tab_style")
		api.type("Panel_Academy/Form/TextBoxHolder/Input", "Kauno Bokso Klubas")
		api.click("Panel_Academy/SwatchRow4/Choice5")
		api.click("Panel_Academy/SwatchRow6/Choice3")
		api.click("Panel_Academy/SwatchRow8/Choice1")
		api.click("Panel_Academy/Actions/SaveButton")
		api.wait(1)
	end,
	check = function(api)
		local p = api.profile()
		assert(p.academyName == "Kauno Bokso Klubas", "name not saved: " .. tostring(p.academyName))
		assert(p.wallColorIndex == 5, "wall not saved")
		assert(p.logoIndex == 1, "logo not saved")
		assert(p.floorColorIndex == 3, "floor not saved: " .. tostring(p.floorColorIndex))
	end,
}

-- ============================================================
-- PHONE
-- ============================================================
S.phone = { seed = richSeed, run = function(api) api.open("Phone") end }
S.phone_scrolled = {
	seed = richSeed,
	run = function(api)
		api.open("Phone")
		api.scroll("Panel_Phone/Page_posts", 260)
	end,
}
S.phone_clients = {
	seed = richSeed,
	run = function(api)
		api.open("Phone")
		api.click("Panel_Phone/TabBar/Tab_clients")
	end,
}
S.phone_fighters = {
	seed = richSeed,
	run = function(api)
		api.open("Phone")
		api.click("Panel_Phone/TabBar/Tab_fighters")
	end,
}
S.phone_fresh = { seed = freshSeed, run = function(api) api.open("Phone") end }
S.phone_phone = { seed = richSeed, viewport = "phone", run = function(api) api.open("Phone") end }
S.flow_post = {
	seed = function(profile, now)
		richSeed(profile, now)
		profile.reachAccumulated = 150
	end,
	run = function(api)
		api.open("Phone")
		api.click("Panel_Phone/Post_AcademyTour/PostButton")
		api.wait(1.2)
	end,
	check = function(api)
		local p = api.profile()
		assert(p.followers > 1340, "followers not increased")
		assert(#p.studentsList == 6, "walk-in not generated: " .. #p.studentsList)
	end,
}

-- ============================================================
-- HUD + switching
-- ============================================================
S.hud_only = { seed = richSeed }
S.switch_panels = {
	seed = richSeed,
	run = function(api)
		api.open("Profile")
		api.open("Academy")
	end,
}
S.legacy_guard = {
	seed = richSeed,
	legacyScripts = true,
	run = function(api)
		api.open("Academy")
	end,
}


-- ============================================================
-- STAFF / SCOUT / SPONSOR / TOURNAMENT
-- ============================================================
local function scoutSeed(profile, now)
	richSeed(profile, now)
	profile.lastScoutAt = now - 400
	profile.scoutCandidates = {
		{ name = "Rokas J.", statPotential = { power = 88, speed = 64, defense = 55, stamina = 70, technique = 61 },
		  potencialas = "Rare", personality = "Confident", recruitCost = 250, reportPurchased = true },
		{ name = "Emilija S.", statPotential = { power = 60, speed = 95, defense = 58, stamina = 66, technique = 72 },
		  potencialas = "Legendary", personality = "Natural Talent", recruitCost = 600 },
		{ name = "Paulius N.", statPotential = { power = 52, speed = 48, defense = 61, stamina = 57, technique = 44 },
		  potencialas = "Common", personality = "Lazy", recruitCost = 100 },
	}
end

local function sponsorReadySeed(profile, now)
	richSeed(profile, now)
	profile.lastSponsorRefresh = 0
end

S.staff = { seed = richSeed, run = function(api) api.open("Staff") end }
S.staff_fresh = { seed = freshSeed, run = function(api) api.open("Staff") end }
S.flow_hire = {
	seed = richSeed,
	run = function(api)
		api.open("Staff")
		api.click("Panel_Staff/Role_NutritionCoach/ActionButton")
		api.wait(1)
	end,
	check = function(api)
		assert(table.find(api.profile().staff, "NutritionCoach"), "NutritionCoach not hired")
		assert(api.profile().pinigai == 2450 - 180, "hire cost wrong " .. api.profile().pinigai)
	end,
}
S.flow_fire = {
	seed = richSeed,
	run = function(api)
		api.open("Staff")
		api.click("Panel_Staff/Role_Physio/ActionButton")
		api.wait(0.5)
		api.click("Panel_Staff/Role_Physio/ActionButton")
		api.wait(1)
	end,
	check = function(api)
		assert(not table.find(api.profile().staff, "Physio"), "Physio not fired")
	end,
}
S.staff_confirm = {
	seed = richSeed,
	run = function(api)
		api.open("Staff")
		api.click("Panel_Staff/Role_Physio/ActionButton")
	end,
}

S.scout = { seed = scoutSeed, run = function(api) api.open("Scout") end }
S.scout_scrolled = {
	seed = scoutSeed,
	run = function(api)
		api.open("Scout")
		api.scroll("Panel_Scout/Page_talent", 250)
	end,
}
S.scout_fresh = { seed = freshSeed, run = function(api) api.open("Scout") end }
S.scout_rivals = {
	seed = richSeed,
	run = function(api)
		api.open("Scout")
		api.click("Panel_Scout/Tabs/Tab_rivals")
	end,
}
S.flow_scout_search = {
	seed = function(profile, now)
		richSeed(profile, now)
		profile.lastScoutAt = 0
		table.insert(profile.staff, "TalentScout")
	end,
	run = function(api)
		api.open("Scout")
		api.click("Panel_Scout/SearchCard/SearchButton")
		api.wait(1)
	end,
	check = function(api)
		local p = api.profile()
		assert(#p.scoutCandidates == 3, "no candidates")
		assert(p.pinigai == 2450 - 70, "scout discount not applied: " .. p.pinigai)
	end,
}
S.flow_scout_report = {
	seed = scoutSeed,
	run = function(api)
		api.open("Scout")
		api.click("Panel_Scout/Candidate2/ReportButton")
		api.wait(1)
	end,
	check = function(api)
		local p = api.profile()
		assert(p.scoutCandidates[2].reportPurchased == true, "report not purchased")
		assert(p.pinigai == 2450 - 40, "report cost wrong " .. p.pinigai)
	end,
}
S.flow_scout_recruit = {
	seed = scoutSeed,
	run = function(api)
		api.open("Scout")
		api.click("Panel_Scout/Candidate1/RecruitButton")
		api.wait(1)
	end,
	check = function(api)
		local p = api.profile()
		assert(#p.studentsList == 6, "recruit failed")
		assert(p.studentsList[6].name == "Rokas J.", "wrong recruit")
	end,
}

S.sponsor = { seed = richSeed, run = function(api) api.open("Sponsor") end }
S.sponsor_scrolled = {
	seed = richSeed,
	run = function(api)
		api.open("Sponsor")
		api.scroll("Panel_Sponsor/Content", 300)
	end,
}
S.sponsor_fresh = { seed = freshSeed, run = function(api) api.open("Sponsor") end }
S.flow_sponsor_collect = {
	seed = richSeed,
	run = function(api)
		api.open("Sponsor")
		api.click("Panel_Sponsor/Contract1/CollectButton")
		api.wait(1)
	end,
	check = function(api)
		assert(api.profile().pinigai == 2450 + 25, "collect failed " .. api.profile().pinigai)
	end,
}
S.flow_sponsor_accept = {
	seed = richSeed,
	run = function(api)
		api.open("Sponsor")
		api.click("Panel_Sponsor/Offer1/AcceptButton")
		api.wait(1)
	end,
	check = function(api)
		local p = api.profile()
		assert(#p.sponsors == 3, "accept failed")
		assert(p.pinigai == 2450 + 430, "bonus wrong " .. p.pinigai)
	end,
}
S.flow_sponsor_refresh = {
	seed = function(profile, now)
		sponsorReadySeed(profile, now)
		profile.sponsors = {}
		profile.sponsorOffers = {}
	end,
	run = function(api)
		api.open("Sponsor")
		api.click("Panel_Sponsor/Summary/RefreshButton")
		api.wait(1)
	end,
	check = function(api)
		assert(#api.profile().sponsorOffers == 2, "no offers")
	end,
}

S.tournament = { seed = richSeed, run = function(api) api.open("Tournament") end }
S.tournament_locked = {
	seed = richSeed,
	run = function(api)
		api.open("Tournament")
		api.click("Panel_Tournament/TournamentList/Tournament_5")
	end,
}
S.tournament_career = {
	seed = richSeed,
	run = function(api)
		api.open("Tournament")
		api.click("Panel_Tournament/Tabs/Tab_career")
	end,
}
S.tournament_fresh = { seed = freshSeed, run = function(api) api.open("Tournament") end }
S.flow_tournament_enter = {
	seed = richSeed,
	run = function(api)
		api.open("Tournament")
		api.click("Panel_Tournament/TournamentList/Tournament_1")
		api.click("Panel_Tournament/Detail/EnterButton")
		api.wait(2)
		api.scroll("Panel_Tournament/Detail", 400)
	end,
	check = function(api)
		local p = api.profile()
		assert(p.lastTournamentAt > 0, "tournament not entered")
	end,
}
S.flow_career_fight = {
	seed = richSeed,
	run = function(api)
		api.open("Tournament")
		api.click("Panel_Tournament/Tabs/Tab_career")
		api.click("Panel_Tournament/Career1/FightButton")
		api.wait(50)
	end,
	check = function(api)
		local alex = api.profile().studentsList[1]
		assert(alex.record.wins + alex.record.losses == 10, "fight not resolved")
	end,
}
S.tournament_phone = { seed = richSeed, viewport = "phone", run = function(api) api.open("Tournament") end }
S.staff_phone = { seed = richSeed, viewport = "phone", run = function(api) api.open("Staff") end }

return S
