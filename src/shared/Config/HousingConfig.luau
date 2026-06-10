--!strict
-- Housing tunables: plot sizes, themes, furniture catalogue, idle income.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type FurnitureDef = {
	DisplayName: string,
	PriceCoins: number,
	-- Footprint in grid cells (width along X, depth along Z) at rotation 0.
	Width: number,
	Depth: number,
	Height: number,
}

return TableUtil.deepFreeze({
	-- Studs per grid cell; all placements snap to this.
	GridSize = 2,

	-- Plot size tiers: side length in grid cells (square plots) and the
	-- Coins price to upgrade INTO that tier.
	PlotTiers = {
		{ Cells = 16, UpgradeCoins = 0 },
		{ Cells = 24, UpgradeCoins = 5000 },
		{ Cells = 32, UpgradeCoins = 20000 },
		{ Cells = 40, UpgradeCoins = 60000 },
	},

	-- Cosmetic themes. Starter is free; CloudIsle is the VIP exclusive and
	-- cannot be bought directly.
	Themes = {
		Starter = { PriceGems = 0, FloorColour = { R = 124, G = 179, B = 66 } },
		Castle = { PriceGems = 150, FloorColour = { R = 144, G = 164, B = 174 } },
		Treehouse = { PriceGems = 150, FloorColour = { R = 141, G = 110, B = 99 } },
		VolcanoLair = { PriceGems = 250, FloorColour = { R = 84, G = 58, B = 56 } },
		CloudIsle = { PriceGems = -1, FloorColour = { R = 207, G = 216, B = 220 } },
	},

	Furniture = {
		Bed = { DisplayName = "Mythling Bed", PriceCoins = 350, Width = 2, Depth = 3, Height = 1 },
		Bowl = { DisplayName = "Feeding Bowl", PriceCoins = 150, Width = 1, Depth = 1, Height = 0.5 },
		Tree = { DisplayName = "Shade Tree", PriceCoins = 800, Width = 3, Depth = 3, Height = 6 },
		Fountain = { DisplayName = "Crystal Fountain", PriceCoins = 2500, Width = 4, Depth = 4, Height = 4 },
		Bench = { DisplayName = "Garden Bench", PriceCoins = 500, Width = 3, Depth = 1, Height = 1.5 },
		Lantern = { DisplayName = "Glow Lantern", PriceCoins = 250, Width = 1, Depth = 1, Height = 3 },
	} :: { [string]: FurnitureDef },

	-- Cap on placed furniture per plot tier index.
	MaxFurniture = { 12, 20, 32, 48 },

	-- Idle income: Coins per hour per housed Mythling, by rarity.
	IncomePerHour = {
		Common = 10,
		Uncommon = 16,
		Rare = 26,
		Epic = 45,
		Legendary = 80,
		Mythic = 140,
	},

	-- Fed within this window doubles that Mythling's income (happiness).
	FedBonusWindowHours = 24,
	FedBonusMultiplier = 2,

	-- Income stops accruing beyond this many hours unclaimed.
	MaxAccrualHours = 12,

	-- Friend visiting: both players earn this once per distinct friend
	-- per day, capped per day for the visitor.
	VisitBonusCoins = 200,
	VisitBonusDailyCap = 5,

	-- Neighbourhood layout: plot world positions on a grid.
	PlotSpacing = 120,
	PlotsPerRow = 8,
	PlotBaseHeight = 1,
})
