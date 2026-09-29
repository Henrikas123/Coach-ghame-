--[[
	ProfilePanel
	Trenerio profilis: reputacijos lygis ir zvaigzdes, karjeros statistika,
	pinigai/pelnas, karjeros kelias (Vietines kovos -> Pasaulio titulas) ir trofeju lentyna.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local DataSchema = require(Modules:WaitForChild("DataSchema"))
local FightConfig = require(Modules:WaitForChild("FightConfig"))
local TournamentConfig = require(Modules:WaitForChild("TournamentConfig"))
local AcademyConfig = require(Modules:WaitForChild("AcademyConfig"))
local SponsorConfig = require(Modules:WaitForChild("SponsorConfig"))

local ProfilePanel = {}

-- Karjeros laiptai: pirmi 3 atitinka FightConfig.Ladder, paskutiniai 2 -- ateities tikslai
local CAREER_STEPS = {
	{ name = "Vietinės kovos", ladderIndex = 1, icon = "🥊" },
	{ name = "Regionas", ladderIndex = 2, icon = "🗺️" },
	{ name = "WBF kontraktas", ladderIndex = 3, icon = "📝" },
	{ name = "Reitingai", ladderIndex = nil, icon = "📊" },
	{ name = "Pasaulio titulas", ladderIndex = nil, icon = "👑" },
}

function ProfilePanel.create(Kit, State)
	local C = Kit.Colors
	local player = Players.LocalPlayer

	local panel = Kit.createPanel({
		key = "Profile",
		title = "Trenerio profilis",
		subtitle = "Karjera, reputacija ir pasiekimai",
		icon = "👤",
		accent = "gold",
		maxSize = Vector2.new(760, 680),
	})

	local scroll = Kit.scroll({
		parent = panel.Body,
		name = "Content",
		size = UDim2.new(1, -8, 1, -10),
		paddingTop = 16,
		paddingBottom = 20,
		paddingLeft = 20,
		paddingRight = 8,
		spacing = 16,
	})
	Kit.scrollFade(scroll)

	-- ========================================================
	-- HERO KORTELE
	-- ========================================================
	local hero = Kit.card({
		parent = scroll,
		name = "Hero",
		size = UDim2.new(1, 0, 0, 136),
		order = 1,
		gradientTop = C.bgCardLight,
		gradientBottom = C.bgCard,
		strokeColor = C.gold,
		strokeTransparency = 0.6,
	})

	local avatarFrame, _, _ = Kit.avatar({
		parent = hero,
		text = player.DisplayName,
		size = 88,
		position = UDim2.new(0, 20, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		ringThickness = 2,
	})
	local avatarImage = Kit.create("ImageLabel", {
		Name = "Headshot",
		BackgroundTransparency = 1,
		Image = "",
		Size = UDim2.new(1, 0, 1, 0),
		ScaleType = Enum.ScaleType.Crop,
		Parent = avatarFrame,
	})
	Kit.corner(avatarImage, UDim.new(1, 0))
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and type(content) == "string" then
			avatarImage.Image = content
		end
	end)

	Kit.label({
		parent = hero,
		name = "Name",
		text = player.DisplayName,
		bold = true,
		textSize = 22,
		size = UDim2.new(1, -300, 0, 26),
		position = UDim2.new(0, 126, 0, 18),
	})
	local handleLabel = Kit.label({
		parent = hero,
		name = "Handle",
		text = "@" .. player.Name,
		textSize = 13,
		color = C.textSecondary,
		size = UDim2.new(1, -300, 0, 18),
		position = UDim2.new(0, 126, 0, 45),
	})
	-- Zvaigzdes + lygio zyme vienoje eiluteje (zyme seka iskart po zvaigzdziu)
	local tierRow = Kit.create("Frame", {
		Name = "TierRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -300, 0, 22),
		Position = UDim2.new(0, 126, 0, 68),
		Parent = hero,
	})
	Kit.list(tierRow, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local starsLabel = Kit.label({
		parent = tierRow,
		name = "Stars",
		text = Kit.stars(1),
		bold = true,
		textSize = 18,
		color = C.gold,
		size = UDim2.new(0, 0, 0, 22),
		autoSize = Enum.AutomaticSize.X,
		order = 1,
	})
	starsLabel.TextTruncate = Enum.TextTruncate.None
	local _, tierLabel = Kit.badge({
		parent = tierRow,
		name = "Tier",
		text = "Vietinis treneris",
		color = C.gold,
		order = 2,
	})
	local repBar = Kit.progressBar({
		parent = hero,
		name = "ReputationBar",
		size = UDim2.new(1, -146, 0, 8),
		position = UDim2.new(0, 126, 0, 98),
	})
	local progressCaption = Kit.label({
		parent = hero,
		name = "ProgressCaption",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, -146, 0, 16),
		position = UDim2.new(0, 126, 0, 110),
	})

	Kit.label({
		parent = hero,
		name = "RepCaption",
		text = "REPUTACIJA",
		bold = true,
		textSize = 11,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 160, 0, 14),
		position = UDim2.new(1, -20, 0, 18),
		anchor = Vector2.new(1, 0),
	})
	local repValue = Kit.label({
		parent = hero,
		name = "RepValue",
		text = "0",
		bold = true,
		textSize = 28,
		color = C.goldBright,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 160, 0, 34),
		position = UDim2.new(1, -20, 0, 30),
		anchor = Vector2.new(1, 0),
	})

	-- ========================================================
	-- STATISTIKOS PLYTELES
	-- ========================================================
	local statsGrid = Kit.create("Frame", {
		Name = "StatsGrid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = scroll,
	})
	local statsLayout = Kit.grid(statsGrid, UDim2.new(0.25, -10, 0, 80), UDim2.new(0, 12, 0, 12))

	local tiles = {}
	local TILE_DEFS = {
		{ key = "fighters", icon = "🥊", label = "Kovotojai" },
		{ key = "wins", icon = "🏆", label = "Pergalės" },
		{ key = "winRate", icon = "📈", label = "Pergalių %" },
		{ key = "champs", icon = "🥇", label = "Turnyrų titulai" },
		{ key = "balance", icon = "💰", label = "Balansas", accent = C.goldBright },
		{ key = "profit", icon = "📊", label = "Pelnas" },
		{ key = "followers", icon = "📱", label = "Sekėjai" },
		{ key = "sponsors", icon = "🤝", label = "Remėjai" },
	}
	for index, def in ipairs(TILE_DEFS) do
		tiles[def.key] = Kit.statTile({
			parent = statsGrid,
			name = "Tile_" .. def.key,
			icon = def.icon,
			label = def.label,
			value = "-",
			accent = def.accent,
			order = index,
		})
	end

	-- ========================================================
	-- KARJEROS KELIAS
	-- ========================================================
	Kit.sectionHeader({ parent = scroll, title = "Karjeros kelias", hint = "Geriausio kovotojo pasiekimas", order = 3 })

	local careerCard = Kit.card({
		parent = scroll,
		name = "CareerPath",
		size = UDim2.new(1, 0, 0, 136),
		order = 4,
	})
	local track = Kit.create("Frame", {
		Name = "Track",
		BackgroundColor3 = C.border,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(0.8, 0, 0, 3),
		Position = UDim2.new(0.1, 0, 0, 34),
		Parent = careerCard,
	})
	Kit.corner(track, UDim.new(1, 0))
	local trackFill = Kit.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, 0, 1, 0),
		Parent = track,
	})
	Kit.corner(trackFill, UDim.new(1, 0))
	Kit.gradient(trackFill, C.gold, C.goldBright, 0)

	local stepNodes = {}
	for index, step in ipairs(CAREER_STEPS) do
		local column = Kit.create("Frame", {
			Name = "Step" .. index,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.2, 0, 0, 100),
			Position = UDim2.new((index - 1) * 0.2, 0, 0, 16),
			Parent = careerCard,
		})
		-- Pulsuojantis "halo" aplink dabartini lygi (rodomas tik current mazgui)
		local halo = Kit.create("Frame", {
			Name = "Halo",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 48, 0, 48),
			Position = UDim2.new(0.5, 0, 0, 19),
			Visible = false,
			Parent = column,
		})
		Kit.corner(halo, UDim.new(1, 0))
		local haloStroke = Kit.stroke(halo, C.goldBright, 2, 0.4)
		local node = Kit.create("Frame", {
			Name = "Node",
			BackgroundColor3 = C.bgCardLight,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 38, 0, 38),
			Position = UDim2.new(0.5, 0, 0, 0),
			ZIndex = 2,
			Parent = column,
		})
		Kit.corner(node, UDim.new(1, 0))
		local nodeStroke = Kit.stroke(node, C.border, 2, 0)
		local nodeText = Kit.label({
			parent = node,
			name = "Glyph",
			text = tostring(index),
			bold = true,
			textSize = 15,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
			zIndex = 3,
		})
		local nameLabel = Kit.label({
			parent = column,
			name = "StepName",
			text = step.name,
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -8, 0, 16),
			position = UDim2.new(0, 4, 0, 46),
		})
		local subLabel = Kit.label({
			parent = column,
			name = "StepSub",
			text = "",
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -8, 0, 16),
			position = UDim2.new(0, 4, 0, 64),
		})
		stepNodes[index] = {
			node = node, stroke = nodeStroke, glyph = nodeText, name = nameLabel, sub = subLabel,
			halo = halo, haloStroke = haloStroke,
		}
	end
	local careerFooter = Kit.label({
		parent = careerCard,
		name = "Footer",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -32, 0, 16),
		position = UDim2.new(0, 16, 1, -26),
	})

	-- ========================================================
	-- TROFEJU LENTYNA
	-- ========================================================
	local _, trophyHint = Kit.sectionHeader({ parent = scroll, title = "Trofėjų lentyna", hint = "", order = 5 })

	local trophyGrid = Kit.create("Frame", {
		Name = "TrophyGrid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = scroll,
	})
	local tournamentCount = #TournamentConfig.Tournaments
	Kit.grid(
		trophyGrid,
		UDim2.new(1 / tournamentCount, -math.ceil(10 * (tournamentCount - 1) / tournamentCount) - 1, 0, 124),
		UDim2.new(0, 10, 0, 10)
	)

	local trophySlots = {}
	for index, tournament in ipairs(TournamentConfig.Tournaments) do
		local slot, slotStroke = Kit.card({
			parent = trophyGrid,
			name = "Trophy" .. index,
			order = index,
			color = C.bgCard,
		})
		local cup = Kit.label({
			parent = slot,
			name = "Cup",
			text = "🏆",
			textSize = 34,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 40),
			position = UDim2.new(0, 0, 0, 10),
		})
		local lock = Kit.label({
			parent = slot,
			name = "Lock",
			text = "🔒",
			textSize = 14,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(0, 20, 0, 20),
			position = UDim2.new(0.5, 10, 0, 32),
		})
		Kit.label({
			parent = slot,
			name = "Name",
			text = Kit.displayName(tournament.name),
			bold = true,
			textSize = 13,
			wrap = true,
			align = Enum.TextXAlignment.Center,
			alignY = Enum.TextYAlignment.Top,
			size = UDim2.new(1, -12, 0, 32),
			position = UDim2.new(0, 6, 0, 56),
		})
		local status = Kit.label({
			parent = slot,
			name = "Status",
			text = "",
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			rich = true,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -12, 0, 16),
			position = UDim2.new(0, 6, 1, -26),
		})
		local countBadge, countText = Kit.badge({
			parent = slot,
			name = "Count",
			text = "×1",
			color = C.gold,
			solid = true,
			height = 20,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -8, 0, 8),
		})
		countBadge.Visible = false
		trophySlots[index] = {
			slot = slot, stroke = slotStroke, cup = cup, lock = lock, status = status, tournament = tournament,
			countBadge = countBadge, countText = countText,
		}
	end

	-- ========================================================
	-- DUOMENU ATVAIZDAVIMAS
	-- ========================================================
	local function careerSummary(students)
		local summary = {
			fighters = #students,
			members = 0,
			trials = 0,
			wins = 0,
			losses = 0,
			draws = 0,
			champs = 0,
			bestTier = 0,
			bestStudent = nil,
			tierCounts = {},
		}
		for _, student in ipairs(students) do
			if student.karjerosStadija == "Trial" then
				summary.trials += 1
			else
				summary.members += 1
			end
			local record = student.record or {}
			summary.wins += record.wins or 0
			summary.losses += record.losses or 0
			summary.draws += record.draws or 0
			summary.champs += student.tournamentWins or 0
			local tier = student.careerTier or 1
			if student.competitionReady or (record.wins or 0) + (record.losses or 0) > 0 then
				summary.tierCounts[tier] = (summary.tierCounts[tier] or 0) + 1
				local better = tier > summary.bestTier
				if not better and tier == summary.bestTier and summary.bestStudent then
					better = (student.tierWins or 0) > (summary.bestStudent.tierWins or 0)
				end
				if better then
					summary.bestTier = tier
					summary.bestStudent = student
				end
			end
		end
		return summary
	end

	local function renderHero(s)
		local rep = s.reputation
		local academy = s.academy
		local logo = AcademyConfig.Logos[academy.logoIndex or 1] or AcademyConfig.Logos[1]
		handleLabel.Text = string.format("@%s  •  %s %s", player.Name, logo, academy.academyName or AcademyConfig.DefaultName)
		starsLabel.Text = Kit.stars(rep.stars or 1)
		tierLabel.Text = Kit.translate("tiers", rep.tierName)
		repValue.Text = Kit.formatNumber(rep.reputacija or 0)

		local current = rep.reputacija or 0
		local tiers = DataSchema.CoachReputationTiers
		local tierIndex = rep.tierIndex or 1
		local floorValue = tiers[tierIndex] and tiers[tierIndex].winsRequired or 0
		local nextRequired = rep.nextTierWinsRequired
		if nextRequired then
			local span = math.max(1, nextRequired - floorValue)
			repBar.Set((current - floorValue) / span)
			progressCaption.Text = string.format(
				"%d / %d iki „%s“",
				current, nextRequired, Kit.translate("tiers", rep.nextTierName)
			)
		else
			repBar.Set(1)
			progressCaption.Text = "Aukščiausias lygis pasiektas"
		end
	end

	local function renderTiles(s, summary)
		local fights = summary.wins + summary.losses + summary.draws
		tiles.fighters.Set(tostring(summary.fighters), string.format("%d narių  •  %d bandomųjų", summary.members, summary.trials))
		tiles.wins.Set(tostring(summary.wins), string.format("Pralaimėjimai: %d", summary.losses))
		if fights > 0 then
			tiles.winRate.Set(string.format("%d%%", math.floor(summary.wins / fights * 100 + 0.5)), string.format("%d kovų", fights))
		else
			tiles.winRate.Set("—", "Dar nekovota")
		end
		tiles.champs.Set(tostring(summary.champs), "Turnyrų čempionai", summary.champs > 0 and C.goldBright or C.textPrimary)
		tiles.balance.Set(s.money and Kit.formatMoney(s.money) or "—", "Dabartinis biudžetas")

		local earned = s.stats.lifetimeEarned or 0
		local spent = s.stats.lifetimeSpent or 0
		local profit = earned - spent
		tiles.profit.Set(
			Kit.formatSignedMoney(profit),
			string.format("+%s  /  -%s", Kit.formatMoney(earned), Kit.formatMoney(spent)),
			profit > 0 and C.goldBright or (profit < 0 and C.crimsonBright or C.textPrimary)
		)
		tiles.followers.Set(Kit.formatNumber(s.marketing.followers or 0), "Socialiniai tinklai")
		tiles.sponsors.Set(
			string.format("%d / %d", #(s.sponsor.sponsors or {}), SponsorConfig.MaxActiveSponsors),
			"Aktyvūs kontraktai"
		)
	end

	local function renderCareer(summary)
		local reached = summary.bestTier -- 0 = dar nera kovojanciu kovotoju
		for index, step in ipairs(CAREER_STEPS) do
			local nodeInfo = stepNodes[index]
			local isReached = step.ladderIndex ~= nil and step.ladderIndex < reached
			local isCurrent = step.ladderIndex ~= nil and step.ladderIndex == reached
			local isNextGoal = step.ladderIndex ~= nil and step.ladderIndex == reached + 1
			nodeInfo.halo.Visible = isCurrent
			nodeInfo.glyph.TextTransparency = 0
			if isCurrent then
				-- dabartinis lygis: numeris ant goldBright + pulsuojantis halo
				nodeInfo.node.BackgroundColor3 = C.goldBright
				nodeInfo.stroke.Color = C.goldBright
				nodeInfo.stroke.Transparency = 0
				nodeInfo.glyph.Text = tostring(index)
				nodeInfo.glyph.TextColor3 = C.textOnGold
				nodeInfo.name.TextColor3 = C.goldBright
			elseif isReached then
				nodeInfo.node.BackgroundColor3 = C.gold
				nodeInfo.stroke.Color = C.gold
				nodeInfo.stroke.Transparency = 0.2
				nodeInfo.glyph.Text = "✓"
				nodeInfo.glyph.TextColor3 = C.textOnGold
				nodeInfo.name.TextColor3 = C.textPrimary
			elseif isNextGoal then
				nodeInfo.node.BackgroundColor3 = C.bgCardLight
				nodeInfo.stroke.Color = C.gold
				nodeInfo.stroke.Transparency = 0
				nodeInfo.glyph.Text = tostring(index)
				nodeInfo.glyph.TextColor3 = C.gold
				nodeInfo.name.TextColor3 = C.textPrimary
			else
				nodeInfo.node.BackgroundColor3 = C.bgCardLight
				nodeInfo.stroke.Color = C.border
				nodeInfo.stroke.Transparency = 0
				nodeInfo.glyph.Text = step.ladderIndex and tostring(index) or "🔒"
				nodeInfo.glyph.TextTransparency = step.ladderIndex and 0 or 0.4
				nodeInfo.glyph.TextColor3 = C.textSecondary
				nodeInfo.name.TextColor3 = C.textSecondary
			end

			nodeInfo.sub.TextColor3 = C.textSecondary
			if step.ladderIndex then
				local count = summary.tierCounts[step.ladderIndex] or 0
				if count > 0 then
					nodeInfo.sub.Text = string.format("%d %s", count, count == 1 and "kovotojas" or "kovotojai")
				elseif isReached then
					nodeInfo.sub.Text = "Pereita"
				elseif isNextGoal then
					nodeInfo.sub.Text = "Kitas tikslas"
					nodeInfo.sub.TextColor3 = C.gold
				else
					nodeInfo.sub.Text = "Užrakinta"
				end
			else
				nodeInfo.sub.Text = "Netrukus"
			end
		end

		local fillRatio = 0
		if reached > 1 then
			fillRatio = (reached - 1) / (#CAREER_STEPS - 1)
		end
		Kit.tween(trackFill, 0.4, { Size = UDim2.new(fillRatio, 0, 1, 0) }, Enum.EasingStyle.Quint)

		local best = summary.bestStudent
		if best then
			local tier = FightConfig.Ladder[best.careerTier or 1]
			local nextTier = FightConfig.Ladder[(best.careerTier or 1) + 1]
			local text = string.format("Geriausias: %s  •  %s", best.name, Kit.translate("ladder", tier and tier.name))
			if nextTier and tier then
				text ..= string.format("  •  %d/%d pergalių iki „%s“", best.tierWins or 0, tier.winsToPromote, Kit.translate("ladder", nextTier.name))
			end
			careerFooter.Text = text
		else
			careerFooter.Text = "Paruošk kovotoją kovoms (vidutinė statistika ≥ 15), kad pradėtum karjerą."
		end
	end

	local function renderTrophies(s, summary)
		local stars = s.reputation.stars or 1
		local trophies = s.stats.trophies or {}
		local earnedTotal = 0
		for _, slotInfo in ipairs(trophySlots) do
			local tournament = slotInfo.tournament
			local count = trophies[tournament.name] or 0
			earnedTotal += count
			local unlocked = stars >= (tournament.minStars or 1)
			slotInfo.countBadge.Visible = count > 0
			if count > 0 then
				slotInfo.cup.TextTransparency = 0
				slotInfo.lock.Visible = false
				slotInfo.stroke.Color = C.gold
				slotInfo.stroke.Transparency = 0.25
				slotInfo.countText.Text = string.format("×%d", count)
				slotInfo.status.Text = "Iškovota"
				slotInfo.status.TextColor3 = C.goldBright
			else
				slotInfo.cup.TextTransparency = unlocked and 0.55 or 0.8
				slotInfo.lock.Visible = not unlocked
				slotInfo.stroke.Color = C.border
				slotInfo.stroke.Transparency = 0.45
				slotInfo.status.TextColor3 = C.textSecondary
				slotInfo.status.Text = unlocked and "Neiškovota"
					or string.format("Reikia <font color=\"#D4AF37\">%s</font>", string.rep("★", tournament.minStars or 1))
			end
		end
		if trophyHint then
			-- trofejai pagal pavadinima skaiciuojami nuo sio atnaujinimo; bendras skaicius -- is kovotoju
			trophyHint.Text = string.format("Iškovota: %d", math.max(earnedTotal, summary and summary.champs or 0))
		end
	end

	local function render()
		local s = State.get()
		local summary = careerSummary(s.students or {})
		renderHero(s)
		renderTiles(s, summary)
		renderCareer(summary)
		renderTrophies(s, summary)
	end

	local renderQueued = false
	local function queueRender()
		if renderQueued then
			return
		end
		renderQueued = true
		task.defer(function()
			renderQueued = false
			if panel.IsOpen then
				render()
			end
		end)
	end

	State.subscribe("any", queueRender)

	-- Dabartinio karjeros lygio halo pulsavimas (tik kol panele atidaryta)
	local pulseTweens = {}
	local function startPulse()
		for _, nodeInfo in ipairs(stepNodes) do
			nodeInfo.halo.Size = UDim2.new(0, 48, 0, 48)
			nodeInfo.haloStroke.Transparency = 0.4
			local info = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1)
			local grow = TweenService:Create(nodeInfo.halo, info, { Size = UDim2.new(0, 60, 0, 60) })
			local fade = TweenService:Create(nodeInfo.haloStroke, info, { Transparency = 1 })
			grow:Play()
			fade:Play()
			table.insert(pulseTweens, grow)
			table.insert(pulseTweens, fade)
		end
	end
	local function stopPulse()
		for _, tweenObject in ipairs(pulseTweens) do
			tweenObject:Cancel()
		end
		table.clear(pulseTweens)
	end

	panel.OnOpen(function()
		render()
		State.refresh()
		startPulse()
	end)
	panel.OnClose(stopPulse)

	-- Plyteliu tinklelis: siauresniame lange 2 stulpeliai vietoj 4; kompaktiskai -- zemesnes plyteles be paaiskinimu
	panel.OnLayout(function(layout)
		local columns = layout.size.X < 600 and 2 or 4
		local tileHeight = layout.compact and 64 or 80
		statsLayout.CellSize = UDim2.new(1 / columns, -math.ceil(12 * (columns - 1) / columns) - 1, 0, tileHeight)
		for _, tile in pairs(tiles) do
			tile.Sub.Visible = not layout.compact
		end
	end)

	return panel
end

return ProfilePanel
