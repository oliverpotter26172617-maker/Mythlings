--!strict
-- Premium Nursery UI: this week's rotating offers, priced in Gems.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local NurseryLogic = require(ReplicatedStorage.Shared.Logic.NurseryLogic)
local RaidLogic = require(ReplicatedStorage.Shared.Logic.RaidLogic)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local NurseryController = {}

function NurseryController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = UIKit.create("ScreenGui", { Name = "Nursery", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.34, 0, 0.5, 0),
		Position = UDim2.new(0.33, 0, 0.25, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("Premium Nursery", 22, {
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBold,
	})
	header.Parent = frame

	local subtitle = UIKit.label("New Mythlings every week. All of these also hatch free from Mythic eggs!", 12, {
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 0, 34),
		TextColor3 = UIKit.Palette.TextDim,
	})
	subtitle.Parent = frame

	local closeButton = UIKit.button("X", UIKit.Palette.Negative, {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
	})
	closeButton.Parent = frame
	closeButton.Activated:Connect(function()
		screenGui.Enabled = false
	end)

	local statusLabel = UIKit.label("", 13, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
	})
	statusLabel.Parent = frame

	local listFrame = UIKit.create("Frame", {
		Size = UDim2.new(1, -16, 1, -98),
		Position = UDim2.new(0, 8, 0, 68),
		BackgroundTransparency = 1,
	})
	listFrame.Parent = frame
	local listLayout = UIKit.create("UIListLayout", { Padding = UDim.new(0, 6) })
	listLayout.Parent = listFrame

	local function rebuild()
		for _, child in listFrame:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local week = RaidLogic.weekIndex(math.floor(Workspace:GetServerTimeNow()))
		local offers = NurseryLogic.offersForWeek(week)
		for index, offer in offers do
			local species = MythlingConfig.Species[offer.SpeciesId]
			local colour = RarityConfig.Colours[offer.Rarity]
			local entry = UIKit.button(
				`{species.DisplayName} ({offer.Rarity})  -  {offer.PriceGems} Gems`,
				UIKit.Palette.PanelLight,
				{
					Size = UDim2.new(1, 0, 0, 42),
					TextColor3 = Color3.fromRGB(colour.R, colour.G, colour.B),
					TextSize = 14,
				}
			)
			entry.Parent = listFrame
			UIKit.onActivated(entry, function()
				local response = NetClient.Invoke("BuyNurseryMythling", index)
				if response.Ok then
					statusLabel.Text = `{species.DisplayName} joined your collection!`
					statusLabel.TextColor3 = UIKit.Palette.Positive
				else
					statusLabel.Text = response.Error or "Purchase failed."
					statusLabel.TextColor3 = UIKit.Palette.Negative
				end
			end)
		end
	end

	local toggle = UIKit.toolbarButton("Nursery", Color3.fromRGB(255, 138, 101), 172)
	toggle.Activated:Connect(function()
		if not screenGui.Enabled then
			rebuild()
		end
		screenGui.Enabled = not screenGui.Enabled
	end)
end

return NurseryController
