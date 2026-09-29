--[[
	LoadingScreen (ReplicatedFirst)
	"Fight Night" loading screen: sweeping arena spotlights, a crowd with camera flashes,
	ring ropes, a championship belt that fills with gold from the centre, and a ring-announcer
	style intro of the player's academy. Progress is real: game load -> asset preload -> profile.

	Hands over to TitleScreen (StarterPlayerScripts) through the player attribute "CoachIntro":
	  "loading" -> "title" (TitleScreen then shows the menu) -> "playing" (set by TitleScreen)
	Self-contained on purpose: ReplicatedStorage is not guaranteed to exist when this starts.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
player:SetAttribute("CoachIntro", "loading")

-- ------------------------------------------------------------
-- Palette (same as the HUD)
-- ------------------------------------------------------------
local C = {
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
	black = Color3.new(0, 0, 0),
	white = Color3.new(1, 1, 1),
}

local STATUS_LINES = {
	"Taping the hands…",
	"Lacing up the gloves…",
	"Hanging the heavy bags…",
	"Stretching the ring ropes…",
	"Warming up the crowd…",
	"Polishing the championship belt…",
}

local TIPS = {
	"Hire a Physio — tired and injured fighters recover much faster.",
	"Every fighting style beats another one. Check the style wheel before a fight.",
	"Buy a Scout Report to see how far a talent can really grow.",
	"Sponsors pay a signing bonus right away, then steady income.",
	"Post on SocialGym to gain followers — they bring walk-in clients.",
	"Rest your fighters. Fatigue weakens them in the ring.",
	"Win tournaments to fill your trophy shelf and grow your reputation.",
}

local MIN_SHOW_TIME = 2.4 -- logo animation needs this long; loading is never padded beyond it
local SKIP_AFTER = 5

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local function new(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function tween(inst, time, goals, style, direction, repeatCount, reverses)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, repeatCount or 0, reverses or false)
	local t = TweenService:Create(inst, info, goals)
	t:Play()
	return t
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius) }, parent)
end

local function gradient(parent, keypoints, rotation, transparency)
	if parent:IsA("GuiObject") and parent.BackgroundTransparency < 1 then
		parent.BackgroundColor3 = C.white -- UIGradient multiplies the background colour
	end
	local seq = {}
	for _, kp in ipairs(keypoints) do
		table.insert(seq, ColorSequenceKeypoint.new(kp[1], kp[2]))
	end
	return new("UIGradient", {
		Color = ColorSequence.new(seq),
		Rotation = rotation or 90,
		Transparency = transparency or NumberSequence.new(0),
	}, parent)
end

local function numberSeq(points)
	local seq = {}
	for _, p in ipairs(points) do
		table.insert(seq, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(seq)
end

local function text(props, parent)
	local label = new("TextLabel", {
		Name = props.name or "Text",
		BackgroundTransparency = 1,
		Font = props.font or Enum.Font.Gotham,
		Text = props.text or "",
		TextSize = props.size or 16,
		TextColor3 = props.color or C.textPrimary,
		TextTransparency = props.transparency or 0,
		TextXAlignment = props.alignX or Enum.TextXAlignment.Center,
		TextYAlignment = props.alignY or Enum.TextYAlignment.Center,
		Size = props.frame or UDim2.new(1, 0, 0, (props.size or 16) + 8),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		AutomaticSize = props.autoSize or Enum.AutomaticSize.None,
		RichText = props.rich == true,
		ZIndex = props.z or 1,
		LayoutOrder = props.order or 0,
	}, parent)
	return label
end

local function viewportSize()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if size.X < 10 or size.Y < 10 then
		size = Vector2.new(1280, 720)
	end
	return size
end

-- ------------------------------------------------------------
-- Screen
-- ------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "CoachLoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
ReplicatedFirst:RemoveDefaultLoadingScreen()

local root = new("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.bg,
	Active = true, -- nothing behind the loading screen can be clicked
}, gui)
gradient(root, { { 0, Color3.fromRGB(30, 26, 32) }, { 0.55, Color3.fromRGB(18, 16, 20) }, { 1, Color3.fromRGB(9, 8, 11) } }, 90)

-- Warm arena haze behind the crowd
local haze = new("Frame", {
	Name = "ArenaHaze",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 0),
	Size = UDim2.new(1.4, 0, 0.62, 0),
	BackgroundColor3 = C.gold,
	ZIndex = 1,
}, root)
corner(haze, UDim.new(1, 0))
gradient(haze, { { 0, Color3.fromRGB(236, 200, 92) }, { 1, Color3.fromRGB(178, 40, 54) } }, 90,
	numberSeq({ { 0, 1 }, { 0.35, 0.86 }, { 0.7, 0.8 }, { 1, 0.9 } }))

-- Spotlights: tall beams pivoting at the top edge (Rotation turns around the centre,
-- so each beam is centred on its pivot and only its lower half is ever on screen)
local beams = {}
for index, def in ipairs({
	{ x = 0.2, from = -28, to = -12, time = 4.2 },
	{ x = 0.5, from = -7, to = 7, time = 5.1 },
	{ x = 0.8, from = 12, to = 28, time = 4.6 },
}) do
	local pivot = new("Frame", {
		Name = "Spotlight" .. index,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(def.x, 0, -0.04, 0),
		Size = UDim2.new(0, 0, 2.3, 0),
		BackgroundTransparency = 1,
		Rotation = def.from,
		ZIndex = 2,
	}, root)
	-- three widths stacked = soft beam edges
	for layer, width in ipairs({ 90, 170, 260 }) do
		local beam = new("Frame", {
			Name = "Layer" .. layer,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(0, width, 1, 0),
			BackgroundColor3 = Color3.fromRGB(255, 240, 214),
			BackgroundTransparency = 0,
			ZIndex = 2,
		}, pivot)
		gradient(beam, { { 0, Color3.fromRGB(255, 244, 222) }, { 1, Color3.fromRGB(236, 200, 92) } }, 90,
			numberSeq({ { 0, 1 }, { 0.499, 1 }, { 0.5, 0.8 + layer * 0.04 }, { 0.8, 0.94 }, { 1, 1 } }))
	end
	table.insert(beams, pivot)
	tween(pivot, def.time, { Rotation = def.to }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
end

-- ------------------------------------------------------------
-- Centre block: logo, belt, status (designed at 640x380, scaled to the screen)
-- ------------------------------------------------------------
local center = new("Frame", {
	Name = "Center",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.42, 0),
	Size = UDim2.new(0, 640, 0, 380),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, root)
local centerScale = new("UIScale", { Scale = 1 }, center)

local logo = new("Frame", {
	Name = "Logo",
	Size = UDim2.new(1, 0, 0, 230),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, center)
local logoScale = new("UIScale", { Scale = 1.35 }, logo)

local coachWord = text({
	name = "Coach",
	text = "C  O  A  C  H",
	font = Enum.Font.Oswald,
	size = 28,
	color = C.gold,
	frame = UDim2.new(1, 0, 0, 34),
	position = UDim2.new(0, 0, 0, 34),
	transparency = 1,
	z = 6,
}, logo)

local titleShadow = text({
	name = "TitleShadow",
	text = "ACADEMY",
	font = Enum.Font.GothamBlack,
	size = 112,
	color = C.black,
	frame = UDim2.new(1, 0, 0, 118),
	position = UDim2.new(0, 0, 0, 78),
	transparency = 1,
	z = 5,
}, logo)
local title = text({
	name = "Title",
	text = "ACADEMY",
	font = Enum.Font.GothamBlack,
	size = 112,
	color = C.white,
	frame = UDim2.new(1, 0, 0, 118),
	position = UDim2.new(0, 0, 0, 70),
	transparency = 1,
	z = 6,
}, logo)
gradient(title, { { 0, C.goldBright }, { 0.55, C.gold }, { 1, Color3.fromRGB(150, 112, 32) } }, 90)
-- Moving shine across the letters
local shine = text({
	name = "TitleShine",
	text = "ACADEMY",
	font = Enum.Font.GothamBlack,
	size = 112,
	color = C.white,
	frame = UDim2.new(1, 0, 0, 118),
	position = UDim2.new(0, 0, 0, 70),
	transparency = 1,
	z = 7,
}, logo)
local shineGradient = new("UIGradient", {
	Rotation = 20,
	Offset = Vector2.new(-1.2, 0),
	Transparency = numberSeq({ { 0, 1 }, { 0.42, 1 }, { 0.5, 0.35 }, { 0.58, 1 }, { 1, 1 } }),
}, shine)

local tagline = text({
	name = "Tagline",
	text = "B U I L D   A   C H A M P I O N",
	font = Enum.Font.Oswald,
	size = 20,
	color = C.textSecondary,
	frame = UDim2.new(1, 0, 0, 26),
	position = UDim2.new(0, 0, 0, 196),
	transparency = 1,
	z = 6,
}, logo)

-- Championship belt progress
local BELT_W, BELT_H, PLATE_W = 520, 34, 92
local belt = new("Frame", {
	Name = "Belt",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 262),
	Size = UDim2.new(0, BELT_W, 0, BELT_H),
	BackgroundColor3 = C.bgCardLight,
	BackgroundTransparency = 1,
	ZIndex = 6,
}, center)
local strap = new("Frame", {
	Name = "Strap",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundColor3 = C.bgCardLight,
	ZIndex = 6,
}, belt)
corner(strap, 8)
new("UIStroke", { Color = C.border, Thickness = 1.5, Transparency = 0.1 }, strap)
gradient(strap, { { 0, Color3.fromRGB(58, 50, 56) }, { 0.5, Color3.fromRGB(34, 30, 36) }, { 1, Color3.fromRGB(22, 19, 24) } }, 90)
-- stitching along the leather
for _, y in ipairs({ 4, 21 }) do
	for i = 0, 46 do
		new("Frame", {
			Name = "Stitch",
			Position = UDim2.new(0, 10 + i * 11, 0, y),
			Size = UDim2.new(0, 6, 0, 1),
			BackgroundColor3 = C.gold,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 7,
		}, strap)
	end
end
local HALF = (BELT_W - PLATE_W) / 2 - 6
local fills = {}
for side, anchorX in pairs({ left = 1, right = 0 }) do
	local fill = new("Frame", {
		Name = "Fill_" .. side,
		AnchorPoint = Vector2.new(anchorX, 0.5),
		Position = UDim2.new(0.5, side == "left" and -PLATE_W / 2 + 4 or PLATE_W / 2 - 4, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 16),
		BackgroundColor3 = C.gold,
		ZIndex = 8,
	}, strap)
	corner(fill, 5)
	gradient(fill, { { 0, C.goldBright }, { 0.5, C.gold }, { 1, Color3.fromRGB(160, 120, 36) } }, 90)
	fills[side] = fill
end
local plateGlow = new("Frame", {
	Name = "PlateGlow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, PLATE_W + 60, 0, 90),
	BackgroundColor3 = C.goldBright,
	BackgroundTransparency = 0.88,
	ZIndex = 6,
}, belt)
corner(plateGlow, UDim.new(1, 0))
local plate = new("Frame", {
	Name = "Plate",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, PLATE_W, 0, 50),
	BackgroundColor3 = C.gold,
	ZIndex = 9,
}, belt)
corner(plate, 12)
local plateStroke = new("UIStroke", { Color = C.goldBright, Thickness = 2, Transparency = 0.15 }, plate)
gradient(plate, { { 0, C.goldBright }, { 0.5, C.gold }, { 1, Color3.fromRGB(150, 112, 32) } }, 135)
local plateInner = new("Frame", {
	Name = "Inner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -10, 1, -10),
	BackgroundTransparency = 1,
	ZIndex = 10,
}, plate)
corner(plateInner, 8)
new("UIStroke", { Color = C.textOnGold, Thickness = 1, Transparency = 0.7 }, plateInner)
local percentLabel = text({
	name = "Percent",
	text = "0%",
	font = Enum.Font.GothamBlack,
	size = 20,
	color = C.textOnGold,
	frame = UDim2.fromScale(1, 1),
	z = 11,
}, plate)
-- belt gems on each side of the plate
for _, dx in ipairs({ -PLATE_W / 2 - 14, PLATE_W / 2 + 14 }) do
	local gem = new("Frame", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, dx, 0.5, 0),
		Size = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = C.crimsonBright,
		Rotation = 45,
		ZIndex = 9,
	}, belt)
	corner(gem, 3)
	new("UIStroke", { Color = C.goldBright, Thickness = 1.5 }, gem)
end

local statusLabel = text({
	name = "Status",
	text = STATUS_LINES[1],
	size = 16,
	color = C.textSecondary,
	frame = UDim2.new(1, 0, 0, 22),
	position = UDim2.new(0, 0, 0, 318),
	z = 6,
}, center)

-- ------------------------------------------------------------
-- Crowd silhouettes + camera flashes + ring ropes (foreground)
-- ------------------------------------------------------------
local crowd = new("Frame", {
	Name = "Crowd",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0.3, 0),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 7,
}, root)
local rng = Random.new(20250929)
for row, def in ipairs({
	{ count = 30, head = 26, shoulders = 64, base = 0.78, color = Color3.fromRGB(17, 15, 19), z = 7 },
	{ count = 22, head = 36, shoulders = 92, base = 1.0, color = Color3.fromRGB(8, 7, 10), z = 9 },
}) do
	for i = 0, def.count - 1 do
		local x = (i + 0.5 + rng:NextNumber(-0.3, 0.3)) / def.count
		local s = rng:NextNumber(0.85, 1.15)
		local person = new("Frame", {
			Name = "Fan",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(x, 0, def.base, rng:NextInteger(-6, 6)),
			Size = UDim2.new(0, math.floor(def.shoulders * s), 0, math.floor(def.head * s * 2.6)),
			BackgroundTransparency = 1,
			ZIndex = def.z,
		}, crowd)
		local shoulders = new("Frame", {
			Name = "Body",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 0, 0.55, 0),
			BackgroundColor3 = def.color,
			BorderSizePixel = 0,
			ZIndex = def.z,
		}, person)
		corner(shoulders, UDim.new(0.45, 0))
		local head = new("Frame", {
			Name = "Head",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, rng:NextInteger(-3, 3), 0.02, 0),
			Size = UDim2.new(0, math.floor(def.head * s), 0, math.floor(def.head * s)),
			BackgroundColor3 = def.color,
			BorderSizePixel = 0,
			ZIndex = def.z,
		}, person)
		corner(head, UDim.new(1, 0))
	end
end

local function cameraFlash()
	local size = rng:NextInteger(5, 9)
	local x, y = rng:NextNumber(0.02, 0.98), rng:NextNumber(0.12, 0.6)
	local glow = new("Frame", {
		Name = "FlashGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(x, 0, y, 0),
		Size = UDim2.new(0, size * 5, 0, size * 5),
		BackgroundColor3 = Color3.fromRGB(255, 246, 225),
		BackgroundTransparency = 0.72,
		ZIndex = 8,
	}, crowd)
	corner(glow, UDim.new(1, 0))
	local core = new("Frame", {
		Name = "Flash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, size, 0, size),
		BackgroundColor3 = C.white,
		ZIndex = 8,
	}, glow)
	corner(core, UDim.new(1, 0))
	tween(glow, 0.35, { BackgroundTransparency = 1, Size = UDim2.new(0, size * 9, 0, size * 9) })
	tween(core, 0.3, { BackgroundTransparency = 1 })
	task.delay(0.4, function()
		glow:Destroy()
	end)
end

-- Ring ropes in the foreground (red / white / blue in the HUD palette)
for index, def in ipairs({
	{ y = 0.705, color = C.crimsonBright, dark = C.crimson },
	{ y = 0.765, color = C.textPrimary, dark = Color3.fromRGB(150, 144, 136) },
	{ y = 0.825, color = C.steelBright, dark = C.steel },
}) do
	local rope = new("Frame", {
		Name = "Rope" .. index,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, def.y, 0),
		Size = UDim2.new(1.02, 0, 0, 7),
		BackgroundColor3 = def.color,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, root)
	corner(rope, UDim.new(1, 0))
	gradient(rope, { { 0, def.color }, { 0.45, def.color }, { 1, def.dark } }, 90)
	-- rope shadow on the crowd
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.new(0, 0, 1, 2),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = C.black,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, rope)
end

-- Vignette + bottom scrim for text legibility
for _, def in ipairs({
	{ name = "VignetteTop", anchor = Vector2.new(0, 0), pos = UDim2.new(0, 0, 0, 0), size = UDim2.new(1, 0, 0.25, 0), rot = 90, seq = { { 0, 0.35 }, { 1, 1 } } },
	{ name = "VignetteLeft", anchor = Vector2.new(0, 0), pos = UDim2.new(0, 0, 0, 0), size = UDim2.new(0.18, 0, 1, 0), rot = 0, seq = { { 0, 0.4 }, { 1, 1 } } },
	{ name = "VignetteRight", anchor = Vector2.new(1, 0), pos = UDim2.new(1, 0, 0, 0), size = UDim2.new(0.18, 0, 1, 0), rot = 180, seq = { { 0, 0.4 }, { 1, 1 } } },
	{ name = "BottomScrim", anchor = Vector2.new(0, 1), pos = UDim2.new(0, 0, 1, 0), size = UDim2.new(1, 0, 0.2, 0), rot = 270, seq = { { 0, 0.15 }, { 1, 1 } } },
}) do
	local frame = new("Frame", {
		Name = def.name,
		AnchorPoint = def.anchor,
		Position = def.pos,
		Size = def.size,
		BackgroundColor3 = C.black,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, root)
	gradient(frame, { { 0, C.black }, { 1, C.black } }, def.rot, numberSeq(def.seq))
end

-- Pro tip pill
local tipPill = new("Frame", {
	Name = "Tip",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -58),
	Size = UDim2.new(0, 0, 0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.2,
	ZIndex = 12,
}, root)
corner(tipPill, UDim.new(1, 0))
new("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.2 }, tipPill)
new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 20) }, tipPill)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 12),
}, tipPill)
text({
	name = "Caption",
	text = "PRO TIP",
	font = Enum.Font.Oswald,
	size = 17,
	color = C.gold,
	frame = UDim2.new(0, 0, 1, 0),
	autoSize = Enum.AutomaticSize.X,
	order = 1,
	z = 13,
}, tipPill)
local tipLabel = text({
	name = "TipText",
	text = TIPS[rng:NextInteger(1, #TIPS)],
	size = 15,
	color = C.textPrimary,
	frame = UDim2.new(0, 0, 1, 0),
	autoSize = Enum.AutomaticSize.X,
	order = 2,
	z = 13,
}, tipPill)

-- Credit
local credit = new("Frame", {
	Name = "Credit",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.new(0, 0, 0, 22),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	ZIndex = 12,
}, root)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 10),
}, credit)
for index, def in ipairs({
	{ kind = "line" },
	{ text = "A GAME BY", font = Enum.Font.Gotham, size = 13, color = C.textSecondary },
	{ text = "HENYTE", font = Enum.Font.GothamBlack, size = 15, color = C.gold },
	{ kind = "line" },
}) do
	if def.kind == "line" then
		new("Frame", {
			Name = "Line",
			Size = UDim2.new(0, 36, 0, 1),
			BackgroundColor3 = C.gold,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ZIndex = 12,
		}, credit)
	else
		text({
			name = def.text == "HENYTE" and "Author" or "By",
			text = def.text,
			font = def.font,
			size = def.size,
			color = def.color,
			frame = UDim2.new(0, 0, 1, 0),
			autoSize = Enum.AutomaticSize.X,
			order = index,
			z = 12,
		}, credit)
	end
end

-- Skip (appears after a few seconds, like every big game)
local skipButton = new("TextButton", {
	Name = "SkipButton",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -18),
	Size = UDim2.new(0, 104, 0, 36),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.25,
	AutoButtonColor = false,
	Font = Enum.Font.GothamBold,
	Text = "SKIP  ›",
	TextSize = 14,
	TextColor3 = C.textPrimary,
	Visible = false,
	ZIndex = 14,
}, root)
corner(skipButton, UDim.new(1, 0))
new("UIStroke", { Color = C.border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skipButton)

-- Impact flash + final dip to black
local flash = new("Frame", {
	Name = "ImpactFlash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 248, 232),
	BackgroundTransparency = 1,
	ZIndex = 18,
}, root)
local dip = new("Frame", {
	Name = "Dip",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.black,
	BackgroundTransparency = 1,
	ZIndex = 20,
}, gui)

-- Announcer intro (shown when loading completes)
local intro = new("Frame", {
	Name = "Introducing",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.42, 0),
	Size = UDim2.new(0, 900, 0, 220),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 15,
}, root)
local introScale = new("UIScale", { Scale = 1.25 }, intro)
local introCaption = text({
	name = "Caption",
	text = "I N T R O D U C I N G",
	font = Enum.Font.Oswald,
	size = 26,
	color = C.gold,
	frame = UDim2.new(1, 0, 0, 32),
	position = UDim2.new(0, 0, 0, 20),
	z = 16,
}, intro)
local introName = text({
	name = "Name",
	text = "",
	font = Enum.Font.GothamBlack,
	size = 64,
	color = C.white,
	frame = UDim2.new(1, 0, 0, 76),
	position = UDim2.new(0, 0, 0, 62),
	z = 16,
}, intro)
gradient(introName, { { 0, C.textPrimary }, { 0.6, C.goldBright }, { 1, C.gold } }, 90)
local introSub = text({
	name = "Sub",
	text = "",
	font = Enum.Font.GothamBold,
	size = 18,
	color = C.textSecondary,
	rich = true,
	frame = UDim2.new(1, 0, 0, 24),
	position = UDim2.new(0, 0, 0, 150),
	z = 16,
}, intro)

-- ------------------------------------------------------------
-- Responsive scale
-- ------------------------------------------------------------
local function applyScale()
	local size = viewportSize()
	local s = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.3)
	centerScale.Scale = s
	introScale.Scale = s
	tipPill.Visible = size.Y >= 420
	tipLabel.TextSize = size.X < 900 and 13 or 15
end
applyScale()
local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
end

-- ------------------------------------------------------------
-- Intro animation
-- ------------------------------------------------------------
local function shake(duration, strength)
	task.spawn(function()
		local t = 0
		while t < duration do
			local falloff = 1 - t / duration
			root.Position = UDim2.new(0, rng:NextInteger(-strength, strength) * falloff, 0, rng:NextInteger(-strength, strength) * falloff)
			t += task.wait(1 / 30)
		end
		root.Position = UDim2.new()
	end)
end

local function impact(strength)
	flash.BackgroundTransparency = 0.8
	tween(flash, 0.35, { BackgroundTransparency = 1 })
	shake(0.3, strength)
end

task.spawn(function()
	task.wait(0.15)
	-- "COACH" fades in, then "ACADEMY" slams down
	tween(coachWord, 0.35, { TextTransparency = 0 })
	task.wait(0.25)
	tween(logoScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(title, 0.18, { TextTransparency = 0 })
	tween(titleShadow, 0.18, { TextTransparency = 0.55 })
	task.wait(0.2)
	impact(8)
	tween(tagline, 0.5, { TextTransparency = 0 })
	-- shine sweep, repeating
	shine.TextTransparency = 0
	while gui.Parent do
		shineGradient.Offset = Vector2.new(-1.2, 0)
		tween(shineGradient, 1.1, { Offset = Vector2.new(1.2, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(3.2)
	end
end)

-- camera flashes in the crowd
task.spawn(function()
	while gui.Parent do
		cameraFlash()
		if rng:NextNumber() < 0.3 then
			task.wait(0.06)
			cameraFlash() -- occasional double pop
		end
		task.wait(rng:NextNumber(0.12, 0.5))
	end
end)

-- plate glow breathing
tween(plateGlow, 1.4, { BackgroundTransparency = 0.95, Size = UDim2.new(0, PLATE_W + 90, 0, 110) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- rotating status lines and tips
task.spawn(function()
	local index = 1
	while gui.Parent and player:GetAttribute("CoachIntro") == "loading" do
		task.wait(1.3)
		index = index % #STATUS_LINES + 1
		if statusLabel.Text ~= "Loading your academy…" then
			statusLabel.Text = STATUS_LINES[index]
		end
	end
end)
task.spawn(function()
	while gui.Parent do
		task.wait(6)
		tipLabel.Text = TIPS[rng:NextInteger(1, #TIPS)]
	end
end)

-- ------------------------------------------------------------
-- Real loading progress
-- ------------------------------------------------------------
local target = 0.06
local shown = 0
local finished = false
local skipped = false
local profileInfo = nil

local function setProgress(value)
	shown = value
	local width = math.floor(HALF * value + 0.5)
	fills.left.Size = UDim2.new(0, width, 0, 16)
	fills.right.Size = UDim2.new(0, width, 0, 16)
	percentLabel.Text = string.format("%d%%", math.floor(value * 100 + 0.5))
end
setProgress(0)

task.spawn(function()
	while not finished do
		local dt = task.wait(1 / 30)
		if shown < target then
			-- eases toward the real target, never faster than ~55%/s, never backwards
			setProgress(math.min(target, shown + math.max(dt * 0.25, (target - shown) * math.min(1, dt * 6)), shown + dt * 0.55))
		end
	end
end)

local startedAt = os.clock()
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	target = 0.45

	-- preload fonts/images used by this screen + configured sounds
	local preload = { gui }
	local modules = ReplicatedStorage:WaitForChild("Modules", 10)
	local sfxModule = modules and modules:WaitForChild("Sfx", 5)
	local Sfx = nil
	if sfxModule then
		local ok, result = pcall(require, sfxModule)
		if ok then
			Sfx = result
			for _, sound in ipairs(Sfx.preloadList()) do
				table.insert(preload, sound)
			end
			Sfx.music("LoadingMusic")
		end
	end
	local total = #preload
	local done = 0
	pcall(function()
		ContentProvider:PreloadAsync(preload, function()
			done += 1
			target = 0.45 + 0.3 * (done / math.max(1, total))
		end)
	end)
	target = 0.75

	-- wait for the player's profile (the server loads it from the DataStore)
	statusLabel.Text = "Loading your academy…"
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	local snapshotRemote = remotes and remotes:WaitForChild("PanelSnapshot", 10)
	local deadline = os.clock() + 15
	while snapshotRemote and os.clock() < deadline and not skipped do
		local ok, snapshot = pcall(function()
			return snapshotRemote:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			profileInfo = snapshot
			break
		end
		task.wait(0.5)
	end
	target = 1

	while shown < 1 and not skipped do
		task.wait(1 / 30)
	end
	local remaining = MIN_SHOW_TIME - (os.clock() - startedAt)
	if remaining > 0 and not skipped then
		task.wait(remaining)
	end
	finished = true
	setProgress(1)
	if Sfx then
		Sfx.play("Bell")
	end
	statusLabel.Text = "READY"
	statusLabel.TextColor3 = C.goldBright
	statusLabel.Font = Enum.Font.GothamBold
	plateStroke.Thickness = 3
	tween(plate, 0.12, { Size = UDim2.new(0, PLATE_W + 10, 0, 56) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	impact(4)
	player:SetAttribute("CoachIntroLoaded", true)
end)

-- ------------------------------------------------------------
-- Finish: announcer intro -> dip to black -> title screen
-- ------------------------------------------------------------
local function tierLine(snapshot)
	local stars, name = 1, "Local Coach"
	local ok, DataSchema = pcall(function()
		return require(ReplicatedStorage.Modules.DataSchema)
	end)
	local tiers = ok and DataSchema.CoachReputationTiers or {}
	-- tier from the reputation value itself (the stored index can lag behind)
	local index = snapshot.coachReputationTier or 1
	for i, tier in ipairs(tiers) do
		if (snapshot.reputacija or 0) >= (tier.winsRequired or 0) then
			index = math.max(index, i)
		end
	end
	local tier = tiers[index]
	if tier then
		stars, name = tier.stars or stars, tier.name or name
	end
	stars = math.clamp(stars, 1, 5)
	return string.format('<font color="#D4AF37">%s</font><font color="#6A5E48">%s</font>   %s',
		string.rep("★", stars), string.rep("☆", 5 - stars), string.upper(name))
end

local function finishIntro()
	if not gui.Parent then
		return
	end
	local name = profileInfo and profileInfo.academyName
	local isNew = not profileInfo or (name == nil or name == "" or name == "Coach Academy") and #(profileInfo.studentsList or {}) == 0
	if isNew or not name or name == "" then
		introName.Text = "THE NEXT CHAMPION COACH"
		introSub.Text = "Your story starts now."
	else
		introName.Text = name
		introSub.Text = tierLine(profileInfo)
	end
	if not skipped then
		tween(center, 0.25, { Position = UDim2.new(0.5, 0, 0.38, 0) })
		for _, label in ipairs({ coachWord, title, titleShadow, shine, tagline, statusLabel, percentLabel }) do
			tween(label, 0.25, { TextTransparency = 1 })
		end
		task.wait(0.25)
		center.Visible = false
		intro.Visible = true
		introCaption.TextTransparency = 1
		introName.TextTransparency = 1
		introSub.TextTransparency = 1
		tween(introCaption, 0.3, { TextTransparency = 0 })
		task.wait(0.35)
		tween(introScale, 0.3, { Scale = introScale.Scale / 1.25 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		tween(introName, 0.2, { TextTransparency = 0 })
		task.wait(0.2)
		impact(10)
		tween(introSub, 0.4, { TextTransparency = 0 })
		task.wait(1.25)
	end

	-- hand over to the title screen (it prepares the camera underneath us)
	player:SetAttribute("CoachIntro", "title")
	local waitUntil = os.clock() + 3
	while player:GetAttribute("CoachTitleReady") ~= true and os.clock() < waitUntil do
		task.wait(0.05)
	end
	tween(dip, 0.3, { BackgroundTransparency = 0 })
	task.wait(0.32)
	root.Visible = false
	tween(dip, 0.55, { BackgroundTransparency = 1 })
	task.wait(0.6)
	gui:Destroy()
end

task.delay(SKIP_AFTER, function()
	if gui.Parent and not finished then
		skipButton.Visible = true
		skipButton.TextTransparency = 1
		skipButton.BackgroundTransparency = 1
		tween(skipButton, 0.3, { TextTransparency = 0, BackgroundTransparency = 0.25 })
	end
end)
skipButton.MouseEnter:Connect(function()
	tween(skipButton, 0.15, { BackgroundColor3 = C.bgCardLight })
end)
skipButton.MouseLeave:Connect(function()
	tween(skipButton, 0.15, { BackgroundColor3 = C.bg })
end)
skipButton.Activated:Connect(function()
	skipped = true
	skipButton.Visible = false
end)

task.spawn(function()
	while not player:GetAttribute("CoachIntroLoaded") and not skipped do
		task.wait(0.05)
	end
	finishIntro()
end)
