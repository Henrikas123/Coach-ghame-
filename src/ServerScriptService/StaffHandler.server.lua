-- Script: ServerScriptService/StaffHandler
-- Banga 3, #1: personalo (padėjėjų trenerių) samdymo/atleidimo apdorojimas + periodinis atlyginimų nurašymas

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StaffConfig = require(ReplicatedStorage.Modules.StaffConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HireStaffRequest = Remotes:WaitForChild("HireStaffRequest")
local FireStaffRequest = Remotes:WaitForChild("FireStaffRequest")
local StaffUpdate = Remotes:WaitForChild("StaffUpdate")

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
	while not profile and tries < 1200 do -- iki 60 s: profilis gali krautis su pakartojimais
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	return profile
end

local function pushStaffUpdate(player, profile, message)
	StaffUpdate:FireClient(player, {
		pinigai = profile.pinigai,
		staff = profile.staff,
		message = message,
	})
end

local function hasRole(profile, roleId)
	for _, id in ipairs(profile.staff or {}) do
		if id == roleId then
			return true
		end
	end
	return false
end

Players.PlayerAdded:Connect(function(player)
	if not dataApi then
		dataApi = getDataApi()
	end
	task.wait(0.6)
	local profile = getProfile(player)
	if not profile then
		warn("StaffHandler: nepavyko rasti profilio žaidėjui", player.Name)
		return
	end
	if not profile.staff then
		profile.staff = {}
	end
	pushStaffUpdate(player, profile, nil)
end)

HireStaffRequest.OnServerEvent:Connect(function(player, roleId)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("StaffHandler: nepavyko rasti profilio samdymo metu", player.Name)
		return
	end
	if not profile.staff then
		profile.staff = {}
	end

	local role = StaffConfig.Roles[roleId]
	if not role then
		warn("StaffHandler: nežinomas roleId iš", player.Name, roleId)
		return
	end

	if hasRole(profile, roleId) then
		pushStaffUpdate(player, profile, role.label .. " already works at your academy!")
		return
	end

	if profile.pinigai < role.hireCost then
		pushStaffUpdate(player, profile, "Not enough money — you need $" .. role.hireCost)
		return
	end

	profile.pinigai -= role.hireCost
	table.insert(profile.staff, roleId)

	pushStaffUpdate(player, profile, "Hired: " .. role.label .. "!")
end)

FireStaffRequest.OnServerEvent:Connect(function(player, roleId)
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = getProfile(player)
	if not profile then
		warn("StaffHandler: nepavyko rasti profilio atleidimo metu", player.Name)
		return
	end
	if not profile.staff then
		profile.staff = {}
		return
	end

	local role = StaffConfig.Roles[roleId]
	for i, id in ipairs(profile.staff) do
		if id == roleId then
			table.remove(profile.staff, i)
			pushStaffUpdate(player, profile, (role and role.label or roleId) .. " was let go.")
			return
		end
	end
end)

-- Periodinis atlyginimų nurašymas -- jei trūksta pinigų visiems apmokėti, personalas
-- pradedant seniausiai pasamdytu palieka akademiją (atleidžiamas), kol likusieji tampa įperkami.
task.spawn(function()
	while true do
		task.wait(StaffConfig.PayrollIntervalSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = dataApi and dataApi.getProfile(player)
			if profile and profile.staff and #profile.staff > 0 then
				local totalSalary = 0
				for _, roleId in ipairs(profile.staff) do
					local role = StaffConfig.Roles[roleId]
					if role then
						totalSalary += role.salary
					end
				end

				local resigned = {}
				while profile.pinigai < totalSalary and #profile.staff > 0 do
					local removedId = table.remove(profile.staff, 1)
					table.insert(resigned, removedId)
					local removedRole = StaffConfig.Roles[removedId]
					totalSalary -= removedRole and removedRole.salary or 0
				end

				profile.pinigai = math.max(0, profile.pinigai - totalSalary)

				local msg
				if #resigned > 0 then
					local names = {}
					for _, id in ipairs(resigned) do
						local role = StaffConfig.Roles[id]
						table.insert(names, role and role.label or id)
					end
					msg = "Not enough money for salaries — quit: " .. table.concat(names, ", ")
				elseif totalSalary > 0 then
					msg = string.format("Paid $%d in staff salaries.", totalSalary)
				end

				pushStaffUpdate(player, profile, msg)
			end
		end
	end
end)

print("StaffHandler paruoštas.")
