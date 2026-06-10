--!strict
-- Battle Pass UI: tier list with claim buttons for both tracks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattlePassConfig = require(ReplicatedStorage.Shared.Config.BattlePassConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local BattlePassController = {}

local listFrame: ScrollingFrame
local headerLabel: TextLabel
local statusLabel: TextLabel

local function rewardText(reward: { [string]: any }): string
	if reward.Type == "Coins" or reward.Type == "Gems" then
		return `{reward.Count} {reward.Type}`
	end
	return `{reward.Id} x{reward.Count}`
end

local function rebuild(snapshot: { [string]: any })
	local pass = snapshot.BattlePass
	if pass == nil then
		return
	end
	local currentTier = math.min(BattlePassConfig.TierCount, math.floor(pass.Xp / BattlePassConfig.XpPerTier))
	headerLabel.Text = `Season {pass.Season}  |  Tier {currentTier}/{BattlePassConfig.TierCount}`

	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	listFrame.CanvasSize = UDim2.new(0, 0, 0, BattlePassConfig.TierCount * 46)

	for tier = 1, BattlePassConfig.TierCount do
		local row = UIKit.create("Frame", {
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundColor3 = if tier <= currentTier then UIKit.Palette.PanelLight else UIKit.Palette.Panel,
			LayoutOrder = tier,
		})
		UIKit.rounded():Clone().Parent = row
		row.Parent = listFrame

		local label = UIKit.label(`T{tier}`, 13, {
			Size = UDim2.new(0.12, 0, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label.Parent = row

		local function claimButton(track: "Free" | "Premium", offset: number)
			local reward = (if track == "Premium" then BattlePassConfig.PremiumTrack else BattlePassConfig.FreeTrack)[tier]
			local claimed = (if track == "Premium" then pass.ClaimedPremium else pass.ClaimedFree)[tostring(tier)]
			local reachable = tier <= currentTier and (track == "Free" or pass.OwnsPremium)
			local text = `{track}: {rewardText(reward)}` .. (if claimed then " (claimed)" else "")
			local button =
				UIKit.button(text, if claimed or not reachable then UIKit.Palette.Panel else UIKit.Palette.Accent, {
					Size = UDim2.new(0.41, 0, 0, 30),
					Position = UDim2.new(offset, 0, 0, 5),
					TextSize = 11,
					TextColor3 = if claimed or not reachable then UIKit.Palette.TextDim else Color3.fromRGB(20, 24, 28),
				})
			button.Parent = row
			button.Activated:Connect(function()
				local response = NetClient.Invoke("ClaimBattlePassTier", tier, track)
				if response.Ok then
					statusLabel.Text = `Claimed tier {tier} ({track})!`
					statusLabel.TextColor3 = UIKit.Palette.Positive
				else
					statusLabel.Text = response.Error or "Claim failed."
					statusLabel.TextColor3 = UIKit.Palette.Negative
				end
			end)
		end

		claimButton("Free", 0.14)
		claimButton("Premium", 0.57)
	end
end

function BattlePassController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = UIKit.create("ScreenGui", { Name = "BattlePass", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.4, 0, 0.7, 0),
		Position = UDim2.new(0.3, 0, 0.15, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	headerLabel = UIKit.label("Battle Pass", 20, {
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBold,
	})
	headerLabel.Parent = frame

	local closeButton = UIKit.button("X", UIKit.Palette.Negative, {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
	})
	closeButton.Parent = frame
	closeButton.Activated:Connect(function()
		screenGui.Enabled = false
	end)

	listFrame = UIKit.create("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -76),
		Position = UDim2.new(0, 8, 0, 44),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
	})
	listFrame.Parent = frame
	local listLayout =
		UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	listLayout.Parent = listFrame

	statusLabel = UIKit.label("", 13, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
	})
	statusLabel.Parent = frame

	local toggleGui = UIKit.create("ScreenGui", { Name = "BattlePassToggle", ResetOnSpawn = false })
	toggleGui.Parent = playerGui
	local toggle = UIKit.button("Pass", Color3.fromRGB(255, 213, 79), {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(0, 12, 0.5, 220),
	})
	toggle.Parent = toggleGui
	toggle.Activated:Connect(function()
		if not screenGui.Enabled then
			local snapshot = ProfileController:Get()
			if snapshot then
				rebuild(snapshot)
			end
		end
		screenGui.Enabled = not screenGui.Enabled
	end)

	ProfileController.Changed:Connect(function(snapshot)
		if screenGui.Enabled then
			rebuild(snapshot)
		end
	end)
end

return BattlePassController
