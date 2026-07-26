--!nocheck
return function()
	local MatchmakingLogic = require(script.Parent.MatchmakingLogic)
	local ArenaConfig = require(script.Parent.Parent.Config.ArenaConfig)

	local function entry(userId, trophies, power, queuedAt)
		return { UserId = userId, Trophies = trophies, Power = power, QueuedAt = queuedAt or 0 }
	end

	describe("MatchmakingLogic.bracketFor", function()
		it("maps trophies to contiguous brackets", function()
			expect(MatchmakingLogic.bracketFor(0).Name).to.equal("Bronze")
			expect(MatchmakingLogic.bracketFor(199).Name).to.equal("Bronze")
			expect(MatchmakingLogic.bracketFor(200).Name).to.equal("Silver")
			expect(MatchmakingLogic.bracketFor(999).Name).to.equal("Gold")
			expect(MatchmakingLogic.bracketFor(50000).Name).to.equal("Diamond")
		end)

		it("brackets are contiguous and ascending in config", function()
			for index = 2, #ArenaConfig.Brackets do
				expect(ArenaConfig.Brackets[index].MinTrophies).to.equal(
					ArenaConfig.Brackets[index - 1].MaxTrophies + 1
				)
			end
		end)
	end)

	describe("MatchmakingLogic.canMatch", function()
		it("blocks cross-bracket matches", function()
			expect(MatchmakingLogic.canMatch(entry(1, 100, 1000), entry(2, 300, 1000))).to.equal(false)
		end)

		it("blocks Power gaps beyond the cap, the anti-stomp guarantee", function()
			local weak = entry(1, 100, 1000)
			local strong = entry(2, 100, 1000 * ArenaConfig.PowerGapMax + 1)
			expect(MatchmakingLogic.canMatch(weak, strong)).to.equal(false)
		end)

		it("allows matches at or under the cap in the same bracket", function()
			local a = entry(1, 100, 1000)
			local b = entry(2, 150, math.floor(1000 * ArenaConfig.PowerGapMax))
			expect(MatchmakingLogic.canMatch(a, b)).to.equal(true)
		end)

		it("never matches a player with themselves", function()
			expect(MatchmakingLogic.canMatch(entry(1, 100, 1000), entry(1, 100, 1000))).to.equal(false)
		end)
	end)

	describe("MatchmakingLogic.findPairs", function()
		it("pairs compatible players and leaves the rest queued", function()
			local queue = {
				entry(1, 100, 1000, 1),
				entry(2, 100, 1100, 2),
				entry(3, 100, 5000, 3),
				entry(4, 800, 1000, 4),
			}
			local pairs_, leftovers = MatchmakingLogic.findPairs(queue)
			expect(#pairs_).to.equal(1)
			expect(pairs_[1][1].UserId).to.equal(1)
			expect(pairs_[1][2].UserId).to.equal(2)
			expect(#leftovers).to.equal(2)
		end)

		it("prioritises the longest waiting player", function()
			local queue = {
				entry(1, 100, 1000, 50),
				entry(2, 100, 1000, 1),
				entry(3, 100, 1000, 10),
			}
			local pairs_ = MatchmakingLogic.findPairs(queue)
			expect(pairs_[1][1].UserId).to.equal(2)
			expect(pairs_[1][2].UserId).to.equal(3)
		end)

		it("breaks equal wait-time ties deterministically by UserId", function()
			-- All queued in the same tick; lowest UserId pair should form
			-- regardless of insertion order.
			local queue = {
				entry(30, 100, 1000, 5),
				entry(10, 100, 1000, 5),
				entry(20, 100, 1000, 5),
			}
			local pairs_ = MatchmakingLogic.findPairs(queue)
			expect(pairs_[1][1].UserId).to.equal(10)
			expect(pairs_[1][2].UserId).to.equal(20)
		end)

		it("returns everything as leftovers when nothing matches", function()
			local queue = { entry(1, 0, 100, 1), entry(2, 5000, 100, 2) }
			local pairs_, leftovers = MatchmakingLogic.findPairs(queue)
			expect(#pairs_).to.equal(0)
			expect(#leftovers).to.equal(2)
		end)
	end)
end
