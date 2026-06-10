--!strict
-- Cosmetic purchase/equip rules and the Arena Shop rotation. Pure Luau.

local ArenaShopConfig = require(script.Parent.Parent.Config.ArenaShopConfig)
local CosmeticConfig = require(script.Parent.Parent.Config.CosmeticConfig)

local CosmeticsLogic = {}

function CosmeticsLogic.validateBuy(data: { [string]: any }, cosmeticId: string): (boolean, string?, number?)
	local def = CosmeticConfig.Catalogue[cosmeticId]
	if def == nil then
		return false, "That cosmetic does not exist.", nil
	end
	if def.PriceGems == nil then
		return false, "That cosmetic cannot be bought directly. Earn it in the arena!", nil
	end
	local owned = if def.Layer == "Avatar" then data.Cosmetics.OwnedAvatar else data.Cosmetics.OwnedMythling
	if owned[cosmeticId] then
		return false, "You already own that.", nil
	end
	if (data.Currencies.Gems or 0) < def.PriceGems then
		return false, `You need {def.PriceGems} Gems for that.`, nil
	end
	return true, nil, def.PriceGems
end

-- Equip nil to clear a slot. Equipping validates layer, slot and ownership.
function CosmeticsLogic.validateEquip(
	data: { [string]: any },
	layer: "Avatar" | "Mythling",
	slot: string,
	cosmeticId: string?
): (boolean, string?)
	local slots = if layer == "Avatar" then CosmeticConfig.AvatarSlots else CosmeticConfig.MythlingSlots
	if table.find(slots, slot) == nil then
		return false, "That is not a valid cosmetic slot."
	end
	if cosmeticId == nil then
		return true, nil
	end
	local def = CosmeticConfig.Catalogue[cosmeticId]
	if def == nil or def.Layer ~= layer or def.Slot ~= slot then
		return false, "That cosmetic does not fit there."
	end
	local owned = if layer == "Avatar" then data.Cosmetics.OwnedAvatar else data.Cosmetics.OwnedMythling
	if not owned[cosmeticId] then
		return false, "You do not own that cosmetic."
	end
	return true, nil
end

-- This week's Arena Shop slots, rotating deterministically over the pool.
function CosmeticsLogic.arenaShopForWeek(weekIndex: number): { ArenaShopConfig.ShopEntry }
	local pool = ArenaShopConfig.Pool
	local slots = {}
	for slot = 0, ArenaShopConfig.SlotsPerWeek - 1 do
		slots[slot + 1] = pool[(weekIndex * ArenaShopConfig.SlotsPerWeek + slot) % #pool + 1]
	end
	return slots
end

return CosmeticsLogic
