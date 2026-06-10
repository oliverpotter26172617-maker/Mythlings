--!strict
-- Registry of every remote in the game with its kind and rate limit.
-- A remote that is not listed here cannot be created or handled; this file
-- is the single source of truth the security audit walks.
--
-- Burst: instant calls allowed before throttling.
-- PerMinute: sustained calls per minute once the burst is spent.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type RemoteDef = {
	Kind: "Event" | "Function",
	Burst: number,
	PerMinute: number,
}

local remotes: { [string]: RemoteDef } = {
	-- Server -> client push of the player's sanitised profile snapshot and
	-- subsequent deltas. Client never sends on this remote.
	ProfileSync = { Kind = "Event", Burst = 1, PerMinute = 1 },

	-- Buys one egg of a given tier with Coins or Gems (server decides cost).
	BuyEgg = { Kind = "Function", Burst = 4, PerMinute = 30 },

	-- Starts incubating an owned egg in a free slot.
	StartIncubation = { Kind = "Function", Burst = 4, PerMinute = 30 },

	-- Claims a finished hatch and rolls the Mythling.
	ClaimHatch = { Kind = "Function", Burst = 4, PerMinute = 30 },

	-- Pays Gems to finish an incubating egg now, then claims it.
	InstantFinishHatch = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Sets which owned Mythlings follow the player (array of ids).
	SetActiveMythlings = { Kind = "Function", Burst = 4, PerMinute = 30 },

	-- Buys food items for Coins or Gems.
	BuyFood = { Kind = "Function", Burst = 5, PerMinute = 40 },

	-- Feeds one owned food item to one owned Mythling.
	FeedMythling = { Kind = "Function", Burst = 6, PerMinute = 60 },

	-- Server -> client: a Mythling reached a new growth stage (for VFX).
	StageUpEffect = { Kind = "Event", Burst = 1, PerMinute = 1 },
}

return TableUtil.deepFreeze({
	DefaultBurst = 8,
	DefaultPerMinute = 60,
	Remotes = remotes,
})
