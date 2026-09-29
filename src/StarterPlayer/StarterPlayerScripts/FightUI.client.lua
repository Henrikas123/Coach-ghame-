-- LocalScript: StarterPlayer/StarterPlayerScripts/FightUI
-- Fazė 7+8: Kovos UI -- kovotojo pasirinkimas, raundų eiga, korner koučingo 4 mygtukai, rezultatas

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FightConfig = require(ReplicatedStorage.Modules.FightConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FightRequest = Remotes:WaitForChild("FightRequest")
local FightUpdate = Remotes:WaitForChild("FightUpdate")
local CornerChoice = Remotes:WaitForChild("CornerChoice")
local TrainingUpdate = Remotes:WaitForChild("TrainingUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local studentsCache = {}
TrainingUpdate.OnClientEvent:Connect(function(data)
	if data.studentsList then
		studentsCache = data.studentsList
	end
end)

-- === GUI sukūrimas ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FightGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "FightPanel"
panel.Size = UDim2.new(0, 420, 0, 420)
panel.Position = UDim2.new(0.5, -210, 0.5, -210)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -80, 0, 40)
title.Position = UDim2.new(0, 16, 0, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 215, 80)
title.Text = "Fight Ring"
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 36, 0, 36)
closeButton.Position = UDim2.new(1, -50, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -32, 0, 90)
statusLabel.Position = UDim2.new(0, 16, 0, 56)
statusLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
statusLabel.BorderSizePixel = 0
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextScaled = true
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
statusLabel.Text = "Choose a fighter."
statusLabel.Parent = panel

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusLabel

-- Studentų sąrašo frame (pasirinkimo būsena)
local listFrame = Instance.new("ScrollingFrame")
listFrame.Name = "StudentList"
listFrame.Size = UDim2.new(1, -32, 0, 240)
listFrame.Position = UDim2.new(0, 16, 0, 156)
listFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = panel

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 8)
listCorner.Parent = listFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = listFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingLeft = UDim.new(0, 6)
listPadding.PaddingRight = UDim.new(0, 6)
listPadding.Parent = listFrame

-- Korner koučingo frame (4 mygtukai)
local cornerFrame = Instance.new("Frame")
cornerFrame.Name = "CornerFrame"
cornerFrame.Size = UDim2.new(1, -32, 0, 240)
cornerFrame.Position = UDim2.new(0, 16, 0, 156)
cornerFrame.BackgroundTransparency = 1
cornerFrame.Visible = false
cornerFrame.Parent = panel

local cornerGrid = Instance.new("UIGridLayout")
cornerGrid.CellSize = UDim2.new(0.5, -6, 0, 90)
cornerGrid.CellPadding = UDim2.new(0, 6, 0, 6)
cornerGrid.Parent = cornerFrame

local cornerButtons = {}
for _, optionId in ipairs(FightConfig.CornerOptionOrder) do
	local option = FightConfig.CornerOptions[optionId]
	local btn = Instance.new("TextButton")
	btn.Name = optionId .. "Button"
	btn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = option.label
	btn.Parent = cornerFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		CornerChoice:FireServer(optionId)
		statusLabel.Text = "Chosen: " .. option.label .. " — waiting for the round..."
		cornerFrame.Visible = false
	end)

	cornerButtons[optionId] = btn
end

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function showSelectState()
	clearList()
	listFrame.Visible = true
	cornerFrame.Visible = false

	local anyReady = false
	for index, student in ipairs(studentsCache) do
		if student.competitionReady then
			anyReady = true
			local tierName = "?"
			local tier = FightConfig.Ladder[student.careerTier or 1]
			if tier then
				tierName = tier.name
			end

			local btn = Instance.new("TextButton")
			btn.Name = "Student_" .. index
			btn.Size = UDim2.new(1, -12, 0, 48)
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
			btn.Font = Enum.Font.Gotham
			btn.TextScaled = true
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextXAlignment = Enum.TextXAlignment.Left
			local record = student.record or { wins = 0, losses = 0 }
			btn.Text = string.format("  %s | %s | %d-%d", student.name, tierName, record.wins, record.losses)
			btn.Parent = listFrame

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 6)
			btnCorner.Parent = btn

			btn.MouseButton1Click:Connect(function()
				FightRequest:FireServer(index)
				listFrame.Visible = false
				statusLabel.Text = "Getting ready to fight..."
			end)
		end
	end

	if not anyReady then
		local msg = Instance.new("TextLabel")
		msg.Size = UDim2.new(1, -12, 0, 48)
		msg.BackgroundTransparency = 1
		msg.Font = Enum.Font.Gotham
		msg.TextScaled = true
		msg.TextWrapped = true
		msg.TextColor3 = Color3.fromRGB(200, 200, 200)
		msg.Text = "None of your fighters is ready to fight yet. Keep training!"
		msg.Parent = listFrame
	end
end

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

local function openPanel()
	panel.Visible = true
	statusLabel.Text = "Choose a fighter."
	showSelectState()
end

FightUpdate.OnClientEvent:Connect(function(data)
	panel.Visible = true
	if data.phase == "start" then
		listFrame.Visible = false
		cornerFrame.Visible = false
		local baseText = string.format(
			"%s (%s) vs %s (%s) — %s",
			data.studentName, data.studentStyle or "?", data.opponentName, data.opponentStyle or "?", data.tierName
		)
		if data.styleNote then
			baseText = baseText .. "\n" .. data.styleNote
		end
		statusLabel.Text = baseText
	elseif data.phase == "round" then
		cornerFrame.Visible = false
		local winnerText = data.roundWinner == "student" and "You won the round!" or "You lost the round."
		statusLabel.Text = string.format(
			"Round %d/%d — %s\nYou: %.1f | Opponent: %.1f\nRounds: %d-%d",
			data.round, data.totalRounds, winnerText, data.studentScore, data.opponentScore,
			data.studentRounds, data.opponentRounds
		)
	elseif data.phase == "corner" then
		cornerFrame.Visible = true
		statusLabel.Text = "In the corner: choose what to improve next round!"
	elseif data.phase == "result" then
		cornerFrame.Visible = false
		listFrame.Visible = false
		local resultText = data.message
		if data.promoted then
			resultText = resultText .. "\n(Promoted to the next career level!)"
		end
		statusLabel.Text = resultText
		task.delay(4, function()
			if panel.Visible then
				showSelectState()
				statusLabel.Text = "Choose a fighter."
			end
		end)
	elseif data.phase == "error" then
		cornerFrame.Visible = false
		statusLabel.Text = data.message
		task.delay(2, function()
			if panel.Visible then
				showSelectState()
			end
		end)
	end
end)

-- Prisijungiam prie RingPlaceholder ProximityPrompt (sukuriamas deploy skripte)
task.spawn(function()
	local ring = Workspace:WaitForChild("GymLayout", 10) and Workspace.GymLayout:WaitForChild("RingPlaceholder", 10)
	if not ring then
		warn("FightUI: nerastas RingPlaceholder")
		return
	end
	local prompt = ring:WaitForChild("FightPrompt", 10)
	if not prompt then
		warn("FightUI: nerastas FightPrompt")
		return
	end
	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer == player then
			openPanel()
		end
	end)
end)

print("FightUI paruoštas.")
