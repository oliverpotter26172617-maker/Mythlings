--!strict
-- Shared item granting for reward systems (battle pass, chests, quests).
-- Returns the list of what was actually granted (egg drops fall back to
-- Coins when storage is full).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)
local RaidConfig = require(ReplicatedStorage.Shared.Config.RaidConfig)

local Grants = {}

export type GrantItem = {
	Type: "Coins" | "Gems" | "Food" | "Egg" | "Cosmetic",
	Id: string?,
	Count: number,
}

function Grants.grant(
	dataService: any,
	player: Player,
	data: { [string]: any },
	item: GrantItem,
	reason: string
): GrantItem
	if item.Type == "Coins" then
		dataService:MutateCurrency(player, "Coins", item.Count, reason)
		return item
	elseif item.Type == "Gems" then
		dataService:MutateCurrency(player, "Gems", item.Count, reason)
		return item
	elseif item.Type == "Food" then
		data.Inventory.Food[item.Id] = (data.Inventory.Food[item.Id] or 0) + item.Count
		return item
	elseif item.Type == "Cosmetic" then
		data.Cosmetics.OwnedMythling[item.Id] = true
		return item
	elseif item.Type == "Egg" then
		local eggCount = 0
		for _ in data.Eggs do
			eggCount += 1
		end
		if eggCount < PlayerConfig.MaxStoredEggs then
			local eggId = `E{data.NextEggId}`
			data.NextEggId += 1
			data.Eggs[eggId] = { Tier = item.Id, ObtainedAt = os.time(), HatchesAt = nil }
			return item
		end
		local fallback: GrantItem = { Type = "Coins", Id = nil, Count = RaidConfig.EggFallbackCoins }
		dataService:MutateCurrency(player, "Coins", fallback.Count, reason .. ":EggFallback")
		return fallback
	end
	error(`Grants.grant: unknown item type {item.Type}`)
end

return Grants
