--!strict
-- Argument validators for remote payloads. Pure Luau.
-- Every validator is a function(value) -> (ok: boolean, err: string?).
-- Validators are strict by default: wrong type, out of range, oversized
-- strings and non-finite numbers all fail.

export type Validator = (value: any) -> (boolean, string?)

local Guard = {}

local function fail(message: string): (boolean, string?)
	return false, message
end

function Guard.boolean(): Validator
	return function(value)
		if type(value) ~= "boolean" then
			return fail(`expected boolean, got {typeof(value)}`)
		end
		return true, nil
	end
end

function Guard.string(maxLength: number?): Validator
	local limit = maxLength or 200
	return function(value)
		if type(value) ~= "string" then
			return fail(`expected string, got {typeof(value)}`)
		end
		if #value > limit then
			return fail(`string too long ({#value} > {limit})`)
		end
		return true, nil
	end
end

function Guard.number(min: number?, max: number?): Validator
	return function(value)
		if type(value) ~= "number" then
			return fail(`expected number, got {typeof(value)}`)
		end
		if value ~= value or value == math.huge or value == -math.huge then
			return fail("number must be finite")
		end
		if min ~= nil and value < min then
			return fail(`number {value} below minimum {min}`)
		end
		if max ~= nil and value > max then
			return fail(`number {value} above maximum {max}`)
		end
		return true, nil
	end
end

function Guard.integer(min: number?, max: number?): Validator
	local numberCheck = Guard.number(min, max)
	return function(value)
		local ok, err = numberCheck(value)
		if not ok then
			return false, err
		end
		if value % 1 ~= 0 then
			return fail(`expected integer, got {value}`)
		end
		return true, nil
	end
end

-- Accepts only values present in the given list.
function Guard.oneOf(options: { any }): Validator
	return function(value)
		if table.find(options, value) == nil then
			return fail(`value {tostring(value)} is not a permitted option`)
		end
		return true, nil
	end
end

function Guard.optional(inner: Validator): Validator
	return function(value)
		if value == nil then
			return true, nil
		end
		return inner(value)
	end
end

-- A plain table with a bounded number of keys. Deep contents must be
-- validated by the handler; this guard blocks oversized payload bombs.
function Guard.table(maxKeys: number?): Validator
	local limit = maxKeys or 50
	return function(value)
		if type(value) ~= "table" then
			return fail(`expected table, got {typeof(value)}`)
		end
		local count = 0
		for _ in value do
			count += 1
			if count > limit then
				return fail(`table has more than {limit} keys`)
			end
		end
		return true, nil
	end
end

function Guard.arrayOf(inner: Validator, maxLength: number?): Validator
	local limit = maxLength or 50
	return function(value)
		if type(value) ~= "table" then
			return fail(`expected array, got {typeof(value)}`)
		end
		local count = 0
		for key, item in value do
			count += 1
			if type(key) ~= "number" then
				return fail("array has non-numeric keys")
			end
			if count > limit then
				return fail(`array longer than {limit}`)
			end
			local ok, err = inner(item)
			if not ok then
				return fail(`array item {count}: {err}`)
			end
		end
		return true, nil
	end
end

-- Validates an argument tuple against an ordered list of validators.
-- Extra arguments beyond the schema are rejected outright.
function Guard.checkArgs(validators: { Validator }, ...: any): (boolean, string?)
	local args = table.pack(...)
	if args.n > #validators then
		return fail(`too many arguments ({args.n} > {#validators})`)
	end
	for index, validator in validators do
		local ok, err = validator(args[index])
		if not ok then
			return fail(`argument {index}: {err}`)
		end
	end
	return true, nil
end

return Guard
