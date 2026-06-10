--!strict
-- Persists client settings toggles into the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local Net = require(script.Parent.Parent.Lib.Net)

local SettingsService = {}

local DataService

local SETTING_KEYS = { "Music", "Sfx", "LowQuality" }

function SettingsService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	Net.HandleFunction("UpdateSetting", { Guard.oneOf(SETTING_KEYS), Guard.boolean() }, function(player, key, value)
		local data = DataService:GetData(player)
		if data == nil then
			Net.Refuse("Your data is still loading. Please try again shortly.")
		end
		data.Settings[key] = value
		DataService:Sync(player)
		return { Key = key, Value = value }
	end)
end

return SettingsService
