--[[
	ScoutPanel
	Skautai:
	  - Talentai: skauto siuntimas (ScoutSearchRequest), kandidatai su potencialu,
	    Scout Report pirkimas (atskleidzia genetines lubas) ir samdymas
	  - Varžovai: kiekvieno karjeros lygio varzovu statistika, uzmokestis ir stiliu ratas
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ScoutConfig = require(Modules:WaitForChild("ScoutConfig"))
local StaffConfig = require(Modules:WaitForChild("StaffConfig"))
local FightConfig = require(Modules:WaitForChild("FightConfig"))
local DataSchema = require(Modules:WaitForChild("DataSchema"))

local ScoutPanel = {}

local STAT_ORDER = { "power", "speed", "defense", "stamina", "technique" }
local TIER_ICONS = { "🥊", "🗺️", "🌍" }

local function staffMultiplier(staff, field)
	if StaffConfig.combinedMultiplier then
		return StaffConfig.combinedMultiplier(staff, field)
	end
	return 1
end

function ScoutPanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Scout",
		title = "Skautai",
		subtitle = "Talentų paieška ir varžovų žvalgyba",
		icon = "🔎",
		accent = "steel",
		maxSize = Vector2.new(760, 560),
	})

	local pages = {}
	local tabs = Kit.tabs({
		parent = panel.Body,
		items = {
			{ key = "talent", label = "Talentai", icon = "🔭" },
			{ key = "rivals", label = "Varžovai", icon = "🥊" },
		},
		size = UDim2.new(1, -40, 0, 42),
		position = UDim2.new(0, 20, 0, 14),
		onSelect = function(key)
			for pageKey, page in pairs(pages) do
				page.Visible = pageKey == key
			end
		end,
	})

	local function makePage(key)
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
			visible = key == "talent",
		})
		Kit.scrollFade(page)
		pages[key] = page
		return page
	end

	-- ============================================================
	-- 1. TALENTAI
	-- ============================================================
	local talentPage = makePage("talent")

	local searchCard = Kit.card({
		parent = talentPage,
		name = "SearchCard",
		size = UDim2.new(1, 0, 0, 104),
		order = 1,
		strokeColor = C.steelBright,
		strokeTransparency = 0.5,
	})
	local searchIcon = Kit.create("Frame", {
		Name = "IconTile",
		BackgroundColor3 = C.bgCardLight,
		Size = UDim2.new(0, 60, 0, 60),
		Position = UDim2.new(0, 18, 0, 18),
		Parent = searchCard,
	})
	Kit.corner(searchIcon, 14)
	Kit.stroke(searchIcon, C.steelBright, 1, 0.4)
	Kit.gradient(searchIcon, C.steelBright, C.steel, 135)
	Kit.label({
		parent = searchIcon,
		name = "Icon",
		text = "🔭",
		textSize = 28,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})
	Kit.label({
		parent = searchCard,
		name = "Title",
		text = "Siųsk skautą ieškoti talentų",
		bold = true,
		textSize = 16,
		size = UDim2.new(1, -310, 0, 20),
		position = UDim2.new(0, 94, 0, 20),
	})
	local searchSub = Kit.label({
		parent = searchCard,
		name = "Sub",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		wrap = true,
		alignY = Enum.TextYAlignment.Top,
		size = UDim2.new(1, -310, 0, 32),
		position = UDim2.new(0, 94, 0, 44),
		rich = true,
	})
	local searchButton = Kit.button({
		parent = searchCard,
		name = "SearchButton",
		text = "Siųsti skautą",
		icon = "🔭",
		variant = "steel",
		size = UDim2.new(0, 196, 0, 40),
		position = UDim2.new(1, -18, 0, 20),
		anchor = Vector2.new(1, 0),
		textSize = 13,
		onClick = function()
			State.fire("ScoutSearchRequest")
		end,
	})
	local cooldownCaption = Kit.label({
		parent = searchCard,
		name = "CooldownCaption",
		text = "",
		bold = true,
		textSize = 12,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 196, 0, 14),
		position = UDim2.new(1, -18, 0, 66),
		anchor = Vector2.new(1, 0),
	})
	local cooldownBar = Kit.progressBar({
		parent = searchCard,
		name = "CooldownBar",
		size = UDim2.new(0, 196, 0, 5),
		position = UDim2.new(1, -18, 0, 84),
		anchor = Vector2.new(1, 0),
		color = C.steel,
		color2 = C.steelBright,
	})

	local _, candidatesHint = Kit.sectionHeader({ parent = talentPage, title = "Kandidatai", hint = "", order = 2, accent = C.steelBright })

	local candidateRows = {}

	local function renderCandidates()
		for _, row in ipairs(candidateRows) do
			row:Destroy()
		end
		table.clear(candidateRows)

		local s = State.get()
		local candidates = s.scout.candidates or {}
		local money = s.money or 0
		candidatesHint.Text = #candidates > 0 and string.format("Rasta: %d", #candidates) or ""

		if #candidates == 0 then
			table.insert(candidateRows, Kit.emptyState({
				parent = talentPage,
				icon = "🧭",
				title = "Kandidatų dar nėra",
				text = "Siųsk skautą — jis atves 3 talentus su jau žinomu potencialu (skirtingai nei atsitiktiniai klientai).",
				size = UDim2.new(1, 0, 0, 160),
				order = 3,
			}))
			return
		end

		for index, candidate in ipairs(candidates) do
			local potentialColor = Kit.potentialColor(candidate.potencialas)
			local hasReport = candidate.reportPurchased == true and type(candidate.statPotential) == "table"
			local cardFrame = Kit.card({
				parent = talentPage,
				name = "Candidate" .. index,
				size = UDim2.new(1, 0, 0, hasReport and 196 or 132),
				order = 2 + index,
				strokeColor = candidate.potencialas == "Legendary" and C.gold or C.border,
				strokeTransparency = candidate.potencialas == "Legendary" and 0.3 or 0.45,
			})
			Kit.avatar({
				parent = cardFrame,
				text = candidate.name,
				size = 52,
				position = UDim2.new(0, 16, 0, 16),
				ringColor = potentialColor,
			})
			Kit.label({
				parent = cardFrame,
				name = "Name",
				text = candidate.name or "?",
				bold = true,
				textSize = 16,
				size = UDim2.new(1, -330, 0, 20),
				position = UDim2.new(0, 82, 0, 18),
			})
			Kit.label({
				parent = cardFrame,
				name = "Personality",
				text = "Asmenybė: " .. Kit.translate("personality", candidate.personality),
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -330, 0, 16),
				position = UDim2.new(0, 82, 0, 40),
			})
			Kit.badge({
				parent = cardFrame,
				text = "💎 " .. Kit.translate("potential", candidate.potencialas) .. " potencialas",
				color = potentialColor,
				position = UDim2.new(0, 82, 0, 62),
			})

			local cost = candidate.recruitCost or ScoutConfig.RecruitCostByPotential[candidate.potencialas] or 150
			local reportCost = ScoutConfig.ReportCost or 40
			Kit.button({
				parent = cardFrame,
				name = "RecruitButton",
				text = money >= cost and ("Samdyti  •  " .. Kit.formatMoney(cost)) or ("Trūksta " .. Kit.formatMoney(cost - money)),
				variant = "gold",
				size = UDim2.new(0, 180, 0, 36),
				position = UDim2.new(1, -16, 0, 16),
				anchor = Vector2.new(1, 0),
				textSize = 13,
				enabled = money >= cost,
				onClick = function()
					State.fire("ScoutRecruitRequest", index)
				end,
			})
			Kit.button({
				parent = cardFrame,
				name = "ReportButton",
				text = hasReport and "Ataskaita nupirkta" or ("Scout Report  •  " .. Kit.formatMoney(reportCost)),
				icon = "📄",
				variant = "ghost",
				size = UDim2.new(0, 180, 0, 32),
				position = UDim2.new(1, -16, 0, 58),
				anchor = Vector2.new(1, 0),
				textSize = 12,
				enabled = not hasReport and money >= reportCost,
				onClick = function()
					State.fire("ScoutReportRequest", index)
				end,
			})

			-- Genetines lubos (Scout Report) arba uzrakinta juosta
			local capsBox = Kit.create("Frame", {
				Name = "Caps",
				BackgroundColor3 = C.bg,
				BackgroundTransparency = 0.2,
				Size = UDim2.new(1, -32, 0, hasReport and 90 or 28),
				Position = UDim2.new(0, 16, 0, 96),
				Parent = cardFrame,
			})
			Kit.corner(capsBox, 10)
			if hasReport then
				Kit.padding(capsBox, 10, 12, 10, 12)
				Kit.label({
					parent = capsBox,
					name = "Caption",
					text = "GENETINĖS LUBOS (maks. pasiekiama statistika)",
					bold = true,
					textSize = 12,
					color = C.textSecondary,
					size = UDim2.new(1, 0, 0, 12),
				})
				local best, bestValue = nil, -1
				for _, statId in ipairs(STAT_ORDER) do
					local value = candidate.statPotential[statId] or 0
					if value > bestValue then
						best, bestValue = statId, value
					end
				end
				for statIndex, statId in ipairs(STAT_ORDER) do
					local value = candidate.statPotential[statId] or 0
					local column = Kit.create("Frame", {
						Name = "Cap_" .. statId,
						BackgroundTransparency = 1,
						Size = UDim2.new(0.2, -8, 0, 50),
						Position = UDim2.new((statIndex - 1) * 0.2, 0, 0, 20),
						Parent = capsBox,
					})
					local isBest = statId == best
					Kit.label({
						parent = column,
						name = "Name",
						text = Kit.translate("stats", statId),
						textSize = 12,
						color = isBest and C.goldBright or C.textSecondary,
						bold = isBest,
						size = UDim2.new(1, 0, 0, 14),
					})
					Kit.label({
						parent = column,
						name = "Value",
						text = tostring(value),
						bold = true,
						textSize = 18,
						color = isBest and C.goldBright or C.textPrimary,
						size = UDim2.new(1, 0, 0, 20),
						position = UDim2.new(0, 0, 0, 15),
					})
					local bar = Kit.progressBar({
						parent = column,
						size = UDim2.new(1, 0, 0, 5),
						position = UDim2.new(0, 0, 0, 40),
						value = value / 100,
					})
					if not isBest then
						bar.SetColor(C.steel, C.steelBright)
					end
				end
			else
				Kit.label({
					parent = capsBox,
					name = "Locked",
					text = "🔒  Genetinės lubos paslėptos — Scout Report parodys, kiek kiekviena statistika gali užaugti.",
					textSize = 12,
					color = C.textSecondary,
					size = UDim2.new(1, -24, 1, 0),
					position = UDim2.new(0, 12, 0, 0),
				})
			end

			table.insert(candidateRows, cardFrame)
		end
	end

	local function renderSearch()
		local s = State.get()
		local staff = s.staff or {}
		local costMultiplier = staffMultiplier(staff, "scoutCostMultiplier")
		local cooldownMultiplier = staffMultiplier(staff, "scoutCooldownMultiplier")
		local cost = math.floor(ScoutConfig.ScoutCost * costMultiplier + 0.5)
		local cooldown = math.floor(ScoutConfig.ScoutCooldown * cooldownMultiplier + 0.5)
		local money = s.money or 0

		local subText = string.format("Rasi %d kandidatus su atskleistu potencialu.", ScoutConfig.CandidateCount)
		if costMultiplier < 1 or cooldownMultiplier < 1 then
			subText ..= string.format(" <font color=\"#608EBC\">Skauto nuolaida: -%d%% kaina.</font>", math.floor((1 - costMultiplier) * 100 + 0.5))
		else
			subText ..= " Pasamdyk Skautą (Personalas) — paieška bus pigesnė."
		end
		searchSub.Text = subText

		local remaining = (s.scout.lastScoutAt or 0) + cooldown - State.now()
		if remaining > 0 then
			searchButton.SetEnabled(false)
			searchButton.SetText("Skautas ilsisi")
			cooldownCaption.Text = "Grįš po " .. Kit.formatDuration(remaining)
			cooldownBar.Instance.Visible = true
			cooldownBar.Set(1 - remaining / math.max(1, cooldown), true)
		else
			cooldownBar.Instance.Visible = false
			cooldownCaption.Text = "Skautas pasiruošęs"
			if money >= cost then
				searchButton.SetEnabled(true)
				searchButton.SetText("Siųsti skautą  •  " .. Kit.formatMoney(cost))
			else
				searchButton.SetEnabled(false)
				searchButton.SetText("Trūksta " .. Kit.formatMoney(cost - money))
			end
		end
	end

	-- ============================================================
	-- 2. VARŽOVAI (žvalgyba)
	-- ============================================================
	local rivalsPage = makePage("rivals")
	Kit.label({
		parent = rivalsPage,
		name = "Intro",
		text = "Kiekviename karjeros lygyje varžovų statistika atsitiktinė, bet ribota. Palygink su savo kovotojais prieš kovą.",
		textSize = 12,
		color = C.textSecondary,
		wrap = true,
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 1,
	})

	for tierIndex, tier in ipairs(FightConfig.Ladder) do
		local cardFrame = Kit.card({
			parent = rivalsPage,
			name = "Tier" .. tierIndex,
			size = UDim2.new(1, 0, 0, 104),
			order = 1 + tierIndex,
		})
		local iconTile = Kit.create("Frame", {
			Name = "IconTile",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(0, 48, 0, 48),
			Position = UDim2.new(0, 16, 0, 16),
			Parent = cardFrame,
		})
		Kit.corner(iconTile, 12)
		Kit.stroke(iconTile, C.border, 1, 0.3)
		Kit.label({
			parent = iconTile,
			name = "Icon",
			text = TIER_ICONS[tierIndex] or "🥊",
			textSize = 22,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		Kit.label({
			parent = cardFrame,
			name = "Name",
			text = string.format("%d. %s", tierIndex, Kit.translate("ladder", tier.name)),
			bold = true,
			textSize = 15,
			size = UDim2.new(0.5, -80, 0, 20),
			position = UDim2.new(0, 78, 0, 16),
		})
		local promoteText = tier.winsToPromote == math.huge and "Aukščiausias lygis"
			or string.format("Kilimas: %d pergalės", tier.winsToPromote)
		Kit.label({
			parent = cardFrame,
			name = "Promote",
			text = promoteText,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(0.5, -80, 0, 16),
			position = UDim2.new(0, 78, 0, 38),
		})
		Kit.label({
			parent = cardFrame,
			name = "Payout",
			text = string.format("Pergalė <font color=\"#ECC85C\">+$%d</font>  •  Pralaim. +$%d  •  Rep. +%d", tier.payoutWin, tier.payoutLoss, tier.reputationWin),
			rich = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(0.5, -80, 0, 16),
			position = UDim2.new(0, 78, 0, 70),
		})
		-- Statistikos diapazonas skaleje 0-100
		local rangeBox = Kit.create("Frame", {
			Name = "Range",
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -16, 0, 60),
			Position = UDim2.new(0.5, 0, 0, 20),
			Parent = cardFrame,
		})
		Kit.label({
			parent = rangeBox,
			name = "Caption",
			text = "VARŽOVŲ STATISTIKA",
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 12),
		})
		Kit.label({
			parent = rangeBox,
			name = "Value",
			text = string.format("%d – %d", tier.opponentStatMin, tier.opponentStatMax),
			bold = true,
			textSize = 18,
			color = C.textPrimary,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(1, 0, 0, 20),
			position = UDim2.new(0, 0, 0, -4),
		})
		local track = Kit.create("Frame", {
			Name = "Track",
			BackgroundColor3 = C.bg,
			Size = UDim2.new(1, 0, 0, 8),
			Position = UDim2.new(0, 0, 0, 28),
			Parent = rangeBox,
		})
		Kit.corner(track, UDim.new(1, 0))
		Kit.stroke(track, C.border, 1, 0.6)
		local span = Kit.create("Frame", {
			Name = "Span",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new((tier.opponentStatMax - tier.opponentStatMin) / 100, 0, 1, 0),
			Position = UDim2.new(tier.opponentStatMin / 100, 0, 0, 0),
			Parent = track,
		})
		Kit.corner(span, UDim.new(1, 0))
		Kit.gradient(span, C.crimson, C.crimsonBright, 0)
		for _, mark in ipairs({ 0, 50, 100 }) do
			Kit.label({
				parent = rangeBox,
				name = "Mark" .. mark,
				text = tostring(mark),
				textSize = 12,
				color = C.textSecondary,
				align = mark == 0 and Enum.TextXAlignment.Left or (mark == 100 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center),
				size = UDim2.new(0, 30, 0, 12),
				position = UDim2.new(mark / 100, 0, 0, 42),
				anchor = Vector2.new(mark / 100, 0),
			})
		end
	end

	-- Stiliu ratas
	local wheelCard = Kit.card({
		parent = rivalsPage,
		name = "StyleWheel",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 10,
	})
	Kit.padding(wheelCard, 14, 16, 16, 16)
	Kit.list(wheelCard, 8)
	Kit.sectionHeader({
		parent = wheelCard,
		title = "Stilių ratas",
		hint = string.format("Pranašumas: +%d%%  •  Silpnybė: -%d%%",
			math.floor((FightConfig.StyleAdvantageMultiplier - 1) * 100 + 0.5),
			math.floor((1 - FightConfig.StyleDisadvantageMultiplier) * 100 + 0.5)),
		order = 0,
	})
	local wheelOrder = 1
	for _, styleId in ipairs(DataSchema.FighterStyles) do
		local victim = FightConfig.StyleAdvantage[styleId]
		if victim then
			local row = Kit.create("Frame", {
				Name = "Pair_" .. wheelOrder,
				BackgroundColor3 = C.bg,
				BackgroundTransparency = 0.3,
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = wheelOrder,
				Parent = wheelCard,
			})
			Kit.corner(row, 8)
			Kit.label({
				parent = row,
				name = "Text",
				text = string.format("<b>%s</b>   <font color=\"#ECC85C\">➜ stiprus prieš</font>   %s", styleId, victim),
				rich = true,
				textSize = 12,
				size = UDim2.new(1, -24, 1, 0),
				position = UDim2.new(0, 12, 0, 0),
			})
			wheelOrder += 1
		end
	end
	Kit.label({
		parent = wheelCard,
		name = "Balanced",
		text = "Balanced — neutralus: neturi nei pranašumo, nei silpnybės.",
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 16),
		order = 99,
	})

	-- ============================================================
	-- DUOMENYS
	-- ============================================================
	local function renderAll()
		renderSearch()
		renderCandidates()
	end

	local queued = false
	local function queueRender()
		if not panel.IsOpen or queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			renderAll()
		end)
	end
	State.subscribe("scout", queueRender)
	State.subscribe("money", queueRender)
	State.subscribe("staff", queueRender)
	State.onMessage("scout", function(message)
		if panel.IsOpen then
			panel.Toast(message)
		end
	end)

	panel.Every(1, renderSearch)
	panel.OnOpen(function()
		renderAll()
		State.refresh()
	end)

	tabs.Select("talent", true)
	return panel
end

return ScoutPanel
