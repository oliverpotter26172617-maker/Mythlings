--!strict
-- Battle Pass season maths and claim rules. Pure Luau.

local BattlePassConfig = require(script.Parent.Parent.Config.BattlePassConfig)

local BattlePassLogic = {}

function BattlePassLogic.seasonIndex(now: number): number
	local seasonSeconds = BattlePassConfig.SeasonLengthWeeks * 7 * 86400
	return math.max(1, math.floor((now - BattlePassConfig.SeasonEpoch) / seasonSeconds) + 1)
end

function BattlePassLogic.tierForXp(xp: number): number
	return math.min(BattlePassConfig.TierCount, math.floor(xp / BattlePassConfig.XpPerTier))
end

-- Rolls the profile's pass block over to the given season, wiping the
-- previous season's progress and claims.
function BattlePassLogic.ensureSeason(data: { [string]: any }, season: number): boolean
	if data.BattlePass.Season == season then
		return false
	end
	data.BattlePass = {
		Season = season,
		Tier = 0,
		Xp = 0,
		OwnsPremium = false,
		ClaimedFree = {},
		ClaimedPremium = {},
	}
	return true
end

function BattlePassLogic.addXp(data: { [string]: any }, amount: number): number
	assert(amount >= 0, "pass XP must not be negative")
	data.BattlePass.Xp += amount
	data.BattlePass.Tier = BattlePassLogic.tierForXp(data.BattlePass.Xp)
	return data.BattlePass.Tier
end

export type ClaimCheck = {
	Ok: boolean,
	Error: string?,
	Reward: BattlePassConfig.PassReward?,
}

function BattlePassLogic.validateClaim(data: { [string]: any }, tier: number, track: "Free" | "Premium"): ClaimCheck
	if tier < 1 or tier > BattlePassConfig.TierCount or tier % 1 ~= 0 then
		return { Ok = false, Error = "That tier does not exist." }
	end
	if BattlePassLogic.tierForXp(data.BattlePass.Xp) < tier then
		return { Ok = false, Error = "You have not reached that tier yet." }
	end
	if track == "Premium" and not data.BattlePass.OwnsPremium then
		return { Ok = false, Error = "That reward needs the Premium pass." }
	end

	local claimed = if track == "Premium" then data.BattlePass.ClaimedPremium else data.BattlePass.ClaimedFree
	local key = tostring(tier)
	if claimed[key] then
		return { Ok = false, Error = "You already claimed that reward." }
	end

	local rewardTable = if track == "Premium" then BattlePassConfig.PremiumTrack else BattlePassConfig.FreeTrack
	return { Ok = true, Reward = rewardTable[tier] }
end

function BattlePassLogic.markClaimed(data: { [string]: any }, tier: number, track: "Free" | "Premium")
	local claimed = if track == "Premium" then data.BattlePass.ClaimedPremium else data.BattlePass.ClaimedFree
	claimed[tostring(tier)] = true
end

return BattlePassLogic
