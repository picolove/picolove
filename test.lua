local api = require("api")
-- hide warnings during test run
--log = print
log = function() end

local lust = require("lust")
local describe, it, expect, before, after, spy = -- luacheck: no unused
lust.describe, lust.it, lust.expect, lust.before, lust.after, lust.spy

local failcount = 0
local failmsg = ""
local cachenext = false
local function cache_errors(text, count)
	if cachenext then
		cachenext = false
		failmsg = failmsg .. "\n" .. text .. "\n"
		if failcount == 5 then
			failmsg = failmsg .. "\n..."
		end
	end
	if count > 0 then
		failcount = failcount + 1
		if failcount <= 5 then
			failmsg = failmsg .. "\n" .. text
			cachenext = true
		end
	end
end

-- format lust output (no color, modified tabs)
local print_org = print
local function print_nocolor(text)
	local count

	text = text:gsub('\27%[%d+m', '')
	text = text:gsub('\t', '        ')
	text, count = text:gsub('^(%s+)%s%s%sFAIL', '!!!%1FAIL')
	print_org(text)
	cache_errors(text, count)
end
print = function() end -- luacheck: globals print
print = print_nocolor -- luacheck: globals print


print("")
print("--------------")
print("running tests:")
print("--------------")

describe("picolove api", function()
	before(function()
	end)

	after(function()
	end)

	describe("api.min", function()
		it("works for numbers", function()
			expect(api.min(1, 2)).to.equal(1)
			expect(api.min(2, 1)).to.equal(1)
			expect(api.min(-1, 2)).to.equal(-1)
			expect(api.min(2, -1)).to.equal(-1)
		end)

		it("works for strings", function()
			expect(api.min("1", "2")).to.equal(1)
			expect(api.min("2", "1")).to.equal(1)
			expect(api.min("-1", "2")).to.equal(-1)
			expect(api.min("2", "-1")).to.equal(-1)
		end)

		it("works for numbers + nils", function()
			expect(api.min(1, nil)).to.equal(0)
			expect(api.min(nil, 1)).to.equal(0)
			expect(api.min(-1, nil)).to.equal(-1)
			expect(api.min(nil, -1)).to.equal(-1)
		end)

		it("works for numbers + strings", function()
			expect(api.min(1, "X")).to.equal(0)
			expect(api.min("X", 1)).to.equal(0)
			expect(api.min(-1, "X")).to.equal(-1)
			expect(api.min("X", -1)).to.equal(-1)
		end)

		it("works for nils", function()
			expect(api.min(nil, nil, nil)).to.equal(0)
			expect(api.min(nil, nil)).to.equal(0)
			expect(api.min(nil)).to.equal(0)
			expect(api.min()).to.equal(0)
		end)
	end)


	describe("api.max", function()
		it("works for numbers", function()
			expect(api.max(1, 2)).to.equal(2)
			expect(api.max(2, 1)).to.equal(2)
			expect(api.max(-1, 2)).to.equal(2)
			expect(api.max(2, -1)).to.equal(2)
		end)

		it("works for strings", function()
			expect(api.max("1", "2")).to.equal(2)
			expect(api.max("2", "1")).to.equal(2)
			expect(api.max("-1", "2")).to.equal(2)
			expect(api.max("2", "-1")).to.equal(2)
		end)

		it("works for numbers + nils", function()
			expect(api.max(1, nil)).to.equal(1)
			expect(api.max(nil, 1)).to.equal(1)
			expect(api.max(-1, nil)).to.equal(0)
			expect(api.max(nil, -1)).to.equal(0)
		end)

		it("works for numbers + strings", function()
			expect(api.max(1, "X")).to.equal(1)
			expect(api.max("X", 1)).to.equal(1)
			expect(api.max(-1, "X")).to.equal(0)
			expect(api.max("X", -1)).to.equal(0)
		end)

		it("works for nils", function()
			expect(api.max(nil, nil, nil)).to.equal(0)
			expect(api.max(nil, nil)).to.equal(0)
			expect(api.max(nil)).to.equal(0)
			expect(api.max()).to.equal(0)
		end)
	end)


	describe("api.mid", function()
		it("works for numbers", function()
			expect(api.mid(1, 2, 3)).to.equal(2)
			expect(api.mid(1, 3, 2)).to.equal(2)
			expect(api.mid(2, 1, 3)).to.equal(2)
			expect(api.mid(2, 3, 1)).to.equal(2)
			expect(api.mid(3, 1, 2)).to.equal(2)
			expect(api.mid(3, 2, 1)).to.equal(2)
		end)
	end)


	describe("api.atan2", function()
		it("works for numbers", function()
			expect(api.atan2(1, 0)).to.equal(0)
			expect(api.atan2(0, -1)).to.equal(0.25)
			expect(api.atan2(-1, 0)).to.equal(0.5)
			expect(api.atan2(0, 1)).to.equal(0.75)
		end)
	end)


	describe("api.band", function()
		it("works for single bit shifts", function()
			expect(bit.band(0x01, bit.lshift(1, 0))).to_not.equal(0)
			expect(bit.band(0x02, bit.lshift(1, 1))).to_not.equal(0)
			expect(bit.band(0x04, bit.lshift(1, 2))).to_not.equal(0)
		end)

		it("works for multi bit shifts", function()
			expect(bit.band(0x05, bit.lshift(1, 2))).to_not.equal(0)
			expect(bit.band(0x05, bit.lshift(1, 0))).to_not.equal(0)
			expect(bit.band(0x05, bit.lshift(1, 3))).to.equal(0)
		end)
	end)


	describe("api.all", function()
		it("works for table with some nil values", function()
			local iter = api.all({nil, nil, 11, nil, 22, 33, 33, b = 42, 44})
			expect(iter()).to.equal(11)
			expect(iter()).to.equal(22)
			expect(iter()).to.equal(33)
			expect(iter()).to.equal(33)
			expect(iter()).to.equal(44)
			expect(iter()).to.equal(nil)
		end)
	end)


	describe("api.add", function()
		it("works for nil array", function()
			expect(api.add(nil, 1)).to.equal(nil)
		end)

		it("works for adding numbers", function()
			local array = {}
			expect(api.add(array, 1)).to.equal(1)
			expect(api.add(array, 2)).to.equal(2)
			expect(api.add(array, 3)).to.equal(3)
			expect(api.add(array, 1)).to.equal(1)
			expect(api.add(array, 2)).to.equal(2)
			expect(api.add(array, 3)).to.equal(3)
			expect(array).to.equal({1,2,3,1,2,3})
		end)
	end)


	describe("api.del", function()
		it("works for removing matching value at the start", function()
			local array = {1, 2, 3, 1, 2, 3}
			expect(api.del(array, 1)).to.equal(1)
			expect(array).to.equal({2, 3, 1, 2, 3})
		end)

		it("works for removing matching value in the middle", function()
			local array = {2, 3, 1, 2, 3}
			expect(api.del(array, 3)).to.equal(3)
			expect(array).to.equal({2, 1, 2, 3})
		end)

		it("works for removing matching value at the end", function()
			local array = {2, 1, 2, 3}
			expect(api.del(array, 3)).to.equal(3)
			expect(array).to.equal({2, 1, 2})
		end)

		it("works for removing missing value", function()
			local array = {2, 1, 2}
			expect(api.del(array, 3)).to.equal(nil)
			expect(array).to.equal({2, 1, 2})
		end)
	end)


	describe("api.tostr", function()
		it("works for empty and nil", function()
			expect(api.tostr()).to.equal("")
			expect(api.tostr("")).to.equal("")
			expect(api.tostr(nil)).to.equal("[nil]")
			expect(api.tostr(nil, nil)).to.equal("[nil]")

			expect(api.tostr(nil, 1)).to.equal("[nil]")
			expect(api.tostr(nil, 2)).to.equal("[nil]")
			expect(api.tostr(nil, 3)).to.equal("[nil]")
		end)

		it("works for booleans", function()
			expect(api.tostr(true)).to.equal("true")
			expect(api.tostr(false)).to.equal("false")

			expect(api.tostr(false), 1).to.equal("false")
			expect(api.tostr(false), 2).to.equal("false")
			expect(api.tostr(false), 3).to.equal("false")
		end)

		it("works for strings", function()
			expect(api.tostr("test")).to.equal("test")
			expect(api.tostr("string with spaces")).to.equal("string with spaces")

			expect(api.tostr("test"), 1).to.equal("test")
			expect(api.tostr("test"), 2).to.equal("test")
			expect(api.tostr("test"), 3).to.equal("test")
		end)

		it("works for tables", function()
			expect(api.tostr({})).to.equal("[table]")
			expect(api.tostr({nil})).to.equal("[table]")
			expect(api.tostr({"test"})).to.equal("[table]")
			expect(api.tostr({42})).to.equal("[table]")

			expect(api.tostr({42}), 1).to.equal("[table]")
			expect(api.tostr({42}), 2).to.equal("[table]")
			expect(api.tostr({42}), 3).to.equal("[table]")
		end)

		it("works for numbers", function()
			expect(api.tostr(1)).to.equal("1")
			expect(api.tostr(255)).to.equal("255")
			expect(api.tostr(255, nil)).to.equal("255")
			expect(api.tostr(255, 0)).to.equal("255")
		end)

		it("works for numbers with format", function()
			expect(api.tostr(255, 1)).to.equal("0x00ff.0000")
			expect(api.tostr(255, true)).to.equal("0x00ff.0000")
			expect(api.tostr(255, 2)).to.equal("16711680")
			expect(api.tostr(255, 3)).to.equal("0x00ff0000")
			expect(api.tostr(255, 4)).to.equal("255")
			expect(api.tostr(255, 5)).to.equal("0x00ff.0000")
			expect(api.tostr(255, 6)).to.equal("16711680")
			expect(api.tostr(255, 7)).to.equal("0x00ff0000")
		end)

		it("works for numbers with negative format", function()
			expect(api.tostr(255, -1)).to.equal("0x00ff0000")
			expect(api.tostr(255, -2)).to.equal("16711680")
			expect(api.tostr(255, -3)).to.equal("0x00ff.0000")
			expect(api.tostr(255, -4)).to.equal("255")
			expect(api.tostr(255, -5)).to.equal("0x00ff0000")
			expect(api.tostr(255, -6)).to.equal("16711680")
			expect(api.tostr(255, -7)).to.equal("0x00ff.0000")
		end)
	end)
end)


-- restore print
print = print_org -- luacheck: globals print

-- show error if tests failed
if failcount > 0 then
	error("\n\n" .. failcount .. " test(s) failed:" .. failmsg)
else
	print("\nAll tests PASSED!\n")
end


print("")
print("-----------------")
print("running picolove:")
print("-----------------")
