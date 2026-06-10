--!strict
-- Idle plot income and friend-visit bonuses. Pure Luau.
-- Housed Mythlings are the ones out with the player (ActiveMythlings):
-- they roam the plot and earn Coins by rarity, doubled while recently fed.

local HousingConfig = require(script.Parent.Parent.Config.HousingConfig)

local IncomeLogic = {}

-- Coins accrued between lastClaim and now. Accrual stops at the cap.
function IncomeLogic.computeIncome(data: { [string]: any }, now: number): number
	local lastClaim = data.Housing.LastIncomeClaimAt
	if lastClaim <= 0 then
		return 0
	end
	local elapsed = math.min(now - lastClaim, HousingConfig.MaxAccrualHours * 3600)
	if elapsed <= 0 then
		return 0
	end

	local total = 0
	for _, mythlingId in data.ActiveMythlings do
		local record = data.Mythlings[mythlingId]
		if record == nil then
			continue
		end
		local perHour = HousingConfig.IncomePerHour[record.Rarity] or 0
		local lastFedAt = record.LastFedAt or 0
		local fedRecently = lastFedAt > 0 and (now - lastFedAt) <= HousingConfig.FedBonusWindowHours * 3600
		if fedRecently then
			perHour *= HousingConfig.FedBonusMultiplier
		end
		total += perHour * (elapsed / 3600)
	end
	return math.floor(total)
end

-- Claims accrued income: returns the amount and stamps the claim time so
-- the same window can never pay twice.
function IncomeLogic.claim(data: { [string]: any }, now: number): number
	if data.Housing.LastIncomeClaimAt <= 0 then
		-- First ever claim starts the clock without paying.
		data.Housing.LastIncomeClaimAt = now
		return 0
	end
	local coins = IncomeLogic.computeIncome(data, now)
	data.Housing.LastIncomeClaimAt = now
	return coins
end

-- Visit bonus bookkeeping for the visitor. Pays once per distinct friend
-- per UTC day, capped per day.
function IncomeLogic.tryRecordVisit(data: { [string]: any }, friendUserId: number, now: number): (boolean, string?)
	local day = math.floor(now / 86400)
	if data.Housing.VisitBonusDay ~= day then
		data.Housing.VisitBonusDay = day
		data.Housing.VisitBonusCount = 0
		data.Housing.VisitedToday = {}
	end
	local key = tostring(friendUserId)
	if data.Housing.VisitedToday[key] then
		return false, "You already visited this friend today."
	end
	if data.Housing.VisitBonusCount >= HousingConfig.VisitBonusDailyCap then
		return false, "You have collected all your visit bonuses for today."
	end
	data.Housing.VisitedToday[key] = true
	data.Housing.VisitBonusCount += 1
	return true, nil
end

return IncomeLogic
