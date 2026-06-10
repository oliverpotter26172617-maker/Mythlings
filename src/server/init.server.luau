--!strict
-- Mythlings server bootstrap.
-- Loads every Service module under Services/, calls OnInit on all of them,
-- then OnStart. Services must not yield in OnInit.

local services: { [string]: any } = {}

for _, child in script.Services:GetChildren() do
	if child:IsA("ModuleScript") then
		services[child.Name] = require(child) :: any
	end
end

for name, service in services do
	if type(service.OnInit) == "function" then
		local ok, err = pcall(service.OnInit, service)
		if not ok then
			error(`Mythlings: {name}.OnInit failed: {err}`)
		end
	end
end

for name, service in services do
	if type(service.OnStart) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.OnStart, service)
			if not ok then
				warn(`Mythlings: {name}.OnStart failed: {err}`)
			end
		end)
	end
end

print("Mythlings server started")
