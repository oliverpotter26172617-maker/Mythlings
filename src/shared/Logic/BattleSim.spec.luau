--!nocheck
return function()
	local BattleSim = require(script.Parent.BattleSim)
	local BattleConfig = require(script.Parent.Parent.Config.BattleConfig)
	local AbilityConfig = require(script.Parent.Parent.Config.AbilityConfig)
	local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)
	local StatCalc = require(script.Parent.StatCalc)
	local ElementConfig = require(script.Parent.Parent.Config.ElementConfig)

	local function makeRng(seed)
		local state = seed
		return function()
			state = (state * 25214903917 + 11) % 281474976710656
			return state / 281474976710656
		end
	end

	local speciesIds = {}
	for id in MythlingConfig.Species do
		table.insert(speciesIds, id)
	end
	table.sort(speciesIds)

	local stages = { "Juvenile", "Adult", "Adult", "Alpha" }

	local function randomTeam(rng, prefix)
		local team = {}
		for slot = 1, 3 do
			local speciesId = speciesIds[1 + math.floor(rng() * #speciesIds)]
			local species = MythlingConfig.Species[speciesId]
			local stage = stages[1 + math.floor(rng() * #stages)]
			local potential = 1 + math.floor(rng() * 100)
			table.insert(team, {
				Id = `{prefix}{slot}`,
				Element = species.Element,
				Stats = StatCalc.compute(speciesId, stage, potential),
				Abilities = AbilityConfig.loadout(species.Element, stage),
			})
		end
		return team
	end

	describe("element wheel", function()
		it("gives +25% only on advantage", function()
			expect(BattleSim.elementModifier("Flame", "Terra")).to.equal(BattleConfig.AdvantageMultiplier)
			expect(BattleSim.elementModifier("Terra", "Flame")).to.equal(1)
			expect(BattleSim.elementModifier("Shadow", "Radiant")).to.equal(BattleConfig.AdvantageMultiplier)
			expect(BattleSim.elementModifier("Radiant", "Shadow")).to.equal(BattleConfig.AdvantageMultiplier)
			expect(BattleSim.elementModifier(nil, "Flame")).to.equal(1)
		end)

		it("covers every element with exactly one advantage", function()
			for _, element in ElementConfig.Order do
				local beats = BattleConfig.Wheel[element]
				expect(beats).to.be.a("table")
				local count = 0
				for _ in beats do
					count += 1
				end
				expect(count).to.equal(1)
			end
		end)
	end)

	describe("damage formula", function()
		it("matches the locked formula exactly", function()
			local atk, def = 150, 90
			local expected = math.floor((atk * atk) / (atk + def) * 1.6 * 1.25 * 0.95)
			expect(BattleSim.damage(atk, def, 1.6, 1.25, 0.95)).to.equal(expected)
		end)
		it("never deals less than 1", function()
			expect(BattleSim.damage(1, 1000, 0.1, 1, 0.9)).to.equal(1)
		end)
	end)

	describe("manual cast policy", function()
		it("only auto-fires Strike and accepts queued ability casts", function()
			local rng = makeRng(5)
			local team = randomTeam(rng, "A")
			for _, unit in team do
				unit.CastPolicy = "Manual"
				unit.Stats = { HP = 500, Attack = 100, Defence = 100, Speed = 100 }
				unit.Abilities = { "Strike", "FlameBolt" }
				unit.Element = "Flame"
			end
			local enemy = randomTeam(rng, "B")
			local sim = BattleSim.new(team, enemy, rng)

			local function teamABoltUsed()
				for _, event in sim:getEvents() do
					if event.AbilityId == "FlameBolt" and string.sub(event.Attacker or "", 1, 1) == "A" then
						return true
					end
				end
				return false
			end

			sim:step(1)
			expect(teamABoltUsed()).to.equal(false)

			local ok = sim:queueCast("A1", "FlameBolt")
			expect(ok).to.equal(true)
			sim:step(0.2)
			expect(teamABoltUsed()).to.equal(true)
		end)

		it("rejects casts for unknown units or unowned abilities", function()
			local rng = makeRng(6)
			local sim = BattleSim.new(randomTeam(rng, "A"), randomTeam(rng, "B"), rng)
			expect((sim:queueCast("Ghost", "Strike"))).to.equal(false)
			expect((sim:queueCast("A1", "VoidBeam"))).to.equal(false)
		end)
	end)

	describe("1,000 simulated battles", function()
		it("complete with zero errors and a median duration of 90 to 180 seconds", function()
			local rng = makeRng(123456789)
			local durations = {}
			local winners = { [0] = 0, [1] = 0, [2] = 0 }

			for _ = 1, 1000 do
				local sim = BattleSim.new(randomTeam(rng, "A"), randomTeam(rng, "B"), rng)
				local result = sim:runToCompletion()
				expect(result).to.be.ok()
				expect(result.Duration > 0).to.equal(true)
				winners[result.Winner] += 1
				table.insert(durations, result.Duration)
			end

			table.sort(durations)
			local median = durations[500]
			expect(median >= 90).to.equal(true)
			expect(median <= 180).to.equal(true)

			-- Both sides must be able to win a random matchup.
			expect(winners[1] > 100).to.equal(true)
			expect(winners[2] > 100).to.equal(true)
		end)
	end)

	describe("timeout handling", function()
		it("awards the higher HP fraction team at the cap", function()
			-- Two tanks that cannot meaningfully hurt each other quickly.
			local tank = {
				Id = "T1",
				Element = "Terra",
				Stats = { HP = 5000, Attack = 10, Defence = 5000, Speed = 1 },
				Abilities = { "Strike" },
			}
			local tank2 = table.clone(tank)
			tank2.Id = "T2"
			tank2.Stats = { HP = 5200, Attack = 9, Defence = 5000, Speed = 1 }
			local sim = BattleSim.new({ tank }, { tank2 }, makeRng(1))
			local result = sim:runToCompletion()
			expect(result.TimedOut).to.equal(true)
			expect(result.Duration).to.equal(BattleConfig.MaxDurationSeconds)
		end)
	end)
end
