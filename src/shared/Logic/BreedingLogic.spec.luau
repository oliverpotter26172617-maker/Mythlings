--!nocheck
return function()
	local BreedingLogic = require(script.Parent.BreedingLogic)
	local BreedingConfig = require(script.Parent.Parent.Config.BreedingConfig)
	local ElementConfig = require(script.Parent.Parent.Config.ElementConfig)
	local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)

	local function makeRng(seed)
		local state = seed
		return function()
			state = (state * 25214903917 + 11) % 281474976710656
			return state / 281474976710656
		end
	end

	describe("breeding distribution over 100,000 rolls", function()
		local rolls = 100000
		local rng = makeRng(777)
		local parentA = { Element = "Flame", Rarity = "Common", Potential = 40 }
		local parentB = { Element = "Tide", Rarity = "Common", Potential = 80 }

		local elementCounts = {}
		local shinyCount = 0
		local upgradeCount = 0
		local potentialSum = 0
		local potentialOutOfBand = 0

		for _ = 1, rolls do
			local offspring = BreedingLogic.breed(parentA, parentB, MythlingConfig.Species, rng)
			elementCounts[offspring.Element] = (elementCounts[offspring.Element] or 0) + 1
			if offspring.Shiny then
				shinyCount += 1
			end
			if offspring.Rarity ~= "Common" then
				upgradeCount += 1
			end
			potentialSum += offspring.Potential
			local average = (parentA.Potential + parentB.Potential) / 2
			if
				offspring.Potential < average - BreedingConfig.PotentialSwing
				or offspring.Potential > average + BreedingConfig.PotentialSwing
			then
				potentialOutOfBand += 1
			end
		end

		it("weights elements toward the parents within 0.5 percentage points", function()
			local parentShare = BreedingConfig.ParentElementShare / 2
			expect(math.abs(elementCounts.Flame / rolls - parentShare) < 0.005).to.equal(true)
			expect(math.abs(elementCounts.Tide / rolls - parentShare) < 0.005).to.equal(true)
			local otherShare = (1 - BreedingConfig.ParentElementShare) / 4
			for _, element in { "Terra", "Storm", "Shadow", "Radiant" } do
				expect(math.abs((elementCounts[element] or 0) / rolls - otherShare) < 0.005).to.equal(true)
			end
		end)

		it("produces Shiny variants at the configured rate within 0.5 points", function()
			expect(math.abs(shinyCount / rolls - BreedingConfig.ShinyChance) < 0.005).to.equal(true)
		end)

		it("upgrades same-rarity pairs at the configured rate within 0.5 points", function()
			expect(math.abs(upgradeCount / rolls - BreedingConfig.SameRarityUpgradeChance) < 0.005).to.equal(true)
		end)

		it("keeps Potential inside the average plus or minus swing band", function()
			expect(potentialOutOfBand).to.equal(0)
			local mean = potentialSum / rolls
			expect(math.abs(mean - 60) < 1).to.equal(true)
		end)
	end)

	describe("rarity inheritance for mixed parents", function()
		it("takes each parent's rarity about half the time and never upgrades", function()
			local rng = makeRng(31337)
			local rareCount = 0
			local rolls = 50000
			for _ = 1, rolls do
				local rarity = BreedingLogic.rollRarity("Rare", "Epic", rng)
				expect(rarity == "Rare" or rarity == "Epic").to.equal(true)
				if rarity == "Rare" then
					rareCount += 1
				end
			end
			expect(math.abs(rareCount / rolls - 0.5) < 0.01).to.equal(true)
		end)

		it("caps upgrades at Mythic", function()
			local alwaysUpgrade = function()
				return 0
			end
			expect(BreedingLogic.rollRarity("Mythic", "Mythic", alwaysUpgrade)).to.equal("Mythic")
		end)
	end)

	describe("species fallback", function()
		it("falls back to any species at the rarity when the element has none", function()
			-- Mythic has no Flame species in the catalogue.
			local rng = makeRng(5)
			for _ = 1, 200 do
				local speciesId = BreedingLogic.pickSpecies(MythlingConfig.Species, "Mythic", "Flame", rng)
				expect(MythlingConfig.Species[speciesId].Rarity).to.equal("Mythic")
			end
		end)

		it("honours the element when species exist for it", function()
			local rng = makeRng(6)
			for _ = 1, 200 do
				local speciesId = BreedingLogic.pickSpecies(MythlingConfig.Species, "Rare", "Storm", rng)
				expect(MythlingConfig.Species[speciesId].Element).to.equal("Storm")
			end
		end)
	end)

	describe("element roll with matching parents", function()
		it("gives the shared element the full parent share", function()
			local rng = makeRng(9)
			local hits = 0
			local rolls = 50000
			for _ = 1, rolls do
				if BreedingLogic.rollElement("Terra", "Terra", rng) == "Terra" then
					hits += 1
				end
			end
			expect(math.abs(hits / rolls - BreedingConfig.ParentElementShare) < 0.01).to.equal(true)
		end)
	end)

	describe("BreedingLogic.validateBreed", function()
		local function freshData()
			return {
				Eggs = {},
				Mythlings = {
					A = { Stage = "Adult", BreedCooldownUntil = 0 },
					B = { Stage = "Alpha", BreedCooldownUntil = 0 },
					Young = { Stage = "Juvenile", BreedCooldownUntil = 0 },
					Tired = { Stage = "Adult", BreedCooldownUntil = 9999999999 },
				},
			}
		end

		it("accepts two rested Adult+ Mythlings", function()
			expect(BreedingLogic.validateBreed(freshData(), "A", "B", 1000, 12).Ok).to.equal(true)
		end)

		it("rejects self-breeding, juveniles, cooldowns and missing Mythlings", function()
			expect(BreedingLogic.validateBreed(freshData(), "A", "A", 1000, 12).Ok).to.equal(false)
			expect(BreedingLogic.validateBreed(freshData(), "A", "Young", 1000, 12).Ok).to.equal(false)
			expect(BreedingLogic.validateBreed(freshData(), "A", "Tired", 1000, 12).Ok).to.equal(false)
			expect(BreedingLogic.validateBreed(freshData(), "A", "Ghost", 1000, 12).Ok).to.equal(false)
		end)

		it("rejects when egg storage is full", function()
			local data = freshData()
			for index = 1, 12 do
				data.Eggs["egg" .. index] = {}
			end
			expect(BreedingLogic.validateBreed(data, "A", "B", 1000, 12).Ok).to.equal(false)
		end)
	end)

	describe("BreedingLogic.skipCost", function()
		it("is zero when rested and scales per hour with a floor of 1", function()
			expect(BreedingLogic.skipCost(0)).to.equal(0)
			expect(BreedingLogic.skipCost(3600)).to.equal(BreedingConfig.GemSkipPerHour)
			expect(BreedingLogic.skipCost(60)).to.equal(1)
			expect(BreedingLogic.skipCost(6 * 3600)).to.equal(6 * BreedingConfig.GemSkipPerHour)
		end)
	end)

	describe("config sanity", function()
		it("element list covers all parent elements used by species", function()
			local known = {}
			for _, element in ElementConfig.Order do
				known[element] = true
			end
			for _, def in MythlingConfig.Species do
				expect(known[def.Element]).to.equal(true)
			end
		end)
	end)
end
