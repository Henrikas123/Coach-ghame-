-- Script: ServerScriptService/FighterRigBuilder
-- Builds ReplicatedStorage.FighterRig once: a plain R15 body that the UI (FighterAppearance) poses and
-- dresses for every fighter. A rig named "FighterRig" already placed in ReplicatedStorage (for example
-- a nicer custom body made in Studio) is left untouched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RIG_NAME = "FighterRig"

if ReplicatedStorage:FindFirstChild(RIG_NAME) then
	return
end

local rig = nil
for attempt = 1, 4 do
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		rig = result
		break
	end
	warn(string.format("FighterRigBuilder: attempt %d failed: %s", attempt, tostring(result)))
	task.wait(2 * attempt)
end

if not rig then
	warn("FighterRigBuilder: no rig, the UI shows fighter initials instead of 3D fighters")
	return
end

-- scripts would run on the client once the rig is cloned into a ViewportFrame in PlayerGui;
-- everything must stay Archivable, otherwise Clone() on the client returns nil
rig.Archivable = true
for _, item in ipairs(rig:GetDescendants()) do
	if item:IsA("LuaSourceContainer") then
		item:Destroy()
	else
		item.Archivable = true
	end
end
local root = rig:FindFirstChild("HumanoidRootPart")
if root then
	rig.PrimaryPart = root
	root.Anchored = true
end
rig.Name = RIG_NAME
rig.Parent = ReplicatedStorage

print("FighterRigBuilder paruoštas.")
