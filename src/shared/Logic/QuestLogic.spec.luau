--!nocheck
return function()
	local QuestLogic = require(script.Parent.QuestLogic)
	local QuestConfig = require(script.Parent.Parent.Config.QuestConfig)

	local DAY = 86400

	local function freshData()
		return {
			Quests = { DayStamp = -1, WeekStamp = -1, Daily = {}, Weekly = {} },
			LoginCalendar = { LastClaimDay = -1, DayIndex = 0 },
			Gifts = { DayStamp = -1, Given = {} },
		}
	end

	describe("quest rolling", function()
		it("rolls the configured counts and rerolls on new stamps", function()
			local data = freshData()
			expect(QuestLogic.ensureQuests(data, DAY * 100)).to.equal(true)
			expect(#data.Quests.Daily).to.equal(QuestConfig.DailyCount)
			expect(#data.Quests.Weekly).to.equal(QuestConfig.WeeklyCount)

			expect(QuestLogic.ensureQuests(data, DAY * 100 + 60)).to.equal(false)

			local oldIds = {}
			for _, quest in data.Quests.Daily do
				table.insert(oldIds, quest.Id)
			end
			expect(QuestLogic.ensureQuests(data, DAY * 101)).to.equal(true)
			local changedAny = false
			for index, quest in data.Quests.Daily do
				if quest.Id ~= oldIds[index] then
					changedAny = true
				end
			end
			expect(changedAny).to.equal(true)
		end)

		it("is deterministic for the same stamp", function()
			local a, b = freshData(), freshData()
			QuestLogic.ensureQuests(a, DAY * 123)
			QuestLogic.ensureQuests(b, DAY * 123)
			for index, quest in a.Quests.Daily do
				expect(quest.Id).to.equal(b.Quests.Daily[index].Id)
			end
		end)
	end)

	describe("progress and claims", function()
		it("tracks metrics, caps at target and claims once", function()
			local data = freshData()
			QuestLogic.ensureQuests(data, DAY * 100)

			-- Find an active daily quest and drive its metric.
			local quest = data.Quests.Daily[1]
			local def = QuestLogic.defFor(quest.Id)
			QuestLogic.report(data, def.Metric, def.Target + 50)
			expect(quest.Progress).to.equal(def.Target)

			local ok, _, claimedDef = QuestLogic.validateClaim(data, "Daily", quest.Id)
			expect(ok).to.equal(true)
			expect(claimedDef.Id).to.equal(quest.Id)
			expect((QuestLogic.validateClaim(data, "Daily", quest.Id))).to.equal(false)
		end)

		it("refuses unfinished and unknown quests", function()
			local data = freshData()
			QuestLogic.ensureQuests(data, DAY * 100)
			expect((QuestLogic.validateClaim(data, "Daily", data.Quests.Daily[1].Id))).to.equal(false)
			expect((QuestLogic.validateClaim(data, "Daily", "NotAQuest"))).to.equal(false)
		end)

		it("ignores progress on already claimed quests", function()
			local data = freshData()
			QuestLogic.ensureQuests(data, DAY * 100)
			local quest = data.Quests.Daily[1]
			local def = QuestLogic.defFor(quest.Id)
			QuestLogic.report(data, def.Metric, def.Target)
			QuestLogic.validateClaim(data, "Daily", quest.Id)
			quest.Progress = 0
			QuestLogic.report(data, def.Metric, 5)
			expect(quest.Progress).to.equal(0)
		end)
	end)

	describe("login calendar", function()
		it("claims once per day and cycles through all seven days", function()
			local data = freshData()
			local seen = {}
			for day = 1, 9 do
				local index, reward = QuestLogic.claimCalendar(data, DAY * (200 + day))
				expect(index).to.be.a("number")
				expect(reward).to.be.ok()
				seen[index] = true
				-- Second claim the same day refuses.
				local again = QuestLogic.claimCalendar(data, DAY * (200 + day) + 60)
				expect(again).to.equal(nil)
			end
			for day = 1, 7 do
				expect(seen[day]).to.equal(true)
			end
		end)

		it("day 7 is the guaranteed Epic egg", function()
			expect(QuestConfig.Calendar[7].Type).to.equal("EpicEgg")
		end)
	end)

	describe("gifting", function()
		it("allows one gift per friend per day with a daily reset", function()
			local data = freshData()
			local now = DAY * 300
			expect((QuestLogic.tryRecordGift(data, 42, now))).to.equal(true)
			expect((QuestLogic.tryRecordGift(data, 42, now + 60))).to.equal(false)
			expect((QuestLogic.tryRecordGift(data, 43, now + 60))).to.equal(true)
			expect((QuestLogic.tryRecordGift(data, 42, now + DAY))).to.equal(true)
		end)
	end)
end
