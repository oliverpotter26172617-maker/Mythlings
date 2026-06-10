--!strict
-- Live operations flags: LaunchConfig defaults overridden by a DataStore
-- document, polled once a minute. Flip a flag in the DataStore (via the
-- open cloud API or a Studio console) and every server applies it within
-- the polling window. DataStore failures fall back to current values.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LaunchConfig = require(ReplicatedStorage.Shared.Config.LaunchConfig)

local LiveConfig = {}

local overrides: { [string]: any } = {}
local started = false

local function poll()
	local ok, result = pcall(function()
		local store = DataStoreService:GetDataStore(LaunchConfig.LiveConfigStore)
		return store:GetAsync(LaunchConfig.LiveConfigKey)
	end)
	if ok and type(result) == "table" then
		overrides = result
	end
end

function LiveConfig.start()
	if started then
		return
	end
	started = true
	if RunService:IsStudio() then
		-- Studio play-tests use defaults only.
		return
	end
	task.spawn(function()
		while true do
			poll()
			task.wait(LaunchConfig.LiveConfigPollSeconds)
		end
	end)
end

function LiveConfig.get(flagName: string): any
	local override = overrides[flagName]
	if override ~= nil then
		return override
	end
	return (LaunchConfig :: any)[flagName]
end

return LiveConfig
