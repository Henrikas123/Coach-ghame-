--!nocheck
-- Surenka atnaujinta place faila is originalaus checkpoint + src/ katalogo.
-- Paleidimas (is repo saknies):  lune run tools/build_place.luau [ivestis.rbxl] [isvestis.rbxl]
--
-- Ka daro:
--   * ReplicatedStorage/Modules: atnaujina/prideda modulius is src/ReplicatedStorage/Modules/*.lua
--     ir sukuria Panels aplanka is src/ReplicatedStorage/Modules/Panels/*.lua
--   * ServerScriptService: atnaujina/prideda Script'us is src/ServerScriptService/*.server.lua
--   * ReplicatedFirst: krovimo ekranas is src/ReplicatedFirst/*.client.lua
--   * StarterPlayerScripts: atnaujina/prideda LocalScript'us is src/StarterPlayer/StarterPlayerScripts/*.client.lua
--   * Remotes: prideda PanelSnapshot (RemoteFunction) ir ScoutReportRequest (RemoteEvent)
--   * Senus UI skriptus, kuriuos pakeite naujos paneles, perkelia i ServerStorage/LegacyUI (ten jie nesileidzia)

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance

local input = process.args[1] or "CoachAcademy_active2_checkpoint.rbxl"
local output = process.args[2] or "CoachAcademy_panels.rbxl"
local SRC = "src"

local LEGACY_UI = {
	"AcademyUI", "PhoneUI", "FighterProfileUI", "StaffUI", "ScoutUI", "SponsorUI", "TournamentUI", "EquipmentShopUI",
}

local game = roblox.deserializePlace(fs.readFile(input))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local Modules = ReplicatedStorage:FindFirstChild("Modules")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
assert(Modules and Remotes and StarterPlayerScripts, "netikėta place struktūra")

local log = {}
local function note(fmt, ...)
	local line = string.format(fmt, ...)
	table.insert(log, line)
	print(line)
end

local function upsertScript(parent, className, name, source)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		error(string.format("%s.%s yra %s, tikėtasi %s", parent.Name, name, existing.ClassName, className))
	end
	if existing then
		if existing.Source ~= source then
			existing.Source = source
			note("  atnaujinta  %s/%s", parent.Name, name)
		end
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
	note("  pridėta     %s/%s (%s)", parent.Name, name, className)
	return inst
end

local function listLua(dir, suffix)
	local out = {}
	if not fs.isDir(dir) then
		return out
	end
	for _, entry in ipairs(fs.readDir(dir)) do
		local name = entry:match("^(.-)" .. suffix:gsub("%.", "%%.") .. "$")
		if name and fs.isFile(dir .. "/" .. entry) then
			table.insert(out, { name = name, path = dir .. "/" .. entry })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

note("ReplicatedStorage/Modules:")
for _, file in ipairs(listLua(SRC .. "/ReplicatedStorage/Modules", ".lua")) do
	upsertScript(Modules, "ModuleScript", file.name, fs.readFile(file.path))
end
local panels = Modules:FindFirstChild("Panels")
if not panels then
	panels = Instance.new("Folder")
	panels.Name = "Panels"
	panels.Parent = Modules
	note("  pridėta     Modules/Panels (Folder)")
end
for _, file in ipairs(listLua(SRC .. "/ReplicatedStorage/Modules/Panels", ".lua")) do
	upsertScript(panels, "ModuleScript", file.name, fs.readFile(file.path))
end

note("ServerScriptService:")
for _, file in ipairs(listLua(SRC .. "/ServerScriptService", ".server.lua")) do
	upsertScript(ServerScriptService, "Script", file.name, fs.readFile(file.path))
end

note("ReplicatedFirst:")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
if fs.isDir(SRC .. "/ReplicatedFirst") then
	for _, file in ipairs(listLua(SRC .. "/ReplicatedFirst", ".client.lua")) do
		upsertScript(ReplicatedFirst, "LocalScript", file.name, fs.readFile(file.path))
	end
end

note("StarterPlayerScripts:")
for _, file in ipairs(listLua(SRC .. "/StarterPlayer/StarterPlayerScripts", ".client.lua")) do
	upsertScript(StarterPlayerScripts, "LocalScript", file.name, fs.readFile(file.path))
end

note("Remotes:")
for name, className in pairs({
	PanelSnapshot = "RemoteFunction",
	ScoutReportRequest = "RemoteEvent",
	RetentionUpdate = "RemoteEvent",
	RetentionRequest = "RemoteEvent",
	LeaderboardFetch = "RemoteFunction",
	TutorialUpdate = "RemoteEvent",
	TutorialRequest = "RemoteEvent",
}) do
	if not Remotes:FindFirstChild(name) then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
		note("  pridėta     Remotes/%s (%s)", name, className)
	end
end

note("Senieji UI skriptai -> ServerStorage/LegacyUI:")
local legacyFolder = ServerStorage:FindFirstChild("LegacyUI")
if not legacyFolder then
	legacyFolder = Instance.new("Folder")
	legacyFolder.Name = "LegacyUI"
	legacyFolder.Parent = ServerStorage
end
for _, name in ipairs(LEGACY_UI) do
	local script = StarterPlayerScripts:FindFirstChild(name)
	if script then
		script.Parent = legacyFolder
		note("  perkelta    %s", name)
	end
end

-- Lyderiu lentos stendas mieste (RetentionHandler piesia SurfaceGui). Studio ji galima laisvai perkelti.
note("Lyderiu lentos stendas:")
local town = game:GetService("Workspace"):FindFirstChild("Town")
if town and not town:FindFirstChild("LeaderboardBoard") then
	local model = Instance.new("Model")
	model.Name = "LeaderboardBoard"
	local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
	local origin = CFrame.new(-24, 0, 46) -- prie salės išėjimo, priekis (-Z) atsuktas į salę
	local function part(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = origin * CFrame.new(offset)
		p.Color = color
		p.Material = material
		p.TopSurface = roblox.Enum.SurfaceType.Smooth
		p.BottomSurface = roblox.Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	part("Board", Vector3.new(12, 8, 0.6), Vector3.new(0, 7, 0), Color3.fromRGB(22, 20, 24), roblox.Enum.Material.SmoothPlastic)
	part("Frame", Vector3.new(12.8, 8.8, 0.4), Vector3.new(0, 7, 0.3), Color3.fromRGB(212, 175, 55), roblox.Enum.Material.Metal)
	part("PostLeft", Vector3.new(0.6, 11, 0.6), Vector3.new(-5.6, 5.5, 0.6), Color3.fromRGB(38, 34, 40), roblox.Enum.Material.Metal)
	part("PostRight", Vector3.new(0.6, 11, 0.6), Vector3.new(5.6, 5.5, 0.6), Color3.fromRGB(38, 34, 40), roblox.Enum.Material.Metal)
	model.Parent = town
	note("  pridėtas    Town/LeaderboardBoard")
end

-- Pasaulio tekstai anglu kalba (ProximityPrompt'ai ir isjungtas senas MainHUD)
note("Pasaulio tekstai (EN):")
local STATION_NAMES = {
	PunchingBag = "Heavy Bag",
	SpeedBag = "Speed Bag",
	Treadmill = "Treadmill",
	DumbbellRack = "Dumbbell Rack",
	WeightBench = "Weight Bench",
}
for _, prompt in ipairs(game:GetService("Workspace"):GetDescendants()) do
	if prompt:IsA("ProximityPrompt") then
		if prompt.Name == "TrainPrompt" then
			prompt.ActionText = "Train"
			prompt.ObjectText = STATION_NAMES[prompt.ObjectText] or prompt.ObjectText
		elseif prompt.Name == "FightPrompt" then
			prompt.ActionText = "Start fight"
			prompt.ObjectText = "Fight Ring"
		end
		note("  %s: %s | %s", prompt.Parent.Name, prompt.ActionText, prompt.ObjectText)
	end
end
local oldHud = game:GetService("StarterGui"):FindFirstChild("MainHUD")
if oldHud then
	for name, text in pairs({ AcademyButton = "🏠 Academy", ProfileButton = "👤 Profile", PhoneButton = "Phone" }) do
		local button = oldHud:FindFirstChild(name)
		if button then
			button.Text = text
		end
	end
end

fs.writeFile(output, roblox.serializePlace(game))
note("Išsaugota: %s", output)
