--!strict
-- Applies battle payouts. Listens to BattleService.MatchEnded so the
-- Section 3.6 table (RewardsLogic) is applied in exactly one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingLogic = require(ReplicatedStorage.Shared.Logic.MatchmakingLogic)
local RewardsLogic = require(ReplicatedStorage.Shared.Logic.RewardsLogic)
local Net = require(script.Parent.Parent.Lib.Net)

local RewardsService = {}

local DataService
local GrowthService
local BattleService

local serverRandom = Random.new()

local function rng(): number
	return serverRandom:NextNumber()
end

-- Applies one player's payout for a finished encounter and pushes the
-- itemised summary. Shared by arena matches and raids.
function RewardsService:ApplyReward(
	player: Player,
	mode: "Ranked" | "Casual" | "Raid",
	outcome: "Win" | "Loss" | "Draw",
	teamMythlingIds: { string }
)
	local data = DataService:GetData(player)
	if data == nil then
		return nil
	end

	local bracket = MatchmakingLogic.bracketFor(data.Stats.Trophies)
	local result = RewardsLogic.compute({
		Mode = mode,
		Outcome = outcome,
		BracketCoinMultiplier = bracket.CoinMultiplier,
		CurrentTrophies = data.Stats.Trophies,
		PriorWinStreak = data.Stats.WinStreak,
		PriorLossStreak = data.Stats.LossStreak,
		Rng = rng,
	})

	if result.Coins > 0 then
		DataService:MutateCurrency(player, "Coins", result.Coins, `Battle:{mode}:{outcome}`)
	end
	if result.BattleTokens > 0 then
		DataService:MutateCurrency(player, "BattleTokens", result.BattleTokens, `Battle:{mode}:{outcome}`)
	end

	data.Stats.Trophies += result.TrophyDelta
	data.Stats.SeasonHighestTrophies = math.max(data.Stats.SeasonHighestTrophies, data.Stats.Trophies)
	data.Stats.WinStreak = result.NewWinStreak
	data.Stats.LossStreak = result.NewLossStreak
	if outcome == "Win" then
		data.Stats.BattlesWon += 1
	elseif outcome == "Loss" then
		data.Stats.BattlesLost += 1
	end

	for _, mythlingId in teamMythlingIds do
		GrowthService:GrantXp(player, mythlingId, result.XpPerMythling)
	end

	DataService:Sync(player)

	Net.FireClient("BattleRewards", player, {
		Mode = mode,
		Outcome = outcome,
		Coins = result.Coins,
		TrophyDelta = result.TrophyDelta,
		BattleTokens = result.BattleTokens,
		XpPerMythling = result.XpPerMythling,
		StreakBonusFraction = result.StreakBonusFraction,
		LossProtected = result.LossProtected,
	})

	return result
end

function RewardsService:OnInit()
	DataService = require(script.Parent.DataService) :: any
	GrowthService = require(script.Parent.GrowthService) :: any
	BattleService = require(script.Parent.BattleService) :: any
end

function RewardsService:OnStart()
	BattleService.MatchEnded:Connect(function(record)
		if record.Mode ~= "Ranked" and record.Mode ~= "Casual" then
			return
		end
		for teamIndex, player in record.Players do
			if player.Parent == nil then
				continue
			end
			local outcome: "Win" | "Loss" | "Draw"
			if record.Winner == 0 then
				outcome = "Draw"
			elseif record.Winner == teamIndex then
				outcome = "Win"
			else
				outcome = "Loss"
			end
			RewardsService:ApplyReward(player, record.Mode, outcome, record.TeamMythlings[player] or {})
		end
	end)
end

return RewardsService
