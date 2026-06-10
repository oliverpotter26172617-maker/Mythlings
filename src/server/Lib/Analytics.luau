--!strict
-- Thin wrapper over Roblox AnalyticsService. Every call is pcall-guarded
-- so analytics can never break gameplay, and every Gem source and sink
-- flows through logEconomy.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

function Analytics.funnelStep(player: Player, funnelName: string, step: number, stepName: string)
	pcall(function()
		(AnalyticsService :: any):LogFunnelStepEvent(player, funnelName, nil, step, stepName)
	end)
end

function Analytics.onboardingStep(player: Player, step: number, stepName: string)
	pcall(function()
		(AnalyticsService :: any):LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- flowType: "Source" or "Sink".
function Analytics.economy(
	player: Player,
	flowType: string,
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	sku: string?
)
	pcall(function()
		local flow = if flowType == "Source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		local service = AnalyticsService :: any
		service:LogEconomyEvent(player, flow, currency, math.abs(amount), endingBalance, transactionType, sku)
	end)
end

function Analytics.custom(player: Player, eventName: string, value: number?)
	pcall(function()
		(AnalyticsService :: any):LogCustomEvent(player, eventName, value)
	end)
end

return Analytics
