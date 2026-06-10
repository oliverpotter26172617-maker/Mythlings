--!strict
-- Launch and operations flags. These are the DEFAULTS; live servers poll
-- the LiveConfig DataStore and any flag found there overrides the value
-- here within a minute, giving real kill switches without a redeploy.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Kill switches.
	PurchasesEnabled = true, -- Robux receipts and pass grants
	BreedingEnabled = true,
	MatchmakingEnabled = true,
	RaidsEnabled = true,

	-- Soft launch: when true the experience is in its limited-visibility
	-- phase. In-server matchmaking is unaffected (queues are per server);
	-- region limiting is done through place visibility settings.
	SoftLaunch = true,

	-- Live override polling.
	LiveConfigStore = "MythlingsLiveConfig",
	LiveConfigKey = "Flags",
	LiveConfigPollSeconds = 60,
})
