--!strict
-- Settings panel: Music, SFX and Low Quality toggles, persisted to the
-- profile. The SFX toggle gates the shared button click sound.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local SettingsController = {}

local buttons: { [string]: TextButton } = {}

local clickSound: Sound

local function playClick()
	local snapshot = ProfileController:Get()
	local sfxOn = true
	if snapshot and (snapshot :: any).Settings then
		sfxOn = (snapshot :: any).Settings.Sfx ~= false
	end
	if sfxOn and clickSound then
		SoundService:PlayLocalSound(clickSound)
	end
end

local function refresh(snapshot: { [string]: any })
	local settings = snapshot.Settings or {}
	for key, button in buttons do
		local enabled = settings[key] ~= false
		button.Text = `{key}: {if enabled then "On" else "Off"}`
		button.BackgroundColor3 = if enabled then UIKit.Palette.Positive else UIKit.Palette.PanelLight
		button.TextColor3 = if enabled then Color3.fromRGB(20, 24, 28) else UIKit.Palette.Text
	end
end

function SettingsController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	clickSound = Instance.new("Sound")
	clickSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	clickSound.Volume = 0.4
	clickSound.Parent = SoundService

	local screenGui = UIKit.create("ScreenGui", { Name = "Settings", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0, 240, 0, 220),
		Position = UDim2.new(0.5, -120, 0.3, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("Settings", 20, {
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBold,
	})
	header.Parent = frame

	local closeButton = UIKit.button("X", UIKit.Palette.Negative, {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
	})
	closeButton.Parent = frame
	closeButton.Activated:Connect(function()
		screenGui.Enabled = false
	end)

	for index, key in { "Music", "Sfx", "LowQuality" } do
		local button = UIKit.button(`{key}: On`, UIKit.Palette.Positive, {
			Size = UDim2.new(0.8, 0, 0, 38),
			Position = UDim2.new(0.1, 0, 0, 40 + index * 46),
		})
		button.Parent = frame
		buttons[key] = button
		button.Activated:Connect(function()
			local snapshot = ProfileController:Get()
			local current = true
			if snapshot and (snapshot :: any).Settings then
				current = (snapshot :: any).Settings[key] ~= false
			end
			playClick()
			NetClient.Invoke("UpdateSetting", key, not current)
		end)
	end

	local toggle = UIKit.toolbarButton("Settings", UIKit.Palette.PanelLight, -116)
	toggle.TextColor3 = UIKit.Palette.Text
	toggle.Activated:Connect(function()
		playClick()
		screenGui.Enabled = not screenGui.Enabled
	end)

	ProfileController.Changed:Connect(refresh)
	local existing = ProfileController:Get()
	if existing then
		refresh(existing)
	end
end

return SettingsController
