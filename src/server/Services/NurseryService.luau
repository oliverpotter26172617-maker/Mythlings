--!strict
-- Premium Nursery purchases. Offers derive from the unix week (pure
-- NurseryLogic) so client and server always agree on the rotation, and
-- every purchase flows through the same MythlingFactory and Potential
-- roll as a hatch, keeping the stat ceiling identical to the free path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)
local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local MythlingFactory = require(ReplicatedStorage.Shared.Logic.MythlingFactory)
local NurseryLogic = require(ReplicatedStorage.Shared.Logic.NurseryLogic)
local RaidLogic = require(ReplicatedStorage.Shared.Logic.RaidLogic)
local Net = require(script.Parent.Parent.Lib.Net)

local NurseryService = {}

local DataService
local serverRandom = Random.new()

local function storageLimit(data: { [string]: any }): number
	local limit = PlayerConfig.BaseMythlingStorage
	if data.Passes.ExtraStorage then
		limit += PlayerConfig.PassExtraSlots
	end
	return limit
end

function NurseryService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction("BuyNurseryMythling", { Guard.integer(1, 8) }, function(player, offerIndex)
		local data = DataService:GetData(player)
		if data == nil then
			Net.Refuse("Your data is still loading. Please try again shortly.")
		end

		local offers = NurseryLogic.offersForWeek(RaidLogic.weekIndex(os.time()))
		local check = NurseryLogic.validatePurchase(data, offers, offerIndex, storageLimit(data))
		if not check.Ok then
			Net.Refuse(check.Error :: string)
		end
		local offer = check.Offer :: NurseryLogic.Offer

		local paid = DataService:MutateCurrency(player, "Gems", -offer.PriceGems, `Nursery:{offer.SpeciesId}`)
		if not paid then
			Net.Refuse("You cannot afford that Mythling.")
		end

		-- Same Potential roll as hatching: no purchased stat advantage.
		local potential = serverRandom:NextInteger(StatConfig.PotentialMin, StatConfig.PotentialMax)

		local mythlingId = `M{data.NextMythlingId}`
		data.NextMythlingId += 1
		data.Mythlings[mythlingId] = MythlingFactory.create({
			SpeciesId = offer.SpeciesId,
			Potential = potential,
			Now = os.time(),
		})

		DataService:Sync(player)
		return {
			MythlingId = mythlingId,
			SpeciesId = offer.SpeciesId,
			Rarity = offer.Rarity,
		}
	end)
end

return NurseryService
