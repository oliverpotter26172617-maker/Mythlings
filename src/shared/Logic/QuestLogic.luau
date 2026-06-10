--!strict
-- Quest rolling, progress, claims, login calendar and gifting rules.
-- Pure Luau. Quest selection is deterministic from the day/week stamp so
-- no roll state needs storing and all servers agree.

local QuestConfig = require(script.Parent.Parent.Config.QuestConfig)

local QuestLogic = {}

local SECONDS_PER_DAY = 86400
local SECONDS_PER_WEEK = 7 * SECONDS_PER_DAY

function QuestLogic.dayStamp(now: number): number
	return math.floor(now / SECONDS_PER_DAY)
end

function QuestLogic.weekStamp(now: number): number
	return math.floor(now / SECONDS_PER_WEEK)
end

local function pickQuests(pool: { QuestConfig.QuestDef }, count: number, stamp: number): { { [string]: any } }
	local quests = {}
	local start = stamp % #pool
	for index = 0, count - 1 do
		local def = pool[(start + index) % #pool + 1]
		table.insert(quests, { Id = def.Id, Progress = 0, Claimed = false })
	end
	return quests
end

-- Rolls daily/weekly quest sets when their stamps change. Returns true if
-- anything was rerolled.
function QuestLogic.ensureQuests(data: { [string]: any }, now: number): boolean
	local changed = false
	local day = QuestLogic.dayStamp(now)
	local week = QuestLogic.weekStamp(now)

	if data.Quests.DayStamp ~= day then
		data.Quests.DayStamp = day
		data.Quests.Daily = pickQuests(QuestConfig.DailyPool, QuestConfig.DailyCount, day)
		changed = true
	end
	if data.Quests.WeekStamp ~= week then
		data.Quests.WeekStamp = week
		data.Quests.Weekly = pickQuests(QuestConfig.WeeklyPool, QuestConfig.WeeklyCount, week)
		changed = true
	end
	return changed
end

local function defFor(questId: string): QuestConfig.QuestDef?
	for _, def in QuestConfig.DailyPool do
		if def.Id == questId then
			return def
		end
	end
	for _, def in QuestConfig.WeeklyPool do
		if def.Id == questId then
			return def
		end
	end
	return nil
end

QuestLogic.defFor = defFor

-- Adds progress to every active quest tracking this metric.
function QuestLogic.report(data: { [string]: any }, metric: string, amount: number)
	for _, list in { data.Quests.Daily, data.Quests.Weekly } do
		for _, quest in list do
			local def = defFor(quest.Id)
			if def and def.Metric == metric and not quest.Claimed then
				quest.Progress = math.min(def.Target, quest.Progress + amount)
			end
		end
	end
end

function QuestLogic.validateClaim(
	data: { [string]: any },
	scope: "Daily" | "Weekly",
	questId: string
): (boolean, string?, QuestConfig.QuestDef?)
	local list = if scope == "Daily" then data.Quests.Daily else data.Quests.Weekly
	for _, quest in list do
		if quest.Id == questId then
			local def = defFor(questId)
			if def == nil then
				return false, "That quest no longer exists.", nil
			end
			if quest.Claimed then
				return false, "You already claimed that quest.", nil
			end
			if quest.Progress < def.Target then
				return false, "That quest is not finished yet.", nil
			end
			quest.Claimed = true
			return true, nil, def
		end
	end
	return false, "That quest is not active.", nil
end

-- Login calendar: claimable once per UTC day, cycling through 7 days.
-- Returns the day index (1..7) and reward, or nil when already claimed.
function QuestLogic.claimCalendar(data: { [string]: any }, now: number): (number?, { [string]: any }?)
	local today = QuestLogic.dayStamp(now)
	if data.LoginCalendar.LastClaimDay >= today then
		return nil, nil
	end
	data.LoginCalendar.LastClaimDay = today
	data.LoginCalendar.DayIndex = (data.LoginCalendar.DayIndex % #QuestConfig.Calendar) + 1
	return data.LoginCalendar.DayIndex, QuestConfig.Calendar[data.LoginCalendar.DayIndex]
end

-- Gifting: one free Basic egg per friend per day, tracked on the giver.
function QuestLogic.tryRecordGift(data: { [string]: any }, friendUserId: number, now: number): (boolean, string?)
	local today = QuestLogic.dayStamp(now)
	if data.Gifts.DayStamp ~= today then
		data.Gifts.DayStamp = today
		data.Gifts.Given = {}
	end
	local key = tostring(friendUserId)
	if (data.Gifts.Given[key] or 0) >= QuestConfig.GiftDailyCapPerFriend then
		return false, "You already sent that friend an egg today."
	end
	data.Gifts.Given[key] = (data.Gifts.Given[key] or 0) + 1
	return true, nil
end

return QuestLogic
