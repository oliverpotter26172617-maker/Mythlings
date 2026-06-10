--!nocheck
-- Mythlings test runner for Lune.
-- Discovers *.spec.luau files under src/shared and runs them with a
-- TestEZ-compatible API (describe / it / expect) so the same specs can
-- also be executed by TestEZ inside Roblox Studio.
--
-- Modules use ordinary Roblox instance requires (require(script.Parent.Foo)).
-- This runner emulates the instance tree over the filesystem: src/shared
-- behaves like ReplicatedStorage.Shared, directories behave like Folders and
-- .luau files behave like ModuleScripts.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = "src/shared"
local ROOT_NAME = "Shared"

-- ---------------------------------------------------------------------------
-- Fake instance tree
-- ---------------------------------------------------------------------------

-- The tree is built eagerly because Lune's fs API can yield, which is not
-- allowed inside __index metamethods.

local nodeMeta = {
	__index = function(node, key)
		local child = node.__children and node.__children[key]
		if child then
			return child
		end
		error(`{key} is not a valid member of {node.__path}`)
	end,
	__tostring = function(node)
		return node.Name
	end,
}

local function makeNode(path: string, name: string, parent: any, isDir: boolean)
	local node = {
		__path = path,
		__isDir = isDir,
		__children = isDir and {} or nil,
		Name = name,
		Parent = parent,
	}
	node.GetChildren = function(self)
		local children = {}
		for _, child in self.__children or {} do
			table.insert(children, child)
		end
		return children
	end
	node.FindFirstChild = function(self, childName)
		return (self.__children or {})[childName]
	end
	node.IsA = function(self, className)
		if self.__isDir then
			return className == "Folder" or className == "Instance"
		end
		return className == "ModuleScript" or className == "LuaSourceContainer" or className == "Instance"
	end
	return setmetatable(node, nodeMeta)
end

local function buildTree(path: string, name: string, parent: any)
	local node = makeNode(path, name, parent, true)
	for _, entry in fs.readDir(path) do
		local full = `{path}/{entry}`
		if fs.isDir(full) then
			node.__children[entry] = buildTree(full, entry, node)
		elseif string.match(entry, "%.luau?$") then
			local childName = string.gsub(entry, "%.luau?$", "")
			node.__children[childName] = makeNode(full, childName, node, false)
		end
	end
	return node
end

local sharedRoot = buildTree(ROOT, ROOT_NAME, nil)

local function childNode(node, childName: string)
	return (node.__children or {})[childName]
end

-- ---------------------------------------------------------------------------
-- Module loader
-- ---------------------------------------------------------------------------

local moduleCache = {}
local testGlobals

local baseEnv = {
	assert = assert,
	error = error,
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	pcall = pcall,
	print = print,
	select = select,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	rawlen = rawlen,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	typeof = typeof,
	unpack = unpack,
	warn = warn,
	xpcall = xpcall,
	math = math,
	string = string,
	table = table,
	os = os,
	bit32 = bit32,
	buffer = buffer,
	utf8 = utf8,
	coroutine = coroutine,
	tick = os.clock,
}

local function loadModule(node): any
	if node == nil or type(node) ~= "table" or node.__path == nil then
		error("require expects a ModuleScript instance", 2)
	end
	if node.__isDir then
		local initNode = childNode(node, "init")
		if initNode then
			node = initNode
		else
			error(`Cannot require folder {node.__path}`, 2)
		end
	end
	local file = node.__path
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end

	local env = {}
	for key, value in baseEnv do
		env[key] = value
	end
	for key, value in testGlobals do
		env[key] = value
	end
	env.script = node
	env.require = loadModule
	env._G = env

	local fn = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local result = fn()
	moduleCache[file] = result
	return result
end

-- ---------------------------------------------------------------------------
-- TestEZ-compatible expect()
-- ---------------------------------------------------------------------------

local function makeExpect(value: any, inverted: boolean)
	local matcher = {}

	local function check(pass: boolean, message: string)
		if inverted then
			pass = not pass
			message = "(never) " .. message
		end
		if not pass then
			error(message, 3)
		end
	end

	matcher.to = matcher
	matcher.be = matcher
	matcher.been = matcher
	matcher.have = matcher
	matcher.was = matcher
	matcher.at = matcher

	function matcher.equal(expected: any)
		check(value == expected, `expected {tostring(value)} to equal {tostring(expected)}`)
	end

	function matcher.ok()
		check(value ~= nil and value ~= false, `expected value to be ok, got {tostring(value)}`)
	end

	function matcher.near(expected: number, limit: number?)
		local eps = limit or 1e-7
		check(
			type(value) == "number" and math.abs(value - expected) <= eps,
			`expected {tostring(value)} to be near {expected} (within {eps})`
		)
	end

	matcher.a = function(typeName: string)
		check(typeof(value) == typeName, `expected {tostring(value)} to be a {typeName}, got {typeof(value)}`)
	end
	matcher.an = matcher.a

	function matcher.throw(substring: string?)
		local ok, err = pcall(value)
		local pass = not ok
		if pass and substring then
			pass = string.find(tostring(err), substring, 1, true) ~= nil
		end
		check(pass, `expected function to throw{substring and ` (containing "{substring}")` or ""}`)
	end

	matcher.never = nil
	if not inverted then
		matcher.never = makeExpect(value, true)
	end

	return matcher
end

local function expect(value: any)
	return makeExpect(value, false)
end

-- ---------------------------------------------------------------------------
-- describe / it tree execution
-- ---------------------------------------------------------------------------

local totalPass, totalFail = 0, 0
local failures = {}
local contextStack = {}

local function describe(name: string, body: () -> ())
	table.insert(contextStack, name)
	local ok, err = pcall(body)
	if not ok then
		totalFail += 1
		table.insert(failures, `{table.concat(contextStack, " > ")}: describe block errored: {err}`)
	end
	table.remove(contextStack)
end

local function it(name: string, body: () -> ())
	table.insert(contextStack, name)
	local ok, err = pcall(body)
	if ok then
		totalPass += 1
	else
		totalFail += 1
		table.insert(failures, `{table.concat(contextStack, " > ")}: {err}`)
	end
	table.remove(contextStack)
end

testGlobals = {
	describe = describe,
	it = it,
	itSKIP = function() end,
	describeSKIP = function() end,
	expect = expect,
	FOCUS = function() end,
}

-- ---------------------------------------------------------------------------
-- Discovery and run
-- ---------------------------------------------------------------------------

local specFiles = {}

local function scan(dir: string, node)
	for _, entry in fs.readDir(dir) do
		local full = `{dir}/{entry}`
		if fs.isDir(full) then
			scan(full, childNode(node, entry))
		elseif string.match(entry, "%.spec%.luau$") then
			local name = string.gsub(entry, "%.luau$", "")
			table.insert(specFiles, { path = full, node = childNode(node, name) })
		end
	end
end

scan(ROOT, sharedRoot)
table.sort(specFiles, function(a, b)
	return a.path < b.path
end)

local filter = process.args[1]

for _, spec in specFiles do
	if filter and not string.find(spec.path, filter, 1, true) then
		continue
	end
	local before = totalFail
	local ok, result = pcall(loadModule, spec.node)
	if ok and type(result) == "function" then
		local bodyOk, err = pcall(result)
		if not bodyOk then
			totalFail += 1
			table.insert(failures, `{spec.path}: spec errored at top level: {err}`)
		end
	elseif not ok then
		totalFail += 1
		table.insert(failures, `{spec.path}: failed to load: {result}`)
	end
	print(`{totalFail == before and "PASS" or "FAIL"} {spec.path}`)
end

print("")
print(`Tests: {totalPass} passed, {totalFail} failed, {#specFiles} spec files`)

if totalFail > 0 then
	print("")
	for _, failure in failures do
		print("  FAIL " .. failure)
	end
	process.exit(1)
end
