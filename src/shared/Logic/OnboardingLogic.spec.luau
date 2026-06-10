--!nocheck
return function()
	local OnboardingLogic = require(script.Parent.OnboardingLogic)
	local OnboardingConfig = require(script.Parent.Parent.Config.OnboardingConfig)

	local function freshData(step)
		return { Flags = { OnboardingStep = step or 0 } }
	end

	describe("flow start", function()
		it("starts fresh profiles on the first actionable step", function()
			local data = freshData(0)
			expect(OnboardingLogic.start(data)).to.equal(true)
			expect(data.Flags.OnboardingStep).to.equal(2)
			expect(OnboardingLogic.start(data)).to.equal(false)
		end)
	end)

	describe("step advancement", function()
		it("walks the whole flow in order from metrics", function()
			local data = freshData(0)
			OnboardingLogic.start(data)

			local sequence = { "EggsHatched", "MythlingsFed", "TeamSet", "BattlesPlayed" }
			local finished = false
			for _, metric in sequence do
				local completed, justFinished = OnboardingLogic.onMetric(data, metric)
				expect(#completed).to.equal(1)
				finished = justFinished
			end
			expect(finished).to.equal(true)
			expect(OnboardingLogic.isComplete(data.Flags.OnboardingStep)).to.equal(true)
		end)

		it("ignores out-of-order and unrelated metrics", function()
			local data = freshData(0)
			OnboardingLogic.start(data)
			-- Step 2 wants EggsHatched; battling early does not skip ahead.
			local completed = OnboardingLogic.onMetric(data, "BattlesPlayed")
			expect(#completed).to.equal(0)
			expect(data.Flags.OnboardingStep).to.equal(2)
			completed = OnboardingLogic.onMetric(data, "NothingMetric")
			expect(#completed).to.equal(0)
		end)

		it("does nothing for completed or unstarted flows", function()
			local done = freshData(#OnboardingConfig.Steps + 1)
			local completed, justFinished = OnboardingLogic.onMetric(done, "EggsHatched")
			expect(#completed).to.equal(0)
			expect(justFinished).to.equal(false)

			local unstarted = freshData(0)
			completed = OnboardingLogic.onMetric(unstarted, "EggsHatched")
			expect(#completed).to.equal(0)
		end)
	end)

	describe("config sanity", function()
		it("every step past Welcome has a completion metric", function()
			for index, step in OnboardingConfig.Steps do
				if index > 1 then
					expect(step.CompletedBy).to.be.a("string")
				end
				expect(#step.Text > 0).to.equal(true)
			end
		end)
	end)
end
