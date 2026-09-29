-- Script: ServerScriptService/PanelDataHandler
-- HUD paneliu duomenu tiltas:
--   1) PanelSnapshot (RemoteFunction) -- grazina pilna profilio busena panelems atidarant
--      (tik skaitymas, jokiu pakeitimu). Sukuriama automatiskai, jei Remotes aplanke jos nera.
--   2) Pinigu srauto sekimas -- profile.lifetimeEarned / profile.lifetimeSpent (Profilio "Pelnas"),
--      skaiciuojama is balanso pokyciu kas sekunde, todel nereikia keisti kitu handleriu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PanelSnapshot = Remotes:FindFirstChild("PanelSnapshot")
if not PanelSnapshot then
	PanelSnapshot = Instance.new("RemoteFunction")
	PanelSnapshot.Name = "PanelSnapshot"
	PanelSnapshot.Parent = Remotes
end

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
	if not dataApi then
		dataApi = getDataApi()
	end
	local profile = dataApi and dataApi.getProfile(player)
	local tries = 0
	while not profile and tries < 100 do
		task.wait(0.05)
		profile = dataApi and dataApi.getProfile(player)
		tries += 1
	end
	return profile
end

local function buildSnapshot(player)
	local profile = getProfile(player)
	if not profile then
		return nil
	end
	return {
		serverTime = os.time(),
		pinigai = profile.pinigai,
		reputacija = profile.reputacija,
		coachReputationTier = profile.coachReputationTier,
		followers = profile.followers,
		reachAccumulated = profile.reachAccumulated,
		walkInThreshold = profile.walkInThreshold,
		lastPostTimes = profile.lastPostTimes,
		studentsList = profile.studentsList,
		academyName = profile.academyName,
		wallColorIndex = profile.wallColorIndex,
		floorColorIndex = profile.floorColorIndex,
		logoIndex = profile.logoIndex,
		gymLevel = profile.gymLevel,
		unlockedEquipment = profile.unlockedEquipment,
		staff = profile.staff or {},
		-- genetines lubos slepiamos, kol nenupirkta Scout Report (zr. ScoutHandler)
		scoutCandidates = _G.CoachAcademyScoutPublic and _G.CoachAcademyScoutPublic(profile.scoutCandidates) or {},
		lastScoutAt = profile.lastScoutAt or 0,
		sponsors = profile.sponsors or {},
		sponsorOffers = profile.sponsorOffers or {},
		lastSponsorRefresh = profile.lastSponsorRefresh or 0,
		lastTournamentAt = profile.lastTournamentAt or 0,
		lifetimeEarned = profile.lifetimeEarned or 0,
		lifetimeSpent = profile.lifetimeSpent or 0,
		trophies = profile.trophies or {},
	}
end

PanelSnapshot.OnServerInvoke = function(player)
	local ok, result = pcall(buildSnapshot, player)
	if ok then
		return result
	end
	warn("PanelDataHandler: nepavyko sudaryti snapshot zaidejui", player.Name, result)
	return nil
end

-- Pinigu srauto sekimas (uzdirbta / isleista) Profilio panelei
local lastBalance = {}

task.spawn(function()
	while true do
		task.wait(1)
		dataApi = dataApi or _G.CoachAcademyData
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = dataApi and dataApi.getProfile(player)
			if profile and type(profile.pinigai) == "number" then
				local previous = lastBalance[player]
				if previous then
					local delta = profile.pinigai - previous
					if delta > 0 then
						profile.lifetimeEarned = (profile.lifetimeEarned or 0) + delta
					elseif delta < 0 then
						profile.lifetimeSpent = (profile.lifetimeSpent or 0) - delta
					end
				end
				lastBalance[player] = profile.pinigai
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastBalance[player] = nil
end)

print("PanelDataHandler paruoštas.")
