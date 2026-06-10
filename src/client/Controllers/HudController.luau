--!strict
-- Persistent top-bar HUD: Coins, Gems, Battle Tokens and Trophies.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local HudController = {}

local labels: { [string]: TextLabel } = {}

local function formatNumber(value: number): string
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 10000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

local function update(snapshot: { [string]: any })
	local currencies = snapshot.Currencies or {}
	local stats = snapshot.Stats or {}
	if labels.Coins then
		labels.Coins.Text = `Coins: {formatNumber(currencies.Coins or 0)}`
	end
	if labels.Gems then
		labels.Gems.Text = `Gems: {formatNumber(currencies.Gems or 0)}`
	end
	if labels.Tokens then
		labels.Tokens.Text = `Tokens: {formatNumber(currencies.BattleTokens or 0)}`
	end
	if labels.Trophies then
		labels.Trophies.Text = `Trophies: {formatNumber(stats.Trophies or 0)}`
	end
end

function HudController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = UIKit.create("ScreenGui", { Name = "Hud", ResetOnSpawn = false })
	screenGui.Parent = playerGui

	local bar = UIKit.create("Frame", {
		Size = UDim2.new(0, 520, 0, 34),
		Position = UDim2.new(0.5, -260, 0, 6),
		BackgroundColor3 = UIKit.Palette.Panel,
		BackgroundTransparency = 0.2,
	})
	UIKit.rounded(10).Parent = bar
	bar.Parent = screenGui

	local layout = UIKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 18),
	})
	layout.Parent = bar

	local slots = {
		{ Key = "Coins", Colour = UIKit.Palette.Accent },
		{ Key = "Gems", Colour = Color3.fromRGB(3, 169, 244) },
		{ Key = "Tokens", Colour = Color3.fromRGB(239, 83, 80) },
		{ Key = "Trophies", Colour = Color3.fromRGB(255, 213, 79) },
	}
	for _, slot in slots do
		local label = UIKit.label(`{slot.Key}: 0`, 14, {
			Size = UDim2.new(0, 115, 1, 0),
			Font = Enum.Font.GothamBold,
			TextColor3 = slot.Colour,
		})
		label.Parent = bar
		labels[slot.Key] = label
	end

	ProfileController.Changed:Connect(update)
	local existing = ProfileController:Get()
	if existing then
		update(existing)
	end

	NetClient.On("SeasonRollover", function(payload)
		local toastGui = UIKit.create("ScreenGui", { Name = "SeasonToast", ResetOnSpawn = false })
		toastGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local text =
			`New season! You placed {payload.Placement} (+{payload.PlacementGems} Gems). Trophies reset to {payload.NewTrophies}.`
		local toast = UIKit.label(text, 16, {
			Size = UDim2.new(0.5, 0, 0, 44),
			Position = UDim2.new(0.25, 0, 0, 48),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = UIKit.Palette.Panel,
			Font = Enum.Font.GothamBold,
			TextColor3 = UIKit.Palette.Accent,
		})
		UIKit.rounded(10).Parent = toast
		toast.Parent = toastGui
		Debris:AddItem(toastGui, 6)
	end)
end

return HudController
