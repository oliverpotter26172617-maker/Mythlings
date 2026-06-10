--!strict
-- Breeding tunables. Locked by spec: 6 hour cooldown, 2% Shiny chance,
-- Potential averaged with a random swing of plus or minus 15, rarity
-- upgrade chance only when both parents share a rarity.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	CooldownHours = 6,

	-- Gems to skip the remaining cooldown, per hour remaining (rounded up,
	-- minimum 1 when any time remains).
	GemSkipPerHour = 8,

	-- Cosmetic recolour only; no stat fields exist on Shiny variants.
	ShinyChance = 0.02,

	-- Offspring Potential = average of parents plus a uniform integer swing
	-- in [-PotentialSwing, PotentialSwing], clamped to the legal range.
	PotentialSwing = 15,

	-- Share of the element roll given to the parents' elements (split
	-- between them; combined when both parents share an element). The
	-- remainder is spread evenly over the other elements.
	ParentElementShare = 0.8,

	-- Chance to upgrade the offspring one rarity tier when both parents
	-- are the same rarity (capped at Mythic).
	SameRarityUpgradeChance = 0.15,

	-- Bred eggs incubate for this long.
	BredEggHatchMinutes = 180,

	-- Minimum growth stage to breed.
	MinBreedStage = "Adult",
})
