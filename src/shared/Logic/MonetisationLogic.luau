--!strict
-- Receipt idempotency and pass benefit maths. Pure Luau.

local MonetisationConfig = require(script.Parent.Parent.Config.MonetisationConfig)

local MonetisationLogic = {}

-- Applies a receipt exactly once. The grant function runs only if the
-- ReceiptId has never been recorded in the profile's purchase ledger.
-- Returns true when granted, false when it was a replay.
function MonetisationLogic.applyReceiptOnce(
	data: { [string]: any },
	receiptId: string,
	now: number,
	grant: () -> ()
): boolean
	if data.PurchaseLedger[receiptId] ~= nil then
		return false
	end
	-- Record before granting: if the grant errors after a partial write,
	-- the replayed receipt must not double-grant currency.
	data.PurchaseLedger[receiptId] = now
	grant()
	return true
end

-- Coin source multiplier from owned passes (battle rewards, idle income).
function MonetisationLogic.coinMultiplier(passes: { [string]: any }): number
	if passes.VIP then
		return MonetisationConfig.VipCoinMultiplier
	end
	return 1
end

-- Incubation seconds after pass discounts.
function MonetisationLogic.hatchSeconds(baseSeconds: number, passes: { [string]: any }): number
	if passes.HatchSpeed then
		return math.ceil(baseSeconds / MonetisationConfig.HatchSpeedMultiplier)
	end
	return baseSeconds
end

-- Day stamp used for the VIP daily Gem stipend (UTC days).
function MonetisationLogic.dayStamp(now: number): number
	return math.floor(now / 86400)
end

function MonetisationLogic.vipStipendDue(data: { [string]: any }, now: number): boolean
	if not data.Passes.VIP then
		return false
	end
	return (data.Flags.LastVipStipendDay or 0) < MonetisationLogic.dayStamp(now)
end

return MonetisationLogic
