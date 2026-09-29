-- Script: ServerScriptService/DataStoreHandler
-- Safe player data:
--   * retries with back-off when the DataStore is busy or down
--   * session lock: only one server at a time may write a profile (no overwrites on server hops)
--   * a profile that failed to load is NEVER saved (the player is asked to rejoin instead)
--   * autosave every 2 minutes + parallel save on shutdown (BindToClose)
--   * old saves are upgraded: missing fields are filled from DataSchema.newPlayerProfile()
--   * NaN / infinite numbers are cleaned before saving (they would make every save fail)
-- Unpublished place / Studio without API access: works from memory, nothing is saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Modules.DataSchema)

local STORE_NAME = "PlayerProfiles_v1" -- same store as before: existing saves keep working
local SAVE_FORMAT = 2 -- stored value: { format, lockedBy, lockedAt, savedAt, profile }
local AUTOSAVE_INTERVAL = 120
local LOCK_STALE_SECONDS = 600 -- a lock older than this belongs to a crashed server
local LOCK_WAIT_SECONDS = 5
local LOCK_WAIT_TRIES = 6 -- ~30 s for the previous server to finish its save
local LOAD_TRIES = 5
local SAVE_TRIES = 3

local JOB_ID = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(math.random(1, 1e9)))

local profileStore = nil
local dataStoreOk = false
do
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if success then
		profileStore = result
		dataStoreOk = true
	else
		warn("DataStoreHandler: DataStore nepasiekiamas (galbūt vieta nepublikuota arba Studio API išjungta) -- naudojama laikina atmintis.", result)
	end
end

-- [userId] = { state = "loading" | "ready" | "failed", profile, memoryOnly, releasing, lostLock }
local sessions = {}

local function keyFor(userId)
	return "Player_" .. userId
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fill fields that did not exist when the save was made (only dictionary tables are merged)
local function reconcile(target, template)
	for key, value in pairs(template) do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(target[key], value)
		end
	end
end

-- Copy for saving: drops values a DataStore cannot store and replaces NaN/inf numbers
local function sanitize(value)
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return value
	elseif kind == "string" or kind == "boolean" then
		return value
	elseif kind == "table" then
		local copy = {}
		for k, v in pairs(value) do
			if type(k) == "string" or type(k) == "number" then
				copy[k] = sanitize(v)
			end
		end
		return copy
	end
	return nil
end

-- Stored value -> profile, wrapper (old saves are the raw profile table)
local function unwrap(stored)
	if type(stored) ~= "table" then
		return nil, nil
	end
	if type(stored.profile) == "table" then
		return stored.profile, stored
	end
	if stored.pinigai ~= nil or stored.studentsList ~= nil then
		return stored, nil
	end
	return nil, nil
end

-- One load attempt that also takes the session lock. Returns "ok" | "locked" | "error", profile
local function tryLoad(userId, force)
	local status, loaded = "error", nil
	local success, err = pcall(function()
		profileStore:UpdateAsync(keyFor(userId), function(stored)
			local profile, wrapper = unwrap(stored)
			local now = os.time()
			if not force and wrapper and wrapper.lockedBy and wrapper.lockedBy ~= JOB_ID
				and now - (tonumber(wrapper.lockedAt) or 0) < LOCK_STALE_SECONDS then
				status = "locked"
				return nil -- keep the stored value untouched
			end
			status = "ok"
			loaded = profile
			return {
				format = SAVE_FORMAT,
				lockedBy = JOB_ID,
				lockedAt = now,
				savedAt = wrapper and wrapper.savedAt or now,
				profile = profile or DataSchema.newPlayerProfile(),
			}
		end)
	end)
	if not success then
		return "error", err
	end
	return status, loaded
end

local function loadProfile(player)
	local userId = player.UserId
	if sessions[userId] then
		return
	end
	local session = { state = "loading" }
	sessions[userId] = session

	if not dataStoreOk then
		local profile = DataSchema.newPlayerProfile()
		profile.dataVersion = DataSchema.DataVersion
		session.profile = profile
		session.memoryOnly = true
		session.state = "ready"
		return
	end

	local errors, lockWaits = 0, 0
	while player.Parent == Players do
		local status, result = tryLoad(userId, lockWaits >= LOCK_WAIT_TRIES)
		if status == "ok" then
			local profile = result or DataSchema.newPlayerProfile()
			reconcile(profile, DataSchema.newPlayerProfile())
			profile.dataVersion = DataSchema.DataVersion
			session.profile = profile
			session.state = "ready"
			return
		elseif status == "locked" then
			-- another server still has this player (fast server hop): give it time to save
			lockWaits += 1
			task.wait(LOCK_WAIT_SECONDS)
		else
			errors += 1
			warn(string.format("DataStoreHandler: nepavyko įkelti %s (%d/%d): %s", player.Name, errors, LOAD_TRIES, tostring(result)))
			if errors >= LOAD_TRIES then
				-- never continue with an empty profile: saving it would erase the real progress
				session.state = "failed"
				player:Kick("We couldn't load your save data right now. Your progress is safe — please rejoin in a minute.")
				return
			end
			task.wait(2 ^ errors)
		end
	end
	-- left while loading: nothing was taken, nothing to save
	if sessions[userId] == session then
		sessions[userId] = nil
	end
end

-- Writes the profile if this server still owns the lock. release = also give the lock up.
local function writeProfile(userId, session, release)
	if session.state ~= "ready" or session.memoryOnly or session.lostLock then
		return true
	end
	local data = sanitize(session.profile)
	for attempt = 1, SAVE_TRIES do
		local lostLock = false
		local success, err = pcall(function()
			profileStore:UpdateAsync(keyFor(userId), function(stored)
				local _, wrapper = unwrap(stored)
				if wrapper and wrapper.lockedBy and wrapper.lockedBy ~= JOB_ID then
					lostLock = true
					return nil
				end
				local now = os.time()
				return {
					format = SAVE_FORMAT,
					lockedBy = (not release) and JOB_ID or nil,
					lockedAt = now,
					savedAt = now,
					profile = data,
				}
			end)
		end)
		if success then
			if lostLock then
				-- another server took this player over: its copy is newer, stop writing ours
				session.lostLock = true
				warn("DataStoreHandler: profilį perėmė kitas serveris, šis nebesaugo", userId)
			end
			return true
		end
		warn(string.format("DataStoreHandler: nepavyko išsaugoti %d (%d/%d): %s", userId, attempt, SAVE_TRIES, tostring(err)))
		if attempt < SAVE_TRIES then
			task.wait(attempt * 2)
		end
	end
	return false
end

local function releaseSession(userId)
	local session = sessions[userId]
	if not session or session.releasing then
		return
	end
	session.releasing = true
	writeProfile(userId, session, true)
	if sessions[userId] == session then
		sessions[userId] = nil
	end
end

Players.PlayerAdded:Connect(loadProfile)
Players.PlayerRemoving:Connect(function(player)
	releaseSession(player.UserId)
end)

-- Play Solo: the player can already be in the game when this script starts
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadProfile, player)
end

-- Autosave (a server crash loses at most a couple of minutes)
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for userId, session in pairs(sessions) do
			if session.state == "ready" and not session.releasing then
				task.spawn(writeProfile, userId, session, false)
			end
		end
	end
end)

-- Shutdown: save everyone in parallel and wait (Roblox gives ~30 s)
local function flushAll()
	local pending = 0
	for userId, session in pairs(sessions) do
		if session.state == "ready" and not session.releasing then
			pending += 1
			task.spawn(function()
				releaseSession(userId)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end
game:BindToClose(flushAll)

local function getProfile(player)
	local session = sessions[player.UserId]
	if session and session.state == "ready" then
		return session.profile
	end
	return nil
end

_G.CoachAcademyData = {
	getProfile = getProfile,
	-- waits until the profile is loaded (nil if loading failed or the player left)
	waitForProfile = function(player, timeout)
		local deadline = os.clock() + (timeout or 60)
		while os.clock() < deadline do
			local session = sessions[player.UserId]
			if session and session.state == "ready" then
				return session.profile
			elseif session and session.state == "failed" then
				return nil
			end
			task.wait(0.1)
		end
		return nil
	end,
	-- save right away (after important events, e.g. a purchase)
	saveNow = function(player)
		local session = sessions[player.UserId]
		if session then
			task.spawn(writeProfile, player.UserId, session, false)
		end
	end,
	flushAll = flushAll,
	isPersistent = function()
		return dataStoreOk
	end,
}

print("DataStoreHandler paruoštas.")
