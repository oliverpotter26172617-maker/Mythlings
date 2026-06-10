--!strict
-- Seasonal trophy rollover. Pure Luau. Seasons align with the Battle
-- Pass season index; each profile rolls over exactly once per season.

local ArenaConfig = require(script.Parent.Parent.Config.ArenaConfig)
local MatchmakingLogic = require(script.Parent.MatchmakingLogic)

local SeasonLogic = {}

export type RolloverResult = {
	Placement: string,
	FinalTrophies: number,
	NewTrophies: number,
	PlacementGems: number,
}

-- Applies the season rollover if this profile has not seen this season.
-- Returns nil when nothing happened; brand new profiles just stamp the
-- season with no reward (they never competed last season).
function SeasonLogic.applyRollover(data: { [string]: any }, season: number): RolloverResult?
	if data.Stats.LastSeason == season then
		return nil
	end

	local isFirstEver = data.Stats.LastSeason == 0
	data.Stats.LastSeason = season
	if isFirstEver then
		return nil
	end

	local finalTrophies = data.Stats.Trophies
	local bracket = MatchmakingLogic.bracketFor(finalTrophies)
	local gems = ArenaConfig.SeasonPlacementGems[bracket.Name] or 0
	local newTrophies = math.floor(finalTrophies * ArenaConfig.SeasonTrophyResetFactor)

	data.Stats.Trophies = newTrophies
	data.Stats.SeasonHighestTrophies = newTrophies

	return {
		Placement = bracket.Name,
		FinalTrophies = finalTrophies,
		NewTrophies = newTrophies,
		PlacementGems = gems,
	}
end

return SeasonLogic
