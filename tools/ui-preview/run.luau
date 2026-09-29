--!nocheck
-- Scenario runner: builds a mock place (server + client), seeds data, runs a scenario,
-- dumps PlayerGui tree for the HTML renderer.
-- Usage: lune run run.luau <scenario> <out.json>

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local HERE = (debug.info(1, "s"):match("^(.*)/[^/]+$") or ".")
local mock = require("./mock")

-- Keliai: src/ (nauji/pakeisti failai) ir place failas (visi kiti originalus skriptai)
local REPO = process.env.COACH_REPO or (HERE .. "/../..")
local SRC = process.env.COACH_SRC or (REPO .. "/src")
local PLACE = process.env.COACH_PLACE or (REPO .. "/CoachAcademy_active2_checkpoint.rbxl")

-- Originaliu skriptu saltiniai is place failo: "ReplicatedStorage/Modules/DataSchema" -> Source
local placeSources = {}
do
	local place = roblox.deserializePlace(fs.readFile(PLACE))
	for _, inst in ipairs(place:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") then
			local parts = {}
			local current = inst
			while current and current ~= place do
				table.insert(parts, 1, current.Name)
				current = current.Parent
			end
			placeSources[table.concat(parts, "/")] = inst.Source
		end
	end
end

local Enum, Color3, Vector2, Vector3, UDim2 = roblox.Enum, roblox.Color3, roblox.Vector2, roblox.Vector3, roblox.UDim2
local world = mock.world
local game = mock.game
local rawInstance = mock.rawInstance

local scenarioName = process.args[1] or "profile"
local outPath = process.args[2] or (HERE .. "/out/" .. scenarioName .. ".json")

math.randomseed(7)

-- ------------------------------------------------------------
-- Source loading
-- ------------------------------------------------------------
local function readFirst(paths)
	for _, path in ipairs(paths) do
		if path:sub(1, 6) == "place:" then
			local source = placeSources[path:sub(7)]
			if source then
				return source, path
			end
		elseif fs.isFile(path) then
			return fs.readFile(path), path
		end
	end
	error("source not found: " .. table.concat(paths, " | "))
end

local function make(className, name, parent, props)
	local inst = rawInstance(className)
	inst.Name = name
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function scriptInstance(className, name, parent, source)
	local inst = make(className, name, parent)
	mock.getData(inst).props.Source = source
	return inst
end

-- ------------------------------------------------------------
-- Place construction
-- ------------------------------------------------------------
local ReplicatedStorage = mock.getService("ReplicatedStorage")
local ServerScriptService = mock.getService("ServerScriptService")
local Players = mock.getService("Players")
local Workspace = mock.getService("Workspace")
mock.getService("StarterGui")
mock.getService("StarterPlayer")

local camera = rawInstance("Camera")
camera.Name = "Camera"
camera.Parent = Workspace
mock.getData(Workspace).props.CurrentCamera = camera

local modulesFolder = make("Folder", "Modules", ReplicatedStorage)
local MODULES = {
	"DataSchema", "TrainingConfig", "EquipmentConfig", "MarketingConfig", "FightConfig", "AcademyConfig",
	"InjuryConfig", "StaffConfig", "ScoutConfig", "SponsorConfig", "TournamentConfig", "MainHUDController",
}
for _, name in ipairs(MODULES) do
	local source = readFirst({
		SRC .. "/ReplicatedStorage/Modules/" .. name .. ".lua",
		"place:ReplicatedStorage/Modules/" .. name,
	})
	scriptInstance("ModuleScript", name, modulesFolder, source)
end
local panelsFolder = make("Folder", "Panels", modulesFolder)
for _, entry in ipairs(fs.readDir(SRC .. "/ReplicatedStorage/Modules/Panels")) do
	local name = entry:match("^(.-)%.lua$")
	if name then
		scriptInstance("ModuleScript", name, panelsFolder, fs.readFile(SRC .. "/ReplicatedStorage/Modules/Panels/" .. entry))
	end
end

local remotesFolder = make("Folder", "Remotes", ReplicatedStorage)
for _, name in ipairs({
	"TrainingRequest", "TrainingUpdate", "EquipmentPurchaseRequest", "EquipmentUpdate", "MarketingPostContent",
	"MarketingUpdate", "ReputationUpdate", "FightRequest", "FightUpdate", "CornerChoice", "AcademyCustomize",
	"AcademyUpdate", "StyleChangeRequest", "EncourageRequest", "RecoveryRequest", "HireStaffRequest",
	"FireStaffRequest", "StaffUpdate", "ScoutSearchRequest", "ScoutRecruitRequest", "ScoutUpdate",
	"SponsorRefreshRequest", "SponsorAcceptRequest", "SponsorCollectRequest", "SponsorUpdate",
	"TournamentRefreshRequest", "TournamentEnterRequest", "TournamentUpdate",
}) do
	make("RemoteEvent", name, remotesFolder)
end

-- Workspace (enough for AcademyHandler / TrainingUI / FightUI)
local gym = make("Folder", "GymLayout", Workspace)
make("Part", "Floor", gym, { Color = Color3.fromRGB(150, 150, 150) })
for _, wall in ipairs({ "Wall_North", "Wall_East", "Wall_West", "Wall_South_A", "Wall_South_B" }) do
	make("Part", wall, gym)
end
local ring = make("Part", "RingPlaceholder", gym)
make("ProximityPrompt", "FightPrompt", ring)
for station, stationType in pairs({
	PunchingBagStation = "PunchingBag", SpeedBagStation = "SpeedBag", TreadmillStation = "Treadmill",
	DumbbellRackStation = "DumbbellRack", WeightBenchStation = "WeightBench",
}) do
	local part = make("Part", station, gym)
	part:SetAttribute("StationType", stationType)
	make("ProximityPrompt", "TrainPrompt", part)
end
local town = make("Folder", "Town", Workspace)
local facade = make("Folder", "PlayerGymFacade", town)
local sign = make("Part", "AcademySignBoard", facade)
local billboard = make("BillboardGui", "BillboardGui", sign)
make("TextLabel", "NameLabel", billboard)

-- Server scripts
local SERVER_SCRIPTS = {
	"DataStoreHandler", "TrainingHandler", "EquipmentHandler", "MarketingHandler", "ReputationHandler",
	"FightHandler", "AcademyHandler", "StyleHandler", "MoraleHandler", "InjuryHandler", "StaffHandler",
	"ScoutHandler", "SponsorHandler", "TournamentHandler", "PanelDataHandler",
}
local serverScripts = {}
for _, name in ipairs(SERVER_SCRIPTS) do
	local source = readFirst({
		SRC .. "/ServerScriptService/" .. name .. ".server.lua",
		"place:ServerScriptService/" .. name,
	})
	table.insert(serverScripts, scriptInstance("Script", name, ServerScriptService, source))
end

-- ------------------------------------------------------------
-- Scenario config
-- ------------------------------------------------------------
local VIEWPORTS = {
	desktop = Vector2.new(1280, 720),
	hd = Vector2.new(1920, 1080),
	laptop = Vector2.new(1366, 768),
	small = Vector2.new(1024, 640),
	phone = Vector2.new(844, 390),
}

local scenarios = require("./scenarios")
local scenario = scenarios[scenarioName]
if not scenario then
	error("unknown scenario " .. scenarioName)
end
local viewport = VIEWPORTS[scenario.viewport or "desktop"]
mock.getData(camera).props.ViewportSize = viewport
mock.topInset = scenario.viewport == "phone" and 36 or 58
mock.touchEnabled = scenario.viewport == "phone"

-- ------------------------------------------------------------
-- Boot: server -> player join -> client
-- ------------------------------------------------------------
for _, s in ipairs(serverScripts) do
	mock.runScript(s, "server:" .. s.Name)
end
mock.advance(0.2)

local player = rawInstance("Player")
mock.getData(player).Name = "CoachHenrikas"
mock.getData(player).displayName = "Henrikas"
mock.getData(player).userId = 4815162342
mock.localPlayer = player
player.Parent = Players
local playerGui = rawInstance("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = player

-- Legacy (disabled) MainHUD from StarterGui -- MainHUDController mirrors its labels
local legacyHud = make("ScreenGui", "MainHUD", nil, { Enabled = false })
make("TextLabel", "MoneyLabel", legacyHud, { Text = "$ 500" })
make("TextLabel", "ReputationLabel", legacyHud, { Text = "" })
make("TextButton", "PhoneButton", legacyHud)
make("TextButton", "ProfileButton", legacyHud)
make("TextButton", "AcademyButton", legacyHud)
legacyHud.Parent = playerGui

mock.getSignal(Players, "PlayerAdded"):Fire(player)
mock.advance(0.1)

-- Seed server profile
local dataApi = mock.sharedG.CoachAcademyData
if not dataApi then print("NO DATA API", #world.errors) for _, l in ipairs(world.logs) do print(l) end end
local profile = dataApi and dataApi.getProfile(player)
if not profile then
	error("profile not loaded")
end
local now = world.epoch + math.floor(world.now)
if scenario.seed then
	scenario.seed(profile, now)
end

-- Client scripts
local starterScripts = {}
local clientList = scenario.legacyScripts and { "MainHUDBootstrap", "PanelsBootstrap", "ReputationUI", "AcademyUI", "PhoneUI" }
	or { "MainHUDBootstrap", "PanelsBootstrap", "ReputationUI" }
local playerScripts = make("Folder", "PlayerScripts", player)
for _, name in ipairs(clientList) do
	local source = readFirst({
		SRC .. "/StarterPlayer/StarterPlayerScripts/" .. name .. ".client.lua",
		"place:StarterPlayer/StarterPlayerScripts/" .. name,
	})
	table.insert(starterScripts, scriptInstance("LocalScript", name, playerScripts, source))
end
for _, s in ipairs(starterScripts) do
	mock.runScript(s, "client:" .. s.Name)
end
mock.advance(3)

-- ------------------------------------------------------------
-- Scenario actions
-- ------------------------------------------------------------
local api = {}
function api.open(key)
	local panels = mock.sharedG.CoachAcademyPanels
	assert(panels and panels[key], "panel not registered: " .. key)
	panels[key]()
	mock.advance(1)
end
function api.wait(seconds)
	mock.advance(seconds)
end
function api.find(path)
	return mock.findPath(playerGui, path)
end
function api.click(path)
	mock.click(api.find(path))
	mock.advance(0.6)
end
function api.hover(path)
	mock.hover(api.find(path))
	mock.advance(0.3)
end
function api.type(path, text)
	local box = api.find(path)
	box.Text = text
	mock.advance(0.3)
end
function api.scroll(path, y)
	local frame = api.find(path)
	frame.CanvasPosition = Vector2.new(0, y)
end
function api.profile()
	return profile
end
function api.state()
	return mock
end

if scenario.run then
	scenario.run(api)
end
mock.advance(1.5)

-- ------------------------------------------------------------
-- Output
-- ------------------------------------------------------------
local result = {
	scenario = scenarioName,
	viewport = { x = viewport.X, y = viewport.Y },
	topInset = mock.topInset,
	tree = mock.dump(playerGui),
	errors = world.errors,
	warnings = world.warnings,
	deprecated = world.deprecatedUse,
	remoteLog = {},
}
for _, entry in ipairs(world.remoteLog) do
	if entry.direction == "toServer" then
		table.insert(result.remoteLog, entry.remote)
	end
end
if not fs.isDir(HERE .. "/out") then
	fs.writeDir(HERE .. "/out")
end
fs.writeFile(outPath, serde.encode("json", result))
print(string.format("%s: %d errors, %d warnings -> %s", scenarioName, #world.errors, #world.warnings, outPath))
if scenario.check then
	local ok, err = pcall(scenario.check, api, result)
	if not ok then
		print("CHECK FAILED: " .. tostring(err))
		process.exit(2)
	end
	print("CHECK OK: " .. scenarioName)
end
if #world.errors > 0 then
	process.exit(1)
end
