--!nocheck
return function()
	local TeamLogic = require(script.Parent.TeamLogic)
	local PlayerConfig = require(script.Parent.Parent.Config.PlayerConfig)

	local function record(speciesId, stage, potential)
		return { SpeciesId = speciesId, Element = "Flame", Rarity = "Common", Stage = stage, Potential = potential }
	end

	describe("TeamLogic.buildTeam", function()
		it("builds units with stats, abilities and power for a full roster", function()
			local data = {
				ActiveMythlings = { "M1", "M2", "M3" },
				Mythlings = {
					M1 = record("Cindercub", "Adult", 50),
					M2 = record("Cindercub", "Juvenile", 30),
					M3 = record("Cindercub", "Alpha", 90),
				},
			}
			local build = TeamLogic.buildTeam(data, 42)
			expect(build.Ok).to.equal(true)
			expect(#build.Units).to.equal(PlayerConfig.TeamSize)
			expect(build.Power > 0).to.equal(true)
			expect(build.Units[1].Id).to.equal("42:M1")
			expect(build.Units[1].CastPolicy).to.equal("Manual")
			expect(#build.Units[3].Abilities).to.equal(4)
			expect(#build.Units[2].Abilities).to.equal(2)
		end)

		it("refuses a short roster", function()
			local data = { ActiveMythlings = { "M1" }, Mythlings = { M1 = record("Cindercub", "Adult", 50) } }
			expect(TeamLogic.buildTeam(data, 42).Ok).to.equal(false)
		end)

		it("refuses when a roster id no longer exists", function()
			local data = {
				ActiveMythlings = { "M1", "M2", "M3" },
				Mythlings = { M1 = record("Cindercub", "Adult", 50) },
			}
			expect(TeamLogic.buildTeam(data, 42).Ok).to.equal(false)
		end)
	end)
end
