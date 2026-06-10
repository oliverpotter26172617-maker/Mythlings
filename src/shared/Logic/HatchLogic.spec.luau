--!nocheck
return function()
	local HatchLogic = require(script.Parent.HatchLogic)
	local EggConfig = require(script.Parent.Parent.Config.EggConfig)
	local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)
	local RarityConfig = require(script.Parent.Parent.Config.RarityConfig)
	local StatConfig = require(script.Parent.Parent.Config.StatConfig)

	-- Deterministic LCG so the simulation is identical on every run.
	local function makeRng(seed)
		local state = seed
		return function()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
	end

	local function isEpicPlus(rarity)
		return RarityConfig.IndexByName[rarity] >= RarityConfig.IndexByName[EggConfig.PityMinRarity]
	end

	describe("HatchLogic.rollWeighted", function()
		it("respects weights deterministically", function()
			local always = HatchLogic.rollWeighted({ OnlyOption = 5 }, makeRng(1))
			expect(always).to.equal("OnlyOption")
		end)

		it("distributes according to the odds over many rolls", function()
			local rng = makeRng(42)
			local odds = EggConfig.Tiers.Basic.Odds
			local counts = {}
			local rolls = 100000
			for _ = 1, rolls do
				local rarity = HatchLogic.rollWeighted(odds, rng)
				counts[rarity] = (counts[rarity] or 0) + 1
			end
			-- Within 1 percentage point of config for the big buckets.
			expect(math.abs(counts.Common / rolls * 100 - odds.Common) < 1).to.equal(true)
			expect(math.abs(counts.Uncommon / rolls * 100 - odds.Uncommon) < 1).to.equal(true)
			expect(math.abs(counts.Rare / rolls * 100 - odds.Rare) < 1).to.equal(true)
		end)
	end)

	describe("pity system", function()
		it("forces Epic or better exactly at the threshold when unlucky", function()
			-- rng of 0 always lands on the lowest sorted key, which is
			-- Common for Basic eggs, so pity must rescue the run.
			local zeroRng = function()
				return 0
			end
			local pity = 0
			for hatch = 1, EggConfig.PityThreshold do
				local rarity, triggered = HatchLogic.rollRarity(
					EggConfig.Tiers.Basic.Odds,
					pity,
					EggConfig.PityThreshold,
					EggConfig.PityMinRarity,
					zeroRng
				)
				if hatch < EggConfig.PityThreshold then
					expect(rarity).to.equal("Common")
					expect(triggered).to.equal(false)
					pity += 1
				else
					expect(isEpicPlus(rarity)).to.equal(true)
					expect(triggered).to.equal(true)
				end
			end
		end)

		it("guarantees Epic+ within the threshold across a 10,000 hatch simulation", function()
			local rng = makeRng(2026)
			local pity = 0
			local gap = 0
			local maxGap = 0
			local epicPlusCount = 0

			for _ = 1, 10000 do
				local result = HatchLogic.hatch({
					Odds = EggConfig.Tiers.Basic.Odds,
					ElementBias = nil,
					BiasWeight = EggConfig.ElementBiasWeight,
					Catalogue = MythlingConfig.Species,
					PityCount = pity,
					PityThreshold = EggConfig.PityThreshold,
					PityMinRarity = EggConfig.PityMinRarity,
					PotentialMin = StatConfig.PotentialMin,
					PotentialMax = StatConfig.PotentialMax,
					Rng = rng,
				})
				pity = result.NewPityCount
				if isEpicPlus(result.Rarity) then
					gap = 0
					epicPlusCount += 1
				else
					gap += 1
					expect(gap < EggConfig.PityThreshold).to.equal(true)
				end
				maxGap = math.max(maxGap, gap)
				expect(result.Potential >= StatConfig.PotentialMin).to.equal(true)
				expect(result.Potential <= StatConfig.PotentialMax).to.equal(true)
				expect(MythlingConfig.Species[result.SpeciesId]).to.be.ok()
				expect(MythlingConfig.Species[result.SpeciesId].Rarity).to.equal(result.Rarity)
			end

			-- Basic eggs are 5% Epic+, so 10,000 hatches must produce plenty.
			expect(epicPlusCount > 300).to.equal(true)
			expect(maxGap < EggConfig.PityThreshold).to.equal(true)
		end)

		it("resets the counter on a natural Epic+", function()
			local result = HatchLogic.hatch({
				Odds = { Epic = 100 },
				ElementBias = nil,
				BiasWeight = 0.5,
				Catalogue = MythlingConfig.Species,
				PityCount = 30,
				PityThreshold = 50,
				PityMinRarity = "Epic",
				PotentialMin = 1,
				PotentialMax = 100,
				Rng = makeRng(7),
			})
			expect(result.NewPityCount).to.equal(0)
			expect(result.PityTriggered).to.equal(false)
		end)
	end)

	describe("element bias", function()
		it("steers around the configured share towards the biased element", function()
			local rng = makeRng(99)
			local hits = 0
			local rolls = 20000
			for _ = 1, rolls do
				local speciesId = HatchLogic.pickSpecies(MythlingConfig.Species, "Common", "Terra", 0.5, rng)
				if MythlingConfig.Species[speciesId].Element == "Terra" then
					hits += 1
				end
			end
			local share = hits / rolls
			expect(math.abs(share - 0.5) < 0.02).to.equal(true)
		end)
	end)

	describe("HatchLogic.instantFinishCost", function()
		it("is zero when the egg is already done", function()
			expect(HatchLogic.instantFinishCost(0, 0.4)).to.equal(0)
			expect(HatchLogic.instantFinishCost(-5, 0.4)).to.equal(0)
		end)
		it("scales with minutes remaining", function()
			expect(HatchLogic.instantFinishCost(600, 0.4)).to.equal(4)
			expect(HatchLogic.instantFinishCost(720 * 60, 0.4)).to.equal(288)
		end)
		it("never costs less than one Gem when time remains", function()
			expect(HatchLogic.instantFinishCost(10, 0.4)).to.equal(1)
		end)
	end)

	describe("MythlingFactory", function()
		local MythlingFactory = require(script.Parent.MythlingFactory)
		it("creates a Hatchling record with species data", function()
			local record = MythlingFactory.create({ SpeciesId = "Cindercub", Potential = 55, Now = 1000 })
			expect(record.Stage).to.equal("Hatchling")
			expect(record.Element).to.equal("Flame")
			expect(record.Rarity).to.equal("Common")
			expect(record.Shiny).to.equal(false)
			expect(record.Xp).to.equal(0)
		end)
		it("rejects unknown species", function()
			expect(function()
				MythlingFactory.create({ SpeciesId = "NotReal", Potential = 1, Now = 0 })
			end).to.throw()
		end)
	end)
end
