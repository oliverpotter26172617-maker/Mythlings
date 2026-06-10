--!nocheck
return function()
	local RaidLogic = require(script.Parent.RaidLogic)
	local RaidConfig = require(script.Parent.Parent.Config.RaidConfig)
	local BattleSim = require(script.Parent.BattleSim)
	local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)
	local AbilityConfig = require(script.Parent.Parent.Config.AbilityConfig)
	local StatCalc = require(script.Parent.StatCalc)

	local function makeRng(seed)
		local state = seed
		return function()
			state = (state * 25214903917 + 11) % 281474976710656
			return state / 281474976710656
		end
	end

	describe("weekly rotation", function()
		it("is deterministic and cycles through every boss", function()
			local seen = {}
			for week = 0, #RaidConfig.Bosses - 1 do
				local boss = RaidLogic.bossForWeek(week)
				expect(seen[boss.Id]).to.equal(nil)
				seen[boss.Id] = true
			end
			expect(RaidLogic.bossForWeek(0).Id).to.equal(RaidLogic.bossForWeek(#RaidConfig.Bosses).Id)
		end)

		it("derives the same boss for any time inside one week", function()
			local weekStart = 1000 * 7 * 24 * 3600
			expect(RaidLogic.bossFor(weekStart).Id).to.equal(RaidLogic.bossFor(weekStart + 6 * 24 * 3600).Id)
		end)
	end)

	describe("chest rolls", function()
		it("returns the configured number of drops", function()
			local drops = RaidLogic.rollChest(makeRng(1))
			expect(#drops).to.equal(RaidConfig.ChestRolls)
		end)

		it("matches the configured weights over 50,000 chests", function()
			local rng = makeRng(2025)
			local counts = {}
			local chests = 50000
			local totalWeight = 0
			for _, entry in RaidConfig.LootTable do
				totalWeight += entry.Weight
			end

			for _ = 1, chests do
				for _, drop in RaidLogic.rollChest(rng) do
					local key = `{drop.Type}:{tostring(drop.Id)}`
					counts[key] = (counts[key] or 0) + 1
				end
			end

			local totalDrops = chests * RaidConfig.ChestRolls
			for _, entry in RaidConfig.LootTable do
				local key = `{entry.Type}:{tostring(entry.Id)}`
				local expected = entry.Weight / totalWeight
				local actual = (counts[key] or 0) / totalDrops
				expect(math.abs(actual - expected) < 0.005).to.equal(true)
			end
		end)
	end)

	describe("boss battles", function()
		local function adultTeam(rng, prefix)
			local speciesIds = {}
			for id, def in MythlingConfig.Species do
				if def.Rarity ~= "Mythic" and def.Rarity ~= "Legendary" then
					table.insert(speciesIds, id)
				end
			end
			table.sort(speciesIds)
			local team = {}
			for slot = 1, 3 do
				local speciesId = speciesIds[1 + math.floor(rng() * #speciesIds)]
				local species = MythlingConfig.Species[speciesId]
				table.insert(team, {
					Id = `{prefix}{slot}`,
					Element = species.Element,
					Stats = StatCalc.compute(speciesId, "Adult", 50),
					Abilities = AbilityConfig.loadout(species.Element, "Adult"),
				})
			end
			return team
		end

		it("a four player party usually clears the weekly boss", function()
			local rng = makeRng(99)
			local wins = 0
			for _ = 1, 30 do
				local party = {}
				for member = 1, 4 do
					for _, unit in adultTeam(rng, `P{member}U`) do
						table.insert(party, unit)
					end
				end
				local sim = BattleSim.new(party, { RaidLogic.bossUnitSpec(0) }, rng)
				local result = sim:runToCompletion()
				if result.Winner == 1 then
					wins += 1
				end
			end
			expect(wins >= 20).to.equal(true)
		end)

		it("the boss unit spec uses real abilities", function()
			local spec = RaidLogic.bossUnitSpec(os.time and os.time() or 0)
			for _, abilityId in spec.Abilities do
				expect(AbilityConfig.Abilities[abilityId]).to.be.ok()
			end
		end)
	end)
end
