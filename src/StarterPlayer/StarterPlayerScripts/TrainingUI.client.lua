-- LocalScript: StarterPlayer/StarterPlayerScripts/TrainingUI
-- Phase 4: Kliento GUI -- treniruočių meniu per ProximityPrompt

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrainingConfig = require(ReplicatedStorage.Modules.TrainingConfig)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TrainingRequest = Remotes:WaitForChild("TrainingRequest")
local TrainingUpdate = Remotes:WaitForChild("TrainingUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== GUI sukūrimas =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TrainingGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "TrainingMenu"
frame.Size = UDim2.new(0, 380, 0, 474)
frame.Position = UDim2.new(0.5, -190, 0.5, -237)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(255, 215, 80)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Alex Martin"
title.Parent = frame

-- ===== Studentų sąrašas (roster) -- pasirinkti kurį treniruoti =====
local rosterHolder = Instance.new("Frame")
rosterHolder.Name = "RosterHolder"
rosterHolder.Size = UDim2.new(1, -20, 0, 34)
rosterHolder.Position = UDim2.new(0, 10, 0, 44)
rosterHolder.BackgroundTransparency = 1
rosterHolder.ClipsDescendants = true
rosterHolder.Parent = frame

local rosterLayout = Instance.new("UIListLayout")
rosterLayout.FillDirection = Enum.FillDirection.Horizontal
rosterLayout.Padding = UDim.new(0, 6)
rosterLayout.Parent = rosterHolder

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, -20, 0, 90)
statsLabel.Position = UDim2.new(0, 10, 0, 84)
statsLabel.BackgroundTransparency = 1
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 14
statsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "Power 1 | Speed 1 | Defense 1\nStamina 1 | Technique 1\nFatigue: 0%"
statsLabel.Parent = frame

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 26, 0, 26)
closeButton.Position = UDim2.new(1, -34, 0, 8)
closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Parent = frame
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

-- Fokuso mygtukai
local focusOrder = { "Power", "Speed", "Defense", "Conditioning", "Technique" }
local selectedFocus = "Power"
local selectedSession = "Group"
local selectedStudentIndex = 1
local focusButtons = {}

local focusHolder = Instance.new("Frame")
focusHolder.Name = "FocusHolder"
focusHolder.Size = UDim2.new(1, -20, 0, 190)
focusHolder.Position = UDim2.new(0, 10, 0, 180)
focusHolder.BackgroundTransparency = 1
focusHolder.Parent = frame

local focusLayout = Instance.new("UIListLayout")
focusLayout.Padding = UDim.new(0, 6)
focusLayout.Parent = focusHolder

local function refreshFocusButtons()
	for name, btn in pairs(focusButtons) do
		if name == selectedFocus then
			btn.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
		end
	end
end

for _, focusName in ipairs(focusOrder) do
	local cfg = TrainingConfig.Focuses[focusName]
	local btn = Instance.new("TextButton")
	btn.Name = focusName .. "Button"
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = string.format(
		"%s   (+%d %s, +%d %s, Fatigue +%d%%)",
		cfg.label, cfg.primaryDelta, cfg.primary, cfg.secondaryDelta, cfg.secondary, cfg.fatigueCost
	)
	btn.Parent = focusHolder
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		selectedFocus = focusName
		refreshFocusButtons()
	end)

	focusButtons[focusName] = btn
end
refreshFocusButtons()

-- Session type mygtukai (Private/Group)
local sessionHolder = Instance.new("Frame")
sessionHolder.Name = "SessionHolder"
sessionHolder.Size = UDim2.new(1, -20, 0, 36)
sessionHolder.Position = UDim2.new(0, 10, 0, 380)
sessionHolder.BackgroundTransparency = 1
sessionHolder.Parent = frame

local sessionLayout = Instance.new("UIListLayout")
sessionLayout.FillDirection = Enum.FillDirection.Horizontal
sessionLayout.Padding = UDim.new(0, 8)
sessionLayout.Parent = sessionHolder

local sessionButtons = {}
local function refreshSessionButtons()
	for name, btn in pairs(sessionButtons) do
		if name == selectedSession then
			btn.BackgroundColor3 = Color3.fromRGB(90, 180, 110)
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 56)		end
	end
end

for _, sessionName in ipairs({ "Group", "Private" }) do
	local cfg = TrainingConfig.SessionTypes[sessionName]
	local btn = Instance.new("TextButton")
	btn.Name = sessionName .. "SessionButton"
	btn.Size = UDim2.new(0.5, -4, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = cfg.label .. (cfg.cost > 0 and (" ($" .. cfg.cost .. ")") or " (Free)")
	btn.Parent = sessionHolder
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	btn.MouseButton1Click:Connect(function()
		selectedSession = sessionName
		refreshSessionButtons()
	end)

	sessionButtons[sessionName] = btn
end
refreshSessionButtons()

-- Train mygtukas
local trainButton = Instance.new("TextButton")
trainButton.Name = "TrainButton"
trainButton.Size = UDim2.new(1, -20, 0, 36)
trainButton.Position = UDim2.new(0, 10, 0, 424)
trainButton.BackgroundColor3 = Color3.fromRGB(220, 160, 40)
trainButton.Font = Enum.Font.GothamBold
trainButton.TextSize = 16
trainButton.TextColor3 = Color3.fromRGB(30, 30, 30)
trainButton.Text = "Train"
trainButton.Parent = frame
local trainCorner = Instance.new("UICorner")
trainCorner.CornerRadius = UDim.new(0, 6)
trainCorner.Parent = trainButton

trainButton.MouseButton1Click:Connect(function()
	TrainingRequest:FireServer(selectedFocus, selectedSession, selectedStudentIndex)
end)

closeButton.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- ===== Duomenų atnaujinimas iš serverio =====
local function updateStatsLabel(student)
	if not student then
		statsLabel.Text = "No fighters yet — wait for a client to walk in."
		return
	end
	local s = student.stats
	local stageLine
	if student.karjerosStadija == "Trial" then
		local trial = TrainingConfig.Trial
		stageLine = string.format(
			"Trial: %d/%d sessions | Satisfaction %d%%",
			student.trialSessionsCompleted or 0, trial.maxSessions, student.satisfactionScore or 0
		)
	else
		stageLine = "Member" .. (student.competitionReady and " | Fight-ready" or "")
	end
	if student.injured then
		stageLine = stageLine .. string.format(" | Injured (~%d min)", math.ceil((student.injuryRecoverySeconds or 0) / 60))
	end
	statsLabel.Text = string.format(
		"Power %d | Speed %d | Defense %d\nStamina %d | Technique %d\nFatigue: %d%% | Morale: %d\nPersonality: %s | Style: %s\n%s",
		s.power, s.speed, s.defense, s.stamina, s.technique,
		student.fatigue or 0, student.morale or 70, student.personality or "-", student.style or "-", stageLine
	)
	title.Text = student.name or "Fighter"
end

-- ===== Studentų roster (pasirinkimo mygtukai) =====
local currentStudentsList = {}
local rosterButtons = {}

local function refreshRosterButtons()
	for _, btn in ipairs(rosterButtons) do
		btn:Destroy()
	end
	rosterButtons = {}

	for i, student in ipairs(currentStudentsList) do
		local btn = Instance.new("TextButton")
		btn.Name = "Student" .. i
		btn.Size = UDim2.new(0, 100, 1, 0)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 12
		btn.TextWrapped = true
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		local tag = student.karjerosStadija == "Trial" and "🆕" or "⭐"
		btn.Text = tag .. " " .. (student.name or "?")
		btn.BackgroundColor3 = (i == selectedStudentIndex) and Color3.fromRGB(90, 140, 220) or Color3.fromRGB(50, 50, 56)
		btn.Parent = rosterHolder
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn

		btn.MouseButton1Click:Connect(function()
			selectedStudentIndex = i
			refreshRosterButtons()
			updateStatsLabel(currentStudentsList[selectedStudentIndex])
		end)

		table.insert(rosterButtons, btn)
	end
end

TrainingUpdate.OnClientEvent:Connect(function(data)
	if data.studentsList then
		currentStudentsList = data.studentsList
		if selectedStudentIndex > #currentStudentsList then
			selectedStudentIndex = 1
		end
		if selectedStudentIndex < 1 and #currentStudentsList > 0 then
			selectedStudentIndex = 1
		end
		refreshRosterButtons()
		updateStatsLabel(currentStudentsList[selectedStudentIndex])
	end
end)

-- ===== Treniruočių stotys =====
-- StreamingEnabled: stotys gali atkeliauti vėliau (arba išnykti ir grįžti kaip nauji objektai),
-- todėl klausomės visų ProximityPrompt paspaudimų, o ne kiekvienos stoties atskirai.
local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player or prompt.Name ~= "TrainPrompt" then
		return
	end
	local part = prompt.Parent
	local stationType = part and part:GetAttribute("StationType")
	if not stationType then
		return
	end
	local defaultFocus = TrainingConfig.StationDefaultFocus[stationType]
	if defaultFocus then
		selectedFocus = defaultFocus
		refreshFocusButtons()
	end
	frame.Visible = true
end)

print("TrainingUI paruoštas.")
