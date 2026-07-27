--!strict
-- Collection UI: every owned Mythling with rarity, stage and Shiny
-- status. Pick up to three as followers; the same roster is the arena
-- battle team. Completes the onboarding SetTeam step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local CollectionController = {}

local listFrame: ScrollingFrame
local statusLabel: TextLabel
local applyButton: TextButton
local selected: { string } = {}

local function setStatus(text: string, positive: boolean)
	statusLabel.Text = text
	statusLabel.TextColor3 = if positive then UIKit.Palette.Positive else UIKit.Palette.Negative
end

local function refreshApplyButton()
	applyButton.Text = `Set team ({#selected}/{PlayerConfig.MaxFollowers})`
end

local function rebuild(snapshot: { [string]: any })
	for _, child in listFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Start the selection from the current roster.
	selected = {}
	for _, mythlingId in (snapshot :: any).ActiveMythlings do
		table.insert(selected, mythlingId)
	end
	refreshApplyButton()

	local ids = {}
	for mythlingId in snapshot.Mythlings do
		table.insert(ids, mythlingId)
	end
	-- Rarest first, then newest.
	table.sort(ids, function(a, b)
		local recordA, recordB = snapshot.Mythlings[a], snapshot.Mythlings[b]
		local rarityA = RarityConfig.IndexByName[recordA.Rarity] or 0
		local rarityB = RarityConfig.IndexByName[recordB.Rarity] or 0
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		return a > b
	end)
	listFrame.CanvasSize = UDim2.new(0, 0, 0, #ids * 46)

	for _, mythlingId in ids do
		local record = snapshot.Mythlings[mythlingId]
		local species = MythlingConfig.Species[record.SpeciesId]
		if species == nil then
			continue
		end
		local colour = RarityConfig.Colours[record.Rarity]

		local labelText = `{record.Nickname or species.DisplayName}  |  {record.Rarity} {record.Stage}`
		if record.Shiny then
			labelText ..= "  |  Shiny!"
		end

		local isSelected = table.find(selected, mythlingId) ~= nil
		local entry = UIKit.button(labelText, if isSelected then UIKit.Palette.Accent else UIKit.Palette.PanelLight, {
			Size = UDim2.new(1, -8, 0, 40),
			TextColor3 = if isSelected
				then Color3.fromRGB(20, 24, 28)
				else Color3.fromRGB(colour.R, colour.G, colour.B),
			TextSize = 13,
		})
		entry.Parent = listFrame

		entry.Activated:Connect(function()
			local foundIndex = table.find(selected, mythlingId)
			if foundIndex then
				table.remove(selected, foundIndex)
				entry.BackgroundColor3 = UIKit.Palette.PanelLight
				entry.TextColor3 = Color3.fromRGB(colour.R, colour.G, colour.B)
			elseif #selected < PlayerConfig.MaxFollowers then
				table.insert(selected, mythlingId)
				entry.BackgroundColor3 = UIKit.Palette.Accent
				entry.TextColor3 = Color3.fromRGB(20, 24, 28)
			else
				setStatus(`You can pick at most {PlayerConfig.MaxFollowers}.`, false)
			end
			refreshApplyButton()
		end)
	end
end

function CollectionController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = UIKit.create("ScreenGui", { Name = "Collection", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.4, 0, 0.66, 0),
		Position = UDim2.new(0.3, 0, 0.17, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("My Mythlings", 22, {
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBold,
	})
	header.Parent = frame

	local hint = UIKit.label("Your followers are also your arena team.", 13, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 34),
		TextColor3 = UIKit.Palette.TextDim,
	})
	hint.Parent = frame

	local closeButton = UIKit.button("X", UIKit.Palette.Negative, {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
	})
	closeButton.Parent = frame
	closeButton.Activated:Connect(function()
		screenGui.Enabled = false
	end)

	listFrame = UIKit.create("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -132),
		Position = UDim2.new(0, 8, 0, 56),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
	})
	listFrame.Parent = frame
	UIKit.create("UIListLayout", { Padding = UDim.new(0, 6) }).Parent = listFrame

	applyButton = UIKit.button("Set team (0/3)", UIKit.Palette.Positive, {
		Size = UDim2.new(0.6, 0, 0, 38),
		Position = UDim2.new(0.2, 0, 1, -70),
	})
	applyButton.Parent = frame
	applyButton.Activated:Connect(function()
		local response = NetClient.Invoke("SetActiveMythlings", selected)
		if response.Ok then
			setStatus("Your team is out and about!", true)
		else
			setStatus(response.Error or "Could not set your team.", false)
		end
	end)

	statusLabel = UIKit.label("", 13, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
	})
	statusLabel.Parent = frame

	local toggle = UIKit.toolbarButton("Mythlings", Color3.fromRGB(66, 165, 245), -68)
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

return CollectionController
