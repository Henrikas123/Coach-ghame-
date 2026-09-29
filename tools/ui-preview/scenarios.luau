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
	-- patyres zaidejas: pamoka baigta, siandienos prizas jau atsiimtas (kitaip atsidarytu Daily Goals)
	profile.tutorial = { step = 99, done = true }
	profile.daily = { lastClaimDay = now // 86400, streak = 1 }
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
	profile.trophies = { ["City Cup"] = 2, ["Regional Championship"] = 1 }
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
		api.click("Panel_Sponsor/OffersEmpty/SearchButton")
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
-- ============================================================
-- LOADING / TITLE
-- ============================================================
S.loading = { seed = richSeed, intro = true, bootWait = 1.9, settle = 0 }
S.loading_phone = { seed = richSeed, intro = true, viewport = "phone", bootWait = 1.9, settle = 0 }
S.loading_intro = { seed = richSeed, intro = true, bootWait = 3.55, settle = 0 }
S.title = { seed = richSeed, intro = true, bootWait = 12 }
S.title_new = { seed = freshSeed, intro = true, bootWait = 12 }
S.title_phone = { seed = richSeed, intro = true, viewport = "phone", bootWait = 12 }
S.flow_play = {
	seed = richSeed,
	intro = true,
	bootWait = 12,
	run = function(api)
		api.click("CoachTitleScreen/Content/TitleBlock/PlayButton")
		api.wait(1.5)
	end,
	check = function(api)
		local playerGui = api.find("MainHUD_Premium").Parent
		assert(playerGui:FindFirstChild("CoachTitleScreen") == nil, "title screen still exists")
		assert(playerGui:FindFirstChild("CoachLoadingScreen") == nil, "loading screen still exists")
		assert(api.find("MainHUD_Premium").Enabled == true, "HUD not re-enabled")
		assert(playerGui.Parent:GetAttribute("CoachIntro") == "playing", "intro state not playing")
		local camera = api.state().getService("Workspace").CurrentCamera
		assert(camera.CameraType.Name == "Custom", "camera not back to Custom: " .. tostring(camera.CameraType))
	end,
}
S.tournament_tape = {
	seed = richSeed,
	run = function(api)
		api.open("Tournament")
		api.click("Panel_Tournament/TournamentList/Tournament_2")
		api.scroll("Panel_Tournament/Detail", 520)
	end,
}
-- ============================================================
-- DUOMENU SAUGUMAS (DataStoreHandler su atminties DataStore)
-- ============================================================
local KEY = "Player_4815162342"
local function legacySave()
	-- senas formatas: profilis irasytas tiesiogiai, be naujuju lauku
	return { pinigai = 1234, reputacija = 7, coachReputationTier = 2, studentsList = {}, followers = 50 }
end
S.ds_roundtrip = {
	datastore = { data = { [KEY] = legacySave() } },
	allowNoProfile = true,
	run = function(api)
		local profile = api.data().getProfile(api.player())
		assert(profile, "profile not loaded")
		assert(profile.pinigai == 1234, "legacy money lost")
		assert(profile.daily and profile.daily.streak == 0, "new fields not filled in")
		assert(profile.dataVersion == 2, "dataVersion not set")
		profile.pinigai = 777
		profile.reputacija = 0 / 0 -- NaN would break every save
		api.serverRun(function()
			api.data().flushAll()
		end)
	end,
	check = function(api)
		local stored = api.state().dataStore.data[KEY]
		assert(stored.format == 2 and type(stored.profile) == "table", "not saved in the new format")
		assert(stored.profile.pinigai == 777, "money not saved")
		assert(stored.profile.reputacija == 0, "NaN not cleaned")
		assert(stored.lockedBy == nil, "lock not released on shutdown")
	end,
}
S.ds_load_fail = {
	datastore = { data = { [KEY] = legacySave() }, failCalls = 99 },
	allowNoProfile = true,
	bootWait = 45,
	run = function(api)
		api.serverRun(function()
			api.data().flushAll()
		end)
	end,
	check = function(api)
		assert(api.data().getProfile(api.player()) == nil, "an empty profile was handed out")
		assert(api.world().kicked, "player was not asked to rejoin")
		local stored = api.state().dataStore.data[KEY]
		assert(stored.pinigai == 1234, "real save was overwritten")
	end,
}
S.ds_locked = {
	datastore = {
		data = { [KEY] = { format = 2, lockedBy = "other-server", lockedAt = 1790000000, savedAt = 1790000000, profile = legacySave() } },
	},
	allowNoProfile = true,
	bootWait = 45,
	run = function(api)
		local profile = api.data().getProfile(api.player())
		assert(profile and profile.pinigai == 1234, "profile not taken over after waiting for the other server")
	end,
	check = function(api)
		local stored = api.state().dataStore.data[KEY]
		assert(stored.lockedBy ~= "other-server", "lock not taken over")
	end,
}
-- ============================================================
-- DAILY GOALS (kasdienis prizas, uzduotys, lyderiu lenta)
-- ============================================================
local DAY = 1790000000 // 86400
local function goalsSeed(profile, now)
	richSeed(profile, now)
	profile.tutorial = { step = 99, done = true }
	profile.daily = { lastClaimDay = DAY - 1, streak = 2 }
	profile.quests = { day = DAY, list = {
		{ id = "train5", progress = 5, claimed = false },
		{ id = "win2", progress = 1, claimed = false },
		{ id = "post3", progress = 3, claimed = true },
	} }
end
S.goals = { seed = goalsSeed, run = function(api) api.ensureOpen("Goals") end }
S.goals_phone = { seed = goalsSeed, viewport = "phone", run = function(api) api.ensureOpen("Goals") end }
S.goals_board = {
	seed = goalsSeed,
	run = function(api)
		api.ensureOpen("Goals")
		api.click("Panel_Goals/Tabs/Tab_board")
		api.wait(2)
	end,
}
S.flow_daily_claim = {
	seed = goalsSeed,
	run = function(api)
		api.ensureOpen("Goals")
		api.click("Panel_Goals/StreakCard/ClaimButton")
		api.wait(1)
	end,
	check = function(api)
		local p = api.profile()
		assert(p.daily.streak == 3 and p.daily.lastClaimDay == DAY, "streak not advanced")
		assert(p.pinigai == 2450 + 200, "day 3 reward not paid: " .. tostring(p.pinigai))
	end,
}
S.flow_quest_claim = {
	seed = goalsSeed,
	run = function(api)
		api.ensureOpen("Goals")
		api.click("Panel_Goals/Quest1/ClaimButton")
		api.wait(1)
	end,
	check = function(api)
		local p = api.profile()
		assert(p.quests.list[1].claimed == true, "quest not claimed")
		assert(p.pinigai == 2450 + 150, "quest reward not paid: " .. tostring(p.pinigai))
	end,
}
S.flow_daily_popup = {
	seed = goalsSeed,
	intro = true,
	bootWait = 12,
	run = function(api)
		api.click("CoachTitleScreen/Content/TitleBlock/PlayButton")
		api.wait(4)
	end,
	check = function(api)
		local goals = api.find("Panel_Goals")
		assert(goals and goals.Visible, "daily goals did not open after PLAY")
	end,
}
-- ============================================================
-- PAMOKA (naujas zaidejas)
-- ============================================================
S.tutorial_start = { seed = freshSeed }
S.tutorial_phone = { seed = freshSeed, viewport = "phone" }
S.flow_tutorial = {
	seed = freshSeed,
	run = function(api)
		api.click("CoachTutorial/Card/ActionButton") -- 1 welcome
		api.wait(1)
		api.open("Academy") -- 2 meet
		api.wait(1)
		api.state().sharedG.CoachAcademyRetention.track(api.player(), "train", 2) -- 3 train x2
		api.wait(0.5)
	end,
	check = function(api)
		local t = api.profile().tutorial
		assert(t.step == 4 and not t.done, "tutorial should be at the fight step, got " .. tostring(t.step))
		local alex = api.profile().studentsList[1]
		assert(alex and alex.stats.power == 14, "starter fighter should start at 14")
	end,
}
S.flow_tutorial_train = {
	seed = freshSeed,
	run = function(api)
		api.click("CoachTutorial/Card/ActionButton")
		api.wait(1)
		api.open("Academy")
		api.wait(1)
		api.open("Academy")
		local remote = api.state().getService("ReplicatedStorage").Remotes.TrainingRequest
		for _ = 1, 2 do
			api.serverRun(function()
				remote.OnServerEvent:Fire(api.player(), "Power", "Group", 1)
			end, 2)
		end
	end,
	check = function(api)
		local alex = api.profile().studentsList[1]
		assert(alex.competitionReady == true, "Alex should be fight-ready after 2 sessions (power " .. tostring(alex.stats.power) .. ")")
		assert(api.profile().tutorial.step == 4, "tutorial did not count real training")
	end,
}
S.flow_tutorial_done = {
	seed = freshSeed,
	run = function(api)
		local retention = api.state().sharedG.CoachAcademyRetention
		api.click("CoachTutorial/Card/ActionButton")
		api.wait(1)
		api.open("Academy")
		api.wait(1)
		api.open("Academy") -- uzdaro
		retention.track(api.player(), "train", 2)
		retention.track(api.player(), "fightDone", 1)
		retention.track(api.player(), "post", 1)
		api.wait(0.5)
		api.open("Goals")
		api.wait(2)
	end,
	check = function(api)
		local p = api.profile()
		assert(p.tutorial.done == true, "tutorial not finished")
		assert(p.pinigai == 500 + 250, "rookie bonus not paid: " .. tostring(p.pinigai))
	end,
}
S.tournament_fresh = { seed = freshSeed, run = function(api) api.open("Tournament") end }
S.flow_tournament_enter = {
	seed = richSeed,
	run = function(api)
		api.open("Tournament")
		api.click("Panel_Tournament/TournamentList/Tournament_1")
		api.click("Panel_Tournament/DetailFooter/EnterButton")
		api.wait(2)
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
