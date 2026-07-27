--!strict
-- Breeding UI: pick two Adult+ Mythlings, see cooldowns, breed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BreedingConfig = require(ReplicatedStorage.Shared.Config.BreedingConfig)
local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local ProfileController = require(script.Parent.ProfileController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local BreedingController = {}

local screenGui: ScreenGui
local listFrame: ScrollingFrame
local statusLabel: TextLabel
local breedButton: TextButton
local selected: { string } = {}

local function setStatus(text: string, positive: boolean)
	statusLabel.Text = text
	statusLabel.TextColor3 = if positive then UIKit.Palette.Positive else UIKit.Palette.Negative
end

local function refreshBreedButton()
	breedButton.Text = if #selected == 2 then "Breed!" else `Pick 2 ({#selected} chosen)`
end

local function rebuild(snapshot: { [string]: any })
	for _, child in listFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Preserve any in-progress selection whose Mythling is still breedable,
	-- so a background profile sync (idle income, a hatch elsewhere) cannot
	-- wipe the player's picks mid-selection.
	local kept: { string } = {}
	for _, id in selected do
		local record = snapshot.Mythlings[id]
		if record ~= nil and (record.Stage == "Adult" or record.Stage == "Alpha") then
			table.insert(kept, id)
		end
	end
	selected = kept
	refreshBreedButton()

	local ids = {}
	for mythlingId, record in snapshot.Mythlings do
		if record.Stage == "Adult" or record.Stage == "Alpha" then
			table.insert(ids, mythlingId)
		end
	end
	table.sort(ids)
	listFrame.CanvasSize = UDim2.new(0, 0, 0, #ids * 46)

	local now = Workspace:GetServerTimeNow()
	for _, mythlingId in ids do
		local record = snapshot.Mythlings[mythlingId]
		local species = MythlingConfig.Species[record.SpeciesId]
		if species == nil then
			-- A species retired from config while still owned: skip it rather
			-- than blanking the whole panel.
			continue
		end
		local resting = record.BreedCooldownUntil > now

		local labelText = species.DisplayName
		if record.Shiny then
			labelText ..= " (Shiny)"
		end
		if resting then
			local minutes = math.ceil((record.BreedCooldownUntil - now) / 60)
			labelText ..= ` - resting {minutes} min`
		end

		local entry = UIKit.button(labelText, UIKit.Palette.PanelLight, {
			Size = UDim2.new(1, -8, 0, 40),
			TextColor3 = if resting then UIKit.Palette.TextDim else UIKit.Palette.Text,
			TextSize = 14,
		})
		entry.Parent = listFrame
		if table.find(selected, mythlingId) then
			entry.BackgroundColor3 = UIKit.Palette.Accent
		end

		entry.Activated:Connect(function()
			if resting then
				local response = NetClient.Invoke("SkipBreedCooldown", mythlingId)
				if response.Ok then
					setStatus("Cooldown skipped!", true)
				else
					setStatus(response.Error or "Could not skip.", false)
				end
				return
			end
			local foundIndex = table.find(selected, mythlingId)
			if foundIndex then
				table.remove(selected, foundIndex)
				entry.BackgroundColor3 = UIKit.Palette.PanelLight
			elseif #selected < 2 then
				table.insert(selected, mythlingId)
				entry.BackgroundColor3 = UIKit.Palette.Accent
			end
			refreshBreedButton()
		end)
	end
end

function BreedingController:OnStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screenGui = UIKit.create("ScreenGui", { Name = "Breeding", ResetOnSpawn = false, Enabled = false })
	screenGui.Parent = playerGui

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.4, 0, 0.6, 0),
		Position = UDim2.new(0.3, 0, 0.2, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = screenGui

	local header = UIKit.label("Breeding Den", 22, {
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBold,
	})
	header.Parent = frame

	local hint = UIKit.label(`Adult Mythlings only. Rest time: {BreedingConfig.CooldownHours} hours.`, 13, {
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
		Size = UDim2.new(1, -16, 1, -130),
		Position = UDim2.new(0, 8, 0, 56),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
	})
	listFrame.Parent = frame
	local listLayout = UIKit.create("UIListLayout", { Padding = UDim.new(0, 6) })
	listLayout.Parent = listFrame

	breedButton = UIKit.button("Pick 2 (0 chosen)", UIKit.Palette.Positive, {
		Size = UDim2.new(0.6, 0, 0, 38),
		Position = UDim2.new(0.2, 0, 1, -68),
	})
	breedButton.Parent = frame
	UIKit.onActivated(breedButton, function()
		if #selected ~= 2 then
			return
		end
		local response = NetClient.Invoke("BreedMythlings", selected[1], selected[2])
		if response.Ok then
			setStatus("An egg appeared! Check your Hatchery.", true)
		else
			setStatus(response.Error or "Breeding failed.", false)
		end
	end)

	statusLabel = UIKit.label("", 14, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
	})
	statusLabel.Parent = frame

	local toggleGui = UIKit.create("ScreenGui", { Name = "BreedingToggle", ResetOnSpawn = false })
	toggleGui.Parent = playerGui
	local toggle = UIKit.button("Breeding", Color3.fromRGB(171, 71, 188), {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(0, 12, 0.5, 76),
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

	-- Only rebuild while the panel is open, so a background sync cannot churn
	-- the list (or disturb the selection) when the player is not looking.
	ProfileController.Changed:Connect(function(snapshot)
		if screenGui.Enabled then
			rebuild(snapshot)
		end
	end)
end

return BreedingController
