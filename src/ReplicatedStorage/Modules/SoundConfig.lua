--[[
	SoundConfig
	Every sound slot the game uses. Paste a Roblox audio asset ID into `id`
	(format: "rbxassetid://1234567890"). An empty id means the sound is skipped,
	so the game works fine before sounds are added.

	group: "Sfx" (effects) or "Music" -- the title screen toggles each group on/off.
]]

local SoundConfig = {}

SoundConfig.Sounds = {
	-- Interface
	Click = { id = "", volume = 0.45, group = "Sfx", note = "Soft UI click / light glove tap" },
	PanelOpen = { id = "", volume = 0.35, group = "Sfx", note = "Short whoosh when a panel opens" },
	Error = { id = "", volume = 0.4, group = "Sfx", note = "Gentle 'not allowed' blip" },

	-- Rewards
	Cash = { id = "", volume = 0.5, group = "Sfx", note = "Cash register 'ka-ching' (collect money)" },
	LevelUp = { id = "", volume = 0.6, group = "Sfx", note = "Reputation tier up fanfare" },

	-- Boxing
	Bell = { id = "", volume = 0.6, group = "Sfx", note = "Boxing bell 'ding-ding'" },
	Punch = { id = "", volume = 0.5, group = "Sfx", note = "Heavy punch impact (logo slam, big moments)" },
	Crowd = { id = "", volume = 0.5, group = "Sfx", note = "Crowd cheer (tournament win)" },

	-- Music (looped)
	LoadingMusic = { id = "", volume = 0.35, group = "Music", looped = true, note = "Calm, tense intro loop for loading/title" },
}

return SoundConfig
