--!strict
-- New-player onboarding: a short guided flow that lands the free Rare
-- egg in the first minutes and ends with a first casual battle.
-- Retention before monetisation.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type StepDef = {
	Id: string,
	Text: string,
	-- The metric (from QuestService reporting) that completes this step.
	CompletedBy: string?,
}

return TableUtil.deepFreeze({
	Steps = {
		{ Id = "Welcome", Text = "Welcome to Mythlings! A free Rare egg is in your Hatchery.", CompletedBy = nil },
		{ Id = "HatchStarter", Text = "Open the Hatchery and hatch your free Rare egg!", CompletedBy = "EggsHatched" },
		{ Id = "FeedMythling", Text = "Buy some food and feed your new Mythling.", CompletedBy = "MythlingsFed" },
		{ Id = "SetTeam", Text = "Pick your Mythling as a follower from your collection.", CompletedBy = "TeamSet" },
		{
			Id = "FirstBattle",
			Text = "Try a Casual battle in the arena. Win or lose, you earn rewards!",
			CompletedBy = "BattlesPlayed",
		},
	} :: { StepDef },

	-- The free Rare egg: sealed Rare outcome, fast hatch.
	StarterEggHatchMinutes = 2,

	-- Coins granted when the flow completes (tops the first session up
	-- towards the 1,500 Coin session-one target).
	CompletionCoins = 500,
})
