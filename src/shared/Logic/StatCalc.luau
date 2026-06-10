--!strict
-- Final stat computation. The only inputs are config values plus the
-- Mythling's species, stage and hidden Potential. Cosmetics are not part
-- of this signature on purpose: they can never influence stats.

local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)
local StatConfig = require(script.Parent.Parent.Config.StatConfig)

local StatCalc = {}

export type Stats = { HP: number, Attack: number, Defence: number, Speed: number }

function StatCalc.potentialScale(potential: number): number
	local clamped = math.clamp(potential, StatConfig.PotentialMin, StatConfig.PotentialMax)
	return StatConfig.PotentialBase + (clamped / StatConfig.PotentialMax) * StatConfig.PotentialRange
end

function StatCalc.compute(speciesId: string, stage: string, potential: number): Stats
	local species = MythlingConfig.Species[speciesId]
	assert(species ~= nil, `unknown species {speciesId}`)
	local budget = StatConfig.RarityBudgets[species.Rarity]
	local stageMultiplier = StatConfig.StageMultipliers[stage]
	assert(stageMultiplier ~= nil, `unknown stage {stage}`)
	local scale = StatCalc.potentialScale(potential)

	local function stat(spreadShare: number): number
		return math.ceil(budget * spreadShare * stageMultiplier * scale)
	end

	return {
		HP = stat(species.Spread.HP),
		Attack = stat(species.Spread.Attack),
		Defence = stat(species.Spread.Defence),
		Speed = stat(species.Spread.Speed),
	}
end

-- Team Power: the matchmaking bracket input. Sum of all stats, HP weighted
-- half so tanks and cannons compare fairly.
function StatCalc.power(stats: Stats): number
	return math.floor(stats.HP * 0.5 + stats.Attack + stats.Defence + stats.Speed)
end

return StatCalc
