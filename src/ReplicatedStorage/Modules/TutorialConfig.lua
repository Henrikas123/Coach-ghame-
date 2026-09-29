--[[
	TutorialConfig
	First-5-minutes guide: meet the first fighter -> train -> first fight -> grow the gym -> daily goals.
	kind: "ack"   = player presses the card button
	      "panel" = opening that panel completes the step
	      "event" = server event (train / fightDone / post) `count` times
	highlight: HUD element to point at (inside MainHUD_Premium), world: part in Workspace.GymLayout to guide to
]]

local TutorialConfig = {}

TutorialConfig.CompletionReward = 250

TutorialConfig.Steps = {
	{
		id = "welcome",
		kind = "ack",
		title = "Welcome, Coach!",
		text = "This is your academy. Let's turn your first fighter into a champion.",
		button = "Let's go",
	},
	{
		id = "meet",
		kind = "panel",
		panel = "Academy",
		title = "Meet your first fighter",
		text = "Open the ACADEMY to meet Alex Martin, your first fighter.",
		highlight = "AcademyButton",
	},
	{
		id = "train",
		kind = "event",
		event = "train",
		count = 2,
		title = "Train Alex",
		text = "Walk to a training station, press E and hit TRAIN. Do it twice.",
		world = "PunchingBagStation",
		worldLabel = "TRAIN HERE",
	},
	{
		id = "fight",
		kind = "event",
		event = "fightDone",
		count = 1,
		title = "First fight!",
		text = "Alex is fight-ready. Step into the ring, press E and send Alex in.",
		world = "RingPlaceholder",
		worldLabel = "FIGHT HERE",
	},
	{
		id = "post",
		kind = "event",
		event = "post",
		count = 1,
		title = "Grow your gym",
		text = "Open your phone and post on SocialGym — followers bring new fighters.",
		highlight = "PhoneFab",
	},
	{
		id = "goals",
		kind = "panel",
		panel = "Goals",
		title = "Daily Goals",
		text = "Finish daily quests and log in every day for bigger rewards.",
		highlight = "GoalsButton",
	},
}

return TutorialConfig
