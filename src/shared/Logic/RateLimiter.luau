--!strict
-- Token-bucket rate limiter, pure Luau. Each key (we use "RemoteName:UserId")
-- gets a bucket with a burst capacity that refills continuously. The clock is
-- a parameter so tests can drive time deterministically.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_capacity: number,
		_refillPerSecond: number,
		_buckets: { [string]: { tokens: number, last: number } },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	assert(capacity >= 1, "capacity must be at least 1")
	assert(refillPerSecond > 0, "refillPerSecond must be positive")
	return setmetatable({
		_capacity = capacity,
		_refillPerSecond = refillPerSecond,
		_buckets = {},
	}, RateLimiter)
end

-- Returns true if the call is allowed, false if the key is throttled.
function RateLimiter.allow(self: RateLimiter, key: string, now: number): boolean
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = self._capacity, last = now }
		self._buckets[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.last)
		bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._refillPerSecond)
		bucket.last = now
	end

	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

-- Drops state for a key (call when a player leaves).
function RateLimiter.clear(self: RateLimiter, keyPrefix: string)
	for key in self._buckets do
		if string.sub(key, 1, #keyPrefix) == keyPrefix then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
