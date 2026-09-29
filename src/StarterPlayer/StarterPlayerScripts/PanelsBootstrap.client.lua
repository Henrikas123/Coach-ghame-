-- LocalScript: StarterPlayer/StarterPlayerScripts/PanelsBootstrap
-- Uzregistruoja visas HUD paneles i _G.CoachAcademyPanels (MainHUDController NavDock/PhoneFab jas kviecia).
-- Paneles kuriamos tingiai -- pirmo atidarymo metu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
player:WaitForChild("PlayerGui")

local modules = ReplicatedStorage:WaitForChild("Modules")
local panelsFolder = modules:WaitForChild("Panels")

local PanelKit = require(panelsFolder:WaitForChild("PanelKit"))
local ClientState = require(panelsFolder:WaitForChild("ClientState"))

ClientState.start()

local PANEL_MODULES = {
	Profile = "ProfilePanel",
	Academy = "AcademyPanel",
	Staff = "StaffPanel",
	Scout = "ScoutPanel",
	Sponsor = "SponsorPanel",
	Tournament = "TournamentPanel",
	Phone = "PhonePanel",
}

-- Musu paneliu funkcijos. _G.CoachAcademyPanels pakeiciamas proxy lentele, kad senieji UI skriptai
-- (AcademyUI, PhoneUI, FighterProfileUI ir kt.), jei dar ijungti, negaletu perrasyti siu raktu.
local owned = {}
local legacy = {}
local warned = {}

for key, moduleName in pairs(PANEL_MODULES) do
	local moduleScript = panelsFolder:FindFirstChild(moduleName)
	if moduleScript then
		PanelKit.register(key, function()
			local panelModule = require(moduleScript)
			return panelModule.create(PanelKit, ClientState)
		end)
		owned[key] = function()
			PanelKit.toggle(key)
		end
	else
		warn("PanelsBootstrap: nerastas panelės modulis " .. moduleName)
	end
end

local existing = _G.CoachAcademyPanels
if type(existing) == "table" then
	for key, fn in pairs(existing) do
		if not owned[key] then
			legacy[key] = fn
		end
	end
end

_G.CoachAcademyPanels = setmetatable({}, {
	__index = function(_, key)
		return owned[key] or legacy[key]
	end,
	__newindex = function(_, key, value)
		if owned[key] then
			if not warned[key] then
				warned[key] = true
				warn("PanelsBootstrap: senas UI skriptas bandė perrašyti _G.CoachAcademyPanels." .. tostring(key) .. " -- ignoruojama (išjunk seną skriptą).")
			end
			return
		end
		legacy[key] = value
	end,
})

print("PanelsBootstrap: HUD panelės užregistruotos.")
