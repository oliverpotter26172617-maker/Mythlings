--!strict
-- Breeding: pairs two Adult+ Mythlings into a bred egg whose contents are
-- rolled server-side at breed time and stored privately on the egg record
-- (ProfileSanitiser strips them from client syncs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BreedingConfig = require(ReplicatedStorage.Shared.Config.BreedingConfig)
local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)
local BreedingLogic = require(ReplicatedStorage.Shared.Logic.BreedingLogic)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local Net = require(script.Parent.Parent.Lib.Net)

local BreedingService = {}

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

function BreedingService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction("BreedMythlings", { Guard.string(16), Guard.string(16) }, function(player, idA, idB)
		local data = getDataOrRefuse(player)
		local now = os.time()

		local check = BreedingLogic.validateBreed(data, idA, idB, now, PlayerConfig.MaxStoredEggs)
		if not check.Ok then
			Net.Refuse(check.Error :: string)
		end

		local parentA = data.Mythlings[idA]
		local parentB = data.Mythlings[idB]

		local offspring = BreedingLogic.breed(
			{ Element = parentA.Element, Rarity = parentA.Rarity, Potential = parentA.Potential },
			{ Element = parentB.Element, Rarity = parentB.Rarity, Potential = parentB.Potential },
			MythlingConfig.Species,
			rng
		)

		local cooldownSeconds = BreedingConfig.CooldownHours * 3600
		parentA.BreedCooldownUntil = now + cooldownSeconds
		parentB.BreedCooldownUntil = now + cooldownSeconds

		local eggId = `E{data.NextEggId}`
		data.NextEggId += 1
		data.Eggs[eggId] = {
			Tier = "Bred",
			ObtainedAt = now,
			HatchesAt = nil,
			HatchMinutes = BreedingConfig.BredEggHatchMinutes,
			ParentSpecies = { parentA.SpeciesId, parentB.SpeciesId },
			-- Hidden from clients by ProfileSanitiser.
			Outcome = {
				SpeciesId = offspring.SpeciesId,
				Potential = offspring.Potential,
				Shiny = offspring.Shiny,
			},
		}

		data.Stats.TotalBreeds += 1
		DataService:Sync(player)

		-- The surprise stays sealed: no species or rarity in the response.
		return {
			EggId = eggId,
			HatchMinutes = BreedingConfig.BredEggHatchMinutes,
			CooldownUntil = parentA.BreedCooldownUntil,
		}
	end)

	Net.HandleFunction("SkipBreedCooldown", { Guard.string(16) }, function(player, mythlingId)
		local data = getDataOrRefuse(player)
		local record = data.Mythlings[mythlingId]
		if record == nil then
			Net.Refuse("You do not own that Mythling.")
		end

		local now = os.time()
		local remaining = record.BreedCooldownUntil - now
		local cost = BreedingLogic.skipCost(remaining)
		if cost <= 0 then
			Net.Refuse("That Mythling is already rested.")
		end

		local paid = DataService:MutateCurrency(player, "Gems", -cost, "SkipBreedCooldown")
		if not paid then
			Net.Refuse(`You need {cost} Gems to skip this rest.`)
		end

		record.BreedCooldownUntil = now
		DataService:Sync(player)
		return { MythlingId = mythlingId, Cost = cost }
	end)
end

return BreedingService
