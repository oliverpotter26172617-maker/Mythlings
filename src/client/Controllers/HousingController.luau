--!strict
-- Housing UI: buy and place furniture, upgrade the plot, switch themes,
-- claim idle income, visit friends. Placement picks the first free grid
-- spot client-side for convenience; the server fully re-validates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HousingConfig = require(ReplicatedStorage.Shared.Config.HousingConfig)
local HousingLogic = require(ReplicatedStorage.Shared.Logic.HousingLogic)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local HousingController = {}

local localPlayer = Players.LocalPlayer
local statusLabel: TextLabel

local function setStatus(text: string, positive: boolean)
	statusLabel.Text = text
	statusLabel.TextColor3 = if positive then UIKit.Palette.Positive else UIKit.Palette.Negative
end

local function teleportToPlot(ownerUserId: number)
	local plots = workspace:FindFirstChild("Plots")
	if plots == nil then
		return
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == ownerUserId then
			local floor = plot:FindFirstChild("Floor")
			local character = localPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if floor and floor:IsA("BasePart") and rootPart then
				rootPart.CFrame = CFrame.new(floor.Position + Vector3.new(0, 6, 0))
			end
			return
		end
	end
end

-- Finds the first grid spot where the item fits, scanning the plot.
local function findFreeSpot(itemId: string): (number?, number?)
	local snapshot = ProfileController:Get()
	if snapshot == nil then
		return nil, nil
	end
	local housing = (snapshot :: any).Housing
	local tier = HousingConfig.PlotTiers[housing.PlotTier]
	local half = tier.Cells / 2
	for z = -half, half - 1 do
		for x = -half, half - 1 do
			if HousingLogic.canPlace(housing.PlotTier, housing.Furniture, itemId, x, z, 0) then
				return x, z
			end
		end
	end
	return nil, nil
end

function HousingController:OnStart()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local screenGui = UIKit.create("ScreenGui", { Name = "Housing", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.36, 0, 0.62, 0),
		Position = UDim2.new(0.32, 0, 0.19, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("My Plot", 22, {
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
		Size = UDim2.new(1, -16, 1, -110),
		Position = UDim2.new(0, 8, 0, 44),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(0, 0, 0, 600),
	})
	listFrame.Parent = frame
	local listLayout = UIKit.create("UIListLayout", { Padding = UDim.new(0, 6) })
	listLayout.Parent = listFrame

	-- Action row: home teleport, upgrade, claim income.
	local homeButton = UIKit.button("Go home", UIKit.Palette.Positive, {
		Size = UDim2.new(0.3, 0, 0, 32),
		Position = UDim2.new(0.02, 0, 1, -66),
	})
	homeButton.Parent = frame
	homeButton.Activated:Connect(function()
		teleportToPlot(localPlayer.UserId)
	end)

	local upgradeButton = UIKit.button("Upgrade plot", UIKit.Palette.Accent, {
		Size = UDim2.new(0.3, 0, 0, 32),
		Position = UDim2.new(0.35, 0, 1, -66),
	})
	upgradeButton.Parent = frame
	upgradeButton.Activated:Connect(function()
		local response = NetClient.Invoke("BuyPlotUpgrade")
		setStatus(if response.Ok then "Plot upgraded!" else response.Error or "Upgrade failed.", response.Ok)
	end)

	local incomeButton = UIKit.button("Claim income", UIKit.Palette.Accent, {
		Size = UDim2.new(0.3, 0, 0, 32),
		Position = UDim2.new(0.68, 0, 1, -66),
	})
	incomeButton.Parent = frame
	incomeButton.Activated:Connect(function()
		local response = NetClient.Invoke("ClaimPlotIncome")
		if response.Ok then
			setStatus(`Collected {response.Data.Coins} Coins from your Mythlings!`, true)
		else
			setStatus(response.Error or "Nothing to collect yet.", false)
		end
	end)

	statusLabel = UIKit.label("", 13, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
	})
	statusLabel.Parent = frame

	-- Furniture catalogue with buy and place actions.
	local itemIds = {}
	for itemId in HousingConfig.Furniture do
		table.insert(itemIds, itemId)
	end
	table.sort(itemIds)

	for _, itemId in itemIds do
		local item = HousingConfig.Furniture[itemId]
		local row = UIKit.create("Frame", {
			Size = UDim2.new(1, -8, 0, 38),
			BackgroundTransparency = 1,
		})
		row.Parent = listFrame

		local label = UIKit.label(`{item.DisplayName} ({item.PriceCoins} Coins)`, 13, {
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 6, 0, 0),
		})
		label.Parent = row

		local buyButton = UIKit.button("Buy", UIKit.Palette.Accent, {
			Size = UDim2.new(0.2, 0, 0, 28),
			Position = UDim2.new(0.52, 0, 0, 5),
			TextSize = 13,
		})
		buyButton.Parent = row
		buyButton.Activated:Connect(function()
			local response = NetClient.Invoke("BuyFurniture", itemId)
			setStatus(
				if response.Ok then `Bought a {item.DisplayName}.` else response.Error or "Could not buy.",
				response.Ok
			)
		end)

		local placeButton = UIKit.button("Place", UIKit.Palette.Positive, {
			Size = UDim2.new(0.2, 0, 0, 28),
			Position = UDim2.new(0.76, 0, 0, 5),
			TextSize = 13,
		})
		placeButton.Parent = row
		placeButton.Activated:Connect(function()
			local x, z = findFreeSpot(itemId)
			if x == nil then
				setStatus("No room on your plot for that.", false)
				return
			end
			local response = NetClient.Invoke("PlaceFurniture", itemId, x, z, 0)
			setStatus(
				if response.Ok then `Placed your {item.DisplayName}!` else response.Error or "Could not place.",
				response.Ok
			)
		end)
	end

	local toggleGui = UIKit.create("ScreenGui", { Name = "HousingToggle", ResetOnSpawn = false })
	toggleGui.Parent = playerGui
	local toggle = UIKit.button("My Plot", Color3.fromRGB(141, 110, 99), {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(0, 12, 0.5, 268),
	})
	toggle.Parent = toggleGui
	toggle.Activated:Connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)
end

return HousingController
