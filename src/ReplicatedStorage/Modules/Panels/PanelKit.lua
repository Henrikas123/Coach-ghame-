--[[
	PanelKit
	Coach Academy - bendras premium UI rinkinys visoms HUD panelems
	(Profilis / Akademija / Personalas / Skautai / Remejai / Turnyrai / Telefonas).

	Vizualine kalba sutampa su MainHUDController: ta pati spalvu palete,
	Gotham/GothamBold, UICorner 10-14px, UIStroke borderiai, minksti seseliai,
	hover/press tween animacijos.

	Viesa API:
	  PanelKit.Colors / PanelKit.tween / PanelKit.create
	  PanelKit.label / button / iconButton / card / tabs / progressBar / statTile /
	  badge / sectionHeader / scroll / avatar / emptyState / textBox / divider
	  PanelKit.createPanel(def)        -- modalinis arba "phone" stiliaus apvalkalas
	  PanelKit.register(key, factory)  -- tingus (lazy) paneles sukurimas
	  PanelKit.toggle(key) / open(key) / close(key)
	  PanelKit.format* pagalbines funkcijos
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelKit = {}

-- Garsai (SoundConfig tusti slotai tiesiog praleidziami)
local Sfx = nil
task.spawn(function()
	local modules = ReplicatedStorage:WaitForChild("Modules", 10)
	local sfxModule = modules and modules:WaitForChild("Sfx", 10)
	if sfxModule then
		local ok, result = pcall(require, sfxModule)
		if ok then
			Sfx = result
		end
	end
end)
local function playSfx(name)
	if Sfx then
		Sfx.play(name)
	end
end
PanelKit.playSfx = playSfx

-- Panelių atidarymo/uždarymo signalas (HUD pažymi aktyvų mygtuką): Changed:Fire(key, isOpen)
PanelKit.Changed = Instance.new("BindableEvent")

-- ============================================================
-- SPALVU PALETE (identiska MainHUDController)
-- ============================================================
local C = {
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
PanelKit.Colors = C

local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
PanelKit.Font = FONT
PanelKit.FontBold = FONT_BOLD

-- Mygtuku variantai: base -> hover spalva, teksto spalva, stroke spalva
local BUTTON_VARIANTS = {
	gold    = { base = C.gold,        hover = C.goldBright,    text = C.textOnGold,  stroke = C.goldBright },
	steel   = { base = C.steel,       hover = C.steelBright,   text = C.textPrimary, stroke = C.steelBright },
	crimson = { base = C.crimson,     hover = C.crimsonBright, text = C.textPrimary, stroke = C.crimsonBright },
	ghost   = { base = C.bgCardLight, hover = C.bgCardLight,   text = C.textPrimary, stroke = C.border, hoverStroke = C.gold, idleStrokeTransparency = 0 },
}
PanelKit.ButtonVariants = BUTTON_VARIANTS

-- Paneliu akcentai (sutampa su NavDock mygtuku tier spalvomis)
local ACCENTS = {
	gold    = { base = C.gold,    bright = C.goldBright,    text = C.textOnGold },
	steel   = { base = C.steel,   bright = C.steelBright,   text = C.textPrimary },
	crimson = { base = C.crimson, bright = C.crimsonBright, text = C.textPrimary },
}
PanelKit.Accents = ACCENTS

-- ============================================================
-- BAZINES PAGALBINES FUNKCIJOS
-- ============================================================
function PanelKit.tween(instance, duration, props, style, direction, repeatCount, reverses)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, repeatCount or 0, reverses == true),
		props
	)
	tween:Play()
	return tween
end
local tween = PanelKit.tween

-- Lieciamuose ekranuose MouseEnter/MouseLeave nepatikimi -- hover efektu nerodome
local function isTouchOnly()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end
PanelKit.isTouchOnly = isTouchOnly

-- create("Frame", { Size = ..., Parent = ... }) -- Parent priskiriamas paskutinis
function PanelKit.create(className, props)
	local instance = Instance.new(className)
	local parent = nil
	if instance:IsA("GuiObject") then
		instance.BorderSizePixel = 0
	end
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end
local create = PanelKit.create

function PanelKit.corner(parent, radius)
	return create("UICorner", {
		CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 12),
		Parent = parent,
	})
end
local corner = PanelKit.corner

function PanelKit.stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color or C.border,
		Thickness = thickness or 1,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end
local stroke = PanelKit.stroke

function PanelKit.padding(parent, top, right, bottom, left)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		PaddingLeft = UDim.new(0, left or right or top or 0),
		Parent = parent,
	})
end
local padding = PanelKit.padding

function PanelKit.list(parent, spacing, direction, hAlign, vAlign)
	return create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, spacing or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end
local list = PanelKit.list

-- Pastaba: CellSize offset'ai turi 1px atsarga (float apvalinimas neturi "numesti" paskutinio stulpelio),
-- todel tinklelis centruojamas -- atsarga pasiskirsto per abu krastus ir lygiavimas islieka.
function PanelKit.grid(parent, cellSize, cellPadding)
	return create("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = cellPadding or UDim2.new(0, 10, 0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

-- Spalvu gradientas (virsus -> apacia). SVARBU: Roblox UIGradient DAUGINA savo spalvas is
-- BackgroundColor3, todel fona nustatome baltu -- tada matomos butent topColor/bottomColor spalvos
-- (kitaip bgCard x bgCardLight duoda beveik juoda).
function PanelKit.gradient(parent, topColor, bottomColor, rotation)
	if parent:IsA("GuiObject") then
		parent.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	return create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, topColor),
			ColorSequenceKeypoint.new(1, bottomColor),
		}),
		Rotation = rotation or 90,
		Parent = parent,
	})
end
local gradient = PanelKit.gradient

-- Plona auksine linija, issilyginanti i sonus
function PanelKit.divider(props)
	local line = create("Frame", {
		Name = props.name or "Divider",
		BackgroundColor3 = props.color or C.gold,
		BackgroundTransparency = 0,
		Size = props.size or UDim2.new(1, 0, 0, 1),
		Position = props.position or UDim2.new(),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, props.strength or 0.55),
			NumberSequenceKeypoint.new(0.8, props.strength or 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = line,
	})
	return line
end

-- ============================================================
-- TEKSTAS
-- ============================================================
function PanelKit.label(props)
	local textSize = props.textSize or 14
	local label = create("TextLabel", {
		Name = props.name or "Label",
		BackgroundTransparency = 1,
		Font = props.bold and FONT_BOLD or (props.font or FONT),
		TextSize = textSize,
		TextColor3 = props.color or C.textPrimary,
		TextTransparency = props.transparency or 0,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = props.alignY or Enum.TextYAlignment.Center,
		TextWrapped = props.wrap == true,
		TextTruncate = props.wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
		RichText = props.rich == true,
		Text = props.text or "",
		Size = props.size or UDim2.new(1, 0, 0, textSize + 6),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		AutomaticSize = props.autoSize or Enum.AutomaticSize.None,
		LayoutOrder = props.order or 0,
		ZIndex = props.zIndex or 1,
		Parent = props.parent,
	})
	return label
end
local label = PanelKit.label

-- ============================================================
-- MYGTUKAI
-- ============================================================
--[[
	PanelKit.button({
		parent, text, icon, variant = "gold"|"steel"|"crimson"|"ghost",
		size, position, anchor, order, textSize, radius, onClick,
	}) -> handle { Instance, Label, SetEnabled(bool), SetText(text), SetVariant(name) }
]]
function PanelKit.button(props)
	local variantName = props.variant or "gold"
	local variant = BUTTON_VARIANTS[variantName]
	local enabled = props.enabled ~= false
	local hovering = false

	local btn = create("TextButton", {
		Name = props.name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = variant.base,
		Text = "",
		Size = props.size or UDim2.new(0, 140, 0, 40),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		LayoutOrder = props.order or 0,
		ZIndex = props.zIndex or 1,
		Parent = props.parent,
	})
	corner(btn, props.radius or 10)
	local btnStroke = stroke(btn, variant.stroke, 1, 0.55)
	local sheen = create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 215, 215)),
		}),
		Rotation = 90,
		Parent = btn,
	})
	local scale = create("UIScale", { Scale = 1, Parent = btn })

	local currentText = props.text or ""
	local function composeText(text)
		if enabled then
			if props.icon and props.icon ~= "" then
				return props.icon .. "  " .. text
			end
			return text
		end
		-- isjungtas mygtukas rodo busena/prieastą; laikmacius pazymim laikrodziu
		if string.find(text, "%d+:%d%d") then
			return "⏱  " .. text
		end
		return text
	end

	local textLabel = label({
		parent = btn,
		name = "Text",
		text = composeText(currentText),
		bold = true,
		textSize = props.textSize or 14,
		color = variant.text,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -12, 1, 0),
		position = UDim2.new(0, 6, 0, 0),
	})

	local function paint(instant)
		local bgColor, bgTransparency, textColor, textTransparency, strokeColor, strokeTransparency
		if not enabled then
			-- "busenos" isvaizda: nepaspaudziamas, bet tekstas (laikmatis, priezastis) gerai matomas
			bgColor, bgTransparency = C.bgCard, 0
			textColor, textTransparency = C.textSecondary, 0
			strokeColor, strokeTransparency = C.border, 0.3
		elseif hovering then
			bgColor, bgTransparency = variant.hover, 0
			textColor, textTransparency = variant.text, 0
			strokeColor = variant.hoverStroke or variant.stroke
			strokeTransparency = variant.hoverStroke and 0.1 or 0.35
		else
			bgColor, bgTransparency = variant.base, 0
			textColor, textTransparency = variant.text, 0
			strokeColor, strokeTransparency = variant.stroke, variant.idleStrokeTransparency or 0.55
		end
		sheen.Enabled = enabled
		textLabel.Text = composeText(currentText)
		if instant then
			btn.BackgroundColor3 = bgColor
			btn.BackgroundTransparency = bgTransparency
			textLabel.TextColor3 = textColor
			textLabel.TextTransparency = textTransparency
			btnStroke.Color = strokeColor
			btnStroke.Transparency = strokeTransparency
		else
			tween(btn, 0.14, { BackgroundColor3 = bgColor, BackgroundTransparency = bgTransparency })
			tween(textLabel, 0.14, { TextColor3 = textColor, TextTransparency = textTransparency })
			tween(btnStroke, 0.14, { Color = strokeColor, Transparency = strokeTransparency })
		end
	end

	btn.MouseEnter:Connect(function()
		if isTouchOnly() then
			return
		end
		hovering = true
		paint(false)
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		paint(false)
		tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	btn.MouseButton1Down:Connect(function()
		if enabled then
			tween(scale, 0.06, { Scale = 0.94 })
			-- jei paspaudimas virsta slinkimu (ScrollingFrame), MouseButton1Up gali neateiti
			task.delay(0.4, function()
				if scale.Scale < 1 then
					tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end)
		end
	end)
	btn.MouseButton1Up:Connect(function()
		tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	-- Apsauga nuo dvigubo paspaudimo: kol serveris atsako, antras paspaudimas ignoruojamas
	local lastActivated = -math.huge
	btn.Activated:Connect(function()
		local now = os.clock()
		if now - lastActivated < (props.debounce or 0.5) then
			return
		end
		lastActivated = now
		playSfx(enabled and "Click" or "Error")
		if enabled and props.onClick then
			props.onClick()
		end
	end)

	paint(true)

	local handle = { Instance = btn, Label = textLabel }
	function handle.SetEnabled(value)
		if enabled == value then
			return
		end
		enabled = value
		btn.Active = value
		paint(false)
	end
	function handle.SetText(text)
		currentText = text
		textLabel.Text = composeText(text)
	end
	function handle.SetVariant(name)
		if BUTTON_VARIANTS[name] and name ~= variantName then
			variantName = name
			variant = BUTTON_VARIANTS[name]
			paint(false)
		end
	end
	function handle.IsEnabled()
		return enabled
	end
	return handle
end

-- Apvalus ikonos mygtukas (pvz. X uzdarymui). Hover -> crimson fonas.
function PanelKit.iconButton(props)
	local size = props.size or 36
	local btn = create("TextButton", {
		Name = props.name or "IconButton",
		AutoButtonColor = false,
		BackgroundColor3 = props.color or C.bgCardLight,
		Text = "",
		Size = UDim2.new(0, size, 0, size),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		LayoutOrder = props.order or 0,
		ZIndex = props.zIndex or 1,
		Parent = props.parent,
	})
	corner(btn, props.radius or 10)
	local btnStroke = stroke(btn, C.border, 1, 0.3)
	local scale = create("UIScale", { Scale = 1, Parent = btn })
	local glyph = label({
		parent = btn,
		name = "Glyph",
		text = props.text or "✕",
		bold = true,
		textSize = props.textSize or 16,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})

	local hoverColor = props.hoverColor or C.crimson
	local baseColor = props.color or C.bgCardLight
	btn.MouseEnter:Connect(function()
		if isTouchOnly() then
			return
		end
		tween(btn, 0.12, { BackgroundColor3 = hoverColor })
		tween(glyph, 0.12, { TextColor3 = C.textPrimary })
		tween(btnStroke, 0.12, { Color = props.hoverStrokeColor or C.crimsonBright, Transparency = 0.2 })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.16, { BackgroundColor3 = baseColor })
		tween(glyph, 0.16, { TextColor3 = C.textSecondary })
		tween(btnStroke, 0.16, { Color = C.border, Transparency = 0.3 })
		tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	btn.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.9 })
	end)
	btn.MouseButton1Up:Connect(function()
		tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	btn.Activated:Connect(function()
		if props.onClick then
			props.onClick()
		end
	end)
	return btn, glyph
end

-- ============================================================
-- KORTELES / BLOKAI
-- ============================================================
-- Kortele: bgCard + border stroke + subtilus gradientas
function PanelKit.card(props)
	local frame = create("Frame", {
		Name = props.name or "Card",
		BackgroundColor3 = props.color or C.bgCard,
		BackgroundTransparency = props.transparency or 0,
		Size = props.size or UDim2.new(1, 0, 0, 80),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		AutomaticSize = props.autoSize or Enum.AutomaticSize.None,
		LayoutOrder = props.order or 0,
		ClipsDescendants = props.clip == true,
		Parent = props.parent,
	})
	corner(frame, props.radius or 12)
	local cardStroke = stroke(frame, props.strokeColor or C.border, props.strokeThickness or 1, props.strokeTransparency or 0.45)
	if props.gradient ~= false then
		gradient(frame, props.gradientTop or C.bgCardLight, props.gradientBottom or (props.color or C.bgCard), 90)
	end
	if props.padding then
		padding(frame, props.padding, props.padding, props.padding, props.padding)
	end
	return frame, cardStroke
end
local card = PanelKit.card

-- Sekcijos antraste: auksinis briaunelis + pavadinimas + (nebutinas) desinysis tekstas
function PanelKit.sectionHeader(props)
	local row = create("Frame", {
		Name = props.name or "SectionHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, props.height or 22),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	local accentBar = create("Frame", {
		Name = "Accent",
		BackgroundColor3 = props.accent or C.gold,
		Size = UDim2.new(0, 3, 0, 14),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Parent = row,
	})
	corner(accentBar, UDim.new(1, 0))
	label({
		parent = row,
		name = "Title",
		text = string.upper(props.title or ""),
		font = Enum.Font.Oswald,
		textSize = (props.textSize or 15) + 2,
		color = C.textPrimary,
		size = UDim2.new(1, -12, 1, 0),
		position = UDim2.new(0, 12, 0, 0),
	})
	local hint = nil
	if props.hint ~= nil then
		hint = label({
			parent = row,
			name = "Hint",
			text = props.hint,
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0.5, 0, 1, 0),
			position = UDim2.new(1, 0, 0, 0),
			anchor = Vector2.new(1, 0),
		})
	end
	return row, hint
end

-- Piliule (badge). tone: spalva; solid=true -> pilnas fonas
function PanelKit.badge(props)
	local tone = props.color or C.gold
	local solid = props.solid == true
	local pill = create("Frame", {
		Name = props.name or "Badge",
		BackgroundColor3 = tone,
		BackgroundTransparency = solid and 0 or 0.82,
		Size = UDim2.new(0, 0, 0, props.height or 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	corner(pill, UDim.new(1, 0))
	stroke(pill, tone, 1, solid and 0.6 or 0.35)
	padding(pill, 0, 9, 0, 9)
	local text = label({
		parent = pill,
		name = "Text",
		text = props.text or "",
		bold = true,
		textSize = props.textSize or 12,
		color = props.textColor or (solid and C.textOnGold or tone),
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(0, 0, 1, 0),
		autoSize = Enum.AutomaticSize.X,
	})
	text.TextTruncate = Enum.TextTruncate.None
	return pill, text
end

-- Progreso juosta su gradientu. handle.Set(0..1, instant), handle.SetColor(c1, c2)
function PanelKit.progressBar(props)
	local height = props.height or 8
	local track = create("Frame", {
		Name = props.name or "ProgressBar",
		BackgroundColor3 = props.trackColor or C.bg,
		Size = props.size or UDim2.new(1, 0, 0, height),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		LayoutOrder = props.order or 0,
		ClipsDescendants = true,
		Parent = props.parent,
	})
	corner(track, UDim.new(1, 0))
	stroke(track, C.border, 1, 0.6)
	local fill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, 0, 1, 0),
		Parent = track,
	})
	corner(fill, UDim.new(1, 0))
	local fillGradient = gradient(fill, props.color or C.gold, props.color2 or C.goldBright, 0)

	local handle = { Instance = track, Fill = fill }
	local current = -1
	function handle.Set(value, instant)
		value = math.clamp(value or 0, 0, 1)
		if value == current then
			return
		end
		current = value
		fill.Visible = value > 0
		if instant then
			fill.Size = UDim2.new(value, 0, 1, 0)
		else
			tween(fill, 0.35, { Size = UDim2.new(value, 0, 1, 0) }, Enum.EasingStyle.Quint)
		end
	end
	function handle.SetColor(c1, c2)
		fillGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(1, c2 or c1),
		})
	end
	handle.Set(props.value or 0, true)
	return handle
end

-- Statistikos plytele: ikona + mazas pavadinimas + didele reiksme + (nebutinas) paaiskinimas
function PanelKit.statTile(props)
	local tile = card({
		parent = props.parent,
		name = props.name or "StatTile",
		size = props.size or UDim2.new(1, 0, 0, 78),
		order = props.order,
		color = C.bgCardLight,
		gradientTop = C.bgCardLight,
		gradientBottom = C.bgCard,
		strokeTransparency = 0.5,
	})
	padding(tile, 10, 12, 10, 12)
	label({
		parent = tile,
		name = "Icon",
		text = props.icon or "",
		textSize = 14,
		size = UDim2.new(0, 20, 0, 16),
	})
	label({
		parent = tile,
		name = "Caption",
		text = props.label or "",
		textSize = 13,
		color = C.textSecondary,
		size = UDim2.new(1, -22, 0, 16),
		position = UDim2.new(0, 22, 0, 0),
	})
	local value = label({
		parent = tile,
		name = "Value",
		text = props.value or "-",
		bold = true,
		textSize = props.valueSize or 22,
		color = props.accent or C.textPrimary,
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.new(0, 0, 0, 18),
	})
	local sub = label({
		parent = tile,
		name = "Sub",
		text = props.sub or "",
		textSize = 12,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -16),
	})
	local handle = { Instance = tile, Value = value, Sub = sub }
	function handle.Set(valueText, subText, color)
		value.Text = valueText
		if subText ~= nil then
			sub.Text = subText
		end
		if color then
			value.TextColor3 = color
		end
	end
	return handle
end

-- Apvalus avataras su inicialais (arba ImageLabel, jei duotas image)
function PanelKit.initials(name)
	local parts = {}
	for word in string.gmatch(name or "?", "[^%s%.]+") do
		table.insert(parts, word)
	end
	local first = parts[1] and utf8.char(utf8.codepoint(parts[1], 1)) or "?"
	local second = parts[2] and utf8.char(utf8.codepoint(parts[2], 1)) or ""
	return string.upper(first .. second)
end

function PanelKit.avatar(props)
	local size = props.size or 40
	local frame = create("Frame", {
		Name = props.name or "Avatar",
		BackgroundColor3 = props.color or C.bgCardLight,
		Size = UDim2.new(0, size, 0, size),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	corner(frame, UDim.new(1, 0))
	local ring = stroke(frame, props.ringColor or C.gold, props.ringThickness or 2, props.ringTransparency or 0.1)
	gradient(frame, C.bgCardLight, C.bg, 135)
	local text = label({
		parent = frame,
		name = "Initials",
		text = PanelKit.initials(props.text),
		bold = true,
		textSize = math.floor(size * 0.38),
		color = props.textColor or C.goldBright,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
	})
	return frame, text, ring
end

-- Tuscios busenos blokas
function PanelKit.emptyState(props)
	local frame = create("Frame", {
		Name = props.name or "EmptyState",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.new(1, 0, 0, 150),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	label({
		parent = frame,
		name = "Icon",
		text = props.icon or "✨",
		textSize = 34,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.new(0, 0, 0, 14),
	})
	label({
		parent = frame,
		name = "Title",
		text = props.title or "",
		bold = true,
		textSize = 16,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.new(0, 0, 0, 62),
	})
	label({
		parent = frame,
		name = "Text",
		text = props.text or "",
		textSize = 13,
		color = C.textSecondary,
		align = Enum.TextXAlignment.Center,
		alignY = Enum.TextYAlignment.Top,
		wrap = true,
		size = UDim2.new(1, -40, 0, 40),
		position = UDim2.new(0, 20, 0, 88),
	})
	return frame
end

-- Slenkamas konteineris su vertikaliu sarasu
function PanelKit.scroll(props)
	local frame = create("ScrollingFrame", {
		Name = props.name or "Scroll",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.new(1, 0, 1, 0),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.gold,
		ScrollBarImageTransparency = 0.6,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		LayoutOrder = props.order or 0,
		Visible = props.visible ~= false,
		Parent = props.parent,
	})
	local pad = props.padding or 0
	padding(frame, props.paddingTop or pad, props.paddingRight or pad, props.paddingBottom or pad, props.paddingLeft or pad)
	if props.layout ~= false then
		list(frame, props.spacing or 10)
	end
	return frame
end

-- "Dar yra zemiau" uzuomina: gradientas slenkamos srities apacioje (dingsta pasiekus gala)
function PanelKit.scrollFade(scroll, color)
	local fade = create("Frame", {
		Name = scroll.Name .. "Fade",
		BackgroundColor3 = color or C.bg,
		Active = false,
		Visible = false,
		ZIndex = scroll.ZIndex + 5,
		Parent = scroll.Parent,
	})
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = fade,
	})
	local function sync()
		local position, size = scroll.Position, scroll.Size
		fade.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale + size.Y.Scale, position.Y.Offset + size.Y.Offset - 28)
		fade.Size = UDim2.new(size.X.Scale, size.X.Offset - (scroll.ScrollBarThickness + 4), 0, 28)
		local canvasHeight = scroll.AbsoluteCanvasSize.Y
		local windowHeight = scroll.AbsoluteWindowSize.Y
		local atBottom = scroll.CanvasPosition.Y + windowHeight >= canvasHeight - 4
		fade.Visible = scroll.Visible and canvasHeight > windowHeight + 4 and not atBottom
	end
	for _, prop in ipairs({ "Position", "Size", "Visible", "CanvasPosition", "AbsoluteCanvasSize", "AbsoluteWindowSize" }) do
		scroll:GetPropertyChangedSignal(prop):Connect(sync)
	end
	sync()
	return fade
end

-- Tabu juosta su slystanciu auksiniu indikatoriumi
--   items = { { key = "roster", label = "Kovotojai", icon = "🥊" }, ... }
function PanelKit.tabs(props)
	local items = props.items
	local count = #items
	local bar = create("Frame", {
		Name = props.name or "Tabs",
		BackgroundColor3 = C.bgCard,
		Size = props.size or UDim2.new(1, 0, 0, 42),
		Position = props.position or UDim2.new(),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	corner(bar, 12)
	stroke(bar, C.border, 1, 0.4)
	padding(bar, 4, 4, 4, 4)

	local indicator = create("Frame", {
		Name = "Indicator",
		BackgroundColor3 = C.gold,
		Size = UDim2.new(1 / count, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Parent = bar,
	})
	corner(indicator, 9)
	gradient(indicator, C.goldBright, C.gold, 90)

	local buttons = {}
	local current = nil
	local handle = { Instance = bar }

	local function paint(instant)
		for index, item in ipairs(items) do
			local entry = buttons[item.key]
			local active = item.key == current
			local color = active and C.textOnGold or (entry.hover and C.textPrimary or C.textSecondary)
			if instant then
				entry.label.TextColor3 = color
			else
				tween(entry.label, 0.15, { TextColor3 = color })
			end
			if active then
				local target = UDim2.new((index - 1) / count, 0, 0, 0)
				if instant then
					indicator.Position = target
				else
					tween(indicator, 0.25, { Position = target }, Enum.EasingStyle.Quint)
				end
			end
		end
	end

	for index, item in ipairs(items) do
		local btn = create("TextButton", {
			Name = "Tab_" .. item.key,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1 / count, 0, 1, 0),
			Position = UDim2.new((index - 1) / count, 0, 0, 0),
			ZIndex = 2,
			Parent = bar,
		})
		local text = label({
			parent = btn,
			name = "Text",
			text = (item.icon and (item.icon .. "  ") or "") .. item.label,
			bold = true,
			textSize = props.textSize or 13,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
			zIndex = 2,
		})
		local entry = { button = btn, label = text, hover = false }
		buttons[item.key] = entry
		btn.MouseEnter:Connect(function()
			if isTouchOnly() then
				return
			end
			entry.hover = true
			paint(false)
		end)
		btn.MouseLeave:Connect(function()
			entry.hover = false
			paint(false)
		end)
		btn.Activated:Connect(function()
			handle.Select(item.key)
		end)
	end

	function handle.Select(key, instant)
		if not buttons[key] then
			return
		end
		local changed = key ~= current
		current = key
		paint(instant)
		if changed and props.onSelect then
			props.onSelect(key)
		end
	end
	function handle.Current()
		return current
	end
	function handle.SetLabel(key, text)
		local entry = buttons[key]
		if entry then
			for _, item in ipairs(items) do
				if item.key == key then
					entry.label.Text = (item.icon and (item.icon .. "  ") or "") .. text
				end
			end
		end
	end

	return handle
end

-- Teksto ivedimo laukas su auksiniu focus stroke
function PanelKit.textBox(props)
	local holder, holderStroke = card({
		parent = props.parent,
		name = props.name or "TextBoxHolder",
		size = props.size or UDim2.new(1, 0, 0, 40),
		position = props.position,
		order = props.order,
		color = C.bg,
		gradient = false,
		radius = 10,
		strokeTransparency = 0.25,
	})
	local box = create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = FONT_BOLD,
		TextSize = props.textSize or 15,
		TextColor3 = C.textPrimary,
		PlaceholderText = props.placeholder or "",
		PlaceholderColor3 = C.textSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = props.text or "",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		ClipsDescendants = true,
		Parent = holder,
	})
	box.Focused:Connect(function()
		tween(holderStroke, 0.15, { Color = C.gold, Transparency = 0 })
	end)
	box.FocusLost:Connect(function()
		tween(holderStroke, 0.2, { Color = C.border, Transparency = 0.25 })
	end)
	return box, holder
end

-- ============================================================
-- FORMATAVIMAS
-- ============================================================
function PanelKit.formatNumber(value)
	local n = math.floor((tonumber(value) or 0) + 0.5)
	local digits = tostring(math.abs(n))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	grouped = grouped:gsub("^,", "")
	return (n < 0 and "-" or "") .. grouped
end

function PanelKit.formatMoney(value)
	local n = tonumber(value) or 0
	if n < 0 then
		return "-$" .. PanelKit.formatNumber(-n)
	end
	return "$" .. PanelKit.formatNumber(n)
end

function PanelKit.formatSignedMoney(value)
	local n = tonumber(value) or 0
	if n > 0 then
		return "+$" .. PanelKit.formatNumber(n)
	end
	return PanelKit.formatMoney(n)
end

-- 3725 -> "1 h 02 min", 125 -> "2:05"
function PanelKit.formatDuration(seconds)
	local s = math.max(0, math.floor(seconds or 0))
	if s >= 3600 then
		return string.format("%d h %02d min", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

-- plural(1, "win", "wins") -> "1 win", plural(3, "win", "wins") -> "3 wins"
function PanelKit.plural(n, one, many)
	return string.format("%d %s", n, n == 1 and one or many)
end

function PanelKit.formatTimeAgo(seconds)
	local s = math.max(0, math.floor(seconds or 0))
	if s < 60 then
		return "just now"
	elseif s < 3600 then
		return string.format("%d min ago", s // 60)
	elseif s < 86400 then
		return string.format("%d h ago", s // 3600)
	end
	return string.format("%d d ago", s // 86400)
end

-- Display names for game data ids (configs keep their ids as keys)
PanelKit.L = {
	tiers = {},
	ladder = {},
	stats = {
		power = "Power",
		speed = "Speed",
		defense = "Defense",
		stamina = "Stamina",
		technique = "Technique",
	},
	personality = {},
	potential = {},
	stage = {
		Trial = "Trial",
		Member = "Member",
	},
	names = {},
}

function PanelKit.translate(group, key)
	local map = PanelKit.L[group]
	return (map and key and map[key]) or key or "-"
end

-- Display name for tournaments, sponsors and opponents
function PanelKit.displayName(name)
	return PanelKit.L.names[name] or name or "-"
end

-- Potencialo spalva is paletes: Legendary -> auksas, Rare -> plienas, Common -> antrinis tekstas
function PanelKit.potentialColor(potential)
	if potential == "Legendary" then
		return C.goldBright
	elseif potential == "Rare" then
		return C.steelBright
	end
	return C.textSecondary
end

-- Kovotojo "OVR" -- penkiu statistiku vidurkis
function PanelKit.overall(student)
	local stats = student and student.stats
	if not stats then
		return 0
	end
	local total = (stats.power or 0) + (stats.speed or 0) + (stats.defense or 0) + (stats.stamina or 0) + (stats.technique or 0)
	return math.floor(total / 5 + 0.5)
end

-- Stabilus kovotojo raktas (indeksai pasislenka, kai narys palieka akademija)
function PanelKit.studentKey(student)
	return tostring(student.name) .. "#" .. tostring(student.memberSince or 0)
end

-- Zvaigzdes RichText'u: uzpildytos auksines, tuscios -- border spalvos
function PanelKit.starsRich(count, total)
	total = total or 5
	count = math.clamp(count or 0, 0, total)
	return string.format(
		"<font color=\"#D4AF37\">%s</font><font color=\"#6A5E48\">%s</font>",
		string.rep("★", count), string.rep("☆", total - count)
	)
end

-- Potencialo zyme (vienoda visose panelese)
function PanelKit.potentialBadge(props)
	return PanelKit.badge({
		parent = props.parent,
		name = props.name or "Potential",
		text = "◆ " .. PanelKit.translate("potential", props.potential) .. (props.suffix or ""),
		color = PanelKit.potentialColor(props.potential),
		position = props.position,
		anchor = props.anchor,
		order = props.order,
	})
end

-- Kolekcine kovotojo kortele: OVR skaicius retumo remelyje (Legendary auksas, Rare plienas, Common tamsus)
local CARD_TONES = {
	Legendary = { top = C.goldBright, bottom = Color3.fromRGB(150, 112, 32), text = C.textOnGold, stroke = C.goldBright },
	Rare = { top = C.steelBright, bottom = Color3.fromRGB(36, 62, 96), text = C.textPrimary, stroke = C.steelBright },
	Common = { top = C.bgCardLight, bottom = C.bg, text = C.textPrimary, stroke = C.border },
}
function PanelKit.ovrCard(props)
	local tone = CARD_TONES[props.student and props.student.potencialas] or CARD_TONES.Common
	local width, height = props.width or 44, props.height or 52
	local cardFrame = create("Frame", {
		Name = props.name or "OvrCard",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, width, 0, height),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		Parent = props.parent,
	})
	corner(cardFrame, 9)
	stroke(cardFrame, tone.stroke, 1.5, 0.15)
	create("UIGradient", {
		Color = ColorSequence.new(tone.top, tone.bottom),
		Rotation = 90,
		Parent = cardFrame,
	})
	-- blizgesys (kortele "blizga" istrizai)
	local gloss = create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = cardFrame,
	})
	corner(gloss, 9)
	create("UIGradient", {
		Rotation = 35,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.45, 0.82),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gloss,
	})
	label({
		parent = cardFrame,
		name = "Caption",
		text = "OVR",
		font = Enum.Font.Oswald,
		textSize = 11,
		color = tone.text,
		transparency = 0.2,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 12),
		position = UDim2.new(0, 0, 0, 5),
	})
	label({
		parent = cardFrame,
		name = "Value",
		text = tostring(PanelKit.overall(props.student)),
		font = Enum.Font.GothamBlack,
		textSize = 20,
		color = tone.text,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.new(0, 0, 0, 19),
	})
	return cardFrame
end

-- Small typography fixes for server messages before they are shown in a toast
local MESSAGE_FIXES = {
	{ " %-%- ", " — " },
}
function PanelKit.localizeMessage(text)
	if type(text) ~= "string" then
		return text
	end
	for _, fix in ipairs(MESSAGE_FIXES) do
		text = text:gsub(fix[1], fix[2])
	end
	for key, display in pairs(PanelKit.L.names) do
		text = text:gsub(key, display)
	end
	return text
end

function PanelKit.stars(count, total)
	total = total or 5
	count = math.clamp(count or 0, 0, total)
	return string.rep("★", count) .. string.rep("☆", total - count)
end

-- Serverio atsakymo zinute -> "error" / "success" / "info" (toast spalvai)
function PanelKit.classifyMessage(message)
	local text = string.lower(message or "")
	local negative = {
		"not enough", "wait ", "can't", "cannot", "no longer", "already", "injured", "too tired", "could not",
		"invalid", "maximum", "quit:", "you need", "lost ", "not ready", "expired", "no sponsors", "blocked", "coming soon",
	}
	for _, word in ipairs(negative) do
		if string.find(text, word, 1, true) then
			return "error"
		end
	end
	return "success"
end

-- ============================================================
-- PANELIU VALDYMAS (vienu metu atidaryta viena modaline panele)
-- ============================================================
local player = Players.LocalPlayer
local playerGui = nil
local panelsGui = nil
local backdrop = nil

local registry = {} -- key -> { factory = fn, panel = panelObj | nil }
local openModalKey = nil

local PANELS_DISPLAY_ORDER = 10
local HUD_GUI_NAME = "MainHUD_Premium"

-- HUD geometrija (is MainHUDController) -- kad paneles jos neuzdengtu
local HUD = {
	margin = 16,
	statusWidth = 268,
	statusHeight = 80,
	dockHeight = 80, -- dokas su ringo virvemis ir kampais viduje
	fabSize = 60,
	fabMargin = 20,
	gap = 12,
}

local function getCamera()
	return Workspace.CurrentCamera
end

local function getViewport()
	local camera = getCamera()
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function getTopInset()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and typeof(topLeft) == "Vector2" then
		return topLeft.Y
	end
	return 36
end

local hudOriginalDisplayOrder = nil

local function setHudAbovePanels(above)
	if not playerGui then
		return
	end
	local hud = playerGui:FindFirstChild(HUD_GUI_NAME)
	if hud and hud:IsA("ScreenGui") then
		if hudOriginalDisplayOrder == nil then
			hudOriginalDisplayOrder = hud.DisplayOrder
		end
		hud.DisplayOrder = above and (PANELS_DISPLAY_ORDER + 1) or (PANELS_DISPLAY_ORDER - 1)
	end
end

-- Uzdarius paskutine modaline panele HUD grazinamas i pradine vieta tarp kitu GUI
local function restoreHudOrder()
	if not playerGui or hudOriginalDisplayOrder == nil then
		return
	end
	local hud = playerGui:FindFirstChild(HUD_GUI_NAME)
	if hud and hud:IsA("ScreenGui") then
		hud.DisplayOrder = hudOriginalDisplayOrder
	end
end

-- Apskaiciuoja modalines paneles vieta ir dydi pagal ekrana (ekrano koordinatemis, IgnoreGuiInset = true).
-- Panele nesidengia su HUD (StatusPanel virsuje kaireje, NavDock apacioje), kol tai imanoma.
local COMPACT_SCALE = 0.9
local function computeModalLayout(maxSize)
	local vp = getViewport()
	local inset = getTopInset()
	local m = HUD.margin

	local availableTop = inset + m
	local availableBottom = vp.Y - (m + HUD.dockHeight + HUD.gap)
	local width = math.min(maxSize.X, vp.X - m * 2)
	local centerX = vp.X / 2

	-- Persidengimas su StatusPanel: 1) susiaurinti centre, 2) paslinkti i desine, 3) nuleisti zemiau
	local statusRight = m + HUD.statusWidth + HUD.gap
	if centerX - width / 2 < statusRight then
		local centeredWidth = vp.X - statusRight * 2
		local shiftedWidth = math.min(maxSize.X, vp.X - statusRight - m)
		if centeredWidth >= math.min(maxSize.X, 680) then
			width = math.min(maxSize.X, centeredWidth)
		elseif shiftedWidth >= 640 then
			width = shiftedWidth
			centerX = statusRight + width / 2
		else
			availableTop = inset + m + HUD.statusHeight + HUD.gap
		end
	end
	local height = math.min(maxSize.Y, availableBottom - availableTop)

	if height >= 380 and width >= 560 then
		return {
			compact = false,
			scale = 1,
			size = Vector2.new(width, height),
			center = Vector2.new(centerX, availableTop + (availableBottom - availableTop) / 2),
		}
	end

	-- Kompaktiskas rezimas (telefonai/mazi langai): panele uzdengia HUD, siek tiek sumazinta per UIScale
	local availW = vp.X - 16
	local availH = vp.Y - inset - 12
	local logicalW = math.min(maxSize.X, availW / COMPACT_SCALE)
	local logicalH = math.min(maxSize.Y, availH / COMPACT_SCALE)
	return {
		compact = true,
		scale = COMPACT_SCALE,
		size = Vector2.new(logicalW, logicalH),
		center = Vector2.new(vp.X / 2, inset + 4 + availH / 2),
	}
end

-- Telefono vieta: desineje apacioje, virs Phone FAB mygtuko. Mazame ekrane -- centre, kaip modalas.
local function computePhoneLayout(maxSize)
	local vp = getViewport()
	local inset = getTopInset()
	local m = HUD.margin
	local right = vp.X - HUD.fabMargin
	local bottom = vp.Y - HUD.fabMargin - HUD.fabSize - HUD.gap
	local top = inset + m
	local height = math.min(maxSize.Y, bottom - top)
	if height >= 440 then
		return {
			compact = false,
			scale = 1,
			size = Vector2.new(maxSize.X, height),
			anchor = Vector2.new(1, 1),
			position = Vector2.new(right, bottom),
		}
	end
	local scale = COMPACT_SCALE
	local availH = vp.Y - inset - 12
	local logicalH = math.min(maxSize.Y, availH / scale)
	return {
		compact = true,
		scale = scale,
		size = Vector2.new(maxSize.X, logicalH),
		anchor = Vector2.new(0.5, 0.5),
		position = Vector2.new(vp.X / 2, inset + 4 + availH / 2),
	}
end

local function ensureGui()
	if panelsGui then
		return
	end
	playerGui = player:WaitForChild("PlayerGui")
	panelsGui = create("ScreenGui", {
		Name = "CoachPanels",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = PANELS_DISPLAY_ORDER,
		Parent = playerGui,
	})
	backdrop = create("TextButton", {
		Name = "Backdrop",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.shadow,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Selectable = false,
		ZIndex = 1,
		Parent = panelsGui,
	})
	backdrop.Activated:Connect(function()
		if openModalKey then
			PanelKit.close(openModalKey)
		end
	end)
end

function PanelKit.getGui()
	ensureGui()
	return panelsGui
end

--[[
	PanelKit.createPanel({
		key, title, subtitle, icon, accent = "gold"|"steel"|"crimson",
		maxSize = Vector2, style = "modal"|"phone",
	}) -> panel {
		Key, Holder, Surface, Header, Body, IsOpen,
		SetTitle, SetSubtitle, Toast(text, kind), Every(seconds, fn),
		OnOpen(fn), OnClose(fn), OnLayout(fn), Layout
	}
]]
function PanelKit.createPanel(def)
	ensureGui()
	local style = def.style or "modal"
	local accent = ACCENTS[def.accent or "gold"]
	local maxSize = def.maxSize or (style == "phone" and Vector2.new(340, 640) or Vector2.new(760, 540))
	local radius = style == "phone" and 34 or 14

	local panel = {
		Key = def.key,
		Style = style,
		IsOpen = false,
		Layout = nil,
		_onOpen = {},
		_onClose = {},
		_onLayout = {},
		_timers = {},
		_token = 0,
	}

	local holder = create("Frame", {
		Name = "Panel_" .. def.key,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, maxSize.X, 0, maxSize.Y),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Visible = false,
		ZIndex = 5,
		Parent = panelsGui,
	})
	local holderScale = create("UIScale", { Scale = 1, Parent = holder })

	-- Minksti seseliai (keli sluoksniai), uz paneles paviršiaus
	local shadowLayers = {}
	for index, spec in ipairs({
		{ grow = 20, offset = 16, transparency = 0.86 },
		{ grow = 8, offset = 8, transparency = 0.72 },
		{ grow = 2, offset = 3, transparency = 0.6 },
	}) do
		local shadow = create("Frame", {
			Name = "Shadow" .. index,
			BackgroundColor3 = C.shadow,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, spec.grow, 1, spec.grow),
			Position = UDim2.new(0.5, 0, 0.5, spec.offset),
			ZIndex = 1,
			Parent = holder,
		})
		corner(shadow, radius + math.floor(spec.grow / 2))
		shadowLayers[index] = { frame = shadow, transparency = spec.transparency }
	end

	-- Paprastas Frame (ne CanvasGroup): CanvasGroup mobiliuose perpiesia visa tekstura po kiekvieno
	-- pokycio viduje ir gali sulieti teksta. Fade efektas imituojamas virsutiniu overlay (zr. zemiau).
	local canvas = create("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2,
		Parent = holder,
	})

	local surface = create("Frame", {
		Name = "Surface",
		BackgroundColor3 = Color3.new(1, 1, 1), -- spalva ateina is UIGradient zemiau
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.new(0, 1, 0, 1),
		ClipsDescendants = false,
		-- Active: paspaudimai ant tuscios paneles vietos neprakrenta iki Backdrop (kuris uzdaro panele)
		-- ir telefono atveju -- iki 3D pasaulio (kameros sukimas)
		Active = true,
		Parent = canvas,
	})
	corner(surface, radius - 1)
	stroke(surface, C.border, style == "phone" and 1.5 or 1, style == "phone" and 0 or 0.2)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.bgCard),
			ColorSequenceKeypoint.new(0.3, C.bg),
			ColorSequenceKeypoint.new(1, C.bg),
		}),
		Rotation = 90,
		Parent = surface,
	})

	-- Telefono korpuso soniniai mygtukai (uz paviršiaus ribu)
	if style == "phone" then
		for index, spec in ipairs({
			{ x = 0, anchorX = 1, y = 0.2, h = 28 },
			{ x = 0, anchorX = 1, y = 0.27, h = 28 },
			{ x = 1, anchorX = 0, y = 0.24, h = 44 },
		}) do
			local sideButton = create("Frame", {
				Name = "SideButton" .. index,
				BackgroundColor3 = C.bgCardLight,
				AnchorPoint = Vector2.new(spec.anchorX, 0),
				Size = UDim2.new(0, 3, 0, spec.h),
				Position = UDim2.new(spec.x, 0, spec.y, 0),
				ZIndex = 1,
				Parent = holder,
			})
			corner(sideButton, UDim.new(1, 0))
			table.insert(shadowLayers, { frame = sideButton, transparency = 0 })
		end
	end

	panel.Holder = holder
	panel.Surface = surface
	panel.Accent = accent

	local HEADER_FULL, HEADER_COMPACT = 76, 56
	local headerHeight = style == "phone" and 0 or HEADER_FULL
	local header, titleLabel, subtitleLabel, closeButton, headerRight, iconBadge, iconGlyph, headerDivider
	if style == "modal" then
		header = create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, headerHeight),
			Parent = surface,
		})
		iconBadge = create("Frame", {
			Name = "IconBadge",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(0, 46, 0, 46),
			Position = UDim2.new(0, 20, 0, 15),
			Parent = header,
		})
		corner(iconBadge, 13)
		stroke(iconBadge, accent.bright, 1, 0.35)
		gradient(iconBadge, accent.bright, accent.base, 135)
		iconGlyph = label({
			parent = iconBadge,
			name = "Icon",
			text = def.icon or "",
			textSize = 22,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		titleLabel = label({
			parent = header,
			name = "Title",
			text = string.upper(def.title or ""),
			font = Enum.Font.Oswald,
			textSize = 26,
			size = UDim2.new(1, -200, 0, 28),
			position = UDim2.new(0, 80, 0, 13),
		})
		subtitleLabel = label({
			parent = header,
			name = "Subtitle",
			text = def.subtitle or "",
			textSize = 13,
			color = C.textSecondary,
			size = UDim2.new(1, -200, 0, 18),
			position = UDim2.new(0, 80, 0, 43),
		})
		closeButton = PanelKit.iconButton({
			parent = header,
			name = "CloseButton",
			text = "✕",
			size = 38,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -18, 0, 19),
			onClick = function()
				PanelKit.close(def.key)
			end,
		})
		headerRight = create("Frame", {
			Name = "HeaderRight",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0, 0, 0, 38),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(1, -68, 0, 19),
			Parent = header,
		})
		list(headerRight, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		headerDivider = PanelKit.divider({
			parent = surface,
			position = UDim2.new(0, 20, 0, headerHeight - 1),
			size = UDim2.new(1, -40, 0, 1),
			strength = 0.5,
		})
	end

	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -headerHeight),
		Position = UDim2.new(0, 0, 0, headerHeight),
		ClipsDescendants = true,
		Parent = surface,
	})

	-- Kompaktiskas (telefono) rezimas: zemesne antraste, be paantrastes
	local function applyHeaderMode(compact)
		if style ~= "modal" then
			return
		end
		headerHeight = compact and HEADER_COMPACT or HEADER_FULL
		header.Size = UDim2.new(1, 0, 0, headerHeight)
		iconBadge.Size = compact and UDim2.new(0, 36, 0, 36) or UDim2.new(0, 46, 0, 46)
		iconBadge.Position = compact and UDim2.new(0, 16, 0, 10) or UDim2.new(0, 20, 0, 15)
		iconGlyph.TextSize = compact and 18 or 22
		titleLabel.TextSize = compact and 21 or 26
		titleLabel.Position = compact and UDim2.new(0, 62, 0, 14) or UDim2.new(0, 80, 0, 13)
		titleLabel.Size = compact and UDim2.new(1, -180, 0, 26) or UDim2.new(1, -200, 0, 26)
		subtitleLabel.Visible = not compact
		closeButton.Size = compact and UDim2.new(0, 32, 0, 32) or UDim2.new(0, 38, 0, 38)
		closeButton.Position = compact and UDim2.new(1, -14, 0, 12) or UDim2.new(1, -18, 0, 19)
		headerRight.Position = compact and UDim2.new(1, -56, 0, 9) or UDim2.new(1, -68, 0, 19)
		headerDivider.Position = UDim2.new(0, 20, 0, headerHeight - 1)
		body.Size = UDim2.new(1, 0, 1, -headerHeight)
		body.Position = UDim2.new(0, 0, 0, headerHeight)
	end

	panel.Header = header
	panel.HeaderRight = headerRight
	panel.TitleLabel = titleLabel
	panel.SubtitleLabel = subtitleLabel
	panel.CloseButton = closeButton
	panel.Body = body

	-- Toast pranesimai: paneles apacioje (neuzdengia antrastes, tabu ir X), su seseliu
	local TOAST_TONES = {
		success = { color = C.gold, glyph = "✓", glyphColor = C.textOnGold },
		error = { color = C.crimsonBright, glyph = "!", glyphColor = C.textPrimary },
		info = { color = C.steelBright, glyph = "i", glyphColor = C.textPrimary },
	}
	-- modalinese panelese toast'as pakeltas virs "sticky" apatiniu juostu (pvz. Issaugoti / Registruotis)
	local toastRestOffset = style == "phone" and -80 or -84
	local toastHolder = create("Frame", {
		Name = "Toast",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = style == "phone" and UDim2.new(1, -24, 0, 0) or UDim2.new(0, 440, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0.5, 0, 1, toastRestOffset),
		Visible = false,
		ZIndex = 50,
		Parent = surface,
	})
	local toastShadow = create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = C.shadow,
		BackgroundTransparency = 0.6,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 4),
		ZIndex = 50,
		Parent = toastHolder,
	})
	corner(toastShadow, 10)
	local toastBody = create("Frame", {
		Name = "Body",
		BackgroundColor3 = C.bgCardLight,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 51,
		Parent = toastHolder,
	})
	corner(toastBody, 10)
	local toastStroke = stroke(toastBody, C.gold, 1, 0.3)
	padding(toastBody, 10, 14, 10, 14)
	local toastIcon = create("Frame", {
		Name = "Icon",
		BackgroundColor3 = C.gold,
		Size = UDim2.new(0, 20, 0, 20),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		ZIndex = 52,
		Parent = toastBody,
	})
	corner(toastIcon, UDim.new(1, 0))
	local toastGlyph = label({
		parent = toastIcon,
		name = "Glyph",
		text = "✓",
		bold = true,
		textSize = 13,
		color = C.textOnGold,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, 0),
		zIndex = 53,
	})
	local toastText = label({
		parent = toastBody,
		name = "Text",
		text = "",
		textSize = 13,
		wrap = true,
		size = UDim2.new(1, -30, 0, 0),
		position = UDim2.new(0, 30, 0, 0),
		autoSize = Enum.AutomaticSize.Y,
		zIndex = 52,
	})
	local toastToken = 0

	local function setToastVisual(transparency)
		toastBody.BackgroundTransparency = transparency
		toastShadow.BackgroundTransparency = 0.6 + 0.4 * transparency
		toastStroke.Transparency = 0.3 + 0.7 * transparency
		toastIcon.BackgroundTransparency = transparency
		toastGlyph.TextTransparency = transparency
		toastText.TextTransparency = transparency
	end

	local function tweenToast(duration, transparency, offset)
		tween(toastHolder, duration, { Position = UDim2.new(0.5, 0, 1, toastRestOffset + offset) }, Enum.EasingStyle.Quint)
		tween(toastBody, duration, { BackgroundTransparency = transparency })
		tween(toastShadow, duration, { BackgroundTransparency = 0.6 + 0.4 * transparency })
		tween(toastStroke, duration, { Transparency = 0.3 + 0.7 * transparency })
		tween(toastIcon, duration, { BackgroundTransparency = transparency })
		tween(toastGlyph, duration, { TextTransparency = transparency })
		tween(toastText, duration, { TextTransparency = transparency })
	end

	function panel.Toast(text, kind)
		if not text or text == "" then
			return
		end
		text = PanelKit.localizeMessage(text)
		kind = kind or PanelKit.classifyMessage(text)
		if kind == "error" then
			playSfx("Error")
		end
		local tone = TOAST_TONES[kind] or TOAST_TONES.success
		toastStroke.Color = tone.color
		toastIcon.BackgroundColor3 = tone.color
		toastGlyph.Text = tone.glyph
		toastGlyph.TextColor3 = tone.glyphColor
		toastText.Text = text
		toastToken += 1
		local myToken = toastToken
		toastHolder.Position = UDim2.new(0.5, 0, 1, toastRestOffset + 12)
		setToastVisual(1)
		toastHolder.Visible = true
		tweenToast(0.22, 0, 0)
		task.delay(3.2, function()
			if toastToken == myToken then
				tweenToast(0.22, 1, 12)
				task.delay(0.23, function()
					if toastToken == myToken then
						toastHolder.Visible = false
					end
				end)
			end
		end)
	end

	-- Fade overlay: paneles fono spalvos sluoksnis virs viso turinio (atidarant isblunka, uzdarant ryskeja)
	local fadeOverlay = create("Frame", {
		Name = "FadeOverlay",
		BackgroundColor3 = style == "phone" and C.bg or C.bg,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		ZIndex = 200,
		Parent = surface,
	})
	corner(fadeOverlay, radius - 1)

	function panel.SetTitle(text)
		if titleLabel then
			titleLabel.Text = string.upper(text or "")
		end
	end
	function panel.SetSubtitle(text)
		if subtitleLabel then
			subtitleLabel.Text = text
		end
	end
	function panel.OnOpen(fn)
		table.insert(panel._onOpen, fn)
	end
	function panel.OnClose(fn)
		table.insert(panel._onClose, fn)
	end
	function panel.OnLayout(fn)
		table.insert(panel._onLayout, fn)
		if panel.Layout then
			fn(panel.Layout)
		end
	end
	-- Periodinis atnaujinimas (pvz. cooldown laikmaciai) -- vyksta tik kol panele atidaryta
	function panel.Every(seconds, fn)
		table.insert(panel._timers, { interval = seconds, fn = fn })
	end

	-- Isdestymas pagal ekrano dydi
	function panel._applyLayout()
		local layout
		if style == "phone" then
			layout = computePhoneLayout(maxSize)
			holder.AnchorPoint = layout.anchor
			holder.Position = UDim2.new(0, layout.position.X, 0, layout.position.Y)
		else
			layout = computeModalLayout(maxSize)
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.new(0, layout.center.X, 0, layout.center.Y)
		end
		holder.Size = UDim2.new(0, math.floor(layout.size.X), 0, math.floor(layout.size.Y))
		applyHeaderMode(layout.compact)
		if style == "modal" then
			toastHolder.Size = UDim2.new(0, math.floor(math.min(440, layout.size.X - 80)), 0, 0)
		end
		panel.Layout = layout
		panel._baseScale = layout.scale
		if panel.IsOpen then
			holderScale.Scale = layout.scale
		end
		for _, fn in ipairs(panel._onLayout) do
			task.spawn(fn, layout)
		end
		return layout
	end

	function panel._show(precomputedLayout)
		panel._token += 1
		local token = panel._token
		local layout = precomputedLayout or panel._applyLayout()
		panel.IsOpen = true
		holder.Visible = true
		if style == "modal" or layout.compact then
			setHudAbovePanels(not layout.compact)
		end

		local restPosition = holder.Position
		local fromOffset = style == "phone" and 28 or 14
		holder.Position = restPosition + UDim2.new(0, 0, 0, fromOffset)
		holderScale.Scale = layout.scale * (style == "phone" and 0.88 or 0.9) -- "smugio" efektas: atsoka per Back
		fadeOverlay.BackgroundTransparency = 0
		fadeOverlay.Visible = true
		for _, layer in ipairs(shadowLayers) do
			layer.frame.BackgroundTransparency = 1
		end

		tween(holder, 0.32, { Position = restPosition }, Enum.EasingStyle.Quint)
		tween(holderScale, 0.34, { Scale = layout.scale }, Enum.EasingStyle.Back)
		playSfx("PanelOpen")
		tween(fadeOverlay, 0.24, { BackgroundTransparency = 1 })
		task.delay(0.25, function()
			if panel._token == token then
				fadeOverlay.Visible = false
			end
		end)
		for _, layer in ipairs(shadowLayers) do
			tween(layer.frame, 0.3, { BackgroundTransparency = layer.transparency })
		end

		for _, fn in ipairs(panel._onOpen) do
			task.spawn(fn)
		end
		for _, timer in ipairs(panel._timers) do
			task.spawn(function()
				while panel.IsOpen and panel._token == token do
					local ok, err = pcall(timer.fn)
					if not ok then
						warn("PanelKit: laikmacio klaida (" .. def.key .. "): " .. tostring(err))
					end
					task.wait(timer.interval)
				end
			end)
		end
	end

	function panel._hide(instant)
		if not panel.IsOpen then
			return
		end
		panel.IsOpen = false
		panel._token += 1
		local token = panel._token
		for _, fn in ipairs(panel._onClose) do
			task.spawn(fn)
		end
		if instant then
			holder.Visible = false
			return
		end
		local base = panel._baseScale or 1
		local restPosition = holder.Position
		fadeOverlay.Visible = true
		tween(fadeOverlay, 0.16, { BackgroundTransparency = 0 })
		tween(holderScale, 0.18, { Scale = base * 0.96 })
		tween(holder, 0.18, { Position = restPosition + UDim2.new(0, 0, 0, style == "phone" and 18 or 8) })
		for _, layer in ipairs(shadowLayers) do
			tween(layer.frame, 0.16, { BackgroundTransparency = 1 })
		end
		task.delay(0.19, function()
			if panel._token == token then
				holder.Visible = false
				holder.Position = restPosition
			end
		end)
	end

	return panel
end

local function showBackdrop(visible)
	if not backdrop then
		return
	end
	if visible then
		backdrop.Visible = true
		tween(backdrop, 0.22, { BackgroundTransparency = 0.45 })
	else
		tween(backdrop, 0.18, { BackgroundTransparency = 1 })
		task.delay(0.18, function()
			if not openModalKey then
				backdrop.Visible = false
			end
		end)
	end
end

local function getPanel(key)
	local entry = registry[key]
	if not entry or entry.failed then
		return nil
	end
	if not entry.panel then
		local ok, result = pcall(entry.factory)
		if not ok then
			-- nebandom kurti is naujo kiekvieno paspaudimo metu (liktu pusiau sukurtos UI kopijos)
			entry.failed = true
			warn("PanelKit: nepavyko sukurti paneles '" .. key .. "': " .. tostring(result))
			return nil
		end
		entry.panel = result
	end
	return entry.panel
end

-- Gamepad: B mygtukas uzdaro atidaryta modaline panele
local CLOSE_ACTION = "CoachPanelsClose"
local function bindCloseAction(bound)
	if bound then
		ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, inputState)
			if inputState == Enum.UserInputState.Begin and openModalKey then
				PanelKit.close(openModalKey)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction(CLOSE_ACTION)
	end
end

function PanelKit.register(key, factory)
	registry[key] = { factory = factory, panel = nil }
end

function PanelKit.get(key)
	return getPanel(key)
end

function PanelKit.isOpen(key)
	local entry = registry[key]
	return entry ~= nil and entry.panel ~= nil and entry.panel.IsOpen
end

-- Modalinis elgesys: visada modalinems panelems, o telefonui -- tik kompaktiskame (mazo ekrano) rezime
local function isModalLike(panel, layout)
	return panel.Style == "modal" or (layout ~= nil and layout.compact == true)
end

function PanelKit.open(key)
	ensureGui()
	local panel = getPanel(key)
	if not panel or panel.IsOpen then
		return
	end
	local layout = panel._applyLayout()
	panel._modalLike = isModalLike(panel, layout)
	if panel._modalLike then
		if openModalKey and openModalKey ~= key then
			local previous = getPanel(openModalKey)
			if previous then
				previous._hide(false)
			end
		end
		openModalKey = key
		showBackdrop(true)
		bindCloseAction(true)
	end
	panel._show(layout)
	PanelKit.Changed:Fire(key, true)
end

function PanelKit.close(key)
	local entry = registry[key]
	local panel = entry and entry.panel
	if not panel or not panel.IsOpen then
		return
	end
	panel._hide(false)
	if openModalKey == key then
		openModalKey = nil
		showBackdrop(false)
		bindCloseAction(false)
		restoreHudOrder()
	end
	PanelKit.Changed:Fire(key, false)
end

-- Uzdaro visas atidarytas paneles (pvz. pries atidarant sena UI langa)
function PanelKit.closeAll()
	for key, entry in pairs(registry) do
		if entry.panel and entry.panel.IsOpen then
			PanelKit.close(key)
		end
	end
end

-- Paneliu sukurimas is anksto (po viena per kadra), kad pirmas atidarymas nestrigtu
function PanelKit.prebuild(keys)
	task.spawn(function()
		for _, key in ipairs(keys) do
			getPanel(key)
			task.wait()
		end
	end)
end

function PanelKit.toggle(key)
	if PanelKit.isOpen(key) then
		PanelKit.close(key)
	else
		PanelKit.open(key)
	end
end

-- Ekrano dydzio pasikeitimas -> perskaiciuojam atidarytu paneliu isdestyma
task.spawn(function()
	local camera = getCamera()
	while not camera do
		task.wait(0.2)
		camera = getCamera()
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		for _, entry in pairs(registry) do
			if entry.panel and entry.panel.IsOpen then
				local layout = entry.panel._applyLayout()
				if entry.panel._modalLike then
					setHudAbovePanels(not layout.compact)
				end
			end
		end
	end)
end)

return PanelKit
