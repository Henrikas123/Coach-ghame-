--[[
	PhonePanel
	Trenerio telefonas su "SocialGym" programele (marketingas):
	  - Įrašai: turinio skelbimas (MarketingConfig) su cooldown'ais + veiklos srautas
	  - Klientai: walk-in klientai (bandomasis laikotarpis) -- ateina organiskai per reach
	  - Kovotojai: kiekvieno kovotojo atskira socialine paskyra
	Telefonas atsiranda desineje apacioje, virs Phone FAB mygtuko.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MarketingConfig = require(Modules:WaitForChild("MarketingConfig"))
local TrainingConfig = require(Modules:WaitForChild("TrainingConfig"))
local FightConfig = require(Modules:WaitForChild("FightConfig"))
local AcademyConfig = require(Modules:WaitForChild("AcademyConfig"))

local PhonePanel = {}

local POST_ICONS = {
	SparringClip = "🥊",
	AcademyTour = "🏟️",
	TransformationPost = "📈",
	CompetitionHighlight = "🏆",
}

-- Paskyros vardas (@handle) is vardo: "Alex Martin" -> "alex.martin"
local ASCII_MAP = {
	["ą"] = "a", ["č"] = "c", ["ę"] = "e", ["ė"] = "e", ["į"] = "i", ["š"] = "s", ["ų"] = "u", ["ū"] = "u", ["ž"] = "z",
	["Ą"] = "a", ["Č"] = "c", ["Ę"] = "e", ["Ė"] = "e", ["Į"] = "i", ["Š"] = "s", ["Ų"] = "u", ["Ū"] = "u", ["Ž"] = "z",
}
local function toHandle(name)
	local text = name or "fighter"
	for from, to in pairs(ASCII_MAP) do
		text = text:gsub(from, to)
	end
	text = string.lower(text):gsub("[^%w%s]", ""):gsub("%s+", ".")
	text = text:gsub("^%.+", ""):gsub("%.+$", "")
	if text == "" then
		text = "fighter"
	end
	return text
end

-- Kovotojo fanu skaicius (kosmetinis) -- is tikru pasiekimu: pergales, titulai, karjeros lygis, akademijos sekejai
local function fanCount(student, academyFollowers)
	local record = student.record or {}
	local fans = 25
		+ (record.wins or 0) * 40
		+ (student.tournamentWins or 0) * 250
		+ ((student.careerTier or 1) - 1) * 150
		+ math.floor((academyFollowers or 0) * 0.05)
	if student.competitionReady then
		fans += 30
	end
	return fans
end

function PhonePanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Phone",
		style = "phone",
		accent = "gold",
		maxSize = Vector2.new(348, 660),
	})
	local surface = panel.Surface

	-- ============================================================
	-- TELEFONO KORPUSAS
	-- ============================================================
	local screen = Kit.create("Frame", {
		Name = "Screen",
		BackgroundColor3 = C.bgCard,
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		ClipsDescendants = true,
		Parent = panel.Body,
	})
	Kit.corner(screen, 28)
	Kit.stroke(screen, C.border, 1, 0.4)
	Kit.gradient(screen, C.bgCardLight, C.bgCard, 90)

	-- Kameros "sala" (notch)
	local notch = Kit.create("Frame", {
		Name = "Notch",
		BackgroundColor3 = C.shadow,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 92, 0, 24),
		Position = UDim2.new(0.5, 0, 0, 8),
		ZIndex = 20,
		Parent = screen,
	})
	Kit.corner(notch, UDim.new(1, 0))
	local lens = Kit.create("Frame", {
		Name = "Lens",
		BackgroundColor3 = C.bgCardLight,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 8, 0, 8),
		Position = UDim2.new(1, -16, 0.5, 0),
		ZIndex = 21,
		Parent = notch,
	})
	Kit.corner(lens, UDim.new(1, 0))

	-- Busenos juosta
	local clockLabel = Kit.label({
		parent = screen,
		name = "Clock",
		text = "12:00",
		bold = true,
		textSize = 13,
		size = UDim2.new(0, 60, 0, 24),
		position = UDim2.new(0, 24, 0, 8),
	})
	-- Busenos ikonos, nupiestos Frame'ais (be spalvotu emoji): 5G, signalas, baterija
	local statusIcons = Kit.create("Frame", {
		Name = "StatusIcons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 84, 0, 24),
		Position = UDim2.new(1, -22, 0, 8),
		Parent = screen,
	})
	Kit.label({
		parent = statusIcons,
		name = "Network",
		text = "5G",
		bold = true,
		textSize = 11,
		size = UDim2.new(0, 20, 1, 0),
	})
	for bar = 1, 4 do
		Kit.create("Frame", {
			Name = "Signal" .. bar,
			BackgroundColor3 = C.textPrimary,
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(0, 3, 0, 2 + bar * 2),
			Position = UDim2.new(0, 22 + (bar - 1) * 5, 0, 17),
			Parent = statusIcons,
		})
	end
	local battery = Kit.create("Frame", {
		Name = "Battery",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, 22, 0, 11),
		Position = UDim2.new(1, -3, 0.5, 0),
		Parent = statusIcons,
	})
	Kit.corner(battery, 3)
	Kit.stroke(battery, C.textPrimary, 1, 0.2)
	local batteryFill = Kit.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = C.textPrimary,
		Size = UDim2.new(0.7, -2, 1, -4),
		Position = UDim2.new(0, 2, 0, 2),
		Parent = battery,
	})
	Kit.corner(batteryFill, 1)
	Kit.create("Frame", {
		Name = "Nub",
		BackgroundColor3 = C.textPrimary,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, 2, 0, 4),
		Position = UDim2.new(1, 1, 0.5, 0),
		Parent = battery,
	})

	-- Programeles antraste
	local appHeader = Kit.create("Frame", {
		Name = "AppHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 0, 40),
		Position = UDim2.new(0, 16, 0, 38),
		Parent = screen,
	})
	local appLogo = Kit.create("Frame", {
		Name = "AppLogo",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = appHeader,
	})
	Kit.corner(appLogo, 9)
	Kit.gradient(appLogo, C.goldBright, C.gold, 135)
	Kit.label({
		parent = appLogo,
		name = "Glyph",
		text = "S",
		bold = true,
		textSize = 17,
		color = C.textOnGold,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})
	Kit.label({
		parent = appHeader,
		name = "AppName",
		text = "SocialGym",
		bold = true,
		textSize = 18,
		size = UDim2.new(1, -90, 1, 0),
		position = UDim2.new(0, 40, 0, 0),
	})
	Kit.iconButton({
		parent = appHeader,
		name = "CloseButton",
		text = "✕",
		size = 30,
		radius = UDim.new(1, 0),
		textSize = 13,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, 0, 0.5, 0),
		onClick = function()
			Kit.close("Phone")
		end,
	})

	-- ============================================================
	-- PROFILIO BLOKAS (akademijos paskyra)
	-- ============================================================
	local profileCard = Kit.card({
		parent = screen,
		name = "ProfileCard",
		size = UDim2.new(1, -24, 0, 152),
		position = UDim2.new(0, 12, 0, 84),
		color = C.bg,
		gradientTop = C.bgCardLight,
		gradientBottom = C.bg,
		strokeColor = C.gold,
		strokeTransparency = 0.65,
		radius = 16,
	})
	local profileLogo = Kit.create("Frame", {
		Name = "Logo",
		BackgroundColor3 = C.bgCardLight,
		Size = UDim2.new(0, 48, 0, 48),
		Position = UDim2.new(0, 14, 0, 14),
		Parent = profileCard,
	})
	Kit.corner(profileLogo, UDim.new(1, 0))
	Kit.stroke(profileLogo, C.gold, 2, 0)
	local profileLogoGlyph = Kit.label({
		parent = profileLogo,
		name = "Glyph",
		text = AcademyConfig.Logos[1],
		textSize = 24,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})
	local profileName = Kit.label({
		parent = profileCard,
		name = "Name",
		text = AcademyConfig.DefaultName,
		bold = true,
		textSize = 15,
		size = UDim2.new(1, -90, 0, 20),
		position = UDim2.new(0, 72, 0, 17),
	})
	local profileHandle = Kit.label({
		parent = profileCard,
		name = "Handle",
		text = "@coachacademy",
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, -90, 0, 16),
		position = UDim2.new(0, 72, 0, 39),
	})

	local statsRow = Kit.create("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 0, 36),
		Position = UDim2.new(0, 14, 0, 70),
		Parent = profileCard,
	})
	local statValues = {}
	for index, def in ipairs({
		{ key = "followers", label = "Sekėjai" },
		{ key = "clients", label = "Klientai" },
		{ key = "members", label = "Nariai" },
	}) do
		local column = Kit.create("Frame", {
			Name = "Stat_" .. def.key,
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / 3, 0, 1, 0),
			Position = UDim2.new((index - 1) / 3, 0, 0, 0),
			Parent = statsRow,
		})
		statValues[def.key] = Kit.label({
			parent = column,
			name = "Value",
			text = "0",
			bold = true,
			textSize = 17,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 20),
		})
		Kit.label({
			parent = column,
			name = "Caption",
			text = def.label,
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 0, 21),
		})
	end

	local reachCaption = Kit.label({
		parent = profileCard,
		name = "ReachCaption",
		text = "🚶  Iki naujo kliento",
		bold = true,
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(0.6, 0, 0, 14),
		position = UDim2.new(0, 14, 0, 114),
	})
	local reachValue = Kit.label({
		parent = profileCard,
		name = "ReachValue",
		text = "0 / 80",
		bold = true,
		textSize = 12,
		color = C.goldBright,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0.4, -14, 0, 14),
		position = UDim2.new(1, -14, 0, 114),
		anchor = Vector2.new(1, 0),
	})
	local reachBar = Kit.progressBar({
		parent = profileCard,
		name = "ReachBar",
		size = UDim2.new(1, -28, 0, 6),
		position = UDim2.new(0, 14, 0, 134),
	})

	-- ============================================================
	-- TURINIO SRITIS + APATINIS TAB BAR
	-- ============================================================
	local content = Kit.create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -(244 + 70)),
		Position = UDim2.new(0, 0, 0, 244),
		Parent = screen,
	})

	local tabBar = Kit.create("Frame", {
		Name = "TabBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.new(0, 0, 1, -70),
		Parent = screen,
	})
	-- Fonas: apacioje suapvalinti kampai (kaip ekrano), virsuje -- tiesus krastas.
	-- ClipsDescendants nepaiso UICorner, todel kampus formuojam patys.
	local tabBarBg = Kit.create("Frame", {
		Name = "Bg",
		BackgroundColor3 = C.bg,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = tabBar,
	})
	Kit.corner(tabBarBg, 28)
	Kit.create("Frame", {
		Name = "BgTop",
		BackgroundColor3 = C.bg,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = tabBar,
	})
	Kit.divider({ parent = tabBar, size = UDim2.new(1, -40, 0, 1), position = UDim2.new(0, 20, 0, 0), strength = 0.6 })
	local homeIndicator = Kit.create("Frame", {
		Name = "HomeIndicator",
		BackgroundColor3 = C.textSecondary,
		BackgroundTransparency = 0.4,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0, 110, 0, 4),
		Position = UDim2.new(0.5, 0, 1, -7),
		Parent = tabBar,
	})
	Kit.corner(homeIndicator, UDim.new(1, 0))

	local pages = {}
	local tabButtons = {}
	local currentTab = "posts"
	local TAB_DEFS = {
		{ key = "posts", label = "Įrašai", icon = "📣" },
		{ key = "clients", label = "Klientai", icon = "🚶" },
		{ key = "fighters", label = "Kovotojai", icon = "🥊" },
	}

	local function selectTab(key)
		currentTab = key
		for tabKey, page in pairs(pages) do
			page.Visible = tabKey == key
		end
		for tabKey, entry in pairs(tabButtons) do
			local active = tabKey == key
			Kit.tween(entry.label, 0.15, { TextColor3 = active and C.goldBright or C.textSecondary })
			Kit.tween(entry.icon, 0.15, { TextTransparency = active and 0 or 0.45 })
			Kit.tween(entry.dot, 0.15, { BackgroundTransparency = active and 0 or 1 })
		end
	end

	for index, def in ipairs(TAB_DEFS) do
		local btn = Kit.create("TextButton", {
			Name = "Tab_" .. def.key,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1 / #TAB_DEFS, 0, 0, 52),
			Position = UDim2.new((index - 1) / #TAB_DEFS, 0, 0, 4),
			Parent = tabBar,
		})
		local icon = Kit.label({
			parent = btn,
			name = "Icon",
			text = def.icon,
			textSize = 18,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 22),
			position = UDim2.new(0, 0, 0, 6),
		})
		local text = Kit.label({
			parent = btn,
			name = "Label",
			text = def.label,
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 0, 30),
		})
		local dot = Kit.create("Frame", {
			Name = "ActiveDot",
			BackgroundColor3 = C.gold,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 18, 0, 3),
			Position = UDim2.new(0.5, 0, 0, 0),
			Parent = btn,
		})
		Kit.corner(dot, UDim.new(1, 0))
		tabButtons[def.key] = { button = btn, label = text, icon = icon, dot = dot }
		btn.Activated:Connect(function()
			selectTab(def.key)
		end)
	end

	local function makePage(key)
		local page = Kit.scroll({
			parent = content,
			name = "Page_" .. key,
			paddingLeft = 12,
			paddingRight = 10,
			paddingTop = 10,
			paddingBottom = 14,
			spacing = 8,
			visible = key == currentTab,
		})
		page.ScrollBarThickness = 3
		Kit.scrollFade(page, C.bgCard)
		pages[key] = page
		return page
	end

	-- ============================================================
	-- 1. ĮRAŠAI (skelbimas + srautas)
	-- ============================================================
	local postsPage = makePage("posts")
	Kit.label({
		parent = postsPage,
		name = "ComposeCaption",
		text = "NAUJAS ĮRAŠAS",
		bold = true,
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 16),
		order = 1,
	})

	local postCards = {}
	for index, itemId in ipairs(MarketingConfig.Order) do
		local item = MarketingConfig.Items[itemId]
		local cardFrame, cardStroke = Kit.card({
			parent = postsPage,
			name = "Post_" .. itemId,
			size = UDim2.new(1, 0, 0, 66),
			order = 1 + index,
			radius = 14,
			clip = true,
		})
		local iconTile = Kit.create("Frame", {
			Name = "IconTile",
			BackgroundColor3 = C.bg,
			Size = UDim2.new(0, 40, 0, 40),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = cardFrame,
		})
		Kit.corner(iconTile, 11)
		Kit.stroke(iconTile, C.border, 1, 0.3)
		local iconLabel = Kit.label({
			parent = iconTile,
			name = "Icon",
			text = POST_ICONS[itemId] or "📣",
			textSize = 19,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		local title = Kit.label({
			parent = cardFrame,
			name = "Title",
			text = item.label,
			bold = true,
			textSize = 13,
			size = UDim2.new(1, -150, 0, 16),
			position = UDim2.new(0, 62, 0, 15),
		})
		Kit.label({
			parent = cardFrame,
			name = "Meta",
			text = string.format("+%d–%d sekėjų · +%d–%d pasiek.", item.followersMin, item.followersMax, item.reachMin, item.reachMax),
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, -146, 0, 16),
			position = UDim2.new(0, 62, 0, 34),
		})
		local postButton = Kit.button({
			parent = cardFrame,
			name = "PostButton",
			text = "Skelbti",
			variant = "gold",
			size = UDim2.new(0, 76, 0, 30),
			position = UDim2.new(1, -12, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			textSize = 12,
			radius = 9,
			onClick = function()
				State.fire("MarketingPostContent", itemId)
			end,
		})
		local cooldownTrack = Kit.create("Frame", {
			Name = "CooldownTrack",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(1, -150, 0, 3),
			Position = UDim2.new(0, 62, 1, -12),
			Visible = false,
			Parent = cardFrame,
		})
		Kit.corner(cooldownTrack, UDim.new(1, 0))
		local cooldownFill = Kit.create("Frame", {
			Name = "Fill",
			BackgroundColor3 = C.steelBright,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = cooldownTrack,
		})
		Kit.corner(cooldownFill, UDim.new(1, 0))
		postCards[itemId] = {
			icon = iconLabel,
			item = item,
			stroke = cardStroke,
			title = title,
			button = postButton,
			track = cooldownTrack,
			fill = cooldownFill,
		}
	end

	local feedCaption = Kit.label({
		parent = postsPage,
		name = "FeedCaption",
		text = "VEIKLA",
		bold = true,
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 16),
		order = 20,
	})
	feedCaption.Size = UDim2.new(1, 0, 0, 24)
	feedCaption.TextYAlignment = Enum.TextYAlignment.Bottom

	local feedRows = {}

	local function renderPostTimers()
		local s = State.get()
		local now = State.now()
		local lastPostTimes = s.marketing.lastPostTimes or {}
		for itemId, entry in pairs(postCards) do
			local item = entry.item
			if item.locked then
				entry.button.SetEnabled(false)
				entry.button.SetText("Netrukus")
				entry.icon.TextTransparency = 0.5
				entry.track.Visible = false
				entry.title.TextColor3 = C.textSecondary
			else
				entry.title.TextColor3 = C.textPrimary
				local lastPost = lastPostTimes[itemId]
				local remaining = lastPost and (lastPost + item.cooldown - now) or 0
				if remaining > 0 then
					entry.button.SetEnabled(false)
					entry.button.SetText(Kit.formatDuration(remaining))
					entry.track.Visible = true
					entry.fill.Size = UDim2.new(1 - remaining / item.cooldown, 0, 1, 0)
					entry.stroke.Color = C.border
				else
					entry.button.SetEnabled(true)
					entry.button.SetText("Skelbti")
					entry.track.Visible = false
					entry.stroke.Color = C.gold
				end
			end
		end
	end

	local function renderFeed()
		for _, row in ipairs(feedRows) do
			row:Destroy()
		end
		table.clear(feedRows)

		local feed = State.get().feed or {}
		if #feed == 0 then
			local empty = Kit.label({
				parent = postsPage,
				name = "FeedEmpty",
				text = "Dar nieko nepaskelbei. Pirmas įrašas pritrauks sekėjų — o sekėjai atveda klientus.",
				textSize = 12,
				color = C.textSecondary,
				wrap = true,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -16, 0, 44),
				order = 21,
			})
			table.insert(feedRows, empty)
			return
		end

		local now = State.now()
		for index, entry in ipairs(feed) do
			if index > 12 then
				break
			end
			local isWalkIn = entry.kind == "walkin"
			local row = Kit.create("Frame", {
				Name = "Feed" .. index,
				BackgroundColor3 = isWalkIn and C.bgCardLight or C.bg,
				BackgroundTransparency = isWalkIn and 0 or 0.35,
				Size = UDim2.new(1, 0, 0, 50),
				LayoutOrder = 20 + index,
				Parent = postsPage,
			})
			Kit.corner(row, 12)
			if isWalkIn then
				Kit.stroke(row, C.gold, 1, 0.45)
			end
			Kit.label({
				parent = row,
				name = "Icon",
				text = isWalkIn and "🚶" or (POST_ICONS[entry.itemId] or "📣"),
				textSize = 16,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(0, 30, 1, 0),
				position = UDim2.new(0, 6, 0, 0),
			})
			Kit.label({
				parent = row,
				name = "Title",
				text = isWalkIn and ("Naujas klientas: " .. (entry.title or "?")) or (entry.title or "Įrašas"),
				bold = true,
				textSize = 12,
				color = isWalkIn and C.goldBright or C.textPrimary,
				size = UDim2.new(1, -110, 0, 16),
				position = UDim2.new(0, 40, 0, 9),
			})
			Kit.label({
				parent = row,
				name = "Text",
				text = entry.text or "",
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -52, 0, 14),
				position = UDim2.new(0, 40, 0, 27),
			})
			Kit.label({
				parent = row,
				name = "Time",
				text = Kit.formatTimeAgo(now - (entry.time or now)),
				textSize = 12,
				color = C.textSecondary,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 70, 0, 14),
				position = UDim2.new(1, -10, 0, 10),
				anchor = Vector2.new(1, 0),
			})
			table.insert(feedRows, row)
		end
	end

	-- ============================================================
	-- 2. KLIENTAI (walk-in / bandomieji)
	-- ============================================================
	local clientsPage = makePage("clients")
	local clientRows = {}

	local function renderClients()
		for _, row in ipairs(clientRows) do
			row:Destroy()
		end
		table.clear(clientRows)

		local s = State.get()
		local trials = {}
		local members = 0
		for _, student in ipairs(s.students or {}) do
			if student.karjerosStadija == "Trial" then
				table.insert(trials, student)
			else
				members += 1
			end
		end

		local intro = Kit.card({
			parent = clientsPage,
			name = "Intro",
			size = UDim2.new(1, 0, 0, 0),
			autoSize = Enum.AutomaticSize.Y,
			order = 1,
			radius = 14,
			color = C.bg,
			gradient = false,
		})
		Kit.padding(intro, 10, 12, 10, 12)
		Kit.label({
			parent = intro,
			name = "Text",
			text = string.format(
				"Klientai ateina patys, kai įrašų pasiekiamumas sukaupia ribą. Po %d nemokamų treniruočių patenkinti (≥ %d%%) tampa nariais.",
				TrainingConfig.Trial.maxSessions, TrainingConfig.Trial.convertThreshold
			),
			textSize = 12,
			color = C.textSecondary,
			wrap = true,
			size = UDim2.new(1, 0, 0, 0),
			autoSize = Enum.AutomaticSize.Y,
		})
		table.insert(clientRows, intro)

		local caption = Kit.label({
			parent = clientsPage,
			name = "Caption",
			text = string.format("BANDOMIEJI  •  %d", #trials),
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 22),
			alignY = Enum.TextYAlignment.Bottom,
			order = 2,
		})
		table.insert(clientRows, caption)

		if #trials == 0 then
			local empty = Kit.emptyState({
				parent = clientsPage,
				icon = "🚪",
				title = "Kol kas tuščia",
				text = "Skelbk įrašus — augantis pasiekiamumas atves naujų klientų.",
				size = UDim2.new(1, 0, 0, 150),
				order = 3,
			})
			table.insert(clientRows, empty)
		end

		for index, student in ipairs(trials) do
			local satisfaction = student.satisfactionScore or 0
			local sessions = student.trialSessionsCompleted or 0
			local good = satisfaction >= TrainingConfig.Trial.convertThreshold
			local row = Kit.card({
				parent = clientsPage,
				name = "Client" .. index,
				size = UDim2.new(1, 0, 0, 78),
				order = 2 + index,
				radius = 14,
			})
			Kit.avatar({
				parent = row,
				text = student.name,
				size = 36,
				position = UDim2.new(0, 12, 0, 12),
				ringColor = C.steelBright,
			})
			Kit.label({
				parent = row,
				name = "Name",
				text = student.name,
				bold = true,
				textSize = 13,
				size = UDim2.new(1, -120, 0, 16),
				position = UDim2.new(0, 58, 0, 13),
			})
			Kit.label({
				parent = row,
				name = "Sessions",
				text = string.format("Treniruotės %d/%d", sessions, TrainingConfig.Trial.maxSessions),
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -120, 0, 14),
				position = UDim2.new(0, 58, 0, 31),
			})
			Kit.badge({
				parent = row,
				text = good and "Liks" or "Abejoja",
				color = good and C.gold or C.crimsonBright,
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, -12, 0, 13),
			})
			local bar = Kit.progressBar({
				parent = row,
				size = UDim2.new(1, -110, 0, 6),
				position = UDim2.new(0, 58, 0, 56),
				value = satisfaction / 100,
			})
			if not good then
				bar.SetColor(C.crimson, C.crimsonBright)
			end
			Kit.label({
				parent = row,
				name = "Satisfaction",
				text = string.format("%d%%", satisfaction),
				bold = true,
				textSize = 12,
				color = good and C.goldBright or C.crimsonBright,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 40, 0, 14),
				position = UDim2.new(1, -12, 0, 52),
				anchor = Vector2.new(1, 0),
			})
			table.insert(clientRows, row)
		end

		local membersNote = Kit.label({
			parent = clientsPage,
			name = "MembersNote",
			text = string.format("Nuolatinių narių akademijoje: %d", members),
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			order = 100,
		})
		table.insert(clientRows, membersNote)
	end

	-- ============================================================
	-- 3. KOVOTOJAI (kiekvieno atskira paskyra)
	-- ============================================================
	local fightersPage = makePage("fighters")
	local fighterRows = {}

	local function renderFighters()
		for _, row in ipairs(fighterRows) do
			row:Destroy()
		end
		table.clear(fighterRows)

		local s = State.get()
		local members = {}
		for _, student in ipairs(s.students or {}) do
			if student.karjerosStadija ~= "Trial" then
				table.insert(members, student)
			end
		end
		table.sort(members, function(a, b)
			return fanCount(a, s.marketing.followers) > fanCount(b, s.marketing.followers)
		end)

		if #members == 0 then
			local empty = Kit.emptyState({
				parent = fightersPage,
				icon = "🥊",
				title = "Dar nėra kovotojų",
				text = "Kai bandomieji klientai taps nariais, jie susikurs savo paskyras.",
				size = UDim2.new(1, 0, 0, 160),
				order = 1,
			})
			table.insert(fighterRows, empty)
			return
		end

		for index, student in ipairs(members) do
			local record = student.record or {}
			local tier = FightConfig.Ladder[student.careerTier or 1]
			local row = Kit.card({
				parent = fightersPage,
				name = "Account" .. index,
				size = UDim2.new(1, 0, 0, 108),
				order = index,
				radius = 14,
			})
			Kit.avatar({
				parent = row,
				text = student.name,
				size = 42,
				position = UDim2.new(0, 12, 0, 12),
				ringColor = Kit.potentialColor(student.potencialas),
			})
			local nameLabel = Kit.label({
				parent = row,
				name = "Name",
				text = student.name,
				bold = true,
				textSize = 13,
				size = UDim2.new(1, -150, 0, 16),
				position = UDim2.new(0, 64, 0, 14),
			})
			if (student.tournamentWins or 0) > 0 or (student.careerTier or 1) >= #FightConfig.Ladder then
				-- patvirtinta paskyra: auksine varnele (be spalvoto emoji)
				nameLabel.RichText = true
				nameLabel.Text = student.name .. "  <font color=\"#D4AF37\">✓</font>"
			end
			Kit.label({
				parent = row,
				name = "Handle",
				text = "@" .. toHandle(student.name),
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -150, 0, 14),
				position = UDim2.new(0, 64, 0, 32),
			})
			Kit.label({
				parent = row,
				name = "FansValue",
				text = Kit.formatNumber(fanCount(student, s.marketing.followers)),
				bold = true,
				textSize = 15,
				color = C.goldBright,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 80, 0, 18),
				position = UDim2.new(1, -12, 0, 12),
				anchor = Vector2.new(1, 0),
			})
			Kit.label({
				parent = row,
				name = "FansCaption",
				text = "fanų",
				textSize = 12,
				color = C.textSecondary,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 80, 0, 12),
				position = UDim2.new(1, -12, 0, 31),
				anchor = Vector2.new(1, 0),
			})

			local status
			if student.injured then
				status = "🩹 Atsigauna po traumos. Grįšiu stipresnis!"
			elseif (student.tournamentWins or 0) > 0 then
				status = string.format("🏆 %d× turnyro čempionas. Kitas tikslas — dar vienas diržas.", student.tournamentWins)
			elseif (record.wins or 0) > 0 then
				status = string.format("🥊 Rekordas %d-%d. %s lygis — einam toliau!", record.wins or 0, record.losses or 0, Kit.translate("ladder", tier and tier.name))
			elseif student.competitionReady then
				status = "⚔️ Pasiruošęs pirmai kovai. Laukiu varžovo!"
			else
				status = "💪 Treniruotės kiekvieną dieną. Kelias į ringą prasidėjo."
			end
			local bubble = Kit.create("Frame", {
				Name = "PostBubble",
				BackgroundColor3 = C.bg,
				BackgroundTransparency = 0.2,
				Size = UDim2.new(1, -24, 0, 38),
				Position = UDim2.new(0, 12, 0, 60),
				Parent = row,
			})
			Kit.corner(bubble, 9)
			Kit.label({
				parent = bubble,
				name = "Text",
				text = status,
				textSize = 12,
				color = C.textPrimary,
				wrap = true,
				size = UDim2.new(1, -16, 1, 0),
				position = UDim2.new(0, 8, 0, 0),
			})
			table.insert(fighterRows, row)
		end
	end

	-- ============================================================
	-- DUOMENU ATVAIZDAVIMAS
	-- ============================================================
	local compactPhone = false

	local function renderProfile()
		local s = State.get()
		local academy = s.academy
		local marketing = s.marketing
		profileLogoGlyph.Text = AcademyConfig.Logos[academy.logoIndex or 1] or AcademyConfig.Logos[1]
		profileName.Text = academy.academyName or AcademyConfig.DefaultName
		if compactPhone then
			profileHandle.Text = string.format(
				"%s sekėjų  •  %d/%d pasiek.",
				Kit.formatNumber(marketing.followers or 0), marketing.reachAccumulated or 0, marketing.walkInThreshold or 80
			)
		else
			profileHandle.Text = "@" .. toHandle(academy.academyName or AcademyConfig.DefaultName)
		end

		local trials, members = 0, 0
		for _, student in ipairs(s.students or {}) do
			if student.karjerosStadija == "Trial" then
				trials += 1
			else
				members += 1
			end
		end
		statValues.followers.Text = Kit.formatNumber(marketing.followers or 0)
		statValues.clients.Text = tostring(trials)
		statValues.members.Text = tostring(members)

		local reach = marketing.reachAccumulated or 0
		local threshold = math.max(1, marketing.walkInThreshold or 80)
		reachValue.Text = string.format("%d / %d pasiek.", reach, threshold)
		reachBar.Set(reach / threshold)
		reachCaption.Text = string.format("🚶  Iki naujo kliento: %d", math.max(0, threshold - reach))
	end

	local function renderAll()
		renderProfile()
		renderPostTimers()
		renderFeed()
		renderClients()
		renderFighters()
	end

	local function queue(fn)
		local queued = false
		return function()
			if not panel.IsOpen or queued then
				return
			end
			queued = true
			task.defer(function()
				queued = false
				fn()
			end)
		end
	end

	State.subscribe("marketing", queue(function()
		renderProfile()
		renderPostTimers()
	end))
	State.subscribe("feed", queue(renderFeed))
	State.subscribe("academy", queue(renderProfile))
	State.subscribe("students", queue(function()
		renderProfile()
		renderClients()
		renderFighters()
	end))

	-- Serverio zinute perrasome zaidejui aiskesne forma (lietuviski terminai, klientas atskiroje eiluteje)
	local function friendlyMarketingMessage(message)
		local label, followers, reach = string.match(message, "^(.-) paskelbtas! %+(%d+) sek.-, %+(%d+) reach")
		if not label then
			return message
		end
		local text = string.format("„%s“ paskelbta: +%s sekėjų · +%s pasiek.", label, followers, reach)
		for name in string.gmatch(message, "Naujas klientas atėjo: ([^!]+)!") do
			text ..= "\n🚶 Naujas klientas: " .. name
		end
		return text
	end
	State.onMessage("marketing", function(message)
		if panel.IsOpen then
			panel.Toast(friendlyMarketingMessage(message))
		end
	end)

	panel.Every(1, function()
		clockLabel.Text = os.date("%H:%M")
		renderPostTimers()
	end)
	panel.Every(30, renderFeed)

	panel.OnOpen(function()
		renderAll()
		State.refresh()
	end)

	-- Mazame ekrane profilio kortele suskleidziama i 64px juosta, kad liktu vietos irasams
	panel.OnLayout(function(layout)
		compactPhone = layout.compact == true
		if compactPhone then
			profileCard.Size = UDim2.new(1, -24, 0, 64)
			profileLogo.Size = UDim2.new(0, 36, 0, 36)
			profileLogo.Position = UDim2.new(0, 12, 0, 14)
			profileLogoGlyph.TextSize = 18
			profileName.TextSize = 13
			profileName.Position = UDim2.new(0, 58, 0, 12)
			profileHandle.Position = UDim2.new(0, 58, 0, 30)
			statsRow.Visible = false
			reachCaption.Visible = false
			reachValue.Visible = false
			reachBar.Instance.Position = UDim2.new(0, 58, 0, 50)
			reachBar.Instance.Size = UDim2.new(1, -72, 0, 4)
			content.Position = UDim2.new(0, 0, 0, 156)
			content.Size = UDim2.new(1, 0, 1, -(156 + 70))
		else
			profileCard.Size = UDim2.new(1, -24, 0, 152)
			profileLogo.Size = UDim2.new(0, 48, 0, 48)
			profileLogo.Position = UDim2.new(0, 14, 0, 14)
			profileLogoGlyph.TextSize = 24
			profileName.TextSize = 15
			profileName.Position = UDim2.new(0, 72, 0, 17)
			profileHandle.Position = UDim2.new(0, 72, 0, 39)
			statsRow.Visible = true
			reachCaption.Visible = true
			reachValue.Visible = true
			reachBar.Instance.Position = UDim2.new(0, 14, 0, 134)
			reachBar.Instance.Size = UDim2.new(1, -28, 0, 6)
			content.Position = UDim2.new(0, 0, 0, 244)
			content.Size = UDim2.new(1, 0, 1, -(244 + 70))
		end
		if panel.IsOpen then
			renderProfile()
		end
	end)

	selectTab("posts")
	return panel
end

return PhonePanel
