--!strict
-- Arena matchmaking and live match hosting. The simulation is pure
-- (BattleSim); this service queues players, pairs them under the trophy
-- bracket and Power-gap rules, hosts the real-time stepping, relays
-- events and teleports players to instanced arena platforms.
--
-- Rewards are granted by RewardsService (Module 3.3) via the MatchEnded
-- signal, keeping the payout table in one place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GoodSignal = require(ReplicatedStorage.Packages.GoodSignal)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local BattleSim = require(ReplicatedStorage.Shared.Logic.BattleSim)
local MatchmakingLogic = require(ReplicatedStorage.Shared.Logic.MatchmakingLogic)
local TeamLogic = require(ReplicatedStorage.Shared.Logic.TeamLogic)
local Analytics = require(script.Parent.Parent.Lib.Analytics)
local Net = require(script.Parent.Parent.Lib.Net)

local BattleService = {}

-- Fired when a match finishes: (matchRecord). RewardsService listens.
BattleService.MatchEnded = GoodSignal.new()

local DataService

type QueueRecord = {
	Player: Player,
	Mode: string,
	Entry: MatchmakingLogic.QueueEntry,
}

type Match = {
	Id: string,
	Mode: string,
	Players: { Player },
	Sim: any,
	UnitOwners: { [string]: Player },
	EventCursor: number,
	Arena: Model?,
	ArenaSlot: number,
	ReturnCFrames: { [Player]: CFrame },
	Powers: { [Player]: number },
	TeamMythlings: { [Player]: { string } },
}

local queues: { [string]: { [Player]: QueueRecord } } = { Ranked = {}, Casual = {} }
local matchesByPlayer: { [Player]: Match } = {}
local activeMatches: { Match } = {}
local arenaSlotsUsed: { [number]: boolean } = {}
local nextMatchId = 1

local function leaveAllQueues(player: Player)
	for _, queue in queues do
		queue[player] = nil
	end
end

local function freeArenaSlot(match: Match)
	if match.Arena then
		match.Arena:Destroy()
		match.Arena = nil
	end
	arenaSlotsUsed[match.ArenaSlot] = nil
end

local function buildArena(slot: number): (Model, CFrame, CFrame)
	local origin = Vector3.new(
		(slot - 1) % 4 * ArenaConfig.ArenaSpacing,
		ArenaConfig.ArenaHeight,
		math.floor((slot - 1) / 4) * ArenaConfig.ArenaSpacing
	)

	local model = Instance.new("Model")
	model.Name = `Arena_{slot}`

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(64, 2, 64)
	floor.Position = origin
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(60, 66, 78)
	floor.Parent = model

	local padA = origin + Vector3.new(-24, 4, 0)
	local padB = origin + Vector3.new(24, 4, 0)
	model.Parent = workspace
	return model, CFrame.lookAt(padA, padB), CFrame.lookAt(padB, padA)
end

local function teleportIntoArena(match: Match)
	local slotCFrames = { nil :: CFrame?, nil :: CFrame? }
	local arena, cfA, cfB = buildArena(match.ArenaSlot)
	match.Arena = arena
	slotCFrames[1] = cfA
	slotCFrames[2] = cfB

	for index, player in match.Players do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			match.ReturnCFrames[player] = rootPart.CFrame
			rootPart.CFrame = slotCFrames[index] :: CFrame
			rootPart.Anchored = true
		end
	end
end

local function returnFromArena(match: Match)
	for _, player in match.Players do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			rootPart.Anchored = false
			local returnTo = match.ReturnCFrames[player]
			if returnTo then
				rootPart.CFrame = returnTo
			end
		end
	end
end

local function endMatch(match: Match, winnerTeam: number, forfeitedBy: Player?)
	local index = table.find(activeMatches, match)
	if index == nil then
		return
	end
	table.remove(activeMatches, index)

	local result = match.Sim:getResult()
	local duration = if result then result.Duration else match.Sim:getTime()

	for teamIndex, player in match.Players do
		matchesByPlayer[player] = nil
		if player.Parent ~= nil then
			-- Match-length telemetry for pacing dashboards.
			Analytics.custom(player, `BattleDuration_{match.Mode}`, math.floor(duration))
			Net.FireClient("BattleEnd", player, {
				MatchId = match.Id,
				Winner = winnerTeam,
				YourTeam = teamIndex,
				Duration = duration,
				Forfeit = forfeitedBy ~= nil,
			})
		end
	end

	returnFromArena(match)
	freeArenaSlot(match)

	BattleService.MatchEnded:Fire({
		Mode = match.Mode,
		Players = match.Players,
		Winner = winnerTeam,
		Duration = duration,
		Powers = match.Powers,
		TeamMythlings = match.TeamMythlings,
		ForfeitedBy = forfeitedBy,
	})
end

local function startMatch(mode: string, recordA: QueueRecord, recordB: QueueRecord)
	local playerA, playerB = recordA.Player, recordB.Player
	local dataA = DataService:GetData(playerA)
	local dataB = DataService:GetData(playerB)
	if dataA == nil or dataB == nil then
		return
	end

	local buildA = TeamLogic.buildTeam(dataA, playerA.UserId)
	local buildB = TeamLogic.buildTeam(dataB, playerB.UserId)
	if not (buildA.Ok and buildB.Ok) then
		return
	end

	local slot
	for candidate = 1, ArenaConfig.MaxConcurrentArenas do
		if not arenaSlotsUsed[candidate] then
			slot = candidate
			break
		end
	end
	if slot == nil then
		return -- all arenas busy; players stay queued
	end
	arenaSlotsUsed[slot] = true

	local serverRandom = Random.new()
	local sim = BattleSim.new(buildA.Units :: any, buildB.Units :: any, function()
		return serverRandom:NextNumber()
	end)

	local match: Match = {
		Id = `Match_{nextMatchId}`,
		Mode = mode,
		Players = { playerA, playerB },
		Sim = sim,
		UnitOwners = {},
		EventCursor = 0,
		Arena = nil,
		ArenaSlot = slot,
		ReturnCFrames = {},
		Powers = { [playerA] = buildA.Power :: number, [playerB] = buildB.Power :: number },
		TeamMythlings = { [playerA] = {}, [playerB] = {} },
	}
	nextMatchId += 1

	for _, unit in buildA.Units :: any do
		match.UnitOwners[unit.Id] = playerA
		table.insert(match.TeamMythlings[playerA], unit.MythlingId)
	end
	for _, unit in buildB.Units :: any do
		match.UnitOwners[unit.Id] = playerB
		table.insert(match.TeamMythlings[playerB], unit.MythlingId)
	end

	queues[mode][playerA] = nil
	queues[mode][playerB] = nil
	matchesByPlayer[playerA] = match
	matchesByPlayer[playerB] = match
	table.insert(activeMatches, match)

	teleportIntoArena(match)

	local publicUnits = sim:getUnitsPublicState()
	for teamIndex, player in match.Players do
		local ownUnits = {}
		for _, unit in (if teamIndex == 1 then buildA.Units else buildB.Units) :: any do
			table.insert(ownUnits, { Id = unit.Id, Abilities = unit.Abilities, DisplayName = unit.DisplayName })
		end
		Net.FireClient("BattleStart", player, {
			MatchId = match.Id,
			Mode = mode,
			YourTeam = teamIndex,
			Units = publicUnits,
			OwnUnits = ownUnits,
		})
	end
end

local function scanQueues()
	for mode, queue in queues do
		local entries: { MatchmakingLogic.QueueEntry } = {}
		local byUserId: { [number]: QueueRecord } = {}
		local now = os.clock()
		for player, record in queue do
			if player.Parent == nil then
				queue[player] = nil
				continue
			end
			if now - record.Entry.QueuedAt > ArenaConfig.QueueTimeoutSeconds then
				queue[player] = nil
				Net.FireClient("BattleEnd", player, { QueueTimeout = true })
				continue
			end
			table.insert(entries, record.Entry)
			byUserId[record.Entry.UserId] = record
		end

		local matchedPairs = MatchmakingLogic.findPairs(entries)
		for _, matchPair in matchedPairs do
			local recordA = byUserId[matchPair[1].UserId]
			local recordB = byUserId[matchPair[2].UserId]
			if recordA and recordB then
				startMatch(mode, recordA, recordB)
			end
		end
	end
end

function BattleService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction("JoinQueue", { Guard.oneOf({ "Ranked", "Casual" }) }, function(player, mode)
		local data = DataService:GetData(player)
		if data == nil then
			Net.Refuse("Your data is still loading. Please try again shortly.")
		end
		if matchesByPlayer[player] ~= nil then
			Net.Refuse("You are already in a battle.")
		end
		leaveAllQueues(player)

		local build = TeamLogic.buildTeam(data, player.UserId)
		if not build.Ok then
			Net.Refuse(build.Error :: string)
		end

		queues[mode][player] = {
			Player = player,
			Mode = mode,
			Entry = {
				UserId = player.UserId,
				Trophies = data.Stats.Trophies,
				Power = build.Power :: number,
				QueuedAt = os.clock(),
			},
		}
		return { Queued = true, Mode = mode, Power = build.Power }
	end)

	Net.HandleFunction("LeaveQueue", {}, function(player)
		leaveAllQueues(player)
		return { Queued = false }
	end)

	Net.HandleFunction("CastAbility", { Guard.string(48), Guard.string(32) }, function(player, unitId, abilityId)
		local match: any = matchesByPlayer[player]
		if match == nil then
			-- Raid units cast through the same remote.
			local RaidService = require(script.Parent.RaidService) :: any
			match = RaidService:GetRaidFor(player)
		end
		if match == nil then
			Net.Refuse("You are not in a battle.")
		end
		if match.UnitOwners[unitId] ~= player then
			Net.Refuse("That is not your Mythling.")
		end
		local ok, reason = match.Sim:queueCast(unitId, abilityId)
		if not ok then
			Net.Refuse(reason or "Cannot cast that right now.")
		end
		return { Cast = true }
	end)
end

function BattleService:OnStart()
	task.spawn(function()
		while true do
			task.wait(ArenaConfig.ScanIntervalSeconds)
			scanQueues()
		end
	end)

	-- Real-time stepping and event relay for all live matches.
	local broadcastAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		broadcastAccumulator += dt
		local shouldBroadcast = broadcastAccumulator >= 0.25
		if shouldBroadcast then
			broadcastAccumulator = 0
		end

		for _, match in table.clone(activeMatches) do
			match.Sim:step(dt)

			if shouldBroadcast or match.Sim:isFinished() then
				local events = match.Sim:getEvents()
				if #events > match.EventCursor then
					local batch = {}
					for index = match.EventCursor + 1, #events do
						table.insert(batch, events[index])
					end
					match.EventCursor = #events
					for _, player in match.Players do
						if player.Parent ~= nil then
							Net.FireClient("BattleEvents", player, { MatchId = match.Id, Events = batch })
						end
					end
				end
			end

			if match.Sim:isFinished() then
				local result = match.Sim:getResult()
				endMatch(match, result.Winner, nil)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveAllQueues(player)
		local match = matchesByPlayer[player]
		if match then
			-- Leaving a live match forfeits it.
			local leaverTeam = table.find(match.Players, player)
			local winnerTeam = if leaverTeam == 1 then 2 else 1
			endMatch(match, winnerTeam, player)
		end
	end)
end

return BattleService
