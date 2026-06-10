--!nocheck
return function()
	local MonetisationLogic = require(script.Parent.MonetisationLogic)
	local MonetisationConfig = require(script.Parent.Parent.Config.MonetisationConfig)

	describe("MonetisationLogic.applyReceiptOnce", function()
		it("grants exactly once for replayed receipts", function()
			local data = { PurchaseLedger = {} }
			local grants = 0
			local grant = function()
				grants += 1
			end

			expect(MonetisationLogic.applyReceiptOnce(data, "r-1", 1000, grant)).to.equal(true)
			expect(MonetisationLogic.applyReceiptOnce(data, "r-1", 1001, grant)).to.equal(false)
			expect(MonetisationLogic.applyReceiptOnce(data, "r-1", 1002, grant)).to.equal(false)
			expect(grants).to.equal(1)
			expect(data.PurchaseLedger["r-1"]).to.equal(1000)
		end)

		it("treats different receipts independently", function()
			local data = { PurchaseLedger = {} }
			local grants = 0
			local grant = function()
				grants += 1
			end
			MonetisationLogic.applyReceiptOnce(data, "r-1", 1, grant)
			MonetisationLogic.applyReceiptOnce(data, "r-2", 2, grant)
			expect(grants).to.equal(2)
		end)

		it("records the ledger entry even if the grant errors", function()
			local data = { PurchaseLedger = {} }
			pcall(function()
				MonetisationLogic.applyReceiptOnce(data, "r-bad", 5, function()
					error("boom")
				end)
			end)
			expect(data.PurchaseLedger["r-bad"]).to.equal(5)
		end)
	end)

	describe("pass benefits", function()
		it("VIP multiplies coin sources by the configured rate", function()
			expect(MonetisationLogic.coinMultiplier({})).to.equal(1)
			expect(MonetisationLogic.coinMultiplier({ VIP = true })).to.equal(MonetisationConfig.VipCoinMultiplier)
		end)

		it("HatchSpeed divides incubation time", function()
			expect(MonetisationLogic.hatchSeconds(3000, {})).to.equal(3000)
			expect(MonetisationLogic.hatchSeconds(3000, { HatchSpeed = true })).to.equal(
				math.ceil(3000 / MonetisationConfig.HatchSpeedMultiplier)
			)
		end)

		it("VIP stipend is due once per UTC day", function()
			local data = { Passes = { VIP = true }, Flags = { LastVipStipendDay = 0 } }
			expect(MonetisationLogic.vipStipendDue(data, 86400 * 100)).to.equal(true)
			data.Flags.LastVipStipendDay = MonetisationLogic.dayStamp(86400 * 100)
			expect(MonetisationLogic.vipStipendDue(data, 86400 * 100 + 3600)).to.equal(false)
			expect(MonetisationLogic.vipStipendDue({ Passes = {}, Flags = {} }, 86400 * 100)).to.equal(false)
		end)
	end)
end
