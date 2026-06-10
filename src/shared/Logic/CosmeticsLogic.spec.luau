--!nocheck
return function()
	local CosmeticsLogic = require(script.Parent.CosmeticsLogic)
	local CosmeticConfig = require(script.Parent.Parent.Config.CosmeticConfig)
	local ArenaShopConfig = require(script.Parent.Parent.Config.ArenaShopConfig)
	local GrowthConfig = require(script.Parent.Parent.Config.GrowthConfig)
	local EggConfig = require(script.Parent.Parent.Config.EggConfig)
	local TeamLogic = require(script.Parent.TeamLogic)
	local BattleSim = require(script.Parent.BattleSim)
	local AbilityConfig = require(script.Parent.Parent.Config.AbilityConfig)

	local function makeRng(seed)
		local state = seed
		return function()
			state = (state * 25214903917 + 11) % 281474976710656
			return state / 281474976710656
		end
	end

	describe("stat neutrality is structural (build gate)", function()
		it("no cosmetic def carries any key outside the whitelist", function()
			local allowed = {}
			for _, key in CosmeticConfig.AllowedKeys do
				allowed[key] = true
			end
			for _, def in CosmeticConfig.Catalogue do
				for key in def do
					expect(allowed[key]).to.equal(true)
				end
			end
		end)

		it("battle teams are identical with and without cosmetics equipped", function()
			local function makeData(withCosmetics)
				local record = {
					SpeciesId = "Cindercub",
					Element = "Flame",
					Rarity = "Common",
					Stage = "Adult",
					Potential = 70,
					Cosmetics = if withCosmetics
						then { Hat = "TinyTopHat", Aura = "EmberAura", Dye = "RoseDye" }
						else {},
				}
				return {
					ActiveMythlings = { "M1", "M2", "M3" },
					Mythlings = { M1 = record, M2 = record, M3 = record },
					Cosmetics = {
						OwnedAvatar = if withCosmetics then { ArenaArmour = true } else {},
						OwnedMythling = {},
						EquippedAvatar = if withCosmetics then { ArmourSkin = "ArenaArmour" } else {},
					},
				}
			end

			local plain = TeamLogic.buildTeam(makeData(false), 1)
			local dressed = TeamLogic.buildTeam(makeData(true), 1)
			expect(plain.Power).to.equal(dressed.Power)
			for index, unit in plain.Units do
				local other = dressed.Units[index]
				expect(unit.Stats.HP).to.equal(other.Stats.HP)
				expect(unit.Stats.Attack).to.equal(other.Stats.Attack)
				expect(unit.Stats.Defence).to.equal(other.Stats.Defence)
				expect(unit.Stats.Speed).to.equal(other.Stats.Speed)
			end

			-- And full battles with the same seed resolve identically.
			local enemy = {
				{
					Id = "E1",
					Element = "Tide",
					Stats = { HP = 120, Attack = 130, Defence = 90, Speed = 100 },
					Abilities = AbilityConfig.loadout("Tide", "Adult"),
				},
			}
			local simPlain = BattleSim.new(plain.Units, enemy, makeRng(42))
			local simDressed = BattleSim.new(dressed.Units, enemy, makeRng(42))
			local resultPlain = simPlain:runToCompletion()
			local resultDressed = simDressed:runToCompletion()
			expect(resultPlain.Winner).to.equal(resultDressed.Winner)
			expect(resultPlain.Duration).to.equal(resultDressed.Duration)
			expect(#simPlain:getEvents()).to.equal(#simDressed:getEvents())
		end)
	end)

	describe("purchases and equipping", function()
		local function freshData()
			return {
				Currencies = { Gems = 1000 },
				Cosmetics = { OwnedAvatar = {}, OwnedMythling = {}, EquippedAvatar = {} },
			}
		end

		it("validates buying", function()
			local data = freshData()
			expect((CosmeticsLogic.validateBuy(data, "WizardHat"))).to.equal(true)
			expect((CosmeticsLogic.validateBuy(data, "Imaginary"))).to.equal(false)
			expect((CosmeticsLogic.validateBuy(data, "RaidAura"))).to.equal(false)
			data.Currencies.Gems = 1
			expect((CosmeticsLogic.validateBuy(data, "WizardHat"))).to.equal(false)
			data.Currencies.Gems = 1000
			data.Cosmetics.OwnedAvatar.WizardHat = true
			expect((CosmeticsLogic.validateBuy(data, "WizardHat"))).to.equal(false)
		end)

		it("validates equipping by layer, slot and ownership", function()
			local data = freshData()
			data.Cosmetics.OwnedAvatar.WizardHat = true
			data.Cosmetics.OwnedMythling.EmberAura = true

			expect((CosmeticsLogic.validateEquip(data, "Avatar", "Hat", "WizardHat"))).to.equal(true)
			expect((CosmeticsLogic.validateEquip(data, "Avatar", "Hat", nil))).to.equal(true)
			expect((CosmeticsLogic.validateEquip(data, "Avatar", "Cape", "WizardHat"))).to.equal(false)
			expect((CosmeticsLogic.validateEquip(data, "Mythling", "Aura", "EmberAura"))).to.equal(true)
			expect((CosmeticsLogic.validateEquip(data, "Avatar", "Aura", "EmberAura"))).to.equal(false)
			expect((CosmeticsLogic.validateEquip(data, "Mythling", "Trail", "StarTrail"))).to.equal(false)
			expect((CosmeticsLogic.validateEquip(data, "Avatar", "Wings", "WizardHat"))).to.equal(false)
		end)
	end)

	describe("arena shop rotation", function()
		it("returns the configured slots and rotates weekly", function()
			local week0 = CosmeticsLogic.arenaShopForWeek(0)
			expect(#week0).to.equal(ArenaShopConfig.SlotsPerWeek)
			local week1 = CosmeticsLogic.arenaShopForWeek(1)
			expect(week0[1].Id).never.to.equal(week1[1].Id)
		end)

		it("every pool entry references a real item", function()
			for _, entry in ArenaShopConfig.Pool do
				if entry.Type == "Cosmetic" then
					expect(CosmeticConfig.Catalogue[entry.Id]).to.be.ok()
				elseif entry.Type == "Food" then
					expect(GrowthConfig.Food[entry.Id]).to.be.ok()
				elseif entry.Type == "Egg" then
					expect(EggConfig.Tiers[entry.Id]).to.be.ok()
				end
				expect(entry.PriceTokens > 0).to.equal(true)
			end
		end)
	end)
end
