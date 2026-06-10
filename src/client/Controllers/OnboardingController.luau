--!strict
-- Onboarding banner: shows the current guided step until the flow ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OnboardingConfig = require(ReplicatedStorage.Shared.Config.OnboardingConfig)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local OnboardingController = {}

local banner: TextLabel? = nil
local bannerGui: ScreenGui? = nil

local function update(snapshot: { [string]: any })
	local step = snapshot.Flags and snapshot.Flags.OnboardingStep or 0
	local def = OnboardingConfig.Steps[step]
	if def == nil then
		if bannerGui then
			bannerGui.Enabled = false
		end
		return
	end
	if banner and bannerGui then
		banner.Text = def.Text
		bannerGui.Enabled = true
	end
end

function OnboardingController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	bannerGui = UIKit.create("ScreenGui", { Name = "Onboarding", ResetOnSpawn = false, Enabled = false })
	bannerGui.Parent = playerGui

	banner = UIKit.label("", 16, {
		Size = UDim2.new(0.5, 0, 0, 46),
		Position = UDim2.new(0.25, 0, 0, 8),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = UIKit.Palette.Panel,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Palette.Accent,
	})
	UIKit.rounded(10).Parent = banner
	banner.Parent = bannerGui

	ProfileController.Changed:Connect(update)
	local existing = ProfileController:Get()
	if existing then
		update(existing)
	end
end

return OnboardingController
