--[[
	TournamentPanel
	Turnyrai ir karjeros laiptai:
	  - Turnyrai: sarasas (TournamentConfig), kovotojo pasirinkimas, "fight camp" pasiruosimo
	    patikra su laimejimo tikimybes ivertinimu, registracija ir paskutinio turnyro rezultatas
	  - Karjera: kiekvieno kovotojo kelias Vietines kovos -> Regionas -> WBF ir "Kovoti" (FightRequest)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TournamentConfig = require(Modules:WaitForChild("TournamentConfig"))
local FightConfig = require(Modules:WaitForChild("FightConfig"))
local TrainingConfig = require(Modules:WaitForChild("TrainingConfig"))
local DataSchema = require(Modules:WaitForChild("DataSchema"))

local TournamentPanel = {}

-- ============================================================
-- KOVOS IVERTINIMAS (ta pati formule kaip FightHandler.weightedScore)
-- ============================================================
local function weightedBase(stats)
	local total = 0
	for statId, weight in pairs(FightConfig.StatWeights) do
		total += (stats and stats[statId] or 0) * weight
	end
	return total
end

-- Tikimybe, kad kovotojas laimes raunda: abu rezultatai dauginami is atsitiktinio U(RandomMin, RandomMax)
local function roundWinChance(fighterScore, opponentScore)
	if opponentScore <= 0 then
		return 1
	end
	local ratio = fighterScore / opponentScore
	local lo, hi = FightConfig.RandomMin, FightConfig.RandomMax
	local width = hi - lo
	local steps = 60
	local sum = 0
	for i = 1, steps do
		local u1 = lo + (i - 0.5) / steps * width
		sum += math.clamp((ratio * u1 - lo) / width, 0, 1)
	end
	return sum / steps
end

local function opponentAverage(tier)
	local mean = (tier.opponentStatMin + tier.opponentStatMax) / 2
	local weights = 0
	for _, weight in pairs(FightConfig.StatWeights) do
		weights += weight
	end
	return mean * weights
end

local function tournamentTier(tournament)
	local index = math.clamp(tournament.opponentTier or 1, 1, #FightConfig.Ladder)
	return FightConfig.Ladder[index], index
end

function TournamentPanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Tournament",
		title = "Tournaments",
		subtitle = "Career ladder, competitions and fight prep",
		icon = "🏆",
		accent = "crimson",
		maxSize = Vector2.new(800, 580),
	})

	local pages = {}
	local tabs = Kit.tabs({
		parent = panel.Body,
		items = {
			{ key = "tournaments", label = "Tournaments", icon = "🏆" },
			{ key = "career", label = "Career Ladder", icon = "🪜" },
		},
		size = UDim2.new(1, -40, 0, 42),
		position = UDim2.new(0, 20, 0, 14),
		onSelect = function(key)
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
		Parent = panel.Body,
	})

	local selectedTournament = nil
	local selectedFighterKey = nil
	local narrow = false
	local showingDetailOnNarrow = false
	local paintList, renderTournaments, applyNarrow -- forward (apibreztos zemiau)
	local FOOTER_HEIGHT = 60

	-- ============================================================
	-- 1. TURNYRAI
	-- ============================================================
	local tournamentsPage = Kit.create("Frame", {
		Name = "Page_tournaments",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = pageHolder,
	})
	pages.tournaments = tournamentsPage

	local listColumn = Kit.scroll({
		parent = tournamentsPage,
		name = "TournamentList",
		size = UDim2.new(0, 256, 1, -16),
		position = UDim2.new(0, 20, 0, 0),
		paddingRight = 8,
		paddingTop = 2,
		paddingLeft = 2,
		paddingBottom = 8,
		spacing = 8,
	})
	Kit.scrollFade(listColumn)
	local detail = Kit.scroll({
		parent = tournamentsPage,
		name = "Detail",
		size = UDim2.new(1, -312, 1, -(16 + FOOTER_HEIGHT)),
		position = UDim2.new(0, 296, 0, 0),
		paddingRight = 10,
		paddingTop = 2,
		paddingLeft = 2,
		paddingBottom = 12,
		spacing = 12,
	})
	Kit.scrollFade(detail)

	-- "Sticky" apatine juosta su pagrindiniu veiksmu (Registruotis) -- visada matoma
	local detailFooter = Kit.create("Frame", {
		Name = "DetailFooter",
		BackgroundColor3 = C.bg,
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -312, 0, FOOTER_HEIGHT),
		Position = UDim2.new(0, 296, 1, -16),
		Parent = tournamentsPage,
	})
	Kit.create("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.border,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 1),
		Parent = detailFooter,
	})

	-- Siaurame ekrane: sarasas -> detales (su grizimo mygtuku)
	local backButton = Kit.button({
		parent = tournamentsPage,
		name = "BackButton",
		text = "All tournaments",
		icon = "←",
		variant = "ghost",
		size = UDim2.new(0, 170, 0, 32),
		position = UDim2.new(0, 20, 0, 0),
		textSize = 13,
		onClick = function()
			showingDetailOnNarrow = false
			applyNarrow()
		end,
	})
	backButton.Instance.Visible = false

	-- Turnyru sarasas
	local tournamentRows = {}
	for index, tournament in ipairs(TournamentConfig.Tournaments) do
		local row = Kit.create("TextButton", {
			Name = "Tournament_" .. index,
			AutoButtonColor = false,
			BackgroundColor3 = C.bgCard,
			Text = "",
			Size = UDim2.new(1, 0, 0, 70),
			LayoutOrder = index,
			Parent = listColumn,
		})
		Kit.corner(row, 12)
		local rowStroke = Kit.stroke(row, C.border, 1, 0.5)
		local accent = Kit.create("Frame", {
			Name = "SelectedAccent",
			BackgroundColor3 = C.gold,
			Size = UDim2.new(0, 3, 0, 30),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Visible = false,
			Parent = row,
		})
		Kit.corner(accent, UDim.new(1, 0))
		local cup = Kit.label({
			parent = row,
			name = "Cup",
			text = "🏆",
			textSize = 22,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(0, 40, 0, 40),
			position = UDim2.new(0, 10, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
		})
		local name = Kit.label({
			parent = row,
			name = "Name",
			text = Kit.displayName(tournament.name),
			bold = true,
			textSize = 13,
			size = UDim2.new(1, -70, 0, 18),
			position = UDim2.new(0, 56, 0, 14),
		})
		local sub = Kit.label({
			parent = row,
			name = "Sub",
			text = "",
			rich = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, -70, 0, 14),
			position = UDim2.new(0, 56, 0, 38),
		})
		tournamentRows[index] = { row = row, stroke = rowStroke, accent = accent, cup = cup, name = name, sub = sub, hover = false }
		row.MouseEnter:Connect(function()
			if Kit.isTouchOnly() then
				return
			end
			tournamentRows[index].hover = true
			paintList()
		end)
		row.MouseLeave:Connect(function()
			tournamentRows[index].hover = false
			paintList()
		end)
		row.Activated:Connect(function()
			selectedTournament = index
			showingDetailOnNarrow = true
			renderTournaments()
			applyNarrow()
		end)
	end

	-- --- Detalės: antraštė ---
	local headerCard, headerStroke = Kit.card({
		parent = detail,
		name = "HeaderCard",
		size = UDim2.new(1, 0, 0, 104),
		autoSize = Enum.AutomaticSize.Y,
		order = 1,
	})
	Kit.padding(headerCard, 0, 0, 16, 0)
	local headerIcon = Kit.create("Frame", {
		Name = "IconTile",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, 60, 0, 60),
		Position = UDim2.new(0, 16, 0, 16),
		Parent = headerCard,
	})
	Kit.corner(headerIcon, 14)
	local headerIconStroke = Kit.stroke(headerIcon, C.crimsonBright, 1, 0.3)
	local headerIconGradient = Kit.gradient(headerIcon, C.crimsonBright, C.crimson, 135)
	Kit.label({
		parent = headerIcon,
		name = "Icon",
		text = "🏆",
		textSize = 28,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})
	local headerName = Kit.label({
		parent = headerCard,
		name = "Name",
		text = "",
		bold = true,
		textSize = 19,
		size = UDim2.new(1, -110, 0, 24),
		position = UDim2.new(0, 90, 0, 16),
	})
	local headerSub = Kit.label({
		parent = headerCard,
		name = "Sub",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		rich = true,
		wrap = true, -- ilgesnis (uzrakinto turnyro) tekstas lusta i 2 eilutes, o ne nukerpamas
		alignY = Enum.TextYAlignment.Top,
		size = UDim2.new(1, -106, 0, 32),
		position = UDim2.new(0, 90, 0, 45),
	})
	local rewardRow = Kit.create("Frame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 16, 0, 88),
		Parent = headerCard,
	})
	Kit.list(rewardRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	-- --- Detalės: kovotojo pasirinkimas ---
	local pickerCard = Kit.card({
		parent = detail,
		name = "FighterPicker",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 3,
	})
	Kit.padding(pickerCard, 14, 16, 16, 16)
	Kit.list(pickerCard, 10)
	Kit.sectionHeader({ parent = pickerCard, title = "Fighter", hint = "Fight-ready only", accent = C.crimsonBright, order = 0 })
	local chipGrid = Kit.create("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = pickerCard,
	})
	local chipLayout = Kit.grid(chipGrid, UDim2.new(0.5, -5, 0, 48), UDim2.new(0, 8, 0, 8))
	chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	-- --- Detalės: fight camp ---
	local campCard = Kit.card({
		parent = detail,
		name = "FightCamp",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 4,
	})
	Kit.padding(campCard, 14, 16, 16, 16)
	Kit.list(campCard, 8)
	Kit.sectionHeader({ parent = campCard, title = "Fight Camp", accent = C.crimsonBright, order = 0 })
	-- Kai nera ne vieno paruosto kovotojo: kvietimas treniruoti vietoj patikros saraso
	local noFighterCallout = Kit.create("Frame", {
		Name = "NoFighterCallout",
		BackgroundColor3 = C.steel,
		BackgroundTransparency = 0.85,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 10,
		Visible = false,
		Parent = campCard,
	})
	Kit.corner(noFighterCallout, 10)
	Kit.stroke(noFighterCallout, C.steelBright, 1, 0.4)
	Kit.padding(noFighterCallout, 12, 12, 12, 12)
	Kit.list(noFighterCallout, 10)
	Kit.label({
		parent = noFighterCallout,
		name = "Text",
		text = string.format(
			"No fight-ready fighters — average stats must be ≥ %d. Train your members at the academy.",
			TrainingConfig.Trial.competitionReadyStatThreshold
		),
		textSize = 12,
		wrap = true,
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 1,
	})
	Kit.button({
		parent = noFighterCallout,
		name = "GoTrain",
		text = "Train at the academy",
		icon = "🏋️",
		variant = "steel",
		size = UDim2.new(1, 0, 0, 34),
		order = 2,
		textSize = 13,
		onClick = function()
			Kit.close("Tournament")
			Kit.open("Academy")
		end,
	})
	local checkRows = {}
	for index, key in ipairs({ "ready", "health", "fatigue", "odds" }) do
		local row = Kit.create("Frame", {
			Name = "Check_" .. key,
			BackgroundColor3 = C.bg,
			BackgroundTransparency = 0.3,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = index,
			Parent = campCard,
		})
		Kit.corner(row, 9)
		local icon = Kit.label({
			parent = row,
			name = "Icon",
			text = "•",
			bold = true,
			textSize = 14,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(0, 28, 1, 0),
			position = UDim2.new(0, 6, 0, 0),
		})
		local text = Kit.label({
			parent = row,
			name = "Text",
			text = "",
			textSize = 12,
			rich = true,
			size = UDim2.new(1, -150, 1, 0),
			position = UDim2.new(0, 38, 0, 0),
		})
		local value = Kit.label({
			parent = row,
			name = "Value",
			text = "",
			bold = true,
			textSize = 12,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 120, 1, 0),
			position = UDim2.new(1, -12, 0, 0),
			anchor = Vector2.new(1, 0),
		})
		checkRows[key] = { row = row, icon = icon, text = text, value = value }
	end
	local oddsBar = Kit.progressBar({
		parent = campCard,
		name = "OddsBar",
		size = UDim2.new(1, 0, 0, 8),
		order = 5,
	})

	local enterButton = Kit.button({
		parent = detailFooter,
		name = "EnterButton",
		text = "Enter",
		icon = "🥊",
		variant = "crimson",
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.new(0, 0, 1, 0),
		anchor = Vector2.new(0, 1),
		textSize = 15,
	})

	-- --- Detalės: paskutinis rezultatas ---
	local resultCard, resultStroke = Kit.card({
		parent = detail,
		name = "LastResult",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 2,
	})
	Kit.padding(resultCard, 14, 16, 16, 16)
	Kit.list(resultCard, 8)
	local resultTitle = Kit.label({
		parent = resultCard,
		name = "Title",
		text = "",
		bold = true,
		textSize = 16,
		order = 1,
	})
	local resultRounds = Kit.create("Frame", {
		Name = "Rounds",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = resultCard,
	})
	Kit.list(resultRounds, 6)
	local resultRewards = Kit.label({
		parent = resultCard,
		name = "Rewards",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		rich = true,
		order = 3,
	})

	-- ------------------------------------------------------------
	local function members()
		local list = {}
		for index, student in ipairs(State.get().students or {}) do
			if student.karjerosStadija ~= "Trial" then
				table.insert(list, { student = student, index = index })
			end
		end
		return list
	end

	local function findFighter()
		for index, student in ipairs(State.get().students or {}) do
			if Kit.studentKey(student) == selectedFighterKey then
				return student, index
			end
		end
		return nil, nil
	end

	local function isEligible(student)
		return student.competitionReady and not student.injured and (student.fatigue or 0) < TrainingConfig.FatigueTrainingBlockThreshold
	end

	paintList = function()
		local stars = State.get().reputation.stars or 1
		for index, entry in ipairs(tournamentRows) do
			local tournament = TournamentConfig.Tournaments[index]
			local locked = stars < (tournament.minStars or 1)
			local selected = index == selectedTournament
			entry.accent.Visible = selected
			entry.row.BackgroundColor3 = (selected or entry.hover) and C.bgCardLight or C.bgCard
			entry.stroke.Color = (selected or entry.hover) and C.gold or C.border
			entry.stroke.Transparency = selected and 0.25 or (entry.hover and 0.45 or 0.5)
			entry.cup.TextTransparency = locked and 0.6 or 0
			entry.name.TextColor3 = locked and C.textSecondary or C.textPrimary
			entry.sub.Text = string.format("%s%s  •  %s", locked and "🔒 " or "", Kit.starsRich(tournament.minStars), Kit.formatMoney(tournament.entryFee))
		end
	end

	local function renderChips()
		for _, child in ipairs(chipGrid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = members()
		if #list == 0 then
			Kit.label({
				parent = chipGrid,
				name = "Empty",
				text = "No members yet — trial clients have to become members first.",
				textSize = 12,
				color = C.textSecondary,
				wrap = true,
			})
			return
		end
		for order, item in ipairs(list) do
			local student = item.student
			local key = Kit.studentKey(student)
			local eligible = isEligible(student)
			local selected = key == selectedFighterKey
			local chip = Kit.create("TextButton", {
				Name = "Fighter_" .. order,
				AutoButtonColor = false,
				BackgroundColor3 = selected and C.bgCardLight or C.bg,
				BackgroundTransparency = eligible and 0 or 0.4,
				Text = "",
				LayoutOrder = order,
				Parent = chipGrid,
			})
			Kit.corner(chip, 10)
			Kit.stroke(chip, selected and C.gold or C.border, selected and 1.5 or 1, selected and 0 or 0.4)
			Kit.avatar({
				parent = chip,
				text = student.name,
				size = 32,
				position = UDim2.new(0, 8, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				ringColor = Kit.potentialColor(student.potencialas),
				ringThickness = 1.5,
			})
			Kit.label({
				parent = chip,
				name = "Name",
				text = student.name,
				bold = true,
				textSize = 12,
				color = eligible and C.textPrimary or C.textSecondary,
				size = UDim2.new(1, -56, 0, 16),
				position = UDim2.new(0, 48, 0, 8),
			})
			local status
			if student.injured then
				status = "🩹 Injured"
			elseif not student.competitionReady then
				status = "Not ready yet"
			elseif (student.fatigue or 0) >= TrainingConfig.FatigueTrainingBlockThreshold then
				status = "Too tired"
			else
				status = string.format("OVR %d  •  %d-%d", Kit.overall(student), student.record and student.record.wins or 0, student.record and student.record.losses or 0)
			end
			Kit.label({
				parent = chip,
				name = "Status",
				text = status,
				textSize = 12,
				color = student.injured and C.crimsonBright or C.textSecondary,
				size = UDim2.new(1, -56, 0, 14),
				position = UDim2.new(0, 48, 0, 26),
			})
			chip.Activated:Connect(function()
				selectedFighterKey = key
				renderTournaments()
			end)
		end
	end

	local function setCheck(key, ok, text, value, warn)
		local row = checkRows[key]
		row.icon.Text = ok and "✓" or (warn and "!" or "✕")
		row.icon.TextColor3 = ok and C.goldBright or (warn and C.goldBright or C.crimsonBright)
		row.text.Text = text
		row.value.Text = value or ""
		row.value.TextColor3 = ok and C.textPrimary or (warn and C.goldBright or C.crimsonBright)
	end

	local function updateEnterButton()
		local s = State.get()
		local tournament = selectedTournament and TournamentConfig.Tournaments[selectedTournament]
		if not tournament then
			enterButton.SetEnabled(false)
			return
		end
		local student = findFighter()
		local stars = s.reputation.stars or 1
		local money = s.money or 0
		local cooldownLeft = (s.tournament.lastTournamentAt or 0) + (TournamentConfig.EntryCooldown or 0) - State.now()
		local anyEligible = false
		for _, item in ipairs(members()) do
			if isEligible(item.student) then
				anyEligible = true
			end
		end
		local reason = nil
		if stars < tournament.minStars then
			reason = "Needs " .. Kit.stars(tournament.minStars) .. " reputation"
		elseif not anyEligible then
			reason = "No fight-ready fighters"
		elseif not student then
			reason = "Pick a fighter"
		elseif not isEligible(student) then
			reason = "Fighter can't enter"
		elseif money < tournament.entryFee then
			reason = "Need " .. Kit.formatMoney(tournament.entryFee - money)
		elseif cooldownLeft > 0 then
			reason = "Wait " .. Kit.formatDuration(cooldownLeft)
		end
		enterButton.SetEnabled(reason == nil)
		enterButton.SetText(reason or ("Enter  •  " .. Kit.formatMoney(tournament.entryFee)))
	end

	local function renderCamp()
		local tournament = selectedTournament and TournamentConfig.Tournaments[selectedTournament]
		local student = findFighter()
		campCard.Visible = tournament ~= nil
		if not tournament then
			return
		end
		if not student then
			local anyEligible = false
			for _, item in ipairs(members()) do
				if isEligible(item.student) then
					anyEligible = true
				end
			end
			noFighterCallout.Visible = not anyEligible
			checkRows.ready.row.Visible = anyEligible
			if anyEligible then
				setCheck("ready", false, "Pick a fighter above", "", true)
			end
			checkRows.health.row.Visible = false
			checkRows.fatigue.row.Visible = false
			checkRows.odds.row.Visible = false
			oddsBar.Instance.Visible = false
			return
		end
		noFighterCallout.Visible = false
		checkRows.ready.row.Visible = true
		checkRows.health.row.Visible = true
		checkRows.fatigue.row.Visible = true
		checkRows.odds.row.Visible = true
		oddsBar.Instance.Visible = true

		local avg = 0
		for _, statId in ipairs(DataSchema.StatIds) do
			avg += (student.stats and student.stats[statId] or 0)
		end
		avg /= #DataSchema.StatIds
		setCheck("ready", student.competitionReady == true,
			"Fight-ready",
			student.competitionReady and "Yes" or string.format("OVR %d / %d", math.floor(avg + 0.5), TrainingConfig.Trial.competitionReadyStatThreshold))
		setCheck("health", not student.injured,
			"Health",
			student.injured and string.format("Injured ~%d min", math.ceil((student.injuryRecoverySeconds or 0) / 60)) or "Healthy")
		local fatigue = student.fatigue or 0
		local fatiguePenalty = math.clamp(fatigue / 100, 0, 0.5)
		-- nuovargis silpnina >= 20% -> "!" (ispejimas), kitaip gerai
		local fatigueOk = fatiguePenalty < 0.2
		setCheck("fatigue", fatigueOk,
			string.format("Fatigue <font color=\"#A8A096\">(weakens %d%%)</font>", math.floor(fatiguePenalty * 100 + 0.5)),
			string.format("%d%%", fatigue), false)
		if not fatigueOk then
			checkRows.fatigue.icon.Text = "!"
		end

		local tier = tournamentTier(tournament)
		local fighterScore = weightedBase(student.stats) * (1 - fatiguePenalty)
		local chance = roundWinChance(fighterScore, opponentAverage(tier))
		local championChance = chance ^ tournament.rounds
		local label, tone
		if chance >= 0.65 then
			label, tone = "Favorite", C.goldBright
		elseif chance >= 0.4 then
			label, tone = "Even", C.steelBright
		else
			label, tone = "Underdog", C.crimsonBright
		end
		setCheck("odds", chance >= 0.4,
			string.format("Round ~<b>%d%%</b>  •  title ~<b>%d%%</b>", math.floor(chance * 100 + 0.5), math.floor(championChance * 100 + 0.5)),
			label, chance >= 0.25)
		checkRows.odds.value.TextColor3 = tone
		oddsBar.Set(chance)
		if chance >= 0.65 then
			oddsBar.SetColor(C.gold, C.goldBright)
		elseif chance >= 0.4 then
			oddsBar.SetColor(C.steel, C.steelBright)
		else
			oddsBar.SetColor(C.crimson, C.crimsonBright)
		end
	end

	local shownResult = nil
	local function renderResult()
		local result = State.get().tournament.lastResult
		resultCard.Visible = result ~= nil
		if not result then
			return
		end
		if result ~= shownResult then
			-- naujas rezultatas: parodom ji (kortele yra iskart po antraste)
			shownResult = result
			detail.CanvasPosition = Vector2.new(0, 0)
		end
		for _, child in ipairs(resultRounds:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if result.champion then
			resultTitle.Text = "🏆  " .. Kit.displayName(result.tournamentName or "Tournament") .. " — CHAMPION!"
			resultTitle.TextColor3 = C.goldBright
			resultStroke.Color = C.gold
			resultStroke.Transparency = 0.2
		else
			resultTitle.Text = string.format("%s — %d/%d rounds", Kit.displayName(result.tournamentName or "Tournament"), result.roundsWon or 0, result.totalRounds or 0)
			resultTitle.TextColor3 = C.textPrimary
			resultStroke.Color = C.border
			resultStroke.Transparency = 0.45
		end
		for index, round in ipairs(result.rounds or {}) do
			local row = Kit.create("Frame", {
				Name = "Round" .. index,
				BackgroundColor3 = C.bg,
				BackgroundTransparency = 0.3,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = index,
				Parent = resultRounds,
			})
			Kit.corner(row, 8)
			Kit.label({
				parent = row,
				name = "Text",
				text = string.format("Round %d  •  vs %s", round.round or index, Kit.displayName(round.opponentName or "?")),
				textSize = 12,
				size = UDim2.new(1, -110, 1, 0),
				position = UDim2.new(0, 12, 0, 0),
			})
			Kit.label({
				parent = row,
				name = "Outcome",
				text = round.won and "✓ Win" or "✕ Loss",
				bold = true,
				textSize = 12,
				color = round.won and C.goldBright or C.crimsonBright,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 100, 1, 0),
				position = UDim2.new(1, -12, 0, 0),
				anchor = Vector2.new(1, 0),
			})
		end
		resultRewards.Text = string.format(
			"Prizes: <font color=\"#ECC85C\"><b>+%s</b></font>  •  +%d reputation",
			Kit.formatMoney(result.rewardMoney or 0), result.rewardReputation or 0
		)
	end

	renderTournaments = function()
		local s = State.get()
		local stars = s.reputation.stars or 1
		if not selectedTournament then
			-- numatytasis: aukščiausias atrakintas turnyras
			selectedTournament = 1
			for index, tournament in ipairs(TournamentConfig.Tournaments) do
				if stars >= tournament.minStars then
					selectedTournament = index
				end
			end
		end
		local student = findFighter()
		if not student then
			selectedFighterKey = nil
			for _, item in ipairs(members()) do
				if isEligible(item.student) then
					selectedFighterKey = Kit.studentKey(item.student)
					break
				end
			end
		end

		paintList()
		local tournament = TournamentConfig.Tournaments[selectedTournament]
		local tier = tournamentTier(tournament)
		local locked = stars < tournament.minStars
		headerName.Text = Kit.displayName(tournament.name)
		headerSub.Text = string.format(
			"%s%s  •  %d rounds  •  Opponents: %s (%d–%d)",
			locked and "<font color=\"#D63E4C\"><b>🔒 Needs</b></font> " or "",
			Kit.starsRich(tournament.minStars), tournament.rounds,
			Kit.translate("ladder", tier.name), tier.opponentStatMin, tier.opponentStatMax
		)
		headerIconGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, locked and C.bgCardLight or C.crimsonBright),
			ColorSequenceKeypoint.new(1, locked and C.bgCard or C.crimson),
		})
		headerIconStroke.Color = locked and C.border or C.crimsonBright
		headerStroke.Color = C.border
		headerStroke.Transparency = 0.45
		for _, child in ipairs(rewardRow:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		Kit.badge({ parent = rewardRow, text = "Champion +" .. Kit.formatMoney(tournament.championBonusMoney), color = C.gold, solid = true, order = 1 })
		Kit.badge({ parent = rewardRow, text = "Per round +" .. Kit.formatMoney(tournament.rewardPerRoundWin), color = C.gold, order = 2 })
		Kit.badge({ parent = rewardRow, text = string.format("+%d rep", tournament.championBonusReputation), color = C.steelBright, order = 3 })

		renderChips()
		renderCamp()
		updateEnterButton()
		renderResult()
	end

	enterButton.Instance.Activated:Connect(function()
		if not enterButton.IsEnabled() then
			return
		end
		local _, studentIndex = findFighter()
		if studentIndex and selectedTournament then
			State.fire("TournamentEnterRequest", studentIndex, selectedTournament)
			enterButton.SetEnabled(false)
			enterButton.SetText("Tournament in progress...")
		end
	end)

	-- ============================================================
	-- 2. KARJEROS LAIPTAI
	-- ============================================================
	local careerPage = Kit.scroll({
		parent = pageHolder,
		name = "Page_career",
		size = UDim2.new(1, -8, 1, -10),
		paddingTop = 2,
		paddingBottom = 20,
		paddingLeft = 20,
		paddingRight = 8,
		spacing = 12,
		visible = false,
	})
	Kit.scrollFade(careerPage)
	pages.career = careerPage
	local careerRows = {}

	local function renderCareer()
		for _, row in ipairs(careerRows) do
			row:Destroy()
		end
		table.clear(careerRows)

		local list = members()
		table.sort(list, function(a, b)
			local ta, tb = a.student.careerTier or 1, b.student.careerTier or 1
			if ta ~= tb then
				return ta > tb
			end
			return Kit.overall(a.student) > Kit.overall(b.student)
		end)

		local intro = Kit.label({
			parent = careerPage,
			name = "Intro",
			text = string.format(
				"Path: %s ➜ %s ➜ %s ➜ Rankings ➜ World Title. Win fights to climb.",
				Kit.translate("ladder", FightConfig.Ladder[1].name), Kit.translate("ladder", FightConfig.Ladder[2].name), Kit.translate("ladder", FightConfig.Ladder[3].name)
			),
			textSize = 12,
			color = C.textSecondary,
			wrap = true,
			size = UDim2.new(1, 0, 0, 0),
			autoSize = Enum.AutomaticSize.Y,
			order = 0,
		})
		table.insert(careerRows, intro)

		if #list == 0 then
			table.insert(careerRows, Kit.emptyState({
				parent = careerPage,
				icon = "🪜",
				title = "No fighters yet",
				text = "Once clients become members and get fight-ready, their careers show up here.",
				size = UDim2.new(1, 0, 0, 160),
				order = 1,
			}))
			return
		end

		for order, item in ipairs(list) do
			local student, studentIndex = item.student, item.index
			local tierIndex = math.clamp(student.careerTier or 1, 1, #FightConfig.Ladder)
			local tier = FightConfig.Ladder[tierIndex]
			local nextTier = FightConfig.Ladder[tierIndex + 1]
			local record = student.record or {}
			local cardFrame = Kit.card({
				parent = careerPage,
				name = "Career" .. order,
				size = UDim2.new(1, 0, 0, 118),
				order = order,
			})
			Kit.avatar({
				parent = cardFrame,
				text = student.name,
				size = 48,
				position = UDim2.new(0, 16, 0, 16),
				ringColor = Kit.potentialColor(student.potencialas),
			})
			Kit.label({
				parent = cardFrame,
				name = "Name",
				text = student.name,
				bold = true,
				textSize = 15,
				size = UDim2.new(1, -330, 0, 20),
				position = UDim2.new(0, 78, 0, 16),
			})
			Kit.label({
				parent = cardFrame,
				name = "Record",
				text = string.format("%s  •  Record %d-%d-%d  •  OVR %d", Kit.translate("ladder", tier.name), record.wins or 0, record.losses or 0, record.draws or 0, Kit.overall(student)),
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -330, 0, 16),
				position = UDim2.new(0, 78, 0, 38),
			})

			-- Mini kopeciu mazgai
			local steps = Kit.create("Frame", {
				Name = "Steps",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.new(0, 78, 0, 60),
				Parent = cardFrame,
			})
			Kit.list(steps, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
			for ladderIndex, ladderTier in ipairs(FightConfig.Ladder) do
				-- pereitas: auksinis kontūras su ✓; dabartinis: pilnas auksas; busimas: pilkas kontūras
				local passed = ladderIndex < tierIndex
				local current = ladderIndex == tierIndex
				local name = Kit.translate("ladder", ladderTier.name)
				Kit.badge({
					parent = steps,
					name = "Step" .. ladderIndex,
					text = passed and ("✓ " .. name) or name,
					color = (passed or current) and C.gold or C.border,
					textColor = current and C.textOnGold or (passed and C.gold or C.textSecondary),
					solid = current,
					height = 20,
					order = ladderIndex,
				})
			end

			-- Progresas iki kito lygio
			local progressText
			local progressValue
			if not student.competitionReady then
				local avg = Kit.overall(student)
				progressText = string.format("Fight-ready at OVR %d / %d", avg, TrainingConfig.Trial.competitionReadyStatThreshold)
				progressValue = avg / TrainingConfig.Trial.competitionReadyStatThreshold
			elseif nextTier then
				progressText = string.format("%d/%d wins to “%s”", student.tierWins or 0, tier.winsToPromote, Kit.translate("ladder", nextTier.name))
				progressValue = (student.tierWins or 0) / tier.winsToPromote
			else
				progressText = string.format("WBF level  •  %d tournament titles", student.tournamentWins or 0)
				progressValue = 1
			end
			Kit.label({
				parent = cardFrame,
				name = "ProgressText",
				text = progressText,
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -330, 0, 14),
				position = UDim2.new(0, 78, 0, 84),
			})
			local bar = Kit.progressBar({
				parent = cardFrame,
				size = UDim2.new(1, -330, 0, 6),
				position = UDim2.new(0, 78, 0, 102),
				value = progressValue,
			})
			if not student.competitionReady then
				bar.SetColor(C.steel, C.steelBright)
			end

			-- Desine: kova
			Kit.label({
				parent = cardFrame,
				name = "OpponentRange",
				text = string.format("Opponent stats %d–%d", tier.opponentStatMin, tier.opponentStatMax),
				textSize = 12,
				color = C.textPrimary,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 220, 0, 16),
				position = UDim2.new(1, -16, 0, 16),
				anchor = Vector2.new(1, 0),
			})
			local fighterScore = weightedBase(student.stats) * (1 - math.clamp((student.fatigue or 0) / 100, 0, 1) * FightConfig.FatiguePenaltyMax) * DataSchema.moraleMultiplier(student.morale)
			local chance = roundWinChance(fighterScore, opponentAverage(tier))
			Kit.label({
				parent = cardFrame,
				name = "Odds",
				text = string.format("Round win ~%d%%", math.floor(chance * 100 + 0.5)),
				bold = true,
				textSize = 13,
				color = chance >= 0.6 and C.goldBright or (chance >= 0.4 and C.textPrimary or C.crimsonBright),
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0, 220, 0, 18),
				position = UDim2.new(1, -16, 0, 36),
				anchor = Vector2.new(1, 0),
			})
			local reason = nil
			if not student.competitionReady then
				reason = "Not ready yet"
			elseif student.injured then
				reason = "🩹 Injured"
			elseif (student.fatigue or 0) >= TrainingConfig.FatigueTrainingBlockThreshold then
				reason = "Too tired"
			end
			Kit.button({
				parent = cardFrame,
				name = "FightButton",
				text = reason or string.format("Fight  •  +$%d", tier.payoutWin),
				icon = reason and "" or "🥊",
				variant = "crimson",
				size = UDim2.new(0, 200, 0, 38),
				position = UDim2.new(1, -16, 1, -16),
				anchor = Vector2.new(1, 1),
				textSize = 13,
				enabled = reason == nil,
				onClick = function()
					State.fire("FightRequest", studentIndex)
					Kit.close("Tournament")
				end,
			})
			table.insert(careerRows, cardFrame)
		end
	end

	-- ============================================================
	-- DUOMENYS / ISDESTYMAS
	-- ============================================================
	local function renderAll()
		renderTournaments()
		renderCareer()
	end

	applyNarrow = function()
		if narrow then
			listColumn.Size = UDim2.new(1, -40, 1, -16)
			listColumn.Visible = not showingDetailOnNarrow
			backButton.Instance.Visible = showingDetailOnNarrow
			detail.Visible = showingDetailOnNarrow
			detailFooter.Visible = showingDetailOnNarrow
			detail.Position = UDim2.new(0, 20, 0, 42)
			detail.Size = UDim2.new(1, -40, 1, -(16 + 42 + FOOTER_HEIGHT))
			detailFooter.Position = UDim2.new(0, 20, 1, -16)
			detailFooter.Size = UDim2.new(1, -40, 0, FOOTER_HEIGHT)
		else
			listColumn.Size = UDim2.new(0, 256, 1, -16)
			listColumn.Visible = true
			backButton.Instance.Visible = false
			detail.Visible = true
			detailFooter.Visible = true
			detail.Position = UDim2.new(0, 296, 0, 0)
			detail.Size = UDim2.new(1, -312, 1, -(16 + FOOTER_HEIGHT))
			detailFooter.Position = UDim2.new(0, 296, 1, -16)
			detailFooter.Size = UDim2.new(1, -312, 0, FOOTER_HEIGHT)
		end
	end

	panel.OnLayout(function(layout)
		local wasNarrow = narrow
		narrow = layout.compact or layout.size.X < 640
		if narrow ~= wasNarrow then
			showingDetailOnNarrow = false
		end
		applyNarrow()
	end)

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
	local queueAll = queue(renderAll)
	State.subscribe("students", queueAll)
	State.subscribe("reputation", queueAll)
	State.subscribe("tournament", queueAll)
	State.subscribe("money", queue(updateEnterButton))
	State.onMessage("tournament", function(message)
		if panel.IsOpen then
			panel.Toast(message)
		end
	end)

	panel.Every(1, updateEnterButton)
	panel.Every(30, function()
		State.refresh()
	end)
	panel.OnOpen(function()
		renderAll()
		State.refresh()
	end)

	tabs.Select("tournaments", true)
	return panel
end

return TournamentPanel
