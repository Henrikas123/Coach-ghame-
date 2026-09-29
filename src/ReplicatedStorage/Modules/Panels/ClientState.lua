--[[
	ClientState
	Coach Academy - vienas kliento duomenu saltinis visoms panelems.

	- Klauso visu esamu *Update RemoteEvent'u (Training/Marketing/Reputation/Academy/
	  Staff/Scout/Sponsor/Tournament/Equipment/Fight) ir laiko naujausia busena.
	- Pilna busena gali pasiimti per PanelSnapshot RemoteFunction (ServerScriptService/
	  PanelDataHandler) -- naudojama atidarant panele, kad duomenys visada butu tikslus,
	  net jei pradiniai serverio pranesimai buvo praleisti.
	- Palaiko sena MainHUD.MoneyLabel sinchronizuota (MainHUDController ji atspindi).
	- Kaupia telefono veiklos srauta (postai, walk-in klientai) is MarketingUpdate zinuciu.

	API:
	  ClientState.start()
	  ClientState.get() -> state lentele
	  ClientState.subscribe(channel, fn) -> disconnect fn
	      kanalai: "money", "reputation", "students", "marketing", "academy", "staff",
	               "scout", "sponsor", "tournament", "equipment", "profile", "feed", "any"
	  ClientState.onMessage(channel, fn) -> disconnect fn   (serverio zinutes toast'ams)
	  ClientState.refresh(force)       -- PanelSnapshot uzklausa (throttled)
	  ClientState.now()                -- serverio laikas (sekundes)
	  ClientState.fire(remoteName, ...) -- RemoteEvent:FireServer
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataSchema = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DataSchema"))
local MarketingConfig = require(ReplicatedStorage.Modules:WaitForChild("MarketingConfig"))

local ClientState = {}

local player = Players.LocalPlayer
local remotes = nil

local state = {
	loaded = false,
	money = nil,
	reputation = {
		reputacija = 0,
		tierIndex = 1,
		tierName = "Local Coach",
		stars = 1,
		nextTierWinsRequired = nil,
		nextTierName = nil,
	},
	students = {},
	marketing = {
		followers = 0,
		reachAccumulated = 0,
		walkInThreshold = 80,
		lastPostTimes = {},
	},
	academy = {
		academyName = "Coach Academy",
		wallColorIndex = 1,
		floorColorIndex = nil,
		logoIndex = 1,
		gymLevel = 1,
	},
	equipment = { "PunchingBag" },
	staff = {},
	scout = { candidates = {}, lastScoutAt = 0 },
	sponsor = { sponsors = {}, offers = {}, lastRefresh = 0 },
	tournament = { lastTournamentAt = 0, lastResult = nil },
	stats = { lifetimeEarned = 0, lifetimeSpent = 0, trophies = {} },
	-- kasdienis prizas + uzduotys (RetentionHandler.publicState); receivedAt -- laikmaciui
	retention = { daily = { canClaim = false, streak = 0, claimStreak = 0, rewardIndex = 1, reward = 0 }, rewards = {}, quests = {}, secondsToReset = 0, tutorialDone = true, receivedAt = 0 },
	feed = {}, -- { kind, icon, title, text, time }
}

local listeners = {}
local messageListeners = {}
local serverTimeOffset = 0
local started = false
local lastRefreshAt = -math.huge
local refreshInFlight = false
local pendingForce = false
local REFRESH_TIMEOUT = 8

-- ============================================================
-- PRENUMERATOS
-- ============================================================
local function subscribeTo(bucket, channel, fn)
	bucket[channel] = bucket[channel] or {}
	local entry = { fn = fn }
	table.insert(bucket[channel], entry)
	return function()
		local entries = bucket[channel]
		if not entries then
			return
		end
		for index, candidate in ipairs(entries) do
			if candidate == entry then
				table.remove(entries, index)
				break
			end
		end
	end
end

function ClientState.subscribe(channel, fn)
	return subscribeTo(listeners, channel, fn)
end

function ClientState.onMessage(channel, fn)
	return subscribeTo(messageListeners, channel, fn)
end

local function emit(bucket, channel, ...)
	local entries = bucket[channel]
	if not entries then
		return
	end
	for _, entry in ipairs(table.clone(entries)) do
		task.spawn(entry.fn, ...)
	end
end

local function notify(channel)
	emit(listeners, channel, state)
	if channel ~= "any" then
		emit(listeners, "any", state, channel)
	end
end

local function pushMessage(channel, message)
	if type(message) == "string" and message ~= "" then
		emit(messageListeners, channel, message)
	end
end

function ClientState.get()
	return state
end

-- ============================================================
-- LAIKAS
-- ============================================================
function ClientState.now()
	local ok, serverNow = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	if ok and type(serverNow) == "number" and serverNow > 0 then
		return serverNow
	end
	return os.time() + serverTimeOffset
end

-- ============================================================
-- PINIGAI (+ senos MainHUD.MoneyLabel sinchronizacija)
-- ============================================================
local function syncLegacyMoneyLabel(amount)
	local playerGui = player:FindFirstChild("PlayerGui")
	local legacyHud = playerGui and playerGui:FindFirstChild("MainHUD")
	local moneyLabel = legacyHud and legacyHud:FindFirstChild("MoneyLabel")
	if moneyLabel and moneyLabel:IsA("TextLabel") then
		moneyLabel.Text = "$ " .. tostring(amount)
	end
end

local function setMoney(amount)
	if type(amount) ~= "number" then
		return
	end
	if state.money ~= amount then
		state.money = amount
		syncLegacyMoneyLabel(amount)
		notify("money")
	end
end

-- ============================================================
-- REPUTACIJA (skaiciuojama ir lokaliai, jei serveris atsiuncia tik skaiciu)
-- ============================================================
local function applyReputationValue(reputacija)
	local tiers = DataSchema.CoachReputationTiers
	local tierIndex = 1
	for index, tier in ipairs(tiers) do
		if reputacija >= tier.winsRequired then
			tierIndex = index
		end
	end
	local tier = tiers[tierIndex]
	local nextTier = tiers[tierIndex + 1]
	local rep = state.reputation
	rep.reputacija = reputacija
	rep.tierIndex = tierIndex
	rep.tierName = tier.name
	rep.stars = tier.stars
	rep.nextTierWinsRequired = nextTier and nextTier.winsRequired or nil
	rep.nextTierName = nextTier and nextTier.name or nil
	rep.currentTierWinsRequired = tier.winsRequired
end

-- ============================================================
-- TELEFONO VEIKLOS SRAUTAS
-- ============================================================
local FEED_LIMIT = 30

local function addFeed(entry)
	entry.time = entry.time or ClientState.now()
	table.insert(state.feed, 1, entry)
	while #state.feed > FEED_LIMIT do
		table.remove(state.feed)
	end
end

local function marketingItemByLabel(labelText)
	for _, itemId in ipairs(MarketingConfig.Order) do
		local item = MarketingConfig.Items[itemId]
		if item and item.label == labelText then
			return itemId, item
		end
	end
	return nil, nil
end

-- Is MarketingHandler zinutes istraukiam posto rezultata ir atejusius klientus
local function parseMarketingMessage(message)
	if type(message) ~= "string" then
		return false
	end
	local added = false
	local postLabel, followersGain, reachGain = string.match(message, "^(.-) posted! %+(%d+) followers, %+(%d+) reach")
	if postLabel then
		local itemId = marketingItemByLabel(postLabel)
		addFeed({
			kind = "post",
			itemId = itemId,
			title = postLabel,
			text = string.format("+%s followers  •  +%s reach", followersGain, reachGain),
			followers = tonumber(followersGain),
			reach = tonumber(reachGain),
		})
		added = true
	end
	for name in string.gmatch(message, "New client walked in: ([^!]+)!") do
		addFeed({
			kind = "walkin",
			title = name,
			text = "Came in for a free trial session",
		})
		added = true
	end
	return added
end

-- Pradinis srautas is issaugotu lastPostTimes (kai dar nieko neparasyta sios sesijos metu)
local function seedFeedFromPostTimes()
	if #state.feed > 0 then
		return
	end
	local entries = {}
	for itemId, postedAt in pairs(state.marketing.lastPostTimes or {}) do
		local item = MarketingConfig.Items[itemId]
		if item and type(postedAt) == "number" then
			table.insert(entries, {
				kind = "post",
				itemId = itemId,
				title = item.label,
				text = string.format("+%d–%d followers  •  +%d–%d reach", item.followersMin, item.followersMax, item.reachMin, item.reachMax),
				time = postedAt,
			})
		end
	end
	table.sort(entries, function(a, b)
		return a.time > b.time
	end)
	for _, entry in ipairs(entries) do
		table.insert(state.feed, entry)
	end
end

-- ============================================================
-- SNAPSHOT TAIKYMAS
-- ============================================================
local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	if type(snapshot.serverTime) == "number" then
		serverTimeOffset = snapshot.serverTime - os.time()
	end
	setMoney(snapshot.pinigai)

	if type(snapshot.reputacija) == "number" then
		applyReputationValue(snapshot.reputacija)
		notify("reputation")
	end

	if type(snapshot.studentsList) == "table" then
		state.students = snapshot.studentsList
		notify("students")
	end

	local marketing = state.marketing
	marketing.followers = snapshot.followers or marketing.followers
	marketing.reachAccumulated = snapshot.reachAccumulated or marketing.reachAccumulated
	marketing.walkInThreshold = snapshot.walkInThreshold or marketing.walkInThreshold
	marketing.lastPostTimes = snapshot.lastPostTimes or marketing.lastPostTimes
	seedFeedFromPostTimes()
	notify("marketing")
	notify("feed")

	local academy = state.academy
	academy.academyName = snapshot.academyName or academy.academyName
	academy.wallColorIndex = snapshot.wallColorIndex or academy.wallColorIndex
	academy.floorColorIndex = snapshot.floorColorIndex or academy.floorColorIndex
	academy.logoIndex = snapshot.logoIndex or academy.logoIndex
	academy.gymLevel = snapshot.gymLevel or academy.gymLevel
	notify("academy")

	if type(snapshot.unlockedEquipment) == "table" then
		state.equipment = snapshot.unlockedEquipment
		notify("equipment")
	end
	if type(snapshot.staff) == "table" then
		state.staff = snapshot.staff
		notify("staff")
	end

	state.scout.candidates = snapshot.scoutCandidates or state.scout.candidates
	state.scout.lastScoutAt = snapshot.lastScoutAt or state.scout.lastScoutAt
	notify("scout")

	state.sponsor.sponsors = snapshot.sponsors or state.sponsor.sponsors
	state.sponsor.offers = snapshot.sponsorOffers or state.sponsor.offers
	state.sponsor.lastRefresh = snapshot.lastSponsorRefresh or state.sponsor.lastRefresh
	notify("sponsor")

	state.tournament.lastTournamentAt = snapshot.lastTournamentAt or state.tournament.lastTournamentAt
	notify("tournament")

	state.stats.lifetimeEarned = snapshot.lifetimeEarned or state.stats.lifetimeEarned
	state.stats.lifetimeSpent = snapshot.lifetimeSpent or state.stats.lifetimeSpent
	state.stats.trophies = snapshot.trophies or state.stats.trophies
	if type(snapshot.retention) == "table" then
		state.retention = snapshot.retention
		state.retention.receivedAt = os.clock()
		notify("retention")
	end
	state.loaded = true
	notify("profile")
end

function ClientState.refresh(force)
	if refreshInFlight then
		-- vykstanti uzklausa galejo prasideti pries pokyti -- priverstini atnaujinima pakartosim po jos
		if force then
			pendingForce = true
		end
		return
	end
	local now = os.clock()
	if not force and now - lastRefreshAt < 1.5 then
		return
	end
	lastRefreshAt = now
	refreshInFlight = true
	local requestId = {}
	ClientState._activeRequest = requestId
	local function finish()
		if ClientState._activeRequest ~= requestId then
			return
		end
		ClientState._activeRequest = nil
		refreshInFlight = false
		if pendingForce then
			pendingForce = false
			ClientState.refresh(true)
		end
	end
	-- apsauga: jei serveris neatsako, po REFRESH_TIMEOUT leidziam naujas uzklausas
	task.delay(REFRESH_TIMEOUT, finish)
	task.spawn(function()
		local snapshotRemote = remotes and remotes:WaitForChild("PanelSnapshot", 10)
		if snapshotRemote and snapshotRemote:IsA("RemoteFunction") then
			local ok, result = pcall(function()
				return snapshotRemote:InvokeServer()
			end)
			if ok then
				if ClientState._activeRequest == requestId then
					applySnapshot(result)
				end
			else
				warn("ClientState: PanelSnapshot klaida: " .. tostring(result))
			end
		end
		finish()
	end)
end

-- ============================================================
-- REMOTE EVENT'U KLAUSYMAS
-- ============================================================
local function connect(remoteName, handler)
	task.spawn(function()
		local remote = remotes:WaitForChild(remoteName, 15)
		if not remote then
			warn("ClientState: RemoteEvent '" .. remoteName .. "' nerastas")
			return
		end
		remote.OnClientEvent:Connect(function(data)
			if type(data) ~= "table" then
				return
			end
			local ok, err = pcall(handler, data)
			if not ok then
				warn("ClientState: " .. remoteName .. " apdorojimo klaida: " .. tostring(err))
			end
		end)
	end)
end

function ClientState.fire(remoteName, ...)
	local remote = remotes and remotes:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(...)
		return true
	end
	warn("ClientState: negaliu issiusti '" .. tostring(remoteName) .. "' — RemoteEvent nerastas")
	return false
end

function ClientState.start()
	if started then
		return
	end
	started = true
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	connect("TrainingUpdate", function(data)
		setMoney(data.pinigai)
		if type(data.studentsList) == "table" then
			state.students = data.studentsList
			notify("students")
		end
		pushMessage("students", data.message)
	end)

	connect("MarketingUpdate", function(data)
		local marketing = state.marketing
		marketing.followers = data.followers or marketing.followers
		marketing.reachAccumulated = data.reachAccumulated or marketing.reachAccumulated
		marketing.walkInThreshold = data.walkInThreshold or marketing.walkInThreshold
		marketing.lastPostTimes = data.lastPostTimes or marketing.lastPostTimes
		local feedChanged = parseMarketingMessage(data.message)
		seedFeedFromPostTimes()
		notify("marketing")
		if feedChanged then
			notify("feed")
			-- naujas walk-in klientas -> atnaujinam nariu sarasa
			if string.find(data.message or "", "New client walked in", 1, true) then
				ClientState.refresh(true)
			end
		end
		pushMessage("marketing", data.message)
	end)

	connect("ReputationUpdate", function(data)
		if type(data.reputacija) == "number" then
			applyReputationValue(data.reputacija)
		end
		local rep = state.reputation
		rep.tierIndex = data.tierIndex or rep.tierIndex
		rep.tierName = data.tierName or rep.tierName
		rep.stars = data.stars or rep.stars
		rep.nextTierWinsRequired = data.nextTierWinsRequired
		rep.nextTierName = data.nextTierName
		notify("reputation")
	end)

	connect("AcademyUpdate", function(data)
		local academy = state.academy
		academy.academyName = data.academyName or academy.academyName
		academy.wallColorIndex = data.wallColorIndex or academy.wallColorIndex
		academy.floorColorIndex = data.floorColorIndex or academy.floorColorIndex
		academy.logoIndex = data.logoIndex or academy.logoIndex
		notify("academy")
		pushMessage("academy", data.message)
	end)

	connect("EquipmentUpdate", function(data)
		setMoney(data.pinigai)
		if type(data.unlockedEquipment) == "table" then
			state.equipment = data.unlockedEquipment
			notify("equipment")
		end
		pushMessage("equipment", data.message)
	end)

	connect("StaffUpdate", function(data)
		setMoney(data.pinigai)
		if type(data.staff) == "table" then
			state.staff = data.staff
			notify("staff")
		end
		pushMessage("staff", data.message)
	end)

	connect("ScoutUpdate", function(data)
		setMoney(data.pinigai)
		state.scout.candidates = data.scoutCandidates or state.scout.candidates
		state.scout.lastScoutAt = data.lastScoutAt or state.scout.lastScoutAt
		notify("scout")
		pushMessage("scout", data.message)
	end)

	connect("RetentionUpdate", function(data)
		setMoney(data.pinigai)
		if type(data.state) == "table" then
			state.retention = data.state
			state.retention.receivedAt = os.clock()
			notify("retention")
		end
		pushMessage("retention", data.message)
	end)

	connect("SponsorUpdate", function(data)
		setMoney(data.pinigai)
		state.sponsor.sponsors = data.sponsors or state.sponsor.sponsors
		state.sponsor.offers = data.sponsorOffers or state.sponsor.offers
		state.sponsor.lastRefresh = data.lastSponsorRefresh or state.sponsor.lastRefresh
		notify("sponsor")
		pushMessage("sponsor", data.message)
	end)

	connect("TournamentUpdate", function(data)
		setMoney(data.pinigai)
		if type(data.reputacija) == "number" then
			applyReputationValue(data.reputacija)
			notify("reputation")
		end
		if data.lastTournamentAt then
			state.tournament.lastTournamentAt = data.lastTournamentAt
		end
		if data.phase == "result" then
			state.tournament.lastResult = data
			state.tournament.lastTournamentAt = math.floor(ClientState.now())
			-- turnyras keicia nariu fatigue/pergales ir trofejus -> pilnas atnaujinimas
			ClientState.refresh(true)
		end
		notify("tournament")
		pushMessage("tournament", data.message)
	end)

	connect("FightUpdate", function(data)
		if data.phase == "result" then
			-- kova baigesi: pinigai, rekordas, reputacija pasikeite serveryje
			task.delay(0.5, function()
				ClientState.refresh(true)
			end)
		end
	end)

	-- Pradinis pilnas busenos paemimas
	task.spawn(function()
		task.wait(1)
		ClientState.refresh(true)
	end)
end

return ClientState
