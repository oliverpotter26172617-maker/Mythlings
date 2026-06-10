--!strict
-- Monetisation SKUs (Section 3.9, locked). ProductId/PassId values are
-- Roblox asset ids and MUST be filled in from the Creator Dashboard before
-- launch; zero means "not yet wired" and purchase prompts will refuse.
-- Robux prices are recorded here for reference; Roblox charges what the
-- dashboard says, so keep them in sync.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type DevProductDef = {
	ProductId: number,
	Robux: number,
	Type: "Gems" | "BattlePassPremium",
	Amount: number?,
}

export type GamePassDef = {
	PassId: number,
	Robux: number,
}

return TableUtil.deepFreeze({
	-- Consumable developer products. Gem packs use standard value laddering.
	DevProducts = {
		Gems100 = { ProductId = 0, Robux = 99, Type = "Gems", Amount = 100 },
		Gems550 = { ProductId = 0, Robux = 499, Type = "Gems", Amount = 550 },
		Gems1200 = { ProductId = 0, Robux = 999, Type = "Gems", Amount = 1200 },
		Gems6500 = { ProductId = 0, Robux = 4999, Type = "Gems", Amount = 6500 },
		BattlePassPremium = { ProductId = 0, Robux = 799, Type = "BattlePassPremium" },
	} :: { [string]: DevProductDef },

	-- One-off game passes. Benefits are read from the server-side pass
	-- cache (Profile.Passes), refreshed on join and on purchase.
	GamePasses = {
		VIP = { PassId = 0, Robux = 449 },
		HatchSpeed = { PassId = 0, Robux = 349 },
		TripleHatch = { PassId = 0, Robux = 599 },
		AutoHatch = { PassId = 0, Robux = 499 },
		ExtraStorage = { PassId = 0, Robux = 249 },
	} :: { [string]: GamePassDef },

	-- Pass benefit tunables.
	VipCoinMultiplier = 1.25,
	VipDailyGems = 10,
	VipChatTag = "VIP",
	VipPlotTheme = "CloudIsle",
	HatchSpeedMultiplier = 1.5, -- incubation time divides by this
	AutoHatchTier = "Basic",
	AutoHatchIntervalSeconds = 10,
})
