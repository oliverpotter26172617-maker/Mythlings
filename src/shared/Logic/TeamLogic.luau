--!strict
-- Builds a battle team from a player's profile. Pure Luau.
-- The arena team is the player's follower roster (ActiveMythlings).

local AbilityConfig = require(script.Parent.Parent.Config.AbilityConfig)
local PlayerConfig = require(script.Parent.Parent.Config.PlayerConfig)
local StatCalc = require(script.Parent.StatCalc)

local TeamLogic = {}

export type TeamBuild = {
	Ok: boolean,
	Error: string?,
	Units: { { [string]: any } }?,
	Power: number?,
}

function TeamLogic.buildTeam(data: { [string]: any }, userId: number): TeamBuild
	local roster = data.ActiveMythlings
	if #roster < PlayerConfig.TeamSize then
		return {
			Ok = false,
			Error = `You need {PlayerConfig.TeamSize} Mythlings out with you to battle. Open your collection and pick a team.`,
		}
	end

	local units = {}
	local power = 0
	for index = 1, PlayerConfig.TeamSize do
		local mythlingId = roster[index]
		local record = data.Mythlings[mythlingId]
		if record == nil then
			return { Ok = false, Error = "One of your team Mythlings is missing." }
		end
		local stats = StatCalc.compute(record.SpeciesId, record.Stage, record.Potential)
		power += StatCalc.power(stats)
		table.insert(units, {
			Id = `{userId}:{mythlingId}`,
			MythlingId = mythlingId,
			Element = record.Element,
			Stats = stats,
			Abilities = AbilityConfig.loadout(record.Element, record.Stage),
			CastPolicy = "Manual",
			DisplayName = record.Nickname or record.SpeciesId,
		})
	end

	return { Ok = true, Units = units, Power = power }
end

return TeamLogic
