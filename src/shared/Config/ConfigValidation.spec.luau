--!nocheck
-- Build-failing config invariants. If a designer edits a config into an
-- illegal state, this spec stops the commit.
return function()
	local EggConfig = require(script.Parent.EggConfig)
	local MythlingConfig = require(script.Parent.MythlingConfig)
	local RarityConfig = require(script.Parent.RarityConfig)
	local StatConfig = require(script.Parent.StatConfig)

	describe("EggConfig odds tables", function()
		it("sum to exactly 100 for every tier", function()
			for _, tier in EggConfig.Tiers do
				local total = 0
				for _, weight in tier.Odds do
					total += weight
				end
				expect(math.abs(total - 100) < 1e-9).to.equal(true)
			end
		end)

		it("only reference known rarities", function()
			for _, tier in EggConfig.Tiers do
				for rarity in tier.Odds do
					expect(RarityConfig.IndexByName[rarity]).to.be.a("number")
				end
			end
		end)

		it("every tier can honour the pity guarantee", function()
			local minIndex = RarityConfig.IndexByName[EggConfig.PityMinRarity]
			for _, tier in EggConfig.Tiers do
				local epicPlus = 0
				for rarity, weight in tier.Odds do
					if RarityConfig.IndexByName[rarity] >= minIndex then
						epicPlus += weight
					end
				end
				expect(epicPlus > 0).to.equal(true)
			end
		end)

		it("prices use known currencies and positive amounts", function()
			for _, tier in EggConfig.Tiers do
				expect(tier.Price.Currency == "Coins" or tier.Price.Currency == "Gems").to.equal(true)
				expect(tier.Price.Amount > 0).to.equal(true)
				expect(tier.HatchMinutes > 0).to.equal(true)
			end
		end)
	end)

	describe("MythlingConfig species", function()
		it("stat spreads sum to 1", function()
			for _, def in MythlingConfig.Species do
				local spread = def.Spread
				local total = spread.HP + spread.Attack + spread.Defence + spread.Speed
				expect(math.abs(total - 1) < 1e-9).to.equal(true)
			end
		end)

		it("use known rarities and budgets exist for each", function()
			for _, def in MythlingConfig.Species do
				expect(RarityConfig.IndexByName[def.Rarity]).to.be.a("number")
				expect(StatConfig.RarityBudgets[def.Rarity]).to.be.a("number")
			end
		end)

		it("every rarity a hatch can produce has at least one species", function()
			local available = {}
			for _, def in MythlingConfig.Species do
				available[def.Rarity] = true
			end
			for _, tier in EggConfig.Tiers do
				for rarity, weight in tier.Odds do
					if weight > 0 then
						expect(available[rarity]).to.equal(true)
					end
				end
			end
		end)

		it("every element bias points at a real element with species", function()
			local elements = {}
			for _, def in MythlingConfig.Species do
				elements[def.Element] = true
			end
			for _, tier in EggConfig.Tiers do
				if tier.ElementBias ~= nil then
					expect(elements[tier.ElementBias]).to.equal(true)
				end
			end
		end)
	end)
end
