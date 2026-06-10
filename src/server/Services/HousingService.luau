--!strict
-- Player plots: allocation in the neighbourhood, size upgrades, themes,
-- grid-snap furniture with full server validation, and rendering of the
-- persisted layout. Furniture art is placeholder parts sized from config.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HousingConfig = require(ReplicatedStorage.Shared.Config.HousingConfig)
local MonetisationConfig = require(ReplicatedStorage.Shared.Config.MonetisationConfig)
local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local HousingLogic = require(ReplicatedStorage.Shared.Logic.HousingLogic)
local IncomeLogic = require(ReplicatedStorage.Shared.Logic.IncomeLogic)
local MonetisationLogic = require(ReplicatedStorage.Shared.Logic.MonetisationLogic)
local Net = require(script.Parent.Parent.Lib.Net)

local HousingService = {}

local DataService

local plotsFolder: Folder
local plotSlots: { [Player]: number } = {}
local plotModels: { [Player]: Model } = {}
local usedSlots: { [number]: boolean } = {}

local function slotOrigin(slot: number): Vector3
	local row = math.floor((slot - 1) / HousingConfig.PlotsPerRow)
	local column = (slot - 1) % HousingConfig.PlotsPerRow
	-- Neighbourhood sits away from the main spawn area.
	return Vector3.new(
		1000 + column * HousingConfig.PlotSpacing,
		HousingConfig.PlotBaseHeight,
		1000 + row * HousingConfig.PlotSpacing
	)
end

local function renderFurniture(player: Player, plotModel: Model, data: { [string]: any })
	local existing = plotModel:FindFirstChild("Furniture")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Furniture"
	folder.Parent = plotModel

	local origin = slotOrigin(plotSlots[player] :: number)
	local grid = HousingConfig.GridSize

	for guid, placement in data.Housing.Furniture do
		local item = HousingConfig.Furniture[placement.ItemId]
		if item == nil then
			continue
		end
		local width, depth = item.Width, item.Depth
		if placement.Rotation == 90 or placement.Rotation == 270 then
			width, depth = depth, width
		end

		local part = Instance.new("Part")
		part.Name = guid
		part.Anchored = true
		part.Size = Vector3.new(width * grid, item.Height, depth * grid)
		part.Color = Color3.fromRGB(121, 134, 203)
		part.Material = Enum.Material.WoodPlanks
		-- Placement coordinates address the footprint's min cell; centre
		-- the part over its cells.
		part.Position = origin
			+ Vector3.new((placement.X + width / 2) * grid, item.Height / 2 + 0.5, (placement.Z + depth / 2) * grid)
		part:SetAttribute("ItemId", placement.ItemId)
		part.Parent = folder
	end
end

local function renderPlot(player: Player)
	local data = DataService:GetData(player)
	local slot = plotSlots[player]
	if data == nil or slot == nil then
		return
	end

	local old = plotModels[player]
	if old then
		old:Destroy()
	end

	local tier = HousingConfig.PlotTiers[data.Housing.PlotTier]
	local theme = HousingConfig.Themes[data.Housing.Theme] or HousingConfig.Themes.Starter
	local origin = slotOrigin(slot)

	local model = Instance.new("Model")
	model.Name = `Plot_{player.UserId}`
	model:SetAttribute("OwnerUserId", player.UserId)

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(tier.Cells * HousingConfig.GridSize, 1, tier.Cells * HousingConfig.GridSize)
	floor.Position = origin
	floor.Color = Color3.fromRGB(theme.FloorColour.R, theme.FloorColour.G, theme.FloorColour.B)
	floor.Material = Enum.Material.Grass
	floor.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.Size = Vector3.new(4, 4, 0.5)
	sign.Position = origin + Vector3.new(0, 3, tier.Cells * HousingConfig.GridSize / 2 + 1)
	sign.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = `{player.DisplayName}'s plot`
	label.Parent = billboard

	model.Parent = plotsFolder
	plotModels[player] = model
	renderFurniture(player, model, data)
end

function HousingService:GetPlotOrigin(player: Player): Vector3?
	local slot = plotSlots[player]
	if slot == nil then
		return nil
	end
	return slotOrigin(slot)
end

local function getDataOrRefuse(player: Player): { [string]: any }
	local data = DataService:GetData(player)
	if data == nil then
		Net.Refuse("Your data is still loading. Please try again shortly.")
	end
	return data :: any
end

function HousingService:OnInit()
	DataService = require(script.Parent.DataService) :: any

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	Net.HandleFunction("BuyPlotUpgrade", {}, function(player)
		local data = getDataOrRefuse(player)
		local ok, message, cost = HousingLogic.validateUpgrade(data)
		if not ok then
			Net.Refuse(message :: string)
		end
		if not DataService:MutateCurrency(player, "Coins", -(cost :: number), "PlotUpgrade") then
			Net.Refuse("You cannot afford that upgrade.")
		end
		data.Housing.PlotTier += 1
		renderPlot(player)
		DataService:Sync(player)
		return { PlotTier = data.Housing.PlotTier }
	end)

	Net.HandleFunction("BuyPlotTheme", { Guard.string(32) }, function(player, themeId)
		local data = getDataOrRefuse(player)
		local ok, message, cost = HousingLogic.validateThemePurchase(data, themeId)
		if not ok then
			Net.Refuse(message :: string)
		end
		if not DataService:MutateCurrency(player, "Gems", -(cost :: number), `PlotTheme:{themeId}`) then
			Net.Refuse("You cannot afford that theme.")
		end
		data.Housing.OwnedThemes[themeId] = true
		DataService:Sync(player)
		return { ThemeId = themeId }
	end)

	Net.HandleFunction("SetPlotTheme", { Guard.string(32) }, function(player, themeId)
		local data = getDataOrRefuse(player)
		if HousingConfig.Themes[themeId] == nil then
			Net.Refuse("That theme does not exist.")
		end
		local owned = data.Housing.OwnedThemes[themeId] == true
		if themeId == MonetisationConfig.VipPlotTheme then
			owned = data.Passes.VIP == true
		end
		if not owned then
			Net.Refuse("You do not own that theme.")
		end
		data.Housing.Theme = themeId
		renderPlot(player)
		DataService:Sync(player)
		return { ThemeId = themeId }
	end)

	Net.HandleFunction("BuyFurniture", { Guard.string(32) }, function(player, itemId)
		local data = getDataOrRefuse(player)
		local item = HousingConfig.Furniture[itemId]
		if item == nil then
			Net.Refuse("That furniture does not exist.")
		end
		if not DataService:MutateCurrency(player, "Coins", -item.PriceCoins, `Furniture:{itemId}`) then
			Net.Refuse(`You need {item.PriceCoins} Coins for that.`)
		end
		data.Inventory.Items[itemId] = (data.Inventory.Items[itemId] or 0) + 1
		DataService:Sync(player)
		return { ItemId = itemId, Owned = data.Inventory.Items[itemId] }
	end)

	Net.HandleFunction(
		"PlaceFurniture",
		{ Guard.string(32), Guard.integer(-100, 100), Guard.integer(-100, 100), Guard.oneOf({ 0, 90, 180, 270 }) },
		function(player, itemId, x, z, rotation)
			local data = getDataOrRefuse(player)
			if (data.Inventory.Items[itemId] or 0) < 1 then
				Net.Refuse("You do not own that furniture. Buy it first.")
			end
			local ok, message =
				HousingLogic.canPlace(data.Housing.PlotTier, data.Housing.Furniture, itemId, x, z, rotation)
			if not ok then
				Net.Refuse(message :: string)
			end

			data.Inventory.Items[itemId] -= 1
			local guid = `F{data.Housing.NextFurnitureId}`
			data.Housing.NextFurnitureId += 1
			data.Housing.Furniture[guid] = { ItemId = itemId, X = x, Z = z, Rotation = rotation }

			local plotModel = plotModels[player]
			if plotModel then
				renderFurniture(player, plotModel, data)
			end
			DataService:Sync(player)
			return { Guid = guid }
		end
	)

	Net.HandleFunction("ClaimPlotIncome", {}, function(player)
		local data = getDataOrRefuse(player)
		local coins = IncomeLogic.claim(data, os.time())
		if coins <= 0 then
			DataService:Sync(player)
			Net.Refuse("Your Mythlings have not earned anything yet. Keep them housed and fed!")
		end
		-- VIP boosts Coin sources, idle income included.
		coins = math.floor(coins * MonetisationLogic.coinMultiplier(data.Passes))
		DataService:MutateCurrency(player, "Coins", coins, "PlotIncome")
		DataService:Sync(player)
		return { Coins = coins }
	end)

	Net.HandleFunction("VisitFriendPlot", { Guard.integer(1) }, function(player, friendUserId)
		local data = getDataOrRefuse(player)
		if friendUserId == player.UserId then
			Net.Refuse("You are already home!")
		end

		local friend = Players:GetPlayerByUserId(friendUserId)
		if friend == nil or plotSlots[friend] == nil then
			Net.Refuse("That friend is not in this server.")
		end

		local isFriend = false
		local ok, result = pcall(player.IsFriendsWith, player, friendUserId)
		if ok then
			isFriend = result
		end
		if not isFriend then
			Net.Refuse("You can only visit Roblox friends.")
		end

		-- Teleport the visitor onto the friend's plot.
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local origin = slotOrigin(plotSlots[friend] :: number)
		if rootPart then
			rootPart.CFrame = CFrame.new(origin + Vector3.new(0, 6, 0))
		end

		-- Daily bonus for both, once per pair per day (visitor-tracked).
		local granted, message = IncomeLogic.tryRecordVisit(data, friendUserId, os.time())
		if granted then
			DataService:MutateCurrency(player, "Coins", HousingConfig.VisitBonusCoins, "VisitBonus:Visitor")
			DataService:MutateCurrency(friend, "Coins", HousingConfig.VisitBonusCoins, "VisitBonus:Host")
			DataService:Sync(player)
			DataService:Sync(friend)
		end
		return { Visited = friend.DisplayName, BonusGranted = granted, Message = message }
	end)

	Net.HandleFunction("RemoveFurniture", { Guard.string(16) }, function(player, guid)
		local data = getDataOrRefuse(player)
		local placement = data.Housing.Furniture[guid]
		if placement == nil then
			Net.Refuse("That furniture is not on your plot.")
		end
		data.Housing.Furniture[guid] = nil
		data.Inventory.Items[placement.ItemId] = (data.Inventory.Items[placement.ItemId] or 0) + 1

		local plotModel = plotModels[player]
		if plotModel then
			renderFurniture(player, plotModel, data)
		end
		DataService:Sync(player)
		return { Returned = placement.ItemId }
	end)
end

function HousingService:OnStart()
	DataService.ProfileLoaded:Connect(function(player)
		-- Start the idle income clock for brand new profiles.
		local data = DataService:GetData(player)
		if data and data.Housing.LastIncomeClaimAt == 0 then
			data.Housing.LastIncomeClaimAt = os.time()
		end
		-- Allocate the first free slot.
		for slot = 1, 200 do
			if not usedSlots[slot] then
				usedSlots[slot] = true
				plotSlots[player] = slot
				break
			end
		end
		renderPlot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local slot = plotSlots[player]
		if slot then
			usedSlots[slot] = nil
		end
		plotSlots[player] = nil
		local model = plotModels[player]
		if model then
			model:Destroy()
		end
		plotModels[player] = nil
	end)
end

return HousingService
