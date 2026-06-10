--!nocheck
return function()
	local TableUtil = require(script.Parent.TableUtil)

	describe("TableUtil.deepCopy", function()
		it("copies nested tables by value", function()
			local original = { a = 1, nested = { b = 2 } }
			local copy = TableUtil.deepCopy(original)
			copy.nested.b = 99
			expect(original.nested.b).to.equal(2)
			expect(copy.a).to.equal(1)
		end)
	end)

	describe("TableUtil.reconcile", function()
		it("fills missing keys without overwriting existing ones", function()
			local target = { coins = 500, settings = { music = false } }
			local template = { coins = 0, gems = 10, settings = { music = true, sfx = true } }
			TableUtil.reconcile(target, template)
			expect(target.coins).to.equal(500)
			expect(target.gems).to.equal(10)
			expect(target.settings.music).to.equal(false)
			expect(target.settings.sfx).to.equal(true)
		end)
	end)

	describe("TableUtil.count", function()
		it("counts dictionary entries", function()
			expect(TableUtil.count({ a = 1, b = 2, c = 3 })).to.equal(3)
			expect(TableUtil.count({})).to.equal(0)
		end)
	end)

	describe("TableUtil.deepFreeze", function()
		it("freezes nested tables", function()
			local config = TableUtil.deepFreeze({ outer = { inner = 1 } })
			expect(function()
				config.outer.inner = 2
			end).to.throw()
		end)
	end)
end
