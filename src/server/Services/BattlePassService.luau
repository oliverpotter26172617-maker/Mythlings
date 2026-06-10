--!strict
-- Seasonal Battle Pass: season rollover on join, XP from battles, claims.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattlePassConfig = require(ReplicatedStorage.Shared.Config.BattlePassConfig)
local BattlePassLogic = require(ReplicatedStorage.Shared.Logic.BattlePassLogic)
local SeasonLogic = require(ReplicatedStorage.Shared.Logic.SeasonLogic)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local Grants = require(script.Parent.Parent.Lib.Grants)
local Net = require(script.Parent.Parent.Lib.Net)

local BattlePassService = {}

local DataService

-- Adds pass XP, handling season rollover first.
function BattlePassService:AddXp(player: Player, amount: number)
	local data = DataService:GetData(player)
	if data == nil or amount <= 0 then
		return
	end
	BattlePassLogic.ensureSeason(data, BattlePassLogic.seasonIndex(os.time()))
	BattlePassLogic.addXp(data, amount)
end

-- Pass XP for a battle outcome; called by RewardsService so arena matches
-- and raids both feed the pass from one place.
function BattlePassService:AddBattleXp(player: Player, mode: string, outcome: string)
	local xp
	if mode == "Ranked" then
		xp = if outcome == "Win" then BattlePassConfig.XpRewards.RankedWin else BattlePassConfig.XpRewards.RankedLoss
	elseif mode == "Casual" then
		xp = if outcome == "Win" then BattlePassConfig.XpRewards.CasualWin else BattlePassConfig.XpRewards.CasualLoss
	else
		xp = if outcome == "Win" then BattlePassConfig.XpRewards.RaidClear else BattlePassConfig.XpRewards.RaidFail
	end
	BattlePassService:AddXp(player, xp)
end

function BattlePassService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction(
		"ClaimBattlePassTier",
		{ Guard.integer(1, BattlePassConfig.TierCount), Guard.oneOf({ "Free", "Premium" }) },
		function(player, tier, track)
			local data = DataService:GetData(player)
			if data == nil then
				Net.Refuse("Your data is still loading. Please try again shortly.")
			end
			BattlePassLogic.ensureSeason(data, BattlePassLogic.seasonIndex(os.time()))

			local check = BattlePassLogic.validateClaim(data, tier, track)
			if not check.Ok then
				Net.Refuse(check.Error :: string)
			end

			BattlePassLogic.markClaimed(data, tier, track)
			local granted = Grants.grant(DataService, player, data, check.Reward :: any, `BattlePass:T{tier}:{track}`)
			DataService:Sync(player)
			return { Tier = tier, Track = track, Granted = granted }
		end
	)
end

function BattlePassService:OnStart()
	DataService.ProfileLoaded:Connect(function(player)
		local data = DataService:GetData(player)
		if data then
			local season = BattlePassLogic.seasonIndex(os.time())

			-- Seasonal trophy rollover with placement rewards (3.10).
			local rollover = SeasonLogic.applyRollover(data, season)
			if rollover ~= nil and rollover.PlacementGems > 0 then
				DataService:MutateCurrency(
					player,
					"Gems",
					rollover.PlacementGems,
					`SeasonPlacement:{rollover.Placement}`
				)
				Net.FireClient("SeasonRollover", player, rollover)
			end

			if BattlePassLogic.ensureSeason(data, season) or rollover ~= nil then
				DataService:Sync(player)
			end
		end
	end)
end

return BattlePassService
