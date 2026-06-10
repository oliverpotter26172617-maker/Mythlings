--!strict
-- Incubation and hatching. Timers are pure timestamps (os.time), so eggs
-- keep progressing while the player is offline and across servers. All
-- rolls happen here on the server with EggConfig odds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)
local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local HatchLogic = require(ReplicatedStorage.Shared.Logic.HatchLogic)
local MythlingFactory = require(ReplicatedStorage.Shared.Logic.MythlingFactory)
local Net = require(script.Parent.Parent.Lib.Net)

local HatchService = {}

local DataService
local serverRandom = Random.new()

local function rng(): number
	return serverRandom:NextNumber()
end

local function getDataOrRefuse(player: Player): { [string]: any }
	local data = DataService:GetData(player)
	if data == nil then
		Net.Refuse("Your data is still loading. Please try again shortly.")
	end
	return data :: any
end

local function getOwnedEgg(data: { [string]: any }, eggId: string): { [string]: any }
	local egg = data.Eggs[eggId]
	if egg == nil then
		Net.Refuse("You do not own that egg.")
	end
	return egg
end

local function incubationSlots(data: { [string]: any }): number
	if data.Passes.TripleHatch then
		return PlayerConfig.TripleHatchSlots
	end
	return PlayerConfig.BaseIncubationSlots
end

local function incubatingCount(data: { [string]: any }): number
	local count = 0
	for _, egg in data.Eggs do
		if egg.HatchesAt ~= nil then
			count += 1
		end
	end
	return count
end

local function mythlingStorageLimit(data: { [string]: any }): number
	local limit = PlayerConfig.BaseMythlingStorage
	if data.Passes.ExtraStorage then
		limit += PlayerConfig.PassExtraSlots
	end
	return limit
end

local function mythlingCount(data: { [string]: any }): number
	local count = 0
	for _ in data.Mythlings do
		count += 1
	end
	return count
end

-- Rolls the hatch, writes the Mythling, removes the egg and updates pity.
-- Callers must have verified the egg is finished.
local function resolveHatch(player: Player, data: { [string]: any }, eggId: string): { [string]: any }
	local egg = data.Eggs[eggId]
	local tier = EggConfig.Tiers[egg.Tier]

	if mythlingCount(data) >= mythlingStorageLimit(data) then
		Net.Refuse("Your Mythling storage is full.")
	end

	local pity = data.PityCounters[egg.Tier] or 0
	local result = HatchLogic.hatch({
		Odds = tier.Odds,
		ElementBias = tier.ElementBias,
		BiasWeight = EggConfig.ElementBiasWeight,
		Catalogue = MythlingConfig.Species,
		PityCount = pity,
		PityThreshold = EggConfig.PityThreshold,
		PityMinRarity = EggConfig.PityMinRarity,
		PotentialMin = StatConfig.PotentialMin,
		PotentialMax = StatConfig.PotentialMax,
		Rng = rng,
	})

	data.PityCounters[egg.Tier] = result.NewPityCount
	data.Stats.TotalHatches += 1
	data.Eggs[eggId] = nil

	local mythlingId = `M{data.NextMythlingId}`
	data.NextMythlingId += 1
	data.Mythlings[mythlingId] = MythlingFactory.create({
		SpeciesId = result.SpeciesId,
		Potential = result.Potential,
		Now = os.time(),
	})

	DataService:Sync(player)

	-- Potential stays hidden: the reveal payload omits it deliberately.
	return {
		MythlingId = mythlingId,
		SpeciesId = result.SpeciesId,
		DisplayName = MythlingConfig.Species[result.SpeciesId].DisplayName,
		Rarity = result.Rarity,
		Element = MythlingConfig.Species[result.SpeciesId].Element,
		PityTriggered = result.PityTriggered,
	}
end

function HatchService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction("StartIncubation", { Guard.string(16) }, function(player, eggId)
		local data = getDataOrRefuse(player)
		local egg = getOwnedEgg(data, eggId)
		if egg.HatchesAt ~= nil then
			Net.Refuse("That egg is already incubating.")
		end
		if incubatingCount(data) >= incubationSlots(data) then
			Net.Refuse("All your incubation slots are busy.")
		end
		local tier = EggConfig.Tiers[egg.Tier]
		egg.HatchesAt = os.time() + tier.HatchMinutes * 60
		DataService:Sync(player)
		return { EggId = eggId, HatchesAt = egg.HatchesAt }
	end)

	Net.HandleFunction("ClaimHatch", { Guard.string(16) }, function(player, eggId)
		local data = getDataOrRefuse(player)
		local egg = getOwnedEgg(data, eggId)
		if egg.HatchesAt == nil then
			Net.Refuse("That egg is not incubating yet.")
		end
		if os.time() < egg.HatchesAt then
			Net.Refuse("That egg is not ready yet.")
		end
		return resolveHatch(player, data, eggId)
	end)

	Net.HandleFunction("InstantFinishHatch", { Guard.string(16) }, function(player, eggId)
		local data = getDataOrRefuse(player)
		local egg = getOwnedEgg(data, eggId)
		if egg.HatchesAt == nil then
			Net.Refuse("That egg is not incubating yet.")
		end

		-- Check storage before charging so Gems are never wasted.
		if mythlingCount(data) >= mythlingStorageLimit(data) then
			Net.Refuse("Your Mythling storage is full.")
		end

		local remaining = egg.HatchesAt - os.time()
		local cost = HatchLogic.instantFinishCost(remaining, EggConfig.InstantHatchGemsPerMinute)
		if cost > 0 then
			local paid = DataService:MutateCurrency(player, "Gems", -cost, `InstantHatch:{egg.Tier}`)
			if not paid then
				Net.Refuse(`You need {cost} Gems to finish this hatch now.`)
			end
		end

		egg.HatchesAt = os.time()
		return resolveHatch(player, data, eggId)
	end)
end

return HatchService
