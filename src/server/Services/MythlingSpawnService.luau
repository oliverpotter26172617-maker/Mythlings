--!strict
-- Spawns follower Mythling actors in the world. Performance model:
-- the server creates lightweight part-based actors (placeholder art until
-- modelled assets land) and hands network ownership to the owning player,
-- so follow physics costs the server nothing and replicates natively.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConfig = require(ReplicatedStorage.Shared.Config.CosmeticConfig)
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

-- Welds a cheap decorative part onto the body. All features share the
-- same render flags as the body and never collide.
local function weldFeature(body: BasePart, props: { [string]: any }, offset: CFrame): Part
	local feature = Instance.new("Part")
	feature.Anchored = false
	feature.CanCollide = false
	feature.CanTouch = false
	feature.CanQuery = false
	feature.CastShadow = false
	feature.Massless = true
	for key, value in props do
		(feature :: any)[key] = value
	end
	feature.CFrame = body.CFrame * offset
	feature.Parent = body.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = feature
	weld.Parent = feature
	return feature
end

-- Turns the base sphere into a readable critter: two eyes facing forward
-- plus one accent shaped by element. Placeholder art, five parts max.
local function addCritterFeatures(body: BasePart, scale: number, element: string)
	for _, side in { -1, 1 } do
		local eye = weldFeature(body, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.5, 0.5, 0.5) * scale,
			Color = Color3.fromRGB(250, 250, 250),
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(side * 0.4 * scale, 0.3 * scale, -0.85 * scale))
		weldFeature(eye, {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.22, 0.22, 0.22) * scale,
			Color = Color3.fromRGB(20, 20, 24),
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(0, 0, -0.18 * scale))
	end

	if element == "Flame" or element == "Storm" then
		-- Spiky crest.
		weldFeature(body, {
			Name = "Crest",
			Size = Vector3.new(0.3, 0.9, 0.3) * scale,
			Color = body.Color,
			Material = Enum.Material.Neon,
		}, CFrame.new(0, 1.05 * scale, 0) * CFrame.Angles(0, 0, math.rad(8)))
	elseif element == "Tide" then
		-- Back fin.
		weldFeature(body, {
			Name = "Fin",
			Size = Vector3.new(0.2, 0.8, 1.1) * scale,
			Color = body.Color,
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(0, 0.8 * scale, 0.4 * scale) * CFrame.Angles(math.rad(-20), 0, 0))
	elseif element == "Terra" then
		-- Rocky brow.
		weldFeature(body, {
			Name = "Brow",
			Size = Vector3.new(1.4, 0.35, 0.5) * scale,
			Color = Color3.fromRGB(110, 100, 90),
			Material = Enum.Material.Slate,
		}, CFrame.new(0, 0.75 * scale, -0.5 * scale))
	else
		-- Shadow and Radiant get a floating halo mote.
		weldFeature(body, {
			Name = "Mote",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.35, 0.35) * scale,
			Color = body.Color,
			Material = Enum.Material.Neon,
		}, CFrame.new(0, 1.4 * scale, 0))
	end
end

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
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = false
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

	addCritterFeatures(body, scale, species.Element)

	-- Cosmetic visuals: purely decorative, never read by battle code.
	local cosmetics = record.Cosmetics or {}
	local dye = cosmetics.Dye and CosmeticConfig.Catalogue[cosmetics.Dye]
	if dye and dye.Colour and record.Shiny then
		body.Color = Color3.fromRGB(dye.Colour.R, dye.Colour.G, dye.Colour.B)
	end
	local aura = cosmetics.Aura and CosmeticConfig.Catalogue[cosmetics.Aura]
	if aura and aura.Colour then
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = Color3.fromRGB(aura.Colour.R, aura.Colour.G, aura.Colour.B)
		light.Range = 10
		light.Brightness = 2
		light.Parent = body
	end
	if cosmetics.Hat and CosmeticConfig.Catalogue[cosmetics.Hat] then
		local hat = Instance.new("Part")
		hat.Name = "Hat"
		hat.Shape = Enum.PartType.Cylinder
		hat.Size = Vector3.new(0.4, 1.2, 1.2) * scale
		hat.Color = Color3.fromRGB(40, 40, 48)
		hat.CanCollide = false
		hat.Massless = true
		hat.CFrame = body.CFrame * CFrame.new(0, 1.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
		hat.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = hat
		weld.Parent = hat
	end

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
			if #mythlingIds > 0 then
				(require(script.Parent.QuestService) :: any):ReportProgress(player, "TeamSet", 1)
			end
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
