--!strict
-- Player-level tunables. Every number a designer might touch lives here.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Currencies granted to a brand-new profile. Kept low on purpose: the
	-- onboarding flow gifts a free Rare egg inside the first ten minutes.
	StartingCurrencies = {
		Coins = 250,
		Gems = 0,
		BattleTokens = 0,
	},

	-- Mythling storage. The Extra Storage game pass adds PassExtraSlots.
	BaseMythlingStorage = 50,
	PassExtraSlots = 100,

	-- Egg inventory limits (owned, not yet hatched).
	MaxStoredEggs = 12,

	-- Simultaneous incubation slots. Triple Hatch pass raises this to 3.
	BaseIncubationSlots = 1,
	TripleHatchSlots = 3,

	-- Battle team size for arena matches.
	TeamSize = 3,

	-- Mythlings that may follow the player around the world at once.
	MaxFollowers = 3,

	-- Follower formation tunables (studs).
	FollowDistance = 5,
	FollowSpacing = 3.5,
	FollowResponsiveness = 18,

	-- Default client settings for a new profile.
	DefaultSettings = {
		Music = true,
		Sfx = true,
		LowQuality = false,
	},
})
