--!strict
-- Quests UI: daily and weekly lists with progress and claims, the login
-- calendar toast, and one-tap friend gifting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local QuestController = {}

local localPlayer = Players.LocalPlayer
local listFrame: ScrollingFrame
local statusLabel: TextLabel

local function defFor(questId: string): { [string]: any }?
	for _, pool in { QuestConfig.DailyPool, QuestConfig.WeeklyPool } do
		for _, def in pool do
			if def.Id == questId then
				return def
			end
		end
	end
	return nil
end

local function rebuild(snapshot: { [string]: any })
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local order = 1
	for _, scope in { "Daily", "Weekly" } do
		local header =
			UIKit.create("Frame", { Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, LayoutOrder = order })
		order += 1
		UIKit.label(`{scope} quests`, 15, { Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBold }).Parent = header
		header.Parent = listFrame

		for _, quest in (snapshot :: any).Quests[scope] do
			local def = defFor(quest.Id)
			if def == nil then
				continue
			end
			local row = UIKit.create("Frame", {
				Size = UDim2.new(1, -8, 0, 40),
				BackgroundColor3 = UIKit.Palette.PanelLight,
				LayoutOrder = order,
			})
			order += 1
			UIKit.rounded():Clone().Parent = row
			row.Parent = listFrame

			local text = `{def.Description}  ({math.min(quest.Progress, def.Target)}/{def.Target})`
			local label = UIKit.label(text, 13, {
				Size = UDim2.new(0.66, 0, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			label.Parent = row

			local done = quest.Progress >= def.Target
			local claimText = if quest.Claimed then "Claimed" elseif done then "Claim!" else "..."
			local button = UIKit.button(
				claimText,
				if done and not quest.Claimed then UIKit.Palette.Accent else UIKit.Palette.Panel,
				{
					Size = UDim2.new(0.28, 0, 0, 30),
					Position = UDim2.new(0.69, 0, 0, 5),
					TextSize = 12,
					TextColor3 = if done and not quest.Claimed
						then Color3.fromRGB(20, 24, 28)
						else UIKit.Palette.TextDim,
				}
			)
			button.Parent = row
			button.Activated:Connect(function()
				local response = NetClient.Invoke("ClaimQuest", scope, quest.Id)
				if response.Ok then
					statusLabel.Text = "Quest reward claimed!"
					statusLabel.TextColor3 = UIKit.Palette.Positive
				else
					statusLabel.Text = response.Error or "Cannot claim yet."
					statusLabel.TextColor3 = UIKit.Palette.Negative
				end
			end)
		end
	end

	-- Friend gifting row.
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == localPlayer then
			continue
		end
		local row = UIKit.create("Frame", {
			Size = UDim2.new(1, -8, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		})
		order += 1
		row.Parent = listFrame
		local giftButton = UIKit.button(`Gift egg to {otherPlayer.DisplayName}`, UIKit.Palette.Positive, {
			Size = UDim2.new(1, 0, 0, 30),
			TextSize = 12,
		})
		giftButton.Parent = row
		giftButton.Activated:Connect(function()
			local response = NetClient.Invoke("GiftEgg", otherPlayer.UserId)
			if response.Ok then
				statusLabel.Text = `Egg sent to {otherPlayer.DisplayName}!`
				statusLabel.TextColor3 = UIKit.Palette.Positive
			else
				statusLabel.Text = response.Error or "Could not gift."
				statusLabel.TextColor3 = UIKit.Palette.Negative
			end
		end)
	end

	listFrame.CanvasSize = UDim2.new(0, 0, 0, order * 46)
end

local function showCalendarToast(payload: { [string]: any })
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local toastGui = UIKit.create("ScreenGui", { Name = "CalendarToast", ResetOnSpawn = false })
	toastGui.Parent = playerGui

	local granted = payload.Granted
	local what = if granted.Type == "Coins" or granted.Type == "Gems"
		then `{granted.Count} {granted.Type}`
		else `{granted.Id} x{granted.Count}`
	local label = UIKit.label(`Daily login day {payload.Day}: {what}!`, 18, {
		Size = UDim2.new(0.4, 0, 0, 40),
		Position = UDim2.new(0.3, 0, 0.06, 0),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = UIKit.Palette.Panel,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Palette.Accent,
	})
	UIKit.rounded(10).Parent = label
	label.Parent = toastGui
	Debris:AddItem(toastGui, 4)
end

function QuestController:OnStart()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local screenGui = UIKit.create("ScreenGui", { Name = "Quests", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.36, 0, 0.66, 0),
		Position = UDim2.new(0.32, 0, 0.17, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("Quests", 22, {
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

	listFrame = UIKit.create("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -76),
		Position = UDim2.new(0, 8, 0, 44),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
	})
	listFrame.Parent = frame
	UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }).Parent =
		listFrame

	statusLabel = UIKit.label("", 13, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
	})
	statusLabel.Parent = frame

	local toggleGui = UIKit.create("ScreenGui", { Name = "QuestsToggle", ResetOnSpawn = false })
	toggleGui.Parent = playerGui
	local toggle = UIKit.button("Quests", Color3.fromRGB(77, 182, 172), {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(0, 12, 0.5, 316),
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

	NetClient.On("CalendarReward", showCalendarToast)
end

return QuestController
