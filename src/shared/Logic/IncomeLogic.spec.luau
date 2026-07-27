--!nocheck
return function()
	local IncomeLogic = require(script.Parent.IncomeLogic)
	local HousingConfig = require(script.Parent.Parent.Config.HousingConfig)

	local function freshData(lastClaim)
		return {
			ActiveMythlings = { "M1", "M2" },
			Mythlings = {
				M1 = { Rarity = "Common", LastFedAt = 0 },
				M2 = { Rarity = "Epic", LastFedAt = 0 },
			},
			Housing = {
				LastIncomeClaimAt = lastClaim or 0,
				VisitBonusDay = 0,
				VisitBonusCount = 0,
				VisitedToday = {},
			},
		}
	end

	describe("IncomeLogic.computeIncome", function()
		it("matches the config rates exactly for one unfed hour", function()
			local data = freshData(1000)
			local expected = HousingConfig.IncomePerHour.Common + HousingConfig.IncomePerHour.Epic
			expect(IncomeLogic.computeIncome(data, 1000 + 3600)).to.equal(expected)
		end)

		it("doubles income for recently fed Mythlings", function()
			local now = 1000 + 3600
			local data = freshData(1000)
			data.Mythlings.M1.LastFedAt = now - 60
			local expected = HousingConfig.IncomePerHour.Common * HousingConfig.FedBonusMultiplier
				+ HousingConfig.IncomePerHour.Epic
			expect(IncomeLogic.computeIncome(data, now)).to.equal(expected)
		end)

		it("caps accrual at the configured hours", function()
			local data = freshData(1000)
			local capped = IncomeLogic.computeIncome(data, 1000 + HousingConfig.MaxAccrualHours * 3600)
			local overnight = IncomeLogic.computeIncome(data, 1000 + 1000 * 3600)
			expect(overnight).to.equal(capped)
		end)

		it("pays nothing for Mythlings no longer owned", function()
			local data = freshData(1000)
			data.Mythlings.M2 = nil
			expect(IncomeLogic.computeIncome(data, 1000 + 3600)).to.equal(HousingConfig.IncomePerHour.Common)
		end)
	end)

	describe("IncomeLogic.claim", function()
		it("cannot pay the same window twice", function()
			local data = freshData(1000)
			local first = IncomeLogic.claim(data, 1000 + 3600)
			expect(first > 0).to.equal(true)
			local second = IncomeLogic.claim(data, 1000 + 3600)
			expect(second).to.equal(0)
		end)

		it("starts the clock on the first ever claim without paying", function()
			local data = freshData(0)
			expect(IncomeLogic.claim(data, 5000)).to.equal(0)
			expect(data.Housing.LastIncomeClaimAt).to.equal(5000)
		end)

		it("keeps the clock when less than a whole coin has accrued", function()
			local data = freshData(1000)
			-- A minute accrues under one coin at these rates, flooring to 0.
			expect(IncomeLogic.claim(data, 1000 + 60)).to.equal(0)
			expect(data.Housing.LastIncomeClaimAt).to.equal(1000)
			-- An hour after the original claim still pays the full hour, so the
			-- earlier sub-coin claim did not discard the accrual.
			local expected = HousingConfig.IncomePerHour.Common + HousingConfig.IncomePerHour.Epic
			expect(IncomeLogic.claim(data, 1000 + 3600)).to.equal(expected)
			expect(data.Housing.LastIncomeClaimAt).to.equal(1000 + 3600)
		end)
	end)

	describe("IncomeLogic.tryRecordHostBonus", function()
		it("pays the host up to the daily cap then stops, resetting daily", function()
			local data = freshData(0)
			local day1 = 86400 * 200
			local paid = 0
			for i = 1, HousingConfig.VisitBonusDailyCap + 3 do
				if IncomeLogic.tryRecordHostBonus(data, day1 + i) then
					paid += 1
				end
			end
			expect(paid).to.equal(HousingConfig.VisitBonusDailyCap)
			-- The next day resets the host's allowance.
			expect(IncomeLogic.tryRecordHostBonus(data, day1 + 86400)).to.equal(true)
		end)
	end)

	describe("IncomeLogic.tryRecordVisit", function()
		it("pays once per friend per day up to the cap, resetting daily", function()
			local data = freshData(0)
			local day1 = 86400 * 100

			expect((IncomeLogic.tryRecordVisit(data, 111, day1))).to.equal(true)
			expect((IncomeLogic.tryRecordVisit(data, 111, day1 + 60))).to.equal(false)

			for friend = 1, HousingConfig.VisitBonusDailyCap - 1 do
				IncomeLogic.tryRecordVisit(data, 1000 + friend, day1 + friend)
			end
			expect((IncomeLogic.tryRecordVisit(data, 9999, day1 + 9999))).to.equal(false)

			-- Next day everything resets, including the same friend.
			expect((IncomeLogic.tryRecordVisit(data, 111, day1 + 86400))).to.equal(true)
		end)
	end)
end
