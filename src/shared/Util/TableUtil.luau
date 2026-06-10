--!strict
-- Small table helpers shared by server and client. Pure Luau, no Roblox APIs,
-- so everything here is unit-testable under Lune.

local TableUtil = {}

-- Deep copies a table (values only, no metatables). Safe for profile data.
function TableUtil.deepCopy<T>(source: T): T
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in source :: any do
		copy[key] = TableUtil.deepCopy(value)
	end
	return copy :: any
end

-- Fills missing keys in target from template, recursively. Used for profile
-- reconciliation and config defaults. Existing values are never overwritten.
function TableUtil.reconcile(target: { [string]: any }, template: { [string]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = TableUtil.deepCopy(value)
		elseif type(target[key]) == "table" and type(value) == "table" then
			TableUtil.reconcile(target[key], value)
		end
	end
end

-- Returns the number of entries in a dictionary.
function TableUtil.count(dictionary: { [any]: any }): number
	local total = 0
	for _ in dictionary do
		total += 1
	end
	return total
end

-- Shallow freeze helper that returns the table for inline use.
function TableUtil.freeze<T>(target: T): T
	return table.freeze(target :: any) :: any
end

-- Deep freeze for config tables so logic code cannot mutate tunables.
function TableUtil.deepFreeze<T>(target: T): T
	for _, value in target :: any do
		if type(value) == "table" and not table.isfrozen(value) then
			TableUtil.deepFreeze(value)
		end
	end
	if not table.isfrozen(target :: any) then
		table.freeze(target :: any)
	end
	return target
end

return TableUtil
