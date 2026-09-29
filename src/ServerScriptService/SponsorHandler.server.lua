-- Script: ServerScriptService/SponsorHandler
-- Banga 3, #3: remeju / sponsorystes sistema

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)
local SponsorConfig = require(ReplicatedStorage.Modules.SponsorConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SponsorRefreshRequest = Remotes:WaitForChild("SponsorRefreshRequest")
local SponsorAcceptRequest = Remotes:WaitForChild("SponsorAcceptRequest")
local SponsorCollectRequest = Remotes:WaitForChild("SponsorCollectRequest")
local SponsorUpdate = Remotes:WaitForChild("SponsorUpdate")

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

local function currentStars(profile)
	local stars = 0
	local reputacija = profile.reputacija or 0
	if DataSchema.CoachReputationTiers then
		for _, tier in ipairs(DataSchema.CoachReputationTiers) do
			if reputacija >= tier.winsRequired then
				stars = math.max(stars, tier.stars)
			end
		end
	end
	return stars
end

local function pushSponsorUpdate(player, profile, message)
	SponsorUpdate:FireClient(player, {
		pinigai = profile.pinigai,
		sponsors = profile.sponsors,
		sponsorOffers = profile.sponsorOffers,
		lastSponsorRefresh = profile.lastSponsorRefresh,
		message = message,
	})
end

Players.PlayerAdded:Connect(function(player)
	if not dataApi then dataApi = getDataApi() end
	task.wait(0.6)
	local profile = getProfile(player)
	if not profile then
		warn("SponsorHandler: nepavyko rasti profilio zaidejui " .. player.Name)
		return
	end
	if not profile.sponsors then profile.sponsors = {} end
	if not profile.sponsorOffers then profile.sponsorOffers = {} end
	pushSponsorUpdate(player, profile, nil)
end)

SponsorRefreshRequest.OnServerEvent:Connect(function(player)
	if not dataApi then dataApi = getDataApi() end
	local profile = getProfile(player)
	if not profile then
		warn("SponsorHandler: nepavyko rasti profilio ieskant remeju")
		return
	end
	if not profile.sponsors then profile.sponsors = {} end
	if not profile.sponsorOffers then profile.sponsorOffers = {} end

	local now = os.time()
	local last = profile.lastSponsorRefresh or 0
	if now - last < SponsorConfig.RefreshCooldown then
		local waitSeconds = SponsorConfig.RefreshCooldown - (now - last)
		pushSponsorUpdate(player, profile, string.format("Wait %d s before searching for sponsors again.", waitSeconds))
		return
	end

	if #profile.sponsors >= SponsorConfig.MaxActiveSponsors then
		pushSponsorUpdate(player, profile, "You already have the maximum number of sponsors.")
		return
	end

	local stars = currentStars(profile)
	local eligible = {}
	for i, s in ipairs(SponsorConfig.Sponsors) do
		if stars >= s.minStars then
			table.insert(eligible, i)
		end
	end

	if #eligible == 0 then
		pushSponsorUpdate(player, profile, "No sponsors are interested yet — grow your reputation.")
		return
	end

	local offers = {}
	local pool = table.clone(eligible)
	for i = 1, math.min(SponsorConfig.OfferCount, #pool) do
		local idx = math.random(1, #pool)
		table.insert(offers, pool[idx])
		table.remove(pool, idx)
	end

	profile.sponsorOffers = offers
	profile.lastSponsorRefresh = now

	pushSponsorUpdate(player, profile, "New sponsor offers received!")
end)

SponsorAcceptRequest.OnServerEvent:Connect(function(player, offerPos)
	if not dataApi then dataApi = getDataApi() end
	local profile = getProfile(player)
	if not profile then return end
	if not profile.sponsorOffers then profile.sponsorOffers = {} end
	if not profile.sponsors then profile.sponsors = {} end

	if typeof(offerPos) ~= "number" then return end
	local configIndex = profile.sponsorOffers[offerPos]
	if not configIndex then
		pushSponsorUpdate(player, profile, "This offer has expired.")
		return
	end

	if #profile.sponsors >= SponsorConfig.MaxActiveSponsors then
		pushSponsorUpdate(player, profile, "You already have the maximum number of sponsors.")
		return
	end

	local sConf = SponsorConfig.Sponsors[configIndex]
	if not sConf then return end

	local now = os.time()
	table.insert(profile.sponsors, {
		configIndex = configIndex,
		acceptedAt = now,
		nextCollectAt = now + SponsorConfig.CollectCycleSeconds,
		expiresAt = now + sConf.durationSeconds,
	})

	profile.pinigai = (profile.pinigai or 0) + sConf.signingBonus
	table.remove(profile.sponsorOffers, offerPos)

	pushSponsorUpdate(player, profile, string.format("%s is now your sponsor! +$%d signing bonus.", sConf.name, sConf.signingBonus))
end)

SponsorCollectRequest.OnServerEvent:Connect(function(player, sponsorPos)
	if not dataApi then dataApi = getDataApi() end
	local profile = getProfile(player)
	if not profile then return end
	if not profile.sponsors then profile.sponsors = {} end

	if typeof(sponsorPos) ~= "number" then return end
	local entry = profile.sponsors[sponsorPos]
	if not entry then return end

	local now = os.time()

	if now >= entry.expiresAt then
		table.remove(profile.sponsors, sponsorPos)
		pushSponsorUpdate(player, profile, "The sponsorship contract has ended.")
		return
	end

	if now < entry.nextCollectAt then
		local waitSeconds = entry.nextCollectAt - now
		pushSponsorUpdate(player, profile, string.format("Next payment in %d s.", waitSeconds))
		return
	end

	local sConf = SponsorConfig.Sponsors[entry.configIndex]
	local income = sConf and sConf.incomePerCycle or 0

	profile.pinigai = (profile.pinigai or 0) + income
	entry.nextCollectAt = now + SponsorConfig.CollectCycleSeconds

	pushSponsorUpdate(player, profile, string.format("Collected $%d from %s.", income, sConf and sConf.name or "a sponsor"))
end)

print("SponsorHandler paruostas.")
