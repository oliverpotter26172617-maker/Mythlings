--!strict
-- Profile template, schema version and migrations. Pure Luau so the whole
-- module is unit-testable under Lune.
--
-- Migration rules (house rule, non-negotiable): a migration must never wipe
-- a field without first writing a reversible backup via backupField. Backups
-- live in data.MigrationBackups[versionKey][fieldName].

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local PlayerConfig = require(script.Parent.Parent.Config.PlayerConfig)

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 1

-- The template is a function so every profile gets fresh table identities.
function ProfileSchema.buildTemplate(): { [string]: any }
	return {
		SchemaVersion = ProfileSchema.CURRENT_VERSION,
		CreatedAt = 0,
		LastSeenAt = 0,

		Currencies = {
			Coins = PlayerConfig.StartingCurrencies.Coins,
			Gems = PlayerConfig.StartingCurrencies.Gems,
			BattleTokens = PlayerConfig.StartingCurrencies.BattleTokens,
		},

		-- [mythlingId string]: Mythling record (see Types/MythlingTypes)
		Mythlings = {},
		NextMythlingId = 1,

		-- [eggId string]: owned egg record, incubating or stored
		Eggs = {},
		NextEggId = 1,

		-- Ordered list of Mythling ids currently following the player.
		ActiveMythlings = {},

		Inventory = {
			Food = {}, -- [foodId]: count
			Items = {}, -- [itemId]: count
		},

		Housing = {
			PlotTier = 1,
			Theme = "Starter",
			OwnedThemes = { Starter = true },
			Furniture = {}, -- [furnitureGuid]: { ItemId, X, Z, Rotation }
			NextFurnitureId = 1,
			LastIncomeClaimAt = 0,
			VisitBonusDay = 0,
			VisitBonusCount = 0,
			VisitedToday = {},
			HostBonusDay = 0,
			HostBonusCount = 0,
		},

		Cosmetics = {
			OwnedAvatar = {}, -- [cosmeticId]: true
			OwnedMythling = {}, -- [cosmeticId]: true
			EquippedAvatar = {}, -- [slot]: cosmeticId
		},

		Stats = {
			Trophies = 0,
			SeasonHighestTrophies = 0,
			LastSeason = 0,
			BattlesWon = 0,
			BattlesLost = 0,
			WinStreak = 0,
			LossStreak = 0,
			TotalHatches = 0,
			TotalBreeds = 0,
			RaidsCleared = 0,
		},

		-- [eggTier]: hatches since the last Epic-or-better result
		PityCounters = {},

		-- Cache of owned game passes, refreshed on join and on purchase.
		Passes = {},

		-- [receiptId]: unix time processed. Guarantees idempotent receipts.
		PurchaseLedger = {},

		BattlePass = {
			Season = 0,
			Tier = 0,
			Xp = 0,
			OwnsPremium = false,
			ClaimedFree = {},
			ClaimedPremium = {},
		},

		Settings = {
			Music = PlayerConfig.DefaultSettings.Music,
			Sfx = PlayerConfig.DefaultSettings.Sfx,
			LowQuality = PlayerConfig.DefaultSettings.LowQuality,
		},

		Quests = {
			DayStamp = -1,
			WeekStamp = -1,
			Daily = {},
			Weekly = {},
		},

		LoginCalendar = {
			LastClaimDay = -1,
			DayIndex = 0,
		},

		Gifts = {
			DayStamp = -1,
			Given = {},
		},

		Flags = {
			OnboardingStep = 0,
			StarterEggGranted = false,
			LastVipStipendDay = 0,
			GroupBonus = false,
		},

		MigrationBackups = {},
	}
end

-- Copies a field into the reversible backup store before a migration
-- changes or removes it.
function ProfileSchema.backupField(data: { [string]: any }, version: number, fieldName: string, value: any)
	data.MigrationBackups = data.MigrationBackups or {}
	local key = "v" .. tostring(version)
	data.MigrationBackups[key] = data.MigrationBackups[key] or {}
	data.MigrationBackups[key][fieldName] = TableUtil.deepCopy(value)
end

-- Ordered migrations. migrations[n] upgrades a profile from version n-1 to n.
-- Version 1 is the initial schema so the table starts empty. Example shape:
--
--   ProfileSchema.migrations[2] = function(data)
--       ProfileSchema.backupField(data, 2, "OldField", data.OldField)
--       data.NewField = transform(data.OldField)
--       data.OldField = nil
--   end
ProfileSchema.migrations = {} :: { [number]: (data: { [string]: any }) -> () }

-- Runs every pending migration in order. Returns the list of versions that
-- were applied. Exposed with injectable arguments for unit testing.
function ProfileSchema.runMigrations(
	data: { [string]: any },
	migrations: { [number]: (data: { [string]: any }) -> () }?,
	targetVersion: number?
): { number }
	local list = migrations or ProfileSchema.migrations
	local target = targetVersion or ProfileSchema.CURRENT_VERSION
	local applied = {}

	local from = data.SchemaVersion or 1
	if from > target then
		error(`Profile schema version {from} is newer than supported version {target}`)
	end

	for version = from + 1, target do
		local migration = list[version]
		if migration == nil then
			error(`Missing migration to schema version {version}`)
		end
		migration(data)
		data.SchemaVersion = version
		table.insert(applied, version)
	end

	-- Stamp the version even on the no-op path (from == target), so a profile
	-- that needed no migration still records the current schema version
	-- rather than leaving it unset for template reconciliation to fill in.
	data.SchemaVersion = target
	return applied
end

return ProfileSchema
