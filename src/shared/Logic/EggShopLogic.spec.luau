--!nocheck
return function()
	local EggShopLogic = require(script.Parent.EggShopLogic)
	local EggConfig = require(script.Parent.Parent.Config.EggConfig)
	local PlayerConfig = require(script.Parent.Parent.Config.PlayerConfig)

	local function freshData(coins, gems)
		return {
			Currencies = { Coins = coins or 0, Gems = gems or 0 },
			Eggs = {},
		}
	end

	describe("EggShopLogic.validatePurchase", function()
		it("rejects unknown egg tiers", function()
			local result = EggShopLogic.validatePurchase(freshData(999999, 999999), "Imaginary")
			expect(result.Ok).to.equal(false)
		end)

		it("rejects insufficient Coins", function()
			local price = EggConfig.Tiers.Basic.Price.Amount
			local result = EggShopLogic.validatePurchase(freshData(price - 1, 0), "Basic")
			expect(result.Ok).to.equal(false)
		end)

		it("rejects insufficient Gems", function()
			local price = EggConfig.Tiers.Royal.Price.Amount
			local result = EggShopLogic.validatePurchase(freshData(0, price - 1), "Royal")
			expect(result.Ok).to.equal(false)
		end)

		it("accepts an affordable purchase and reports the exact cost", function()
			local tier = EggConfig.Tiers.Basic
			local result = EggShopLogic.validatePurchase(freshData(tier.Price.Amount, 0), "Basic")
			expect(result.Ok).to.equal(true)
			expect(result.Currency).to.equal("Coins")
			expect(result.Amount).to.equal(tier.Price.Amount)
		end)

		it("rejects purchases when egg storage is full", function()
			local data = freshData(999999, 999999)
			for index = 1, PlayerConfig.MaxStoredEggs do
				data.Eggs["egg" .. index] = { Tier = "Basic" }
			end
			local result = EggShopLogic.validatePurchase(data, "Basic")
			expect(result.Ok).to.equal(false)
		end)
	end)
end
