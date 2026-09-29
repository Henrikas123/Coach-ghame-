-- Script: ServerScriptService/EquipmentHandler
-- Fazė: Įrangos pirkimo apdorojimas -- validacija, pinigų nurašymas, unlockedEquipment atnaujinimas

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentConfig = require(ReplicatedStorage.Modules.EquipmentConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipmentPurchaseRequest = Remotes:WaitForChild("EquipmentPurchaseRequest")
local EquipmentUpdate = Remotes:WaitForChild("EquipmentUpdate")

local function getDataApi()
	local tries = 0
	while not _G.CoachAcademyData and tries < 200 do
		task.wait(0.05)
		tries += 1
	end
	return _G.CoachAcademyData
end

local dataApi = getDataApi()

local function pushEquipmentUpdate(player, profile, message)
	EquipmentUpdate:FireClient(player, {
		pinigai = profile.pinigai,
		unlockedEquipment = profile.unlockedEquipment,
		message = message,
	})
end

Players.PlayerAdded:Connect(function(player)
	if not dataApi then
		dataApi = getDataApi()
	end
	task.wait(0.6)
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 1200 do -- iki 60 s: profilis gali krautis su pakartojimais
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	if not profile then
		warn("EquipmentHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end
	pushEquipmentUpdate(player, profile, nil)
end)

EquipmentPurchaseRequest.OnServerEvent:Connect(function(player, itemId)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 1200 do -- iki 60 s: profilis gali krautis su pakartojimais
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	if not profile then
		warn("EquipmentHandler: nepavyko rasti profilio pirkimo metu", player.Name)
		return
	end

	local item = EquipmentConfig.Items[itemId]
	if not item then
		warn("EquipmentHandler: nežinomas itemId iš", player.Name, itemId)
		return
	end

	for _, ownedId in ipairs(profile.unlockedEquipment) do
		if ownedId == itemId then
			pushEquipmentUpdate(player, profile, "You already own " .. item.label .. "!")
			return
		end
	end

	if profile.pinigai < item.cost then
		pushEquipmentUpdate(player, profile, "Not enough money — you need $" .. item.cost)
		return
	end

	profile.pinigai -= item.cost
	table.insert(profile.unlockedEquipment, itemId)

	pushEquipmentUpdate(player, profile, "Purchased: " .. item.label .. "!")
end)

print("EquipmentHandler paruoštas.")
