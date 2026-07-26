--!strict
-- New-player onboarding: grants the free Rare egg in the first minutes,
-- walks the guided steps and logs a funnel event at every stage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local OnboardingConfig = require(ReplicatedStorage.Shared.Config.OnboardingConfig)
local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)
local HatchLogic = require(ReplicatedStorage.Shared.Logic.HatchLogic)
local OnboardingLogic = require(ReplicatedStorage.Shared.Logic.OnboardingLogic)
local Analytics = require(script.Parent.Parent.Lib.Analytics)
local Grants = require(script.Parent.Parent.Lib.Grants)

local OnboardingService = {}

local DataService
local serverRandom = Random.new()

local function rng(): number
	return serverRandom:NextNumber()
end

-- Grants the free Rare starter egg while respecting the storage cap. Returns
-- true when it was stored; a full inventory (only possible for an already
-- established profile) simply defers the grant to a later join.
local function grantStarterEgg(data: { [string]: any }): boolean
	local speciesId = HatchLogic.pickSpecies(MythlingConfig.Species, "Rare", nil, 0.5, rng)
	local outcome = {
		SpeciesId = speciesId,
		Potential = HatchLogic.rollPotential(StatConfig.PotentialMin, StatConfig.PotentialMax, rng),
		Shiny = false,
	}
	return Grants.trySealedEgg(data, "Gift", OnboardingConfig.StarterEggHatchMinutes, outcome, os.time())
end

-- Called by QuestService whenever a metric fires, so onboarding rides the
-- same reporting pipeline as quests.
function OnboardingService:OnMetric(player: Player, metric: string)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local completed, justFinished = OnboardingLogic.onMetric(data, metric)
	for _, stepIndex in completed do
		local def = OnboardingConfig.Steps[stepIndex]
		Analytics.onboardingStep(player, stepIndex, def.Id)
	end
	if justFinished then
		DataService:MutateCurrency(player, "Coins", OnboardingConfig.CompletionCoins, "OnboardingComplete")
		Analytics.custom(player, "OnboardingComplete")
		DataService:Sync(player)
	end
end

function OnboardingService:OnInit()
	DataService = require(script.Parent.DataService) :: any
end

function OnboardingService:OnStart()
	DataService.ProfileLoaded:Connect(function(player)
		local data = DataService:GetData(player)
		if data == nil then
			return
		end
		if OnboardingLogic.start(data) then
			Analytics.onboardingStep(player, 1, OnboardingConfig.Steps[1].Id)
		end
		-- First-session generosity: the free Rare egg lands immediately,
		-- even for profiles that somehow skipped the flow.
		if not data.Flags.StarterEggGranted then
			if grantStarterEgg(data) then
				data.Flags.StarterEggGranted = true
				DataService:Sync(player)
			end
		end
	end)
end

return OnboardingService
