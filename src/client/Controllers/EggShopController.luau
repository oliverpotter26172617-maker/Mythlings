--!strict
-- Egg shop UI. The odds panel renders straight from EggConfig, so what the
-- player sees before buying is exactly what the server rolls with (Roblox
-- paid random item policy).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local EggShopController = {}

local screenGui: ScreenGui
local shopFrame: Frame
local detailFrame: Frame
local statusLabel: TextLabel

local function rarityColour(rarity: string): Color3
	local c = RarityConfig.Colours[rarity]
	return Color3.fromRGB(c.R, c.G, c.B)
end

local function setStatus(text: string, positive: boolean)
	statusLabel.Text = text
	statusLabel.TextColor3 = if positive then UIKit.Palette.Positive else UIKit.Palette.Negative
end

-- Builds the pre-purchase detail view: full odds table plus the buy button.
-- Buying is only reachable through this panel, so odds are always shown
-- before any randomised purchase.
local function showDetail(tierId: string)
	detailFrame:ClearAllChildren()
	local tier = EggConfig.Tiers[tierId]

	local layout = UIKit.create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	layout.Parent = detailFrame

	local title = UIKit.label(tier.DisplayName, 20, {
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBold,
		LayoutOrder = 1,
	})
	title.Parent = detailFrame

	local priceText = `{tier.Price.Amount} {tier.Price.Currency}  |  Hatch time: {tier.HatchMinutes} min`
	local price = UIKit.label(priceText, 14, {
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = UIKit.Palette.TextDim,
		LayoutOrder = 2,
	})
	price.Parent = detailFrame

	local oddsHeader = UIKit.label("Hatch odds", 16, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		LayoutOrder = 3,
	})
	oddsHeader.Parent = detailFrame

	local order = 4
	for _, rarity in RarityConfig.Order do
		local weight = tier.Odds[rarity]
		if weight ~= nil and weight > 0 then
			local row = UIKit.label(`{rarity}: {weight}%`, 15, {
				Size = UDim2.new(1, 0, 0, 20),
				TextColor3 = rarityColour(rarity),
				LayoutOrder = order,
			})
			row.Parent = detailFrame
			order += 1
		end
	end

	local buyButton = UIKit.button(`Buy for {tier.Price.Amount} {tier.Price.Currency}`, UIKit.Palette.Accent, {
		Size = UDim2.new(0.8, 0, 0, 36),
		LayoutOrder = order,
	})
	buyButton.Parent = detailFrame
	buyButton.Activated:Connect(function()
		buyButton.Text = "Buying..."
		local response = NetClient.Invoke("BuyEgg", tierId)
		buyButton.Text = `Buy for {tier.Price.Amount} {tier.Price.Currency}`
		if response.Ok then
			setStatus(`You bought a {tier.DisplayName}!`, true)
		else
			setStatus(response.Error or "Purchase failed.", false)
		end
	end)
end

local function buildShop()
	local tierIds = {}
	for tierId in EggConfig.Tiers do
		table.insert(tierIds, tierId)
	end
	table.sort(tierIds, function(a, b)
		return EggConfig.Tiers[a].ShopOrder < EggConfig.Tiers[b].ShopOrder
	end)

	local listFrame = UIKit.create("ScrollingFrame", {
		Size = UDim2.new(0.45, 0, 1, -40),
		Position = UDim2.new(0, 0, 0, 40),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, #tierIds * 46),
		ScrollBarThickness = 4,
	})
	listFrame.Parent = shopFrame

	local listLayout = UIKit.create("UIListLayout", { Padding = UDim.new(0, 6) })
	listLayout.Parent = listFrame

	for _, tierId in tierIds do
		local tier = EggConfig.Tiers[tierId]
		local entry = UIKit.button(tier.DisplayName, UIKit.Palette.PanelLight, {
			Size = UDim2.new(1, -8, 0, 40),
			TextColor3 = UIKit.Palette.Text,
		})
		entry.Parent = listFrame
		entry.Activated:Connect(function()
			showDetail(tierId)
		end)
	end
end

function EggShopController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screenGui = UIKit.create("ScreenGui", {
		Name = "EggShop",
		ResetOnSpawn = false,
		Enabled = false,
		IgnoreGuiInset = true,
	})
	screenGui.Parent = playerGui

	shopFrame = UIKit.create("Frame", {
		Size = UDim2.new(0.6, 0, 0.65, 0),
		Position = UDim2.new(0.2, 0, 0.175, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = shopFrame
	shopFrame.Parent = screenGui

	local header = UIKit.label("Egg Shop", 22, {
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBold,
	})
	header.Parent = shopFrame

	local closeButton = UIKit.button("X", UIKit.Palette.Negative, {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
	})
	closeButton.Parent = shopFrame
	closeButton.Activated:Connect(function()
		screenGui.Enabled = false
	end)

	detailFrame = UIKit.create("Frame", {
		Size = UDim2.new(0.52, -8, 1, -48),
		Position = UDim2.new(0.46, 0, 0, 40),
		BackgroundColor3 = UIKit.Palette.PanelLight,
	})
	UIKit.rounded(10).Parent = detailFrame
	detailFrame.Parent = shopFrame

	statusLabel = UIKit.label("", 14, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -22),
	})
	statusLabel.Parent = shopFrame

	buildShop()

	-- Toggle button on the main screen.
	local toggleGui = UIKit.create("ScreenGui", { Name = "EggShopToggle", ResetOnSpawn = false })
	toggleGui.Parent = playerGui
	local toggle = UIKit.button("Egg Shop", UIKit.Palette.Accent, {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(0, 12, 0.5, -20),
	})
	toggle.Parent = toggleGui
	toggle.Activated:Connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)
end

return EggShopController
