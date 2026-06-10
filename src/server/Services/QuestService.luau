--!strict
-- Quests, login calendar, gifting and the group membership bonus.
-- Other services report metric progress through ReportProgress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local HatchLogic = require(ReplicatedStorage.Shared.Logic.HatchLogic)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local Grants = require(script.Parent.Parent.Lib.Grants)
local Net = require(script.Parent.Parent.Lib.Net)

local QuestService = {}

local DataService
local serverRandom = Random.new()

local function rng(): number
	return serverRandom:NextNumber()
end

-- Grants the day-7 guaranteed Epic egg: a sealed outcome rolled now.
local function grantEpicEgg(data: { [string]: any })
	local speciesId = HatchLogic.pickSpecies(MythlingConfig.Species, "Epic", nil, 0.5, rng)
	local eggId = `E{data.NextEggId}`
	data.NextEggId += 1
	data.Eggs[eggId] = {
		Tier = "Gift",
		ObtainedAt = os.time(),
		HatchesAt = nil,
		HatchMinutes = QuestConfig.CalendarEggHatchMinutes,
		Outcome = {
			SpeciesId = speciesId,
			Potential = HatchLogic.rollPotential(StatConfig.PotentialMin, StatConfig.PotentialMax, rng),
			Shiny = false,
		},
	}
end

-- Public: adds quest progress for a metric. Cheap when nothing matches.
function QuestService:ReportProgress(player: Player, metric: string, amount: number)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	QuestLogic.ensureQuests(data, os.time())
	QuestLogic.report(data, metric, amount)
	DataService:Sync(player)
end

function QuestService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction(
		"ClaimQuest",
		{ Guard.oneOf({ "Daily", "Weekly" }), Guard.string(32) },
		function(player, scope, questId)
			local data = DataService:GetData(player)
			if data == nil then
				Net.Refuse("Your data is still loading. Please try again shortly.")
			end
			QuestLogic.ensureQuests(data, os.time())

			local ok, message, def = QuestLogic.validateClaim(data, scope, questId)
			if not ok then
				Net.Refuse(message :: string)
			end

			local reward = (def :: any).Reward
			local granted = Grants.grant(DataService, player, data, reward, `Quest:{questId}`)
			DataService:Sync(player)
			return { QuestId = questId, Granted = granted }
		end
	)

	Net.HandleFunction("GiftEgg", { Guard.integer(1) }, function(player, friendUserId)
		local data = DataService:GetData(player)
		if data == nil then
			Net.Refuse("Your data is still loading. Please try again shortly.")
		end
		if friendUserId == player.UserId then
			Net.Refuse("You cannot gift yourself an egg!")
		end

		local friend = Players:GetPlayerByUserId(friendUserId)
		if friend == nil then
			Net.Refuse("That friend is not in this server.")
		end
		local friendData = DataService:GetData(friend)
		if friendData == nil then
			Net.Refuse("Your friend's data is still loading.")
		end

		local isFriend = false
		local ok, result = pcall(player.IsFriendsWith, player, friendUserId)
		if ok then
			isFriend = result
		end
		if not isFriend then
			Net.Refuse("You can only gift Roblox friends.")
		end

		local allowed, message = QuestLogic.tryRecordGift(data, friendUserId, os.time())
		if not allowed then
			Net.Refuse(message :: string)
		end

		local granted = Grants.grant(
			DataService,
			friend,
			friendData,
			{ Type = "Egg", Id = QuestConfig.GiftEggTier, Count = 1 },
			`Gift:{player.UserId}`
		)
		QuestService:ReportProgress(player, "GiftsSent", 1)
		DataService:Sync(player)
		DataService:Sync(friend)
		return { GiftedTo = friend.DisplayName, Granted = granted }
	end)
end

function QuestService:OnStart()
	DataService.ProfileLoaded:Connect(function(player)
		local data = DataService:GetData(player)
		if data == nil then
			return
		end
		local now = os.time()
		QuestLogic.ensureQuests(data, now)

		-- Login calendar: auto-claim on the first join of the day.
		local dayIndex, reward = QuestLogic.claimCalendar(data, now)
		if dayIndex ~= nil and reward ~= nil then
			local granted
			if reward.Type == "EpicEgg" then
				grantEpicEgg(data)
				granted = { Type = "Egg", Id = "Guaranteed Epic", Count = 1 }
			else
				granted = Grants.grant(DataService, player, data, reward :: any, `Calendar:Day{dayIndex}`)
			end
			Net.FireClient("CalendarReward", player, { Day = dayIndex, Granted = granted })
		end

		-- Group membership bonus (free marketing, +10% Coins).
		if QuestConfig.GroupId > 0 and not data.Flags.GroupBonus then
			task.spawn(function()
				local inGroup = false
				local checkOk, checkResult = pcall(player.IsInGroup, player, QuestConfig.GroupId)
				if checkOk then
					inGroup = checkResult
				end
				if inGroup then
					data.Flags.GroupBonus = true
					DataService:Sync(player)
				end
			end)
		end

		DataService:Sync(player)
	end)
end

return QuestService
