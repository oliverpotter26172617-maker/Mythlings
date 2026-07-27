--!strict
-- Gem packs and game passes. Prompting uses the native Roblox purchase
-- flow; granting happens server-side in MonetisationService.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetisationConfig = require(ReplicatedStorage.Shared.Config.MonetisationConfig)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local GemShopController = {}

local localPlayer = Players.LocalPlayer

function GemShopController:OnStart()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local screenGui = UIKit.create("ScreenGui", { Name = "GemShop", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.34, 0, 0.6, 0),
		Position = UDim2.new(0.33, 0, 0.2, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("Gem Shop", 22, {
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

	local listFrame = UIKit.create("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -52),
		Position = UDim2.new(0, 8, 0, 44),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(0, 0, 0, 480),
	})
	listFrame.Parent = frame
	local listLayout = UIKit.create("UIListLayout", { Padding = UDim.new(0, 6) })
	listLayout.Parent = listFrame

	-- Gem packs, smallest first.
	local packKeys = {}
	for key, def in MonetisationConfig.DevProducts do
		if def.Type == "Gems" then
			table.insert(packKeys, key)
		end
	end
	table.sort(packKeys, function(a, b)
		return (MonetisationConfig.DevProducts[a].Amount or 0) < (MonetisationConfig.DevProducts[b].Amount or 0)
	end)

	for _, key in packKeys do
		local def = MonetisationConfig.DevProducts[key]
		local entry = UIKit.button(`{def.Amount} Gems  ({def.Robux} R$)`, UIKit.Palette.Accent, {
			Size = UDim2.new(1, -8, 0, 40),
		})
		entry.Parent = listFrame
		entry.Activated:Connect(function()
			if def.ProductId == 0 then
				entry.Text = "Coming soon!"
				task.delay(1.5, function()
					entry.Text = `{def.Amount} Gems  ({def.Robux} R$)`
				end)
				return
			end
			MarketplaceService:PromptProductPurchase(localPlayer, def.ProductId)
		end)
	end

	-- Game passes.
	local passOrder = { "VIP", "HatchSpeed", "TripleHatch", "AutoHatch", "ExtraStorage" }
	local passLabels = {
		VIP = "VIP: +25% Coins and daily Gems",
		HatchSpeed = "Hatch Speed +50%",
		TripleHatch = "Triple Hatch",
		AutoHatch = "Auto-Hatch",
		ExtraStorage = "+100 Mythling storage",
	}
	for _, passKey in passOrder do
		local def = MonetisationConfig.GamePasses[passKey]
		local entry = UIKit.button(`{passLabels[passKey]}  ({def.Robux} R$)`, UIKit.Palette.PanelLight, {
			Size = UDim2.new(1, -8, 0, 40),
			TextColor3 = UIKit.Palette.Text,
			TextSize = 14,
		})
		entry.Parent = listFrame
		entry.Activated:Connect(function()
			if def.PassId == 0 then
				entry.Text = "Coming soon!"
				task.delay(1.5, function()
					entry.Text = `{passLabels[passKey]}  ({def.Robux} R$)`
				end)
				return
			end
			MarketplaceService:PromptGamePassPurchase(localPlayer, def.PassId)
		end)
	end

	local toggle = UIKit.toolbarButton("Gems", Color3.fromRGB(3, 169, 244), 124)
	toggle.Activated:Connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)
end

return GemShopController
