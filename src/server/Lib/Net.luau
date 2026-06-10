--!strict
-- Server-side remote wrapper. Every remote gets:
-- - registration against RemoteConfig (unknown names are a hard error)
-- - per-player token-bucket rate limiting
-- - argument validation via Guard schemas before the handler runs
-- - violation logging (throttles and bad payloads)
--
-- RemoteFunctions always answer with a response envelope:
--   { Ok = true, Data = any } or { Ok = false, Error = string }
-- so the client can distinguish refusals from crashes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Logic.Guard)
local RateLimiter = require(ReplicatedStorage.Shared.Logic.RateLimiter)
local RemoteConfig = require(ReplicatedStorage.Shared.Config.RemoteConfig)

type Validator = Guard.Validator

local Net = {}

local remotesFolder: Folder? = nil
local limiters: { [string]: RateLimiter.RateLimiter } = {}
local violationCounts: { [string]: number } = {}

local function getFolder(): Folder
	if remotesFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		remotesFolder = folder

		Players.PlayerRemoving:Connect(function(player)
			for _, limiter in limiters do
				limiter:clear(`:{player.UserId}`)
			end
		end)
	end
	return remotesFolder :: Folder
end

local function getDef(name: string): RemoteConfig.RemoteDef
	local def = RemoteConfig.Remotes[name]
	if def == nil then
		error(`Net: remote "{name}" is not registered in RemoteConfig`)
	end
	return def
end

local function getRemote(name: string): Instance
	local def = getDef(name)
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local class = if def.Kind == "Function" then "RemoteFunction" else "RemoteEvent"
	local remote = Instance.new(class)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function logViolation(name: string, player: Player, reason: string)
	violationCounts[name] = (violationCounts[name] or 0) + 1
	warn(`Net violation [{name}] from {player.Name} ({player.UserId}): {reason}`)
end

-- Returns true if the call passes the remote's rate limit.
local function checkRate(name: string, def: RemoteConfig.RemoteDef, player: Player): boolean
	local limiter = limiters[name]
	if limiter == nil then
		limiter = RateLimiter.new(def.Burst, def.PerMinute / 60)
		limiters[name] = limiter
	end
	return limiter:allow(`{name}:{player.UserId}`, os.clock())
end

-- Registers the server handler for a client->server RemoteEvent.
function Net.HandleEvent(name: string, validators: { Validator }, handler: (player: Player, ...any) -> ())
	local def = getDef(name)
	assert(def.Kind == "Event", `Net.HandleEvent on non-Event remote "{name}"`)
	local remote = getRemote(name) :: RemoteEvent

	remote.OnServerEvent:Connect(function(player, ...)
		if not checkRate(name, def, player) then
			logViolation(name, player, "rate limited")
			return
		end
		local ok, err = Guard.checkArgs(validators, ...)
		if not ok then
			logViolation(name, player, err :: string)
			return
		end
		local success, handlerErr = pcall(handler, player, ...)
		if not success then
			warn(`Net handler error [{name}]: {handlerErr}`)
		end
	end)
end

-- Registers the server handler for a RemoteFunction. The handler returns the
-- payload; refusals should error with a player-safe message via Net.Refuse.
function Net.HandleFunction(name: string, validators: { Validator }, handler: (player: Player, ...any) -> any)
	local def = getDef(name)
	assert(def.Kind == "Function", `Net.HandleFunction on non-Function remote "{name}"`)
	local remote = getRemote(name) :: RemoteFunction

	remote.OnServerInvoke = function(player, ...)
		if not checkRate(name, def, player) then
			logViolation(name, player, "rate limited")
			return { Ok = false, Error = "You are doing that too fast. Please slow down." }
		end
		local ok, err = Guard.checkArgs(validators, ...)
		if not ok then
			logViolation(name, player, err :: string)
			return { Ok = false, Error = "Invalid request." }
		end
		local success, result = pcall(handler, player, ...)
		if not success then
			local message = tostring(result)
			local refusal = string.match(message, "REFUSE:%s*(.+)$")
			if refusal then
				return { Ok = false, Error = refusal }
			end
			warn(`Net handler error [{name}]: {message}`)
			return { Ok = false, Error = "Something went wrong. Please try again." }
		end
		return { Ok = true, Data = result }
	end
end

-- Raises a player-safe refusal from inside a RemoteFunction handler.
function Net.Refuse(message: string): never
	error("REFUSE: " .. message, 0)
end

function Net.FireClient(name: string, player: Player, ...: any)
	local remote = getRemote(name)
	assert(remote:IsA("RemoteEvent"), `Net.FireClient on non-Event remote "{name}"`)
	remote:FireClient(player, ...)
end

function Net.FireAllClients(name: string, ...: any)
	local remote = getRemote(name)
	assert(remote:IsA("RemoteEvent"), `Net.FireAllClients on non-Event remote "{name}"`)
	remote:FireAllClients(...)
end

-- Exposed for the security audit and tests.
function Net.GetViolationCounts(): { [string]: number }
	return table.clone(violationCounts)
end

return Net
