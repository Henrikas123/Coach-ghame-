--[[
	RetentionConfig
	Daily login reward (7-day streak cycle), daily quests and the Top Coaches leaderboard.
	Days are UTC days: os.time() // 86400.
]]

local RetentionConfig = {}

-- Login streak rewards: day 1..7, then the cycle repeats while the streak continues
RetentionConfig.DailyRewards = { 100, 150, 200, 300, 400, 500, 1000 }
-- Extra reputation on some streak days
RetentionConfig.DailyBonusReputation = { [7] = 5 }

-- Three quests per day: the first one is always doable for a brand-new player
RetentionConfig.QuestsPerDay = 3
RetentionConfig.StarterQuest = "train5"
RetentionConfig.Quests = {
	{ id = "train5", event = "train", target = 5, reward = 150, title = "Train 5 sessions", icon = "💪" },
	{ id = "win2", event = "fightWon", target = 2, reward = 250, title = "Win 2 fights", icon = "🥊" },
	{ id = "post3", event = "post", target = 3, reward = 150, title = "Post 3 times on SocialGym", icon = "📣" },
	{ id = "collect2", event = "collect", target = 2, reward = 120, title = "Collect sponsor income twice", icon = "💰" },
	{ id = "tournament1", event = "tournament", target = 1, reward = 200, title = "Enter a tournament", icon = "🏆" },
	{ id = "encourage2", event = "encourage", target = 2, reward = 80, title = "Encourage your fighters twice", icon = "🙌" },
	{ id = "scout1", event = "scout", target = 1, reward = 100, title = "Send your scout", icon = "🔎" },
}

RetentionConfig.LeaderboardStore = "CoachLeaderboard_v1"
RetentionConfig.LeaderboardSize = 20
RetentionConfig.LeaderboardRefreshSeconds = 60

function RetentionConfig.quest(id)
	for _, quest in ipairs(RetentionConfig.Quests) do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

return RetentionConfig
