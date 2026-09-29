-- Script: ServerScriptService/DataStoreHandler
-- Fazė 2: PlayerProfile įkėlimas/išsaugojimas per DataStoreService
-- Fazė: apsaugota nuo DataStore nepasiekiamumo (pvz. Studio be publikavimo) -- naudoja laikiną atmintį kaip atsarginį variantą

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)

local profileStore
local dataStoreOk = false
do
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerProfiles_v1")
	end)
	if success then
		profileStore = result
		dataStoreOk = true
	else
		warn("DataStoreHandler: DataStore nepasiekiamas (galbūt vieta nepublikuota arba Studio API išjungta) -- naudojama laikina atmintis.", result)
	end
end

local sessionData = {}

local function loadProfile(player)
	local data = nil

	if dataStoreOk then
		local key = "Player_" .. player.UserId
		local success, result = pcall(function()
			return profileStore:GetAsync(key)
		end)
		if success then
			data = result
		else
			warn("Nepavyko įkelti duomenų žaidėjui", player.Name, result)
		end
	end

	if data then
		sessionData[player.UserId] = data
	else
		sessionData[player.UserId] = DataSchema.newPlayerProfile()
	end
end

local function saveProfile(player)
	local data = sessionData[player.UserId]
	if not data then
		return
	end
	if not dataStoreOk then
		return
	end
	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		profileStore:SetAsync(key, data)
	end)
	if not success then
		warn("Nepavyko išsaugoti duomenų žaidėjui", player.Name, err)
	end
end

local function getProfile(player)
	return sessionData[player.UserId]
end

Players.PlayerAdded:Connect(loadProfile)
Players.PlayerRemoving:Connect(saveProfile)

-- Play Solo / Team Test atveju žaidėjas gali būti jau prisijungęs, kai šis Script pradeda vykdymą
-- (PlayerAdded įvykis būtų praleistas) -- todėl užkrauname profilį ir jau esantiems žaidėjams.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadProfile, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveProfile(player)
	end
end)

_G.CoachAcademyData = {
	getProfile = getProfile,
}

print("DataStoreHandler paruoštas.")
