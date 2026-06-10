--!nocheck
-- Mythlings test runner for Lune.
-- Discovers *.spec.luau files under src/shared and runs them with a
-- TestEZ-compatible API (describe / it / expect) so the same specs can
-- also be executed by TestEZ inside Roblox Studio.
--
-- Modules under test use relative string requires ("./Foo", "../Util/Bar")
-- which this runner resolves against the filesystem and which the Roblox
-- engine resolves against the instance tree.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = "src/shared"

-- ---------------------------------------------------------------------------
-- Module loader with relative string require support
-- ---------------------------------------------------------------------------

local moduleCache = {}

local function normalise(path: string): string
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do
		if part == ".." then
			table.remove(parts)
		elseif part ~= "." then
			table.insert(parts, part)
		end
	end
	return table.concat(parts, "/")
end

local function resolveFile(path: string): string?
	for _, candidate in { path, path .. ".luau", path .. ".lua", path .. "/init.luau" } do
		if fs.isFile(candidate) then
			return candidate
		end
	end
	return nil
end

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

local function loadModule(path: string, extraGlobals: { [string]: any }?): any
	local file = resolveFile(path)
	if not file then
		error(`Could not resolve module "{path}"`)
	end
	file = normalise(file)
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end

	local dir = string.match(file, "^(.*)/[^/]+$") or "."
	local env = {}
	for key, value in baseEnv do
		env[key] = value
	end
	if extraGlobals then
		for key, value in extraGlobals do
			env[key] = value
		end
	end
	env.require = function(target: string)
		if string.sub(target, 1, 1) ~= "." then
			error(`Only relative string requires are supported in shared modules (got "{target}")`)
		end
		return loadModule(normalise(`{dir}/{target}`), extraGlobals)
	end
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

local testGlobals

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

local function scan(dir: string)
	for _, entry in fs.readDir(dir) do
		local full = `{dir}/{entry}`
		if fs.isDir(full) then
			scan(full)
		elseif string.match(entry, "%.spec%.luau$") then
			table.insert(specFiles, full)
		end
	end
end

scan(ROOT)
table.sort(specFiles)

local filter = process.args[1]

for _, file in specFiles do
	if filter and not string.find(file, filter, 1, true) then
		continue
	end
	local before = totalFail
	local specBody = loadModule(file, testGlobals)
	if type(specBody) == "function" then
		local ok, err = pcall(specBody)
		if not ok then
			totalFail += 1
			table.insert(failures, `{file}: spec errored at top level: {err}`)
		end
	end
	print(`{totalFail == before and "PASS" or "FAIL"} {file}`)
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
