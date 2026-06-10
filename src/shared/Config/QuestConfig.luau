--!strict
-- Daily and weekly quests, the login calendar and gifting tunables.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type QuestDef = {
	Id: string,
	Description: string,
	Metric: string,
	Target: number,
	Reward: { Type: "Coins" | "Gems" | "Food" | "Egg", Id: string?, Count: number },
}

return TableUtil.deepFreeze({
	DailyCount = 3,
	WeeklyCount = 5,

	DailyPool = {
		{
			Id = "DailyBattles",
			Description = "Play 3 arena battles",
			Metric = "BattlesPlayed",
			Target = 3,
			Reward = { Type = "Coins", Count = 300 },
		},
		{
			Id = "DailyWins",
			Description = "Win 2 arena battles",
			Metric = "BattlesWon",
			Target = 2,
			Reward = { Type = "Gems", Count = 5 },
		},
		{
			Id = "DailyHatch",
			Description = "Hatch 2 eggs",
			Metric = "EggsHatched",
			Target = 2,
			Reward = { Type = "Coins", Count = 350 },
		},
		{
			Id = "DailyFeed",
			Description = "Feed your Mythlings 5 times",
			Metric = "MythlingsFed",
			Target = 5,
			Reward = { Type = "Gems", Count = 4 },
		},
		{
			Id = "DailyIncome",
			Description = "Collect your plot income",
			Metric = "IncomeCollected",
			Target = 1,
			Reward = { Type = "Coins", Count = 200 },
		},
		{
			Id = "DailyGift",
			Description = "Send a friend an egg",
			Metric = "GiftsSent",
			Target = 1,
			Reward = { Type = "Gems", Count = 6 },
		},
	} :: { QuestDef },

	WeeklyPool = {
		{
			Id = "WeeklyWins",
			Description = "Win 10 arena battles",
			Metric = "BattlesWon",
			Target = 10,
			Reward = { Type = "Gems", Count = 30 },
		},
		{
			Id = "WeeklyHatch",
			Description = "Hatch 8 eggs",
			Metric = "EggsHatched",
			Target = 8,
			Reward = { Type = "Egg", Id = "Storm", Count = 1 },
		},
		{
			Id = "WeeklyBreed",
			Description = "Breed a new Mythling egg",
			Metric = "MythlingsBred",
			Target = 1,
			Reward = { Type = "Gems", Count = 20 },
		},
		{
			Id = "WeeklyRaid",
			Description = "Clear the weekly boss raid",
			Metric = "RaidsCleared",
			Target = 1,
			Reward = { Type = "Gems", Count = 25 },
		},
		{
			Id = "WeeklyFeasts",
			Description = "Feed your Mythlings 20 times",
			Metric = "MythlingsFed",
			Target = 20,
			Reward = { Type = "Coins", Count = 2500 },
		},
		{
			Id = "WeeklyTokens",
			Description = "Earn 15 Battle Tokens",
			Metric = "TokensEarned",
			Target = 15,
			Reward = { Type = "Egg", Id = "Royal", Count = 1 },
		},
	} :: { QuestDef },

	-- Login calendar: 7 escalating days, repeating. Day 7 is a guaranteed
	-- Epic egg (sealed outcome rolled at grant time).
	Calendar = {
		{ Type = "Coins", Count = 200 },
		{ Type = "Food", Id = "Berry", Count = 3 },
		{ Type = "Coins", Count = 400 },
		{ Type = "Gems", Count = 5 },
		{ Type = "Food", Id = "Meat", Count = 3 },
		{ Type = "Gems", Count = 10 },
		{ Type = "EpicEgg", Count = 1 },
	},

	-- Day 7 calendar egg: sealed Epic outcome, quick hatch.
	CalendarEggHatchMinutes = 5,

	-- Gifting: one free Basic egg per friend per day.
	GiftEggTier = "Basic",
	GiftDailyCapPerFriend = 1,

	-- Roblox group membership bonus. GroupId 0 disables the check until
	-- the real group id is configured.
	GroupId = 0,
	GroupCoinBonus = 0.1,
})
