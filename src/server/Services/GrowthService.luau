--!strict
-- Food shop, feeding and stage progression. XP is only ever granted here
-- and by the battle rewards engine; both run through GrowthLogic so stage
-- transitions are consistent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrowthConfig = require(ReplicatedStorage.Shared.Config.GrowthConfig)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local GrowthLogic = require(ReplicatedStorage.Shared.Logic.GrowthLogic)
local Net = require(script.Parent.Parent.Lib.Net)

local GrowthService = {}

local DataService
local MythlingSpawnService

local function getDataOrRefuse(player: Player): { [string]: any }
	local data = DataService:GetData(player)
	if data == nil then
		Net.Refuse("Your data is still loading. Please try again shortly.")
	end
	return data :: any
end

-- Grants XP to an owned Mythling and handles stage-up side effects.
-- Shared with the battle rewards engine (Phase 3).
function GrowthService:GrantXp(player: Player, mythlingId: string, amount: number): { [string]: any }?
	local data = DataService:GetData(player)
	if data == nil then
		return nil
	end
	local record = data.Mythlings[mythlingId]
	if record == nil then
		return nil
	end

	local result = GrowthLogic.addXp(record.Xp, record.Stage, amount)
	record.Xp = result.NewXp
	record.Stage = result.NewStage

	if #result.StagesGained > 0 then
		-- Respawn followers so the actor scale matches the new stage, and
		-- tell the client to play the stage-up moment.
		MythlingSpawnService:RefreshFollowers(player)
		Net.FireClient("StageUpEffect", player, {
			MythlingId = mythlingId,
			SpeciesId = record.SpeciesId,
			Stages = result.StagesGained,
		})
	end

	return result
end

function GrowthService:OnInit()
	DataService = require(script.Parent.DataService) :: any
	MythlingSpawnService = require(script.Parent.MythlingSpawnService) :: any

	Net.HandleFunction(
		"BuyFood",
		{ Guard.string(32), Guard.integer(1, GrowthConfig.MaxFoodPerPurchase) },
		function(player, foodId, quantity)
			local data = getDataOrRefuse(player)

			local check = GrowthLogic.validateFoodPurchase(data, foodId, quantity)
			if not check.Ok then
				Net.Refuse(check.Error :: string)
			end

			local paid = DataService:MutateCurrency(
				player,
				check.Currency :: string,
				-(check.Amount :: number),
				`BuyFood:{foodId}`
			)
			if not paid then
				Net.Refuse("You cannot afford that.")
			end

			data.Inventory.Food[foodId] = (data.Inventory.Food[foodId] or 0) + quantity
			DataService:Sync(player)
			return { FoodId = foodId, Owned = data.Inventory.Food[foodId] }
		end
	)

	Net.HandleFunction("FeedMythling", { Guard.string(16), Guard.string(32) }, function(player, mythlingId, foodId)
		local data = getDataOrRefuse(player)

		local record = data.Mythlings[mythlingId]
		if record == nil then
			Net.Refuse("You do not own that Mythling.")
		end

		local food = GrowthConfig.Food[foodId]
		if food == nil then
			Net.Refuse("That food does not exist.")
		end

		local owned = data.Inventory.Food[foodId] or 0
		if owned < 1 then
			Net.Refuse("You do not have any of that food. Visit the food shop first.")
		end

		data.Inventory.Food[foodId] = owned - 1
		local result = GrowthService:GrantXp(player, mythlingId, food.Xp)

		DataService:Sync(player)
		return {
			MythlingId = mythlingId,
			NewXp = (result :: any).NewXp,
			NewStage = (result :: any).NewStage,
			StagesGained = (result :: any).StagesGained,
		}
	end)
end

return GrowthService
