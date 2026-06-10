--!strict
-- Egg purchasing. All validation and pricing comes from shared config and
-- pure logic; the client only ever names a tier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggShopLogic = require(ReplicatedStorage.Shared.Logic.EggShopLogic)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local Net = require(script.Parent.Parent.Lib.Net)

local EggService = {}

local DataService

function EggService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction("BuyEgg", { Guard.string(32) }, function(player, tierId)
		return EggService:BuyEgg(player, tierId)
	end)
end

function EggService:BuyEgg(player: Player, tierId: string): { [string]: any }
	local data = DataService:GetData(player)
	if data == nil then
		Net.Refuse("Your data is still loading. Please try again shortly.")
	end

	local check = EggShopLogic.validatePurchase(data, tierId)
	if not check.Ok then
		Net.Refuse(check.Error :: string)
	end

	local paid =
		DataService:MutateCurrency(player, check.Currency :: string, -(check.Amount :: number), `BuyEgg:{tierId}`)
	if not paid then
		Net.Refuse("You cannot afford this egg.")
	end

	local eggId = `E{data.NextEggId}`
	data.NextEggId += 1
	data.Eggs[eggId] = {
		Tier = tierId,
		ObtainedAt = os.time(),
		-- nil until the player starts incubating it.
		HatchesAt = nil,
	}

	DataService:Sync(player)

	return {
		EggId = eggId,
		Tier = tierId,
		DisplayName = EggConfig.Tiers[tierId].DisplayName,
	}
end

return EggService
