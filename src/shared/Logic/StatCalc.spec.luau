--!nocheck
return function()
	local StatCalc = require(script.Parent.StatCalc)
	local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)
	local StatConfig = require(script.Parent.Parent.Config.StatConfig)

	describe("StatCalc.compute", function()
		it("matches the config formula exactly for every stage", function()
			local speciesId = "Cindercub"
			local species = MythlingConfig.Species[speciesId]
			local potential = 50
			local scale = StatConfig.PotentialBase + (potential / StatConfig.PotentialMax) * StatConfig.PotentialRange
			local budget = StatConfig.RarityBudgets[species.Rarity]

			for _, stage in StatConfig.StageOrder do
				local stats = StatCalc.compute(speciesId, stage, potential)
				local stageMultiplier = StatConfig.StageMultipliers[stage]
				expect(stats.HP).to.equal(math.ceil(budget * species.Spread.HP * stageMultiplier * scale))
				expect(stats.Attack).to.equal(math.ceil(budget * species.Spread.Attack * stageMultiplier * scale))
				expect(stats.Defence).to.equal(math.ceil(budget * species.Spread.Defence * stageMultiplier * scale))
				expect(stats.Speed).to.equal(math.ceil(budget * species.Spread.Speed * stageMultiplier * scale))
			end
		end)

		it("applies stage multipliers in the configured ratios", function()
			local adult = StatCalc.compute("Pebblit", "Adult", 50)
			local hatchling = StatCalc.compute("Pebblit", "Hatchling", 50)
			local expectedRatio = StatConfig.StageMultipliers.Adult / StatConfig.StageMultipliers.Hatchling
			-- Ceiling rounding allows at most 1 point of drift per stat.
			expect(math.abs(adult.Attack / hatchling.Attack - expectedRatio) < 0.05).to.equal(true)
		end)

		it("scales with Potential within the configured band", function()
			local low = StatCalc.compute("Voltfox", "Adult", StatConfig.PotentialMin)
			local high = StatCalc.compute("Voltfox", "Adult", StatConfig.PotentialMax)
			expect(high.Attack > low.Attack).to.equal(true)
			local maxScale = StatConfig.PotentialBase + StatConfig.PotentialRange
			expect(high.Attack <= math.ceil(low.Attack / StatConfig.PotentialBase * maxScale)).to.equal(true)
		end)

		it("clamps Potential outside the legal range", function()
			local clamped = StatCalc.compute("Cindercub", "Adult", 9999)
			local max = StatCalc.compute("Cindercub", "Adult", StatConfig.PotentialMax)
			expect(clamped.Attack).to.equal(max.Attack)
		end)

		it("computes a positive power score", function()
			local stats = StatCalc.compute("Aetherion", "Alpha", 100)
			expect(StatCalc.power(stats) > 0).to.equal(true)
		end)
	end)
end
