--!strict
-- Weekly boss raid tunables. The active boss rotates by ISO week derived
-- from unix time; no state is stored.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type LootEntry = {
	Type: "Food" | "Egg" | "Gems" | "Cosmetic",
	Id: string?,
	Count: number,
	Weight: number,
}

return TableUtil.deepFreeze({
	-- Up to this many players share one raid instance.
	MaxPartySize = 4,

	-- A raid launches when the party is full, or after this wait with at
	-- least one member.
	LobbyWaitSeconds = 15,

	-- All bosses share this stat template; the element rotates weekly.
	BossStats = { HP = 600, Attack = 550, Defence = 200, Speed = 150 },
	BossStage = "Alpha",

	-- Weekly rotation order. Week N uses Bosses[(N % count) + 1].
	Bosses = {
		{ Id = "Ignarok", DisplayName = "Ignarok the Cinder Tyrant", Element = "Flame" },
		{ Id = "Maelstra", DisplayName = "Maelstra of the Deep", Element = "Tide" },
		{ Id = "Gravemaw", DisplayName = "Gravemaw the Unmoving", Element = "Terra" },
		{ Id = "Voltessa", DisplayName = "Voltessa Skyrender", Element = "Storm" },
		{ Id = "Nyxshade", DisplayName = "Nyxshade the Hollow", Element = "Shadow" },
		{ Id = "Aurelion", DisplayName = "Aurelion Dawnbringer", Element = "Radiant" },
	},

	-- Raid chest: each clear rolls this many entries from the loot table.
	ChestRolls = 2,

	LootTable = {
		{ Type = "Food", Id = "Meat", Count = 3, Weight = 30 },
		{ Type = "Food", Id = "Feast", Count = 1, Weight = 20 },
		{ Type = "Gems", Id = nil, Count = 10, Weight = 20 },
		{ Type = "Egg", Id = "Storm", Count = 1, Weight = 15 },
		{ Type = "Egg", Id = "Royal", Count = 1, Weight = 9 },
		{ Type = "Cosmetic", Id = "RaidAura", Count = 1, Weight = 5 },
		{ Type = "Egg", Id = "Mythic", Count = 1, Weight = 1 },
	} :: { LootEntry },

	-- Coins granted instead when an egg drop cannot fit in storage.
	EggFallbackCoins = 1500,
})
