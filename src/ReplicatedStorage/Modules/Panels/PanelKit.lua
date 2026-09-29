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

local PanelKit = {}

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
	ghost   = { base = C.bgCardLight, hover = C.bgCardLight,   text = C.textPrimary, stroke = C.border, hoverStroke = C.gold },
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
function PanelKit.tween(instance, duration, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end
local tween = PanelKit.tween

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

function PanelKit.grid(parent, cellSize, cellPadding)
	return create("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = cellPadding or UDim2.new(0, 10, 0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
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

	local function composeText(text)
		if props.icon and props.icon ~= "" then
			return props.icon .. "  " .. text
		end
		return text
	end

	local textLabel = label({
		parent = btn,
		name = "Text",
		text = composeText(props.text or ""),
		bold = true,
		textSize = props.textSize or 14,
		color = variant.text,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -12, 1, 0),
		position = UDim2.new(0, 6, 0, 0),
	})

	local function paint(instant)
		local bgColor, textColor, strokeColor, strokeTransparency
		if not enabled then
			bgColor, textColor, strokeColor, strokeTransparency = C.bgCardLight, C.textSecondary, C.border, 0.5
		elseif hovering then
			bgColor = variant.hover
			textColor = variant.text
			strokeColor = variant.hoverStroke or variant.stroke
			strokeTransparency = variant.hoverStroke and 0.1 or 0.35
		else
			bgColor, textColor, strokeColor, strokeTransparency = variant.base, variant.text, variant.stroke, 0.55
		end
		sheen.Enabled = enabled
		if instant then
			btn.BackgroundColor3 = bgColor
			textLabel.TextColor3 = textColor
			btnStroke.Color = strokeColor
			btnStroke.Transparency = strokeTransparency
		else
			tween(btn, 0.14, { BackgroundColor3 = bgColor })
			tween(textLabel, 0.14, { TextColor3 = textColor })
			tween(btnStroke, 0.14, { Color = strokeColor, Transparency = strokeTransparency })
		end
	end

	btn.MouseEnter:Connect(function()
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
		end
	end)
	btn.MouseButton1Up:Connect(function()
		tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	btn.Activated:Connect(function()
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
		text = props.title or "",
		bold = true,
		textSize = props.textSize or 15,
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
		Size = UDim2.new(0, 0, 0, props.height or 20),
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
		textSize = props.textSize or 11,
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
		textSize = 12,
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
		position = UDim2.new(0, 0, 0, 20),
	})
	local sub = label({
		parent = tile,
		name = "Sub",
		text = props.sub or "",
		textSize = 11,
		color = C.textSecondary,
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.new(0, 0, 1, -14),
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
		ScrollBarImageTransparency = 0.45,
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
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	grouped = grouped:gsub("^%s+", "")
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

-- 3725 -> "1 val 02 min", 125 -> "2:05"
function PanelKit.formatDuration(seconds)
	local s = math.max(0, math.floor(seconds or 0))
	if s >= 3600 then
		return string.format("%d val %02d min", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

function PanelKit.formatTimeAgo(seconds)
	local s = math.max(0, math.floor(seconds or 0))
	if s < 60 then
		return "ką tik"
	elseif s < 3600 then
		return string.format("prieš %d min", s // 60)
	elseif s < 86400 then
		return string.format("prieš %d val", s // 3600)
	end
	return string.format("prieš %d d.", s // 86400)
end

-- Lietuviski pavadinimai zaidimo duomenims (config'uose likę angliski ID)
PanelKit.L = {
	tiers = {
		["Local Coach"] = "Vietinis treneris",
		["Rising Coach"] = "Kylantis treneris",
		["Respected Coach"] = "Gerbiamas treneris",
		["Elite Coach"] = "Elitinis treneris",
		["World-Class Coach"] = "Pasaulinio lygio treneris",
	},
	ladder = {
		["Local Amateur"] = "Vietinės kovos",
		["Regional"] = "Regionas",
		["WBF"] = "WBF",
	},
	stats = {
		power = "Jėga",
		speed = "Greitis",
		defense = "Gynyba",
		stamina = "Ištvermė",
		technique = "Technika",
	},
	personality = {
		["Aggressive"] = "Agresyvus",
		["Defensive"] = "Gynybiškas",
		["Hard Worker"] = "Darbštus",
		["Lazy"] = "Tingus",
		["Nervous"] = "Nervingas",
		["Confident"] = "Pasitikintis",
		["Disciplined"] = "Disciplinuotas",
		["Natural Talent"] = "Įgimtas talentas",
	},
	potential = {
		Common = "Įprastas",
		Rare = "Retas",
		Legendary = "Legendinis",
	},
	stage = {
		Trial = "Bandomasis",
		Member = "Narys",
	},
	-- Config'uose pavadinimai be diakritiku (naudojami kaip raktai) -- rodome taisyklingai
	names = {
		["Miesto Taure"] = "Miesto Taurė",
		["Regiono Cempionatas"] = "Regiono Čempionatas",
		["Pasaulio Taure"] = "Pasaulio Taurė",
		["Legendu Arena"] = "Legendų Arena",
		["Azuolo Mityba"] = "Ąžuolo Mityba",
		["Gelezinis Kumstis"] = "Geležinis Kumštis",
		["Cempionu Studija"] = "Čempionų Studija",
		["Nacionaline Arena"] = "Nacionalinė Arena",
		["Tomas Zaibas"] = "Tomas Žaibas",
		["Linas Perkunas"] = "Linas Perkūnas",
		["Audrius Gelezis"] = "Audrius Geležis",
		["Vytas Azuolas"] = "Vytas Ąžuolas",
	},
}

function PanelKit.translate(group, key)
	local map = PanelKit.L[group]
	return (map and key and map[key]) or key or "-"
end

-- Rodomas pavadinimas (turnyrai, remejai, varzovai) su lietuviskomis raidemis
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

function PanelKit.stars(count, total)
	total = total or 5
	count = math.clamp(count or 0, 0, total)
	return string.rep("★", count) .. string.rep("☆", total - count)
end

-- Serverio atsakymo zinute -> "error" / "success" / "info" (toast spalvai)
function PanelKit.classifyMessage(message)
	local text = string.lower(message or "")
	local negative = { "nepakanka", "palauk", "negali", "nebe", "trūksta", "truksta", "jau ", "susižeid", "susizeid", "pavarg", "nepavyko", "neteising", "maksimal", "paliko", "reikia", "pralaim" }
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
	statusWidth = 250,
	statusHeight = 76,
	dockHeight = 64,
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

local function setHudAbovePanels(above)
	if not playerGui then
		return
	end
	local hud = playerGui:FindFirstChild(HUD_GUI_NAME)
	if hud and hud:IsA("ScreenGui") then
		hud.DisplayOrder = above and (PANELS_DISPLAY_ORDER + 1) or (PANELS_DISPLAY_ORDER - 1)
	end
end

-- Apskaiciuoja modalines paneles vieta ir dydi pagal ekrana (ekrano koordinatemis, IgnoreGuiInset = true).
local function computeModalLayout(maxSize)
	local vp = getViewport()
	local inset = getTopInset()
	local m = HUD.margin

	local availableTop = inset + m
	local availableBottom = vp.Y - (m + HUD.dockHeight + HUD.gap)
	local width = math.min(maxSize.X, vp.X - m * 2)
	local left = (vp.X - width) / 2

	-- Jei panele horizontaliai persidengia su StatusPanel (virsuje kaireje): pirmiausia bandom ja
	-- susiaurinti (islaikant pilna auksti), o jei per siaura -- nuleidziam zemiau StatusPanel.
	local statusRight = m + HUD.statusWidth + HUD.gap
	if left < statusRight then
		local narrowedWidth = vp.X - statusRight * 2
		if narrowedWidth >= math.min(maxSize.X, 680) then
			width = narrowedWidth
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
			center = Vector2.new(vp.X / 2, availableTop + (availableBottom - availableTop) / 2),
		}
	end

	-- Kompaktiskas rezimas (telefonai/mazi langai): panele uzdengia HUD, sumazinta per UIScale
	local scale = 0.82
	local availW = vp.X - 16
	local availH = vp.Y - inset - 12
	local logicalW = math.min(maxSize.X, availW / scale)
	local logicalH = math.min(maxSize.Y, availH / scale)
	return {
		compact = true,
		scale = scale,
		size = Vector2.new(logicalW, logicalH),
		center = Vector2.new(vp.X / 2, inset + 4 + availH / 2),
	}
end

-- Telefono vieta: desineje apacioje, virs Phone FAB mygtuko
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
	local scale = 0.8
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

	-- Minksti seseliai (keli sluoksniai), uz CanvasGroup ribu
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

	-- CanvasGroup leidzia issaugoti visos paneles fade animacija
	local canvas = create("CanvasGroup", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2,
		Parent = holder,
	})
	corner(canvas, radius)

	local surface = create("Frame", {
		Name = "Surface",
		BackgroundColor3 = Color3.new(1, 1, 1), -- spalva ateina is UIGradient zemiau
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.new(0, 1, 0, 1),
		ClipsDescendants = false,
		Parent = canvas,
	})
	corner(surface, radius - 1)
	stroke(surface, style == "phone" and C.gold or C.border, 1, style == "phone" and 0.55 or 0.2)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.bgCard),
			ColorSequenceKeypoint.new(0.3, C.bg),
			ColorSequenceKeypoint.new(1, C.bg),
		}),
		Rotation = 90,
		Parent = surface,
	})

	panel.Holder = holder
	panel.Canvas = canvas
	panel.Surface = surface
	panel.Accent = accent

	local headerHeight = style == "phone" and 0 or 76
	local header, titleLabel, subtitleLabel, closeButton, headerRight
	if style == "modal" then
		header = create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, headerHeight),
			Parent = surface,
		})
		local iconBadge = create("Frame", {
			Name = "IconBadge",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(0, 46, 0, 46),
			Position = UDim2.new(0, 20, 0, 15),
			Parent = header,
		})
		corner(iconBadge, 13)
		stroke(iconBadge, accent.bright, 1, 0.35)
		gradient(iconBadge, accent.bright, accent.base, 135)
		label({
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
			text = def.title or "",
			bold = true,
			textSize = 22,
			size = UDim2.new(1, -200, 0, 26),
			position = UDim2.new(0, 80, 0, 16),
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
		PanelKit.divider({
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

	panel.Header = header
	panel.HeaderRight = headerRight
	panel.TitleLabel = titleLabel
	panel.SubtitleLabel = subtitleLabel
	panel.CloseButton = closeButton
	panel.Body = body

	-- Toast pranesimai (paneles virsuje, virs turinio)
	local toastFrame, toastText, toastBar, toastIcon, toastStroke
	do
		toastFrame = create("Frame", {
			Name = "Toast",
			BackgroundColor3 = C.bgCardLight,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(1, style == "phone" and -32 or -120, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0.5, 0, 0, headerHeight + 10),
			Visible = false,
			ZIndex = 50,
			Parent = surface,
		})
		corner(toastFrame, 10)
		toastStroke = stroke(toastFrame, C.gold, 1, 0.3)
		toastBar = create("Frame", {
			Name = "Accent",
			BackgroundColor3 = C.gold,
			Size = UDim2.new(0, 4, 1, -12),
			Position = UDim2.new(0, 6, 0, 6),
			ZIndex = 51,
			Parent = toastFrame,
		})
		corner(toastBar, UDim.new(1, 0))
		toastIcon = label({
			parent = toastFrame,
			name = "Icon",
			text = "✅",
			textSize = 16,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(0, 24, 0, 24),
			position = UDim2.new(0, 16, 0, 8),
			zIndex = 51,
		})
		toastText = label({
			parent = toastFrame,
			name = "Text",
			text = "",
			textSize = 13,
			wrap = true,
			alignY = Enum.TextYAlignment.Center,
			size = UDim2.new(1, -56, 0, 0),
			position = UDim2.new(0, 46, 0, 0),
			autoSize = Enum.AutomaticSize.Y,
			zIndex = 51,
		})
		padding(toastText, 11, 0, 11, 0)
	end
	local toastToken = 0

	function panel.Toast(text, kind)
		if not text or text == "" then
			return
		end
		kind = kind or PanelKit.classifyMessage(text)
		local tone = kind == "error" and C.crimsonBright or (kind == "info" and C.steelBright or C.gold)
		toastBar.BackgroundColor3 = tone
		toastStroke.Color = tone
		toastIcon.Text = kind == "error" and "⚠️" or (kind == "info" and "ℹ️" or "✅")
		toastText.Text = text
		toastToken += 1
		local myToken = toastToken
		local restY = style == "phone" and 58 or headerHeight + 10
		toastFrame.Position = UDim2.new(0.5, 0, 0, restY - 8)
		toastFrame.BackgroundTransparency = 0
		toastFrame.Visible = true
		tween(toastFrame, 0.25, { Position = UDim2.new(0.5, 0, 0, restY) }, Enum.EasingStyle.Back)
		task.delay(3.6, function()
			if toastToken == myToken then
				tween(toastFrame, 0.2, { Position = UDim2.new(0.5, 0, 0, restY - 8) })
				task.delay(0.2, function()
					if toastToken == myToken then
						toastFrame.Visible = false
					end
				end)
			end
		end)
	end

	function panel.SetTitle(text)
		if titleLabel then
			titleLabel.Text = text
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

	function panel._show()
		panel._token += 1
		local token = panel._token
		local layout = panel._applyLayout()
		panel.IsOpen = true
		holder.Visible = true
		if style == "modal" then
			setHudAbovePanels(not layout.compact)
		end

		local restPosition = holder.Position
		local fromOffset = style == "phone" and 28 or 14
		holder.Position = restPosition + UDim2.new(0, 0, 0, fromOffset)
		holderScale.Scale = layout.scale * (style == "phone" and 0.9 or 0.95)
		canvas.GroupTransparency = 1
		for _, layer in ipairs(shadowLayers) do
			layer.frame.BackgroundTransparency = 1
		end

		tween(holder, 0.32, { Position = restPosition }, Enum.EasingStyle.Quint)
		tween(holderScale, 0.3, { Scale = layout.scale }, Enum.EasingStyle.Back)
		tween(canvas, 0.2, { GroupTransparency = 0 })
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
		tween(canvas, 0.16, { GroupTransparency = 1 })
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
	if not entry then
		return nil
	end
	if not entry.panel then
		local ok, result = pcall(entry.factory)
		if not ok then
			warn("PanelKit: nepavyko sukurti paneles '" .. key .. "': " .. tostring(result))
			return nil
		end
		entry.panel = result
	end
	return entry.panel
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

function PanelKit.open(key)
	ensureGui()
	local panel = getPanel(key)
	if not panel or panel.IsOpen then
		return
	end
	if panel.Style == "modal" then
		if openModalKey and openModalKey ~= key then
			local previous = getPanel(openModalKey)
			if previous then
				previous._hide(false)
			end
		end
		openModalKey = key
		showBackdrop(true)
	end
	panel._show()
end

function PanelKit.close(key)
	local entry = registry[key]
	local panel = entry and entry.panel
	if not panel or not panel.IsOpen then
		return
	end
	panel._hide(false)
	if panel.Style == "modal" and openModalKey == key then
		openModalKey = nil
		showBackdrop(false)
	end
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
				if entry.panel.Style == "modal" then
					setHudAbovePanels(not layout.compact)
				end
			end
		end
	end)
end)

return PanelKit
