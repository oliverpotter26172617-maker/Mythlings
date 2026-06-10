--!strict
-- Matchmaking and arena tunables.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type BracketDef = {
	Name: string,
	MinTrophies: number,
	MaxTrophies: number,
	CoinMultiplier: number,
}

return TableUtil.deepFreeze({
	-- Trophy brackets, ascending and contiguous. CoinMultiplier feeds the
	-- ranked win payout (Section 3.6 table).
	Brackets = {
		{ Name = "Bronze", MinTrophies = 0, MaxTrophies = 199, CoinMultiplier = 1.0 },
		{ Name = "Silver", MinTrophies = 200, MaxTrophies = 499, CoinMultiplier = 1.25 },
		{ Name = "Gold", MinTrophies = 500, MaxTrophies = 999, CoinMultiplier = 1.5 },
		{ Name = "Platinum", MinTrophies = 1000, MaxTrophies = 1999, CoinMultiplier = 1.75 },
		{ Name = "Diamond", MinTrophies = 2000, MaxTrophies = math.huge, CoinMultiplier = 2.0 },
	} :: { BracketDef },

	-- A match only forms when the stronger team's Power is at most this
	-- multiple of the weaker team's. This is the core fairness guarantee:
	-- spending speeds you up but cannot buy stomps.
	PowerGapMax = 1.35,

	-- Matchmaker scan cadence and queue patience.
	ScanIntervalSeconds = 2,
	QueueTimeoutSeconds = 90,

	-- Arena instancing: match platforms are laid out on a grid well above
	-- the main map, ArenaSpacing studs apart.
	ArenaHeight = 500,
	ArenaSpacing = 256,
	MaxConcurrentArenas = 16,
})
