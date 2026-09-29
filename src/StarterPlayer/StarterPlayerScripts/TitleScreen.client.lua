--[[
	TitleScreen
	Cinematic title after the loading screen: the camera slowly orbits the player's gym,
	letterbox bars, the game logo, a big PLAY button, music/sound toggles and a
	"Welcome back" card with what is waiting for the player (real data from ClientState).

	The HUD, player list and movement stay hidden until PLAY. Hand-over with the loading
	screen goes through the player attribute "CoachIntro" ("loading" -> "title" -> "playing").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local panelsFolder = Modules:WaitForChild("Panels")
local Kit = require(panelsFolder:WaitForChild("PanelKit"))
local State = require(panelsFolder:WaitForChild("ClientState"))
local Sfx = require(Modules:WaitForChild("Sfx"))
local TrainingConfig = require(Modules:WaitForChild("TrainingConfig"))
local SponsorConfig = require(Modules:WaitForChild("SponsorConfig"))
local TournamentConfig = require(Modules:WaitForChild("TournamentConfig"))

local C = Kit.Colors
local tween = Kit.tween

State.start()

-- ------------------------------------------------------------
-- Hide the game UI until PLAY
-- ------------------------------------------------------------
local hiddenGuis = {}
local playing = false

local function hideGui(name)
	task.spawn(function()
		local gui = playerGui:WaitForChild(name, 15)
		if gui and not playing and gui:IsA("ScreenGui") then
			hiddenGuis[gui] = gui.Enabled
			gui.Enabled = false
		end
	end)
end
hideGui("MainHUD_Premium")

local CORE_TYPES = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu }
local coreStates = {}
for _, coreType in ipairs(CORE_TYPES) do
	pcall(function()
		coreStates[coreType] = StarterGui:GetCoreGuiEnabled(coreType)
		StarterGui:SetCoreGuiEnabled(coreType, false)
	end)
end

local controls = nil
task.spawn(function()
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
	if playerModule and not playing then
		local ok, module = pcall(require, playerModule)
		if ok and module and module.GetControls then
			controls = module:GetControls()
			controls:Disable()
		end
	end
end)

-- ------------------------------------------------------------
-- Cinematic camera: slow orbit around the ring + colour grade
-- ------------------------------------------------------------
local camera = Workspace.CurrentCamera
local gym = Workspace:FindFirstChild("GymLayout")
local ring = gym and gym:FindFirstChild("RingPlaceholder")
local focus = ring and ring.Position or Vector3.new(0, 2, 0)
local ORBIT_RADIUS, ORBIT_HEIGHT, ORBIT_SPEED = 22, 10, 0.05
local angle = math.rad(70)

local savedCamera = { type = camera.CameraType, fov = camera.FieldOfView }
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 50
local function placeCamera()
	local offset = Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
	camera.CFrame = CFrame.lookAt(focus + offset, focus + Vector3.new(0, 1.5, 0))
end
placeCamera()
local orbit = RunService.RenderStepped:Connect(function(dt)
	angle += dt * ORBIT_SPEED
	placeCamera()
end)

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "CoachTitleGrade"
grade.Contrast = 0.15
grade.Saturation = -0.2
grade.Brightness = -0.03
grade.TintColor = Color3.fromRGB(255, 238, 220)
grade.Parent = Lighting

local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
local savedDof = nil
if dof then
	savedDof = { dof.Enabled, dof.FarIntensity, dof.FocusDistance, dof.InFocusRadius, dof.NearIntensity }
	dof.Enabled = true
	dof.FarIntensity = 0.45
	dof.FocusDistance = ORBIT_RADIUS
	dof.InFocusRadius = 12
	dof.NearIntensity = 0.25
end

-- ------------------------------------------------------------
-- UI
-- ------------------------------------------------------------
local gui = Kit.create("ScreenGui", {
	Name = "CoachTitleScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 90,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local LETTERBOX = 0.085
local bars = {}
for _, def in ipairs({ { name = "TopBar", anchor = Vector2.new(0, 0), pos = UDim2.new(0, 0, 0, 0) }, { name = "BottomBar", anchor = Vector2.new(0, 1), pos = UDim2.new(0, 0, 1, 0) } }) do
	bars[def.name] = Kit.create("Frame", {
		Name = def.name,
		AnchorPoint = def.anchor,
		Position = def.pos,
		Size = UDim2.new(1, 0, LETTERBOX, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = gui,
	})
end

local content = Kit.create("Frame", {
	Name = "Content",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = gui,
})

-- left scrim so the logo reads over any 3D scene
local scrim = Kit.create("Frame", {
	Name = "Scrim",
	Size = UDim2.new(0.62, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	Parent = content,
})
Kit.create("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = scrim,
})

-- Title block (designed at 560 x 400)
local titleBlock = Kit.create("Frame", {
	Name = "TitleBlock",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0.065, 0, 0.5, 0),
	Size = UDim2.new(0, 560, 0, 400),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = content,
})
local titleScale = Kit.create("UIScale", { Scale = 1, Parent = titleBlock })

Kit.label({
	parent = titleBlock,
	name = "Coach",
	text = "C  O  A  C  H",
	font = Enum.Font.Oswald,
	textSize = 26,
	color = C.gold,
	size = UDim2.new(1, 0, 0, 30),
	position = UDim2.new(0, 4, 0, 0),
	zIndex = 3,
})
Kit.label({
	parent = titleBlock,
	name = "TitleShadow",
	text = "ACADEMY",
	font = Enum.Font.GothamBlack,
	textSize = 96,
	color = Color3.new(0, 0, 0),
	transparency = 0.55,
	size = UDim2.new(1, 0, 0, 100),
	position = UDim2.new(0, 0, 0, 38),
	zIndex = 2,
})
local title = Kit.label({
	parent = titleBlock,
	name = "Title",
	text = "ACADEMY",
	font = Enum.Font.GothamBlack,
	textSize = 96,
	color = Color3.new(1, 1, 1),
	size = UDim2.new(1, 0, 0, 100),
	position = UDim2.new(0, 0, 0, 32),
	zIndex = 3,
})
Kit.create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.goldBright),
		ColorSequenceKeypoint.new(0.55, C.gold),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 112, 32)),
	}),
	Rotation = 90,
	Parent = title,
})
Kit.label({
	parent = titleBlock,
	name = "Tagline",
	text = "Train fighters. Build your gym. Win the belt.",
	textSize = 18,
	color = C.textPrimary,
	transparency = 0.1,
	size = UDim2.new(1, 0, 0, 24),
	position = UDim2.new(0, 4, 0, 140),
	zIndex = 3,
})

-- PLAY
local playGlow = Kit.create("Frame", {
	Name = "PlayGlow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 154, 0, 232),
	Size = UDim2.new(0, 330, 0, 96),
	BackgroundColor3 = C.goldBright,
	BackgroundTransparency = 0.82,
	ZIndex = 2,
	Parent = titleBlock,
})
Kit.corner(playGlow, UDim.new(1, 0))
local playButton = Kit.create("TextButton", {
	Name = "PlayButton",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 154, 0, 232),
	Size = UDim2.new(0, 300, 0, 72),
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "",
	ZIndex = 4,
	Parent = titleBlock,
})
Kit.corner(playButton, 16)
local playStroke = Kit.stroke(playButton, C.goldBright, 2, 0.1)
Kit.create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.goldBright),
		ColorSequenceKeypoint.new(1, C.gold),
	}),
	Rotation = 90,
	Parent = playButton,
})
local playScale = Kit.create("UIScale", { Scale = 1, Parent = playButton })
local playRow = Kit.create("Frame", {
	Name = "Row",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = playButton,
})
Kit.list(playRow, 14, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
Kit.label({
	parent = playRow,
	name = "Text",
	text = "PLAY",
	font = Enum.Font.GothamBlack,
	textSize = 32,
	color = C.textOnGold,
	size = UDim2.new(0, 0, 0, 36),
	autoSize = Enum.AutomaticSize.X,
	order = 2,
	zIndex = 5,
})
local keyHint = Kit.label({
	parent = titleBlock,
	name = "KeyHint",
	text = "or press Enter",
	textSize = 13,
	color = C.textSecondary,
	size = UDim2.new(0, 300, 0, 16),
	position = UDim2.new(0, 4, 0, 276),
	align = Enum.TextXAlignment.Center,
	zIndex = 3,
})

-- Sound toggles
local toggleRow = Kit.create("Frame", {
	Name = "Toggles",
	Size = UDim2.new(0, 300, 0, 36),
	Position = UDim2.new(0, 4, 0, 306),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = titleBlock,
})
Kit.list(toggleRow, 10, Enum.FillDirection.Horizontal)
local function makeToggle(groupName, label, order)
	local button = Kit.button({
		parent = toggleRow,
		name = groupName .. "Toggle",
		text = "",
		variant = "ghost",
		size = UDim2.new(0.5, -5, 1, 0),
		textSize = 14,
		order = order,
		zIndex = 3,
		onClick = function() end,
	})
	local function refresh()
		local on = Sfx.isEnabled(groupName)
		button.SetText(string.format("%s  %s", label, on and "ON" or "OFF"))
	end
	button.Instance.Activated:Connect(function()
		Sfx.setEnabled(groupName, not Sfx.isEnabled(groupName))
		refresh()
	end)
	refresh()
	return button
end
makeToggle("Music", "MUSIC", 1)
makeToggle("Sfx", "SOUND", 2)

-- Welcome card (right side)
local card = Kit.create("Frame", {
	Name = "WelcomeCard",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0.94, 0, 0.5, 0),
	Size = UDim2.new(0, 340, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.bgCard,
	BackgroundTransparency = 0.08,
	ZIndex = 2,
	Parent = content,
})
Kit.corner(card, 16)
Kit.stroke(card, C.gold, 1, 0.55)
Kit.padding(card, 20, 22, 20, 22)
Kit.list(card, 10)
local cardScale = Kit.create("UIScale", { Scale = 1, Parent = card })

local welcomeCaption = Kit.label({
	parent = card,
	name = "Caption",
	text = "WELCOME BACK",
	font = Enum.Font.Oswald,
	textSize = 17,
	color = C.gold,
	size = UDim2.new(1, 0, 0, 20),
	order = 1,
	zIndex = 3,
})
local academyLabel = Kit.label({
	parent = card,
	name = "Academy",
	text = "",
	bold = true,
	textSize = 22,
	size = UDim2.new(1, 0, 0, 26),
	order = 2,
	zIndex = 3,
})
local tierLabel = Kit.label({
	parent = card,
	name = "Tier",
	text = "",
	rich = true,
	textSize = 14,
	color = C.textSecondary,
	size = UDim2.new(1, 0, 0, 18),
	order = 3,
	zIndex = 3,
})
Kit.create("Frame", {
	Name = "Divider",
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = C.border,
	BorderSizePixel = 0,
	LayoutOrder = 4,
	ZIndex = 3,
	Parent = card,
})
local listCaption = Kit.label({
	parent = card,
	name = "ListCaption",
	text = "WAITING FOR YOU",
	font = Enum.Font.Oswald,
	textSize = 15,
	color = C.textSecondary,
	size = UDim2.new(1, 0, 0, 18),
	order = 5,
	zIndex = 3,
})
local itemsHolder = Kit.create("Frame", {
	Name = "Items",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 6,
	ZIndex = 3,
	Parent = card,
})
Kit.list(itemsHolder, 8)
local moneyRow = Kit.create("Frame", {
	Name = "Money",
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.3,
	LayoutOrder = 7,
	ZIndex = 3,
	Parent = card,
})
Kit.corner(moneyRow, 10)
Kit.label({
	parent = moneyRow,
	name = "Caption",
	text = "BALANCE",
	font = Enum.Font.Oswald,
	textSize = 15,
	color = C.textSecondary,
	size = UDim2.new(0.5, 0, 1, 0),
	position = UDim2.new(0, 14, 0, 0),
	zIndex = 4,
})
local moneyLabel = Kit.label({
	parent = moneyRow,
	name = "Value",
	text = "",
	font = Enum.Font.GothamBlack,
	textSize = 20,
	color = C.goldBright,
	align = Enum.TextXAlignment.Right,
	size = UDim2.new(0.5, -14, 1, 0),
	position = UDim2.new(0.5, 0, 0, 0),
	zIndex = 4,
})

local maxItems = 3
local function addItem(order, icon, iconColor, textValue)
	local row = Kit.create("Frame", {
		Name = "Item" .. order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		ZIndex = 3,
		Parent = itemsHolder,
	})
	local badge = Kit.create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 26, 0, 26),
		BackgroundColor3 = iconColor,
		BackgroundTransparency = 0.8,
		ZIndex = 3,
		Parent = row,
	})
	Kit.corner(badge, UDim.new(1, 0))
	Kit.stroke(badge, iconColor, 1, 0.4)
	Kit.label({
		parent = badge,
		name = "Glyph",
		text = icon,
		bold = true,
		textSize = 13,
		color = iconColor,
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		zIndex = 4,
	})
	Kit.label({
		parent = row,
		name = "Text",
		text = textValue,
		rich = true,
		textSize = 14,
		wrap = true,
		size = UDim2.new(1, -38, 1, 0),
		position = UDim2.new(0, 38, 0, 0),
		zIndex = 3,
	})
end

local function renderCard()
	for _, child in ipairs(itemsHolder:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local s = State.get()
	local now = State.now()
	local reputation = s.reputation or {}
	local stars = math.clamp(reputation.stars or 1, 1, 5)
	academyLabel.Text = s.academy and s.academy.academyName or "Coach Academy"
	tierLabel.Text = Kit.starsRich(stars) .. "   " .. string.upper(reputation.tierName or "Local Coach")
	moneyLabel.Text = Kit.formatMoney(s.money or 0)

	local members, rested, injured = 0, 0, 0
	for _, student in ipairs(s.students or {}) do
		if student.karjerosStadija ~= "Trial" then
			members += 1
			if student.injured then
				injured += 1
			elseif (student.fatigue or 0) < TrainingConfig.FatigueTrainingBlockThreshold * 0.5 then
				rested += 1
			end
		end
	end
	local isNew = members == 0 and #(s.students or {}) == 0

	welcomeCaption.Text = isNew and "WELCOME, COACH" or "WELCOME BACK"
	listCaption.Text = isNew and "YOUR FIRST STEPS" or "WAITING FOR YOU"

	local order = 0
	local function push(icon, color, textValue)
		if order >= maxItems then
			return
		end
		order += 1
		addItem(order, icon, color, textValue)
	end

	if isNew then
		push("1", C.gold, "Recruit your first fighter")
		push("2", C.gold, "Train them at the gym stations")
		push("3", C.gold, "Win your first fight in the ring")
		return
	end

	local readyIncome, readyCount = 0, 0
	for _, entry in ipairs(s.sponsor and s.sponsor.sponsors or {}) do
		local sponsor = SponsorConfig.Sponsors[entry.configIndex]
		if sponsor and (entry.nextCollectAt or 0) <= now and (entry.expiresAt or math.huge) > now then
			readyIncome += sponsor.incomePerCycle or 0
			readyCount += 1
		end
	end
	if readyCount > 0 then
		push("$", C.goldBright, string.format("<b>%s</b> sponsor income ready", Kit.formatMoney(readyIncome)))
	end
	if rested > 0 then
		push("✓", C.steelBright, string.format("<b>%d</b> %s rested and ready", rested, rested == 1 and "fighter" or "fighters"))
	end
	if injured > 0 then
		push("+", C.crimsonBright, string.format("<b>%d</b> %s recovering from injury", injured, injured == 1 and "fighter" or "fighters"))
	end
	local lastTournament = s.tournament and s.tournament.lastTournamentAt or 0
	if now - lastTournament >= (TournamentConfig.EntryCooldown or 0) then
		push("★", C.gold, "Tournaments are open")
	end
	if order == 0 then
		push("✓", C.steelBright, "Everything is in order, Coach")
	end
end

-- ------------------------------------------------------------
-- Layout
-- ------------------------------------------------------------
local function applyLayout()
	local size = camera.ViewportSize
	if size.X < 10 then
		size = Vector2.new(1280, 720)
	end
	local s = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.25)
	local compact = size.Y < 500
	titleScale.Scale = compact and math.max(s, 0.7) or s
	cardScale.Scale = compact and 0.78 or math.max(s, 0.75)
	maxItems = compact and 2 or 3
	card.Visible = size.X >= 700
	keyHint.Visible = not UserInputService.TouchEnabled
	local letterbox = compact and 0.06 or LETTERBOX
	for _, bar in pairs(bars) do
		if not playing then
			bar.Size = UDim2.new(1, 0, letterbox, 0)
		end
	end
end
applyLayout()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)

-- Credit in the bottom letterbox bar
local creditRow = Kit.create("Frame", {
	Name = "Credit",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0.065, 0, 0.5, 0),
	Size = UDim2.new(0, 0, 0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	ZIndex = 21,
	Parent = bars.BottomBar,
})
Kit.list(creditRow, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
Kit.label({ parent = creditRow, name = "By", text = "A GAME BY", textSize = 12, color = C.textSecondary, size = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, order = 1, zIndex = 21 })
Kit.label({ parent = creditRow, name = "Author", text = "HENYTE", font = Enum.Font.GothamBlack, textSize = 14, color = C.gold, size = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, order = 2, zIndex = 21 })

-- ------------------------------------------------------------
-- PLAY
-- ------------------------------------------------------------
local function startGame()
	if playing then
		return
	end
	playing = true
	Sfx.play("Bell")
	tween(playScale, 0.08, { Scale = 0.94 })
	task.wait(0.08)
	tween(playScale, 0.12, { Scale = 1 })
	Sfx.stopMusic(1)

	-- bars close like a curtain, the world switches behind them, bars open on gameplay
	for _, bar in pairs(bars) do
		tween(bar, 0.35, { Size = UDim2.new(1, 0, 0.51, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		bar.ZIndex = 30
	end
	task.wait(0.37)
	content.Visible = false
	creditRow.Visible = false

	orbit:Disconnect()
	camera.CameraType = savedCamera.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or savedCamera.type
	camera.FieldOfView = savedCamera.fov
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	grade:Destroy()
	if dof and savedDof then
		dof.Enabled, dof.FarIntensity, dof.FocusDistance, dof.InFocusRadius, dof.NearIntensity = table.unpack(savedDof)
	end
	for guiObject, wasEnabled in pairs(hiddenGuis) do
		guiObject.Enabled = wasEnabled
	end
	for coreType, wasEnabled in pairs(coreStates) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreType, wasEnabled)
		end)
	end
	if controls then
		controls:Enable()
	end
	player:SetAttribute("CoachIntro", "playing")

	for _, bar in pairs(bars) do
		tween(bar, 0.5, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	task.wait(0.55)
	gui:Destroy()
end

playButton.MouseEnter:Connect(function()
	if Kit.isTouchOnly() then
		return
	end
	tween(playScale, 0.15, { Scale = 1.04 })
	tween(playStroke, 0.15, { Thickness = 3 })
end)
playButton.MouseLeave:Connect(function()
	tween(playScale, 0.15, { Scale = 1 })
	tween(playStroke, 0.15, { Thickness = 2 })
end)
playButton.Activated:Connect(function()
	task.spawn(startGame)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or playing or not content.Visible then
		return
	end
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		task.spawn(startGame)
	end
end)
tween(playGlow, 1.2, { BackgroundTransparency = 0.93, Size = UDim2.new(0, 360, 0, 112) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- ------------------------------------------------------------
-- Reveal (after the loading screen hands over)
-- ------------------------------------------------------------
renderCard()
State.subscribe("any", function()
	if not playing then
		renderCard()
	end
end)
State.refresh(true)
player:SetAttribute("CoachTitleReady", true)

local loadingGui = playerGui:FindFirstChild("CoachLoadingScreen")
if loadingGui then
	local deadline = os.clock() + 25
	while player:GetAttribute("CoachIntro") == "loading" and os.clock() < deadline do
		task.wait(0.05)
	end
else
	player:SetAttribute("CoachIntro", "title")
end
Sfx.music("LoadingMusic")

titleBlock.Position = UDim2.new(0.065, -40, 0.5, 0)
card.Position = UDim2.new(0.94, 40, 0.5, 0)
tween(titleBlock, 0.6, { Position = UDim2.new(0.065, 0, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
task.wait(0.15)
tween(card, 0.6, { Position = UDim2.new(0.94, 0, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
