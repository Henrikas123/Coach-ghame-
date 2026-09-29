--[[
	Tutorial (client)
	Coach's guide card at the top of the screen + a pulsing ring and arrow on the HUD button
	to press, or a gold beam and "TRAIN HERE" / "FIGHT HERE" marker in the gym.
	The server (TutorialHandler) owns the progress; this script only shows it and reports
	"ack" / opened panels. Starts after PLAY on the title screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Kit = require(Modules:WaitForChild("Panels"):WaitForChild("PanelKit"))
local TutorialConfig = require(Modules:WaitForChild("TutorialConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TutorialUpdate = Remotes:WaitForChild("TutorialUpdate", 30)
local TutorialRequest = Remotes:WaitForChild("TutorialRequest", 30)
if not TutorialUpdate or not TutorialRequest then
	return
end

local C = Kit.Colors
local STEPS = TutorialConfig.Steps

local state = nil -- { step, counter, done }
local ready = false -- after PLAY

-- ------------------------------------------------------------
-- UI
-- ------------------------------------------------------------
local gui = Kit.create("ScreenGui", {
	Name = "CoachTutorial",
	ResetOnSpawn = false,
	DisplayOrder = 30,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = playerGui,
})

local card = Kit.create("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.new(0, 470, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = gui,
})
Kit.corner(card, 14)
local cardStroke = Kit.stroke(card, C.gold, 1.5, 0.2)
Kit.create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(50, 43, 50), Color3.fromRGB(24, 21, 26)),
	Rotation = 90,
	Parent = card,
})
Kit.padding(card, 12, 16, 14, 16)
Kit.list(card, 6)
local cardScale = Kit.create("UIScale", { Scale = 1, Parent = card })

local header = Kit.create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = card })
local stepLabel = Kit.label({
	parent = header,
	name = "Step",
	text = "",
	font = Enum.Font.Oswald,
	textSize = 15,
	color = C.gold,
	size = UDim2.new(1, -80, 1, 0),
})
local skipButton = Kit.create("TextButton", {
	Name = "SkipButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, 80, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "Skip guide",
	TextSize = 12,
	TextColor3 = C.textSecondary,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = header,
})
local titleLabel = Kit.label({ parent = card, name = "Title", text = "", bold = true, textSize = 18, size = UDim2.new(1, 0, 0, 24), order = 2 })
local textLabel = Kit.label({
	parent = card,
	name = "Text",
	text = "",
	textSize = 14,
	color = C.textPrimary,
	wrap = true,
	size = UDim2.new(1, 0, 0, 0),
	autoSize = Enum.AutomaticSize.Y,
	order = 3,
})
local progressRow = Kit.create("Frame", { Name = "Progress", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 4, Parent = card })
local progressBar = Kit.progressBar({ parent = progressRow, size = UDim2.new(1, -54, 0, 8), position = UDim2.new(0, 0, 0.5, 0), anchor = Vector2.new(0, 0.5) })
local progressText = Kit.label({
	parent = progressRow,
	name = "Count",
	text = "",
	bold = true,
	textSize = 12,
	color = C.goldBright,
	align = Enum.TextXAlignment.Right,
	size = UDim2.new(0, 48, 1, 0),
	position = UDim2.new(1, 0, 0, 0),
	anchor = Vector2.new(1, 0),
})
local actionButton = Kit.button({
	parent = card,
	name = "ActionButton",
	text = "Let's go",
	variant = "gold",
	size = UDim2.new(1, 0, 0, 40),
	order = 5,
	textSize = 14,
	onClick = function()
		TutorialRequest:FireServer("ack")
	end,
})

-- HUD highlight: pulsing ring + bouncing arrow
local ring = Kit.create("Frame", {
	Name = "HighlightRing",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
Kit.corner(ring, 16)
local ringStroke = Kit.stroke(ring, C.goldBright, 3, 0)
local arrow = Kit.label({
	parent = gui,
	name = "Arrow",
	text = "▼",
	font = Enum.Font.GothamBlack,
	textSize = 28,
	color = C.goldBright,
	align = Enum.TextXAlignment.Center,
	size = UDim2.new(0, 40, 0, 32),
	anchor = Vector2.new(0.5, 1),
})
arrow.Visible = false
arrow.TextStrokeTransparency = 0.4
Kit.tween(ringStroke, 0.6, { Transparency = 0.7, Thickness = 5 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local highlightTarget = nil
local bob = 0
RunService.RenderStepped:Connect(function(dt)
	if not highlightTarget or not highlightTarget.Parent or not gui.Enabled then
		ring.Visible = false
		arrow.Visible = false
		return
	end
	bob += dt
	local position = highlightTarget.AbsolutePosition + highlightTarget.AbsoluteSize / 2
	local size = highlightTarget.AbsoluteSize
	-- the ScreenGui respects the top bar inset like the HUD, so positions line up
	ring.Position = UDim2.fromOffset(position.X, position.Y)
	ring.Size = UDim2.fromOffset(size.X + 14, size.Y + 14)
	arrow.Position = UDim2.fromOffset(position.X, position.Y - size.Y / 2 - 10 - math.abs(math.sin(bob * 4)) * 10)
	ring.Visible = true
	arrow.Visible = true
end)

local function findHudElement(name)
	local hud = playerGui:FindFirstChild("MainHUD_Premium")
	return hud and hud:FindFirstChild(name, true)
end

-- World marker: beam from the player to the target + label above it
local worldMarker = nil
local function clearWorldMarker()
	if worldMarker then
		for _, inst in ipairs(worldMarker) do
			inst:Destroy()
		end
		worldMarker = nil
	end
end
local function showWorldMarker(partName, text)
	clearWorldMarker()
	local gym = Workspace:FindFirstChild("GymLayout")
	local target = gym and gym:FindFirstChild(partName)
	if not target or not target:IsA("BasePart") then
		return
	end
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTarget"
	targetAttachment.Position = Vector3.new(0, target.Size.Y / 2 + 1, 0)
	targetAttachment.Parent = target
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TutorialMarker"
	billboard.Size = UDim2.fromOffset(180, 70)
	billboard.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 4, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = target
	billboard.Parent = playerGui -- BillboardGui cannot live inside a ScreenGui
	Kit.label({ parent = billboard, name = "Text", text = text, font = Enum.Font.Oswald, textSize = 26, color = C.goldBright, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 32) }).TextStrokeTransparency = 0.3
	local down = Kit.label({ parent = billboard, name = "Arrow", text = "▼", font = Enum.Font.GothamBlack, textSize = 26, color = C.goldBright, align = Enum.TextXAlignment.Center, size = UDim2.new(1, 0, 0, 30), position = UDim2.new(0, 0, 0, 34) })
	down.TextStrokeTransparency = 0.3
	Kit.tween(down, 0.5, { Position = UDim2.new(0, 0, 0, 42) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	worldMarker = { targetAttachment, billboard }

	-- gold beam from the character to the target (rebuilt on respawn)
	local function attachBeam(character)
		local root = character and character:WaitForChild("HumanoidRootPart", 5)
		if not root or not worldMarker then
			return
		end
		local from = Instance.new("Attachment")
		from.Name = "TutorialFrom"
		from.Parent = root
		local beam = Instance.new("Beam")
		beam.Name = "TutorialBeam"
		beam.Attachment0 = from
		beam.Attachment1 = targetAttachment
		beam.Color = ColorSequence.new(C.goldBright)
		beam.Transparency = NumberSequence.new(0.35)
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Parent = root
		table.insert(worldMarker, from)
		table.insert(worldMarker, beam)
	end
	task.spawn(attachBeam, player.Character)
end

-- ------------------------------------------------------------
-- Render
-- ------------------------------------------------------------
local function panelCoversScreen()
	return Kit.isAnyOpen and Kit.isAnyOpen()
end

local finishedShownAt = nil
local function render(message)
	if not ready or not state then
		gui.Enabled = false
		return
	end
	if state.done then
		highlightTarget = nil
		clearWorldMarker()
		if message then
			-- completion card for a few seconds
			gui.Enabled = true
			stepLabel.Text = "COACH'S GUIDE COMPLETE"
			titleLabel.Text = "You're ready, Coach!"
			textLabel.Text = message
			progressRow.Visible = false
			actionButton.Instance.Visible = false
			skipButton.Visible = false
			cardStroke.Color = C.goldBright
			finishedShownAt = os.clock()
			task.delay(5, function()
				if finishedShownAt and os.clock() - finishedShownAt >= 4.9 then
					gui.Enabled = false
				end
			end)
		elseif not finishedShownAt then
			gui.Enabled = false
		end
		return
	end
	local step = STEPS[state.step]
	if not step then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	card.Visible = not panelCoversScreen()
	stepLabel.Text = string.format("COACH'S GUIDE  •  STEP %d/%d", state.step, #STEPS)
	titleLabel.Text = step.title
	textLabel.Text = step.text
	skipButton.Visible = true
	actionButton.Instance.Visible = step.kind == "ack"
	actionButton.SetText(step.button or "OK")
	local count = step.count or 1
	progressRow.Visible = step.kind == "event" and count > 1
	progressBar.Set(math.clamp((state.counter or 0) / count, 0, 1))
	progressText.Text = string.format("%d / %d", state.counter or 0, count)

	highlightTarget = step.highlight and findHudElement(step.highlight) or nil
	if step.world then
		showWorldMarker(step.world, step.worldLabel or "HERE")
	else
		clearWorldMarker()
	end
end

TutorialUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	local previousStep = state and state.step
	state = data
	render(data.done and data.message or nil)
	if ready and previousStep and data.step ~= previousStep and not data.done then
		Kit.playSfx("Click")
	end
end)

skipButton.Activated:Connect(function()
	TutorialRequest:FireServer("skip")
end)

-- panel-type steps complete when that panel opens
if Kit.Changed then
	Kit.Changed.Event:Connect(function(key, isOpen)
		if state and not state.done then
			local step = STEPS[state.step]
			if isOpen and step and step.kind == "panel" and step.panel == key then
				TutorialRequest:FireServer("panel", key)
			end
			card.Visible = not panelCoversScreen()
		end
	end)
end

local function fitScreen()
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 1280
	cardScale.Scale = width < 700 and 0.8 or 1
end
fitScreen()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScreen)
end

-- start after the title screen's PLAY
task.spawn(function()
	local deadline = os.clock() + 180
	while os.clock() < deadline do
		local intro = player:GetAttribute("CoachIntro")
		if intro == nil or intro == "playing" then
			break
		end
		task.wait(0.25)
	end
	task.wait(0.8)
	ready = true
	TutorialRequest:FireServer("sync")
	render()
end)

player.CharacterAdded:Connect(function()
	if state and not state.done then
		task.wait(1)
		render()
	end
end)
