--[[
	Sfx
	Plays sounds from SoundConfig. Slots without an id are silently skipped.

	  Sfx.play("Cash")                 -- one-shot effect
	  Sfx.music("LoadingMusic")        -- looped music (one track at a time, fades in)
	  Sfx.stopMusic(0.8)               -- fade out current music
	  Sfx.setEnabled("Music", false)   -- mute a group ("Sfx" / "Music")
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundConfig = require(script.Parent:WaitForChild("SoundConfig"))

local Sfx = {}

local groups = {}
local enabled = { Sfx = true, Music = true }
local currentMusic = nil

local function getGroup(name)
	if groups[name] then
		return groups[name]
	end
	local group = SoundService:FindFirstChild("Coach" .. name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = "Coach" .. name
		group.Volume = 1
		group.Parent = SoundService
	end
	groups[name] = group
	return group
end

local function makeSound(name)
	local def = SoundConfig.Sounds[name]
	if not def or type(def.id) ~= "string" or def.id == "" then
		return nil, nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Coach_" .. name
	sound.SoundId = def.id
	sound.Volume = def.volume or 0.5
	sound.Looped = def.looped == true
	sound.SoundGroup = getGroup(def.group or "Sfx")
	sound.Parent = SoundService
	return sound, def
end

function Sfx.has(name)
	local def = SoundConfig.Sounds[name]
	return def ~= nil and type(def.id) == "string" and def.id ~= ""
end

function Sfx.play(name)
	local sound = makeSound(name)
	if not sound then
		return nil
	end
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(12, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

function Sfx.stopMusic(fadeTime)
	local music = currentMusic
	currentMusic = nil
	if not music then
		return
	end
	local tween = TweenService:Create(music, TweenInfo.new(fadeTime or 0.6), { Volume = 0 })
	tween:Play()
	task.delay((fadeTime or 0.6) + 0.05, function()
		music:Destroy()
	end)
end

function Sfx.music(name)
	if currentMusic and currentMusic.Name == "Coach_" .. name then
		return currentMusic
	end
	Sfx.stopMusic(0.6)
	local sound, def = makeSound(name)
	if not sound then
		return nil
	end
	sound.Looped = true
	sound.Volume = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(1.2), { Volume = def.volume or 0.35 }):Play()
	currentMusic = sound
	return sound
end

function Sfx.setEnabled(groupName, isEnabled)
	enabled[groupName] = isEnabled
	getGroup(groupName).Volume = isEnabled and 1 or 0
end

function Sfx.isEnabled(groupName)
	return enabled[groupName] ~= false
end

-- Sound instances to pass to ContentProvider:PreloadAsync (loading screen)
function Sfx.preloadList()
	local list = {}
	for name in pairs(SoundConfig.Sounds) do
		if Sfx.has(name) then
			local sound = Instance.new("Sound")
			sound.SoundId = SoundConfig.Sounds[name].id
			table.insert(list, sound)
		end
	end
	return list
end

return Sfx
