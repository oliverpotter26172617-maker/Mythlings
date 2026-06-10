--!strict
-- Onboarding step progression. Pure Luau.
-- Flags.OnboardingStep holds the index of the step the player is ON;
-- 0 means not started, a value past the last step means completed.

local OnboardingConfig = require(script.Parent.Parent.Config.OnboardingConfig)

local OnboardingLogic = {}

function OnboardingLogic.isComplete(step: number): boolean
	return step > #OnboardingConfig.Steps
end

function OnboardingLogic.currentStep(step: number): OnboardingConfig.StepDef?
	return OnboardingConfig.Steps[step]
end

-- Starts the flow for a fresh profile. Returns true if it started.
function OnboardingLogic.start(data: { [string]: any }): boolean
	if data.Flags.OnboardingStep ~= 0 then
		return false
	end
	-- Step 1 (Welcome) has no trigger; the player begins on step 2.
	data.Flags.OnboardingStep = 2
	return true
end

-- Advances the flow when a metric fires. Returns the list of step indexes
-- completed by this event (usually zero or one) and whether the whole
-- flow just completed.
function OnboardingLogic.onMetric(data: { [string]: any }, metric: string): ({ number }, boolean)
	local completed = {}
	local step = data.Flags.OnboardingStep
	if step == 0 or OnboardingLogic.isComplete(step) then
		return completed, false
	end

	local def = OnboardingConfig.Steps[step]
	if def ~= nil and def.CompletedBy == metric then
		table.insert(completed, step)
		data.Flags.OnboardingStep = step + 1
	end

	local justFinished = OnboardingLogic.isComplete(data.Flags.OnboardingStep) and #completed > 0
	return completed, justFinished
end

return OnboardingLogic
