--!strict
-- Seasonal Battle Pass: 50 tiers, free and premium tracks, 8-week
-- seasons. Premium unlocks via the BattlePassPremium product (799 Robux).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type PassReward = {
	Type: "Coins" | "Gems" | "Food" | "Egg" | "Cosmetic",
	Id: string?,
	Count: number,
}

local TIER_COUNT = 50

-- Tier reward tables. Built by rule so designers can re-tune the rhythm
-- in one place; the generated tables are still plain data at runtime.
local freeTrack: { [number]: PassReward } = {}
local premiumTrack: { [number]: PassReward } = {}

for tier = 1, TIER_COUNT do
	if tier % 10 == 0 then
		freeTrack[tier] = { Type = "Gems", Id = nil, Count = 10 + tier }
		premiumTrack[tier] = { Type = "Egg", Id = if tier == TIER_COUNT then "Mythic" else "Royal", Count = 1 }
	elseif tier % 5 == 0 then
		freeTrack[tier] = { Type = "Food", Id = "Feast", Count = 1 }
		premiumTrack[tier] = { Type = "Gems", Id = nil, Count = 25 }
	elseif tier % 2 == 0 then
		freeTrack[tier] = { Type = "Coins", Id = nil, Count = 150 + tier * 10 }
		premiumTrack[tier] = { Type = "Coins", Id = nil, Count = 400 + tier * 20 }
	else
		freeTrack[tier] = { Type = "Food", Id = "Berry", Count = 2 }
		premiumTrack[tier] = { Type = "Food", Id = "Meat", Count = 2 }
	end
end

-- Tier 1 premium is the exclusive seasonal cosmetic.
premiumTrack[1] = { Type = "Cosmetic", Id = "SeasonAura", Count = 1 }

return TableUtil.deepFreeze({
	TierCount = TIER_COUNT,
	XpPerTier = 1000,

	SeasonLengthWeeks = 8,
	-- Monday 2026-01-05 00:00 UTC; season 1 starts here.
	SeasonEpoch = 1767571200,

	-- Pass XP per battle outcome.
	XpRewards = {
		RankedWin = 100,
		RankedLoss = 40,
		CasualWin = 60,
		CasualLoss = 25,
		RaidClear = 150,
		RaidFail = 25,
	},

	FreeTrack = freeTrack,
	PremiumTrack = premiumTrack,
})
