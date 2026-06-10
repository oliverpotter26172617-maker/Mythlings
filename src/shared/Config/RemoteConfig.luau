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

	-- Breeds two owned Adult+ Mythlings into an egg.
	BreedMythlings = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Pays Gems to clear a Mythling's breeding cooldown.
	SkipBreedCooldown = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Joins or leaves the arena queue.
	JoinQueue = { Kind = "Function", Burst = 3, PerMinute = 20 },
	LeaveQueue = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Casts an ability for one of the caller's units in their live match.
	CastAbility = { Kind = "Function", Burst = 10, PerMinute = 120 },

	-- Server -> client battle lifecycle pushes.
	BattleStart = { Kind = "Event", Burst = 1, PerMinute = 1 },
	BattleEvents = { Kind = "Event", Burst = 1, PerMinute = 1 },
	BattleEnd = { Kind = "Event", Burst = 1, PerMinute = 1 },

	-- Server -> client: itemised payout after a battle.
	BattleRewards = { Kind = "Event", Burst = 1, PerMinute = 1 },

	-- Joins or leaves the weekly boss raid lobby.
	JoinRaid = { Kind = "Function", Burst = 3, PerMinute = 20 },
	LeaveRaid = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Server -> client: raid chest contents after a clear.
	RaidChest = { Kind = "Event", Burst = 1, PerMinute = 1 },

	-- Buys this week's Premium Nursery offer by slot index.
	BuyNurseryMythling = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Claims a reached Battle Pass tier on the Free or Premium track.
	ClaimBattlePassTier = { Kind = "Function", Burst = 6, PerMinute = 60 },

	-- Housing: upgrades, themes, furniture and visiting.
	BuyPlotUpgrade = { Kind = "Function", Burst = 3, PerMinute = 20 },
	BuyPlotTheme = { Kind = "Function", Burst = 3, PerMinute = 20 },
	SetPlotTheme = { Kind = "Function", Burst = 3, PerMinute = 20 },
	BuyFurniture = { Kind = "Function", Burst = 5, PerMinute = 40 },
	PlaceFurniture = { Kind = "Function", Burst = 8, PerMinute = 80 },
	RemoveFurniture = { Kind = "Function", Burst = 8, PerMinute = 80 },
	ClaimPlotIncome = { Kind = "Function", Burst = 3, PerMinute = 20 },
	VisitFriendPlot = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Persists a client settings toggle (Music, Sfx, LowQuality).
	UpdateSetting = { Kind = "Function", Burst = 4, PerMinute = 30 },

	-- Quests, calendar and gifting.
	ClaimQuest = { Kind = "Function", Burst = 6, PerMinute = 60 },
	GiftEgg = { Kind = "Function", Burst = 3, PerMinute = 20 },

	-- Server -> client: login calendar reward toast.
	CalendarReward = { Kind = "Event", Burst = 1, PerMinute = 1 },

	-- Server -> client: seasonal placement reward and trophy reset notice.
	SeasonRollover = { Kind = "Event", Burst = 1, PerMinute = 1 },

	-- Cosmetics: Gem purchases, equipping and the Battle Token shop.
	BuyCosmetic = { Kind = "Function", Burst = 4, PerMinute = 30 },
	EquipAvatarCosmetic = { Kind = "Function", Burst = 6, PerMinute = 60 },
	EquipMythlingCosmetic = { Kind = "Function", Burst = 6, PerMinute = 60 },
	BuyArenaShopItem = { Kind = "Function", Burst = 3, PerMinute = 20 },
}

return TableUtil.deepFreeze({
	DefaultBurst = 8,
	DefaultPerMinute = 60,
	Remotes = remotes,
})
