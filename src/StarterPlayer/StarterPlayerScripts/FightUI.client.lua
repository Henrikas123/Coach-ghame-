--[[
	FightUI -- "Fight Night" TV broadcast
	  * Picker: pressing E at the ring opens FIGHT NIGHT with your fighters (OVR cards, status)
	  * Broadcast: letterbox bars with LIVE bug, tale-of-the-tape intro plates, scoreboard with
	    round pips, "ROUND 1 / FIGHT!" slams, momentum bar with play-by-play commentary,
	    corner plan between rounds (with timer), WINNER / DEFEAT card with confetti
	Server phases (FightHandler): start -> round -> corner -> ... -> result (or error).
	Events are processed in order by one worker so animations never overlap.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FightConfig = require(Modules:WaitForChild("FightConfig"))
local TrainingConfig = require(Modules:WaitForChild("TrainingConfig"))
local panelsFolder = Modules:WaitForChild("Panels")
local Kit = require(panelsFolder:WaitForChild("PanelKit"))
local State = require(panelsFolder:WaitForChild("ClientState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FightRequest = Remotes:WaitForChild("FightRequest")
local FightUpdate = Remotes:WaitForChild("FightUpdate")
local CornerChoice = Remotes:WaitForChild("CornerChoice")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = Kit.Colors
local tween = Kit.tween
State.start()

local CORNER_ICONS = { Power = "🥊", Defense = "🛡️", Stamina = "💨", Technique = "🎯" }
local STAT_LABELS = { power = "POWER", speed = "SPEED", defense = "DEFENSE", stamina = "STAMINA", technique = "TECHNIQUE" }
local GOOD_LINES = {
	"%s lands a sharp jab.",
	"%s slips a punch and fires back!",
	"Big right hand from %s!",
	"%s goes to the body.",
	"%s takes the center of the ring.",
	"Clean combination from %s!",
}
local PRESSURE_LINES = {
	"%s walks forward and lets it go.",
	"%s answers with a heavy hook!",
	"%s traps him on the ropes.",
	"%s sneaks an uppercut through.",
}

local function average(stats)
	if type(stats) ~= "table" then
		return 0
	end
	local total = 0
	for _, id in ipairs({ "power", "speed", "defense", "stamina", "technique" }) do
		total += stats[id] or 0
	end
	return math.floor(total / 5 + 0.5)
end

local function shortName(name)
	name = tostring(name or "?")
	return string.upper(name:match("(%S+)%s*$") or name)
end

-- ============================================================
-- GUI
-- ============================================================
local gui = Kit.create("ScreenGui", {
	Name = "FightGui",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 40,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local function viewportScale()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if size.X < 10 then
		size = Vector2.new(1280, 720)
	end
	return math.clamp(math.min(size.X / 1280, size.Y / 720), 0.6, 1.2)
end

-- ------------------------------------------------------------
-- Picker
-- ------------------------------------------------------------
local picker = Kit.create("Frame", {
	Name = "Picker",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
	Active = true,
	Visible = false,
	Parent = gui,
})
local pickerCard = Kit.create("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 560, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = picker,
})
Kit.corner(pickerCard, 16)
Kit.stroke(pickerCard, C.gold, 1.5, 0.3)
Kit.create("UIGradient", { Color = ColorSequence.new(C.bgCardLight, C.bg), Rotation = 90, Parent = pickerCard })
Kit.padding(pickerCard, 18, 20, 20, 20)
Kit.list(pickerCard, 10)
local pickerScale = Kit.create("UIScale", { Scale = 1, Parent = pickerCard })
local pickerHeader = Kit.create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 1, Parent = pickerCard })
Kit.label({ parent = pickerHeader, name = "Title", text = "FIGHT NIGHT", font = Enum.Font.Oswald, textSize = 32, color = C.goldBright, size = UDim2.new(1, -50, 0, 34) })
Kit.label({ parent = pickerHeader, name = "Sub", text = "Pick a fighter to send into the ring", textSize = 13, color = C.textSecondary, size = UDim2.new(1, -50, 0, 16), position = UDim2.new(0, 0, 0, 36) })
Kit.iconButton({
	parent = pickerHeader,
	name = "CloseButton",
	text = "✕",
	size = 38,
	anchor = Vector2.new(1, 0),
	position = UDim2.new(1, 0, 0, 0),
	onClick = function()
		picker.Visible = false
	end,
})
local pickerList = Kit.create("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = pickerCard })
Kit.list(pickerList, 8)
local pickerError = Kit.label({ parent = pickerCard, name = "Error", text = "", textSize = 13, color = C.crimsonBright, wrap = true, size = UDim2.new(1, 0, 0, 0), autoSize = Enum.AutomaticSize.Y, order = 3 })

local function fighterStatus(student)
	if student.injured then
		return false, "Injured"
	elseif not student.competitionReady then
		return false, "Not ready"
	elseif (student.fatigue or 0) >= TrainingConfig.FatigueTrainingBlockThreshold then
		return false, "Too tired"
	end
	return true, nil
end

local function renderPicker()
	for _, child in ipairs(pickerList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	pickerError.Text = ""
	local shown = 0
	for index, student in ipairs(State.get().students or {}) do
		if student.karjerosStadija ~= "Trial" then
			shown += 1
			local ready, reason = fighterStatus(student)
			local row = Kit.card({ parent = pickerList, name = "Fighter_" .. index, size = UDim2.new(1, 0, 0, 70), order = index, strokeColor = ready and C.gold or C.border, strokeTransparency = ready and 0.35 or 0.5 })
			Kit.ovrCard({ parent = row, student = student, position = UDim2.new(0, 12, 0.5, 0), anchor = Vector2.new(0, 0.5) })
			Kit.label({ parent = row, name = "Name", text = student.name or "?", bold = true, textSize = 15, size = UDim2.new(1, -250, 0, 20), position = UDim2.new(0, 68, 0, 14) })
			local record = student.record or {}
			Kit.label({
				parent = row,
				name = "Info",
				text = string.format("%d-%d-%d  •  %s", record.wins or 0, record.losses or 0, record.draws or 0, student.style or "Balanced"),
				textSize = 12,
				color = C.textSecondary,
				size = UDim2.new(1, -250, 0, 16),
				position = UDim2.new(0, 68, 0, 38),
			})
			Kit.button({
				parent = row,
				name = "SendButton",
				text = ready and "Send in" or reason,
				icon = ready and "🥊" or nil,
				variant = "crimson",
				enabled = ready,
				size = UDim2.new(0, 150, 0, 40),
				position = UDim2.new(1, -14, 0.5, 0),
				anchor = Vector2.new(1, 0.5),
				textSize = 14,
				onClick = function()
					FightRequest:FireServer(index)
				end,
			})
		end
	end
	if shown == 0 then
		Kit.label({ parent = pickerList, name = "Empty", text = "No fighters yet — train a client until they become a member.", textSize = 13, color = C.textSecondary, wrap = true, size = UDim2.new(1, 0, 0, 40) })
	end
end

local function openPicker()
	pickerScale.Scale = viewportScale()
	renderPicker()
	picker.Visible = true
	State.refresh()
end
State.subscribe("students", function()
	if picker.Visible then
		renderPicker()
	end
end)

-- ------------------------------------------------------------
-- Broadcast
-- ------------------------------------------------------------
local broadcast = Kit.create("Frame", { Name = "Broadcast", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
local bcScale = Kit.create("UIScale", { Scale = 1 })

local topBar = Kit.create("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0.085, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = broadcast })
local bottomBar = Kit.create("Frame", { Name = "BottomBar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.085, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = broadcast })
local bug = Kit.create("Frame", { Name = "Bug", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.03, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 6, Parent = topBar })
Kit.list(bug, 12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
Kit.label({ parent = bug, name = "Logo", text = "FIGHT NIGHT", font = Enum.Font.Oswald, textSize = 22, color = C.goldBright, size = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, order = 1, zIndex = 6 })
local liveDot = Kit.label({ parent = bug, name = "Live", text = "● LIVE", bold = true, textSize = 13, color = C.crimsonBright, size = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, order = 2, zIndex = 6 })
local tierLabel = Kit.label({ parent = topBar, name = "Tier", text = "", font = Enum.Font.Oswald, textSize = 18, color = C.textSecondary, align = Enum.TextXAlignment.Right, size = UDim2.new(0.4, 0, 1, 0), position = UDim2.new(0.97, 0, 0, 0), anchor = Vector2.new(1, 0), zIndex = 6 })
local ticker = Kit.label({ parent = bottomBar, name = "Ticker", text = "", textSize = 16, color = C.textPrimary, align = Enum.TextXAlignment.Center, size = UDim2.new(1, -40, 1, 0), position = UDim2.new(0, 20, 0, 0), zIndex = 6 })

local stageScaleHolder = Kit.create("Frame", { Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0, 1000, 0, 240), BackgroundTransparency = 1, ZIndex = 8, Parent = broadcast })
bcScale.Parent = stageScaleHolder
local stageShadow = Kit.label({ parent = stageScaleHolder, name = "Shadow", text = "", font = Enum.Font.Oswald, textSize = 96, color = Color3.new(0, 0, 0), transparency = 1, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 110), position = UDim2.new(0, 4, 0, 69), zIndex = 8 })
local stageText = Kit.label({ parent = stageScaleHolder, name = "Text", text = "", font = Enum.Font.Oswald, textSize = 96, color = C.goldBright, transparency = 1, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 110), position = UDim2.new(0, 0, 0, 65), zIndex = 9 })
local stagePunch = Kit.create("UIScale", { Scale = 1, Parent = stageText })

-- scoreboard
local scoreboard = Kit.create("Frame", { Name = "Scoreboard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.085, 10), Size = UDim2.new(0, 460, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = broadcast })
Kit.corner(scoreboard, 12)
Kit.stroke(scoreboard, C.border, 1, 0.2)
Kit.create("UIGradient", { Color = ColorSequence.new(C.bgCardLight, C.bg), Rotation = 90, Parent = scoreboard })
local scoreScale = Kit.create("UIScale", { Scale = 1, Parent = scoreboard })
local function sideBlock(isLeft)
	local block = Kit.create("Frame", { Name = isLeft and "Left" or "Right", BackgroundTransparency = 1, Size = UDim2.new(0.36, 0, 1, 0), Position = isLeft and UDim2.new(0, 14, 0, 0) or UDim2.new(1, -14, 0, 0), AnchorPoint = isLeft and Vector2.new(0, 0) or Vector2.new(1, 0), ZIndex = 7, Parent = scoreboard })
	local name = Kit.label({ parent = block, name = "Name", text = "", bold = true, textSize = 15, color = isLeft and C.goldBright or C.crimsonBright, align = isLeft and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, size = UDim2.new(1, 0, 0, 20), position = UDim2.new(0, 0, 0, 8), zIndex = 7 })
	local pips = {}
	for i = 1, FightConfig.Rounds do
		local pip = Kit.create("Frame", { Name = "Pip" .. i, Size = UDim2.new(0, 12, 0, 12), Position = isLeft and UDim2.new(0, (i - 1) * 16, 0, 34) or UDim2.new(1, -12 - (i - 1) * 16, 0, 34), BackgroundColor3 = C.border, ZIndex = 7, Parent = block })
		Kit.corner(pip, UDim.new(1, 0))
		pips[i] = pip
	end
	return { name = name, pips = pips, color = isLeft and C.goldBright or C.crimsonBright }
end
local leftSide = sideBlock(true)
local rightSide = sideBlock(false)
local roundLabel = Kit.label({ parent = scoreboard, name = "Round", text = "ROUND 1/3", font = Enum.Font.Oswald, textSize = 20, align = Enum.TextXAlignment.Center, size = UDim2.new(0.3, 0, 1, 0), position = UDim2.new(0.35, 0, 0, 0), zIndex = 7 })

-- momentum bar
local momentum = Kit.create("Frame", { Name = "Momentum", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.915, -14), Size = UDim2.new(0, 560, 0, 18), BackgroundColor3 = C.crimson, ZIndex = 6, Parent = broadcast })
Kit.corner(momentum, UDim.new(1, 0))
Kit.stroke(momentum, Color3.new(0, 0, 0), 2, 0.3)
local momentumScale = Kit.create("UIScale", { Scale = 1, Parent = momentum })
local momentumFill = Kit.create("Frame", { Name = "Fill", Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = C.gold, ZIndex = 7, Parent = momentum })
Kit.corner(momentumFill, UDim.new(1, 0))
local puck = Kit.create("Frame", { Name = "Puck", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 28, 0, 28), BackgroundColor3 = C.textPrimary, ZIndex = 8, Parent = momentum })
Kit.corner(puck, UDim.new(1, 0))
Kit.stroke(puck, Color3.new(0, 0, 0), 2, 0.2)
Kit.label({ parent = puck, name = "Glove", text = "🥊", textSize = 15, align = Enum.TextXAlignment.Center, size = UDim2.fromScale(1, 1), zIndex = 9 })

-- tale of the tape intro plates
local intro = Kit.create("Frame", { Name = "Intro", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0, 1000, 0, 300), BackgroundTransparency = 1, Visible = false, ZIndex = 8, Parent = broadcast })
local introScale = Kit.create("UIScale", { Scale = 1, Parent = intro })
local function plate(isLeft)
	local frame = Kit.create("Frame", { Name = isLeft and "PlateLeft" or "PlateRight", AnchorPoint = Vector2.new(isLeft and 1 or 0, 0.5), Position = UDim2.new(0.5, isLeft and -50 or 50, 0.5, 0), Size = UDim2.new(0, 400, 0, 250), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8, Parent = intro })
	Kit.corner(frame, 16)
	Kit.stroke(frame, isLeft and C.gold or C.crimsonBright, 2, 0.1)
	Kit.create("UIGradient", { Color = ColorSequence.new(C.bgCardLight, C.bg), Rotation = 90, Parent = frame })
	local accent = isLeft and C.goldBright or C.crimsonBright
	local align = isLeft and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	local corner = Kit.label({ parent = frame, name = "Corner", text = isLeft and "RED CORNER  •  YOUR FIGHTER" or "BLUE CORNER  •  OPPONENT", font = Enum.Font.Oswald, textSize = 15, color = accent, align = align, size = UDim2.new(1, -36, 0, 18), position = UDim2.new(0, 18, 0, 16), zIndex = 9 })
	local name = Kit.label({ parent = frame, name = "Name", text = "", font = Enum.Font.GothamBlack, textSize = 30, align = align, size = UDim2.new(1, -36, 0, 36), position = UDim2.new(0, 18, 0, 38), zIndex = 9 })
	local info = Kit.label({ parent = frame, name = "Info", text = "", textSize = 13, color = C.textSecondary, align = align, size = UDim2.new(1, -36, 0, 16), position = UDim2.new(0, 18, 0, 76), zIndex = 9 })
	local rows = {}
	for i, statId in ipairs({ "power", "speed", "defense", "stamina", "technique" }) do
		local y = 104 + (i - 1) * 26
		Kit.label({ parent = frame, name = "Stat_" .. statId, text = STAT_LABELS[statId], font = Enum.Font.Oswald, textSize = 13, color = C.textSecondary, align = align, size = UDim2.new(0, 90, 0, 18), position = isLeft and UDim2.new(0, 18, 0, y) or UDim2.new(1, -108, 0, y), zIndex = 9 })
		local track = Kit.create("Frame", { Name = "Track_" .. statId, BackgroundColor3 = C.bg, Size = UDim2.new(1, -170, 0, 8), Position = isLeft and UDim2.new(0, 112, 0, y + 5) or UDim2.new(0, 58, 0, y + 5), ZIndex = 9, Parent = frame })
		Kit.corner(track, UDim.new(1, 0))
		local fill = Kit.create("Frame", { Name = "Fill", BackgroundColor3 = accent, Size = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(isLeft and 0 or 1, 0), Position = UDim2.new(isLeft and 0 or 1, 0, 0, 0), ZIndex = 10, Parent = track })
		Kit.corner(fill, UDim.new(1, 0))
		local value = Kit.label({ parent = frame, name = "Value_" .. statId, text = "", bold = true, textSize = 13, align = isLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, size = UDim2.new(0, 40, 0, 18), position = isLeft and UDim2.new(1, -58, 0, y) or UDim2.new(0, 18, 0, y), zIndex = 9 })
		rows[statId] = { fill = fill, value = value }
	end
	return { frame = frame, name = name, info = info, rows = rows, corner = corner }
end
local plateLeft = plate(true)
local plateRight = plate(false)
Kit.label({ parent = intro, name = "VS", text = "VS", font = Enum.Font.Oswald, textSize = 64, color = C.textPrimary, align = Enum.TextXAlignment.Center, size = UDim2.new(0, 100, 0, 70), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), zIndex = 9 })
local styleNoteLabel = Kit.label({ parent = intro, name = "StyleNote", text = "", bold = true, textSize = 15, color = C.goldBright, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 20), position = UDim2.new(0, 0, 1, 12), zIndex = 9 })

-- corner plan
local cornerCard = Kit.create("Frame", { Name = "Corner", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.915, -44), Size = UDim2.new(0, 640, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 10, Parent = broadcast })
Kit.corner(cornerCard, 16)
Kit.stroke(cornerCard, C.gold, 1.5, 0.2)
Kit.create("UIGradient", { Color = ColorSequence.new(C.bgCardLight, C.bg), Rotation = 90, Parent = cornerCard })
Kit.padding(cornerCard, 14, 16, 16, 16)
Kit.list(cornerCard, 10)
local cornerScale = Kit.create("UIScale", { Scale = 1, Parent = cornerCard })
local cornerTitle = Kit.label({ parent = cornerCard, name = "Title", text = "IN THE CORNER", font = Enum.Font.Oswald, textSize = 22, color = C.goldBright, size = UDim2.new(1, 0, 0, 26), order = 1, zIndex = 11 })
Kit.label({ parent = cornerCard, name = "Hint", text = "What's the plan for the next round, coach? Your pick boosts one stat.", textSize = 13, color = C.textSecondary, size = UDim2.new(1, 0, 0, 16), order = 2, zIndex = 11 })
local optionGrid = Kit.create("Frame", { Name = "Options", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 3, ZIndex = 11, Parent = cornerCard })
Kit.grid(optionGrid, UDim2.new(0.25, -8, 1, 0), UDim2.new(0, 10, 0, 0))
local cornerTimer = Kit.progressBar({ parent = cornerCard, name = "Timer", size = UDim2.new(1, 0, 0, 6), order = 4 })
local optionButtons = {}
local cornerOpen = false
for index, optionId in ipairs(FightConfig.CornerOptionOrder) do
	local option = FightConfig.CornerOptions[optionId]
	local button = Kit.create("TextButton", { Name = "Option_" .. optionId, AutoButtonColor = false, Text = "", BackgroundColor3 = C.bgCard, LayoutOrder = index, ZIndex = 11, Parent = optionGrid })
	Kit.corner(button, 12)
	local buttonStroke = Kit.stroke(button, C.border, 1, 0.2)
	Kit.label({ parent = button, name = "Icon", text = CORNER_ICONS[optionId] or "🥊", textSize = 18, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 22), position = UDim2.new(0, 0, 0, 6), zIndex = 12 })
	Kit.label({ parent = button, name = "Label", text = option.label, bold = true, textSize = 12, align = Enum.TextXAlignment.Center, size = UDim2.new(1, -8, 0, 16), position = UDim2.new(0, 4, 0, 30), zIndex = 12 })
	Kit.label({ parent = button, name = "Boost", text = string.format("+%d%% %s", math.floor((option.multiplier - 1) * 100 + 0.5), STAT_LABELS[option.statBoost] or ""), font = Enum.Font.Oswald, textSize = 12, color = C.goldBright, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 14), position = UDim2.new(0, 0, 0, 46), zIndex = 12 })
	button.MouseEnter:Connect(function()
		tween(buttonStroke, 0.12, { Color = C.gold })
		tween(button, 0.12, { BackgroundColor3 = C.bgCardLight })
	end)
	button.MouseLeave:Connect(function()
		tween(buttonStroke, 0.12, { Color = C.border })
		tween(button, 0.12, { BackgroundColor3 = C.bgCard })
	end)
	button.Activated:Connect(function()
		if not cornerOpen then
			return
		end
		cornerOpen = false
		Kit.playSfx("Click")
		CornerChoice:FireServer(optionId)
		cornerCard.Visible = false
		ticker.Text = string.format('Coach: "%s!"', option.label)
	end)
	optionButtons[optionId] = button
end

-- result
local resultCard = Kit.create("Frame", { Name = "Result", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 560, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 12, Parent = broadcast })
Kit.corner(resultCard, 18)
local resultStroke = Kit.stroke(resultCard, C.gold, 2, 0.1)
Kit.create("UIGradient", { Color = ColorSequence.new(C.bgCardLight, C.bg), Rotation = 90, Parent = resultCard })
Kit.padding(resultCard, 20, 24, 22, 24)
Kit.list(resultCard, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
local resultScale = Kit.create("UIScale", { Scale = 1, Parent = resultCard })
local resultTitle = Kit.label({ parent = resultCard, name = "Title", text = "", font = Enum.Font.Oswald, textSize = 64, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 70), order = 1, zIndex = 13 })
local resultName = Kit.label({ parent = resultCard, name = "Name", text = "", font = Enum.Font.GothamBlack, textSize = 24, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 30), order = 2, zIndex = 13 })
local resultScore = Kit.label({ parent = resultCard, name = "Score", text = "", font = Enum.Font.Oswald, textSize = 22, color = C.textSecondary, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 26), order = 3, zIndex = 13 })
local resultPromo = Kit.label({ parent = resultCard, name = "Promotion", text = "", font = Enum.Font.Oswald, textSize = 20, color = C.goldBright, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 24), order = 4, zIndex = 13 })
local resultText = Kit.label({ parent = resultCard, name = "Text", text = "", textSize = 14, color = C.textPrimary, align = Enum.TextXAlignment.Center, wrap = true, size = UDim2.new(1, 0, 0, 0), autoSize = Enum.AutomaticSize.Y, order = 5, zIndex = 13 })
local resultButton = Kit.button({
	parent = resultCard,
	name = "BackButton",
	text = "Back to the gym",
	variant = "gold",
	size = UDim2.new(0, 240, 0, 44),
	order = 6,
	textSize = 15,
})

local toast = Kit.label({ parent = gui, name = "ErrorToast", text = "", bold = true, textSize = 15, color = C.textPrimary, align = Enum.TextXAlignment.Center, wrap = true, size = UDim2.new(0, 520, 0, 44), position = UDim2.new(0.5, 0, 0.8, 0), anchor = Vector2.new(0.5, 0.5) })
toast.BackgroundColor3 = C.crimson
toast.BackgroundTransparency = 0.1
toast.Visible = false
Kit.corner(toast, 12)

-- ============================================================
-- Broadcast helpers
-- ============================================================
local hiddenGuis = {}
local fight = nil -- { studentName, opponentName, studentRounds, opponentRounds, totalRounds }

local function setGameUiHidden(hidden)
	if hidden then
		for _, name in ipairs({ "MainHUD_Premium", "CoachTutorial" }) do
			local other = playerGui:FindFirstChild(name)
			if other and other:IsA("ScreenGui") and other.Enabled then
				hiddenGuis[other] = true
				other.Enabled = false
			end
		end
	else
		for other in pairs(hiddenGuis) do
			if other.Parent then
				other.Enabled = true
			end
		end
		table.clear(hiddenGuis)
	end
end

local function applyScales()
	local s = viewportScale()
	bcScale.Scale = s
	scoreScale.Scale = s
	momentumScale.Scale = s
	introScale.Scale = s
	cornerScale.Scale = s
	resultScale.Scale = s
	pickerScale.Scale = s
end

local function slam(text, color, hold)
	stageText.Text = text
	stageShadow.Text = text
	stageText.TextColor3 = color or C.goldBright
	stageText.TextTransparency = 0
	stageShadow.TextTransparency = 0.5
	stagePunch.Scale = 1.6
	tween(stagePunch, 0.25, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(hold or 0.6)
	tween(stageText, 0.2, { TextTransparency = 1 })
	tween(stageShadow, 0.2, { TextTransparency = 1 })
end

local function setMomentum(position, time)
	position = math.clamp(position, 0.04, 0.96)
	tween(momentumFill, time or 0.35, { Size = UDim2.new(position, 0, 1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(puck, time or 0.35, { Position = UDim2.new(position, 0, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function paintPips()
	if not fight then
		return
	end
	for i, pip in ipairs(leftSide.pips) do
		pip.BackgroundColor3 = i <= fight.studentRounds and leftSide.color or C.border
	end
	for i, pip in ipairs(rightSide.pips) do
		pip.BackgroundColor3 = i <= fight.opponentRounds and rightSide.color or C.border
	end
end

local function confetti()
	local colors = { C.goldBright, C.gold, C.textPrimary, C.crimsonBright }
	local rng = Random.new()
	for i = 1, 60 do
		local piece = Kit.create("Frame", {
			Name = "Confetti",
			Size = UDim2.new(0, rng:NextInteger(6, 12), 0, rng:NextInteger(10, 18)),
			Position = UDim2.new(rng:NextNumber(0, 1), 0, -0.05, -rng:NextInteger(0, 200)),
			Rotation = rng:NextInteger(0, 180),
			BackgroundColor3 = colors[(i % #colors) + 1],
			BorderSizePixel = 0,
			ZIndex = 14,
			Parent = broadcast,
		})
		local fall = rng:NextNumber(2.2, 3.6)
		tween(piece, fall, { Position = UDim2.new(piece.Position.X.Scale + rng:NextNumber(-0.08, 0.08), 0, 1.1, 0), Rotation = piece.Rotation + rng:NextInteger(180, 540) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(fall + 0.1, function()
			piece:Destroy()
		end)
	end
end

local function endBroadcast()
	broadcast.Visible = false
	resultCard.Visible = false
	cornerCard.Visible = false
	cornerOpen = false
	setGameUiHidden(false)
	fight = nil
end
resultButton.Instance.Activated:Connect(endBroadcast)

-- ============================================================
-- Phases
-- ============================================================
local handlers = {}

function handlers.start(data)
	picker.Visible = false
	applyScales()
	setGameUiHidden(true)
	fight = { studentName = data.studentName, opponentName = data.opponentName, studentRounds = 0, opponentRounds = 0, totalRounds = data.totalRounds or FightConfig.Rounds }
	broadcast.Visible = true
	resultCard.Visible = false
	cornerCard.Visible = false
	stageText.TextTransparency = 1
	stageShadow.TextTransparency = 1
	tierLabel.Text = string.upper(Kit.translate("ladder", data.tierName or ""))
	leftSide.name.Text = shortName(data.studentName)
	rightSide.name.Text = shortName(data.opponentName)
	roundLabel.Text = string.format("ROUND 1/%d", fight.totalRounds)
	paintPips()
	setMomentum(0.5, 0)
	ticker.Text = string.format("Welcome to Fight Night! %s vs %s.", data.studentName or "?", data.opponentName or "?")

	-- tale of the tape
	plateLeft.name.Text = data.studentName or "?"
	plateRight.name.Text = data.opponentName or "?"
	local record = data.studentRecord or {}
	plateLeft.info.Text = string.format("OVR %d  •  %s  •  %d-%d", average(data.studentStats), data.studentStyle or "Balanced", record.wins or 0, record.losses or 0)
	plateRight.info.Text = string.format("OVR %d  •  %s", average(data.opponentStats), data.opponentStyle or "Balanced")
	for statId, row in pairs(plateLeft.rows) do
		local value = data.studentStats and data.studentStats[statId] or 0
		row.value.Text = tostring(value)
		row.fill.Size = UDim2.new(0, 0, 1, 0)
		tween(row.fill, 0.6, { Size = UDim2.new(math.clamp(value / 100, 0, 1), 0, 1, 0) })
	end
	for statId, row in pairs(plateRight.rows) do
		local value = data.opponentStats and data.opponentStats[statId] or 0
		row.value.Text = tostring(value)
		row.fill.Size = UDim2.new(0, 0, 1, 0)
		tween(row.fill, 0.6, { Size = UDim2.new(math.clamp(value / 100, 0, 1), 0, 1, 0) })
	end
	styleNoteLabel.Text = data.styleNote or ""
	intro.Visible = true
	plateLeft.frame.Position = UDim2.new(0.5, -50 - 300, 0.5, 0)
	plateRight.frame.Position = UDim2.new(0.5, 50 + 300, 0.5, 0)
	tween(plateLeft.frame, 0.45, { Position = UDim2.new(0.5, -50, 0.5, 0) }, Enum.EasingStyle.Quint)
	tween(plateRight.frame, 0.45, { Position = UDim2.new(0.5, 50, 0.5, 0) }, Enum.EasingStyle.Quint)
	Kit.playSfx("Crowd")
	task.wait(math.max(0.5, (FightConfig.IntroSeconds or 2) - 0.4))
	intro.Visible = false
end

function handlers.round(data)
	if not fight then
		return
	end
	intro.Visible = false
	cornerCard.Visible = false
	roundLabel.Text = string.format("ROUND %d/%d", data.round, data.totalRounds or fight.totalRounds)
	Kit.playSfx("Bell")
	slam("ROUND " .. tostring(data.round), C.textPrimary, 0.45)
	slam("FIGHT!", C.goldBright, 0.25)

	-- momentum swings end on the real round result
	local s, o = data.studentScore or 1, data.opponentScore or 1
	local final = 0.5 + math.clamp((s - o) / math.max(1, s + o) * 3, -0.42, 0.42)
	if data.roundWinner == "student" then
		final = math.max(final, 0.58)
	else
		final = math.min(final, 0.42)
	end
	local rng = Random.new()
	local position = 0.5
	for i = 1, 5 do
		local bias = (final - 0.5) * (i / 5)
		position = 0.5 + bias + rng:NextNumber(-0.18, 0.18)
		local studentSwing = position >= 0.5
		local lines = studentSwing and GOOD_LINES or PRESSURE_LINES
		local name = studentSwing and fight.studentName or fight.opponentName
		ticker.Text = string.format(lines[rng:NextInteger(1, #lines)], name or "?")
		setMomentum(position, 0.35)
		if rng:NextNumber() < 0.5 then
			Kit.playSfx("Punch")
		end
		task.wait(0.4)
	end
	setMomentum(final, 0.3)
	task.wait(0.3)
	fight.studentRounds = data.studentRounds or fight.studentRounds
	fight.opponentRounds = data.opponentRounds or fight.opponentRounds
	paintPips()
	local winnerName = data.roundWinner == "student" and fight.studentName or fight.opponentName
	local color = data.roundWinner == "student" and C.goldBright or C.crimsonBright
	ticker.Text = string.format("%s takes round %d!", winnerName or "?", data.round)
	slam(string.format("%s TAKES R%d", shortName(winnerName), data.round), color, 0.5)
end

function handlers.corner(data)
	if not fight then
		return
	end
	cornerTitle.Text = string.format("IN THE CORNER  •  PLAN FOR ROUND %d", (data.round or 1) + 1)
	cornerCard.Visible = true
	cornerOpen = true
	ticker.Text = "Coaches are in the corner..."
	local timeout = FightConfig.CornerChoiceTimeout or 20
	cornerTimer.Set(1, true)
	task.spawn(function()
		local started = os.clock()
		while cornerOpen and os.clock() - started < timeout do
			cornerTimer.Set(1 - (os.clock() - started) / timeout, true)
			task.wait(0.1)
		end
		if cornerOpen then
			cornerOpen = false
			cornerCard.Visible = false
		end
	end)
end

function handlers.result(data)
	cornerOpen = false
	cornerCard.Visible = false
	intro.Visible = false
	if not fight then
		applyScales()
		setGameUiHidden(true)
		broadcast.Visible = true
		fight = { studentName = "?", opponentName = "?", studentRounds = 0, opponentRounds = 0, totalRounds = FightConfig.Rounds }
	end
	local won = data.won == true
	resultTitle.Text = won and "WINNER" or "DEFEAT"
	resultTitle.TextColor3 = won and C.goldBright or C.crimsonBright
	resultStroke.Color = won and C.gold or C.crimson
	resultName.Text = won and (fight.studentName or "") or (fight.opponentName or "")
	resultScore.Text = string.format("%s  %d – %d  %s", shortName(fight.studentName), data.studentRounds or fight.studentRounds, data.opponentRounds or fight.opponentRounds, shortName(fight.opponentName))
	resultPromo.Text = data.promoted and "PROMOTED TO THE NEXT CAREER LEVEL!" or ""
	resultPromo.Visible = data.promoted == true
	resultText.Text = Kit.localizeMessage(data.message or "")
	resultCard.Visible = true
	ticker.Text = won and "What a performance! The crowd is on its feet." or "Tough night. Back to the gym, coach."
	resultScale.Scale = viewportScale() * 0.85
	tween(resultScale, 0.35, { Scale = viewportScale() }, Enum.EasingStyle.Back)
	if won then
		Kit.playSfx("Crowd")
		confetti()
	end
	task.delay(10, function()
		if resultCard.Visible and broadcast.Visible then
			endBroadcast()
		end
	end)
end

function handlers.error(data)
	local message = data.message or "The fight could not start."
	if picker.Visible then
		pickerError.Text = message
	else
		toast.Text = message
		toast.Visible = true
		task.delay(3, function()
			toast.Visible = false
		end)
	end
	Kit.playSfx("Error")
end

-- one worker so phases never overlap (the server paces them to the animations)
local queue = {}
local working = false
local function pump()
	if working then
		return
	end
	working = true
	task.spawn(function()
		while #queue > 0 do
			local data = table.remove(queue, 1)
			local handler = handlers[data.phase]
			if handler then
				local ok, err = pcall(handler, data)
				if not ok then
					warn("FightUI: " .. tostring(data.phase) .. " failed: " .. tostring(err))
				end
			end
		end
		working = false
	end)
end
FightUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	table.insert(queue, data)
	pump()
end)

-- blinking LIVE dot
task.spawn(function()
	while gui.Parent do
		if broadcast.Visible then
			liveDot.TextTransparency = liveDot.TextTransparency < 0.5 and 0.6 or 0
		end
		task.wait(0.6)
	end
end)

-- Ring prompt opens the picker. Listened to globally: with StreamingEnabled the ring can stream in
-- late or stream out and come back as a new instance (e.g. after a fight in a far arena).
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, triggerPlayer)
	if triggerPlayer == player and prompt.Name == "FightPrompt" and not broadcast.Visible then
		openPicker()
	end
end)

_G.CoachAcademyFightUI = { openPicker = openPicker }

print("FightUI paruoštas.")
