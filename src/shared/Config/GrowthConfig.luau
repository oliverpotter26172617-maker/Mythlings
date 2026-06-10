--!strict
-- Growth tunables: food catalogue and cumulative XP thresholds per stage.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type FoodDef = {
	DisplayName: string,
	Price: { Currency: "Coins" | "Gems", Amount: number },
	Xp: number,
	ShopOrder: number,
}

return TableUtil.deepFreeze({
	-- Cumulative XP required to reach each stage. Hatchling is the start.
	StageThresholds = {
		Hatchling = 0,
		Juvenile = 100,
		Adult = 400,
		Alpha = 1200,
	},

	Food = {
		Berry = {
			DisplayName = "Sunberry",
			Price = { Currency = "Coins", Amount = 50 },
			Xp = 10,
			ShopOrder = 1,
		},
		Meat = {
			DisplayName = "Hearty Haunch",
			Price = { Currency = "Coins", Amount = 200 },
			Xp = 45,
			ShopOrder = 2,
		},
		Feast = {
			DisplayName = "Grand Feast",
			Price = { Currency = "Coins", Amount = 800 },
			Xp = 200,
			ShopOrder = 3,
		},
		RoyalJelly = {
			DisplayName = "Royal Jelly",
			Price = { Currency = "Gems", Amount = 30 },
			Xp = 1000,
			ShopOrder = 4,
		},
	} :: { [string]: FoodDef },

	-- How many of one food item can be bought in a single request.
	MaxFoodPerPurchase = 20,
})
