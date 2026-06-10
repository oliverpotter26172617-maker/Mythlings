--!strict
-- Weekly boss selection and chest rolling. Pure Luau.

local AbilityConfig = require(script.Parent.Parent.Config.AbilityConfig)
local RaidConfig = require(script.Parent.Parent.Config.RaidConfig)

local RaidLogic = {}

local SECONDS_PER_WEEK = 7 * 24 * 3600

function RaidLogic.weekIndex(now: number): number
	return math.floor(now / SECONDS_PER_WEEK)
end

function RaidLogic.bossForWeek(weekIndex: number): { [string]: any }
	local count = #RaidConfig.Bosses
	return RaidConfig.Bosses[(weekIndex % count) + 1]
end

function RaidLogic.bossFor(now: number): { [string]: any }
	return RaidLogic.bossForWeek(RaidLogic.weekIndex(now))
end

-- Battle unit spec for the active boss.
function RaidLogic.bossUnitSpec(now: number): { [string]: any }
	local boss = RaidLogic.bossFor(now)
	return {
		Id = `Boss:{boss.Id}`,
		Element = boss.Element,
		Stats = {
			HP = RaidConfig.BossStats.HP,
			Attack = RaidConfig.BossStats.Attack,
			Defence = RaidConfig.BossStats.Defence,
			Speed = RaidConfig.BossStats.Speed,
		},
		Abilities = AbilityConfig.loadout(boss.Element, RaidConfig.BossStage),
		CastPolicy = "Auto",
		DisplayName = boss.DisplayName,
	}
end

-- Rolls the raid chest: ChestRolls weighted picks from the loot table.
function RaidLogic.rollChest(rng: () -> number): { RaidConfig.LootEntry }
	local total = 0
	for _, entry in RaidConfig.LootTable do
		total += entry.Weight
	end

	local drops = {}
	for _ = 1, RaidConfig.ChestRolls do
		local roll = rng() * total
		local cumulative = 0
		for _, entry in RaidConfig.LootTable do
			cumulative += entry.Weight
			if roll < cumulative then
				table.insert(drops, entry)
				break
			end
		end
	end
	return drops
end

return RaidLogic
