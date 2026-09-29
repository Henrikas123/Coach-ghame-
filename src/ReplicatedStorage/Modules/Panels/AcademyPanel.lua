--[[
	AcademyPanel
	Akademijos (salės) valdymas:
	  - Kovotojai: roster'is + pasirinkto kovotojo kortele (statistika, nuovargis, nuotaika,
	    trauma / Poilsio kambarys, bandomasis laikotarpis, kovos stiliaus keitimas)
	  - Įranga: treniruociu irangos pirkimas (EquipmentConfig)
	  - Išvaizda: pavadinimas, sienu spalva, grindys, logotipas su gyva perziura
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local DataSchema = require(Modules:WaitForChild("DataSchema"))
local FightConfig = require(Modules:WaitForChild("FightConfig"))
local TrainingConfig = require(Modules:WaitForChild("TrainingConfig"))
local InjuryConfig = require(Modules:WaitForChild("InjuryConfig"))
local EquipmentConfig = require(Modules:WaitForChild("EquipmentConfig"))
local AcademyConfig = require(Modules:WaitForChild("AcademyConfig"))

local AcademyPanel = {}

local STAT_ORDER = { "power", "speed", "defense", "stamina", "technique" }

local FOCUS_INFO = {
	Power = { icon = "🥊", name = "Jėga" },
	Speed = { icon = "⚡", name = "Greitis" },
	Defense = { icon = "🛡️", name = "Gynyba" },
	Conditioning = { icon = "🏃", name = "Kondicija" },
	Technique = { icon = "🎯", name = "Technika" },
}

-- Fokuso kilmininkas aprasymams ("+20% naudos is jegos treniruociu")
local FOCUS_GENITIVE = {
	Power = "jėgos",
	Speed = "greičio",
	Defense = "gynybos",
	Conditioning = "kondicijos",
	Technique = "technikos",
}

-- Sienu spalvu pavadinimai (AcademyConfig.WallColors tvarka)
local WALL_COLOR_NAMES = { "Pilka", "Raudona", "Mėlyna", "Žalia", "Auksinė", "Juoda" }

-- Bazine (pradine) iranga, kurios nera EquipmentConfig -- rodoma kaip jau irengta
local STARTER_EQUIPMENT = {
	id = "PunchingBag",
	label = "Bokso maišas",
	description = "Bazinė salės įranga — jėgos treniruotėms.",
	focus = "Power",
}

function AcademyPanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Academy",
		title = "Akademija",
		subtitle = "Kovotojai, įranga ir salės išvaizda",
		icon = "🏛️",
		accent = "gold",
		maxSize = Vector2.new(800, 680),
	})

	local body = panel.Body
	local pages = {}
	local currentPage = "roster"

	local tabs = Kit.tabs({
		parent = body,
		items = {
			{ key = "roster", label = "Kovotojai", icon = "🥊" },
			{ key = "equipment", label = "Įranga", icon = "🏋️" },
			{ key = "style", label = "Išvaizda", icon = "🎨" },
		},
		size = UDim2.new(1, -40, 0, 42),
		position = UDim2.new(0, 20, 0, 14),
		onSelect = function(key)
			currentPage = key
			for pageKey, page in pairs(pages) do
				page.Visible = pageKey == key
			end
		end,
	})

	local pageHolder = Kit.create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.new(0, 0, 0, 70),
		Parent = body,
	})

	local function makePage(key)
		local page = Kit.create("Frame", {
			Name = "Page_" .. key,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Visible = key == currentPage,
			Parent = pageHolder,
		})
		pages[key] = page
		return page
	end

	-- ============================================================
	-- 1. KOVOTOJAI
	-- ============================================================
	local rosterPage = makePage("roster")
	local selectedKey = nil
	local narrow = false
	local showingDetailOnNarrow = false
	local applyNarrow -- forward (apibrezta zemiau)

	local listColumn = Kit.create("Frame", {
		Name = "ListColumn",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 268, 1, -16),
		Position = UDim2.new(0, 20, 0, 0),
		Parent = rosterPage,
	})
	local rosterList = Kit.scroll({
		parent = listColumn,
		name = "RosterList",
		size = UDim2.new(1, 0, 1, 0),
		paddingRight = 8,
		paddingTop = 2,
		paddingLeft = 2,
		paddingBottom = 8,
		spacing = 8,
	})
	Kit.scrollFade(rosterList)

	local detailColumn = Kit.create("Frame", {
		Name = "DetailColumn",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -316, 1, -16),
		Position = UDim2.new(0, 300, 0, 0),
		Parent = rosterPage,
	})
	local backButton = Kit.button({
		parent = detailColumn,
		name = "BackButton",
		text = "Atgal į sąrašą",
		icon = "←",
		variant = "ghost",
		size = UDim2.new(0, 170, 0, 32),
		textSize = 13,
		onClick = function()
			showingDetailOnNarrow = false
			applyNarrow()
		end,
	})
	backButton.Instance.Visible = false

	local detailScroll = Kit.scroll({
		parent = detailColumn,
		name = "Detail",
		paddingRight = 10,
		paddingTop = 2,
		paddingLeft = 2,
		paddingBottom = 12,
		spacing = 12,
	})
	Kit.scrollFade(detailScroll)
	local detailEmpty = Kit.emptyState({
		parent = detailColumn,
		icon = "🥊",
		title = "Pasirink kovotoją",
		text = "Kairėje pasirink narį, kad matytum jo statistiką, būklę ir kovos stilių.",
		size = UDim2.new(1, 0, 0, 160),
	})
	detailEmpty.Position = UDim2.new(0, 0, 0.5, -80)

	-- --- Detalės: antraštės kortelė ---
	local headerCard = Kit.card({ parent = detailScroll, name = "HeaderCard", size = UDim2.new(1, 0, 0, 104), order = 1 })
	local _, detailInitials, detailAvatarRing = Kit.avatar({
		parent = headerCard,
		text = "?",
		size = 60,
		position = UDim2.new(0, 16, 0, 16),
	})
	local detailName = Kit.label({
		parent = headerCard,
		name = "Name",
		text = "",
		bold = true,
		textSize = 20,
		size = UDim2.new(1, -(90 + 100), 0, 24),
		position = UDim2.new(0, 90, 0, 16),
	})
	local detailSub = Kit.label({
		parent = headerCard,
		name = "Sub",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, -(90 + 100), 0, 18),
		position = UDim2.new(0, 90, 0, 42),
	})
	local badgeRow = Kit.create("Frame", {
		Name = "Badges",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -106, 0, 22),
		Position = UDim2.new(0, 90, 0, 68),
		Parent = headerCard,
	})
	Kit.list(badgeRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	Kit.label({
		parent = headerCard,
		name = "RecordCaption",
		text = "REKORDAS",
		bold = true,
		textSize = 10,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 84, 0, 14),
		position = UDim2.new(1, -16, 0, 16),
		anchor = Vector2.new(1, 0),
	})
	local recordValue = Kit.label({
		parent = headerCard,
		name = "Record",
		text = "0-0-0",
		bold = true,
		textSize = 18,
		color = C.goldBright,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 84, 0, 24),
		position = UDim2.new(1, -16, 0, 30),
		anchor = Vector2.new(1, 0),
	})
	local tierValue = Kit.label({
		parent = headerCard,
		name = "Tier",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 84, 0, 16),
		position = UDim2.new(1, -16, 0, 56),
		anchor = Vector2.new(1, 0),
	})

	-- --- Detalės: statistika ---
	local statsCard = Kit.card({
		parent = detailScroll,
		name = "StatsCard",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 4,
	})
	Kit.padding(statsCard, 14, 16, 16, 16)
	Kit.list(statsCard, 10)
	local _, ovrHint = Kit.sectionHeader({ parent = statsCard, title = "Statistika", hint = "OVR 0", order = 0 })
	local statRows = {}
	for index, statId in ipairs(STAT_ORDER) do
		local row = Kit.create("Frame", {
			Name = "Stat_" .. statId,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = index,
			Parent = statsCard,
		})
		-- pavadinimas + MAX zyme vienoje eiluteje (zyme iskart po pavadinimo)
		local nameRow = Kit.create("Frame", {
			Name = "NameRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 108, 1, 0),
			Parent = row,
		})
		Kit.list(nameRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		local statName = Kit.label({
			parent = nameRow,
			order = 1,
			name = "Name",
			text = Kit.translate("stats", statId),
			textSize = 13,
			color = C.textSecondary,
			size = UDim2.new(0, 0, 1, 0),
			autoSize = Enum.AutomaticSize.X,
		})
		statName.TextTruncate = Enum.TextTruncate.None
		local bar = Kit.progressBar({
			parent = row,
			size = UDim2.new(1, -(112 + 56), 0, 8),
			position = UDim2.new(0, 112, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
		})
		local value = Kit.label({
			parent = row,
			name = "Value",
			text = "0",
			bold = true,
			textSize = 13,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 48, 1, 0),
			position = UDim2.new(1, 0, 0, 0),
			anchor = Vector2.new(1, 0),
		})
		local maxBadge = Kit.badge({
			parent = nameRow,
			name = "MaxBadge",
			text = "MAX",
			color = C.gold,
			solid = true,
			height = 16,
			textSize = 10,
			order = 2,
		})
		maxBadge.Visible = false
		statRows[statId] = { bar = bar, value = value, maxBadge = maxBadge }
	end

	-- --- Detalės: būklė (nuovargis, nuotaika, padrąsinimas) ---
	local conditionCard = Kit.card({
		parent = detailScroll,
		name = "ConditionCard",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 5,
	})
	Kit.padding(conditionCard, 14, 16, 16, 16)
	Kit.list(conditionCard, 10)
	Kit.sectionHeader({ parent = conditionCard, title = "Būklė", order = 0 })

	local function conditionRow(name, order, parent)
		local row = Kit.create("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = order,
			Parent = parent or conditionCard,
		})
		Kit.label({
			parent = row,
			name = "Name",
			text = name,
			textSize = 13,
			color = C.textSecondary,
			size = UDim2.new(0, 104, 1, 0),
		})
		local bar = Kit.progressBar({
			parent = row,
			size = UDim2.new(1, -(112 + 56), 0, 8),
			position = UDim2.new(0, 112, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
		})
		local value = Kit.label({
			parent = row,
			name = "Value",
			text = "0",
			bold = true,
			textSize = 13,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 48, 1, 0),
			position = UDim2.new(1, 0, 0, 0),
			anchor = Vector2.new(1, 0),
		})
		return { bar = bar, value = value }
	end
	local fatigueRow = conditionRow("Nuovargis", 1)
	local moraleRow = conditionRow("Nuotaika", 2)
	local conditionCallout = Kit.create("Frame", {
		Name = "Callout",
		BackgroundColor3 = C.crimson,
		BackgroundTransparency = 0.88,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Visible = false,
		Parent = conditionCard,
	})
	Kit.corner(conditionCallout, 10)
	Kit.stroke(conditionCallout, C.crimson, 1, 0.5)
	Kit.padding(conditionCallout, 10, 12, 10, 12)
	Kit.label({
		parent = conditionCallout,
		name = "Icon",
		text = "⚠",
		bold = true,
		textSize = 14,
		color = C.crimsonBright,
		size = UDim2.new(0, 18, 0, 18),
	})
	local conditionHint = Kit.label({
		parent = conditionCallout,
		name = "Hint",
		text = "",
		textSize = 12,
		color = C.textPrimary,
		wrap = true,
		size = UDim2.new(1, -26, 0, 0),
		position = UDim2.new(0, 26, 0, 1),
		autoSize = Enum.AutomaticSize.Y,
	})
	local encourageButton = Kit.button({
		parent = conditionCard,
		name = "EncourageButton",
		text = string.format("Padrąsinti (+%d nuotaikos)", DataSchema.Morale.EncourageGain),
		icon = "💬",
		variant = "steel",
		size = UDim2.new(1, 0, 0, 38),
		order = 4,
	})

	-- --- Detalės: trauma ---
	local injuryCard = Kit.card({
		parent = detailScroll,
		name = "InjuryCard",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 2,
		strokeColor = C.crimsonBright,
		strokeTransparency = 0.3,
		-- lengvas crimson atspalvis (crimson ~10% virs kortelės fono)
		gradientTop = C.bgCardLight:Lerp(C.crimson, 0.12),
		gradientBottom = C.bgCard:Lerp(C.crimson, 0.07),
	})
	Kit.padding(injuryCard, 14, 16, 16, 16)
	Kit.list(injuryCard, 8)
	local injuryTitle = Kit.label({
		parent = injuryCard,
		name = "Title",
		text = "🩹  Trauma",
		bold = true,
		textSize = 15,
		color = C.crimsonBright,
		order = 1,
	})
	local injuryText = Kit.label({
		parent = injuryCard,
		name = "Text",
		text = "",
		textSize = 13,
		color = C.textSecondary,
		wrap = true,
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 2,
	})
	local recoveryButton = Kit.button({
		parent = injuryCard,
		name = "RecoveryButton",
		text = string.format("Poilsio kambarys  •  $%d", InjuryConfig.RecoveryRoomCost),
		icon = "🛏️",
		variant = "gold",
		size = UDim2.new(1, 0, 0, 38),
		order = 3,
	})

	-- --- Detalės: bandomasis laikotarpis ---
	local trialCard = Kit.card({
		parent = detailScroll,
		name = "TrialCard",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 3,
		strokeColor = C.steelBright,
		strokeTransparency = 0.4,
	})
	Kit.padding(trialCard, 14, 16, 16, 16)
	Kit.list(trialCard, 10)
	local _, trialHint = Kit.sectionHeader({ parent = trialCard, title = "Bandomasis laikotarpis", hint = "", accent = C.steelBright, order = 0 })
	local trialSessionsRow = conditionRow("Treniruotės", 1, trialCard)
	local trialSatisfactionRow = conditionRow("Pasitenkinimas", 2, trialCard)
	Kit.label({
		parent = trialCard,
		name = "Explain",
		text = string.format(
			"Po %d treniruočių klientas, kurio pasitenkinimas ≥ %d%%, tampa nariu (+$%d, +%d reputacijos). Kitaip jis išeina.",
			TrainingConfig.Trial.maxSessions, TrainingConfig.Trial.convertThreshold,
			TrainingConfig.Trial.membershipFeeIncome, TrainingConfig.Trial.convertReputationBonus
		),
		textSize = 12,
		color = C.textSecondary,
		wrap = true,
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 3,
	})

	-- --- Detalės: kovos stilius ---
	local styleCard = Kit.card({
		parent = detailScroll,
		name = "StyleCard",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 6,
	})
	Kit.padding(styleCard, 14, 16, 16, 16)
	Kit.list(styleCard, 10)
	Kit.sectionHeader({
		parent = styleCard,
		title = "Kovos stilius",
		hint = string.format("Keitimas: $%d", FightConfig.StyleChangeCost),
		order = 0,
	})
	local styleGrid = Kit.create("Frame", {
		Name = "StyleGrid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = styleCard,
	})
	local styleGridLayout = Kit.grid(styleGrid, UDim2.new(1 / 3, -6, 0, 34), UDim2.new(0, 8, 0, 8))
	local styleMatchup = Kit.create("Frame", {
		Name = "Matchup",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 2,
		Parent = styleCard,
	})
	Kit.list(styleMatchup, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local styleChangeButton = Kit.button({
		parent = styleCard,
		name = "ChangeStyleButton",
		text = "Pasirink naują stilių",
		variant = "gold",
		size = UDim2.new(1, 0, 0, 38),
		order = 3,
		enabled = false,
	})

	local pendingStyle = nil
	local styleChips = {}
	for index, styleId in ipairs(DataSchema.FighterStyles) do
		local chip = Kit.create("TextButton", {
			Name = "Style_" .. index,
			AutoButtonColor = false,
			BackgroundColor3 = C.bgCardLight,
			Text = "",
			LayoutOrder = index,
			Parent = styleGrid,
		})
		Kit.corner(chip, 9)
		local chipStroke = Kit.stroke(chip, C.border, 1, 0.3)
		local chipLabel = Kit.label({
			parent = chip,
			name = "Text",
			text = styleId,
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -8, 1, 0),
			position = UDim2.new(0, 4, 0, 0),
		})
		styleChips[styleId] = { button = chip, stroke = chipStroke, label = chipLabel, hover = false }
	end

	-- ------------------------------------------------------------
	-- Roster'io duomenys
	-- ------------------------------------------------------------
	local function findSelected()
		local students = State.get().students or {}
		for index, student in ipairs(students) do
			if Kit.studentKey(student) == selectedKey then
				return student, index
			end
		end
		return nil, nil
	end

	local function moraleColor(value)
		if value < DataSchema.Morale.LowMoraleThreshold then
			return C.crimson, C.crimsonBright
		elseif value < 60 then
			return C.gold, C.goldBright
		end
		return C.steel, C.steelBright
	end

	local function fatigueColor(value)
		if value >= 70 then
			return C.crimson, C.crimsonBright
		elseif value >= 40 then
			return C.gold, C.goldBright
		end
		return C.steel, C.steelBright
	end

	local function paintStyleChips(student)
		for styleId, chip in pairs(styleChips) do
			local isCurrent = student and student.style == styleId
			local isPending = pendingStyle == styleId
			if isCurrent then
				chip.button.BackgroundColor3 = C.gold
				chip.stroke.Color = C.goldBright
				chip.stroke.Transparency = 0.2
				chip.stroke.Thickness = 1
				chip.label.TextColor3 = C.textOnGold
				chip.label.Text = "✓ " .. styleId
			elseif isPending then
				chip.button.BackgroundColor3 = C.steel
				chip.stroke.Color = C.steelBright
				chip.stroke.Transparency = 0
				chip.stroke.Thickness = 2
				chip.label.TextColor3 = C.textPrimary
				chip.label.Text = styleId
			else
				chip.button.BackgroundColor3 = C.bgCardLight
				chip.stroke.Color = C.border
				chip.stroke.Transparency = chip.hover and 0 or 0.3
				chip.stroke.Thickness = 1
				chip.label.TextColor3 = chip.hover and C.textPrimary or C.textSecondary
				chip.label.Text = styleId
			end
		end

		local shownStyle = pendingStyle or (student and student.style)
		local strongAgainst = shownStyle and FightConfig.StyleAdvantage[shownStyle]
		local weakAgainst = nil
		for attacker, victim in pairs(FightConfig.StyleAdvantage) do
			if victim == shownStyle then
				weakAgainst = attacker
			end
		end
		for _, child in ipairs(styleMatchup:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if strongAgainst or weakAgainst then
			Kit.badge({ parent = styleMatchup, text = "Stiprus prieš: " .. (strongAgainst or "—"), color = C.gold, order = 1 })
			Kit.badge({ parent = styleMatchup, text = "Silpnas prieš: " .. (weakAgainst or "—"), color = C.crimsonBright, order = 2 })
		else
			Kit.badge({ parent = styleMatchup, text = "Subalansuotas: be stiprybių ir silpnybių", color = C.steelBright, order = 1 })
		end

		local money = State.get().money or 0
		if pendingStyle and student and pendingStyle ~= student.style then
			local affordable = money >= FightConfig.StyleChangeCost
			styleChangeButton.SetEnabled(affordable)
			styleChangeButton.SetText(affordable
				and string.format("Keisti į %s  •  $%d", pendingStyle, FightConfig.StyleChangeCost)
				or string.format("Trūksta $%d", FightConfig.StyleChangeCost - money))
		else
			styleChangeButton.SetEnabled(false)
			styleChangeButton.SetText("Pasirink naują stilių")
		end
	end

	for styleId, chip in pairs(styleChips) do
		chip.button.MouseEnter:Connect(function()
			if Kit.isTouchOnly() then
				return
			end
			chip.hover = true
			paintStyleChips((findSelected()))
		end)
		chip.button.MouseLeave:Connect(function()
			chip.hover = false
			paintStyleChips((findSelected()))
		end)
		chip.button.Activated:Connect(function()
			local student = findSelected()
			if not student then
				return
			end
			if student.style == styleId then
				pendingStyle = nil
			else
				pendingStyle = styleId
			end
			paintStyleChips(student)
		end)
	end

	local function updateTimers()
		local student, index = findSelected()
		if not student then
			return
		end
		local now = State.now()
		local encourageLeft = (student.lastEncourageAt or 0) + DataSchema.Morale.EncourageCooldown - now
		if encourageLeft > 0 then
			encourageButton.SetEnabled(false)
			encourageButton.SetText("Padrąsinta  •  vėl po " .. Kit.formatDuration(encourageLeft))
		else
			encourageButton.SetEnabled(true)
			encourageButton.SetText(string.format("Padrąsinti (+%d nuotaikos)", DataSchema.Morale.EncourageGain))
		end

		if student.injured then
			local cooldownLeft = (student.lastRecoveryRoomAt or 0) + InjuryConfig.RecoveryRoomCooldown - now
			local money = State.get().money or 0
			if cooldownLeft > 0 then
				recoveryButton.SetEnabled(false)
				recoveryButton.SetText("Poilsio kambarys ruošiamas  •  " .. Kit.formatDuration(cooldownLeft))
			elseif money < InjuryConfig.RecoveryRoomCost then
				recoveryButton.SetEnabled(false)
				recoveryButton.SetText(string.format("Trūksta $%d Poilsio kambariui", InjuryConfig.RecoveryRoomCost - money))
			else
				recoveryButton.SetEnabled(true)
				recoveryButton.SetText(string.format(
					"Poilsio kambarys  •  -%d min  •  $%d",
					InjuryConfig.RecoveryRoomReduceSeconds // 60, InjuryConfig.RecoveryRoomCost
				))
			end
		end
		return index
	end

	local function renderDetail()
		local student = findSelected()
		local hasStudent = student ~= nil
		detailScroll.Visible = hasStudent and (not narrow or showingDetailOnNarrow)
		detailEmpty.Visible = not hasStudent and not narrow
		if not student then
			return
		end

		local potentialColor = Kit.potentialColor(student.potencialas)
		detailInitials.Text = Kit.initials(student.name)
		detailAvatarRing.Color = potentialColor
		detailName.Text = student.name or "?"
		detailSub.Text = string.format("%s  •  %s", Kit.translate("personality", student.personality), student.style or "Balanced")

		for _, child in ipairs(badgeRow:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		Kit.potentialBadge({ parent = badgeRow, potential = student.potencialas, order = 1 })
		if student.karjerosStadija == "Trial" then
			Kit.badge({ parent = badgeRow, text = "Bandomasis", color = C.steelBright, order = 2 })
		else
			Kit.badge({ parent = badgeRow, text = "Narys", color = C.textSecondary, order = 2 })
		end
		-- Crimson = tik neigiama busena; paruostas kovoms = auksas
		if student.injured then
			Kit.badge({ parent = badgeRow, text = "Traumuotas", color = C.crimson, solid = true, textColor = C.textPrimary, order = 3 })
		elseif student.competitionReady then
			Kit.badge({ parent = badgeRow, text = "✓ Paruoštas", color = C.gold, order = 3 })
		end

		local record = student.record or {}
		recordValue.Text = string.format("%d-%d-%d", record.wins or 0, record.losses or 0, record.draws or 0)
		local tier = FightConfig.Ladder[student.careerTier or 1]
		tierValue.Text = Kit.translate("ladder", tier and tier.name or "-")

		-- Statistika
		local stats = student.stats or {}
		local caps = student.statPotential or {}
		ovrHint.Text = string.format("OVR %d", Kit.overall(student))
		for _, statId in ipairs(STAT_ORDER) do
			local row = statRows[statId]
			local value = stats[statId] or 0
			local atCap = caps[statId] ~= nil and value >= caps[statId]
			row.bar.Set(value / TrainingConfig.MaxStat)
			row.value.Text = tostring(value)
			row.maxBadge.Visible = atCap
			if atCap then
				row.bar.SetColor(C.goldBright, C.goldBright)
				row.value.TextColor3 = C.goldBright
			else
				row.bar.SetColor(C.gold, C.goldBright)
				row.value.TextColor3 = C.textPrimary
			end
		end

		-- Būklė
		local fatigue = student.fatigue or 0
		local morale = student.morale or DataSchema.Morale.Default
		fatigueRow.bar.Set(fatigue / TrainingConfig.MaxFatigue)
		fatigueRow.bar.SetColor(fatigueColor(fatigue))
		fatigueRow.value.Text = string.format("%d%%", fatigue)
		moraleRow.bar.Set(morale / DataSchema.Morale.Max)
		moraleRow.bar.SetColor(moraleColor(morale))
		moraleRow.value.Text = tostring(morale)

		local hints = {}
		if fatigue >= TrainingConfig.FatigueTrainingBlockThreshold then
			table.insert(hints, "Per daug pavargęs — reikia poilsio prieš treniruotę ar kovą.")
		elseif fatigue >= DataSchema.Morale.OvertrainingFatigueThreshold then
			table.insert(hints, "Pervargimo zona: treniruotės dabar kenkia nuotaikai.")
		end
		if morale < DataSchema.Morale.LowMoraleThreshold then
			table.insert(hints, "Žema nuotaika mažina treniruočių ir kovų efektyvumą.")
		end
		conditionHint.Text = table.concat(hints, " ")
		conditionCallout.Visible = #hints > 0

		-- Trauma
		injuryCard.Visible = student.injured == true
		if student.injured then
			local seconds = student.injuryRecoverySeconds or 0
			injuryTitle.Text = "🩹  " .. InjuryConfig.severityLabel(seconds)
			injuryText.Text = string.format(
				"Liko ~%d min iki pagijimo. Kol gyja, %s negali treniruotis ir kovoti.",
				math.ceil(seconds / 60), student.name
			)
		end

		-- Bandomasis laikotarpis
		local isTrial = student.karjerosStadija == "Trial"
		trialCard.Visible = isTrial
		if isTrial then
			local done = student.trialSessionsCompleted or 0
			local satisfaction = student.satisfactionScore or 0
			trialSessionsRow.bar.Set(done / TrainingConfig.Trial.maxSessions)
			trialSessionsRow.bar.SetColor(C.steel, C.steelBright)
			trialSessionsRow.value.Text = string.format("%d/%d", done, TrainingConfig.Trial.maxSessions)
			trialSatisfactionRow.bar.Set(satisfaction / 100)
			if satisfaction >= TrainingConfig.Trial.convertThreshold then
				trialSatisfactionRow.bar.SetColor(C.gold, C.goldBright)
			else
				trialSatisfactionRow.bar.SetColor(C.crimson, C.crimsonBright)
			end
			trialSatisfactionRow.value.Text = string.format("%d%%", satisfaction)
			trialHint.Text = satisfaction >= TrainingConfig.Trial.convertThreshold and "Liks akademijoje" or "Rizika išeiti"
			trialHint.TextColor3 = satisfaction >= TrainingConfig.Trial.convertThreshold and C.goldBright or C.crimsonBright
		end

		if pendingStyle == student.style then
			pendingStyle = nil
		end
		paintStyleChips(student)
		updateTimers()
	end

	local rosterRows = {}

	local function renderRoster()
		local students = State.get().students or {}
		tabs.SetLabel("roster", string.format("Kovotojai · %d", #students))

		-- Jei pasirinktas kovotojas dingo (pvz. bandomasis isejo) -- renkames pirma
		local selectedStillExists = false
		for _, student in ipairs(students) do
			if Kit.studentKey(student) == selectedKey then
				selectedStillExists = true
			end
		end
		if not selectedStillExists then
			selectedKey = students[1] and Kit.studentKey(students[1]) or nil
			pendingStyle = nil
		end

		for _, row in ipairs(rosterRows) do
			row:Destroy()
		end
		table.clear(rosterRows)

		if #students == 0 then
			local empty = Kit.emptyState({
				parent = rosterList,
				icon = "📱",
				title = "Dar nėra kovotojų",
				text = "Skelbk turinį telefone — nauji klientai ateis patys.",
				size = UDim2.new(1, 0, 0, 170),
			})
			table.insert(rosterRows, empty)
		end

		for index, student in ipairs(students) do
			local key = Kit.studentKey(student)
			local isSelected = key == selectedKey
			local row = Kit.create("TextButton", {
				Name = "Fighter_" .. index,
				AutoButtonColor = false,
				BackgroundColor3 = isSelected and C.bgCardLight or C.bgCard,
				Text = "",
				Size = UDim2.new(1, 0, 0, 64),
				LayoutOrder = index,
				Parent = rosterList,
			})
			Kit.corner(row, 12)
			local rowStroke = Kit.stroke(row, isSelected and C.gold or C.border, 1, isSelected and 0.15 or 0.5)
			if isSelected then
				local accent = Kit.create("Frame", {
					Name = "SelectedAccent",
					BackgroundColor3 = C.gold,
					Size = UDim2.new(0, 3, 0, 28),
					Position = UDim2.new(0, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Parent = row,
				})
				Kit.corner(accent, UDim.new(1, 0))
			end
			Kit.avatar({
				parent = row,
				text = student.name,
				size = 40,
				position = UDim2.new(0, 12, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				ringColor = Kit.potentialColor(student.potencialas),
			})
			Kit.label({
				parent = row,
				name = "Name",
				text = student.name or "?",
				bold = true,
				textSize = 14,
				size = UDim2.new(1, -140, 0, 18),
				position = UDim2.new(0, 62, 0, 13),
			})
			local stage = student.karjerosStadija == "Trial" and "Bandomasis" or "Narys"
			Kit.label({
				parent = row,
				name = "Sub",
				text = string.format("%s  •  OVR %d", stage, Kit.overall(student)),
				textSize = 12,
				color = student.karjerosStadija == "Trial" and C.steelBright or C.textSecondary,
				size = UDim2.new(1, -140, 0, 16),
				position = UDim2.new(0, 62, 0, 34),
			})
			-- Busenos zyme (vietoj emoji): trauma > pavarges > paruostas kovoms
			local statusBadge = nil
			if student.injured then
				statusBadge = { text = "Trauma", color = C.crimson, solid = true, textColor = C.textPrimary }
			elseif (student.fatigue or 0) >= TrainingConfig.FatigueTrainingBlockThreshold then
				statusBadge = { text = "Pavargęs", color = C.crimsonBright }
			elseif student.competitionReady then
				statusBadge = { text = "Kovoms", color = C.gold }
			end
			if statusBadge then
				Kit.badge({
					parent = row,
					name = "Status",
					text = statusBadge.text,
					color = statusBadge.color,
					solid = statusBadge.solid,
					textColor = statusBadge.textColor,
					height = 18,
					textSize = 11,
					anchor = Vector2.new(1, 0.5),
					position = UDim2.new(1, -12, 0.5, 0),
				})
			end

			row.MouseEnter:Connect(function()
				if Kit.isTouchOnly() then
					return
				end
				if key ~= selectedKey then
					Kit.tween(rowStroke, 0.12, { Color = C.gold, Transparency = 0.45 })
					Kit.tween(row, 0.12, { BackgroundColor3 = C.bgCardLight })
				end
			end)
			row.MouseLeave:Connect(function()
				if key ~= selectedKey then
					Kit.tween(rowStroke, 0.16, { Color = C.border, Transparency = 0.5 })
					Kit.tween(row, 0.16, { BackgroundColor3 = C.bgCard })
				end
			end)
			row.Activated:Connect(function()
				if selectedKey ~= key then
					pendingStyle = nil
				end
				selectedKey = key
				showingDetailOnNarrow = true
				renderRoster()
				applyNarrow()
			end)

			table.insert(rosterRows, row)
		end

		-- Maziau nei 4 kovotojai: kvietimas pritraukti daugiau per telefona
		if #students > 0 and #students < 4 then
			local cta = Kit.card({
				parent = rosterList,
				name = "MoreFightersCta",
				size = UDim2.new(1, 0, 0, 120),
				order = 1000,
				strokeColor = C.steelBright,
				strokeTransparency = 0.55,
			})
			Kit.padding(cta, 14, 14, 14, 14)
			Kit.label({ parent = cta, name = "Title", text = "📱  Reikia daugiau kovotojų", bold = true, textSize = 14, size = UDim2.new(1, 0, 0, 18) })
			Kit.label({
				parent = cta,
				name = "Text",
				text = "Skelbk įrašus SocialGym — nauji klientai ateis patys.",
				textSize = 12,
				color = C.textSecondary,
				wrap = true,
				alignY = Enum.TextYAlignment.Top,
				size = UDim2.new(1, 0, 0, 32),
				position = UDim2.new(0, 0, 0, 22),
			})
			Kit.button({
				parent = cta,
				name = "OpenPhone",
				text = "Atidaryti telefoną",
				variant = "steel",
				size = UDim2.new(1, 0, 0, 32),
				position = UDim2.new(0, 0, 1, 0),
				anchor = Vector2.new(0, 1),
				textSize = 13,
				onClick = function()
					Kit.close("Academy")
					Kit.open("Phone")
				end,
			})
			table.insert(rosterRows, cta)
		end

		renderDetail()
	end

	encourageButton.Instance.Activated:Connect(function()
		if not encourageButton.IsEnabled() then
			return
		end
		local _, index = findSelected()
		if index then
			State.fire("EncourageRequest", index)
		end
	end)
	recoveryButton.Instance.Activated:Connect(function()
		if not recoveryButton.IsEnabled() then
			return
		end
		local _, index = findSelected()
		if index then
			State.fire("RecoveryRequest", index)
		end
	end)
	styleChangeButton.Instance.Activated:Connect(function()
		if not styleChangeButton.IsEnabled() then
			return
		end
		local student, index = findSelected()
		if index and pendingStyle and student.style ~= pendingStyle then
			State.fire("StyleChangeRequest", index, pendingStyle)
		end
	end)

	-- Siauras ekranas: sarasas ir detales rodomi po viena
	applyNarrow = function()
		if narrow then
			listColumn.Size = UDim2.new(1, -40, 1, -16)
			listColumn.Visible = not showingDetailOnNarrow
			detailColumn.Position = UDim2.new(0, 20, 0, 0)
			detailColumn.Size = UDim2.new(1, -40, 1, -16)
			detailColumn.Visible = showingDetailOnNarrow
			backButton.Instance.Visible = showingDetailOnNarrow
			detailScroll.Position = UDim2.new(0, 0, 0, 42)
			detailScroll.Size = UDim2.new(1, 0, 1, -42)
		else
			listColumn.Size = UDim2.new(0, 268, 1, -16)
			listColumn.Visible = true
			detailColumn.Position = UDim2.new(0, 300, 0, 0)
			detailColumn.Size = UDim2.new(1, -316, 1, -16)
			detailColumn.Visible = true
			backButton.Instance.Visible = false
			detailScroll.Position = UDim2.new(0, 0, 0, 0)
			detailScroll.Size = UDim2.new(1, 0, 1, 0)
		end
		renderDetail()
	end

	-- ============================================================
	-- 2. ĮRANGA
	-- ============================================================
	local equipmentPage = makePage("equipment")
	local equipmentScroll = Kit.scroll({
		parent = equipmentPage,
		name = "EquipmentScroll",
		size = UDim2.new(1, -8, 1, -10),
		paddingLeft = 20,
		paddingRight = 8,
		paddingTop = 2,
		paddingBottom = 16,
		spacing = 12,
	})
	Kit.scrollFade(equipmentScroll)

	local equipmentSummary = Kit.card({
		parent = equipmentScroll,
		name = "Summary",
		size = UDim2.new(1, 0, 0, 86),
		order = 1,
		strokeColor = C.gold,
		strokeTransparency = 0.6,
	})
	Kit.label({
		parent = equipmentSummary,
		name = "Icon",
		text = "🏋️",
		textSize = 28,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(0, 52, 0, 52),
		position = UDim2.new(0, 16, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
	})
	Kit.label({
		parent = equipmentSummary,
		name = "Title",
		text = "Salės įranga",
		bold = true,
		textSize = 17,
		size = UDim2.new(1, -220, 0, 22),
		position = UDim2.new(0, 78, 0, 20),
	})
	local equipmentSubtitle = Kit.label({
		parent = equipmentSummary,
		name = "Sub",
		text = "Nauja įranga didina treniruočių naudą pasirinktam fokusui.",
		textSize = 13,
		color = C.textSecondary,
		wrap = true,
		alignY = Enum.TextYAlignment.Top,
		size = UDim2.new(1, -220, 0, 34),
		position = UDim2.new(0, 78, 0, 44),
	})
	Kit.label({
		parent = equipmentSummary,
		name = "OwnedCaption",
		text = "ĮRENGTA",
		bold = true,
		textSize = 11,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 120, 0, 14),
		position = UDim2.new(1, -18, 0, 20),
		anchor = Vector2.new(1, 0),
	})
	local ownedValue = Kit.label({
		parent = equipmentSummary,
		name = "OwnedValue",
		text = "1 / 4",
		bold = true,
		textSize = 28,
		color = C.goldBright,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 120, 0, 32),
		position = UDim2.new(1, -18, 0, 34),
		anchor = Vector2.new(1, 0),
	})

	local equipmentGrid = Kit.create("Frame", {
		Name = "EquipmentGrid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = equipmentScroll,
	})
	local equipmentGridLayout = Kit.grid(equipmentGrid, UDim2.new(0.5, -7, 0, 156), UDim2.new(0, 12, 0, 12))

	local equipmentCards = {}
	local function buildEquipmentCard(order, itemId, item, isStarter)
		local info = FOCUS_INFO[item.focus] or { icon = "🏋️", name = item.focus }
		local cardFrame, cardStroke = Kit.card({ parent = equipmentGrid, name = "Item_" .. itemId, order = order })
		local iconTile = Kit.create("Frame", {
			Name = "IconTile",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(0, 46, 0, 46),
			Position = UDim2.new(0, 14, 0, 14),
			Parent = cardFrame,
		})
		Kit.corner(iconTile, 12)
		Kit.stroke(iconTile, C.border, 1, 0.3)
		Kit.label({
			parent = iconTile,
			name = "Icon",
			text = info.icon,
			textSize = 22,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		Kit.label({
			parent = cardFrame,
			name = "Title",
			text = item.label,
			bold = true,
			textSize = 14,
			size = UDim2.new(1, -86, 0, 18),
			position = UDim2.new(0, 72, 0, 16),
		})
		local bonusText = isStarter and ("Bazinė  •  " .. info.name)
			or string.format("+%d%%  •  %s", math.floor((item.multiplier - 1) * 100 + 0.5), info.name)
		Kit.badge({
			parent = cardFrame,
			text = bonusText,
			color = isStarter and C.textSecondary or C.steelBright,
			position = UDim2.new(0, 72, 0, 38),
		})
		local description = item.description
		if not isStarter and item.multiplier and FOCUS_GENITIVE[item.focus] then
			description = string.format("+%d%% naudos iš %s treniruočių.", math.floor((item.multiplier - 1) * 100 + 0.5), FOCUS_GENITIVE[item.focus])
		end
		Kit.label({
			parent = cardFrame,
			name = "Description",
			text = description,
			textSize = 12,
			color = C.textSecondary,
			wrap = true,
			alignY = Enum.TextYAlignment.Top,
			size = UDim2.new(1, -28, 0, 32),
			position = UDim2.new(0, 14, 0, 70),
		})
		local buyButton = Kit.button({
			parent = cardFrame,
			name = "BuyButton",
			text = "Pirkti  •  " .. Kit.formatMoney(item.cost or 0),
			variant = "gold",
			size = UDim2.new(1, -28, 0, 36),
			position = UDim2.new(0, 14, 1, -50),
			textSize = 13,
			onClick = function()
				State.fire("EquipmentPurchaseRequest", itemId)
			end,
		})
		-- Irengta iranga: ramus uzrasas vietoj isjungto mygtuko
		local ownedLabel = Kit.label({
			parent = cardFrame,
			name = "OwnedLabel",
			text = "✓  Įrengta",
			bold = true,
			textSize = 13,
			color = C.gold,
			size = UDim2.new(1, -28, 0, 36),
			position = UDim2.new(0, 14, 1, -50),
		})
		ownedLabel.Visible = false
		equipmentCards[itemId] = { stroke = cardStroke, button = buyButton, owned = ownedLabel, item = item, isStarter = isStarter }
	end

	buildEquipmentCard(0, STARTER_EQUIPMENT.id, STARTER_EQUIPMENT, true)
	for index, itemId in ipairs(EquipmentConfig.Order) do
		local item = EquipmentConfig.Items[itemId]
		if item then
			buildEquipmentCard(index, itemId, item, false)
		end
	end

	local function renderEquipment()
		local s = State.get()
		local owned = {}
		for _, id in ipairs(s.equipment or {}) do
			owned[id] = true
		end
		owned[STARTER_EQUIPMENT.id] = true
		local ownedCount, totalCount = 0, 0
		for itemId, entry in pairs(equipmentCards) do
			totalCount += 1
			local isOwned = owned[itemId] == true
			entry.button.Instance.Visible = not isOwned
			entry.owned.Visible = isOwned
			if isOwned then
				ownedCount += 1
				entry.stroke.Color = C.border
				entry.stroke.Transparency = 0.45
			else
				local money = s.money or 0
				local cost = entry.item.cost or 0
				if money >= cost then
					entry.stroke.Color = C.gold
					entry.stroke.Transparency = 0.45
					entry.button.SetEnabled(true)
					entry.button.SetText("Pirkti  •  " .. Kit.formatMoney(cost))
				else
					entry.stroke.Color = C.border
					entry.stroke.Transparency = 0.45
					entry.button.SetEnabled(false)
					entry.button.SetText("Trūksta " .. Kit.formatMoney(cost - money))
				end
			end
		end
		ownedValue.Text = string.format("%d / %d", ownedCount, totalCount)
		equipmentSubtitle.Text = string.format(
			"Salės lygis %d. Nauja įranga didina treniruočių naudą pasirinktam fokusui.",
			s.academy.gymLevel or 1
		)
	end

	-- ============================================================
	-- 3. IŠVAIZDA (pritaikymas)
	-- ============================================================
	local stylePage = makePage("style")
	local floorOptions = AcademyConfig.FloorOptions

	local draft = { academyName = "", wallColorIndex = 1, logoIndex = 1, floorColorIndex = 1 }
	local saved = { academyName = "", wallColorIndex = 1, logoIndex = 1, floorColorIndex = 1 }
	local awaitingSave = false

	-- Peržiūra (kairėje)
	local previewColumn = Kit.create("Frame", {
		Name = "PreviewColumn",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 300, 1, -16),
		Position = UDim2.new(0, 20, 0, 0),
		Parent = stylePage,
	})
	local previewCard, previewStroke = Kit.card({
		parent = previewColumn,
		name = "Preview",
		size = UDim2.new(1, 0, 1, -26),
		color = C.bgCard,
		clip = true,
		strokeColor = C.gold,
		strokeTransparency = 0.5,
	})
	local previewWall = Kit.create("Frame", {
		Name = "Wall",
		BackgroundColor3 = AcademyConfig.WallColors[1],
		Size = UDim2.new(1, 0, 0.72, 0),
		Parent = previewCard,
	})
	Kit.corner(previewWall, 12)
	Kit.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
		}),
		Rotation = 90,
		Parent = previewWall,
	})
	local previewFloor = Kit.create("Frame", {
		Name = "Floor",
		BackgroundColor3 = floorOptions and floorOptions[1].color or Color3.fromRGB(150, 150, 150),
		Size = UDim2.new(1, 0, 0.28, 0),
		Position = UDim2.new(0, 0, 0.72, 0),
		Parent = previewCard,
	})
	Kit.corner(previewFloor, 12)
	Kit.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		Rotation = 90,
		Parent = previewFloor,
	})
	local floorEdge = Kit.create("Frame", {
		Name = "Baseboard",
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 0.72, -2),
		Parent = previewCard,
	})
	floorEdge.ZIndex = 2
	local signPlate = Kit.create("Frame", {
		Name = "Sign",
		BackgroundColor3 = C.bg,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.84, 0, 0, 108),
		Position = UDim2.new(0.5, 0, 0.36, 0),
		ZIndex = 3,
		Parent = previewCard,
	})
	Kit.corner(signPlate, 12)
	Kit.stroke(signPlate, C.gold, 2, 0.1)
	Kit.gradient(signPlate, C.bgCardLight, C.bg, 90)
	local signLogo = Kit.label({
		parent = signPlate,
		name = "Logo",
		text = AcademyConfig.Logos[1],
		textSize = 36,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.new(0, 0, 0, 12),
		zIndex = 4,
	})
	local signName = Kit.label({
		parent = signPlate,
		name = "Name",
		text = AcademyConfig.DefaultName,
		bold = true,
		textSize = 18,
		color = C.goldBright,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -20, 0, 24),
		position = UDim2.new(0, 10, 0, 60),
		zIndex = 4,
	})
	Kit.label({
		parent = signPlate,
		name = "Tagline",
		text = "BOKSO AKADEMIJA",
		bold = true,
		textSize = 10,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 12),
		position = UDim2.new(0, 0, 0, 86),
		zIndex = 4,
	})
	Kit.label({
		parent = previewColumn,
		name = "PreviewCaption",
		text = "Iškabos ir salės peržiūra",
		textSize = 12,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -16),
	})

	-- Forma (dešinėje)
	local FOOTER_HEIGHT = 76
	local formScroll = Kit.scroll({
		parent = stylePage,
		name = "Form",
		size = UDim2.new(1, -356, 1, -(16 + FOOTER_HEIGHT)),
		position = UDim2.new(0, 336, 0, 0),
		paddingRight = 10,
		paddingTop = 2,
		paddingLeft = 2,
		paddingBottom = 8,
		spacing = 10,
	})
	Kit.scrollFade(formScroll)

	local _, nameCounter = Kit.sectionHeader({ parent = formScroll, title = "Pavadinimas", hint = "0/24", order = 1 })
	local nameBox, nameHolder = Kit.textBox({
		parent = formScroll,
		placeholder = AcademyConfig.DefaultName,
		order = 2,
		size = UDim2.new(1, 0, 0, 42),
	})
	nameBox.Size = UDim2.new(1, -44, 1, 0)
	Kit.label({
		parent = nameHolder,
		name = "EditGlyph",
		text = "✎",
		textSize = 14,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(0, 24, 1, 0),
		position = UDim2.new(1, -8, 0, 0),
		anchor = Vector2.new(1, 0),
	})

	local function swatchRow(order, height)
		local row = Kit.create("Frame", {
			Name = "SwatchRow" .. order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = order,
			Parent = formScroll,
		})
		Kit.list(row, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		Kit.padding(row, 0, 0, 0, 3)
		return row
	end

	-- Pasirinkimo mygtukas (spalva / logotipas) su auksiniu ziedu, kai pasirinktas
	local function makeChoice(parent, order, size, fill, text, onPick)
		local choice = Kit.create("TextButton", {
			Name = "Choice" .. order,
			AutoButtonColor = false,
			BackgroundColor3 = fill or C.bgCardLight,
			Text = "",
			Size = UDim2.new(0, size, 0, size),
			LayoutOrder = order,
			Parent = parent,
		})
		Kit.corner(choice, text and 12 or UDim.new(1, 0))
		local ring = Kit.stroke(choice, C.border, 2, 0.2)
		local scale = Kit.create("UIScale", { Parent = choice })
		local glyph = Kit.label({
			parent = choice,
			name = "Glyph",
			text = text or "",
			bold = true,
			textSize = text and 22 or 14,
			color = C.textOnGold,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		-- Pasirinkimo zyme: auksinis apskritimas su varnele apatiniame desiniajame kampe
		local check = Kit.create("Frame", {
			Name = "Check",
			BackgroundColor3 = C.gold,
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.new(0, 18, 0, 18),
			Position = UDim2.new(1, 4, 1, 4),
			Visible = false,
			ZIndex = 3,
			Parent = choice,
		})
		Kit.corner(check, UDim.new(1, 0))
		Kit.stroke(check, C.bg, 2, 0)
		Kit.label({
			parent = check,
			name = "Glyph",
			text = "✓",
			bold = true,
			textSize = 11,
			color = C.textOnGold,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
			zIndex = 4,
		})
		choice.MouseEnter:Connect(function()
			if Kit.isTouchOnly() then
				return
			end
			Kit.tween(scale, 0.12, { Scale = 1.08 }, Enum.EasingStyle.Back)
		end)
		choice.MouseLeave:Connect(function()
			Kit.tween(scale, 0.12, { Scale = 1 })
		end)
		choice.Activated:Connect(onPick)
		return { button = choice, ring = ring, glyph = glyph, check = check, isText = text ~= nil }
	end

	local function paintChoices(choices, selectedIndex)
		for index, choice in ipairs(choices) do
			local selected = index == selectedIndex
			choice.ring.Color = selected and C.goldBright or C.border
			choice.ring.Transparency = selected and 0 or 0.2
			choice.ring.Thickness = selected and 3 or 2
			choice.check.Visible = selected
			if choice.isText then
				choice.button.BackgroundColor3 = selected and C.bgCard or C.bgCardLight
			end
		end
	end

	local renderStyleDraft -- forward

	local _, wallNameHint = Kit.sectionHeader({ parent = formScroll, title = "Sienų spalva", hint = "", order = 3 })
	local wallRow = swatchRow(4, 44)
	local wallChoices = {}
	for index, color in ipairs(AcademyConfig.WallColors) do
		wallChoices[index] = makeChoice(wallRow, index, 38, color, nil, function()
			draft.wallColorIndex = index
			renderStyleDraft()
		end)
	end

	local floorChoices = {}
	local floorNameHint = nil
	if floorOptions then
		local _, hint = Kit.sectionHeader({ parent = formScroll, title = "Grindys", hint = "", order = 5 })
		floorNameHint = hint
		local floorRow = swatchRow(6, 44)
		for index, option in ipairs(floorOptions) do
			floorChoices[index] = makeChoice(floorRow, index, 38, option.color, nil, function()
				draft.floorColorIndex = index
				renderStyleDraft()
			end)
		end
	end

	Kit.sectionHeader({ parent = formScroll, title = "Logotipas", order = 7 })
	local logoRow = swatchRow(8, 52)
	local logoChoices = {}
	for index, logo in ipairs(AcademyConfig.Logos) do
		logoChoices[index] = makeChoice(logoRow, index, 46, C.bgCardLight, logo, function()
			draft.logoIndex = index
			renderStyleDraft()
		end)
	end

	-- "Sticky" apatine juosta: busena + Atsaukti / Issaugoti visada matomi
	local formFooter = Kit.create("Frame", {
		Name = "FormFooter",
		BackgroundColor3 = C.bg,
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -356, 0, FOOTER_HEIGHT),
		Position = UDim2.new(0, 336, 1, -16),
		Parent = stylePage,
	})
	Kit.create("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.border,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 1),
		Parent = formFooter,
	})
	local actionRow = Kit.create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, 0),
		Parent = formFooter,
	})
	local resetButton = Kit.button({
		parent = actionRow,
		name = "ResetButton",
		text = "Atšaukti",
		variant = "ghost",
		size = UDim2.new(0.38, -5, 1, 0),
		textSize = 13,
	})
	local saveButton = Kit.button({
		parent = actionRow,
		name = "SaveButton",
		text = "Išsaugoti",
		icon = "💾",
		variant = "gold",
		size = UDim2.new(0.62, -5, 1, 0),
		position = UDim2.new(1, 0, 0, 0),
		anchor = Vector2.new(1, 0),
		textSize = 13,
		enabled = false,
	})
	local dirtyHint = Kit.label({
		parent = formFooter,
		name = "DirtyHint",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 0, 8),
	})

	local function isDirty()
		return draft.academyName ~= saved.academyName
			or draft.wallColorIndex ~= saved.wallColorIndex
			or draft.logoIndex ~= saved.logoIndex
			or (floorOptions ~= nil and draft.floorColorIndex ~= saved.floorColorIndex)
	end

	renderStyleDraft = function()
		local name = draft.academyName
		if name == "" then
			name = AcademyConfig.DefaultName
		end
		signName.Text = name
		signLogo.Text = AcademyConfig.Logos[draft.logoIndex] or AcademyConfig.Logos[1]
		Kit.tween(previewWall, 0.2, { BackgroundColor3 = AcademyConfig.WallColors[draft.wallColorIndex] or AcademyConfig.WallColors[1] })
		if floorOptions then
			local option = floorOptions[draft.floorColorIndex] or floorOptions[1]
			Kit.tween(previewFloor, 0.2, { BackgroundColor3 = option.color })
			if floorNameHint then
				floorNameHint.Text = option.name
			end
		end
		nameCounter.Text = string.format("%d/%d", utf8.len(draft.academyName) or #draft.academyName, AcademyConfig.MaxNameLength)
		wallNameHint.Text = WALL_COLOR_NAMES[draft.wallColorIndex] or ""
		paintChoices(wallChoices, draft.wallColorIndex)
		paintChoices(floorChoices, draft.floorColorIndex)
		paintChoices(logoChoices, draft.logoIndex)

		local dirty = isDirty()
		saveButton.SetEnabled(dirty and not awaitingSave)
		resetButton.SetEnabled(dirty)
		previewStroke.Transparency = dirty and 0.15 or 0.5
		if awaitingSave then
			dirtyHint.Text = "Saugoma..."
			dirtyHint.TextColor3 = C.textSecondary
		elseif dirty then
			dirtyHint.Text = "● Neišsaugoti pakeitimai"
			dirtyHint.TextColor3 = C.goldBright
		else
			dirtyHint.Text = "Visi pakeitimai išsaugoti"
			dirtyHint.TextColor3 = C.textSecondary
		end
	end

	local function loadSavedIntoDraft()
		local academy = State.get().academy
		saved.academyName = academy.academyName or AcademyConfig.DefaultName
		saved.wallColorIndex = academy.wallColorIndex or 1
		saved.logoIndex = academy.logoIndex or 1
		saved.floorColorIndex = academy.floorColorIndex or 1
		draft.academyName = saved.academyName
		draft.wallColorIndex = saved.wallColorIndex
		draft.logoIndex = saved.logoIndex
		draft.floorColorIndex = saved.floorColorIndex
		nameBox.Text = draft.academyName
		renderStyleDraft()
	end

	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		local text = nameBox.Text
		local length = utf8.len(text) or #text
		if length > AcademyConfig.MaxNameLength then
			local cut = utf8.offset(text, AcademyConfig.MaxNameLength + 1)
			nameBox.Text = cut and string.sub(text, 1, cut - 1) or text
			return
		end
		draft.academyName = text
		renderStyleDraft()
	end)

	resetButton.Instance.Activated:Connect(function()
		if resetButton.IsEnabled() then
			loadSavedIntoDraft()
		end
	end)
	saveButton.Instance.Activated:Connect(function()
		if not saveButton.IsEnabled() then
			return
		end
		awaitingSave = true
		renderStyleDraft()
		local payload = {
			academyName = draft.academyName,
			wallColorIndex = draft.wallColorIndex,
			logoIndex = draft.logoIndex,
		}
		if floorOptions then
			payload.floorColorIndex = draft.floorColorIndex
		end
		State.fire("AcademyCustomize", payload)
		task.delay(4, function()
			if awaitingSave then
				awaitingSave = false
				renderStyleDraft()
			end
		end)
	end)

	-- ============================================================
	-- DUOMENU SUSIEJIMAS
	-- ============================================================
	local function renderAll()
		renderRoster()
		renderEquipment()
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

	State.subscribe("students", queue(renderRoster))
	State.subscribe("money", queue(function()
		renderEquipment()
		renderDetail()
	end))
	State.subscribe("equipment", queue(renderEquipment))
	local lastAcademyMessage = nil
	State.onMessage("academy", function(message)
		lastAcademyMessage = message
	end)
	State.subscribe("academy", function()
		if awaitingSave then
			awaitingSave = false
			loadSavedIntoDraft()
			task.defer(function()
				-- serverio zinute (pvz. atmestas pavadinimas) turi pirmenybe pries "issaugota"
				local message = lastAcademyMessage
				lastAcademyMessage = nil
				if panel.IsOpen then
					if message then
						panel.Toast(message, "error")
					else
						panel.Toast("Akademijos išvaizda išsaugota!", "success")
					end
				end
			end)
		elseif not isDirty() then
			loadSavedIntoDraft()
		end
	end)

	local function toastIfOpen(message)
		if panel.IsOpen then
			panel.Toast(message)
		end
	end
	State.onMessage("students", toastIfOpen)
	State.onMessage("equipment", toastIfOpen)

	panel.Every(1, updateTimers)
	-- Serveris kas 60 s pasyviai keicia nuovargi/nuotaika/traumas be pranesimo -- periodiskai atnaujinam
	panel.Every(30, function()
		State.refresh()
	end)

	panel.OnOpen(function()
		loadSavedIntoDraft()
		renderAll()
		State.refresh()
	end)

	panel.OnLayout(function(layout)
		local wasNarrow = narrow
		narrow = layout.compact or layout.size.X < 640
		if narrow ~= wasNarrow then
			showingDetailOnNarrow = false
		end
		applyNarrow()
		-- Iranga: 1 stulpelis siaurame lange
		equipmentGridLayout.CellSize = (layout.size.X < 640) and UDim2.new(1, 0, 0, 156) or UDim2.new(0.5, -7, 0, 156)
		-- Isvaizda: perziura virsuje siaurame lange
		if narrow then
			previewColumn.Visible = false
			formScroll.Position = UDim2.new(0, 20, 0, 0)
			formScroll.Size = UDim2.new(1, -40, 1, -(16 + FOOTER_HEIGHT))
			formFooter.Position = UDim2.new(0, 20, 1, -16)
			formFooter.Size = UDim2.new(1, -40, 0, FOOTER_HEIGHT)
		else
			previewColumn.Visible = true
			formScroll.Position = UDim2.new(0, 336, 0, 0)
			formScroll.Size = UDim2.new(1, -356, 1, -(16 + FOOTER_HEIGHT))
			formFooter.Position = UDim2.new(0, 336, 1, -16)
			formFooter.Size = UDim2.new(1, -356, 0, FOOTER_HEIGHT)
		end
	end)

	tabs.Select("roster", true)
	return panel
end

return AcademyPanel
