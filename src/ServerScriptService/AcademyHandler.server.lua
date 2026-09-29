-- Script: ServerScriptService/AcademyHandler
-- Fazė 8: Akademijos pritaikymas -- sienų spalva, logotipas, pavadinimas (rodoma ant iškabos prie įėjimo)
-- HUD panelės: + grindų pasirinkimas (AcademyConfig.FloorOptions / profile.floorColorIndex)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AcademyConfig = require(ReplicatedStorage.Modules.AcademyConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AcademyCustomize = Remotes:WaitForChild("AcademyCustomize")
local AcademyUpdate = Remotes:WaitForChild("AcademyUpdate")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end

local dataApi = getDataApi()

local function getProfile(player)
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 100 do
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	return profile
end

local function applyToWorkspace(profile)
	local gymLayout = Workspace:FindFirstChild("GymLayout")
	if not gymLayout then
		return
	end
	local color = AcademyConfig.WallColors[profile.wallColorIndex] or AcademyConfig.WallColors[1]
	for _, wallName in ipairs({ "Wall_North", "Wall_South_A", "Wall_South_B", "Wall_East", "Wall_West" }) do
		local wall = gymLayout:FindFirstChild(wallName)
		if wall then
			wall.Color = color
		end
	end

	-- HUD Akademijos panelė: grindys (taikoma tik jei žaidėjas jas pasirinko)
	local floorOption = AcademyConfig.FloorOptions and profile.floorColorIndex and AcademyConfig.FloorOptions[profile.floorColorIndex]
	local floor = gymLayout:FindFirstChild("Floor")
	if floorOption and floor and floor:IsA("BasePart") then
		floor.Color = floorOption.color
		local ok, material = pcall(function()
			return Enum.Material[floorOption.material]
		end)
		if ok and material then
			floor.Material = material
		end
	end

	local town = Workspace:FindFirstChild("Town")
	local sign = town and town:FindFirstChild("PlayerGymFacade") and town.PlayerGymFacade:FindFirstChild("AcademySignBoard")
	if sign then
		local billboard = sign:FindFirstChildOfClass("BillboardGui")
		local label = billboard and billboard:FindFirstChild("NameLabel")
		if label then
			local logo = AcademyConfig.Logos[profile.logoIndex] or AcademyConfig.Logos[1]
			label.Text = logo .. " " .. profile.academyName
		end
		local facadePart = sign
		if facadePart:IsA("BasePart") then
			facadePart.Color = color
		end
	end
end

local function push(player, profile)
	AcademyUpdate:FireClient(player, {
		academyName = profile.academyName,
		wallColorIndex = profile.wallColorIndex,
		logoIndex = profile.logoIndex,
		floorColorIndex = profile.floorColorIndex,
		wallColors = AcademyConfig.WallColors,
		logos = AcademyConfig.Logos,
	})
end

Players.PlayerAdded:Connect(function(player)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("AcademyHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end
	applyToWorkspace(profile)
	push(player, profile)
end)

AcademyCustomize.OnServerEvent:Connect(function(player, data)
	local profile = getProfile(player)
	if not profile or type(data) ~= "table" then
		return
	end

	if type(data.wallColorIndex) == "number" then
		profile.wallColorIndex = math.clamp(math.floor(data.wallColorIndex), 1, #AcademyConfig.WallColors)
	end
	if type(data.logoIndex) == "number" then
		profile.logoIndex = math.clamp(math.floor(data.logoIndex), 1, #AcademyConfig.Logos)
	end
	if type(data.floorColorIndex) == "number" and AcademyConfig.FloorOptions then
		profile.floorColorIndex = math.clamp(math.floor(data.floorColorIndex), 1, #AcademyConfig.FloorOptions)
	end
	if type(data.academyName) == "string" then
		local trimmed = data.academyName:gsub("^%s+", ""):gsub("%s+$", "")
		if #trimmed == 0 then
			trimmed = AcademyConfig.DefaultName
		elseif #trimmed > AcademyConfig.MaxNameLength then
			trimmed = string.sub(trimmed, 1, AcademyConfig.MaxNameLength)
		end
		profile.academyName = trimmed
	end

	applyToWorkspace(profile)
	push(player, profile)
end)

print("AcademyHandler paruoštas.")
