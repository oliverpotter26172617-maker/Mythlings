--!strict
-- Client-side remote access. Mirrors src/server/Lib/Net.luau.
-- RemoteFunction responses arrive as { Ok, Data?, Error? } envelopes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetClient = {}

export type Response = {
	Ok: boolean,
	Data: any?,
	Error: string?,
}

local function getRemote(name: string): Instance
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name)
end

function NetClient.Fire(name: string, ...: any)
	local remote = getRemote(name)
	assert(remote:IsA("RemoteEvent"), `NetClient.Fire on non-Event remote "{name}"`)
	remote:FireServer(...)
end

function NetClient.Invoke(name: string, ...: any): Response
	local remote = getRemote(name)
	assert(remote:IsA("RemoteFunction"), `NetClient.Invoke on non-Function remote "{name}"`)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok then
		return { Ok = false, Error = "Could not reach the server. Please try again." }
	end
	if type(result) ~= "table" or type(result.Ok) ~= "boolean" then
		return { Ok = false, Error = "Unexpected server response." }
	end
	return result
end

function NetClient.On(name: string, callback: (...any) -> ()): RBXScriptConnection
	local remote = getRemote(name)
	assert(remote:IsA("RemoteEvent"), `NetClient.On on non-Event remote "{name}"`)
	return remote.OnClientEvent:Connect(callback)
end

return NetClient
