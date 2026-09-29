-- Script: ServerScriptService/RetentionHandler
-- Reasons to come back every day:
--   * daily login reward with a 7-day streak cycle (missing a day restarts the streak)
--   * three daily quests (progress comes from the other handlers via _G.CoachAcademyRetention.track)
--   * Top Coaches leaderboard by reputation (OrderedDataStore) on a board in town and in the Goals panel

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RetentionConfig = require(Modules:WaitForChild("RetentionConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function remote(name, className)
	local existing = Remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Remotes
	return created
end
local RetentionUpdate = remote("RetentionUpdate", "RemoteEvent")
local RetentionRequest = remote("RetentionRequest", "RemoteEvent")
local LeaderboardFetch = remote("LeaderboardFetch", "RemoteFunction")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end
local dataApi = getDataApi()

local function today()
	return os.time() // 86400
end

-- ------------------------------------------------------------
-- Daily quests
-- ------------------------------------------------------------
local function pickQuests(userId, day)
	local chosen = { RetentionConfig.StarterQuest }
	local pool = {}
	for _, quest in ipairs(RetentionConfig.Quests) do
		if quest.id ~= RetentionConfig.StarterQuest then
			table.insert(pool, quest.id)
		end
	end
	-- same player + same day = same quests (rejoining does not reroll)
	local rng = Random.new((userId % 1000003) * 31 + day)
	while #chosen < RetentionConfig.QuestsPerDay and #pool > 0 do
		table.insert(chosen, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	local list = {}
	for _, id in ipairs(chosen) do
		table.insert(list, { id = id, progress = 0, claimed = false })
	end
	return list
end

local function ensureQuests(player, profile)
	local day = today()
	if type(profile.quests) ~= "table" or profile.quests.day ~= day or type(profile.quests.list) ~= "table" then
		profile.quests = { day = day, list = pickQuests(player.UserId, day) }
	end
	return profile.quests
end

local function dailyInfo(profile)
	profile.daily = profile.daily or { lastClaimDay = 0, streak = 0 }
	local daily = profile.daily
	local day = today()
	local last = daily.lastClaimDay or 0
	local canClaim = last < day
	local alive = last >= day - 1
	local streak = alive and (daily.streak or 0) or 0
	local claimStreak = canClaim and streak + 1 or streak -- streak day the (next/today's) reward belongs to
	local rewardIndex = ((math.max(claimStreak, 1) - 1) % #RetentionConfig.DailyRewards) + 1
	return {
		canClaim = canClaim,
		streak = streak,
		claimStreak = claimStreak,
		rewardIndex = rewardIndex,
		reward = RetentionConfig.DailyRewards[rewardIndex],
		bonusReputation = RetentionConfig.DailyBonusReputation[rewardIndex] or 0,
	}
end

local function publicState(player, profile)
	local quests = ensureQuests(player, profile)
	local list = {}
	for _, entry in ipairs(quests.list) do
		local def = RetentionConfig.quest(entry.id)
		if def then
			table.insert(list, {
				id = def.id,
				title = def.title,
				icon = def.icon,
				target = def.target,
				reward = def.reward,
				progress = math.min(entry.progress or 0, def.target),
				claimed = entry.claimed == true,
			})
		end
	end
	local tutorial = profile.tutorial or {}
	return {
		day = today(),
		secondsToReset = (today() + 1) * 86400 - os.time(),
		daily = dailyInfo(profile),
		rewards = RetentionConfig.DailyRewards,
		quests = list,
		tutorialDone = tutorial.done == true,
	}
end

local function push(player, profile, message)
	RetentionUpdate:FireClient(player, {
		state = publicState(player, profile),
		pinigai = profile.pinigai,
		reputacija = profile.reputacija,
		message = message,
	})
end

local function track(player, event, amount)
	-- the first-minutes tutorial listens to the same events
	if _G.CoachAcademyTutorial then
		_G.CoachAcademyTutorial.onEvent(player, event, amount or 1)
	end
	local profile = dataApi and dataApi.getProfile(player)
	if not profile then
		return
	end
	local changed = false
	for _, entry in ipairs(ensureQuests(player, profile).list) do
		local def = RetentionConfig.quest(entry.id)
		if def and def.event == event and not entry.claimed and (entry.progress or 0) < def.target then
			entry.progress = math.min(def.target, (entry.progress or 0) + (amount or 1))
			changed = true
		end
	end
	if changed then
		push(player, profile)
	end
end

RetentionRequest.OnServerEvent:Connect(function(player, action, argument)
	local profile = dataApi and dataApi.getProfile(player)
	if not profile or type(action) ~= "string" then
		return
	end
	if action == "claimDaily" then
		local info = dailyInfo(profile)
		if not info.canClaim then
			push(player, profile, "Daily reward already claimed — come back tomorrow!")
			return
		end
		profile.daily.lastClaimDay = today()
		profile.daily.streak = info.claimStreak
		profile.pinigai += info.reward
		if info.bonusReputation > 0 then
			profile.reputacija += info.bonusReputation
		end
		local message = string.format("Daily reward: +$%d (day %d streak)", info.reward, info.claimStreak)
		if info.bonusReputation > 0 then
			message ..= string.format(" +%d reputation", info.bonusReputation)
		end
		push(player, profile, message)
		dataApi.saveNow(player)
	elseif action == "claimQuest" then
		for _, entry in ipairs(ensureQuests(player, profile).list) do
			local def = RetentionConfig.quest(entry.id)
			if def and entry.id == argument then
				if entry.claimed then
					push(player, profile, "Quest reward already claimed.")
				elseif (entry.progress or 0) < def.target then
					push(player, profile, "Quest not finished yet.")
				else
					entry.claimed = true
					profile.pinigai += def.reward
					push(player, profile, string.format("Quest complete: %s (+$%d)", def.title, def.reward))
					dataApi.saveNow(player)
				end
				return
			end
		end
	elseif action == "refresh" then
		push(player, profile)
	end
end)

-- ------------------------------------------------------------
-- Leaderboard
-- ------------------------------------------------------------
local ordered = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(RetentionConfig.LeaderboardStore)
	end)
	if ok then
		ordered = result
	end
end

local board = { entries = {}, updatedAt = 0 }
local nameCache = {}

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName ~= "" and player.DisplayName or player.Name
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Coach " .. tostring(userId))
	return nameCache[userId]
end

local function submit(player)
	local profile = dataApi and dataApi.getProfile(player)
	if not profile or not ordered then
		return
	end
	pcall(function()
		ordered:SetAsync(tostring(player.UserId), math.max(0, math.floor(profile.reputacija or 0)))
	end)
end

-- Town board (Workspace.Town.LeaderboardBoard.Board, placed by the build): SurfaceGui with the top 10
local boardRows = nil
local function ensureTownBoard()
	if boardRows then
		return boardRows
	end
	local town = Workspace:FindFirstChild("Town")
	local model = town and town:FindFirstChild("LeaderboardBoard")
	local part = model and model:FindFirstChild("Board")
	if not part then
		return nil
	end
	local gui = part:FindFirstChild("TopCoachesGui") or Instance.new("SurfaceGui")
	gui.Name = "TopCoachesGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(600, 400)
	gui.LightInfluence = 0
	gui.Parent = part
	local bg = gui:FindFirstChild("Background") or Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(22, 20, 24)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local title = bg:FindFirstChild("Title") or Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Font = Enum.Font.Oswald
	title.Text = "TOP COACHES"
	title.TextSize = 42
	title.TextColor3 = Color3.fromRGB(236, 200, 92)
	title.Parent = bg
	boardRows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, 30, 0, 64 + (i - 1) * 32)
		row.Size = UDim2.new(1, -60, 0, 30)
		row.Font = i <= 3 and Enum.Font.GothamBold or Enum.Font.Gotham
		row.TextSize = 22
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i == 1 and Color3.fromRGB(236, 200, 92) or Color3.fromRGB(240, 235, 226)
		row.Text = ""
		row.Parent = bg
		boardRows[i] = row
	end
	return boardRows
end

local function renderTownBoard()
	local rows = ensureTownBoard()
	if not rows then
		return
	end
	for i, row in ipairs(rows) do
		local entry = board.entries[i]
		row.Text = entry and string.format("#%d   %s   —   %d rep", entry.rank, entry.name, entry.value) or ""
	end
	if #board.entries == 0 then
		rows[1].Text = "Be the first coach on the board!"
	end
end

local function refreshBoard()
	local entries = {}
	if ordered then
		local ok, pages = pcall(function()
			return ordered:GetSortedAsync(false, RetentionConfig.LeaderboardSize)
		end)
		if ok and pages then
			for rank, row in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(row.key)
				if userId then
					table.insert(entries, { rank = rank, userId = userId, name = nameFor(userId), value = row.value })
				end
			end
		end
	end
	if #entries == 0 then
		-- no DataStore (Studio): rank the players on this server
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = dataApi and dataApi.getProfile(player)
			if profile then
				table.insert(entries, { userId = player.UserId, name = nameFor(player.UserId), value = math.floor(profile.reputacija or 0) })
			end
		end
		table.sort(entries, function(a, b)
			return a.value > b.value
		end)
		for rank, entry in ipairs(entries) do
			entry.rank = rank
		end
	end
	board = { entries = entries, updatedAt = os.time() }
	renderTownBoard()
end

LeaderboardFetch.OnServerInvoke = function()
	return board
end

task.spawn(function()
	task.wait(3)
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			submit(player)
		end
		refreshBoard()
		task.wait(RetentionConfig.LeaderboardRefreshSeconds)
	end
end)

-- ------------------------------------------------------------
-- Join / leave
-- ------------------------------------------------------------
local function onPlayerAdded(player)
	local profile = dataApi and dataApi.waitForProfile and dataApi.waitForProfile(player, 60) or (dataApi and dataApi.getProfile(player))
	if not profile then
		return
	end
	push(player, profile)
	submit(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
	submit(player)
end)

_G.CoachAcademyRetention = {
	track = track,
	publicState = publicState,
	push = function(player)
		local profile = dataApi and dataApi.getProfile(player)
		if profile then
			push(player, profile)
		end
	end,
}

print("RetentionHandler paruoštas.")
