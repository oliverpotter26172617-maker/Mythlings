--!strict
-- Arena UI: queueing, the live battle HUD (HP bars, ability buttons with
-- cooldown feedback) and the end-of-match screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local BattleController = {}

local playerGui: PlayerGui
local queueGui: ScreenGui
local battleGui: ScreenGui
local statusLabel: TextLabel
local unitRows: { [string]: { bar: Frame, label: TextLabel } } = {}
local abilityButtons: { [string]: { [string]: TextButton } } = {}
local currentMatchId: string? = nil

local function setStatus(text: string)
	statusLabel.Text = text
end

local function clearBattleHud()
	for _, child in battleGui:GetChildren() do
		child:Destroy()
	end
	unitRows = {}
	abilityButtons = {}
end

local function buildUnitRow(parent: Frame, unit: { [string]: any }, order: number)
	local row = UIKit.create("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})
	row.Parent = parent

	local label = UIKit.label(unit.DisplayName, 13, {
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = row

	local barBack = UIKit.create("Frame", {
		Size = UDim2.new(0.55, 0, 0, 14),
		Position = UDim2.new(0.42, 0, 0.5, -7),
		BackgroundColor3 = Color3.fromRGB(20, 24, 28),
	})
	UIKit.rounded(4).Parent = barBack
	barBack.Parent = row

	local bar = UIKit.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = UIKit.Palette.Positive,
	})
	UIKit.rounded(4).Parent = bar
	bar.Parent = barBack
	-- The start payload carries authoritative MaxHp for exact fractions.
	bar:SetAttribute("MaxHp", unit.MaxHp)

	unitRows[unit.Id] = { bar = bar, label = label }
end

local function buildBattleHud(payload: { [string]: any })
	clearBattleHud()
	currentMatchId = payload.MatchId

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.34, 0, 0.7, 0),
		Position = UDim2.new(0.01, 0, 0.15, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
		BackgroundTransparency = 0.15,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = battleGui

	local layout = UIKit.create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	layout.Parent = frame

	local yourHeader = UIKit.label("Your team", 15, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		LayoutOrder = 1,
	})
	yourHeader.Parent = frame

	local enemyHeader = UIKit.label("Enemy team", 15, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		LayoutOrder = 50,
	})
	enemyHeader.Parent = frame

	local order = 2
	local enemyOrder = 51
	local ownUnitIds = {}
	for _, own in payload.OwnUnits do
		ownUnitIds[own.Id] = true
	end

	for _, unit in payload.Units do
		local isOwn = ownUnitIds[unit.Id] == true
		buildUnitRow(frame, unit, if isOwn then order else enemyOrder)
		if isOwn then
			order += 1
		else
			enemyOrder += 1
		end
	end

	-- Ability buttons for each of the player's units.
	local abilityFrame = UIKit.create("Frame", {
		Size = UDim2.new(0.5, 0, 0, 120),
		Position = UDim2.new(0.25, 0, 1, -130),
		BackgroundTransparency = 1,
	})
	abilityFrame.Parent = battleGui

	local abilityLayout = UIKit.create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	abilityLayout.Parent = abilityFrame

	for unitIndex, own in payload.OwnUnits do
		local unitRow = UIKit.create("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = unitIndex,
		})
		unitRow.Parent = abilityFrame

		local rowLayout = UIKit.create("UIListLayout", {
			Padding = UDim.new(0, 4),
			FillDirection = Enum.FillDirection.Horizontal,
		})
		rowLayout.Parent = unitRow

		abilityButtons[own.Id] = {}
		for _, abilityId in own.Abilities do
			if abilityId == "Strike" then
				continue -- the basic attack fires automatically
			end
			local ability = AbilityConfig.Abilities[abilityId]
			if ability == nil then
				-- Unknown ability id from the server: skip its button rather
				-- than erroring the whole battle HUD.
				continue
			end
			local button = UIKit.button(ability.DisplayName, UIKit.Palette.Accent, {
				Size = UDim2.new(0, 130, 1, 0),
				TextSize = 13,
			})
			button.Parent = unitRow
			abilityButtons[own.Id][abilityId] = button

			button.Activated:Connect(function()
				local response = NetClient.Invoke("CastAbility", own.Id, abilityId)
				if response.Ok then
					button.BackgroundColor3 = UIKit.Palette.PanelLight
					task.delay(ability.CooldownSeconds, function()
						if button.Parent then
							button.BackgroundColor3 = UIKit.Palette.Accent
						end
					end)
				end
			end)
		end
	end
end

local function applyEvents(payload: { [string]: any })
	if payload.MatchId ~= currentMatchId then
		return
	end
	for _, event in payload.Events do
		if event.Type == "Cast" and event.Target ~= nil then
			local row = unitRows[event.Target]
			if row then
				local fraction = 0
				if event.TargetHp ~= nil then
					-- MaxHp arrives in the start payload; track via bar size
					-- relative to reported HP by storing it as an attribute.
					local maxHp = row.bar:GetAttribute("MaxHp")
					if maxHp == nil then
						maxHp = event.TargetHp + (event.Damage or 0)
						row.bar:SetAttribute("MaxHp", maxHp)
					end
					fraction = math.clamp(event.TargetHp / math.max(1, maxHp), 0, 1)
				end
				row.bar.Size = UDim2.new(fraction, 0, 1, 0)
				if event.Killed then
					row.label.TextColor3 = UIKit.Palette.Negative
				end
			end
		end
	end
end

local function showEndScreen(payload: { [string]: any })
	if payload.QueueTimeout then
		setStatus("No opponent found. Try again soon!")
		return
	end
	if payload.MatchId ~= currentMatchId then
		return
	end
	currentMatchId = nil
	clearBattleHud()

	local won = payload.Winner == payload.YourTeam
	local text
	if payload.Winner == 0 then
		text = "A draw!"
	elseif won then
		text = "Victory!"
	else
		text = "Defeat. Every battle still pays out."
	end

	local frame = UIKit.create("Frame", {
		Size = UDim2.new(0.3, 0, 0.2, 0),
		Position = UDim2.new(0.35, 0, 0.35, 0),
		BackgroundColor3 = UIKit.Palette.Panel,
	})
	UIKit.rounded(12).Parent = frame
	frame.Parent = battleGui

	local label = UIKit.label(text, 24, {
		Size = UDim2.new(1, 0, 0.6, 0),
		Font = Enum.Font.GothamBold,
		TextColor3 = if won then UIKit.Palette.Positive else UIKit.Palette.Text,
	})
	label.Parent = frame

	local closeButton = UIKit.button("Continue", UIKit.Palette.Accent, {
		Size = UDim2.new(0.5, 0, 0, 34),
		Position = UDim2.new(0.25, 0, 0.65, 0),
	})
	closeButton.Parent = frame
	closeButton.Activated:Connect(function()
		frame:Destroy()
	end)
end

function BattleController:OnStart()
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	queueGui = UIKit.create("ScreenGui", { Name = "ArenaQueue", ResetOnSpawn = false })
	queueGui.Parent = playerGui

	battleGui = UIKit.create("ScreenGui", { Name = "BattleHud", ResetOnSpawn = false })
	battleGui.Parent = playerGui

	local rankedButton = UIKit.button("Ranked Battle", UIKit.Palette.Negative, {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(1, -122, 0.5, -20),
	})
	rankedButton.Parent = queueGui

	local casualButton = UIKit.button("Casual Battle", UIKit.Palette.PanelLight, {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(1, -122, 0.5, 28),
		TextColor3 = UIKit.Palette.Text,
	})
	casualButton.Parent = queueGui

	local raidButton = UIKit.button("Boss Raid", Color3.fromRGB(171, 71, 188), {
		Size = UDim2.new(0, 110, 0, 40),
		Position = UDim2.new(1, -122, 0.5, 76),
	})
	raidButton.Parent = queueGui

	statusLabel = UIKit.label("", 13, {
		Size = UDim2.new(0, 220, 0, 18),
		Position = UDim2.new(1, -232, 0.5, 122),
	})
	statusLabel.Parent = queueGui

	local function queue(mode: string)
		local response = NetClient.Invoke("JoinQueue", mode)
		if response.Ok then
			setStatus(`Searching for a {mode} opponent...`)
		else
			setStatus(response.Error or "Could not join the queue.")
		end
	end

	rankedButton.Activated:Connect(function()
		queue("Ranked")
	end)
	casualButton.Activated:Connect(function()
		queue("Casual")
	end)
	raidButton.Activated:Connect(function()
		local response = NetClient.Invoke("JoinRaid")
		if response.Ok then
			setStatus(`Raid lobby: facing {response.Data.Boss}...`)
		else
			setStatus(response.Error or "Could not join the raid.")
		end
	end)

	NetClient.On("RaidChest", function(payload)
		local parts = {}
		for _, drop in payload.Drops do
			if drop.Type == "Gems" or drop.Type == "Coins" then
				table.insert(parts, `{drop.Count} {drop.Type}`)
			else
				table.insert(parts, `{drop.Id} x{drop.Count}`)
			end
		end
		setStatus("Raid chest: " .. table.concat(parts, ", "))
	end)

	NetClient.On("BattleStart", function(payload)
		setStatus("")
		buildBattleHud(payload)
	end)
	NetClient.On("BattleEvents", applyEvents)
	NetClient.On("BattleEnd", showEndScreen)
end

return BattleController
