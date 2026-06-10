--!strict
-- DataService: session-locked player profiles via ProfileStore.
--
-- Guarantees:
-- - One session per profile (ProfileStore session locking), so duped data
--   from multi-server joins is impossible.
-- - BindToClose is handled inside ProfileStore; on shutdown every active
--   session is ended and flushed before the server closes.
-- - Schema migrations run before any other system touches the profile.
-- - All currency mutations flow through MutateCurrency so they can be
--   clamped, audited and logged in one place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(ReplicatedStorage.Packages.ProfileStore)
local GoodSignal = require(ReplicatedStorage.Packages.GoodSignal)
local ProfileSchema = require(ReplicatedStorage.Shared.Logic.ProfileSchema)
local ProfileSanitiser = require(ReplicatedStorage.Shared.Logic.ProfileSanitiser)
local Analytics = require(script.Parent.Parent.Lib.Analytics)
local LiveConfig = require(script.Parent.Parent.Lib.LiveConfig)
local Net = require(script.Parent.Parent.Lib.Net)

local STORE_NAME = "PlayerData"

local DataService = {}

DataService.ProfileLoaded = GoodSignal.new() -- (player, profile)
DataService.ProfileReleased = GoodSignal.new() -- (player)

local profiles: { [Player]: any } = {}
local store

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Could not acquire a session lock (another server holds it).
		player:Kick("Your data is still saving from another server. Please rejoin in a moment.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	local ok, err = pcall(ProfileSchema.runMigrations, profile.Data)
	if not ok then
		warn(`DataService: migration failed for {player.Name}: {err}`)
		profile:EndSession()
		player:Kick("Your data could not be upgraded safely. Please contact support.")
		return
	end

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		DataService.ProfileReleased:Fire(player)
		player:Kick("Your game session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local now = os.time()
	if profile.Data.CreatedAt == 0 then
		profile.Data.CreatedAt = now
	end
	profile.Data.LastSeenAt = now

	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
	DataService:Sync(player)
end

function DataService:OnInit()
	LiveConfig.start()

	-- Boot-time pull: the join push can race the client's controllers.
	Net.HandleFunction("RequestProfile", {}, function(player)
		local data = self:GetData(player)
		if data == nil then
			Net.Refuse("Your data is still loading. Please try again shortly.")
		end
		return ProfileSanitiser.sanitise(data :: any)
	end)

	store = ProfileStore.New(STORE_NAME, ProfileSchema.buildTemplate())
	if RunService:IsStudio() then
		-- Studio play-tests use the mock store so test data never pollutes
		-- live DataStores and works without API access.
		store = store.Mock
	end
end

function DataService:OnStart()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile.Data.LastSeenAt = os.time()
			profile:EndSession()
		end
	end)
end

-- Returns the live profile, or nil if it has not loaded or was released.
function DataService:GetProfile(player: Player): any?
	return profiles[player]
end

-- Yields until the player's profile is available or the player leaves.
-- Returns nil if the player left before their profile loaded.
function DataService:WaitForProfile(player: Player): any?
	while player.Parent ~= nil do
		local profile = profiles[player]
		if profile then
			return profile
		end
		task.wait(0.1)
	end
	return nil
end

function DataService:GetData(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data or nil
end

-- The single entry point for changing a player's currency balance.
-- Positive delta grants, negative spends. Spends that would go below zero
-- are rejected and return false. Reason is required for the audit trail.
function DataService:MutateCurrency(player: Player, currency: string, delta: number, reason: string): boolean
	assert(type(reason) == "string" and reason ~= "", "MutateCurrency requires a reason")
	local data = self:GetData(player)
	if data == nil then
		return false
	end
	local balance = data.Currencies[currency]
	if balance == nil then
		error(`Unknown currency "{currency}"`)
	end
	if delta % 1 ~= 0 then
		error(`Currency delta must be an integer, got {delta}`)
	end
	local newBalance = balance + delta
	if newBalance < 0 then
		return false
	end
	data.Currencies[currency] = newBalance

	-- Telemetry: every source and sink for every currency lands on the
	-- economy dashboard, keyed by the audit reason.
	Analytics.economy(
		player,
		if delta > 0 then "Source" else "Sink",
		currency,
		delta,
		newBalance,
		Analytics.transactionTypeFor(reason),
		reason
	)
	return true
end

-- Pushes the sanitised profile snapshot to the client. Call after any
-- mutation a player should see reflected in their UI. Pushes are
-- coalesced per player so bursts of mutations cost one snapshot.
local syncPending: { [Player]: boolean } = {}

function DataService:Sync(player: Player)
	if syncPending[player] then
		return
	end
	syncPending[player] = true
	task.delay(0.2, function()
		syncPending[player] = nil
		local data = self:GetData(player)
		if data == nil or player.Parent == nil then
			return
		end
		Net.FireClient("ProfileSync", player, ProfileSanitiser.sanitise(data))
	end)
end

function DataService:GetBalance(player: Player, currency: string): number?
	local data = self:GetData(player)
	if data == nil then
		return nil
	end
	return data.Currencies[currency]
end

return DataService
