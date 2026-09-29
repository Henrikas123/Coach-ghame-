--[[
	SponsorPanel
	Remejai (fiktyvus prekiu zenklai): aktyvios sutartys su pajamu rinkimu,
	nauji pasiulymai (paieska su cooldown) ir didesniu remeju perziura pagal reputacijos zvaigzdes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SponsorConfig = require(Modules:WaitForChild("SponsorConfig"))

local SponsorPanel = {}

-- Remejo "logotipas": inicialai + prekes zenklo spalva (is SponsorConfig)
local function monogram(Kit, parent, sponsor, size, position)
	local C = Kit.Colors
	local tile = Kit.create("Frame", {
		Name = "Monogram",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, size, 0, size),
		Position = position,
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = parent,
	})
	Kit.corner(tile, 12)
	Kit.stroke(tile, C.border, 1, 0.2)
	local base = sponsor.color or C.steel
	Kit.gradient(tile, base, base:Lerp(Color3.new(0, 0, 0), 0.45), 135)
	Kit.label({
		parent = tile,
		name = "Initials",
		text = Kit.initials(Kit.displayName(sponsor.name)),
		bold = true,
		textSize = math.floor(size * 0.36),
		color = C.textPrimary,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})
	return tile
end

function SponsorPanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Sponsor",
		title = "Rėmėjai",
		subtitle = "Sutartys, pajamos ir nauji pasiūlymai",
		icon = "🤝",
		accent = "steel",
		maxSize = Vector2.new(760, 560),
	})

	local scroll = Kit.scroll({
		parent = panel.Body,
		name = "Content",
		paddingTop = 16,
		paddingBottom = 20,
		paddingLeft = 20,
		paddingRight = 16,
		spacing = 12,
	})

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
			textSize = 11,
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
			textSize = 11,
			color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 1, -14),
		})
		return value, sub
	end
	local activeValue, activeSub = summaryBlock("Active", "AKTYVIOS SUTARTYS", 18)
	local incomeValue, incomeSub = summaryBlock("Income", "PAJAMOS", 196)
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
		text = "Ieškoti rėmėjų",
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
		textSize = 11,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0, 210, 0, 14),
		position = UDim2.new(1, -18, 0, 66),
		anchor = Vector2.new(1, 0),
	})

	local _, activeHint = Kit.sectionHeader({ parent = scroll, title = "Aktyvios sutartys", hint = "", order = 2, accent = C.steelBright })
	local activeHolder = Kit.create("Frame", {
		Name = "ActiveList",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = scroll,
	})
	Kit.list(activeHolder, 10)

	local _, offersHint = Kit.sectionHeader({ parent = scroll, title = "Pasiūlymai", hint = "", order = 4, accent = C.steelBright })
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

	Kit.sectionHeader({ parent = scroll, title = "Didesni rėmėjai", hint = "Atsirakina kylant reputacijai", order = 6, accent = C.steelBright })
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
	local activeTimers = {} -- { entry, button, bar, caption, expires }

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
			if untilExpire <= 0 then
				timer.button.SetEnabled(true)
				timer.button.SetVariant("ghost")
				timer.button.SetText("Sutartis baigėsi -- uždaryti")
				timer.bar.Set(1)
				timer.caption.Text = "Sutartis baigėsi"
			elseif untilCollect <= 0 then
				timer.button.SetEnabled(true)
				timer.button.SetVariant("gold")
				timer.button.SetText("Surinkti  •  " .. Kit.formatMoney(income))
				timer.bar.Set(1)
				timer.caption.Text = "Pajamos paruoštos!"
			else
				timer.button.SetEnabled(false)
				timer.button.SetVariant("gold")
				timer.button.SetText("Po " .. Kit.formatDuration(untilCollect))
				timer.bar.Set(1 - untilCollect / SponsorConfig.CollectCycleSeconds)
				timer.caption.Text = "Sutartis baigsis po " .. Kit.formatDuration(untilExpire)
			end
		end

		local s = State.get()
		local remaining = (s.sponsor.lastRefresh or 0) + SponsorConfig.RefreshCooldown - now
		local full = #(s.sponsor.sponsors or {}) >= SponsorConfig.MaxActiveSponsors
		if full then
			refreshButton.SetEnabled(false)
			refreshButton.SetText("Sutarčių limitas")
			refreshCaption.Text = string.format("Daugiausia %d aktyvios sutartys", SponsorConfig.MaxActiveSponsors)
		elseif remaining > 0 then
			refreshButton.SetEnabled(false)
			refreshButton.SetText("Laukiama atsakymų")
			refreshCaption.Text = "Nauji pasiūlymai po " .. Kit.formatDuration(remaining)
		else
			refreshButton.SetEnabled(true)
			refreshButton.SetText("Ieškoti rėmėjų")
			refreshCaption.Text = "Galima ieškoti naujų rėmėjų"
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
		activeSub.Text = #sponsors == 0 and "Dar nėra rėmėjų" or "Pasirašytos sutartys"
		incomeValue.Text = Kit.formatMoney(incomeTotal)
		incomeValue.TextColor3 = incomeTotal > 0 and C.goldBright or C.textPrimary
		incomeSub.Text = string.format("kas %d min", math.floor(SponsorConfig.CollectCycleSeconds / 60))
		activeHint.Text = #sponsors > 0 and string.format("%d aktyvios", #sponsors) or ""
		offersHint.Text = #offers > 0 and string.format("%d nauji", #offers) or ""

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
				text = "📭  Dar neturi rėmėjų. Ieškok pasiūlymų -- pasirašymo bonusas iškart papildys biudžetą.",
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
				local cardFrame = Kit.card({
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
					text = string.format("<font color=\"#ECC85C\"><b>%s</b></font> kas %d min", Kit.formatMoney(sponsor.incomePerCycle), math.floor(SponsorConfig.CollectCycleSeconds / 60)),
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
					textSize = 11,
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
					text = "Surinkti",
					variant = "gold",
					size = UDim2.new(0, 196, 0, 36),
					position = UDim2.new(1, -16, 0, 16),
					anchor = Vector2.new(1, 0),
					textSize = 13,
					onClick = function()
						State.fire("SponsorCollectRequest", position)
					end,
				})
				table.insert(activeTimers, { entry = entry, button = collectButton, bar = bar, caption = caption })
				table.insert(dynamic, cardFrame)
			end
		end

		-- Pasiulymai
		if #offers == 0 then
			local empty = Kit.card({
				parent = offersHolder,
				name = "Empty",
				color = C.bgCard,
				gradient = false,
				transparency = 0.4,
				order = 1,
			})
			Kit.label({
				parent = empty,
				name = "Text",
				text = "Naujų pasiūlymų nėra.\nPaspausk „Ieškoti rėmėjų“.",
				textSize = 12,
				color = C.textSecondary,
				wrap = true,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -24, 1, 0),
				position = UDim2.new(0, 12, 0, 0),
			})
			table.insert(dynamic, empty)
		end
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
					text = string.format("Trukmė %d min  •  %s", math.floor(sponsor.durationSeconds / 60), Kit.stars(sponsor.minStars)),
					textSize = 11,
					color = C.textSecondary,
					size = UDim2.new(1, -80, 0, 14),
					position = UDim2.new(0, 68, 0, 37),
				})
				Kit.label({
					parent = cardFrame,
					name = "Terms",
					text = string.format(
						"Bonusas <font color=\"#ECC85C\"><b>+%s</b></font>  •  %s / %d min  •  Viso ≈ %s",
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
					text = full and "Sutarčių limitas" or "Pasirašyti sutartį",
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
					text = string.format("Bonusas %s  •  %s / %d min", Kit.formatMoney(sponsor.signingBonus), Kit.formatMoney(sponsor.incomePerCycle), math.floor(SponsorConfig.CollectCycleSeconds / 60)),
					textSize = 11,
					color = C.textSecondary,
					size = UDim2.new(0.5, -120, 1, 0),
					position = UDim2.new(0.5, 0, 0, 0),
				})
				Kit.label({
					parent = row,
					name = "Stars",
					text = "🔒 " .. Kit.stars(sponsor.minStars),
					bold = true,
					textSize = 12,
					color = C.gold,
					align = Enum.TextXAlignment.Right,
					size = UDim2.new(0, 110, 1, 0),
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
