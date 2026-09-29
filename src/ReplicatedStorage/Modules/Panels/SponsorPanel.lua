--[[
	SponsorPanel
	Remejai (fiktyvus prekiu zenklai): aktyvios sutartys su pajamu rinkimu,
	nauji pasiulymai (paieska su cooldown) ir didesniu remeju perziura pagal reputacijos zvaigzdes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SponsorConfig = require(Modules:WaitForChild("SponsorConfig"))

local SponsorPanel = {}

-- Prekes zenklo spalva (is SponsorConfig) pritraukiama prie artimiausio paletes tono,
-- kad atsitiktines config spalvos (zalia, violetine...) nelauztu HUD paletes.
local function paletteTone(C, color)
	local tones = {
		{ top = C.steelBright, bottom = C.steel, text = C.textPrimary },
		{ top = C.crimsonBright, bottom = C.crimson, text = C.textPrimary },
		{ top = C.goldBright, bottom = C.gold, text = C.textOnGold },
		{ top = C.bgCardLight, bottom = C.bgCard, text = C.gold },
	}
	if not color then
		return tones[1]
	end
	local best, bestDistance = tones[1], math.huge
	for _, tone in ipairs(tones) do
		local base = tone.bottom
		local distance = (color.R - base.R) ^ 2 + (color.G - base.G) ^ 2 + (color.B - base.B) ^ 2
		if distance < bestDistance then
			best, bestDistance = tone, distance
		end
	end
	return best
end

-- Remejo "logotipas": inicialai paletes tone
local function monogram(Kit, parent, sponsor, size, position)
	local C = Kit.Colors
	local tone = paletteTone(C, sponsor.color)
	local tile = Kit.create("Frame", {
		Name = "Monogram",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, size, 0, size),
		Position = position,
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = parent,
	})
	Kit.corner(tile, 12)
	Kit.stroke(tile, tone.top, 1, 0.35)
	Kit.gradient(tile, tone.top, tone.bottom, 135)
	Kit.label({
		parent = tile,
		name = "Initials",
		text = Kit.initials(Kit.displayName(sponsor.name)),
		bold = true,
		textSize = math.floor(size * 0.36),
		color = tone.text,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})
	return tile
end

function SponsorPanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Sponsor",
		title = "Sponsors",
		subtitle = "Contracts, income and new offers",
		icon = "🤝",
		accent = "steel",
		maxSize = Vector2.new(760, 560),
	})

	local scroll = Kit.scroll({
		parent = panel.Body,
		name = "Content",
		size = UDim2.new(1, -8, 1, -10),
		paddingTop = 16,
		paddingBottom = 20,
		paddingLeft = 20,
		paddingRight = 8,
		spacing = 12,
	})
	Kit.scrollFade(scroll)

	-- ========================================================
	-- SUVESTINE + PAIESKA
	-- ========================================================
	local summary = Kit.card({
		parent = scroll,
		name = "Summary",
		size = UDim2.new(1, 0, 0, 96),
		order = 1,
		strokeColor = C.steelBright,
		strokeTransparency = 0.55,
	})
	local function summaryBlock(name, caption, x)
		local block = Kit.create("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 170, 1, -32),
			Position = UDim2.new(0, x, 0, 16),
			Parent = summary,
		})
		Kit.label({
			parent = block,
			name = "Caption",
			text = caption,
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 14),
		})
		local value = Kit.label({
			parent = block,
			name = "Value",
			text = "-",
			bold = true,
			textSize = 22,
			size = UDim2.new(1, 0, 0, 26),
			position = UDim2.new(0, 0, 0, 18),
		})
		local sub = Kit.label({
			parent = block,
			name = "Sub",
			text = "",
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 1, -14),
		})
		return value, sub
	end
	local activeValue, activeSub = summaryBlock("Active", "ACTIVE DEALS", 18)
	local incomeValue, incomeSub = summaryBlock("Income", "INCOME", 196)
	Kit.create("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.border,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(0, 1, 1, -32),
		Position = UDim2.new(0, 180, 0, 16),
		Parent = summary,
	})
	local refreshButton = Kit.button({
		parent = summary,
		name = "RefreshButton",
		text = "Find sponsors",
		icon = "📨",
		variant = "steel",
		size = UDim2.new(0, 210, 0, 40),
		position = UDim2.new(1, -18, 0, 18),
		anchor = Vector2.new(1, 0),
		textSize = 13,
		onClick = function()
			State.fire("SponsorRefreshRequest")
		end,
	})
	local refreshCaption = Kit.label({
		parent = summary,
		name = "RefreshCaption",
		text = "",
		bold = true,
		textSize = 12,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 210, 0, 14),
		position = UDim2.new(1, -18, 0, 66),
		anchor = Vector2.new(1, 0),
	})

	local _, activeHint = Kit.sectionHeader({ parent = scroll, title = "Active deals", hint = "", order = 2, accent = C.steelBright })
	local activeHolder = Kit.create("Frame", {
		Name = "ActiveList",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = scroll,
	})
	Kit.list(activeHolder, 10)

	local _, offersHint = Kit.sectionHeader({ parent = scroll, title = "Offers", hint = "", order = 4, accent = C.steelBright })
	local offersHolder = Kit.create("Frame", {
		Name = "OfferList",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = scroll,
	})
	offersHolder.Size = UDim2.new(1, 0, 0, 0)
	local offersGrid = Kit.grid(offersHolder, UDim2.new(0.5, -7, 0, 150), UDim2.new(0, 12, 0, 12))

	-- Kai pasiulymu nera: pilno plocio kortele su paieskos mygtuku vietoje (ne tinklelio langelyje)
	local offersEmpty = Kit.card({
		parent = scroll,
		name = "OffersEmpty",
		size = UDim2.new(1, 0, 0, 72),
		color = C.bgCard,
		gradient = false,
		transparency = 0.4,
		order = 5,
	})
	Kit.label({
		parent = offersEmpty,
		name = "Title",
		text = "No new offers",
		bold = true,
		textSize = 14,
		size = UDim2.new(1, -250, 0, 18),
		position = UDim2.new(0, 18, 0, 17),
	})
	local offersEmptySub = Kit.label({
		parent = offersEmpty,
		name = "Sub",
		text = "",
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, -250, 0, 16),
		position = UDim2.new(0, 18, 0, 39),
	})
	local offersEmptyButton = Kit.button({
		parent = offersEmpty,
		name = "SearchButton",
		text = "Find sponsors",
		icon = "📨",
		variant = "steel",
		size = UDim2.new(0, 210, 0, 40),
		position = UDim2.new(1, -16, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		textSize = 13,
		onClick = function()
			State.fire("SponsorRefreshRequest")
		end,
	})

	Kit.sectionHeader({ parent = scroll, title = "Bigger sponsors", hint = "Unlock as your reputation grows", order = 6, accent = C.steelBright })
	local lockedHolder = Kit.card({
		parent = scroll,
		name = "LockedList",
		size = UDim2.new(1, 0, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		order = 7,
	})
	Kit.padding(lockedHolder, 8, 14, 8, 14)
	Kit.list(lockedHolder, 0)

	-- ========================================================
	-- ATVAIZDAVIMAS
	-- ========================================================
	local dynamic = {}
	local activeTimers = {} -- { entry, button, bar, caption, stroke }

	local function clearDynamic()
		for _, inst in ipairs(dynamic) do
			inst:Destroy()
		end
		table.clear(dynamic)
		table.clear(activeTimers)
	end

	local function updateTimers()
		local now = State.now()
		for _, timer in ipairs(activeTimers) do
			local entry = timer.entry
			local sponsor = SponsorConfig.Sponsors[entry.configIndex]
			local income = sponsor and sponsor.incomePerCycle or 0
			local untilCollect = (entry.nextCollectAt or 0) - now
			local untilExpire = (entry.expiresAt or 0) - now
			local ready = untilExpire > 0 and untilCollect <= 0
			-- Paruostos pajamos: kortele paryskinama auksu, kad isskirtu is laukianciu
			timer.stroke.Color = ready and C.gold or C.border
			timer.stroke.Transparency = ready and 0.45 or 0.45
			timer.stroke.Thickness = ready and 1.5 or 1
			timer.caption.TextColor3 = ready and C.goldBright or C.textSecondary
			timer.caption.Font = ready and Enum.Font.GothamBold or Enum.Font.Gotham
			if untilExpire <= 0 then
				timer.button.SetEnabled(true)
				timer.button.SetVariant("ghost")
				timer.button.SetText("Deal ended — close")
				timer.bar.Set(1)
				timer.caption.Text = "Deal ended"
			elseif ready then
				timer.button.SetEnabled(true)
				timer.button.SetVariant("gold")
				timer.button.SetText("Collect  •  " .. Kit.formatMoney(income))
				timer.bar.Set(1)
				timer.caption.Text = "Income ready!"
			else
				timer.button.SetEnabled(false)
				timer.button.SetVariant("gold")
				timer.button.SetText("Ready in " .. Kit.formatDuration(untilCollect))
				timer.bar.Set(1 - untilCollect / SponsorConfig.CollectCycleSeconds)
				timer.caption.Text = "Deal ends in " .. Kit.formatDuration(untilExpire)
			end
		end

		local s = State.get()
		local remaining = (s.sponsor.lastRefresh or 0) + SponsorConfig.RefreshCooldown - now
		local full = #(s.sponsor.sponsors or {}) >= SponsorConfig.MaxActiveSponsors
		for _, button in ipairs({ refreshButton, offersEmptyButton }) do
			if full then
				button.SetEnabled(false)
				button.SetText("Deal limit reached")
			elseif remaining > 0 then
				button.SetEnabled(false)
				button.SetText("Ready in " .. Kit.formatDuration(remaining))
			else
				button.SetEnabled(true)
				button.SetText("Find sponsors")
			end
		end
		if full then
			refreshCaption.Text = string.format("Max %d active deals", SponsorConfig.MaxActiveSponsors)
			offersEmptySub.Text = "You've hit the deal limit — collect income and wait for a deal to end."
		elseif remaining > 0 then
			refreshCaption.Text = "New offers in " .. Kit.formatDuration(remaining)
			offersEmptySub.Text = "Sponsors are thinking — new offers soon."
		else
			refreshCaption.Text = "You can look for new sponsors"
			offersEmptySub.Text = "A signing bonus lands in your budget right away."
		end
	end

	local function currentStars(s)
		return s.reputation.stars or 1
	end

	local function render()
		clearDynamic()
		local s = State.get()
		local sponsors = s.sponsor.sponsors or {}
		local offers = s.sponsor.offers or {}
		local stars = currentStars(s)
		local full = #sponsors >= SponsorConfig.MaxActiveSponsors

		-- Suvestine
		local incomeTotal = 0
		for _, entry in ipairs(sponsors) do
			local sponsor = SponsorConfig.Sponsors[entry.configIndex]
			incomeTotal += sponsor and sponsor.incomePerCycle or 0
		end
		activeValue.Text = string.format("%d / %d", #sponsors, SponsorConfig.MaxActiveSponsors)
		activeSub.Text = #sponsors == 0 and "No sponsors yet" or "Signed deals"
		incomeValue.Text = Kit.formatMoney(incomeTotal)
		incomeValue.TextColor3 = incomeTotal > 0 and C.goldBright or C.textPrimary
		incomeSub.Text = string.format("every %d min", math.floor(SponsorConfig.CollectCycleSeconds / 60))
		activeHint.Text = #sponsors > 0 and string.format("%d active", #sponsors) or ""
		offersHint.Text = #offers > 0 and string.format("%d new", #offers) or ""

		-- Aktyvios sutartys
		if #sponsors == 0 then
			local empty = Kit.card({
				parent = activeHolder,
				name = "Empty",
				size = UDim2.new(1, 0, 0, 64),
				color = C.bgCard,
				gradient = false,
				transparency = 0.4,
				order = 1,
			})
			Kit.label({
				parent = empty,
				name = "Text",
				text = "📭  No sponsors yet — sign a deal from the offers below.",
				textSize = 12,
				color = C.textSecondary,
				wrap = true,
				size = UDim2.new(1, -32, 1, 0),
				position = UDim2.new(0, 16, 0, 0),
			})
			table.insert(dynamic, empty)
		end
		for position, entry in ipairs(sponsors) do
			local sponsor = SponsorConfig.Sponsors[entry.configIndex]
			if sponsor then
				local cardFrame, cardStroke = Kit.card({
					parent = activeHolder,
					name = "Contract" .. position,
					size = UDim2.new(1, 0, 0, 88),
					order = position,
				})
				monogram(Kit, cardFrame, sponsor, 52, UDim2.new(0, 16, 0.5, 0))
				Kit.label({
					parent = cardFrame,
					name = "Name",
					text = Kit.displayName(sponsor.name),
					bold = true,
					textSize = 15,
					size = UDim2.new(1, -320, 0, 20),
					position = UDim2.new(0, 82, 0, 14),
				})
				Kit.label({
					parent = cardFrame,
					name = "Income",
					text = string.format("<font color=\"#ECC85C\"><b>%s</b></font> every %d min", Kit.formatMoney(sponsor.incomePerCycle), math.floor(SponsorConfig.CollectCycleSeconds / 60)),
					rich = true,
					textSize = 12,
					color = C.textSecondary,
					size = UDim2.new(1, -320, 0, 16),
					position = UDim2.new(0, 82, 0, 36),
				})
				local caption = Kit.label({
					parent = cardFrame,
					name = "Expires",
					text = "",
					textSize = 12,
					color = C.textSecondary,
					size = UDim2.new(1, -320, 0, 14),
					position = UDim2.new(0, 82, 0, 58),
				})
				local bar = Kit.progressBar({
					parent = cardFrame,
					size = UDim2.new(0, 196, 0, 5),
					position = UDim2.new(1, -16, 0, 68),
					anchor = Vector2.new(1, 0),
				})
				local collectButton = Kit.button({
					parent = cardFrame,
					name = "CollectButton",
					text = "Collect",
					variant = "gold",
					size = UDim2.new(0, 196, 0, 36),
					position = UDim2.new(1, -16, 0, 16),
					anchor = Vector2.new(1, 0),
					textSize = 13,
					onClick = function()
						State.fire("SponsorCollectRequest", position)
					end,
				})
				table.insert(activeTimers, { entry = entry, button = collectButton, bar = bar, caption = caption, stroke = cardStroke })
				table.insert(dynamic, cardFrame)
			end
		end

		-- Pasiulymai
		offersEmpty.Visible = #offers == 0
		offersHolder.Visible = #offers > 0
		-- Be pasiulymu paieskos mygtukas rodomas tuscioje korteleje -- suvestineje jo nekartojame
		refreshButton.Instance.Visible = #offers > 0
		refreshCaption.Visible = #offers > 0
		for position, configIndex in ipairs(offers) do
			local sponsor = SponsorConfig.Sponsors[configIndex]
			if sponsor then
				local cycles = math.floor(sponsor.durationSeconds / SponsorConfig.CollectCycleSeconds)
				local totalValue = sponsor.signingBonus + cycles * sponsor.incomePerCycle
				local cardFrame = Kit.card({
					parent = offersHolder,
					name = "Offer" .. position,
					order = position,
					strokeColor = C.gold,
					strokeTransparency = 0.5,
				})
				monogram(Kit, cardFrame, sponsor, 44, UDim2.new(0, 14, 0, 36))
				Kit.label({
					parent = cardFrame,
					name = "Name",
					text = Kit.displayName(sponsor.name),
					bold = true,
					textSize = 14,
					size = UDim2.new(1, -80, 0, 18),
					position = UDim2.new(0, 68, 0, 16),
				})
				Kit.label({
					parent = cardFrame,
					name = "Duration",
					text = string.format("%d min deal  •  Prestige %s", math.floor(sponsor.durationSeconds / 60), Kit.starsRich(sponsor.minStars)),
					rich = true,
					textSize = 12,
					color = C.textSecondary,
					size = UDim2.new(1, -80, 0, 14),
					position = UDim2.new(0, 68, 0, 37),
				})
				Kit.label({
					parent = cardFrame,
					name = "Terms",
					text = string.format(
						"Bonus <font color=\"#ECC85C\"><b>+%s</b></font>  •  %s / %d min  •  Total ≈ %s",
						Kit.formatMoney(sponsor.signingBonus), Kit.formatMoney(sponsor.incomePerCycle),
						math.floor(SponsorConfig.CollectCycleSeconds / 60), Kit.formatMoney(totalValue)
					),
					rich = true,
					textSize = 12,
					color = C.textSecondary,
					wrap = true,
					alignY = Enum.TextYAlignment.Top,
					size = UDim2.new(1, -28, 0, 32),
					position = UDim2.new(0, 14, 0, 66),
				})
				Kit.button({
					parent = cardFrame,
					name = "AcceptButton",
					text = full and "Deal limit reached" or "Sign deal",
					icon = full and "" or "✍️",
					variant = "gold",
					size = UDim2.new(1, -28, 0, 34),
					position = UDim2.new(0, 14, 1, -46),
					textSize = 13,
					enabled = not full,
					onClick = function()
						State.fire("SponsorAcceptRequest", position)
					end,
				})
				table.insert(dynamic, cardFrame)
			end
		end

		-- Uzrakinti (didesni) remejai
		local lockedCount = 0
		for index, sponsor in ipairs(SponsorConfig.Sponsors) do
			if sponsor.minStars > stars then
				lockedCount += 1
				local row = Kit.create("Frame", {
					Name = "Locked" .. index,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 44),
					LayoutOrder = index,
					Parent = lockedHolder,
				})
				local tile = monogram(Kit, row, sponsor, 30, UDim2.new(0, 0, 0.5, 0))
				tile.BackgroundTransparency = 0.5
				Kit.label({
					parent = row,
					name = "Name",
					text = Kit.displayName(sponsor.name),
					bold = true,
					textSize = 13,
					color = C.textSecondary,
					size = UDim2.new(0.5, -44, 1, 0),
					position = UDim2.new(0, 44, 0, 0),
				})
				Kit.label({
					parent = row,
					name = "Terms",
					text = string.format("Bonus %s  •  %s / %d min", Kit.formatMoney(sponsor.signingBonus), Kit.formatMoney(sponsor.incomePerCycle), math.floor(SponsorConfig.CollectCycleSeconds / 60)),
					textSize = 12,
					color = C.textSecondary,
					size = UDim2.new(0.5, -150, 1, 0),
					position = UDim2.new(0.5, -20, 0, 0),
				})
				Kit.label({
					parent = row,
					name = "Stars",
					text = "🔒 Needs " .. Kit.starsRich(sponsor.minStars),
					rich = true,
					bold = true,
					textSize = 12,
					color = C.textSecondary,
					align = Enum.TextXAlignment.Right,
					size = UDim2.new(0, 140, 1, 0),
					position = UDim2.new(1, 0, 0, 0),
					anchor = Vector2.new(1, 0),
				})
				table.insert(dynamic, row)
			end
		end
		lockedHolder.Visible = lockedCount > 0

		updateTimers()
	end

	panel.OnLayout(function(layout)
		offersGrid.CellSize = layout.size.X < 600 and UDim2.new(1, 0, 0, 150) or UDim2.new(0.5, -7, 0, 150)
	end)

	local queued = false
	local function queueRender()
		if not panel.IsOpen or queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			render()
		end)
	end
	State.subscribe("sponsor", queueRender)
	State.subscribe("reputation", queueRender)
	State.subscribe("money", queueRender)
	State.onMessage("sponsor", function(message)
		if panel.IsOpen then
			panel.Toast(message)
		end
	end)

	panel.Every(1, updateTimers)
	panel.OnOpen(function()
		render()
		State.refresh()
	end)

	return panel
end

return SponsorPanel
