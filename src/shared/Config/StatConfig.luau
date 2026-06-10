--!strict
-- Stat maths tunables. Final stats are computed by Logic/StatCalc:
--
--   stat = ceil(RarityBudget * SpeciesSpread * StageMultiplier * PotentialScale)
--   PotentialScale = PotentialBase + (potential / 100) * PotentialRange
--
-- Potential is hidden, rolled 1 to 100 at hatch, and is the only per-unit
-- stat variance. Cosmetics never appear in this formula.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Total stat points at Adult stage with Potential 50.
	RarityBudgets = {
		Common = 400,
		Uncommon = 460,
		Rare = 530,
		Epic = 610,
		Legendary = 700,
		Mythic = 800,
	},

	StageOrder = { "Hatchling", "Juvenile", "Adult", "Alpha" },

	StageMultipliers = {
		Hatchling = 0.50,
		Juvenile = 0.75,
		Adult = 1.00,
		Alpha = 1.15,
	},

	-- Model scale per stage, used by the spawner and LODs.
	StageScales = {
		Hatchling = 0.6,
		Juvenile = 0.85,
		Adult = 1.1,
		Alpha = 1.35,
	},

	PotentialBase = 0.85,
	PotentialRange = 0.30,
	PotentialMin = 1,
	PotentialMax = 100,
})
