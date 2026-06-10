--!strict
-- Cosmetic purchases, equipping and the Battle Token Arena Shop. All
-- cosmetics are stat-neutral by type; nothing here is read by battles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConfig = require(ReplicatedStorage.Shared.Config.CosmeticConfig)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local CosmeticsLogic = require(ReplicatedStorage.Shared.Logic.CosmeticsLogic)
local RaidLogic = require(ReplicatedStorage.Shared.Logic.RaidLogic)
local Grants = require(script.Parent.Parent.Lib.Grants)
local Net = require(script.Parent.Parent.Lib.Net)

local CosmeticsService = {}

local DataService
local MythlingSpawnService

local function getDataOrRefuse(player: Player): { [string]: any }
	local data = DataService:GetData(player)
	if data == nil then
		Net.Refuse("Your data is still loading. Please try again shortly.")
	end
	return data :: any
end

function CosmeticsService:OnInit()
	DataService = require(script.Parent.DataService) :: any
	MythlingSpawnService = require(script.Parent.MythlingSpawnService) :: any

	Net.HandleFunction("BuyCosmetic", { Guard.string(32) }, function(player, cosmeticId)
		local data = getDataOrRefuse(player)
		local ok, message, price = CosmeticsLogic.validateBuy(data, cosmeticId)
		if not ok then
			Net.Refuse(message :: string)
		end
		if not DataService:MutateCurrency(player, "Gems", -(price :: number), `Cosmetic:{cosmeticId}`) then
			Net.Refuse("You cannot afford that.")
		end
		local def = CosmeticConfig.Catalogue[cosmeticId]
		local owned = if def.Layer == "Avatar" then data.Cosmetics.OwnedAvatar else data.Cosmetics.OwnedMythling
		owned[cosmeticId] = true
		DataService:Sync(player)
		return { CosmeticId = cosmeticId }
	end)

	Net.HandleFunction(
		"EquipAvatarCosmetic",
		{ Guard.string(16), Guard.optional(Guard.string(32)) },
		function(player, slot, cosmeticId)
			local data = getDataOrRefuse(player)
			local ok, message = CosmeticsLogic.validateEquip(data, "Avatar", slot, cosmeticId)
			if not ok then
				Net.Refuse(message :: string)
			end
			data.Cosmetics.EquippedAvatar[slot] = cosmeticId
			DataService:Sync(player)
			return { Slot = slot, CosmeticId = cosmeticId }
		end
	)

	Net.HandleFunction(
		"EquipMythlingCosmetic",
		{ Guard.string(16), Guard.string(16), Guard.optional(Guard.string(32)) },
		function(player, mythlingId, slot, cosmeticId)
			local data = getDataOrRefuse(player)
			local record = data.Mythlings[mythlingId]
			if record == nil then
				Net.Refuse("You do not own that Mythling.")
			end
			local ok, message = CosmeticsLogic.validateEquip(data, "Mythling", slot, cosmeticId)
			if not ok then
				Net.Refuse(message :: string)
			end
			record.Cosmetics[slot] = cosmeticId
			-- Respawn followers so auras and dyes show immediately.
			MythlingSpawnService:RefreshFollowers(player)
			DataService:Sync(player)
			return { MythlingId = mythlingId, Slot = slot, CosmeticId = cosmeticId }
		end
	)

	Net.HandleFunction("BuyArenaShopItem", { Guard.integer(1, 8) }, function(player, slotIndex)
		local data = getDataOrRefuse(player)
		local shop = CosmeticsLogic.arenaShopForWeek(RaidLogic.weekIndex(os.time()))
		local entry = shop[slotIndex]
		if entry == nil then
			Net.Refuse("That shop slot is empty this week.")
		end
		if entry.Type == "Cosmetic" then
			local def = CosmeticConfig.Catalogue[entry.Id]
			local owned = if def.Layer == "Avatar" then data.Cosmetics.OwnedAvatar else data.Cosmetics.OwnedMythling
			if owned[entry.Id] then
				Net.Refuse("You already own that.")
			end
		end
		if not DataService:MutateCurrency(player, "BattleTokens", -entry.PriceTokens, `ArenaShop:{entry.Id}`) then
			Net.Refuse(`You need {entry.PriceTokens} Battle Tokens for that.`)
		end

		local grantType: any = if entry.Type == "Cosmetic" then "Cosmetic" else entry.Type
		local granted = Grants.grant(
			DataService,
			player,
			data,
			{ Type = grantType, Id = entry.Id, Count = 1 },
			`ArenaShop:{entry.Id}`
		)
		DataService:Sync(player)
		return { Granted = granted }
	end)
end

return CosmeticsService
