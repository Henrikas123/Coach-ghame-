--[[
	GoalsPanel
	Daily tab: 7-day login streak (claim today's reward) + three daily quests with progress.
	Top Coaches tab: leaderboard by reputation (RetentionHandler, LeaderboardFetch).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GoalsPanel = {}

local function formatCountdown(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm", math.max(1, minutes))
end

function GoalsPanel.create(Kit, State)
	local C = Kit.Colors
	local player = Players.LocalPlayer

	local panel = Kit.createPanel({
		key = "Goals",
		title = "Daily Goals",
		subtitle = "Log in every day, finish quests, climb the leaderboard",
		icon = "🎯",
		accent = "gold",
		maxSize = Vector2.new(720, 600),
	})

	local pages = {}
	local tabs
	local function makePage(key, visible)
		local page = Kit.scroll({
			parent = panel.Body,
			name = "Page_" .. key,
			size = UDim2.new(1, -8, 1, -80),
			position = UDim2.new(0, 0, 0, 70),
			paddingTop = 2,
			paddingBottom = 20,
			paddingLeft = 20,
			paddingRight = 8,
			spacing = 12,
			visible = visible,
		})
		Kit.scrollFade(page)
		pages[key] = page
		return page
	end

	-- ============================================================
	-- DAILY: login streak
	-- ============================================================
	local dailyPage = makePage("daily", true)
	local streakCard = Kit.card({
		parent = dailyPage,
		name = "StreakCard",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 1,
		strokeColor = C.gold,
		strokeTransparency = 0.45,
	})
	Kit.padding(streakCard, 14, 16, 16, 16)
	Kit.list(streakCard, 12)
	local _, streakHint = Kit.sectionHeader({ parent = streakCard, title = "Login streak", hint = "", order = 0 })
	local dayRow = Kit.create("Frame", {
		Name = "Days",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 86),
		LayoutOrder = 1,
		Parent = streakCard,
	})
	Kit.grid(dayRow, UDim2.new(1 / 7, -7, 1, 0), UDim2.new(0, 6, 0, 0))
	local dayTiles = {}
	for day = 1, 7 do
		local tile = Kit.create("Frame", {
			Name = "Day" .. day,
			BackgroundColor3 = C.bg,
			LayoutOrder = day,
			Parent = dayRow,
		})
		Kit.corner(tile, 10)
		local tileStroke = Kit.stroke(tile, C.border, 1, 0.3)
		local caption = Kit.label({
			parent = tile,
			name = "Caption",
			text = day == 7 and "DAY 7" or ("DAY " .. day),
			font = Enum.Font.Oswald,
			textSize = 13,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 16),
			position = UDim2.new(0, 0, 0, 8),
		})
		local glyph = Kit.label({
			parent = tile,
			name = "Glyph",
			text = day == 7 and "🏆" or "💰",
			textSize = 20,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			position = UDim2.new(0, 0, 0, 27),
		})
		local amount = Kit.label({
			parent = tile,
			name = "Amount",
			text = "",
			bold = true,
			textSize = 12,
			color = C.goldBright,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -4, 0, 16),
			position = UDim2.new(0, 2, 1, -24),
		})
		dayTiles[day] = { tile = tile, stroke = tileStroke, caption = caption, glyph = glyph, amount = amount }
	end
	local claimButton = Kit.button({
		parent = streakCard,
		name = "ClaimButton",
		text = "Claim",
		variant = "gold",
		size = UDim2.new(1, 0, 0, 44),
		order = 2,
		textSize = 15,
		onClick = function()
			State.fire("RetentionRequest", "claimDaily")
		end,
	})

	-- ============================================================
	-- DAILY: quests
	-- ============================================================
	local _, questHint = Kit.sectionHeader({ parent = dailyPage, title = "Daily quests", hint = "", order = 2 })
	local questHolder = Kit.create("Frame", {
		Name = "Quests",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = dailyPage,
	})
	Kit.list(questHolder, 10)
	local questRows = {}

	local function questRow(index)
		if questRows[index] then
			return questRows[index]
		end
		local cardFrame, cardStroke = Kit.card({
			parent = questHolder,
			name = "Quest" .. index,
			size = UDim2.new(1, 0, 0, 74),
			order = index,
		})
		local iconBg = Kit.create("Frame", {
			Name = "IconBg",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(0, 44, 0, 44),
			Position = UDim2.new(0, 14, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = cardFrame,
		})
		Kit.corner(iconBg, 12)
		local icon = Kit.label({
			parent = iconBg,
			name = "Icon",
			text = "",
			textSize = 22,
			align = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
		})
		local title = Kit.label({
			parent = cardFrame,
			name = "Title",
			text = "",
			bold = true,
			textSize = 14,
			size = UDim2.new(1, -230, 0, 18),
			position = UDim2.new(0, 70, 0, 14),
		})
		local bar = Kit.progressBar({
			parent = cardFrame,
			name = "Progress",
			size = UDim2.new(1, -290, 0, 8),
			position = UDim2.new(0, 70, 0, 44),
		})
		local count = Kit.label({
			parent = cardFrame,
			name = "Count",
			text = "",
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(0, 50, 0, 16),
			position = UDim2.new(1, -214, 0, 40),
		})
		local button = Kit.button({
			parent = cardFrame,
			name = "ClaimButton",
			text = "",
			variant = "gold",
			size = UDim2.new(0, 140, 0, 36),
			position = UDim2.new(1, -14, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			textSize = 13,
		})
		local row = { card = cardFrame, stroke = cardStroke, icon = icon, title = title, bar = bar, count = count, button = button, id = nil }
		button.Instance.Activated:Connect(function()
			if row.id and button.IsEnabled() then
				State.fire("RetentionRequest", "claimQuest", row.id)
			end
		end)
		questRows[index] = row
		return row
	end

	-- ============================================================
	-- TOP COACHES
	-- ============================================================
	local boardPage = makePage("board", false)
	local meCard = Kit.card({
		parent = boardPage,
		name = "MeCard",
		size = UDim2.new(1, 0, 0, 70),
		order = 1,
		strokeColor = C.gold,
		strokeTransparency = 0.45,
	})
	Kit.label({
		parent = meCard,
		name = "Caption",
		text = "YOUR REPUTATION",
		font = Enum.Font.Oswald,
		textSize = 15,
		color = C.textSecondary,
		size = UDim2.new(0.5, 0, 0, 18),
		position = UDim2.new(0, 18, 0, 14),
	})
	local meValue = Kit.label({
		parent = meCard,
		name = "Value",
		text = "",
		font = Enum.Font.GothamBlack,
		textSize = 22,
		color = C.goldBright,
		size = UDim2.new(0.5, 0, 0, 26),
		position = UDim2.new(0, 18, 0, 34),
	})
	local meRank = Kit.label({
		parent = meCard,
		name = "Rank",
		text = "",
		bold = true,
		textSize = 14,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0.5, -18, 1, 0),
		position = UDim2.new(0.5, 0, 0, 0),
	})
	Kit.sectionHeader({ parent = boardPage, title = "Top coaches", hint = "Updates every minute", order = 2 })
	local boardHolder = Kit.card({
		parent = boardPage,
		name = "Board",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 3,
	})
	Kit.padding(boardHolder, 8, 12, 8, 12)
	Kit.list(boardHolder, 4)
	local boardRows = {}
	local RANK_COLORS = { C.goldBright, Color3.fromRGB(200, 204, 212), Color3.fromRGB(204, 140, 88) }

	local function renderBoard(data)
		for _, row in ipairs(boardRows) do
			row:Destroy()
		end
		table.clear(boardRows)
		local entries = data and data.entries or {}
		local myRank = nil
		for index, entry in ipairs(entries) do
			local isMe = entry.userId == player.UserId
			if isMe then
				myRank = entry.rank
			end
			local row = Kit.create("Frame", {
				Name = "Row" .. index,
				BackgroundColor3 = isMe and C.bgCardLight or C.bg,
				BackgroundTransparency = isMe and 0 or 0.4,
				Size = UDim2.new(1, 0, 0, 38),
				LayoutOrder = index,
				Parent = boardHolder,
			})
			Kit.corner(row, 9)
			if isMe then
				Kit.stroke(row, C.gold, 1, 0.3)
			end
			local rankColor = RANK_COLORS[entry.rank] or C.textSecondary
			Kit.label({
				parent = row,
				name = "Rank",
				text = "#" .. tostring(entry.rank),
				font = Enum.Font.GothamBlack,
				textSize = 15,
				color = rankColor,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(0, 48, 1, 0),
				position = UDim2.new(0, 4, 0, 0),
			})
			Kit.label({
				parent = row,
				name = "Name",
				text = (entry.name or "?") .. (isMe and "  (you)" or ""),
				bold = isMe or entry.rank <= 3,
				textSize = 14,
				color = isMe and C.goldBright or C.textPrimary,
				size = UDim2.new(1, -170, 1, 0),
				position = UDim2.new(0, 56, 0, 0),
			})
			Kit.label({
				parent = row,
				name = "Value",
				text = string.format("%s rep", Kit.formatNumber(entry.value or 0)),
				bold = true,
				textSize = 13,
				color = C.textSecondary,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 100, 1, 0),
				position = UDim2.new(1, -12, 0, 0),
				anchor = Vector2.new(1, 0),
			})
			table.insert(boardRows, row)
		end
		if #entries == 0 then
			local empty = Kit.label({
				parent = boardHolder,
				name = "Empty",
				text = "No coaches on the board yet — be the first!",
				textSize = 13,
				color = C.textSecondary,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 44),
			})
			table.insert(boardRows, empty)
		end
		local reputation = State.get().reputation or {}
		meValue.Text = Kit.formatNumber(reputation.reputacija or 0)
		meRank.Text = myRank and string.format("Rank #%d", myRank) or "Not in the top 20 yet"
		meRank.TextColor3 = myRank and C.goldBright or C.textSecondary
	end

	local fetching = false
	local function fetchBoard()
		if fetching then
			return
		end
		fetching = true
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local fetch = remotes and remotes:FindFirstChild("LeaderboardFetch")
			local ok, data = false, nil
			if fetch then
				ok, data = pcall(function()
					return fetch:InvokeServer()
				end)
			end
			fetching = false
			if panel.IsOpen then
				renderBoard(ok and data or nil)
			end
		end)
	end

	tabs = Kit.tabs({
		parent = panel.Body,
		items = {
			{ key = "daily", label = "Daily", icon = "🎯" },
			{ key = "board", label = "Top Coaches", icon = "🏆" },
		},
		size = UDim2.new(1, -40, 0, 42),
		position = UDim2.new(0, 20, 0, 14),
		onSelect = function(key)
			for pageKey, page in pairs(pages) do
				page.Visible = pageKey == key
			end
			if key == "board" then
				fetchBoard()
			end
		end,
	})

	-- ============================================================
	-- RENDER
	-- ============================================================
	local function secondsLeft(retention)
		return (retention.secondsToReset or 0) - (os.clock() - (retention.receivedAt or os.clock()))
	end

	local function renderDaily()
		local retention = State.get().retention or {}
		local daily = retention.daily or {}
		local rewards = retention.rewards or {}
		local cycleStart = (math.max(daily.claimStreak or 1, 1) - 1) // 7 * 7 -- streak days before this 7-day cycle
		local todayIndex = daily.rewardIndex or 1
		for day, entry in ipairs(dayTiles) do
			local claimed = day < todayIndex or (day == todayIndex and not daily.canClaim)
			local isToday = day == todayIndex
			entry.amount.Text = rewards[day] and Kit.formatMoney(rewards[day]) or ""
			entry.caption.Text = isToday and "TODAY" or ("DAY " .. (cycleStart + day))
			entry.caption.TextColor3 = isToday and C.goldBright or C.textSecondary
			entry.tile.BackgroundColor3 = isToday and C.bgCardLight or C.bg
			entry.stroke.Color = isToday and C.gold or C.border
			entry.stroke.Thickness = isToday and 2 or 1
			entry.stroke.Transparency = isToday and 0.05 or 0.3
			entry.glyph.Text = claimed and "✓" or (day == 7 and "🏆" or "💰")
			entry.glyph.TextColor3 = C.goldBright
			entry.amount.TextTransparency = claimed and 0.5 or 0
		end
		local left = secondsLeft(retention)
		streakHint.Text = (daily.streak or 0) > 0 and string.format("🔥 %d day streak", daily.streak) or "Start your streak today"
		if daily.canClaim then
			claimButton.SetEnabled(true)
			claimButton.SetText(string.format("Claim %s", Kit.formatMoney(daily.reward or 0)))
		else
			claimButton.SetEnabled(false)
			claimButton.SetText("Next reward in " .. formatCountdown(left))
		end

		questHint.Text = "New quests in " .. formatCountdown(left)
		local quests = retention.quests or {}
		for index, quest in ipairs(quests) do
			local row = questRow(index)
			row.card.Visible = true
			row.id = quest.id
			row.icon.Text = quest.icon or "🎯"
			row.title.Text = quest.title
			row.bar.Set(quest.target > 0 and quest.progress / quest.target or 0)
			row.count.Text = string.format("%d / %d", quest.progress, quest.target)
			local done = quest.progress >= quest.target
			if quest.claimed then
				row.button.SetVariant("ghost")
				row.button.SetEnabled(false)
				row.button.SetText("✓ Claimed")
				row.stroke.Color = C.border
			elseif done then
				row.button.SetVariant("gold")
				row.button.SetEnabled(true)
				row.button.SetText("Claim " .. Kit.formatMoney(quest.reward))
				row.stroke.Color = C.gold
			else
				row.button.SetVariant("gold")
				row.button.SetEnabled(false)
				row.button.SetText("Reward " .. Kit.formatMoney(quest.reward))
				row.stroke.Color = C.border
			end
		end
		for index = #quests + 1, #questRows do
			questRows[index].card.Visible = false
		end
	end

	local queued = false
	local function queueRender()
		if not panel.IsOpen or queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			renderDaily()
		end)
	end
	State.subscribe("retention", queueRender)
	State.onMessage("retention", function(message)
		if panel.IsOpen then
			panel.Toast(message)
		end
	end)
	panel.Every(30, function()
		renderDaily()
		if pages.board.Visible then
			fetchBoard()
		end
	end)
	panel.OnOpen(function()
		renderDaily()
		State.fire("RetentionRequest", "refresh")
		if tabs.Current() == "board" then
			fetchBoard()
		end
	end)

	tabs.Select("daily", true)
	return panel
end

return GoalsPanel
