--!strict
-- Weekly Premium Nursery rotation and purchase validation. Pure Luau.

local MythlingConfig = require(script.Parent.Parent.Config.MythlingConfig)
local NurseryConfig = require(script.Parent.Parent.Config.NurseryConfig)

local NurseryLogic = {}

export type Offer = {
	SpeciesId: string,
	Rarity: string,
	PriceGems: number,
}

-- Deterministic weekly rotation over the pools; no stored state.
function NurseryLogic.offersForWeek(weekIndex: number): { Offer }
	local offers: { Offer } = {}

	local epicCount = #NurseryConfig.EpicPool
	for slot = 0, NurseryConfig.EpicsPerWeek - 1 do
		local speciesId = NurseryConfig.EpicPool[(weekIndex * NurseryConfig.EpicsPerWeek + slot) % epicCount + 1]
		table.insert(offers, {
			SpeciesId = speciesId,
			Rarity = MythlingConfig.Species[speciesId].Rarity,
			PriceGems = NurseryConfig.Prices[MythlingConfig.Species[speciesId].Rarity],
		})
	end

	local legendaryCount = #NurseryConfig.LegendaryPool
	for slot = 0, NurseryConfig.LegendariesPerWeek - 1 do
		local speciesId = NurseryConfig.LegendaryPool[(weekIndex + slot) % legendaryCount + 1]
		table.insert(offers, {
			SpeciesId = speciesId,
			Rarity = MythlingConfig.Species[speciesId].Rarity,
			PriceGems = NurseryConfig.Prices[MythlingConfig.Species[speciesId].Rarity],
		})
	end

	return offers
end

function NurseryLogic.validatePurchase(
	data: { [string]: any },
	offers: { Offer },
	offerIndex: number,
	storageLimit: number
): { Ok: boolean, Error: string?, Offer: Offer? }
	local offer = offers[offerIndex]
	if offer == nil then
		return { Ok = false, Error = "That Nursery offer is not available this week." }
	end

	local count = 0
	for _ in data.Mythlings do
		count += 1
	end
	if count >= storageLimit then
		return { Ok = false, Error = "Your Mythling storage is full." }
	end

	if (data.Currencies.Gems or 0) < offer.PriceGems then
		return { Ok = false, Error = `You need {offer.PriceGems} Gems for this Mythling.` }
	end

	return { Ok = true, Offer = offer }
end

return NurseryLogic
