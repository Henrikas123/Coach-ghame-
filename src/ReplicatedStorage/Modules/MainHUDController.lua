--[[
	MainHUDController
	Coach Academy main HUD in the "fight night" identity:
	  * StatusPanel: a championship-belt plate -- tier gem medallion (Bronze/Silver/Gold/
	    Sapphire/Ruby by reputation stars), animated money counter with +$/-$ pop-ups, tier name.
	  * NavDock: the ring apron -- red corner and blue corner posts with three ropes inside the
	    dock; buttons show a tier accent and light up while their panel is open.
	  * PhoneFab: gold phone button with a "post ready" badge.
	Buttons call _G.CoachAcademyPanels[key]() (registered by PanelsBootstrap).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainHUDController = {}

-- ============================================================
-- PALETTE
-- ============================================================
local COLORS = {
	bg = Color3.fromRGB(22, 20, 24),
	bgCard = Color3.fromRGB(30, 27, 32),
	bgCardLight = Color3.fromRGB(38, 34, 40),
	border = Color3.fromRGB(64, 56, 40),

	gold = Color3.fromRGB(212, 175, 55),
	goldBright = Color3.fromRGB(236, 200, 92),

	steel = Color3.fromRGB(70, 108, 148),
	steelBright = Color3.fromRGB(96, 142, 188),

	crimson = Color3.fromRGB(178, 40, 54),
	crimsonBright = Color3.fromRGB(214, 62, 76),

	textPrimary = Color3.fromRGB(240, 235, 226),
	textSecondary = Color3.fromRGB(168, 160, 150),
	textOnGold = Color3.fromRGB(32, 24, 8),

	shadow = Color3.fromRGB(0, 0, 0),
	white = Color3.new(1, 1, 1),
}

-- Belt gem by reputation stars
local GEMS = {
	{ name = "Bronze", light = Color3.fromRGB(214, 150, 96), dark = Color3.fromRGB(120, 70, 36) },
	{ name = "Silver", light = Color3.fromRGB(226, 228, 232), dark = Color3.fromRGB(120, 124, 132) },
	{ name = "Gold", light = COLORS.goldBright, dark = Color3.fromRGB(150, 112, 32) },
	{ name = "Sapphire", light = COLORS.steelBright, dark = Color3.fromRGB(36, 62, 96) },
	{ name = "Ruby", light = COLORS.crimsonBright, dark = Color3.fromRGB(110, 20, 32) },
}

local NAV_ITEMS = {
	{ key = "Profile", label = "PROFILE", accent = COLORS.gold },
	{ key = "Academy", label = "ACADEMY", accent = COLORS.gold },
	{ key = "Staff", label = "STAFF", accent = COLORS.steelBright },
	{ key = "Scout", label = "SCOUTING", accent = COLORS.steelBright },
	{ key = "Sponsor", label = "SPONSORS", accent = COLORS.steelBright },
	{ key = "Tournament", label = "TOURNAMENTS", accent = COLORS.crimsonBright },
}

local IconConfig = nil
do
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local iconModule = modules and modules:FindFirstChild("IconConfig")
	if iconModule then
		local ok, result = pcall(require, iconModule)
		if ok then
			IconConfig = result
		end
	end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function tween(inst, time, goals, style, direction, repeatCount, reverses)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, repeatCount or 0, reverses or false), goals)
	t:Play()
	return t
end

local function new(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 12) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- UIGradient multiplies BackgroundColor3, so the frame background is set to white
local function gradient(parent, top, bottom, rotation)
	parent.BackgroundColor3 = COLORS.white
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	}, parent)
end

local function label(props)
	return new("TextLabel", {
		Name = props.name or "Label",
		BackgroundTransparency = 1,
		Font = props.font or Enum.Font.Gotham,
		Text = props.text or "",
		TextSize = props.size or 16,
		TextColor3 = props.color or COLORS.textPrimary,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = props.rich == true,
		Size = props.uiSize or UDim2.new(1, 0, 1, 0),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		ZIndex = props.zIndex or 2,
	}, props.parent)
end

local function addShadow(target, transparency, offsetY, radius)
	local shadow = new("Frame", {
		Name = target.Name .. "Shadow",
		BackgroundColor3 = COLORS.shadow,
		BackgroundTransparency = transparency or 0.55,
		BorderSizePixel = 0,
		AnchorPoint = target.AnchorPoint,
		Size = target.Size,
		Position = target.Position + UDim2.new(0, 0, 0, offsetY or 4),
		ZIndex = target.ZIndex - 1,
	}, target.Parent)
	corner(shadow, radius or UDim.new(0, 14))
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		shadow.Size = UDim2.new(0, target.AbsoluteSize.X, 0, target.AbsoluteSize.Y)
	end)
	return shadow
end

local function formatMoney(n)
	n = math.floor((tonumber(n) or 0) + 0.5)
	local digits = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (n < 0 and "-$" or "$") .. digits
end

local function starsRich(stars)
	stars = math.clamp(stars or 1, 0, 5)
	return string.format('<font color="#D4AF37">%s</font><font color="#6A5E48">%s</font>',
		string.rep("★", stars), string.rep("☆", 5 - stars))
end

local function makeIcon(parent, name, props)
	if IconConfig then
		return IconConfig.make(parent, name, props)
	end
	return label({ parent = parent, name = "Icon", text = "•", size = props.textSize or 20, align = Enum.TextXAlignment.Center, uiSize = props.size, position = props.position, anchor = props.anchor, zIndex = props.zIndex })
end

local function attachPress(button, scale)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.93 })
	end)
	local function release()
		tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- ============================================================
-- STATUS PANEL: championship belt plate
-- ============================================================
local function buildStatusPanel(screenGui)
	local panel = new("Frame", {
		Name = "StatusPanel",
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(0, 268, 0, 80),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, screenGui)
	corner(panel, 16)
	stroke(panel, COLORS.gold, 1.5, 0.35)
	gradient(panel, Color3.fromRGB(50, 43, 50), Color3.fromRGB(24, 21, 26))
	addShadow(panel, 0.55, 5, UDim.new(0, 16))

	-- leather stitching
	for _, y in ipairs({ 6, 73 }) do
		for i = 0, 17 do
			new("Frame", {
				Name = "Stitch",
				Position = UDim2.new(0, 82 + i * 10, 0, y),
				Size = UDim2.new(0, 5, 0, 1),
				BackgroundColor3 = COLORS.gold,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, panel)
		end
	end

	-- gem medallion
	local medal = new("Frame", {
		Name = "Medal",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.new(0, 62, 0, 62),
		ZIndex = 3,
	}, panel)
	corner(medal, UDim.new(1, 0))
	stroke(medal, COLORS.goldBright, 2, 0.05)
	gradient(medal, Color3.fromRGB(70, 58, 40), Color3.fromRGB(28, 24, 20), 135)
	local medalScale = new("UIScale", { Scale = 1 }, medal)
	local gem = new("Frame", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 46, 0, 46),
		ZIndex = 4,
	}, medal)
	corner(gem, UDim.new(1, 0))
	stroke(gem, COLORS.textOnGold, 1, 0.5)
	local gemGradient = gradient(gem, GEMS[1].light, GEMS[1].dark, 135)
	local gemStar = label({
		parent = gem,
		name = "Star",
		text = "★",
		font = Enum.Font.GothamBlack,
		size = 24,
		color = COLORS.white,
		align = Enum.TextXAlignment.Center,
		zIndex = 5,
	})
	gemStar.TextStrokeTransparency = 0.6

	local moneyLabel = label({
		parent = panel,
		name = "MoneyValue",
		text = "$0",
		font = Enum.Font.GothamBlack,
		size = 24,
		color = COLORS.goldBright,
		uiSize = UDim2.new(1, -94, 0, 28),
		position = UDim2.new(0, 84, 0, 9),
		zIndex = 3,
	})
	local tierLabel = label({
		parent = panel,
		name = "ReputationValue",
		text = "LOCAL COACH",
		font = Enum.Font.Oswald,
		size = 16,
		color = COLORS.textPrimary,
		uiSize = UDim2.new(1, -94, 0, 18),
		position = UDim2.new(0, 84, 0, 38),
		zIndex = 3,
	})
	local starsLabel = label({
		parent = panel,
		name = "ReputationStars",
		text = starsRich(1),
		rich = true,
		font = Enum.Font.GothamBold,
		size = 13,
		uiSize = UDim2.new(1, -94, 0, 14),
		position = UDim2.new(0, 84, 0, 56),
		zIndex = 3,
	})

	return {
		panel = panel,
		money = moneyLabel,
		tier = tierLabel,
		stars = starsLabel,
		gemGradient = gemGradient,
		medalScale = medalScale,
	}
end

-- ============================================================
-- NAV DOCK: ring apron with corner posts and ropes
-- ============================================================
local function createNavButton(parent, item, order)
	local btn = new("TextButton", {
		Name = item.key .. "Button",
		LayoutOrder = order,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(0, 98, 0, 52),
		ZIndex = 4,
	}, parent)
	corner(btn, 11)
	local btnStroke = stroke(btn, COLORS.border, 1, 0.35)
	gradient(btn, COLORS.bgCardLight, COLORS.bgCard)
	local scale = new("UIScale", { Scale = 1 }, btn)
	attachPress(btn, scale)

	local glow = new("Frame", {
		Name = "ActiveGlow",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = item.accent,
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, btn)
	corner(glow, 11)
	local accent = new("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0, 44, 0, 3),
		BackgroundColor3 = item.accent,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, btn)
	corner(accent, UDim.new(1, 0))

	makeIcon(btn, item.key, {
		color = item.accent,
		textSize = 19,
		size = UDim2.new(0, 22, 0, 22),
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 7),
		zIndex = 5,
	})
	local text = label({
		parent = btn,
		name = "Label",
		text = item.label,
		font = Enum.Font.Oswald,
		size = 14,
		color = COLORS.textPrimary,
		align = Enum.TextXAlignment.Center,
		uiSize = UDim2.new(1, -6, 0, 16),
		position = UDim2.new(0, 3, 1, -20),
		zIndex = 5,
	})

	local state = { hover = false, active = false }
	local function paint()
		local lit = state.hover or state.active
		tween(accent, 0.15, { Size = UDim2.new(0, lit and 70 or 44, 0, state.active and 4 or 3) })
		tween(glow, 0.15, { BackgroundTransparency = state.active and 0.82 or (state.hover and 0.92 or 1) })
		tween(btnStroke, 0.15, { Color = lit and item.accent or COLORS.border, Transparency = lit and 0.25 or 0.35 })
		text.TextColor3 = state.active and item.accent or COLORS.textPrimary
	end
	btn.MouseEnter:Connect(function()
		state.hover = true
		paint()
	end)
	btn.MouseLeave:Connect(function()
		state.hover = false
		paint()
	end)
	return btn, function(active)
		state.active = active
		paint()
	end
end

-- Dock geometry: the ropes and corner posts live INSIDE the dark dock (never floating over the world)
local BUTTON_W, BUTTON_H, BUTTON_GAP = 98, 52, 8
local DOCK_SIDE = 30 -- room for the corner posts
local DOCK_H = 80
local DOCK_W = #NAV_ITEMS * BUTTON_W + (#NAV_ITEMS - 1) * BUTTON_GAP + DOCK_SIDE * 2

local function buildNavDock(screenGui)
	local dock = new("Frame", {
		Name = "NavDock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, DOCK_W, 0, DOCK_H),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, screenGui)
	corner(dock, 14)
	stroke(dock, COLORS.border, 1, 0.25)
	gradient(dock, Color3.fromRGB(46, 40, 48), Color3.fromRGB(20, 17, 22))
	addShadow(dock, 0.55, 5, UDim.new(0, 14))
	-- narrow screens: shrink the whole dock instead of letting it run off screen
	local dockScale = new("UIScale", { Scale = 1 }, dock)
	local camera = game:GetService("Workspace").CurrentCamera
	local function fit()
		local width = camera and camera.ViewportSize.X or 0
		dockScale.Scale = width > 0 and math.min(1, (width - 24) / DOCK_W) or 1
	end
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	fit()

	-- three ropes across the top of the dock (red / white / blue)
	for index, def in ipairs({
		{ color = COLORS.crimsonBright, dark = COLORS.crimson },
		{ color = COLORS.textPrimary, dark = Color3.fromRGB(150, 144, 136) },
		{ color = COLORS.steelBright, dark = COLORS.steel },
	}) do
		local rope = new("Frame", {
			Name = "Rope" .. index,
			Position = UDim2.new(0, DOCK_SIDE - 14, 0, 6 + (index - 1) * 5),
			Size = UDim2.new(1, -(DOCK_SIDE - 14) * 2, 0, 3),
			BorderSizePixel = 0,
			ZIndex = 4,
		}, dock)
		corner(rope, UDim.new(1, 0))
		gradient(rope, def.color, def.dark)
	end

	-- red corner (left) and blue corner (right) posts
	for _, def in ipairs({
		{ name = "RedCorner", x = 0, offset = 8, anchor = 0, light = COLORS.crimsonBright, dark = COLORS.crimson },
		{ name = "BlueCorner", x = 1, offset = -8, anchor = 1, light = COLORS.steelBright, dark = COLORS.steel },
	}) do
		local post = new("Frame", {
			Name = def.name,
			AnchorPoint = Vector2.new(def.anchor, 0.5),
			Position = UDim2.new(def.x, def.offset, 0.5, 0),
			Size = UDim2.new(0, 12, 1, -12),
			BorderSizePixel = 0,
			ZIndex = 5,
		}, dock)
		corner(post, 6)
		gradient(post, def.light, def.dark, 0)
	end

	local row = new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -DOCK_SIDE * 2, 0, BUTTON_H),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, dock)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, BUTTON_GAP),
	}, row)

	local buttons, setters = {}, {}
	for index, item in ipairs(NAV_ITEMS) do
		buttons[item.key], setters[item.key] = createNavButton(row, item, index)
	end
	return dock, buttons, setters
end

-- ============================================================
-- PHONE FAB
-- ============================================================
local function buildPhoneFab(screenGui)
	local fab = new("TextButton", {
		Name = "PhoneFab",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, 60, 0, 60),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
	}, screenGui)
	corner(fab, UDim.new(1, 0))
	stroke(fab, COLORS.goldBright, 2, 0.15)
	gradient(fab, COLORS.goldBright, COLORS.gold)
	addShadow(fab, 0.5, 5, UDim.new(1, 0))
	local scale = new("UIScale", { Scale = 1 }, fab)
	attachPress(fab, scale)
	fab.MouseEnter:Connect(function()
		tween(scale, 0.15, { Scale = 1.06 })
	end)
	makeIcon(fab, "Phone", {
		color = COLORS.textOnGold,
		textSize = 26,
		size = UDim2.new(0, 30, 0, 30),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		zIndex = 4,
	})
	local badge = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0, 22, 0, 22),
		BackgroundColor3 = COLORS.crimsonBright,
		Visible = false,
		ZIndex = 6,
	}, fab)
	corner(badge, UDim.new(1, 0))
	stroke(badge, COLORS.bg, 2, 0)
	local badgeText = label({
		parent = badge,
		name = "Count",
		text = "!",
		font = Enum.Font.GothamBlack,
		size = 12,
		color = COLORS.white,
		align = Enum.TextXAlignment.Center,
		zIndex = 7,
	})
	return fab, badge, badgeText
end

-- ============================================================
-- PANEL CALLS
-- ============================================================
local function callPanel(key)
	task.spawn(function()
		local waited = 0
		while waited < 5 do
			if _G.CoachAcademyPanels and _G.CoachAcademyPanels[key] then
				local ok, err = pcall(_G.CoachAcademyPanels[key])
				if not ok then
					warn("MainHUDController: failed to open panel '" .. key .. "': " .. tostring(err))
				end
				return
			end
			task.wait(0.1)
			waited += 0.1
		end
		warn("MainHUDController: panel '" .. key .. "' was not registered within 5s")
	end)
end

-- ============================================================
-- LIVE DATA
-- ============================================================
local function bindLiveData(player, status, fabBadge, fabBadgeText, setActive)
	local playerGui = player:WaitForChild("PlayerGui")

	-- money counter: counts up/down, pops "+$25" / "-$150"
	local shownMoney = nil
	local counter = Instance.new("NumberValue")
	counter:GetPropertyChangedSignal("Value"):Connect(function()
		status.money.Text = formatMoney(counter.Value)
	end)
	local function popDelta(delta)
		local pop = label({
			parent = status.panel,
			name = "MoneyDelta",
			text = (delta > 0 and "+" or "") .. formatMoney(delta),
			font = Enum.Font.GothamBlack,
			size = 16,
			color = delta > 0 and COLORS.goldBright or COLORS.crimsonBright,
			align = Enum.TextXAlignment.Right,
			uiSize = UDim2.new(0, 120, 0, 20),
			position = UDim2.new(1, -10, 0, 12),
			anchor = Vector2.new(1, 0),
			zIndex = 8,
		})
		pop.TextStrokeTransparency = 0.5
		tween(pop, 1.1, { Position = UDim2.new(1, -10, 0, -14), TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(1.15, function()
			pop:Destroy()
		end)
	end
	local function setMoney(amount, Sfx)
		if type(amount) ~= "number" then
			return
		end
		if shownMoney == nil then
			shownMoney = amount
			counter.Value = amount
			status.money.Text = formatMoney(amount)
			return
		end
		local delta = amount - shownMoney
		if delta == 0 then
			return
		end
		shownMoney = amount
		popDelta(delta)
		if delta > 0 and Sfx then
			Sfx.play("Cash")
		end
		tween(counter, math.clamp(math.abs(delta) / 400, 0.35, 1.2), { Value = amount }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	end

	local shownStars = nil
	local function setReputation(stars, tierName, Sfx)
		if tierName then
			status.tier.Text = string.upper(tierName)
		end
		if stars then
			stars = math.clamp(stars, 1, 5)
			status.stars.Text = starsRich(stars)
			local gem = GEMS[stars]
			status.gemGradient.Color = ColorSequence.new(gem.light, gem.dark)
			if shownStars and stars > shownStars then
				if Sfx then
					Sfx.play("LevelUp")
				end
				status.medalScale.Scale = 1.35
				tween(status.medalScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Elastic)
			end
			shownStars = stars
		end
	end

	task.spawn(function()
		local modules = ReplicatedStorage:WaitForChild("Modules", 10)
		local panels = modules and modules:WaitForChild("Panels", 10)
		local stateModule = panels and panels:WaitForChild("ClientState", 10)
		if not stateModule then
			return
		end
		local ok, ClientState = pcall(require, stateModule)
		if not ok or type(ClientState) ~= "table" or not ClientState.subscribe then
			return
		end
		local Sfx = nil
		local sfxModule = modules:FindFirstChild("Sfx")
		if sfxModule then
			local okSfx, result = pcall(require, sfxModule)
			Sfx = okSfx and result or nil
		end
		local MarketingConfig = nil
		local marketingModule = modules:FindFirstChild("MarketingConfig")
		if marketingModule then
			local okMarketing, result = pcall(require, marketingModule)
			MarketingConfig = okMarketing and result or nil
		end

		ClientState.subscribe("money", function(state)
			setMoney(state.money, Sfx)
		end)
		ClientState.subscribe("reputation", function(state)
			local rep = state.reputation or {}
			setReputation(rep.stars, rep.tierName, Sfx)
		end)

		-- phone badge: number of posts ready to publish
		local function refreshBadge()
			if not MarketingConfig or not MarketingConfig.Items then
				return
			end
			local state = ClientState.get()
			local now = ClientState.now()
			local ready = 0
			for id, item in pairs(MarketingConfig.Items) do
				if not item.locked then
					local last = (state.marketing.lastPostTimes or {})[id]
					if not last or now - last >= (item.cooldown or 0) then
						ready += 1
					end
				end
			end
			fabBadge.Visible = ready > 0 and state.loaded == true
			fabBadgeText.Text = tostring(ready)
		end
		ClientState.subscribe("marketing", refreshBadge)
		task.spawn(function()
			while playerGui.Parent do
				refreshBadge()
				task.wait(5)
			end
		end)

		local current = ClientState.get()
		if current.loaded then
			setMoney(current.money, Sfx)
			setReputation(current.reputation.stars, current.reputation.tierName, Sfx)
		end
		refreshBadge()

		-- highlight the dock button of the open panel
		local kitModule = panels:WaitForChild("PanelKit", 10)
		if kitModule then
			local okKit, PanelKit = pcall(require, kitModule)
			if okKit and PanelKit.Changed then
				PanelKit.Changed.Event:Connect(setActive)
			end
		end
	end)

	-- legacy MainHUD money label (old scripts still write to it)
	task.spawn(function()
		local oldHud = playerGui:WaitForChild("MainHUD", 10)
		local oldMoney = oldHud and oldHud:WaitForChild("MoneyLabel", 5)
		if oldMoney then
			local function sync()
				local amount = tonumber((oldMoney.Text:gsub("[^%d%-]", "")))
				if amount and shownMoney == nil then
					setMoney(amount)
				end
			end
			sync()
			oldMoney:GetPropertyChangedSignal("Text"):Connect(sync)
		end
	end)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local reputationUpdate = remotes and remotes:FindFirstChild("ReputationUpdate")
	if reputationUpdate then
		reputationUpdate.OnClientEvent:Connect(function(data)
			if data then
				setReputation(data.stars, data.tierName)
			end
		end)
	end
end

-- ============================================================
-- PUBLIC API
-- ============================================================
function MainHUDController.Init(screenGui, player)
	local status = buildStatusPanel(screenGui)
	local navDock, navButtons, setters = buildNavDock(screenGui)
	local phoneFab, fabBadge, fabBadgeText = buildPhoneFab(screenGui)

	for key, btn in pairs(navButtons) do
		btn.MouseButton1Click:Connect(function()
			callPanel(key)
		end)
	end
	phoneFab.MouseButton1Click:Connect(function()
		callPanel("Phone")
	end)

	local function setActive(key, isOpen)
		if setters[key] then
			if isOpen then
				for otherKey, setter in pairs(setters) do
					if otherKey ~= key then
						setter(false)
					end
				end
			end
			setters[key](isOpen)
		end
	end
	bindLiveData(player, status, fabBadge, fabBadgeText, setActive)

	return {
		StatusPanel = status.panel,
		NavDock = navDock,
		PhoneFab = phoneFab,
	}
end

return MainHUDController
