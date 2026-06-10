--!strict
-- Pure validation for egg purchases. The server calls this before touching
-- the profile; the client may call it too for instant UI feedback, but the
-- server result is the only one that matters.

local EggConfig = require(script.Parent.Parent.Config.EggConfig)
local PlayerConfig = require(script.Parent.Parent.Config.PlayerConfig)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local EggShopLogic = {}

export type PurchaseCheck = {
	Ok: boolean,
	Error: string?,
	Currency: string?,
	Amount: number?,
}

function EggShopLogic.countOwnedEggs(data: { [string]: any }): number
	return TableUtil.count(data.Eggs)
end

function EggShopLogic.validatePurchase(data: { [string]: any }, tierId: string): PurchaseCheck
	local tier = EggConfig.Tiers[tierId]
	if tier == nil then
		return { Ok = false, Error = "That egg does not exist." }
	end

	if EggShopLogic.countOwnedEggs(data) >= PlayerConfig.MaxStoredEggs then
		return { Ok = false, Error = "Your egg storage is full. Hatch some eggs first." }
	end

	local currency = tier.Price.Currency
	local amount = tier.Price.Amount
	local balance = data.Currencies[currency] or 0
	if balance < amount then
		local label = if currency == "Gems" then "Gems" else "Coins"
		return { Ok = false, Error = `You need {amount} {label} for this egg.` }
	end

	return { Ok = true, Currency = currency, Amount = amount }
end

return EggShopLogic
