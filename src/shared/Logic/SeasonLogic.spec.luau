--!nocheck
return function()
	local SeasonLogic = require(script.Parent.SeasonLogic)
	local ArenaConfig = require(script.Parent.Parent.Config.ArenaConfig)

	local function freshData(trophies, lastSeason)
		return {
			Stats = {
				Trophies = trophies,
				SeasonHighestTrophies = trophies,
				LastSeason = lastSeason or 0,
			},
		}
	end

	describe("SeasonLogic.applyRollover", function()
		it("stamps brand new profiles without rewarding them", function()
			local data = freshData(0, 0)
			expect(SeasonLogic.applyRollover(data, 3)).to.equal(nil)
			expect(data.Stats.LastSeason).to.equal(3)
		end)

		it("is a no-op within the same season", function()
			local data = freshData(800, 3)
			expect(SeasonLogic.applyRollover(data, 3)).to.equal(nil)
			expect(data.Stats.Trophies).to.equal(800)
		end)

		it("pays placement Gems by final bracket and soft-resets trophies", function()
			local data = freshData(800, 3)
			local result = SeasonLogic.applyRollover(data, 4)
			expect(result).to.be.ok()
			expect(result.Placement).to.equal("Gold")
			expect(result.PlacementGems).to.equal(ArenaConfig.SeasonPlacementGems.Gold)
			expect(result.FinalTrophies).to.equal(800)
			expect(data.Stats.Trophies).to.equal(math.floor(800 * ArenaConfig.SeasonTrophyResetFactor))
			expect(data.Stats.SeasonHighestTrophies).to.equal(data.Stats.Trophies)
		end)

		it("rolls over exactly once per season", function()
			local data = freshData(2500, 3)
			expect(SeasonLogic.applyRollover(data, 4)).to.be.ok()
			expect(SeasonLogic.applyRollover(data, 4)).to.equal(nil)
		end)

		it("every bracket has a placement reward configured", function()
			for _, bracket in ArenaConfig.Brackets do
				expect(ArenaConfig.SeasonPlacementGems[bracket.Name]).to.be.a("number")
			end
		end)
	end)
end
