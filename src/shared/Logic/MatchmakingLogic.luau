--!strict
-- Bracket lookup and pairing rules. Pure Luau.

local ArenaConfig = require(script.Parent.Parent.Config.ArenaConfig)

local MatchmakingLogic = {}

export type QueueEntry = {
	UserId: number,
	Trophies: number,
	Power: number,
	QueuedAt: number,
}

function MatchmakingLogic.bracketFor(trophies: number): ArenaConfig.BracketDef
	for _, bracket in ArenaConfig.Brackets do
		if trophies >= bracket.MinTrophies and trophies <= bracket.MaxTrophies then
			return bracket
		end
	end
	-- Trophies below zero cannot happen (floor of 0), but stay safe.
	return ArenaConfig.Brackets[1]
end

-- Two entries can fight when they share a bracket and the Power gap is
-- within the cap. A whale's overbuilt team simply will not match a fresh
-- player's team.
function MatchmakingLogic.canMatch(a: QueueEntry, b: QueueEntry): boolean
	if a.UserId == b.UserId then
		return false
	end
	if MatchmakingLogic.bracketFor(a.Trophies).Name ~= MatchmakingLogic.bracketFor(b.Trophies).Name then
		return false
	end
	local stronger = math.max(a.Power, b.Power)
	local weaker = math.max(1, math.min(a.Power, b.Power))
	return stronger / weaker <= ArenaConfig.PowerGapMax
end

-- Greedy pairing over a queue ordered by wait time (longest waiting gets
-- priority). Returns pairs of entries and the list of leftovers.
function MatchmakingLogic.findPairs(queue: { QueueEntry }): ({ { QueueEntry } }, { QueueEntry })
	local sorted = table.clone(queue)
	table.sort(sorted, function(x, y)
		return x.QueuedAt < y.QueuedAt
	end)

	local pairs_: { { QueueEntry } } = {}
	local used: { [number]: boolean } = {}

	for i = 1, #sorted do
		if used[i] then
			continue
		end
		for j = i + 1, #sorted do
			if used[j] then
				continue
			end
			if MatchmakingLogic.canMatch(sorted[i], sorted[j]) then
				table.insert(pairs_, { sorted[i], sorted[j] })
				used[i] = true
				used[j] = true
				break
			end
		end
	end

	local leftovers = {}
	for i = 1, #sorted do
		if not used[i] then
			table.insert(leftovers, sorted[i])
		end
	end
	return pairs_, leftovers
end

return MatchmakingLogic
