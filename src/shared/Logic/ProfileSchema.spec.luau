--!nocheck
return function()
	local ProfileSchema = require(script.Parent.ProfileSchema)

	describe("ProfileSchema.buildTemplate", function()
		it("returns fresh table identities per call", function()
			local a = ProfileSchema.buildTemplate()
			local b = ProfileSchema.buildTemplate()
			expect(a).never.to.equal(b)
			a.Currencies.Coins = 999999
			expect(b.Currencies.Coins).never.to.equal(999999)
		end)

		it("contains every top-level section from the locked spec", function()
			local template = ProfileSchema.buildTemplate()
			for _, field in
				{
					"Currencies",
					"Mythlings",
					"Eggs",
					"Inventory",
					"Housing",
					"Cosmetics",
					"Stats",
					"PityCounters",
					"Passes",
					"Settings",
					"PurchaseLedger",
					"MigrationBackups",
				}
			do
				expect(template[field]).to.be.a("table")
			end
			expect(template.SchemaVersion).to.equal(ProfileSchema.CURRENT_VERSION)
		end)
	end)

	describe("ProfileSchema.runMigrations", function()
		it("applies pending migrations in order and stamps the version", function()
			local order = {}
			local migrations = {
				[2] = function(data)
					table.insert(order, 2)
					data.A = true
				end,
				[3] = function(data)
					table.insert(order, 3)
					data.B = true
				end,
			}
			local data = { SchemaVersion = 1 }
			local applied = ProfileSchema.runMigrations(data, migrations, 3)
			expect(#applied).to.equal(2)
			expect(order[1]).to.equal(2)
			expect(order[2]).to.equal(3)
			expect(data.SchemaVersion).to.equal(3)
			expect(data.A).to.equal(true)
			expect(data.B).to.equal(true)
		end)

		it("is a no-op when already at the target version", function()
			local data = { SchemaVersion = 1 }
			local applied = ProfileSchema.runMigrations(data, {}, 1)
			expect(#applied).to.equal(0)
			expect(data.SchemaVersion).to.equal(1)
		end)

		it("rejects profiles from a newer schema", function()
			local data = { SchemaVersion = 99 }
			expect(function()
				ProfileSchema.runMigrations(data, {}, 1)
			end).to.throw("newer than supported")
		end)

		it("fails loudly when a migration step is missing", function()
			local data = { SchemaVersion = 1 }
			expect(function()
				ProfileSchema.runMigrations(data, {}, 3)
			end).to.throw("Missing migration")
		end)

		it("writes a reversible backup when a migration removes a field", function()
			local migrations = {
				[2] = function(data)
					ProfileSchema.backupField(data, 2, "LegacyCoins", data.LegacyCoins)
					data.Currencies = { Coins = data.LegacyCoins }
					data.LegacyCoins = nil
				end,
			}
			local data = { SchemaVersion = 1, LegacyCoins = 1234, MigrationBackups = {} }
			ProfileSchema.runMigrations(data, migrations, 2)
			expect(data.LegacyCoins).to.equal(nil)
			expect(data.Currencies.Coins).to.equal(1234)
			expect(data.MigrationBackups.v2.LegacyCoins).to.equal(1234)
		end)
	end)
end
