--!nocheck
-- One describe block per row of the locked Section 3.6 table.
return function()
	local RewardsLogic = require(script.Parent.RewardsLogic)
	local RewardsConfig = require(script.Parent.Parent.Config.RewardsConfig)

	local function fixedRng(value)
		return function()
			return value
		end
	end

	local function compute(overrides)
		local input = {
			Mode = "Ranked",
			Outcome = "Win",
			BracketCoinMultiplier = 1,
			CurrentTrophies = 500,
			PriorWinStreak = 0,
			PriorLossStreak = 0,
			Rng = fixedRng(0),
		}
		for key, value in overrides do
			input[key] = value
		end
		return RewardsLogic.compute(input)
	end

	describe("Ranked win row", function()
		it("pays 250 base times the bracket multiplier", function()
			expect(compute({ BracketCoinMultiplier = 1 }).Coins).to.equal(250)
			expect(compute({ BracketCoinMultiplier = 1.5 }).Coins).to.equal(375)
			expect(compute({ BracketCoinMultiplier = 2 }).Coins).to.equal(500)
		end)

		it("awards +25 to +35 trophies", function()
			expect(compute({ Rng = fixedRng(0) }).TrophyDelta).to.equal(25)
			expect(compute({ Rng = fixedRng(0.999999) }).TrophyDelta).to.equal(35)
		end)

		it("grants full XP and 3 Battle Tokens", function()
			local result = compute({})
			expect(result.XpPerMythling).to.equal(RewardsConfig.BaseBattleXp)
			expect(result.BattleTokens).to.equal(3)
		end)

		it("adds +10% Coins per streak, capped at +50%", function()
			expect(compute({ PriorWinStreak = 1 }).Coins).to.equal(275)
			expect(compute({ PriorWinStreak = 3 }).Coins).to.equal(325)
			expect(compute({ PriorWinStreak = 5 }).Coins).to.equal(375)
			expect(compute({ PriorWinStreak = 50 }).Coins).to.equal(375)
			expect(compute({ PriorWinStreak = 50 }).StreakBonusFraction).to.equal(0.5)
		end)

		it("extends the win streak and clears the loss streak", function()
			local result = compute({ PriorWinStreak = 2, PriorLossStreak = 0 })
			expect(result.NewWinStreak).to.equal(3)
			expect(result.NewLossStreak).to.equal(0)
		end)
	end)

	describe("Ranked loss row", function()
		it("pays the 75 Coin consolation (30% of base)", function()
			local result = compute({ Outcome = "Loss" })
			expect(result.Coins).to.equal(75)
			expect(result.Coins).to.equal(math.floor(250 * 0.3))
		end)

		it("takes 10 to 20 trophies", function()
			expect(compute({ Outcome = "Loss", Rng = fixedRng(0) }).TrophyDelta).to.equal(-10)
			expect(compute({ Outcome = "Loss", Rng = fixedRng(0.999999) }).TrophyDelta).to.equal(-20)
		end)

		it("never drops trophies below zero", function()
			local result = compute({ Outcome = "Loss", CurrentTrophies = 7, Rng = fixedRng(0.999999) })
			expect(result.TrophyDelta).to.equal(-7)
		end)

		it("grants 40% XP and 1 Battle Token", function()
			local result = compute({ Outcome = "Loss" })
			expect(result.XpPerMythling).to.equal(math.floor(RewardsConfig.BaseBattleXp * 0.4))
			expect(result.BattleTokens).to.equal(1)
		end)

		it("activates loss protection after 3 straight losses", function()
			local unprotected = compute({ Outcome = "Loss", PriorLossStreak = 2, Rng = fixedRng(0.5) })
			expect(unprotected.LossProtected).to.equal(false)
			expect(unprotected.TrophyDelta < 0).to.equal(true)

			local protected_ = compute({ Outcome = "Loss", PriorLossStreak = 3 })
			expect(protected_.LossProtected).to.equal(true)
			expect(protected_.TrophyDelta).to.equal(0)
		end)

		it("extends the loss streak and clears the win streak", function()
			local result = compute({ Outcome = "Loss", PriorWinStreak = 4, PriorLossStreak = 1 })
			expect(result.NewWinStreak).to.equal(0)
			expect(result.NewLossStreak).to.equal(2)
		end)
	end)

	describe("Casual win row", function()
		it("pays 150 Coins, 0 trophies, full XP, 2 tokens", function()
			local result = compute({ Mode = "Casual", Outcome = "Win", PriorWinStreak = 9 })
			expect(result.Coins).to.equal(150)
			expect(result.TrophyDelta).to.equal(0)
			expect(result.XpPerMythling).to.equal(RewardsConfig.BaseBattleXp)
			expect(result.BattleTokens).to.equal(2)
			expect(result.StreakBonusFraction).to.equal(0)
		end)
	end)

	describe("Casual loss row", function()
		it("pays 50 Coins, 0 trophies, 40% XP, 1 token", function()
			local result = compute({ Mode = "Casual", Outcome = "Loss" })
			expect(result.Coins).to.equal(50)
			expect(result.TrophyDelta).to.equal(0)
			expect(result.XpPerMythling).to.equal(math.floor(RewardsConfig.BaseBattleXp * 0.4))
			expect(result.BattleTokens).to.equal(1)
		end)
	end)

	describe("Boss raid clear row", function()
		it("pays 400 Coins, full XP and 5 tokens (chest rolls separately)", function()
			local result = compute({ Mode = "Raid", Outcome = "Win" })
			expect(result.Coins).to.equal(400)
			expect(result.TrophyDelta).to.equal(0)
			expect(result.XpPerMythling).to.equal(RewardsConfig.BaseBattleXp)
			expect(result.BattleTokens).to.equal(5)
		end)
	end)

	describe("draws", function()
		it("pay the loss row with frozen streaks and no trophy movement", function()
			local result = compute({ Outcome = "Draw", PriorWinStreak = 2, PriorLossStreak = 1 })
			expect(result.Coins).to.equal(75)
			expect(result.TrophyDelta).to.equal(0)
			expect(result.NewWinStreak).to.equal(2)
			expect(result.NewLossStreak).to.equal(1)
		end)
	end)
end
