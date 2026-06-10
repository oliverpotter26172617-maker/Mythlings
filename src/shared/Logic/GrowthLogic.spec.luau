--!nocheck
return function()
	local GrowthLogic = require(script.Parent.GrowthLogic)
	local GrowthConfig = require(script.Parent.Parent.Config.GrowthConfig)

	describe("GrowthLogic.stageForXp", function()
		it("maps cumulative XP to the configured stage", function()
			expect(GrowthLogic.stageForXp(0)).to.equal("Hatchling")
			expect(GrowthLogic.stageForXp(GrowthConfig.StageThresholds.Juvenile)).to.equal("Juvenile")
			expect(GrowthLogic.stageForXp(GrowthConfig.StageThresholds.Adult)).to.equal("Adult")
			expect(GrowthLogic.stageForXp(GrowthConfig.StageThresholds.Alpha + 5000)).to.equal("Alpha")
		end)
	end)

	describe("GrowthLogic.addXp", function()
		it("accumulates XP without a stage change below the threshold", function()
			local result = GrowthLogic.addXp(0, "Hatchling", GrowthConfig.StageThresholds.Juvenile - 1)
			expect(result.NewStage).to.equal("Hatchling")
			expect(#result.StagesGained).to.equal(0)
		end)

		it("advances one stage at the threshold", function()
			local result = GrowthLogic.addXp(0, "Hatchling", GrowthConfig.StageThresholds.Juvenile)
			expect(result.NewStage).to.equal("Juvenile")
			expect(#result.StagesGained).to.equal(1)
		end)

		it("reports every stage passed in one large grant, in order", function()
			local result = GrowthLogic.addXp(0, "Hatchling", GrowthConfig.StageThresholds.Alpha)
			expect(result.NewStage).to.equal("Alpha")
			expect(#result.StagesGained).to.equal(3)
			expect(result.StagesGained[1]).to.equal("Juvenile")
			expect(result.StagesGained[2]).to.equal("Adult")
			expect(result.StagesGained[3]).to.equal("Alpha")
		end)

		it("never moves backwards from the current stage", function()
			local result = GrowthLogic.addXp(GrowthConfig.StageThresholds.Alpha, "Alpha", 10)
			expect(result.NewStage).to.equal("Alpha")
			expect(#result.StagesGained).to.equal(0)
		end)

		it("rejects negative XP", function()
			expect(function()
				GrowthLogic.addXp(0, "Hatchling", -5)
			end).to.throw()
		end)
	end)

	describe("GrowthLogic.validateFoodPurchase", function()
		local function freshData(coins, gems)
			return { Currencies = { Coins = coins or 0, Gems = gems or 0 } }
		end

		it("accepts an affordable purchase with the exact total", function()
			local price = GrowthConfig.Food.Berry.Price.Amount
			local result = GrowthLogic.validateFoodPurchase(freshData(price * 3, 0), "Berry", 3)
			expect(result.Ok).to.equal(true)
			expect(result.Amount).to.equal(price * 3)
		end)

		it("rejects unknown food, bad quantities and short funds", function()
			expect(GrowthLogic.validateFoodPurchase(freshData(99999), "Gravel", 1).Ok).to.equal(false)
			expect(GrowthLogic.validateFoodPurchase(freshData(99999), "Berry", 0).Ok).to.equal(false)
			expect(GrowthLogic.validateFoodPurchase(freshData(99999), "Berry", 2.5).Ok).to.equal(false)
			expect(GrowthLogic.validateFoodPurchase(freshData(99999), "Berry", GrowthConfig.MaxFoodPerPurchase + 1).Ok).to.equal(
				false
			)
			expect(GrowthLogic.validateFoodPurchase(freshData(10), "Berry", 1).Ok).to.equal(false)
		end)
	end)
end
