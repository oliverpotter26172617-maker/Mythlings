--!strict
-- Mythlings client bootstrap.
-- Loads every Controller module under Controllers/, calls OnInit then OnStart.

local controllers: { [string]: any } = {}

for _, child in script.Controllers:GetChildren() do
	if child:IsA("ModuleScript") then
		controllers[child.Name] = require(child) :: any
	end
end

for name, controller in controllers do
	if type(controller.OnInit) == "function" then
		local ok, err = pcall(controller.OnInit, controller)
		if not ok then
			warn(`Mythlings: {name}.OnInit failed: {err}`)
		end
	end
end

for name, controller in controllers do
	if type(controller.OnStart) == "function" then
		task.spawn(function()
			local ok, err = pcall(controller.OnStart, controller)
			if not ok then
				warn(`Mythlings: {name}.OnStart failed: {err}`)
			end
		end)
	end
end

print("Mythlings client started")
