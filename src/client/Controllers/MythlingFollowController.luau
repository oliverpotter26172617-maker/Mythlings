--!strict
-- Drives follow targets for the local player's Mythling actors. The server
-- gives us network ownership, so updating AlignPosition goals here is
-- authoritative for physics and replicates to everyone at no server cost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActiveMythlingLogic = require(ReplicatedStorage.Shared.Logic.ActiveMythlingLogic)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)

local MythlingFollowController = {}

local localPlayer = Players.LocalPlayer
local tracked: { [Model]: BasePart } = {}

local function watchFolder(folder: Instance)
	local function tryTrack(child: Instance)
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == localPlayer.UserId then
			local body = child:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				tracked[child] = body
			end
		end
	end

	for _, child in folder:GetChildren() do
		tryTrack(child)
	end
	folder.ChildAdded:Connect(function(child)
		-- Attributes and children replicate just after the model itself.
		task.defer(tryTrack, child)
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			tracked[child] = nil
		end
	end)
end

function MythlingFollowController:OnStart()
	task.spawn(function()
		local folder = workspace:WaitForChild("MythlingActors", 30)
		if folder then
			watchFolder(folder)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart == nil then
			return
		end

		for model, body in tracked do
			if model.Parent == nil then
				tracked[model] = nil
				continue
			end
			local slotIndex = model:GetAttribute("FollowIndex") or 1
			local x, z =
				ActiveMythlingLogic.formationOffset(slotIndex, PlayerConfig.FollowDistance, PlayerConfig.FollowSpacing)
			local target = rootPart.CFrame * CFrame.new(x, 0, z)

			local alignPosition = body:FindFirstChild("FollowPosition") :: AlignPosition?
			local alignOrientation = body:FindFirstChild("FollowOrientation") :: AlignOrientation?
			if alignPosition then
				alignPosition.Position = target.Position + Vector3.new(0, 1.5, 0)
			end
			if alignOrientation then
				alignOrientation.CFrame = CFrame.lookAt(target.Position, target.Position + rootPart.CFrame.LookVector)
			end
		end
	end)
end

return MythlingFollowController
