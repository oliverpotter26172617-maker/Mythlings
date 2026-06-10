--!strict
-- Every egg tier: price, hatch timer, rarity odds and element bias.
--
-- POLICY: the odds tables below are shown to the player on the purchase UI
-- before any randomised purchase, exactly as written here (Roblox paid
-- random item rules). The odds UI renders directly from this module; there
-- is no second copy to drift.
--
-- Odds are percentages and every table must sum to exactly 100. A unit test
-- fails the build if it does not.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type EggTierDef = {
	DisplayName: string,
	Price: { Currency: "Coins" | "Gems", Amount: number },
	HatchMinutes: number,
	Odds: { [string]: number },
	ElementBias: string?,
	ShopOrder: number,
}

local tiers: { [string]: EggTierDef } = {
	Basic = {
		DisplayName = "Basic Egg",
		Price = { Currency = "Coins", Amount = 400 },
		HatchMinutes = 2,
		Odds = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 0.9, Mythic = 0.1 },
		ElementBias = nil,
		ShopOrder = 1,
	},
	Forest = {
		DisplayName = "Forest Egg",
		Price = { Currency = "Coins", Amount = 900 },
		HatchMinutes = 10,
		Odds = { Common = 52, Uncommon = 28, Rare = 13, Epic = 5.5, Legendary = 1.2, Mythic = 0.3 },
		ElementBias = "Terra",
		ShopOrder = 2,
	},
	Ember = {
		DisplayName = "Ember Egg",
		Price = { Currency = "Coins", Amount = 2000 },
		HatchMinutes = 30,
		Odds = { Common = 45, Uncommon = 30, Rare = 16, Epic = 7, Legendary = 1.6, Mythic = 0.4 },
		ElementBias = "Flame",
		ShopOrder = 3,
	},
	Tidal = {
		DisplayName = "Tidal Egg",
		Price = { Currency = "Coins", Amount = 4500 },
		HatchMinutes = 90,
		Odds = { Common = 38, Uncommon = 31, Rare = 20, Epic = 8.5, Legendary = 1.9, Mythic = 0.6 },
		ElementBias = "Tide",
		ShopOrder = 4,
	},
	Storm = {
		DisplayName = "Storm Egg",
		Price = { Currency = "Coins", Amount = 9000 },
		HatchMinutes = 240,
		Odds = { Common = 30, Uncommon = 31, Rare = 25, Epic = 11, Legendary = 2.2, Mythic = 0.8 },
		ElementBias = "Storm",
		ShopOrder = 5,
	},
	Royal = {
		DisplayName = "Royal Egg",
		Price = { Currency = "Gems", Amount = 250 },
		HatchMinutes = 480,
		Odds = { Common = 0, Uncommon = 30, Rare = 40, Epic = 24, Legendary = 5, Mythic = 1 },
		ElementBias = nil,
		ShopOrder = 6,
	},
	Mythic = {
		DisplayName = "Mythic Egg",
		Price = { Currency = "Gems", Amount = 950 },
		HatchMinutes = 720,
		Odds = { Common = 0, Uncommon = 0, Rare = 35, Epic = 45, Legendary = 16, Mythic = 4 },
		ElementBias = nil,
		ShopOrder = 7,
	},
}

return TableUtil.deepFreeze({
	Tiers = tiers,

	-- Guaranteed Epic or better after this many hatches of one tier without
	-- an Epic+ result. Tracked per player per tier.
	PityThreshold = 50,
	PityMinRarity = "Epic",

	-- Instant finish price: ceil(minutesRemaining * this) Gems.
	InstantHatchGemsPerMinute = 0.4,

	-- Element bias weighting: share of species rolls steered to the biased
	-- element. The rest of the weight is spread evenly over all elements.
	ElementBiasWeight = 0.5,
})
