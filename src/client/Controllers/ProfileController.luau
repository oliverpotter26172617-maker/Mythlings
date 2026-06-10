--!strict
-- Holds the latest sanitised profile snapshot pushed by the server and
-- notifies UI controllers when it changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.GoodSignal)
local NetClient = require(script.Parent.Parent.Lib.NetClient)

local ProfileController = {}

ProfileController.Changed = GoodSignal.new() -- (snapshot)

local snapshot: { [string]: any }? = nil

function ProfileController:OnStart()
	NetClient.On("ProfileSync", function(newSnapshot)
		snapshot = newSnapshot
		ProfileController.Changed:Fire(newSnapshot)
	end)

	-- The join push can land before this controller connects; pull the
	-- snapshot once at boot, retrying briefly while data loads.
	task.spawn(function()
		for _ = 1, 10 do
			if snapshot ~= nil then
				return
			end
			local response = NetClient.Invoke("RequestProfile")
			if response.Ok and snapshot == nil then
				snapshot = response.Data
				ProfileController.Changed:Fire(response.Data)
				return
			end
			task.wait(1)
		end
	end)
end

function ProfileController:Get(): { [string]: any }?
	return snapshot
end

function ProfileController:GetBalance(currency: string): number
	if snapshot == nil then
		return 0
	end
	return (snapshot :: any).Currencies[currency] or 0
end

return ProfileController
