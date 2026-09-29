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
		{ key = "followers", label = "Followers" },
		{ key = "clients", label = "Clients" },
		{ key = "members", label = "Members" },
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
		text = "🚶  Next walk-in client",
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
		{ key = "posts", label = "Posts", icon = "📣" },
		{ key = "clients", label = "Clients", icon = "🚶" },
		{ key = "fighters", label = "Fighters", icon = "🥊" },
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

	-- ============================================================
	-- IŠŠOKANTYS PRANEŠIMAI (kaip tikrame telefone: nusileidžia iš viršaus, po 2,6 s pakyla)
	-- ============================================================
	local banner = Kit.create("Frame", {
		Name = "Notification",
		BackgroundColor3 = C.bgCardLight,
		BackgroundTransparency = 0.04,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, -20, 0, 56),
		Position = UDim2.new(0.5, 0, 0, -70),
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	Kit.corner(banner, 16)
	Kit.stroke(banner, C.gold, 1, 0.55)
	local bannerIcon = Kit.create("Frame", {
		Name = "Icon",
		BackgroundColor3 = C.bg,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0, 10, 0.5, 0),
		ZIndex = 31,
		Parent = banner,
	})
	Kit.corner(bannerIcon, 10)
	local bannerGlyph = Kit.label({
		parent = bannerIcon,
		name = "Glyph",
		text = "🔔",
		textSize = 18,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
		zIndex = 32,
	})
	Kit.label({
		parent = banner,
		name = "App",
		text = "SOCIALGYM  •  now",
		bold = true,
		textSize = 10,
		color = C.textSecondary,
		size = UDim2.new(1, -64, 0, 12),
		position = UDim2.new(0, 54, 0, 9),
		zIndex = 31,
	})
	local bannerText = Kit.label({
		parent = banner,
		name = "Text",
		text = "",
		rich = true,
		wrap = true,
		textSize = 12,
		alignY = Enum.TextYAlignment.Top,
		size = UDim2.new(1, -64, 0, 30),
		position = UDim2.new(0, 54, 0, 22),
		zIndex = 31,
	})
	local bannerPortrait = nil

	local FAN_HANDLES = {
		"emily.s", "jonas.k", "marta.v", "mike_trains", "boxing.daily", "sofia.fit",
		"tomas.b", "fightfan22", "coach.rico", "nina.t", "ringside.tv", "lukas.p",
	}
	local FAN_COMMENTS = {
		"That jab is crazy 🔥", "Beast mode 💪", "Sign me up!", "Champion in the making 🏆",
		"Clean footwork!", "Where is this gym?", "Let's gooo 🥊", "Those gloves are fire",
	}
	local fanRng = Random.new()
	local function fan()
		return FAN_HANDLES[fanRng:NextInteger(1, #FAN_HANDLES)]
	end

	local notifications = {}
	local showingNotification = false
	local function pumpNotifications()
		if showingNotification then
			return
		end
		showingNotification = true
		task.spawn(function()
			while #notifications > 0 and panel.IsOpen do
				local note = table.remove(notifications, 1)
				bannerText.Text = note.text
				bannerGlyph.Text = note.icon or "🔔"
				if bannerPortrait then
					bannerPortrait.Instance:Destroy()
					bannerPortrait = nil
				end
				if note.fighter then
					bannerPortrait = Kit.fighterView({
						parent = bannerIcon,
						name = note.fighter,
						mode = "portrait",
						corner = UDim.new(0, 10),
						zIndex = 33,
					})
				end
				bannerGlyph.Visible = bannerPortrait == nil
				banner.Position = UDim2.new(0.5, 0, 0, -70)
				banner.Visible = true
				Kit.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, 36) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				task.wait(2.6)
				Kit.tween(banner, 0.25, { Position = UDim2.new(0.5, 0, 0, -70) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.wait(0.35)
			end
			banner.Visible = false
			table.clear(notifications)
			showingNotification = false
		end)
	end
	local function notifyPhone(note)
		if not panel.IsOpen then
			return
		end
		if #notifications >= 6 then
			table.remove(notifications, 1)
		end
		table.insert(notifications, note)
		pumpNotifications()
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
		text = "NEW POST  •  TAP A STORY",
		bold = true,
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 16),
		order = 1,
	})

	-- Įrašų tipai kaip "stories" burbulai: auksinis žiedas = galima skelbti, pilkas su laiku = laukti
	local STORY_LABELS = {
		SparringClip = "Sparring",
		AcademyTour = "Gym tour",
		TransformationPost = "Glow-up",
		CompetitionHighlight = "Highlight",
	}
	local storyRow = Kit.create("Frame", {
		Name = "Stories",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 96),
		LayoutOrder = 2,
		Parent = postsPage,
	})
	local postCards = {}
	local storyCount = #MarketingConfig.Order
	for index, itemId in ipairs(MarketingConfig.Order) do
		local item = MarketingConfig.Items[itemId]
		local cell = Kit.create("Frame", {
			Name = "Post_" .. itemId,
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / storyCount, 0, 1, 0),
			Position = UDim2.new((index - 1) / storyCount, 0, 0, 0),
			Parent = storyRow,
		})
		local bubble = Kit.create("TextButton", {
			Name = "PostButton",
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = C.bg,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 58, 0, 58),
			Position = UDim2.new(0.5, 0, 0, 4),
			Parent = cell,
		})
		Kit.corner(bubble, UDim.new(1, 0))
		local ring = Kit.stroke(bubble, C.gold, 2.5, 0)
		local bubbleScale = Kit.create("UIScale", { Scale = 1, Parent = bubble })
		local iconLabel = Kit.label({
			parent = bubble,
			name = "Icon",
			text = POST_ICONS[itemId] or "📣",
			textSize = 24,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		local cooldownShade = Kit.create("Frame", {
			Name = "Cooldown",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 1, 0),
			Visible = false,
			Parent = bubble,
		})
		Kit.corner(cooldownShade, UDim.new(1, 0))
		local cooldownText = Kit.label({
			parent = cooldownShade,
			name = "Time",
			text = "",
			bold = true,
			textSize = 12,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		local title = Kit.label({
			parent = cell,
			name = "Title",
			text = STORY_LABELS[itemId] or item.label,
			bold = true,
			textSize = 11,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -4, 0, 14),
			position = UDim2.new(0, 2, 0, 66),
		})
		Kit.label({
			parent = cell,
			name = "Meta",
			text = string.format("+%d–%d fans", item.followersMin, item.followersMax),
			textSize = 10,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -4, 0, 12),
			position = UDim2.new(0, 2, 0, 81),
		})
		local entry = {
			item = item,
			icon = iconLabel,
			ring = ring,
			title = title,
			shade = cooldownShade,
			time = cooldownText,
			bubble = bubble,
			ready = false,
		}
		bubble.MouseEnter:Connect(function()
			if entry.ready then
				Kit.tween(bubbleScale, 0.12, { Scale = 1.08 })
			end
		end)
		bubble.MouseLeave:Connect(function()
			Kit.tween(bubbleScale, 0.12, { Scale = 1 })
		end)
		bubble.Activated:Connect(function()
			if not entry.ready then
				Kit.playSfx("Error")
				return
			end
			Kit.playSfx("Click")
			bubbleScale.Scale = 0.88
			Kit.tween(bubbleScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			State.fire("MarketingPostContent", itemId)
		end)
		postCards[itemId] = entry
	end

	local feedCaption = Kit.label({
		parent = postsPage,
		name = "FeedCaption",
		text = "FEED",
		bold = true,
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 16),
		order = 20,
	})
	feedCaption.Size = UDim2.new(1, 0, 0, 24)
	feedCaption.TextYAlignment = Enum.TextYAlignment.Bottom

	local function renderPostTimers()
		local s = State.get()
		local now = State.now()
		local lastPostTimes = s.marketing.lastPostTimes or {}
		for itemId, entry in pairs(postCards) do
			local item = entry.item
			local remaining = 0
			if not item.locked then
				local lastPost = lastPostTimes[itemId]
				remaining = lastPost and (lastPost + item.cooldown - now) or 0
			end
			entry.ready = not item.locked and remaining <= 0
			entry.ring.Color = entry.ready and C.gold or C.border
			entry.ring.Transparency = entry.ready and 0 or 0.3
			entry.icon.TextTransparency = entry.ready and 0 or 0.45
			entry.title.TextColor3 = entry.ready and C.textPrimary or C.textSecondary
			entry.shade.Visible = not entry.ready
			if item.locked then
				entry.time.Text = "Soon"
			elseif remaining > 0 then
				entry.time.Text = Kit.formatDuration(remaining)
			end
		end
	end

	-- ------------------------------------------------------------
	-- Srautas kaip socialinis tinklas: įrašai = nuotraukų kortelės su 3D kovotojais,
	-- "like" skaičius gyvai auga pirmas minutes, nauji klientai -- kompaktiškos eilutės.
	-- Eilutės pernaudojamos (raktas pagal įrašą), todėl 3D vaizdai nekuriami iš naujo.
	-- ------------------------------------------------------------
	local PHOTO_POSTS = 6 -- tiek naujausių įrašų rodoma su nuotrauka, senesni -- kompaktiškai
	local FEED_LIMIT = 12
	local feedEmpty = nil
	local feedItems = {} -- key -> { frame, time, likes = { value, label, pop, target }, timeLabel }

	local function hashText(text)
		local fighters = Kit.fighters()
		if fighters then
			return fighters.hash(text)
		end
		local h = 0
		for i = 1, #text do
			h = (h * 31 + string.byte(text, i)) % 2147483647
		end
		return h
	end

	local function entryKey(entry)
		return string.format("%s|%s|%s", entry.kind or "post", tostring(entry.itemId or entry.title or ""), tostring(entry.time or 0))
	end

	-- kovotojai "nuotraukoje": nariai (arba visi), parenkami pastoviai pagal įrašą
	local function photoFighters(entry)
		local pool = {}
		for _, student in ipairs(State.get().students or {}) do
			if student.karjerosStadija ~= "Trial" then
				table.insert(pool, student.name)
			end
		end
		if #pool == 0 then
			for _, student in ipairs(State.get().students or {}) do
				table.insert(pool, student.name)
			end
		end
		if #pool == 0 then
			pool = { State.get().academy.academyName or "Coach" }
		end
		local seed = hashText(entryKey(entry))
		local first = pool[seed % #pool + 1]
		local second = pool[(seed + 1) % #pool + 1]
		if second == first then
			second = FightConfig.OpponentNames and FightConfig.OpponentNames[seed % #FightConfig.OpponentNames + 1] or "Sparring Partner"
		end
		return first, second
	end

	local POST_STYLE = {
		SparringClip = { sticker = "🥊 SPARRING", caption = "Sparring day: %s vs %s 🔥 #boxing #sparring", duo = true },
		AcademyTour = { sticker = "🏟️ GYM TOUR", caption = "Welcome to the gym! %s is putting in the work 💪 #academy" },
		TransformationPost = { sticker = "📈 GLOW-UP", caption = "%s's glow-up. Hard work pays off 📈 #transformation", pose = "victory" },
		CompetitionHighlight = { sticker = "🏆 HIGHLIGHT", caption = "%s under the lights 🏆 #fightnight", pose = "victory" },
	}

	-- galutinis like skaicius (pagal tikrus sekejus/reach) ir kiek jo jau "surinkta" per laika
	local function likeTarget(entry)
		local item = MarketingConfig.Items[entry.itemId or ""]
		local followers = entry.followers or (item and math.floor((item.followersMin + item.followersMax) / 2)) or 10
		local reach = entry.reach or (item and math.floor((item.reachMin + item.reachMax) / 2)) or 10
		return 24 + followers * 6 + reach * 3 + hashText(entryKey(entry)) % 37
	end
	local function likesAt(entry, now)
		local age = math.max(0, now - (entry.time or now))
		return math.floor(likeTarget(entry) * (1 - math.exp(-age / 50)) + 0.5)
	end

	local function makePhotoPost(entry, key)
		local style = POST_STYLE[entry.itemId] or { sticker = "📣 POST", caption = "New post from %s's gym 💪" }
		local academy = State.get().academy
		local academyName = academy.academyName or AcademyConfig.DefaultName
		local card = Kit.card({
			parent = postsPage,
			name = "Post",
			size = UDim2.new(1, 0, 0, 322),
			radius = 16,
			clip = true,
		})
		-- antraste: akademijos paskyra
		local logo = Kit.create("Frame", {
			Name = "Logo",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(0, 28, 0, 28),
			Position = UDim2.new(0, 10, 0, 8),
			Parent = card,
		})
		Kit.corner(logo, UDim.new(1, 0))
		Kit.stroke(logo, C.gold, 1.5, 0)
		Kit.label({
			parent = logo,
			name = "Glyph",
			text = AcademyConfig.Logos[academy.logoIndex or 1] or AcademyConfig.Logos[1],
			textSize = 14,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		Kit.label({
			parent = card,
			name = "Account",
			text = academyName,
			bold = true,
			textSize = 12,
			size = UDim2.new(1, -90, 0, 15),
			position = UDim2.new(0, 46, 0, 8),
		})
		local timeLabel = Kit.label({
			parent = card,
			name = "Time",
			text = "",
			textSize = 11,
			color = C.textSecondary,
			size = UDim2.new(1, -90, 0, 13),
			position = UDim2.new(0, 46, 0, 23),
		})
		Kit.label({
			parent = card,
			name = "More",
			text = "•••",
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 30, 0, 28),
			position = UDim2.new(1, -12, 0, 8),
			anchor = Vector2.new(1, 0),
		})

		-- "nuotrauka": ringas, prožektorius, kovotojas(-ai)
		local photo = Kit.create("Frame", {
			Name = "Photo",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 0, 206),
			Position = UDim2.new(0, 0, 0, 44),
			ClipsDescendants = true,
			Parent = card,
		})
		Kit.create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 46, 38), Color3.fromRGB(18, 16, 20)), Rotation = 90, Parent = photo })
		local spot = Kit.create("Frame", {
			Name = "Spotlight",
			BackgroundColor3 = Color3.fromRGB(255, 232, 190),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0.8, 0, 0.9, 0),
			Position = UDim2.new(0.5, 0, 0, -10),
			Parent = photo,
		})
		Kit.corner(spot, UDim.new(1, 0))
		Kit.create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(1, 1) }),
			Parent = spot,
		})
		for index, rope in ipairs({ { 0.44, C.crimsonBright }, { 0.56, Color3.fromRGB(235, 235, 240) }, { 0.68, C.steelBright } }) do
			Kit.create("Frame", {
				Name = "Rope" .. index,
				BackgroundColor3 = rope[2],
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 3),
				Position = UDim2.new(0, 0, rope[1], 0),
				Parent = photo,
			})
		end
		-- ringo danga: šviesesnė juosta, ant kurios stovi kovotojai
		local canvas = Kit.create("Frame", {
			Name = "Canvas",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.2, 0),
			Position = UDim2.new(0, 0, 0.8, 0),
			Parent = photo,
		})
		Kit.create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(96, 84, 88), Color3.fromRGB(46, 40, 46)), Rotation = 90, Parent = canvas })
		Kit.create("Frame", {
			Name = "Edge",
			BackgroundColor3 = Color3.fromRGB(235, 225, 210),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Parent = canvas,
		})
		local first, second = photoFighters(entry)
		if style.duo then
			Kit.fighterView({ parent = photo, frameName = "FighterA", name = first, yaw = 55, size = UDim2.new(0.56, 0, 0.94, 0), position = UDim2.new(0.02, 0, 0.96, 0), anchor = Vector2.new(0, 1) })
			Kit.fighterView({ parent = photo, frameName = "FighterB", name = second, yaw = -55, size = UDim2.new(0.56, 0, 0.94, 0), position = UDim2.new(0.98, 0, 0.96, 0), anchor = Vector2.new(1, 1) })
		else
			Kit.fighterView({ parent = photo, frameName = "FighterA", name = first, pose = style.pose, size = UDim2.new(0.7, 0, 0.94, 0), position = UDim2.new(0.5, 0, 0.96, 0), anchor = Vector2.new(0.5, 1) })
		end
		local sticker = Kit.create("Frame", {
			Name = "Sticker",
			BackgroundColor3 = C.bg,
			BackgroundTransparency = 0.2,
			Size = UDim2.new(0, 0, 0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(0, 10, 0, 10),
			Parent = photo,
		})
		Kit.corner(sticker, 8)
		Kit.stroke(sticker, C.gold, 1, 0.4)
		Kit.padding(sticker, 0, 8, 0, 8)
		Kit.label({
			parent = sticker,
			name = "Text",
			text = style.sticker,
			font = Enum.Font.Oswald,
			textSize = 12,
			color = C.goldBright,
			size = UDim2.new(0, 0, 1, 0),
			autoSize = Enum.AutomaticSize.X,
		})

		-- veiksmai: ♥ (gyvai auga), 💬, dalintis; desineje -- tikras rezultatas
		local actions = Kit.create("Frame", {
			Name = "Actions",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -24, 0, 26),
			Position = UDim2.new(0, 12, 0, 256),
			Parent = card,
		})
		local heart = Kit.label({
			parent = actions,
			name = "Heart",
			text = "♥",
			bold = true,
			textSize = 18,
			color = C.crimsonBright,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(0, 20, 1, 0),
		})
		local heartPop = Kit.create("UIScale", { Scale = 1, Parent = heart })
		local likesLabel = Kit.label({
			parent = actions,
			name = "Likes",
			text = "0",
			bold = true,
			textSize = 13,
			size = UDim2.new(0, 60, 1, 0),
			position = UDim2.new(0, 24, 0, 0),
		})
		local commentsLabel = Kit.label({
			parent = actions,
			name = "Comments",
			text = "💬 0",
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(0, 60, 1, 0),
			position = UDim2.new(0, 88, 0, 0),
		})
		Kit.label({
			parent = actions,
			name = "Share",
			text = "↗",
			bold = true,
			textSize = 15,
			color = C.textSecondary,
			size = UDim2.new(0, 20, 1, 0),
			position = UDim2.new(0, 150, 0, 0),
		})
		if entry.followers then
			Kit.badge({
				parent = actions,
				name = "Gain",
				text = string.format("+%d fans", entry.followers),
				color = C.gold,
				height = 20,
				textSize = 11,
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, 0, 0.5, 0),
			})
		end
		local caption = string.format(style.caption, first, second)
		Kit.label({
			parent = card,
			name = "Caption",
			text = string.format("<b>%s</b>  %s", toHandle(academyName), caption),
			rich = true,
			textSize = 12,
			color = C.textPrimary,
			wrap = true,
			alignY = Enum.TextYAlignment.Top,
			size = UDim2.new(1, -24, 0, 32),
			position = UDim2.new(0, 12, 0, 284),
		})
		local counter = Instance.new("NumberValue")
		counter.Value = 0
		counter:GetPropertyChangedSignal("Value"):Connect(function()
			local value = math.floor(counter.Value + 0.5)
			likesLabel.Text = Kit.formatNumber(value)
			commentsLabel.Text = "💬 " .. Kit.formatNumber(math.floor(value / 9))
		end)
		return {
			frame = card,
			entry = entry,
			timeLabel = timeLabel,
			counter = counter,
			heartPop = heartPop,
			shown = 0,
		}
	end

	local function makeWalkInRow(entry)
		local row = Kit.create("Frame", {
			Name = "WalkIn",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(1, 0, 0, 58),
			Parent = postsPage,
		})
		Kit.corner(row, 14)
		Kit.stroke(row, C.gold, 1, 0.45)
		local student = nil
		for _, candidate in ipairs(State.get().students or {}) do
			if candidate.name == entry.title then
				student = candidate
			end
		end
		Kit.fighterCard({
			parent = row,
			student = student or { name = entry.title },
			size = 42,
			showOvr = false,
			position = UDim2.new(0, 8, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
		})
		Kit.label({
			parent = row,
			name = "Title",
			text = "New client: " .. (entry.title or "?"),
			bold = true,
			textSize = 12,
			color = C.goldBright,
			size = UDim2.new(1, -120, 0, 16),
			position = UDim2.new(0, 60, 0, 12),
		})
		Kit.label({
			parent = row,
			name = "Text",
			text = entry.text or "",
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, -68, 0, 14),
			position = UDim2.new(0, 60, 0, 31),
		})
		local timeLabel = Kit.label({
			parent = row,
			name = "Time",
			text = "",
			textSize = 11,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 60, 0, 14),
			position = UDim2.new(1, -10, 0, 12),
			anchor = Vector2.new(1, 0),
		})
		return { frame = row, entry = entry, timeLabel = timeLabel }
	end

	local function makeCompactPost(entry)
		local row = Kit.create("Frame", {
			Name = "PostCompact",
			BackgroundColor3 = C.bg,
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 0, 50),
			Parent = postsPage,
		})
		Kit.corner(row, 12)
		Kit.label({
			parent = row,
			name = "Icon",
			text = POST_ICONS[entry.itemId] or "📣",
			textSize = 16,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(0, 30, 1, 0),
			position = UDim2.new(0, 6, 0, 0),
		})
		Kit.label({
			parent = row,
			name = "Title",
			text = entry.title or "Post",
			bold = true,
			textSize = 12,
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
		local timeLabel = Kit.label({
			parent = row,
			name = "Time",
			text = "",
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 70, 0, 14),
			position = UDim2.new(1, -10, 0, 10),
			anchor = Vector2.new(1, 0),
		})
		return { frame = row, entry = entry, timeLabel = timeLabel }
	end

	-- like skaicius kyla link to, kiek "surinkta" iki dabar; sirdele stukteli
	local function updateLikes(instant)
		local now = State.now()
		for _, item in pairs(feedItems) do
			if item.counter then
				local target = likesAt(item.entry, now)
				if target > item.shown then
					item.shown = target
					if instant then
						item.counter.Value = target
					else
						Kit.tween(item.counter, 0.9, { Value = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						item.heartPop.Scale = 1.35
						Kit.tween(item.heartPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
					end
				end
			end
		end
	end

	local function renderFeed()
		local feed = State.get().feed or {}
		local now = State.now()
		local wanted = {}
		local photos = 0
		for index, entry in ipairs(feed) do
			if index > FEED_LIMIT then
				break
			end
			local key = entryKey(entry)
			local item = feedItems[key]
			if not item then
				if entry.kind == "walkin" then
					item = makeWalkInRow(entry)
				elseif photos < PHOTO_POSTS then
					item = makePhotoPost(entry, key)
				else
					item = makeCompactPost(entry)
				end
				feedItems[key] = item
				item.isNew = true
				if index == 1 and item.counter and now - (entry.time or now) < 10 and postsPage.AbsoluteSize.Y > 0 then
					-- ką tik paskelbtas įrašas: nuslenkam iki srauto, kad matytųsi nuotrauka
					task.defer(function()
						local target = feedCaption.AbsolutePosition.Y - postsPage.AbsolutePosition.Y + postsPage.CanvasPosition.Y - 6
						Kit.tween(postsPage, 0.5, { CanvasPosition = Vector2.new(0, math.max(0, target)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					end)
				end
			end
			if item.counter then
				photos += 1
			end
			item.frame.LayoutOrder = 20 + index
			item.timeLabel.Text = Kit.formatTimeAgo(now - (entry.time or now))
			wanted[key] = true
		end
		for key, item in pairs(feedItems) do
			if not wanted[key] then
				item.frame:Destroy()
				feedItems[key] = nil
			end
		end
		-- naujai sukurti irasai: senesni is karto su galutiniu skaiciumi, naujausi -- auga akyse
		for _, item in pairs(feedItems) do
			if item.isNew and item.counter then
				local age = now - (item.entry.time or now)
				if age > 20 then
					item.shown = likesAt(item.entry, now)
					item.counter.Value = item.shown
				end
			end
			item.isNew = nil
		end
		updateLikes(false)

		if #feed == 0 and not feedEmpty then
			feedEmpty = Kit.label({
				parent = postsPage,
				name = "FeedEmpty",
				text = "Nothing posted yet. Your first post brings followers — and followers bring clients.",
				textSize = 12,
				color = C.textSecondary,
				wrap = true,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -16, 0, 44),
				order = 21,
			})
		elseif #feed > 0 and feedEmpty then
			feedEmpty:Destroy()
			feedEmpty = nil
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
				"Clients walk in when your posts' reach hits the goal. After %d free sessions, happy clients (≥ %d%%) become members.",
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
			text = string.format("ON TRIAL  •  %d", #trials),
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
				title = "Nobody here yet",
				text = "Keep posting — growing reach brings in new clients.",
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
			Kit.fighterCard({
				parent = row,
				student = student,
				size = 40,
				showOvr = false,
				position = UDim2.new(0, 10, 0, 10),
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
				text = string.format("Sessions %d/%d", sessions, TrainingConfig.Trial.maxSessions),
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -120, 0, 14),
				position = UDim2.new(0, 58, 0, 31),
			})
			Kit.badge({
				parent = row,
				text = good and "Staying" or "Unsure",
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
			text = string.format("Full members at the academy: %d", members),
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
				title = "No fighters yet",
				text = "When trial clients become members, they'll set up their own accounts.",
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
			Kit.fighterCard({
				parent = row,
				student = student,
				size = 44,
				position = UDim2.new(0, 10, 0, 10),
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
				text = "fans",
				textSize = 12,
				color = C.textSecondary,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 80, 0, 12),
				position = UDim2.new(1, -12, 0, 31),
				anchor = Vector2.new(1, 0),
			})

			local status
			if student.injured then
				status = "🩹 Recovering from injury. I'll come back stronger!"
			elseif (student.tournamentWins or 0) > 0 then
				status = string.format("🏆 %d× tournament champion. Next goal — another belt.", student.tournamentWins)
			elseif (record.wins or 0) > 0 then
				status = string.format("🥊 Record %d-%d. %s level — let's keep going!", record.wins or 0, record.losses or 0, Kit.translate("ladder", tier and tier.name))
			elseif student.competitionReady then
				status = "⚔️ Ready for my first fight. Bring on an opponent!"
			else
				status = "💪 Training every day. The road to the ring has started."
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
				"%s followers  •  %d/%d reach",
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
		reachValue.Text = string.format("%d / %d reach", reach, threshold)
		reachBar.Set(reach / threshold)
		reachCaption.Text = string.format("🚶  Next walk-in: %d", math.max(0, threshold - reach))
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
		local label, followers, reach = string.match(message, "^(.-) posted! %+(%d+) followers, %+(%d+) reach")
		if not label then
			return message
		end
		local text = string.format("“%s” posted: +%s followers · +%s reach", label, followers, reach)
		for name in string.gmatch(message, "New client walked in: ([^!]+)!") do
			text ..= "\n🚶 New client: " .. name
		end
		return text
	end
	-- Įrašo rezultatas -> telefono pranešimų seka (paskelbta, nauji sekėjai, like, komentaras, klientas)
	State.onMessage("marketing", function(message)
		if not panel.IsOpen then
			return
		end
		local _, followers, reach = string.match(message, "^(.-) posted! %+(%d+) followers, %+(%d+) reach")
		if not followers then
			panel.Toast(friendlyMarketingMessage(message))
			return
		end
		followers = tonumber(followers) or 0
		notifyPhone({ icon = "📣", text = string.format("<b>Posted!</b>  +%d followers · +%s reach", followers, reach) })
		if followers > 1 then
			notifyPhone({ icon = "🔥", text = string.format("<b>%s</b> and %d others started following you", fan(), followers - 1) })
		elseif followers == 1 then
			notifyPhone({ icon = "🔥", text = string.format("<b>%s</b> started following you", fan()) })
		end
		notifyPhone({ icon = "❤️", text = string.format("<b>%s</b> and %d others liked your post", fan(), fanRng:NextInteger(6, 24)) })
		notifyPhone({ icon = "💬", text = string.format("<b>%s</b>: “%s”", fan(), FAN_COMMENTS[fanRng:NextInteger(1, #FAN_COMMENTS)]) })
		for name in string.gmatch(message, "New client walked in: ([^!]+)!") do
			notifyPhone({ fighter = name, text = string.format("<b>%s</b> walked in for a free trial!", name) })
		end
	end)

	panel.Every(1, function()
		clockLabel.Text = os.date("%H:%M")
		renderPostTimers()
		updateLikes(false)
	end)
	panel.Every(10, renderFeed)
	-- kol naujausias įrašas "karštas", retkarčiais ateina like / komentaras
	panel.Every(9, function()
		local newest = (State.get().feed or {})[1]
		if not newest or newest.kind ~= "post" or showingNotification or fanRng:NextNumber() > 0.6 then
			return
		end
		if State.now() - (newest.time or 0) > 240 then
			return
		end
		if fanRng:NextNumber() < 0.6 then
			notifyPhone({ icon = "❤️", text = string.format("<b>%s</b> liked your post", fan()) })
		else
			notifyPhone({ icon = "💬", text = string.format("<b>%s</b>: “%s”", fan(), FAN_COMMENTS[fanRng:NextInteger(1, #FAN_COMMENTS)]) })
		end
	end)

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
