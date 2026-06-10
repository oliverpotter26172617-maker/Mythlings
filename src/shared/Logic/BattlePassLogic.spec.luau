--!nocheck
return function()
	local BattlePassLogic = require(script.Parent.BattlePassLogic)
	local BattlePassConfig = require(script.Parent.Parent.Config.BattlePassConfig)

	local function freshPass(overrides)
		local data = {
			BattlePass = {
				Season = 1,
				Tier = 0,
				Xp = 0,
				OwnsPremium = false,
				ClaimedFree = {},
				ClaimedPremium = {},
			},
		}
		for key, value in overrides or {} do
			data.BattlePass[key] = value
		end
		return data
	end

	describe("season maths", function()
		it("computes season 1 at the epoch and rolls every 8 weeks", function()
			local epoch = BattlePassConfig.SeasonEpoch
			local seasonSeconds = BattlePassConfig.SeasonLengthWeeks * 7 * 86400
			expect(BattlePassLogic.seasonIndex(epoch)).to.equal(1)
			expect(BattlePassLogic.seasonIndex(epoch + seasonSeconds - 1)).to.equal(1)
			expect(BattlePassLogic.seasonIndex(epoch + seasonSeconds)).to.equal(2)
		end)

		it("ensureSeason resets progress exactly once per rollover", function()
			local data = freshPass({ Xp = 5000, Tier = 5, OwnsPremium = true, ClaimedFree = { ["3"] = true } })
			expect(BattlePassLogic.ensureSeason(data, 1)).to.equal(false)
			expect(data.BattlePass.Xp).to.equal(5000)

			expect(BattlePassLogic.ensureSeason(data, 2)).to.equal(true)
			expect(data.BattlePass.Xp).to.equal(0)
			expect(data.BattlePass.OwnsPremium).to.equal(false)
			expect(data.BattlePass.ClaimedFree["3"]).to.equal(nil)
		end)
	end)

	describe("tier progression", function()
		it("maps XP to tiers and caps at the final tier", function()
			expect(BattlePassLogic.tierForXp(0)).to.equal(0)
			expect(BattlePassLogic.tierForXp(BattlePassConfig.XpPerTier)).to.equal(1)
			expect(BattlePassLogic.tierForXp(BattlePassConfig.XpPerTier * 999)).to.equal(BattlePassConfig.TierCount)
		end)

		it("addXp accumulates and stamps the tier", function()
			local data = freshPass()
			BattlePassLogic.addXp(data, BattlePassConfig.XpPerTier * 2 + 50)
			expect(data.BattlePass.Tier).to.equal(2)
			BattlePassLogic.addXp(data, BattlePassConfig.XpPerTier)
			expect(data.BattlePass.Tier).to.equal(3)
		end)
	end)

	describe("claims", function()
		it("allows a reached free tier to be claimed exactly once", function()
			local data = freshPass({ Xp = BattlePassConfig.XpPerTier * 3 })
			local check = BattlePassLogic.validateClaim(data, 2, "Free")
			expect(check.Ok).to.equal(true)
			expect(check.Reward).to.be.ok()
			BattlePassLogic.markClaimed(data, 2, "Free")
			expect(BattlePassLogic.validateClaim(data, 2, "Free").Ok).to.equal(false)
		end)

		it("blocks unreached tiers and premium without ownership", function()
			local data = freshPass({ Xp = BattlePassConfig.XpPerTier })
			expect(BattlePassLogic.validateClaim(data, 5, "Free").Ok).to.equal(false)
			expect(BattlePassLogic.validateClaim(data, 1, "Premium").Ok).to.equal(false)
			data.BattlePass.OwnsPremium = true
			expect(BattlePassLogic.validateClaim(data, 1, "Premium").Ok).to.equal(true)
		end)

		it("tracks free and premium claims independently", function()
			local data = freshPass({ Xp = BattlePassConfig.XpPerTier * 5, OwnsPremium = true })
			BattlePassLogic.markClaimed(data, 4, "Free")
			expect(BattlePassLogic.validateClaim(data, 4, "Premium").Ok).to.equal(true)
		end)

		it("rejects nonsense tiers", function()
			local data = freshPass({ Xp = BattlePassConfig.XpPerTier * 50 })
			expect(BattlePassLogic.validateClaim(data, 0, "Free").Ok).to.equal(false)
			expect(BattlePassLogic.validateClaim(data, 51, "Free").Ok).to.equal(false)
			expect(BattlePassLogic.validateClaim(data, 2.5, "Free").Ok).to.equal(false)
		end)
	end)

	describe("config completeness", function()
		it("every tier has a reward on both tracks", function()
			for tier = 1, BattlePassConfig.TierCount do
				expect(BattlePassConfig.FreeTrack[tier]).to.be.ok()
				expect(BattlePassConfig.PremiumTrack[tier]).to.be.ok()
				expect(BattlePassConfig.FreeTrack[tier].Count > 0).to.equal(true)
				expect(BattlePassConfig.PremiumTrack[tier].Count > 0).to.equal(true)
			end
		end)
	end)
end
