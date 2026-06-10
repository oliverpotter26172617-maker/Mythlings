--!strict
-- Plays the stage-up moment: a particle burst on the Mythling's actor and
-- a celebratory toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local NetClient = require(script.Parent.Parent.Lib.NetClient)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local GrowthController = {}

local localPlayer = Players.LocalPlayer

local function findActor(mythlingId: string): Model?
	local folder = workspace:FindFirstChild("MythlingActors")
	if folder == nil then
		return nil
	end
	for _, child in folder:GetChildren() do
		if
			child:IsA("Model")
			and child:GetAttribute("OwnerUserId") == localPlayer.UserId
			and child:GetAttribute("MythlingId") == mythlingId
		then
			return child
		end
	end
	return nil
end

local function playBurst(actor: Model)
	local body = actor:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(6, 10)
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = body
	emitter:Emit(40)
	Debris:AddItem(emitter, 2)
end

local function showToast(text: string)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local toastGui = UIKit.create("ScreenGui", { Name = "StageUpToast", ResetOnSpawn = false })
	toastGui.Parent = playerGui

	local label = UIKit.label(text, 20, {
		Size = UDim2.new(0.4, 0, 0, 44),
		Position = UDim2.new(0.3, 0, 0.12, 0),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = UIKit.Palette.Panel,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Palette.Accent,
	})
	UIKit.rounded(10).Parent = label
	label.Parent = toastGui
	Debris:AddItem(toastGui, 3)
end

function GrowthController:OnStart()
	NetClient.On("StageUpEffect", function(payload)
		if type(payload) ~= "table" then
			return
		end
		local species = MythlingConfig.Species[payload.SpeciesId]
		local displayName = species and species.DisplayName or "Your Mythling"
		local finalStage = payload.Stages[#payload.Stages]
		showToast(`{displayName} grew into a {finalStage}!`)

		local actor = findActor(payload.MythlingId)
		if actor then
			playBurst(actor)
		end
	end)
end

return GrowthController
