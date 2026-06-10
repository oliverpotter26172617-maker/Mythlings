--!strict
-- Rotating Arena Shop: the Battle Token sink. Three slots rotate weekly
-- over this pool (exclusive cosmetics, rare food, occasional Epic eggs).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type ShopEntry = {
	Type: "Cosmetic" | "Food" | "Egg",
	Id: string,
	PriceTokens: number,
}

return TableUtil.deepFreeze({
	SlotsPerWeek = 3,

	Pool = {
		{ Type = "Cosmetic", Id = "GladiatorHelm", PriceTokens = 60 },
		{ Type = "Cosmetic", Id = "StarTrail", PriceTokens = 45 },
		{ Type = "Food", Id = "RoyalJelly", PriceTokens = 25 },
		{ Type = "Food", Id = "Feast", PriceTokens = 10 },
		{ Type = "Egg", Id = "Royal", PriceTokens = 80 },
		{ Type = "Cosmetic", Id = "TinyTopHat", PriceTokens = 30 },
		{ Type = "Egg", Id = "Storm", PriceTokens = 40 },
		{ Type = "Cosmetic", Id = "MoonAura", PriceTokens = 55 },
	} :: { ShopEntry },
})
