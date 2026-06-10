--!strict
-- Robux products and game passes. ProcessReceipt is idempotent via the
-- profile purchase ledger (keyed by ReceiptId); pass benefits are cached
-- into the profile on join and on purchase so every other system reads
-- one server-side source of truth.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetisationConfig = require(ReplicatedStorage.Shared.Config.MonetisationConfig)
local MonetisationLogic = require(ReplicatedStorage.Shared.Logic.MonetisationLogic)

local MonetisationService = {}

local DataService
local HatchService

local productsById: { [number]: { Key: string, Def: MonetisationConfig.DevProductDef } } = {}
local passesById: { [number]: string } = {}

local function refreshPassCache(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	for passKey, passDef in MonetisationConfig.GamePasses do
		if passDef.PassId == 0 then
			continue
		end
		local ok, owns =
			pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passDef.PassId)
		if ok and owns then
			-- Ownership is never revoked on API failure; passes only turn on.
			data.Passes[passKey] = true
		end
	end
	DataService:Sync(player)
end

local function grantVipStipend(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local now = os.time()
	if MonetisationLogic.vipStipendDue(data, now) then
		data.Flags.LastVipStipendDay = MonetisationLogic.dayStamp(now)
		DataService:MutateCurrency(player, "Gems", MonetisationConfig.VipDailyGems, "VipDailyStipend")
		DataService:Sync(player)
	end
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService:GetData(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = productsById[receiptInfo.ProductId]
	if product == nil then
		warn(`MonetisationService: receipt for unknown ProductId {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptId = tostring(receiptInfo.PurchaseId)
	MonetisationLogic.applyReceiptOnce(data, receiptId, os.time(), function()
		if product.Def.Type == "Gems" then
			DataService:MutateCurrency(player, "Gems", product.Def.Amount :: number, `DevProduct:{product.Key}`)
		elseif product.Def.Type == "BattlePassPremium" then
			data.BattlePass.OwnsPremium = true
		end
	end)
	-- Replays fall through here too: the grant already happened once, so
	-- the receipt is settled either way.
	DataService:Sync(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetisationService:OnInit()
	DataService = require(script.Parent.DataService) :: any
	HatchService = require(script.Parent.HatchService) :: any

	for key, def in MonetisationConfig.DevProducts do
		if def.ProductId ~= 0 then
			productsById[def.ProductId] = { Key = key, Def = def }
		end
	end
	for key, def in MonetisationConfig.GamePasses do
		if def.PassId ~= 0 then
			passesById[def.PassId] = key
		end
	end

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local passKey = passesById[passId]
		local data = DataService:GetData(player)
		if passKey and data then
			data.Passes[passKey] = true
			DataService:Sync(player)
			if passKey == "VIP" then
				grantVipStipend(player)
			end
		end
	end)
end

function MonetisationService:OnStart()
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(function()
			refreshPassCache(player)
			grantVipStipend(player)
		end)
	end)

	-- Auto-Hatch loop for pass owners.
	task.spawn(function()
		while true do
			task.wait(MonetisationConfig.AutoHatchIntervalSeconds)
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data and data.Passes.AutoHatch then
					local ok, err = pcall(HatchService.AutoHatchTick, HatchService, player)
					if not ok then
						warn(`MonetisationService: AutoHatchTick failed for {player.Name}: {err}`)
					end
				end
			end
		end
	end)
end

return MonetisationService
