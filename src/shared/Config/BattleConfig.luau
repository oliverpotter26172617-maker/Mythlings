--!strict
-- Battle simulation tunables.
--
-- Damage formula (locked):
--   (ATK^2 / (ATK + DEF)) * abilityPower * elementMod * variance(0.9..1.1)
--
-- Element advantage wheel (+25% on advantage): Flame beats Terra, Terra
-- beats Storm, Storm beats Tide, Tide beats Flame; Shadow and Radiant
-- beat each other.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Simulation stepping. The server advances the sim on this interval.
	TickInterval = 0.1,

	-- Hard cap; at the cap the team with the higher HP fraction wins.
	MaxDurationSeconds = 240,

	-- Battle HP pool multiplier over the raw HP stat, sized so matches land
	-- in the 90 to 180 second target band.
	HpMultiplier = 110,

	-- Attack cadence: effectiveCooldown = base * 100 / (100 + Speed * SpeedFactor).
	SpeedFactor = 0.5,

	VarianceMin = 0.9,
	VarianceMax = 1.1,

	-- Sudden-death pacing: after EnrageStartSeconds, all damage gains
	-- EnrageRampPerSecond per second elapsed, so stalemates cannot run to
	-- the cap unresolved.
	EnrageStartSeconds = 150,
	EnrageRampPerSecond = 0.03,

	AdvantageMultiplier = 1.25,

	-- [attacking element] = defending element it has advantage over.
	Wheel = {
		Flame = { Terra = true },
		Terra = { Storm = true },
		Storm = { Tide = true },
		Tide = { Flame = true },
		Shadow = { Radiant = true },
		Radiant = { Shadow = true },
	},

	-- Cap on stored battle events (replay feed safety).
	MaxEvents = 4000,
})
