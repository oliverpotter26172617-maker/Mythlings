--!strict
-- Spawns follower Mythling actors in the world. Performance model:
-- the server creates lightweight part-based actors (placeholder art until
-- modelled assets land) and hands network ownership to the owning player,
-- so follow physics costs the server nothing and replicates natively.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElementConfig = require(ReplicatedStorage.Shared.Config.ElementConfig)
local MythlingConfig = require(ReplicatedStorage.Shared.Config.MythlingConfig)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.PlayerConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)
local ActiveMythlingLogic = require(ReplicatedStorage.Shared.Logic.ActiveMythlingLogic)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local Net = require(script.Parent.Parent.Lib.Net)

local MythlingSpawnService = {}

local DataService
local actorsFolder: Folder

local activeActors: { [Player]: { Model } } = {}

local function buildActor(player: Player, mythlingId: string, record: { [string]: any }, slotIndex: number): Model
	local species = MythlingConfig.Species[record.SpeciesId]
	local scale = StatConfig.StageScales[record.Stage] or 1
	local elementColour = ElementConfig.Colours[species.Element]
	local rarityColour = RarityConfig.Colours[species.Rarity]

	local model = Instance.new("Model")
	model.Name = `Mythling_{player.UserId}_{mythlingId}`

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2, 2, 2) * scale
	body.Color = Color3.fromRGB(elementColour.R, elementColour.G, elementColour.B)
	body.Material = if record.Shiny then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Massless = true
	body.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0, 0)
	body.Parent = model

	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = body

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "FollowPosition"
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = 100000
	alignPosition.Responsiveness = PlayerConfig.FollowResponsiveness
	alignPosition.Parent = body

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "FollowOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 100000
	alignOrientation.Responsiveness = PlayerConfig.FollowResponsiveness
	alignOrientation.Parent = body

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 120, 0, 28)
	billboard.StudsOffset = Vector3.new(0, 1.6 * scale, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = if record.Shiny then `{species.DisplayName} (Shiny)` else species.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(rarityColour.R, rarityColour.G, rarityColour.B)
	nameLabel.Parent = billboard

	model.PrimaryPart = body
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("MythlingId", mythlingId)
	model:SetAttribute("SpeciesId", record.SpeciesId)
	model:SetAttribute("Stage", record.Stage)
	model:SetAttribute("FollowIndex", slotIndex)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		local x, z =
			ActiveMythlingLogic.formationOffset(slotIndex, PlayerConfig.FollowDistance, PlayerConfig.FollowSpacing)
		body.CFrame = rootPart.CFrame * CFrame.new(x, 0, z)
	end

	model.Parent = actorsFolder
	body:SetNetworkOwner(player)
	return model
end

local function despawnAll(player: Player)
	local actors = activeActors[player]
	if actors then
		for _, model in actors do
			model:Destroy()
		end
	end
	activeActors[player] = nil
end

-- Rebuilds the player's follower actors from their profile roster.
function MythlingSpawnService:RefreshFollowers(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	despawnAll(player)

	local actors = {}
	for slotIndex, mythlingId in data.ActiveMythlings do
		local record = data.Mythlings[mythlingId]
		if record ~= nil then
			table.insert(actors, buildActor(player, mythlingId, record, slotIndex))
		end
	end
	activeActors[player] = actors
end

function MythlingSpawnService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	actorsFolder = Instance.new("Folder")
	actorsFolder.Name = "MythlingActors"
	actorsFolder.Parent = workspace

	Net.HandleFunction(
		"SetActiveMythlings",
		{ Guard.arrayOf(Guard.string(16), PlayerConfig.MaxFollowers) },
		function(player, mythlingIds)
			local data = DataService:GetData(player)
			if data == nil then
				Net.Refuse("Your data is still loading. Please try again shortly.")
			end

			local result = ActiveMythlingLogic.validateRoster(data, mythlingIds, PlayerConfig.MaxFollowers)
			if not result.Ok then
				Net.Refuse(result.Error :: string)
			end

			data.ActiveMythlings = table.clone(mythlingIds)
			MythlingSpawnService:RefreshFollowers(player)
			DataService:Sync(player)
			return { Count = #mythlingIds }
		end
	)
end

function MythlingSpawnService:OnStart()
	DataService.ProfileLoaded:Connect(function(player)
		MythlingSpawnService:RefreshFollowers(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			MythlingSpawnService:RefreshFollowers(player)
		end)
	end)

	Players.PlayerRemoving:Connect(despawnAll)
end

return MythlingSpawnService
