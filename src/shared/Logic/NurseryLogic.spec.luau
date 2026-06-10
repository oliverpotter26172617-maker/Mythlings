--!nocheck
return function()
	local NurseryLogic = require(script.Parent.NurseryLogic)
	local NurseryConfig = require(script.Parent.Parent.Config.NurseryConfig)
	local EggConfig = require(script.Parent.Parent.Config.EggConfig)
	local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)
	local MythlingFactory = require(script.Parent.MythlingFactory)
	local StatCalc = require(script.Parent.StatCalc)
	local StatConfig = require(script.Parent.Parent.Config.StatConfig)

	describe("free-path availability (build-failing guardrail)", function()
		it("every Nursery species is obtainable from the Mythic egg", function()
			local pools = {}
			for _, speciesId in NurseryConfig.EpicPool do
				table.insert(pools, speciesId)
			end
			for _, speciesId in NurseryConfig.LegendaryPool do
				table.insert(pools, speciesId)
			end
			for _, speciesId in pools do
				local species = MythlingConfig.Species[speciesId]
				expect(species).to.be.ok()
				-- The Mythic egg picks species purely by rolled rarity, so a
				-- positive rarity weight means this species drops for free.
				expect(EggConfig.Tiers.Mythic.Odds[species.Rarity] > 0).to.equal(true)
			end
		end)
	end)

	describe("stat ceiling enforcement", function()
		it("a Nursery Mythling can never exceed the free-path stat ceiling", function()
			-- Nursery purchases go through the same factory and stat
			-- formula; the ceiling is the species at max Potential.
			local record = MythlingFactory.create({ SpeciesId = "Infernyx", Potential = 100, Now = 0 })
			local ceiling = StatCalc.compute("Infernyx", "Alpha", StatConfig.PotentialMax)
			local bought = StatCalc.compute(record.SpeciesId, "Alpha", record.Potential)
			expect(bought.Attack <= ceiling.Attack).to.equal(true)
			expect(bought.HP <= ceiling.HP).to.equal(true)
			-- And the record has no stat fields of its own to inflate.
			expect(record.Stats).to.equal(nil)
			expect(record.Attack).to.equal(nil)
		end)
	end)

	describe("weekly rotation", function()
		it("returns the configured number of offers with prices", function()
			local offers = NurseryLogic.offersForWeek(0)
			expect(#offers).to.equal(NurseryConfig.EpicsPerWeek + NurseryConfig.LegendariesPerWeek)
			for _, offer in offers do
				expect(offer.PriceGems > 0).to.equal(true)
				expect(MythlingConfig.Species[offer.SpeciesId]).to.be.ok()
			end
		end)

		it("rotates offers between consecutive weeks deterministically", function()
			local week0 = NurseryLogic.offersForWeek(0)
			local week1 = NurseryLogic.offersForWeek(1)
			expect(week0[1].SpeciesId).never.to.equal(week1[1].SpeciesId)
			local again = NurseryLogic.offersForWeek(0)
			expect(again[1].SpeciesId).to.equal(week0[1].SpeciesId)
		end)

		it("only ever offers Epic or Legendary species", function()
			for week = 0, 11 do
				for _, offer in NurseryLogic.offersForWeek(week) do
					expect(offer.Rarity == "Epic" or offer.Rarity == "Legendary").to.equal(true)
				end
			end
		end)
	end)

	describe("purchase validation", function()
		local offers = NurseryLogic.offersForWeek(0)

		it("accepts an affordable purchase", function()
			local data = { Mythlings = {}, Currencies = { Gems = 99999 } }
			local result = NurseryLogic.validatePurchase(data, offers, 1, 50)
			expect(result.Ok).to.equal(true)
			expect(result.Offer.SpeciesId).to.equal(offers[1].SpeciesId)
		end)

		it("rejects bad offer indexes, short Gems and full storage", function()
			local rich = { Mythlings = {}, Currencies = { Gems = 99999 } }
			expect(NurseryLogic.validatePurchase(rich, offers, 99, 50).Ok).to.equal(false)

			local poor = { Mythlings = {}, Currencies = { Gems = 1 } }
			expect(NurseryLogic.validatePurchase(poor, offers, 1, 50).Ok).to.equal(false)

			local full = { Mythlings = {}, Currencies = { Gems = 99999 } }
			for index = 1, 50 do
				full.Mythlings["M" .. index] = {}
			end
			expect(NurseryLogic.validatePurchase(full, offers, 1, 50).Ok).to.equal(false)
		end)
	end)
end
