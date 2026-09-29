-- Script: ServerScriptService/AcademyHandler
-- Fazė 8: Akademijos pritaikymas -- sienų spalva, logotipas, pavadinimas (rodoma ant iškabos prie įėjimo)
-- HUD panelės: + grindų pasirinkimas (AcademyConfig.FloorOptions / profile.floorColorIndex)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")

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

local function push(player, profile, message)
	AcademyUpdate:FireClient(player, {
		message = message,
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

	-- Indeksai: tik baigtiniai skaiciai (NaN/inf praeina pro math.clamp ir sugadintu issaugojima)
	local function validIndex(value, count)
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return math.clamp(math.floor(value), 1, count)
	end

	local wallIndex = validIndex(data.wallColorIndex, #AcademyConfig.WallColors)
	if wallIndex then
		profile.wallColorIndex = wallIndex
	end
	local logoIndex = validIndex(data.logoIndex, #AcademyConfig.Logos)
	if logoIndex then
		profile.logoIndex = logoIndex
	end
	if AcademyConfig.FloorOptions then
		local floorIndex = validIndex(data.floorColorIndex, #AcademyConfig.FloorOptions)
		if floorIndex then
			profile.floorColorIndex = floorIndex
		end
	end

	local message = nil
	if type(data.academyName) == "string" then
		local trimmed = data.academyName:gsub("^%s+", ""):gsub("%s+$", "")
		if utf8.len(trimmed) == nil then
			-- netinkamas UTF-8 -- DataStore tokio teksto neissaugotu
			message = "That name contains blocked words — not changed."
		else
			if #trimmed == 0 then
				trimmed = AcademyConfig.DefaultName
			elseif utf8.len(trimmed) > AcademyConfig.MaxNameLength then
				-- trumpinam simboliais, ne baitais (lietuviskos raides uzima 2 baitus)
				trimmed = string.sub(trimmed, 1, utf8.offset(trimmed, AcademyConfig.MaxNameLength + 1) - 1)
			end
			-- Pavadinimas matomas visiems ant iskabos -- privalomas Roblox teksto filtravimas
			local ok, filtered = pcall(function()
				local result = TextService:FilterStringAsync(trimmed, player.UserId)
				return result:GetNonChatStringForBroadcastAsync()
			end)
			if ok and type(filtered) == "string" then
				profile.academyName = filtered
			else
				message = "Could not check the name — please try again."
				warn("AcademyHandler: teksto filtravimas nepavyko", player.Name, filtered)
			end
		end
	end

	applyToWorkspace(profile)
	push(player, profile, message)
end)

print("AcademyHandler paruoštas.")
