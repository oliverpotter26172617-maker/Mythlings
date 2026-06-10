--!strict
-- The Section 3.6 win/loss reward table, locked. Losing always pays
-- something: no match is wasted time.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	Ranked = {
		Win = {
			BaseCoins = 250, -- multiplied by the bracket CoinMultiplier
			TrophiesMin = 25,
			TrophiesMax = 35,
			XpFraction = 1.0,
			BattleTokens = 3,
		},
		Loss = {
			BaseCoins = 75, -- 30% consolation of the win base
			TrophiesMin = 10, -- subtracted; trophies floor at 0
			TrophiesMax = 20,
			XpFraction = 0.4,
			BattleTokens = 1,
		},
		-- +10% Coins per consecutive win before this one, capped at +50%.
		StreakBonusPerWin = 0.1,
		StreakBonusCap = 0.5,
		-- After this many straight losses, further losses cost 0 trophies
		-- until a win resets the run.
		LossProtectionThreshold = 3,
	},

	Casual = {
		Win = { BaseCoins = 150, TrophiesMin = 0, TrophiesMax = 0, XpFraction = 1.0, BattleTokens = 2 },
		Loss = { BaseCoins = 50, TrophiesMin = 0, TrophiesMax = 0, XpFraction = 0.4, BattleTokens = 1 },
	},

	Raid = {
		Clear = { BaseCoins = 400, TrophiesMin = 0, TrophiesMax = 0, XpFraction = 1.0, BattleTokens = 5 },
		Fail = { BaseCoins = 0, TrophiesMin = 0, TrophiesMax = 0, XpFraction = 0.4, BattleTokens = 1 },
	},

	-- Full battle XP granted to each team Mythling on a win.
	BaseBattleXp = 80,

	-- Draws pay the loss consolation with no trophy or streak movement.
	DrawPaysLossRow = true,
})
