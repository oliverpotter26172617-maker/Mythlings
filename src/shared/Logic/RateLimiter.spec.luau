--!nocheck
return function()
	local RateLimiter = require(script.Parent.RateLimiter)

	describe("RateLimiter", function()
		it("allows up to the burst capacity instantly", function()
			local limiter = RateLimiter.new(5, 1)
			for _ = 1, 5 do
				expect(limiter:allow("Hatch:123", 0)).to.equal(true)
			end
		end)

		it("throttles a spammer past the burst", function()
			local limiter = RateLimiter.new(5, 1)
			local allowed = 0
			for _ = 1, 100 do
				if limiter:allow("Hatch:123", 0) then
					allowed += 1
				end
			end
			expect(allowed).to.equal(5)
		end)

		it("refills tokens over time", function()
			local limiter = RateLimiter.new(2, 1)
			expect(limiter:allow("k", 0)).to.equal(true)
			expect(limiter:allow("k", 0)).to.equal(true)
			expect(limiter:allow("k", 0)).to.equal(false)
			expect(limiter:allow("k", 1)).to.equal(true)
			expect(limiter:allow("k", 1)).to.equal(false)
		end)

		it("never refills beyond capacity", function()
			local limiter = RateLimiter.new(3, 100)
			expect(limiter:allow("k", 0)).to.equal(true)
			local allowed = 0
			for _ = 1, 10 do
				if limiter:allow("k", 1000) then
					allowed += 1
				end
			end
			expect(allowed).to.equal(3)
		end)

		it("tracks keys independently", function()
			local limiter = RateLimiter.new(1, 0.001)
			expect(limiter:allow("Hatch:1", 0)).to.equal(true)
			expect(limiter:allow("Hatch:1", 0)).to.equal(false)
			expect(limiter:allow("Hatch:2", 0)).to.equal(true)
		end)

		it("clears state by key prefix", function()
			local limiter = RateLimiter.new(1, 0.001)
			expect(limiter:allow("Hatch:1", 0)).to.equal(true)
			expect(limiter:allow("Hatch:1", 0)).to.equal(false)
			limiter:clear("Hatch:1")
			expect(limiter:allow("Hatch:1", 0)).to.equal(true)
		end)

		it("clears a player's buckets without hitting a same-prefixed id", function()
			-- Net keys buckets "UserId:RemoteName"; clearing "12:" on leave
			-- must not also drop user 123's bucket.
			local limiter = RateLimiter.new(1, 0.001)
			expect(limiter:allow("12:BuyEgg", 0)).to.equal(true)
			expect(limiter:allow("123:BuyEgg", 0)).to.equal(true)
			limiter:clear("12:")
			-- User 12 is reset (allowed again); user 123 is untouched (still throttled).
			expect(limiter:allow("12:BuyEgg", 0)).to.equal(true)
			expect(limiter:allow("123:BuyEgg", 0)).to.equal(false)
		end)

		it("is robust against a clock going backwards", function()
			local limiter = RateLimiter.new(2, 1)
			expect(limiter:allow("k", 100)).to.equal(true)
			expect(limiter:allow("k", 50)).to.equal(true)
			expect(limiter:allow("k", 10)).to.equal(false)
		end)
	end)
end
