--!strict
-- XP accrual and stage transitions. Pure Luau.

local GrowthConfig = require(script.Parent.Parent.Config.GrowthConfig)
local StatConfig = require(script.Parent.Parent.Config.StatConfig)

local GrowthLogic = {}

-- The stage a Mythling should be at for a cumulative XP total. Stages are
-- never skipped silently: the result lists every stage passed through so
-- the caller can fire stage-up moments in order.
function GrowthLogic.stageForXp(xp: number): string
	local result = "Hatchling"
	for _, stage in StatConfig.StageOrder do
		if xp >= GrowthConfig.StageThresholds[stage] then
			result = stage
		end
	end
	return result
end

export type XpResult = {
	NewXp: number,
	NewStage: string,
	StagesGained: { string },
}

function GrowthLogic.addXp(currentXp: number, currentStage: string, amount: number): XpResult
	assert(amount >= 0, "XP amount must not be negative")
	local newXp = currentXp + amount
	local stagesGained = {}

	local passedCurrent = false
	for _, stage in StatConfig.StageOrder do
		if stage == currentStage then
			passedCurrent = true
		elseif passedCurrent and newXp >= GrowthConfig.StageThresholds[stage] then
			table.insert(stagesGained, stage)
		end
	end

	local newStage = if #stagesGained > 0 then stagesGained[#stagesGained] else currentStage
	return { NewXp = newXp, NewStage = newStage, StagesGained = stagesGained }
end

-- Validation for buying food.
function GrowthLogic.validateFoodPurchase(
	data: { [string]: any },
	foodId: string,
	quantity: number
): { Ok: boolean, Error: string?, Currency: string?, Amount: number? }
	local food = GrowthConfig.Food[foodId]
	if food == nil then
		return { Ok = false, Error = "That food does not exist." }
	end
	if quantity < 1 or quantity % 1 ~= 0 or quantity > GrowthConfig.MaxFoodPerPurchase then
		return { Ok = false, Error = `You can buy between 1 and {GrowthConfig.MaxFoodPerPurchase} at once.` }
	end
	local cost = food.Price.Amount * quantity
	local balance = data.Currencies[food.Price.Currency] or 0
	if balance < cost then
		return { Ok = false, Error = `You need {cost} {food.Price.Currency} for that.` }
	end
	return { Ok = true, Currency = food.Price.Currency, Amount = cost }
end

return GrowthLogic
