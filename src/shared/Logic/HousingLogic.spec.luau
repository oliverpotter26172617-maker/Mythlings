--!nocheck
return function()
	local HousingLogic = require(script.Parent.HousingLogic)
	local HousingConfig = require(script.Parent.Parent.Config.HousingConfig)

	describe("HousingLogic.canPlace", function()
		it("accepts a legal placement inside the plot", function()
			expect((HousingLogic.canPlace(1, {}, "Bed", 0, 0, 0))).to.equal(true)
			expect((HousingLogic.canPlace(1, {}, "Bed", -8, -8, 0))).to.equal(true)
		end)

		it("rejects placements outside the plot (exploit test)", function()
			-- Tier 1 spans cells -8..7; these all poke out.
			expect((HousingLogic.canPlace(1, {}, "Bed", 7, 0, 0))).to.equal(false)
			expect((HousingLogic.canPlace(1, {}, "Bed", -9, 0, 0))).to.equal(false)
			expect((HousingLogic.canPlace(1, {}, "Bed", 0, 999, 0))).to.equal(false)
			expect((HousingLogic.canPlace(1, {}, "Bed", 0, -99999, 0))).to.equal(false)
		end)

		it("a placement illegal at tier 1 becomes legal on a bigger plot", function()
			expect((HousingLogic.canPlace(1, {}, "Bed", 10, 0, 0))).to.equal(false)
			expect((HousingLogic.canPlace(4, {}, "Bed", 10, 0, 0))).to.equal(true)
		end)

		it("rejects off-grid coordinates and bad rotations", function()
			expect((HousingLogic.canPlace(1, {}, "Bed", 0.5, 0, 0))).to.equal(false)
			expect((HousingLogic.canPlace(1, {}, "Bed", 0, 0, 45))).to.equal(false)
		end)

		it("rejects unknown furniture", function()
			expect((HousingLogic.canPlace(1, {}, "Spaceship", 0, 0, 0))).to.equal(false)
		end)

		it("rejects overlapping footprints and accepts adjacent ones", function()
			local existing = { g1 = { ItemId = "Bed", X = 0, Z = 0, Rotation = 0 } }
			-- Bed is 2x3 at rotation 0, occupying x 0..1, z 0..2.
			expect((HousingLogic.canPlace(1, existing, "Bowl", 1, 2, 0))).to.equal(false)
			expect((HousingLogic.canPlace(1, existing, "Bowl", 2, 0, 0))).to.equal(true)
			expect((HousingLogic.canPlace(1, existing, "Bowl", 0, 3, 0))).to.equal(true)
		end)

		it("rotation swaps the footprint axes", function()
			-- Bench is 3x1; at 90 degrees it becomes 1x3.
			local existing = { g1 = { ItemId = "Bench", X = 0, Z = 0, Rotation = 90 } }
			expect((HousingLogic.canPlace(1, existing, "Bowl", 0, 2, 0))).to.equal(false)
			expect((HousingLogic.canPlace(1, existing, "Bowl", 1, 1, 0))).to.equal(true)
		end)

		it("enforces the furniture cap for the tier", function()
			local existing = {}
			for index = 1, HousingConfig.MaxFurniture[1] do
				existing["g" .. index] = { ItemId = "Lantern", X = -8 + index, Z = -8, Rotation = 0 }
			end
			expect((HousingLogic.canPlace(1, existing, "Bowl", 0, 5, 0))).to.equal(false)
		end)
	end)

	describe("plot upgrades", function()
		it("validates funds and the top tier", function()
			local data =
				{ Housing = { PlotTier = 1 }, Currencies = { Coins = HousingConfig.PlotTiers[2].UpgradeCoins } }
			local ok, _, cost = HousingLogic.validateUpgrade(data)
			expect(ok).to.equal(true)
			expect(cost).to.equal(HousingConfig.PlotTiers[2].UpgradeCoins)

			data.Currencies.Coins = 1
			expect((HousingLogic.validateUpgrade(data))).to.equal(false)

			data.Housing.PlotTier = #HousingConfig.PlotTiers
			data.Currencies.Coins = 999999999
			expect((HousingLogic.validateUpgrade(data))).to.equal(false)
		end)
	end)

	describe("theme purchases", function()
		it("validates Gems, ownership and VIP exclusivity", function()
			local data = { Housing = { PlotTier = 1, OwnedThemes = {} }, Currencies = { Gems = 9999 } }
			expect((HousingLogic.validateThemePurchase(data, "Castle"))).to.equal(true)
			expect((HousingLogic.validateThemePurchase(data, "CloudIsle"))).to.equal(false)
			expect((HousingLogic.validateThemePurchase(data, "Imaginary"))).to.equal(false)

			data.Housing.OwnedThemes.Castle = true
			expect((HousingLogic.validateThemePurchase(data, "Castle"))).to.equal(false)

			data.Currencies.Gems = 0
			expect((HousingLogic.validateThemePurchase(data, "Treehouse"))).to.equal(false)
		end)
	end)
end
