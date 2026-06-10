--!nocheck
return function()
	local ActiveMythlingLogic = require(script.Parent.ActiveMythlingLogic)

	local data = {
		Mythlings = {
			M1 = { SpeciesId = "Cindercub" },
			M2 = { SpeciesId = "Pebblit" },
			M3 = { SpeciesId = "Dribblet" },
			M4 = { SpeciesId = "Sparkmote" },
		},
	}

	describe("ActiveMythlingLogic.validateRoster", function()
		it("accepts an owned, unique roster within the cap", function()
			local result = ActiveMythlingLogic.validateRoster(data, { "M1", "M2", "M3" }, 3)
			expect(result.Ok).to.equal(true)
		end)

		it("accepts an empty roster", function()
			expect(ActiveMythlingLogic.validateRoster(data, {}, 3).Ok).to.equal(true)
		end)

		it("rejects rosters above the cap", function()
			local result = ActiveMythlingLogic.validateRoster(data, { "M1", "M2", "M3", "M4" }, 3)
			expect(result.Ok).to.equal(false)
		end)

		it("rejects Mythlings the player does not own", function()
			local result = ActiveMythlingLogic.validateRoster(data, { "M1", "Stolen" }, 3)
			expect(result.Ok).to.equal(false)
		end)

		it("rejects duplicate picks", function()
			local result = ActiveMythlingLogic.validateRoster(data, { "M1", "M1" }, 3)
			expect(result.Ok).to.equal(false)
		end)
	end)

	describe("ActiveMythlingLogic.formationOffset", function()
		it("puts the first follower directly behind", function()
			local x, z = ActiveMythlingLogic.formationOffset(1, 5, 3.5)
			expect(x).to.equal(0)
			expect(z).to.equal(5)
		end)

		it("fans later followers out to alternate sides", function()
			local x2 = ActiveMythlingLogic.formationOffset(2, 5, 3.5)
			local x3 = ActiveMythlingLogic.formationOffset(3, 5, 3.5)
			expect(x2 < 0).to.equal(true)
			expect(x3 > 0).to.equal(true)
		end)
	end)
end
