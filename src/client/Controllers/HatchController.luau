--!strict
-- Egg inventory and hatching UI: incubation slots, live countdowns,
-- instant finish with the Gem cost shown, and the hatch reveal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local HatchController = {}

local screenGui: ScreenGui
local listFrame: ScrollingFrame
local revealFrame: Frame
local statusLabel: TextLabel
local rows: { [string]: { frame: Frame, timer: TextLabel, action: TextButton } } = {}

-- Server time approximation: ProfileSync carries server timestamps, and
-- Workspace:GetServerTimeNow() keeps countdowns honest on the client.
local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function setStatus(text: string, positive: boolean)
	statusLabel.Text = text
	statusLabel.TextColor3 = if positive then UIKit.Palette.Positive else UIKit.Palette.Negative
end

local function showReveal(result: { [string]: any })
	revealFrame:ClearAllChildren()
	revealFrame.Visible = true

	local layout = UIKit.create("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	layout.Parent = revealFrame

	local colour = RarityConfig.Colours[result.Rarity]
	local rarityLabel = UIKit.label(result.Rarity .. "!", 26, {
		Size = UDim2.new(1, 0, 0, 34),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(colour.R, colour.G, colour.B),
	})
	rarityLabel.Parent = revealFrame

	local nameLabel = UIKit.label(`{result.DisplayName} ({result.Element})`, 20, {
		Size = UDim2.new(1, 0, 0, 26),
	})
	nameLabel.Parent = revealFrame

	if result.PityTriggered then
		local pityLabel = UIKit.label("Lucky guarantee!", 14, {
			Size = UDim2.new(1, 0, 0, 18),
			TextColor3 = UIKit.Palette.Accent,
		})
		pityLabel.Parent = revealFrame
	end

	local closeButton = UIKit.button("Brilliant!", UIKit.Palette.Accent, {
		Size = UDim2.new(0, 140, 0, 36),
	})
	closeButton.Parent = revealFrame
	closeButton.Activated:Connect(function()
		revealFrame.Visible = false
	end)
end

local function handleResponse(response: NetClient.Response)
	if response.Ok then
		local data = response.Data
		if data and data.Rarity then
			showReveal(data)
		end
	else
		setStatus(response.Error or "Something went wrong.", false)
	end
end

local function rebuildList(snapshot: { [string]: any })
	for _, row in rows do
		row.frame:Destroy()
	end
	rows = {}

	local eggIds = {}
	for eggId in snapshot.Eggs do
		table.insert(eggIds, eggId)
	end
	table.sort(eggIds)
	listFrame.CanvasSize = UDim2.new(0, 0, 0, #eggIds * 52)

	for _, eggId in eggIds do
		local egg = snapshot.Eggs[eggId]
		local tier = EggConfig.Tiers[egg.Tier]

		local row = UIKit.create("Frame", {
			Size = UDim2.new(1, -8, 0, 46),
			BackgroundColor3 = UIKit.Palette.PanelLight,
		})
		UIKit.rounded():Clone().Parent = row
		row.Parent = listFrame

		local name = UIKit.label(tier and tier.DisplayName or egg.Tier, 15, {
			Size = UDim2.new(0.4, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 0),
		})
		name.Parent = row

		local timer = UIKit.label("", 13, {
			Size = UDim2.new(0.25, 0, 1, 0),
			Position = UDim2.new(0.42, 0, 0, 0),
			TextColor3 = UIKit.Palette.TextDim,
		})
		timer.Parent = row

		local action = UIKit.button("", UIKit.Palette.Accent, {
			Size = UDim2.new(0.28, 0, 0, 32),
			Position = UDim2.new(0.7, 0, 0, 7),
			TextSize = 13,
		})
		action.Parent = row

		UIKit.onActivated(action, function()
			local current = (ProfileController:Get() :: any).Eggs[eggId]
			if current == nil then
				return
			end
			if current.HatchesAt == nil then
				handleResponse(NetClient.Invoke("StartIncubation", eggId))
			elseif serverNow() >= current.HatchesAt then
				handleResponse(NetClient.Invoke("ClaimHatch", eggId))
			else
				handleResponse(NetClient.Invoke("InstantFinishHatch", eggId))
			end
		end)

		rows[eggId] = { frame = row, timer = timer, action = action }
	end
end

local function refreshTimers()
	local snapshot = ProfileController:Get()
	if snapshot == nil then
		return
	end
	for eggId, row in rows do
		local egg = (snapshot :: any).Eggs[eggId]
		if egg == nil then
			continue
		end
		if egg.HatchesAt == nil then
			row.timer.Text = "Stored"
			row.action.Text = "Incubate"
		else
			local remaining = egg.HatchesAt - serverNow()
			if remaining <= 0 then
				row.timer.Text = "Ready!"
				row.action.Text = "Hatch!"
			else
				local minutes = math.floor(remaining / 60)
				local seconds = math.floor(remaining % 60)
				row.timer.Text = string.format("%d:%02d", minutes, seconds)
				local cost = math.max(1, math.ceil((remaining / 60) * EggConfig.InstantHatchGemsPerMinute))
				row.action.Text = `Finish ({cost} Gems)`
			end
		end
	end
end

function HatchController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screenGui = UIKit.create("ScreenGui", {
		Name = "Hatchery",
		ResetOnSpawn = false,
		Enabled = false,
	})
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.4, 0, 0.6, 0),
		Position = UDim2.new(0.3, 0, 0.2, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("Hatchery", 22, {
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
	local listLayout = UIKit.create("UIListLayout", { Padding = UDim.new(0, 6) })
	listLayout.Parent = listFrame

	statusLabel = UIKit.label("", 14, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
	})
	statusLabel.Parent = frame

	revealFrame = UIKit.create("Frame", {
		Size = UDim2.new(0.3, 0, 0.35, 0),
		Position = UDim2.new(0.35, 0, 0.3, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
		Visible = false,
		ZIndex = 5,
	})
	UIKit.rounded(12).Parent = revealFrame
	revealFrame.Parent = screenGui

	local toggleGui = UIKit.create("ScreenGui", { Name = "HatcheryToggle", ResetOnSpawn = false })
	toggleGui.Parent = playerGui
	local toggle = UIKit.button("Hatchery", UIKit.Palette.Positive, {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(0, 12, 0.5, 28),
	})
	toggle.Parent = toggleGui
	toggle.Activated:Connect(function()
		if not screenGui.Enabled then
			local snapshot = ProfileController:Get()
			if snapshot then
				rebuildList(snapshot)
			end
		end
		screenGui.Enabled = not screenGui.Enabled
	end)

	-- Rebuild only while the panel is open; the timer loop below already
	-- refreshes countdowns on the same condition.
	ProfileController.Changed:Connect(function(snapshot)
		if screenGui.Enabled then
			rebuildList(snapshot)
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.25 then
			accumulator = 0
			if screenGui.Enabled then
				refreshTimers()
			end
		end
	end)
end

return HatchController
