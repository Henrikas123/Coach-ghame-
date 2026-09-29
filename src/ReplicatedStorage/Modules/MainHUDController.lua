--[[
	MainHUDController
	Coach Academy - Premium Main HUD (Wave 3 -> Wave 4 polish pass)
	StatusPanel (pinigai/reputacija), NavDock (Profilis/Akademija/Personalas/
	Skautai/Remejai/Turnyrai), PhoneFab. Sukurta pagal GLOBAL DEVELOPMENT
	STANDARD (premium quality: apvalinti kampai, sesely, hover/press animacijos,
	nuosekli spalvu palete, tvarkinga tipografija).
]]

local TweenService = game:GetService("TweenService")

local MainHUDController = {}

-- ============================================================
-- SPALVU PALETE
-- ============================================================
local COLORS = {
	bg          = Color3.fromRGB(22, 20, 24),
	bgCard      = Color3.fromRGB(30, 27, 32),
	bgCardLight = Color3.fromRGB(38, 34, 40),
	border      = Color3.fromRGB(64, 56, 40),

	gold        = Color3.fromRGB(212, 175, 55),
	goldBright  = Color3.fromRGB(236, 200, 92),

	steel       = Color3.fromRGB(70, 108, 148),
	steelBright = Color3.fromRGB(96, 142, 188),

	crimson       = Color3.fromRGB(178, 40, 54),
	crimsonBright = Color3.fromRGB(214, 62, 76),

	textPrimary   = Color3.fromRGB(240, 235, 226),
	textSecondary = Color3.fromRGB(168, 160, 150),
	textOnGold    = Color3.fromRGB(32, 24, 8),

	shadow = Color3.fromRGB(0, 0, 0),
}

local REPUTATION_TIER_LT = {
	["Local Coach"]       = "Local Coach",
	["Rising Coach"]      = "Rising Coach",
	["Respected Coach"]   = "Respected Coach",
	["Elite Coach"]       = "Elite Coach",
	["World-Class Coach"] = "World-Class Coach",
}

local NAV_ITEMS = {
	{ key = "Profile",    label = "Profile",    tier = "primary",   icon = "\240\159\145\164" },
	{ key = "Academy",    label = "Academy",    tier = "primary",   icon = "\240\159\143\155" },
	{ key = "Staff",      label = "Staff",      tier = "secondary", icon = "\240\159\145\165" },
	{ key = "Scout",      label = "Scouting",   tier = "secondary", icon = "\240\159\148\142" },
	{ key = "Sponsor",    label = "Sponsors",   tier = "secondary", icon = "\240\159\164\157" },
	{ key = "Tournament", label = "Tournaments", tier = "highlight", icon = "\240\159\143\134" },
}

local TIER_STYLE = {
	primary   = { base = COLORS.gold,    hover = COLORS.goldBright,    text = COLORS.textOnGold  },
	secondary = { base = COLORS.steel,   hover = COLORS.steelBright,   text = COLORS.textPrimary },
	highlight = { base = COLORS.crimson, hover = COLORS.crimsonBright, text = COLORS.textPrimary },
}

-- ============================================================
-- UI PAGALBINES FUNKCIJOS
-- ============================================================
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 12)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addShadow(target, transparency, offsetY, radius)
	local shadow = Instance.new("Frame")
	shadow.Name = "CardShadow"
	shadow.BackgroundColor3 = COLORS.shadow
	shadow.BackgroundTransparency = transparency or 0.55
	shadow.BorderSizePixel = 0
	shadow.AnchorPoint = target.AnchorPoint
	shadow.Size = target.Size
	shadow.Position = target.Position + UDim2.new(0, 0, 0, offsetY or 4)
	shadow.ZIndex = target.ZIndex - 1
	shadow.Parent = target.Parent
	corner(shadow, radius or UDim.new(0, 14))

	target:GetPropertyChangedSignal("Size"):Connect(function()
		shadow.Size = target.Size
	end)
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		shadow.Size = UDim2.new(0, target.AbsoluteSize.X, 0, target.AbsoluteSize.Y)
	end)

	return shadow
end

local function makeLabel(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.Gotham
	l.TextColor3 = props.color or COLORS.textPrimary
	l.TextSize = props.size or 16
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Text = props.text or ""
	l.Size = props.uiSize or UDim2.new(1, 0, 1, 0)
	l.Position = props.position or UDim2.new(0, 0, 0, 0)
	l.AnchorPoint = props.anchor or Vector2.new(0, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.ZIndex = props.zIndex or 2
	l.Name = props.name or "Label"
	l.Parent = props.parent
	return l
end

local function attachPressFeedback(button)
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = button
	button.MouseButton1Down:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad), {Scale = 0.94}):Play()
	end)
	local function release()
		TweenService:Create(uiScale, TweenInfo.new(0.14, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

local function styleButtonHover(button, style)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = style.hover}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.16), {BackgroundColor3 = style.base}):Play()
	end)
end

-- ============================================================
-- STATUS PANEL (virsus kaire - pinigai + reputacija)
-- ============================================================
local function buildStatusPanel(screenGui)
	local panel = Instance.new("Frame")
	panel.Name = "StatusPanel"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(0, 16, 0, 16)
	panel.Size = UDim2.new(0, 250, 0, 76)
	-- UIGradient daugina savo spalvas is BackgroundColor3 -> baltas fonas, kad matytusi bgCardLight->bgCard
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BorderSizePixel = 0
	panel.ZIndex = 2
	panel.Parent = screenGui
	corner(panel, UDim.new(0, 14))
	stroke(panel, COLORS.border, 1, 0.25)
	addShadow(panel, 0.6, 5)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.bgCardLight),
		ColorSequenceKeypoint.new(1, COLORS.bgCard),
	})
	grad.Rotation = 90
	grad.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel

	local moneyRow = Instance.new("Frame")
	moneyRow.Name = "MoneyRow"
	moneyRow.BackgroundTransparency = 1
	moneyRow.Size = UDim2.new(1, 0, 0, 26)
	moneyRow.Position = UDim2.new(0, 0, 0, 0)
	moneyRow.ZIndex = 3
	moneyRow.Parent = panel

	makeLabel({
		parent = moneyRow, name = "MoneyIcon", text = "\240\159\146\176",
		size = 18, uiSize = UDim2.new(0, 24, 1, 0), align = Enum.TextXAlignment.Left, zIndex = 3,
	})
	local moneyLabel = makeLabel({
		parent = moneyRow, name = "MoneyValue", text = "0",
		font = Enum.Font.GothamBold, color = COLORS.goldBright, size = 18,
		uiSize = UDim2.new(1, -28, 1, 0), position = UDim2.new(0, 28, 0, 0), zIndex = 3,
	})

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BackgroundColor3 = COLORS.border
	divider.BackgroundTransparency = 0.4
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 0, 30)
	divider.ZIndex = 3
	divider.Parent = panel

	local repRow = Instance.new("Frame")
	repRow.Name = "ReputationRow"
	repRow.BackgroundTransparency = 1
	repRow.Size = UDim2.new(1, 0, 0, 30)
	repRow.Position = UDim2.new(0, 0, 0, 38)
	repRow.ZIndex = 3
	repRow.Parent = panel

	local repLabel = makeLabel({
		parent = repRow, name = "ReputationValue", text = "Local Coach",
		font = Enum.Font.Gotham, color = COLORS.textSecondary, size = 13,
		uiSize = UDim2.new(1, 0, 0, 16), position = UDim2.new(0, 0, 0, 0), zIndex = 3,
	})
	local starsLabel = makeLabel({
		parent = repRow, name = "ReputationStars", text = "\226\152\134\226\152\134\226\152\134\226\152\134\226\152\134",
		font = Enum.Font.GothamBold, color = COLORS.gold, size = 14,
		uiSize = UDim2.new(1, 0, 0, 14), position = UDim2.new(0, 0, 0, 16), zIndex = 3,
	})

	return panel, moneyLabel, repLabel, starsLabel
end

-- ============================================================
-- NAV DOCK MYGTUKAS
-- ============================================================
local function createNavButton(parent, item, layoutOrder)
	local style = TIER_STYLE[item.tier]
	local btn = Instance.new("TextButton")
	btn.Name = item.key .. "Button"
	btn.LayoutOrder = layoutOrder
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = style.base
	btn.Size = UDim2.new(0, 96, 1, -12)
	btn.Text = ""
	btn.ZIndex = 3
	btn.Parent = parent
	corner(btn, UDim.new(0, 12))
	stroke(btn, style.hover, 1, 0.55)
	attachPressFeedback(btn)
	styleButtonHover(btn, style)

	makeLabel({
		parent = btn, name = "Icon", text = item.icon, size = 20,
		uiSize = UDim2.new(1, 0, 0, 22), position = UDim2.new(0, 0, 0, 6),
		align = Enum.TextXAlignment.Center, zIndex = 4,
	})
	makeLabel({
		parent = btn, name = "Label", text = item.label,
		font = Enum.Font.GothamBold, color = style.text, size = 12,
		uiSize = UDim2.new(1, 0, 0, 16), position = UDim2.new(0, 0, 1, -18),
		align = Enum.TextXAlignment.Center, zIndex = 4,
	})

	return btn
end

local function buildNavDock(screenGui)
	local dock = Instance.new("Frame")
	dock.Name = "NavDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -16)
	dock.Size = UDim2.new(0, 0, 0, 64)
	dock.AutomaticSize = Enum.AutomaticSize.X
	dock.BackgroundColor3 = Color3.new(1, 1, 1) -- spalva ateina is UIGradient (zr. StatusPanel)
	dock.BorderSizePixel = 0
	dock.ZIndex = 2
	dock.Parent = screenGui
	corner(dock, UDim.new(0, 16))
	stroke(dock, COLORS.border, 1, 0.3)
	addShadow(dock, 0.6, 5)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.bgCardLight),
		ColorSequenceKeypoint.new(1, COLORS.bgCard),
	})
	grad.Rotation = 90
	grad.Parent = dock

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = dock

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = dock

	local buttons = {}
	for idx, item in ipairs(NAV_ITEMS) do
		buttons[item.key] = createNavButton(dock, item, idx)
	end

	return dock, buttons
end

-- ============================================================
-- TELEFONO FAB (apacia desine)
-- ============================================================
local function buildPhoneFab(screenGui)
	local fab = Instance.new("TextButton")
	fab.Name = "PhoneFab"
	fab.AnchorPoint = Vector2.new(1, 1)
	fab.Position = UDim2.new(1, -20, 1, -20)
	fab.Size = UDim2.new(0, 60, 0, 60)
	fab.BackgroundColor3 = COLORS.gold
	fab.AutoButtonColor = false
	fab.Text = ""
	fab.ZIndex = 2
	fab.Parent = screenGui
	corner(fab, UDim.new(1, 0))
	stroke(fab, COLORS.goldBright, 1.5, 0.2)
	addShadow(fab, 0.55, 5, UDim.new(1, 0)) -- apvalus seselis apvaliam mygtukui
	attachPressFeedback(fab)
	styleButtonHover(fab, TIER_STYLE.primary)

	makeLabel({
		parent = fab, name = "Icon", text = "\240\159\147\177", size = 26,
		align = Enum.TextXAlignment.Center, zIndex = 4,
	})

	return fab
end

-- ============================================================
-- PANEL ISSAUKIMO PAGALBININKAS
-- ============================================================
local function callPanel(key)
	task.spawn(function()
		local waited = 0
		while waited < 5 do
			if _G.CoachAcademyPanels and _G.CoachAcademyPanels[key] then
				local ok, err = pcall(_G.CoachAcademyPanels[key])
				if not ok then
					warn("MainHUDController: klaida atidarant panele '" .. key .. "': " .. tostring(err))
				end
				return
			end
			task.wait(0.1)
			waited += 0.1
		end
		warn("MainHUDController: panele '" .. key .. "' neprisiregistravo per 5s (_G.CoachAcademyPanels." .. key .. ")")
	end)
end

-- ============================================================
-- REPUTACIJOS / PINIGU DUOMENU SINCHRONIZAVIMAS
-- ============================================================
local function starString(stars)
	stars = math.clamp(stars or 1, 0, 5)
	return string.rep("\226\152\133", stars) .. string.rep("\226\152\134", 5 - stars)
end

-- Sena ReputationLabel.Text formatas (is ReputationUI.lua):
--   starString(stars) .. " " .. tierName .. [" (%d/%d)"]
-- Cia ji issiurbiama i (starsCount, tierNameOnly), kad galetume
-- atvaizduoti zvaigzdes atskirai ir isversti tik tikrini pavadinima.
local function parseOldReputationText(text)
	local filled = 0
	local i = 1
	local len = #text
	while i <= len do
		local three = text:sub(i, i + 2)
		if three == "\226\152\133" then -- filled star
			filled += 1
			i += 3
		elseif three == "\226\152\134" then -- empty star
			i += 3
		else
			break
		end
	end
	if i <= 1 then
		return nil, nil
	end
	local rest = text:sub(i)
	rest = rest:gsub("^%s+", "")
	local tierNameOnly = rest:match("^(.-)%s*%(") or rest
	tierNameOnly = tierNameOnly:gsub("%s+$", "")
	if tierNameOnly == "" then
		return filled, nil
	end
	return filled, tierNameOnly
end

local function bindLiveData(player, moneyLabel, repLabel, starsLabel)
	local playerGui = player:WaitForChild("PlayerGui")

	task.spawn(function()
		local oldHud = playerGui:WaitForChild("MainHUD", 10)
		if not oldHud then
			warn("MainHUDController: senas MainHUD nerastas per 10s")
			return
		end
		local oldMoney = oldHud:WaitForChild("MoneyLabel", 5)
		if oldMoney then
			local function sync()
				moneyLabel.Text = oldMoney.Text
			end
			sync()
			oldMoney:GetPropertyChangedSignal("Text"):Connect(sync)
		else
			warn("MainHUDController: MoneyLabel nerastas senoje MainHUD")
		end

		local oldRep = oldHud:FindFirstChild("ReputationLabel")
		if oldRep and oldRep.Text ~= "" then
			local stars, tierName = parseOldReputationText(oldRep.Text)
			if tierName then
				repLabel.Text = REPUTATION_TIER_LT[tierName] or tierName
			end
			if stars then
				starsLabel.Text = starString(stars)
			end
		end
	end)

	-- HUD paneliu ClientState (jei idiegtas): patikimas pinigu/reputacijos saltinis, nepriklausantis nuo
	-- to, kuris LocalScript pirmas "pagavo" pradinius serverio pranesimus (RemoteEvent eile).
	task.spawn(function()
		local modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
		local panels = modules and modules:WaitForChild("Panels", 10)
		local stateModule = panels and panels:WaitForChild("ClientState", 10)
		if not stateModule then
			return
		end
		local ok, ClientState = pcall(require, stateModule)
		if not ok or type(ClientState) ~= "table" or not ClientState.subscribe then
			return
		end
		local function renderMoney(state)
			if type(state.money) == "number" then
				moneyLabel.Text = "$ " .. tostring(state.money)
			end
		end
		local function renderReputation(state)
			local rep = state.reputation
			if rep and rep.tierName then
				repLabel.Text = REPUTATION_TIER_LT[rep.tierName] or rep.tierName
			end
			if rep and rep.stars then
				starsLabel.Text = starString(rep.stars)
			end
		end
		ClientState.subscribe("money", renderMoney)
		ClientState.subscribe("reputation", renderReputation)
		local current = ClientState.get()
		if current.loaded then
			renderMoney(current)
			renderReputation(current)
		end
	end)

	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local reputationUpdate = remotes and remotes:FindFirstChild("ReputationUpdate")
	if reputationUpdate then
		reputationUpdate.OnClientEvent:Connect(function(data)
			if not data then return end
			if data.tierName then
				repLabel.Text = REPUTATION_TIER_LT[data.tierName] or data.tierName
			end
			if data.stars then
				starsLabel.Text = starString(data.stars)
			end
		end)
	else
		warn("MainHUDController: ReputationUpdate RemoteEvent nerastas")
	end
end

-- ============================================================
-- VIESA API
-- ============================================================
function MainHUDController.Init(screenGui, player)
	local statusPanel, moneyLabel, repLabel, starsLabel = buildStatusPanel(screenGui)
	local navDock, navButtons = buildNavDock(screenGui)
	local phoneFab = buildPhoneFab(screenGui)

	for key, btn in pairs(navButtons) do
		btn.MouseButton1Click:Connect(function()
			callPanel(key)
		end)
	end
	phoneFab.MouseButton1Click:Connect(function()
		callPanel("Phone")
	end)

	bindLiveData(player, moneyLabel, repLabel, starsLabel)

	return {
		StatusPanel = statusPanel,
		NavDock = navDock,
		PhoneFab = phoneFab,
	}
end

return MainHUDController
