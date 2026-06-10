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
}

return TableUtil.deepFreeze({
	DefaultBurst = 8,
	DefaultPerMinute = 60,
	Remotes = remotes,
})
