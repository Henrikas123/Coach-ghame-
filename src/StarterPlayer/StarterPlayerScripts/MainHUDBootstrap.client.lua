local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local modules = ReplicatedStorage:WaitForChild("Modules")
local MainHUDController = require(modules:WaitForChild("MainHUDController"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD_Premium"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

MainHUDController.Init(screenGui, player)

print("MainHUDBootstrap: MainHUD_Premium paleistas.")
