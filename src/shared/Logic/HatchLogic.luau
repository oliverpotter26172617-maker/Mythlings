--!strict
-- Pure hatching maths: rarity rolls with pity, species selection with
-- element bias, potential rolls and incubation timing. The server is the
-- only caller for real rolls; rng is injected as a function returning a
-- number in [0, 1) so tests are deterministic.

local RarityConfig = require(script.Parent.Parent.Config.RarityConfig)

export type Rng = () -> number

export type HatchResult = {
	SpeciesId: string,
	Rarity: string,
	Potential: number,
	PityTriggered: boolean,
	NewPityCount: number,
}

local HatchLogic = {}

-- Weighted pick over a { [rarity]: percent } table. Weights need not sum to
-- any particular value here; EggConfig enforces 100 via its own test.
function HatchLogic.rollWeighted(weights: { [string]: number }, rng: Rng): string
	local total = 0
	for _, weight in weights do
		total += weight
	end
	assert(total > 0, "rollWeighted requires positive total weight")

	local roll = rng() * total
	local cumulative = 0
	local lastKey: string? = nil
	-- Deterministic iteration order: sort keys so the same roll always maps
	-- to the same outcome regardless of table hashing.
	local keys = {}
	for key in weights do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local weight = weights[key]
		if weight > 0 then
			cumulative += weight
			lastKey = key
			if roll < cumulative then
				return key
			end
		end
	end
	return lastKey :: string
end

local function isAtLeast(rarity: string, minRarity: string): boolean
	return RarityConfig.IndexByName[rarity] >= RarityConfig.IndexByName[minRarity]
end

-- Rolls a rarity honouring the pity counter. pityCount is the number of
-- hatches of this tier since the last Epic+ result; when this hatch would
-- be the threshold-th miss, the roll is restricted to PityMinRarity and up.
function HatchLogic.rollRarity(
	odds: { [string]: number },
	pityCount: number,
	pityThreshold: number,
	pityMinRarity: string,
	rng: Rng
): (string, boolean)
	local pityDue = pityCount + 1 >= pityThreshold
	if pityDue then
		local restricted: { [string]: number } = {}
		local total = 0
		for rarity, weight in odds do
			if isAtLeast(rarity, pityMinRarity) and weight > 0 then
				restricted[rarity] = weight
				total += weight
			end
		end
		if total > 0 then
			return HatchLogic.rollWeighted(restricted, rng), true
		end
		-- A tier with zero Epic+ odds cannot honour pity; fall through to a
		-- plain roll rather than crash (config test prevents this case).
	end

	local rarity = HatchLogic.rollWeighted(odds, rng)
	return rarity, false
end

-- Picks a species id of the given rarity. If elementBias is set, biasWeight
-- of the probability mass is steered to species of that element (when any
-- exist at this rarity); the remainder is spread evenly.
function HatchLogic.pickSpecies(
	catalogue: { [string]: any },
	rarity: string,
	elementBias: string?,
	biasWeight: number,
	rng: Rng
): string
	local weights: { [string]: number } = {}
	local biased = 0
	local total = 0
	for id, def in catalogue do
		if def.Rarity == rarity then
			weights[id] = 1
			total += 1
			if elementBias ~= nil and def.Element == elementBias then
				biased += 1
			end
		end
	end
	assert(total > 0, `no species exist at rarity {rarity}`)

	if elementBias ~= nil and biased > 0 and biased < total then
		local biasedShare = biasWeight / biased
		local otherShare = (1 - biasWeight) / (total - biased)
		for id in weights do
			local def = catalogue[id]
			weights[id] = if def.Element == elementBias then biasedShare else otherShare
		end
	end

	return HatchLogic.rollWeighted(weights, rng)
end

function HatchLogic.rollPotential(min: number, max: number, rng: Rng): number
	return min + math.floor(rng() * (max - min + 1))
end

-- Full hatch resolution for one egg.
function HatchLogic.hatch(args: {
	Odds: { [string]: number },
	ElementBias: string?,
	BiasWeight: number,
	Catalogue: { [string]: any },
	PityCount: number,
	PityThreshold: number,
	PityMinRarity: string,
	PotentialMin: number,
	PotentialMax: number,
	Rng: Rng,
}): HatchResult
	local rarity, pityTriggered =
		HatchLogic.rollRarity(args.Odds, args.PityCount, args.PityThreshold, args.PityMinRarity, args.Rng)
	local speciesId = HatchLogic.pickSpecies(args.Catalogue, rarity, args.ElementBias, args.BiasWeight, args.Rng)
	local potential = HatchLogic.rollPotential(args.PotentialMin, args.PotentialMax, args.Rng)

	local newPityCount
	if isAtLeast(rarity, args.PityMinRarity) then
		newPityCount = 0
	else
		newPityCount = args.PityCount + 1
	end

	return {
		SpeciesId = speciesId,
		Rarity = rarity,
		Potential = potential,
		PityTriggered = pityTriggered,
		NewPityCount = newPityCount,
	}
end

-- Gems required to finish a hatch instantly. Always at least 1 for any
-- remaining time, zero when already done.
function HatchLogic.instantFinishCost(secondsRemaining: number, gemsPerMinute: number): number
	if secondsRemaining <= 0 then
		return 0
	end
	return math.max(1, math.ceil((secondsRemaining / 60) * gemsPerMinute))
end

return HatchLogic
