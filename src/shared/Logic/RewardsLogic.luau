--!strict
-- Battle payout computation. Pure Luau; implements Section 3.6 exactly.

local RewardsConfig = require(script.Parent.Parent.Config.RewardsConfig)

local RewardsLogic = {}

export type Outcome = "Win" | "Loss" | "Draw"

export type RewardInput = {
	Mode: "Ranked" | "Casual" | "Raid",
	Outcome: Outcome,
	BracketCoinMultiplier: number,
	CurrentTrophies: number,
	PriorWinStreak: number,
	PriorLossStreak: number,
	Rng: () -> number,
}

export type RewardResult = {
	Coins: number,
	TrophyDelta: number,
	XpPerMythling: number,
	BattleTokens: number,
	NewWinStreak: number,
	NewLossStreak: number,
	StreakBonusFraction: number,
	LossProtected: boolean,
}

local function rollBetween(min: number, max: number, rng: () -> number): number
	if max <= min then
		return min
	end
	return min + math.floor(rng() * (max - min + 1))
end

function RewardsLogic.compute(input: RewardInput): RewardResult
	local modeTable = (RewardsConfig :: any)[input.Mode]
	assert(modeTable ~= nil, `unknown reward mode {input.Mode}`)

	local isWin = input.Outcome == "Win"
	local isDraw = input.Outcome == "Draw"
	local rowName: string
	if input.Mode == "Raid" then
		rowName = if isWin then "Clear" else "Fail"
	else
		rowName = if isWin then "Win" else "Loss"
	end
	local row = modeTable[rowName]

	-- Coins
	local coins = row.BaseCoins
	local streakBonus = 0
	if input.Mode == "Ranked" then
		if isWin then
			coins = math.floor(row.BaseCoins * input.BracketCoinMultiplier)
			streakBonus = math.min(
				RewardsConfig.Ranked.StreakBonusCap,
				RewardsConfig.Ranked.StreakBonusPerWin * input.PriorWinStreak
			)
			coins = math.floor(coins * (1 + streakBonus))
		end
	end

	-- Trophies
	local trophyDelta = 0
	local lossProtected = false
	if input.Mode == "Ranked" and not isDraw then
		if isWin then
			trophyDelta = rollBetween(row.TrophiesMin, row.TrophiesMax, input.Rng)
		else
			if input.PriorLossStreak >= RewardsConfig.Ranked.LossProtectionThreshold then
				lossProtected = true
				trophyDelta = 0
			else
				trophyDelta = -rollBetween(row.TrophiesMin, row.TrophiesMax, input.Rng)
				-- Floor of 0 trophies.
				if input.CurrentTrophies + trophyDelta < 0 then
					trophyDelta = -input.CurrentTrophies
				end
			end
		end
	end

	-- XP
	local xp = math.floor(RewardsConfig.BaseBattleXp * row.XpFraction)

	-- Streaks: draws freeze both.
	local newWinStreak = input.PriorWinStreak
	local newLossStreak = input.PriorLossStreak
	if not isDraw then
		if isWin then
			newWinStreak += 1
			newLossStreak = 0
		else
			newLossStreak += 1
			newWinStreak = 0
		end
	end

	return {
		Coins = coins,
		TrophyDelta = trophyDelta,
		XpPerMythling = xp,
		BattleTokens = row.BattleTokens,
		NewWinStreak = newWinStreak,
		NewLossStreak = newLossStreak,
		StreakBonusFraction = streakBonus,
		LossProtected = lossProtected,
	}
end

return RewardsLogic
