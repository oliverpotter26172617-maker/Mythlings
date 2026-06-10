--!strict
-- Weekly boss raids: co-op lobby, shared battle instance against the
-- rotating boss, Section 3.6 raid payouts plus chest drops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)
local RaidConfig = require(ReplicatedStorage.Shared.Config.RaidConfig)
local BattleSim = require(ReplicatedStorage.Shared.Logic.BattleSim)
local RaidLogic = require(ReplicatedStorage.Shared.Logic.RaidLogic)
local TeamLogic = require(ReplicatedStorage.Shared.Logic.TeamLogic)
local Net = require(script.Parent.Parent.Lib.Net)

local RaidService = {}

local DataService
local RewardsService

local serverRandom = Random.new()

local function rng(): number
	return serverRandom:NextNumber()
end

type Raid = {
	Id: string,
	Players: { Player },
	Sim: any,
	UnitOwners: { [string]: Player },
	TeamMythlings: { [Player]: { string } },
	EventCursor: number,
}

local lobby: { [Player]: { JoinedAt: number } } = {}
local raidByPlayer: { [Player]: Raid } = {}
local activeRaids: { Raid } = {}
local nextRaidId = 1

local function grantChestDrops(player: Player, drops: { any })
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local granted = {}
	for _, drop in drops do
		if drop.Type == "Food" then
			data.Inventory.Food[drop.Id] = (data.Inventory.Food[drop.Id] or 0) + drop.Count
			table.insert(granted, { Type = "Food", Id = drop.Id, Count = drop.Count })
		elseif drop.Type == "Gems" then
			DataService:MutateCurrency(player, "Gems", drop.Count, "RaidChest")
			table.insert(granted, { Type = "Gems", Count = drop.Count })
		elseif drop.Type == "Cosmetic" then
			data.Cosmetics.OwnedMythling[drop.Id] = true
			table.insert(granted, { Type = "Cosmetic", Id = drop.Id, Count = 1 })
		elseif drop.Type == "Egg" then
			local eggCount = 0
			for _ in data.Eggs do
				eggCount += 1
			end
			if eggCount < PlayerConfig.MaxStoredEggs then
				local eggId = `E{data.NextEggId}`
				data.NextEggId += 1
				data.Eggs[eggId] = { Tier = drop.Id, ObtainedAt = os.time(), HatchesAt = nil }
				table.insert(granted, { Type = "Egg", Id = drop.Id, Count = 1 })
			else
				DataService:MutateCurrency(player, "Coins", RaidConfig.EggFallbackCoins, "RaidChestEggFallback")
				table.insert(granted, { Type = "Coins", Count = RaidConfig.EggFallbackCoins })
			end
		end
	end
	DataService:Sync(player)
	Net.FireClient("RaidChest", player, { Drops = granted })
end

local function endRaid(raid: Raid, playersWon: boolean)
	local index = table.find(activeRaids, raid)
	if index == nil then
		return
	end
	table.remove(activeRaids, index)

	for _, player in raid.Players do
		raidByPlayer[player] = nil
		if player.Parent == nil then
			continue
		end
		Net.FireClient("BattleEnd", player, {
			MatchId = raid.Id,
			Winner = if playersWon then 1 else 2,
			YourTeam = 1,
			Duration = raid.Sim:getTime(),
		})
		RewardsService:ApplyReward(
			player,
			"Raid",
			if playersWon then "Win" else "Loss",
			raid.TeamMythlings[player] or {}
		)
		if playersWon then
			local data = DataService:GetData(player)
			if data then
				data.Stats.RaidsCleared += 1
			end
			grantChestDrops(player, RaidLogic.rollChest(rng))
		end
	end
end

local function startRaid(party: { Player })
	local units = {}
	local raid: Raid = {
		Id = `Raid_{nextRaidId}`,
		Players = {},
		Sim = nil,
		UnitOwners = {},
		TeamMythlings = {},
		EventCursor = 0,
	}
	nextRaidId += 1

	for _, player in party do
		lobby[player] = nil
		local data = DataService:GetData(player)
		if data == nil then
			continue
		end
		local build = TeamLogic.buildTeam(data, player.UserId)
		if not build.Ok then
			continue
		end
		table.insert(raid.Players, player)
		raid.TeamMythlings[player] = {}
		for _, unit in build.Units :: any do
			table.insert(units, unit)
			raid.UnitOwners[unit.Id] = player
			table.insert(raid.TeamMythlings[player], unit.MythlingId)
		end
	end

	if #raid.Players == 0 then
		return
	end

	raid.Sim = BattleSim.new(units, { RaidLogic.bossUnitSpec(os.time()) }, rng)

	for _, player in raid.Players do
		raidByPlayer[player] = raid
	end
	table.insert(activeRaids, raid)

	local publicUnits = raid.Sim:getUnitsPublicState()
	for _, player in raid.Players do
		local ownUnits = {}
		for unitId, owner in raid.UnitOwners do
			if owner == player then
				for _, unit in units do
					if unit.Id == unitId then
						table.insert(
							ownUnits,
							{ Id = unit.Id, Abilities = unit.Abilities, DisplayName = unit.DisplayName }
						)
					end
				end
			end
		end
		Net.FireClient("BattleStart", player, {
			MatchId = raid.Id,
			Mode = "Raid",
			YourTeam = 1,
			Units = publicUnits,
			OwnUnits = ownUnits,
		})
	end
end

-- Allows BattleService-style casting in raids through the same remote by
-- exposing the lookup BattleService uses.
function RaidService:GetRaidFor(player: Player): Raid?
	return raidByPlayer[player]
end

function RaidService:OnInit()
	DataService = require(script.Parent.DataService) :: any
	RewardsService = require(script.Parent.RewardsService) :: any

	Net.HandleFunction("JoinRaid", {}, function(player)
		local data = DataService:GetData(player)
		if data == nil then
			Net.Refuse("Your data is still loading. Please try again shortly.")
		end
		if raidByPlayer[player] ~= nil then
			Net.Refuse("You are already in a raid.")
		end
		local build = TeamLogic.buildTeam(data, player.UserId)
		if not build.Ok then
			Net.Refuse(build.Error :: string)
		end
		lobby[player] = { JoinedAt = os.clock() }
		local boss = RaidLogic.bossFor(os.time())
		return { Queued = true, Boss = boss.DisplayName }
	end)

	Net.HandleFunction("LeaveRaid", {}, function(player)
		lobby[player] = nil
		return { Queued = false }
	end)
end

function RaidService:OnStart()
	-- Lobby launcher.
	task.spawn(function()
		while true do
			task.wait(2)
			local waiting = {}
			local oldest = math.huge
			for player, record in lobby do
				if player.Parent == nil then
					lobby[player] = nil
					continue
				end
				table.insert(waiting, player)
				oldest = math.min(oldest, record.JoinedAt)
			end
			if #waiting >= RaidConfig.MaxPartySize then
				startRaid({ waiting[1], waiting[2], waiting[3], waiting[4] })
			elseif #waiting > 0 and os.clock() - oldest >= RaidConfig.LobbyWaitSeconds then
				startRaid(waiting)
			end
		end
	end)

	-- Raid stepping and event relay.
	local broadcastAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		broadcastAccumulator += dt
		local shouldBroadcast = broadcastAccumulator >= 0.25
		if shouldBroadcast then
			broadcastAccumulator = 0
		end

		for _, raid in table.clone(activeRaids) do
			raid.Sim:step(dt)

			if shouldBroadcast or raid.Sim:isFinished() then
				local events = raid.Sim:getEvents()
				if #events > raid.EventCursor then
					local batch = {}
					for index = raid.EventCursor + 1, #events do
						table.insert(batch, events[index])
					end
					raid.EventCursor = #events
					for _, player in raid.Players do
						if player.Parent ~= nil then
							Net.FireClient("BattleEvents", player, { MatchId = raid.Id, Events = batch })
						end
					end
				end
			end

			if raid.Sim:isFinished() then
				local result = raid.Sim:getResult()
				endRaid(raid, result.Winner == 1)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lobby[player] = nil
		-- Leaving a live raid does not end it for the rest of the party;
		-- the leaver simply forfeits their rewards.
		local raid = raidByPlayer[player]
		if raid then
			raidByPlayer[player] = nil
			local index = table.find(raid.Players, player)
			if index then
				table.remove(raid.Players, index)
			end
		end
	end)
end

return RaidService
