--!strict
-- Server-side 3v3 battle simulation. Pure Luau: no Roblox APIs, rng
-- injected, stepped by the caller. Supports auto-cast units (PvE, tests)
-- and manual-cast units (live players queue ability casts; the basic
-- Strike always auto-fires so idling never stalls a match).

local AbilityConfig = require(script.Parent.Parent.Config.AbilityConfig)
local BattleConfig = require(script.Parent.Parent.Config.BattleConfig)

local BattleSim = {}
BattleSim.__index = BattleSim

export type Rng = () -> number

export type UnitSpec = {
	Id: string,
	Element: string,
	Stats: { HP: number, Attack: number, Defence: number, Speed: number },
	Abilities: { string },
	CastPolicy: "Auto" | "Manual"?,
	DisplayName: string?,
}

type AbilityState = {
	AbilityId: string,
	ReadyAt: number,
}

type Unit = {
	Id: string,
	Team: number,
	Element: string,
	DisplayName: string,
	Attack: number,
	Defence: number,
	Speed: number,
	MaxHp: number,
	Hp: number,
	Abilities: { AbilityState },
	CastPolicy: "Auto" | "Manual",
	QueuedCasts: { string },
}

export type BattleEvent = {
	Type: string,
	Time: number,
	Attacker: string?,
	Target: string?,
	AbilityId: string?,
	Damage: number?,
	TargetHp: number?,
	Killed: boolean?,
	Winner: number?,
}

export type BattleResult = {
	Winner: number, -- 1, 2 or 0 for a dead-even draw
	Duration: number,
	TeamHpFraction: { number },
	TimedOut: boolean,
}

function BattleSim.elementModifier(attackElement: string?, defendElement: string): number
	if attackElement == nil then
		return 1
	end
	local beats = BattleConfig.Wheel[attackElement]
	if beats ~= nil and beats[defendElement] == true then
		return BattleConfig.AdvantageMultiplier
	end
	return 1
end

-- The locked damage formula.
function BattleSim.damage(
	attack: number,
	defence: number,
	abilityPower: number,
	elementMod: number,
	variance: number
): number
	local base = (attack * attack) / (attack + defence)
	return math.max(1, math.floor(base * abilityPower * elementMod * variance))
end

local function buildUnit(spec: UnitSpec, team: number, now: number): Unit
	local abilityStates = {}
	for _, abilityId in spec.Abilities do
		assert(AbilityConfig.Abilities[abilityId] ~= nil, `unknown ability {abilityId}`)
		-- Stagger initial readiness so openers do not alpha-strike at once.
		table.insert(abilityStates, { AbilityId = abilityId, ReadyAt = now })
	end
	return {
		Id = spec.Id,
		Team = team,
		Element = spec.Element,
		DisplayName = spec.DisplayName or spec.Id,
		Attack = spec.Stats.Attack,
		Defence = spec.Stats.Defence,
		Speed = spec.Stats.Speed,
		MaxHp = spec.Stats.HP * BattleConfig.HpMultiplier,
		Hp = spec.Stats.HP * BattleConfig.HpMultiplier,
		Abilities = abilityStates,
		CastPolicy = spec.CastPolicy or "Auto",
		QueuedCasts = {},
	}
end

function BattleSim.new(teamA: { UnitSpec }, teamB: { UnitSpec }, rng: Rng)
	assert(#teamA > 0 and #teamB > 0, "both teams need at least one unit")
	local self = setmetatable({}, BattleSim)
	self._rng = rng
	self._time = 0
	self._carry = 0
	self._units = {} :: { Unit }
	self._unitsById = {} :: { [string]: Unit }
	self._events = {} :: { BattleEvent }
	self._finished = false
	self._result = nil :: BattleResult?

	for _, spec in teamA do
		local unit = buildUnit(spec, 1, 0)
		table.insert(self._units, unit)
		assert(self._unitsById[unit.Id] == nil, `duplicate unit id {unit.Id}`)
		self._unitsById[unit.Id] = unit
	end
	for _, spec in teamB do
		local unit = buildUnit(spec, 2, 0)
		table.insert(self._units, unit)
		assert(self._unitsById[unit.Id] == nil, `duplicate unit id {unit.Id}`)
		self._unitsById[unit.Id] = unit
	end

	return self
end

function BattleSim.getTime(self: any): number
	return self._time
end

function BattleSim.getEvents(self: any): { BattleEvent }
	return self._events
end

function BattleSim.isFinished(self: any): boolean
	return self._finished
end

function BattleSim.getResult(self: any): BattleResult?
	return self._result
end

function BattleSim.getUnitsPublicState(self: any): { { [string]: any } }
	local state = {}
	for _, unit in self._units :: { Unit } do
		table.insert(state, {
			Id = unit.Id,
			Team = unit.Team,
			Element = unit.Element,
			DisplayName = unit.DisplayName,
			Hp = unit.Hp,
			MaxHp = unit.MaxHp,
		})
	end
	return state
end

-- Queues a manual cast for a unit; ignored for unknown units/abilities.
-- Returns false with a reason string when the cast cannot queue.
function BattleSim.queueCast(self: any, unitId: string, abilityId: string): (boolean, string?)
	local unit: Unit? = self._unitsById[unitId]
	if unit == nil then
		return false, "unknown unit"
	end
	if unit.Hp <= 0 then
		return false, "unit is down"
	end
	for _, state in unit.Abilities do
		if state.AbilityId == abilityId then
			if state.ReadyAt > self._time then
				return false, "ability not ready"
			end
			if table.find(unit.QueuedCasts, abilityId) == nil then
				table.insert(unit.QueuedCasts, abilityId)
			end
			return true, nil
		end
	end
	return false, "unit does not have that ability"
end

local function aliveEnemies(self: any, team: number): { Unit }
	local result = {}
	for _, unit in self._units :: { Unit } do
		if unit.Team ~= team and unit.Hp > 0 then
			table.insert(result, unit)
		end
	end
	return result
end

local function teamAlive(self: any, team: number): boolean
	for _, unit in self._units :: { Unit } do
		if unit.Team == team and unit.Hp > 0 then
			return true
		end
	end
	return false
end

local function teamHpFraction(self: any, team: number): number
	local current, max = 0, 0
	for _, unit in self._units :: { Unit } do
		if unit.Team == team then
			current += math.max(0, unit.Hp)
			max += unit.MaxHp
		end
	end
	return if max > 0 then current / max else 0
end

local function pushEvent(self: any, event: BattleEvent)
	if #self._events < BattleConfig.MaxEvents then
		table.insert(self._events, event)
	end
end

local function effectiveCooldown(baseCooldown: number, speed: number): number
	return baseCooldown * 100 / (100 + speed * BattleConfig.SpeedFactor)
end

-- Focus the weakest enemy by absolute HP: concentrates fire and keeps
-- match pacing tight.
local function pickTarget(enemies: { Unit }): Unit
	local best = enemies[1]
	for _, enemy in enemies do
		if enemy.Hp < best.Hp then
			best = enemy
		end
	end
	return best
end

local function castAbility(self: any, unit: Unit, abilityState: AbilityState, target: Unit)
	local ability = AbilityConfig.Abilities[abilityState.AbilityId]
	local elementMod = BattleSim.elementModifier(ability.Element, target.Element)
	local variance = BattleConfig.VarianceMin + self._rng() * (BattleConfig.VarianceMax - BattleConfig.VarianceMin)
	local enrage = 1 + math.max(0, self._time - BattleConfig.EnrageStartSeconds) * BattleConfig.EnrageRampPerSecond
	local damage = BattleSim.damage(unit.Attack, target.Defence, ability.Power, elementMod, variance * enrage)

	target.Hp = math.max(0, target.Hp - damage)
	abilityState.ReadyAt = self._time + effectiveCooldown(ability.CooldownSeconds, unit.Speed)

	pushEvent(self, {
		Type = "Cast",
		Time = self._time,
		Attacker = unit.Id,
		Target = target.Id,
		AbilityId = abilityState.AbilityId,
		Damage = damage,
		TargetHp = target.Hp,
		Killed = target.Hp <= 0,
	})
end

local function finish(self: any, winner: number, timedOut: boolean)
	self._finished = true
	if timedOut then
		self._time = BattleConfig.MaxDurationSeconds
	end
	self._result = {
		Winner = winner,
		Duration = self._time,
		TeamHpFraction = { teamHpFraction(self, 1), teamHpFraction(self, 2) },
		TimedOut = timedOut,
	} :: BattleResult
	pushEvent(self, { Type = "End", Time = self._time, Winner = winner })
end

-- Runs exactly one fixed TickInterval of simulation. Every step funnels
-- through here so a battle's outcome depends only on the seed and the total
-- elapsed time, never on how the caller batches dt into steps.
local function runTick(self: any)
	self._time += BattleConfig.TickInterval

	for _, unit in self._units :: { Unit } do
		if unit.Hp <= 0 then
			continue
		end
		local enemies = aliveEnemies(self, unit.Team)
		if #enemies == 0 then
			break
		end

		-- Manual queued casts fire first.
		if #unit.QueuedCasts > 0 then
			local abilityId = table.remove(unit.QueuedCasts, 1) :: string
			for _, state in unit.Abilities do
				if state.AbilityId == abilityId and state.ReadyAt <= self._time then
					castAbility(self, unit, state, pickTarget(enemies))
					break
				end
			end
		end

		-- Auto casting: strongest ready ability for Auto units; only
		-- the basic Strike for Manual units.
		local bestState: AbilityState? = nil
		local bestPower = -1
		for _, state in unit.Abilities do
			if state.ReadyAt > self._time then
				continue
			end
			local ability = AbilityConfig.Abilities[state.AbilityId]
			local isBasic = state.AbilityId == "Strike"
			if unit.CastPolicy == "Manual" and not isBasic then
				continue
			end
			if ability.Power > bestPower then
				bestPower = ability.Power
				bestState = state
			end
		end
		if bestState ~= nil then
			enemies = aliveEnemies(self, unit.Team)
			if #enemies > 0 then
				castAbility(self, unit, bestState, pickTarget(enemies))
			end
		end
	end

	local aliveA = teamAlive(self, 1)
	local aliveB = teamAlive(self, 2)
	if not aliveA or not aliveB then
		local winner = if aliveA then 1 elseif aliveB then 2 else 0
		finish(self, winner, false)
	elseif self._time >= BattleConfig.MaxDurationSeconds then
		local fractionA = teamHpFraction(self, 1)
		local fractionB = teamHpFraction(self, 2)
		local winner = if fractionA > fractionB then 1 elseif fractionB > fractionA then 2 else 0
		finish(self, winner, true)
	end
end

-- Advances the simulation by dt seconds. Time is quantised into fixed
-- BattleConfig.TickInterval steps with any sub-tick remainder carried
-- forward, so a battle plays out identically whether it is stepped once with
-- a large dt, once per frame with a small dt, or run to completion. Without
-- this, tick cadence (and therefore ability fires and outcomes) would depend
-- on the caller's frame rate.
function BattleSim.step(self: any, dt: number)
	if self._finished then
		return
	end

	self._carry += dt
	-- The epsilon absorbs floating-point error so that, for example, sixty
	-- steps of 1/60 produce exactly ten ticks per second rather than nine.
	local ticks = math.floor(self._carry / BattleConfig.TickInterval + 1e-6)
	if ticks <= 0 then
		return
	end
	self._carry -= ticks * BattleConfig.TickInterval

	for _ = 1, ticks do
		if self._finished then
			break
		end
		runTick(self)
	end
end

-- Runs an entire battle in one call (tests and PvE resolution).
function BattleSim.runToCompletion(self: any): BattleResult
	while not self._finished do
		BattleSim.step(self, 1)
	end
	return self._result :: BattleResult
end

return BattleSim
