--!nocheck
return function()
	local ProfileSanitiser = require(script.Parent.ProfileSanitiser)

	describe("ProfileSanitiser.sanitise", function()
		local data = {
			Currencies = { Coins = 100 },
			Mythlings = {
				M1 = { SpeciesId = "Cindercub", Potential = 87, Rarity = "Common" },
			},
			MigrationBackups = { v2 = { Old = true } },
			PurchaseLedger = { ["receipt-1"] = 123 },
		}
		local snapshot = ProfileSanitiser.sanitise(data)

		it("strips server bookkeeping sections", function()
			expect(snapshot.MigrationBackups).to.equal(nil)
			expect(snapshot.PurchaseLedger).to.equal(nil)
		end)

		it("redacts hidden Potential from every Mythling", function()
			expect(snapshot.Mythlings.M1.Potential).to.equal(nil)
			expect(snapshot.Mythlings.M1.SpeciesId).to.equal("Cindercub")
		end)

		it("does not mutate the source profile", function()
			expect(data.Mythlings.M1.Potential).to.equal(87)
			expect(data.MigrationBackups.v2.Old).to.equal(true)
		end)

		it("deep copies so later edits cannot leak", function()
			snapshot.Currencies.Coins = 999
			expect(data.Currencies.Coins).to.equal(100)
		end)
	end)
end
