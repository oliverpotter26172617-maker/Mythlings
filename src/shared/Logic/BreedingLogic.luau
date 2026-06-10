--!strict
-- Breeding inheritance maths. Pure Luau, rng injected.

local BreedingConfig = require(script.Parent.Parent.Config.BreedingConfig)
local ElementConfig = require(script.Parent.Parent.Config.ElementConfig)
local RarityConfig = require(script.Parent.Parent.Config.RarityConfig)
local StatConfig = require(script.Parent.Parent.Config.StatConfig)
local HatchLogic = require(script.Parent.HatchLogic)

local BreedingLogic = {}

export type Rng = () -> number

export type Offspring = {
	SpeciesId: string,
	Element: string,
	Rarity: string,
	Potential: number,
	Shiny: boolean,
}

-- Element roll: parents' elements take ParentElementShare of the mass
-- (split between them, combined if equal); the rest spreads evenly over
-- the remaining elements.
function BreedingLogic.rollElement(elementA: string, elementB: string, rng: Rng): string
	local weights: { [string]: number } = {}
	local parentElements: { [string]: number } = {}
	parentElements[elementA] = (parentElements[elementA] or 0) + 0.5
	parentElements[elementB] = (parentElements[elementB] or 0) + 0.5

	local parentCount = 0
	for _ in parentElements do
		parentCount += 1
	end
	local othersCount = #ElementConfig.Order - parentCount
	local otherShare = if othersCount > 0 then (1 - BreedingConfig.ParentElementShare) / othersCount else 0

	for _, element in ElementConfig.Order do
		local parentPortion = parentElements[element]
		if parentPortion ~= nil then
			weights[element] = BreedingConfig.ParentElementShare * parentPortion
		else
			weights[element] = otherShare
		end
	end

	return HatchLogic.rollWeighted(weights, rng)
end

-- Rarity roll: take one parent's rarity at even chance; when both parents
-- share a rarity there is a configured chance to upgrade one tier.
function BreedingLogic.rollRarity(rarityA: string, rarityB: string, rng: Rng): string
	local base = if rng() < 0.5 then rarityA else rarityB
	if rarityA == rarityB and rng() < BreedingConfig.SameRarityUpgradeChance then
		local index = RarityConfig.IndexByName[base]
		local upgraded = RarityConfig.Order[math.min(index + 1, #RarityConfig.Order)]
		return upgraded
	end
	return base
end

function BreedingLogic.rollPotential(potentialA: number, potentialB: number, rng: Rng): number
	local average = (potentialA + potentialB) / 2
	local swing = BreedingConfig.PotentialSwing
	local offset = math.floor(rng() * (swing * 2 + 1)) - swing
	return math.clamp(math.floor(average + offset + 0.5), StatConfig.PotentialMin, StatConfig.PotentialMax)
end

-- Species pick: prefer the rolled element at the rolled rarity; if no such
-- species exists (some rarities lack some elements), fall back to any
-- species of the rolled rarity.
function BreedingLogic.pickSpecies(catalogue: { [string]: any }, rarity: string, element: string, rng: Rng): string
	local exact: { [string]: number } = {}
	local anyAtRarity: { [string]: number } = {}
	for id, def in catalogue do
		if def.Rarity == rarity then
			anyAtRarity[id] = 1
			if def.Element == element then
				exact[id] = 1
			end
		end
	end
	if next(exact) ~= nil then
		return HatchLogic.rollWeighted(exact, rng)
	end
	assert(next(anyAtRarity) ~= nil, `no species exist at rarity {rarity}`)
	return HatchLogic.rollWeighted(anyAtRarity, rng)
end

function BreedingLogic.breed(
	parentA: { Element: string, Rarity: string, Potential: number },
	parentB: { Element: string, Rarity: string, Potential: number },
	catalogue: { [string]: any },
	rng: Rng
): Offspring
	local element = BreedingLogic.rollElement(parentA.Element, parentB.Element, rng)
	local rarity = BreedingLogic.rollRarity(parentA.Rarity, parentB.Rarity, rng)
	local speciesId = BreedingLogic.pickSpecies(catalogue, rarity, element, rng)
	local potential = BreedingLogic.rollPotential(parentA.Potential, parentB.Potential, rng)
	local shiny = rng() < BreedingConfig.ShinyChance

	local species = catalogue[speciesId]
	return {
		SpeciesId = speciesId,
		Element = species.Element,
		Rarity = species.Rarity,
		Potential = potential,
		Shiny = shiny,
	}
end

-- Validation for a breed request against the caller's own profile.
function BreedingLogic.validateBreed(
	data: { [string]: any },
	idA: string,
	idB: string,
	now: number,
	maxStoredEggs: number
): { Ok: boolean, Error: string? }
	if idA == idB then
		return { Ok = false, Error = "Pick two different Mythlings." }
	end
	local stageIndex: { [string]: number } = {}
	for index, stage in StatConfig.StageOrder do
		stageIndex[stage] = index
	end
	local minIndex = stageIndex[BreedingConfig.MinBreedStage]

	local eggCount = 0
	for _ in data.Eggs do
		eggCount += 1
	end
	if eggCount >= maxStoredEggs then
		return { Ok = false, Error = "Your egg storage is full. Hatch some eggs first." }
	end

	for _, id in { idA, idB } do
		local record = data.Mythlings[id]
		if record == nil then
			return { Ok = false, Error = "You do not own both of those Mythlings." }
		end
		if (stageIndex[record.Stage] or 0) < minIndex then
			return { Ok = false, Error = `Both Mythlings must be {BreedingConfig.MinBreedStage} stage or above.` }
		end
		if record.BreedCooldownUntil > now then
			return { Ok = false, Error = "One of those Mythlings needs to rest before breeding again." }
		end
	end

	return { Ok = true }
end

-- Gems to clear the remaining breeding cooldown.
function BreedingLogic.skipCost(secondsRemaining: number): number
	if secondsRemaining <= 0 then
		return 0
	end
	return math.max(1, math.ceil((secondsRemaining / 3600) * BreedingConfig.GemSkipPerHour))
end

return BreedingLogic
