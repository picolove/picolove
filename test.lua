local api = require("api")

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

	text = text:gsub("\27%[%d+m", "")
	text = text:gsub("\t", "        ")
	text, count = text:gsub("^(%s+)%s%s%sFAIL", "!!!%1FAIL")
	print_org(text)
	cache_errors(text, count)
end
print = function() end -- luacheck: globals print
print = print_nocolor -- luacheck: globals print

-- hide warnings during test run
local log_org = log
log = function() end

print("")
print("--------------")
print("running tests:")
print("--------------")

describe("picolove api", function()
	before(function() end)

	after(function() end)

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
			local iter = api.all({ nil, nil, 11, nil, 22, 33, 33, b = 42, 44 })
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
			expect(array).to.equal({ 1, 2, 3, 1, 2, 3 })
		end)
	end)

	describe("api.del", function()
		it("works for removing matching value at the start", function()
			local array = { 1, 2, 3, 1, 2, 3 }
			expect(api.del(array, 1)).to.equal(1)
			expect(array).to.equal({ 2, 3, 1, 2, 3 })
		end)

		it("works for removing matching value in the middle", function()
			local array = { 2, 3, 1, 2, 3 }
			expect(api.del(array, 3)).to.equal(3)
			expect(array).to.equal({ 2, 1, 2, 3 })
		end)

		it("works for removing matching value at the end", function()
			local array = { 2, 1, 2, 3 }
			expect(api.del(array, 3)).to.equal(3)
			expect(array).to.equal({ 2, 1, 2 })
		end)

		it("works for removing missing value", function()
			local array = { 2, 1, 2 }
			expect(api.del(array, 3)).to.equal(nil)
			expect(array).to.equal({ 2, 1, 2 })
		end)
	end)

	describe("api.deli", function()
		it("works for removing index at the start", function()
			local array = { 1, 2, 3, 1, 2, 3 }
			expect(api.deli(array, 1)).to.equal(1)
			expect(array).to.equal({ 2, 3, 1, 2, 3 })
		end)

		it("works for removing index in the middle", function()
			local array = { 2, 3, 1, 2, 3 }
			expect(api.deli(array, 2)).to.equal(3)
			expect(array).to.equal({ 2, 1, 2, 3 })
		end)

		it("works for removing index at the end", function()
			local array = { 2, 1, 2, 3 }
			expect(api.deli(array, 4)).to.equal(3)
			expect(array).to.equal({ 2, 1, 2 })
		end)

		it("works for removing missing index", function()
			local array = { 2, 1, 2 }
			expect(api.deli(array, 7)).to.equal(nil)
			expect(array).to.equal({ 2, 1, 2 })
		end)

		it("works for removing missing negative index", function()
			local array = { 2, 1, 2 }
			expect(api.deli(array, -1)).to.equal(nil)
			expect(array).to.equal({ 2, 1, 2 })
		end)

		it("works for removing missing zero index", function()
			local array = { 2, 1, 2 }
			expect(api.deli(array, 0)).to.equal(nil)
			expect(array).to.equal({ 2, 1, 2 })
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
			expect(api.tostr({ nil })).to.equal("[table]")
			expect(api.tostr({ "test" })).to.equal("[table]")
			expect(api.tostr({ 42 })).to.equal("[table]")

			expect(api.tostr({ 42 }), 1).to.equal("[table]")
			expect(api.tostr({ 42 }), 2).to.equal("[table]")
			expect(api.tostr({ 42 }), 3).to.equal("[table]")
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

	describe("api.tonum", function()
		it("works with booleans", function()
			expect(api.tonum(true)).to.equal(1)
			expect(api.tonum(false)).to.equal(0)
		end)

		it("works with string booleans", function()
			expect(api.tonum("true")).to.equal(nil)
			expect(api.tonum("false")).to.equal(nil)
		end)

		it("works with positive string numbers", function()
			expect(api.tonum("0")).to.equal(0)
			expect(api.tonum("8")).to.equal(8)
			expect(api.tonum("42")).to.equal(42)
			expect(api.tonum("846")).to.equal(846)
			expect(api.tonum("9332")).to.equal(9332)
			expect(api.tonum("72417")).to.equal(72417)
		end)

		it("works with negative string numbers", function()
			expect(api.tonum("-0")).to.equal(-0)
			expect(api.tonum("-1")).to.equal(-1)
			expect(api.tonum("-8")).to.equal(-8)
			expect(api.tonum("-42")).to.equal(-42)
			expect(api.tonum("-846")).to.equal(-846)
			expect(api.tonum("-9332")).to.equal(-9332)
			expect(api.tonum("-72417")).to.equal(-72417)
		end)

		it("works with invalid string inputs", function()
			expect(api.tonum("")).to.equal(nil)
			expect(api.tonum("false")).to.equal(nil)
			expect(api.tonum("true")).to.equal(nil)
			expect(api.tonum("hello")).to.equal(nil)
			expect(api.tonum("///")).to.equal(nil)

			local hasnoreturn = function(...)
				return select("#", ...) == 0
			end
			expect(hasnoreturn(1)).to.equal(false)
			expect(hasnoreturn()).to.equal(true)
			expect(hasnoreturn("")).to.equal(false)
			expect(hasnoreturn("test")).to.equal(false)
			expect(hasnoreturn(nil)).to.equal(false)
			expect(hasnoreturn({})).to.equal(false)
			expect(hasnoreturn({ 1 })).to.equal(false)
			expect(hasnoreturn({ "test" })).to.equal(false)

			expect(hasnoreturn(api.tonum(""))).to.equal(true)
			expect(hasnoreturn(api.tonum("false"))).to.equal(true)
			expect(hasnoreturn(api.tonum("true"))).to.equal(true)
			expect(hasnoreturn(api.tonum("hello"))).to.equal(true)
			expect(hasnoreturn(api.tonum("///"))).to.equal(true)
		end)

		it("works with positive numbers", function()
			expect(api.tonum(0)).to.equal(0)
			expect(api.tonum(1)).to.equal(1)
			expect(api.tonum(8)).to.equal(8)
			expect(api.tonum(42)).to.equal(42)
			expect(api.tonum(846)).to.equal(846)
			expect(api.tonum(9332)).to.equal(9332)
			expect(api.tonum(72417)).to.equal(72417)
		end)

		it("works with no argument", function()
			expect(api.tonum()).to.equal(nil)

			local hasnoreturn = function(...)
				return select("#", ...) == 0
			end
			expect(hasnoreturn(api.tonum())).to.equal(true)
		end)

		it("works with negative numbers", function()
			expect(api.tonum(-0)).to.equal(-0)
			expect(api.tonum(-1)).to.equal(-1)
			expect(api.tonum(-8)).to.equal(-8)
			expect(api.tonum(-42)).to.equal(-42)
			expect(api.tonum(-846)).to.equal(-846)
			expect(api.tonum(-9332)).to.equal(-9332)
			expect(api.tonum(-72417)).to.equal(-72417)
		end)

		it("works with hex format", function()
			expect(api.tonum("ff", 1)).to.equal(255)
		end)

		it("works with integer format", function()
			expect(api.tonum("1114112", 2)).to.equal(17)
		end)

		it("works with integer + hex format", function()
			expect(api.tonum("1234abcd", 3)).to.equal(0x1234.abcd)
		end)

		it("works with zero return format", function()
			expect(api.tonum("hello", 4)).to.equal(0)
			expect(api.tonum("world", 5)).to.equal(0)
			expect(api.tonum("///", 6)).to.equal(0)
			expect(api.tonum("test", 7)).to.equal(0)

			expect(api.tonum("", 4)).to.equal(0)
			expect(api.tonum("", 5)).to.equal(0)
			expect(api.tonum("", 6)).to.equal(0)
			expect(api.tonum("", 7)).to.equal(0)
		end)

		it("works with formatted booleans", function()
			expect(api.tonum(true, 0)).to.equal(1)
			expect(api.tonum(true, 1)).to.equal(1)
			expect(api.tonum(true, 2)).to.equal(0)
			expect(api.tonum(true, 3)).to.equal(0)
			expect(api.tonum(true, 4)).to.equal(1)
			expect(api.tonum(true, 5)).to.equal(1)
			expect(api.tonum(true, 6)).to.equal(0)
			expect(api.tonum(true, 7)).to.equal(0)
			expect(api.tonum(true, 8)).to.equal(1)

			expect(api.tonum(false, 0)).to.equal(0)
			expect(api.tonum(false, 1)).to.equal(0)
			expect(api.tonum(false, 2)).to.equal(0)
			expect(api.tonum(false, 3)).to.equal(0)
			expect(api.tonum(false, 4)).to.equal(0)
			expect(api.tonum(false, 5)).to.equal(0)
			expect(api.tonum(false, 6)).to.equal(0)
			expect(api.tonum(false, 7)).to.equal(0)
			expect(api.tonum(false, 8)).to.equal(0)
		end)

		it("works with formatted booleans", function()
			expect(api.tonum(1, 0)).to.equal(1)
			expect(api.tonum(1, 1)).to.equal(1)
			expect(api.tonum(1, 2)).to.equal(1)
			expect(api.tonum(1, 3)).to.equal(1)
			expect(api.tonum(1, 4)).to.equal(1)
			expect(api.tonum(1, 5)).to.equal(1)
			expect(api.tonum(1, 6)).to.equal(1)
			expect(api.tonum(1, 7)).to.equal(1)
			expect(api.tonum(1, 8)).to.equal(1)

			expect(api.tonum(0, 0)).to.equal(0)
			expect(api.tonum(0, 1)).to.equal(0)
			expect(api.tonum(0, 2)).to.equal(0)
			expect(api.tonum(0, 3)).to.equal(0)
			expect(api.tonum(0, 4)).to.equal(0)
			expect(api.tonum(0, 5)).to.equal(0)
			expect(api.tonum(0, 6)).to.equal(0)
			expect(api.tonum(0, 7)).to.equal(0)
			expect(api.tonum(0, 8)).to.equal(0)

			expect(api.tonum(17, 0)).to.equal(17)
			expect(api.tonum(17, 1)).to.equal(17)
			expect(api.tonum(17, 2)).to.equal(17)
			expect(api.tonum(17, 3)).to.equal(17)
			expect(api.tonum(17, 4)).to.equal(17)
			expect(api.tonum(17, 5)).to.equal(17)
			expect(api.tonum(17, 6)).to.equal(17)
			expect(api.tonum(17, 7)).to.equal(17)
			expect(api.tonum(17, 8)).to.equal(17)
		end)

		it("works with formatted nil", function()
			expect(api.tonum(nil)).to.equal(nil)
			expect(api.tonum(nil, 0)).to.equal(nil)
			expect(api.tonum(nil, 1)).to.equal(nil)
			expect(api.tonum(nil, 2)).to.equal(nil)
			expect(api.tonum(nil, 3)).to.equal(nil)
			expect(api.tonum(nil, 4)).to.equal(nil)
			expect(api.tonum(nil, 5)).to.equal(nil)
			expect(api.tonum(nil, 6)).to.equal(nil)
			expect(api.tonum(nil, 7)).to.equal(nil)
			expect(api.tonum(nil, 8)).to.equal(nil)
		end)

		it("works with formatted tables", function()
			expect(api.tonum({})).to.equal(nil)
			expect(api.tonum({}, 0)).to.equal(nil)
			expect(api.tonum({}, 1)).to.equal(nil)
			expect(api.tonum({}, 2)).to.equal(nil)
			expect(api.tonum({}, 3)).to.equal(nil)
			expect(api.tonum({}, 4)).to.equal(nil)
			expect(api.tonum({}, 5)).to.equal(nil)
			expect(api.tonum({}, 6)).to.equal(nil)
			expect(api.tonum({}, 7)).to.equal(nil)
			expect(api.tonum({}, 8)).to.equal(nil)
		end)

		it("works with formatted functions", function()
			expect(api.tonum(function() end)).to.equal(nil)
			expect(api.tonum(function() end, 0)).to.equal(nil)
			expect(api.tonum(function() end, 1)).to.equal(nil)
			expect(api.tonum(function() end, 2)).to.equal(nil)
			expect(api.tonum(function() end, 3)).to.equal(nil)
			expect(api.tonum(function() end, 4)).to.equal(nil)
			expect(api.tonum(function() end, 5)).to.equal(nil)
			expect(api.tonum(function() end, 6)).to.equal(nil)
			expect(api.tonum(function() end, 7)).to.equal(nil)
			expect(api.tonum(function() end, 8)).to.equal(nil)
		end)

		it("works with unexpected formats", function()
			expect(api.tonum("123", {})).to.equal(123)
			expect(api.tonum("123", function() end)).to.equal(123)
			expect(api.tonum("123", "")).to.equal(123)
			expect(api.tonum("123", nil)).to.equal(123)
			expect(api.tonum("123", "1")).to.equal(291)
			expect(api.tonum("1114112", "2")).to.equal(17)
			expect(api.tonum("1234abcd", "3")).to.equal(0x1234.abcd)
			expect(api.tonum("123", "4")).to.equal(123)
			expect(api.tonum("???", "4")).to.equal(0)
		end)

		it("works with partial number strings", function()
			expect(api.tonum("?4", 4)).to.equal(0)
			expect(api.tonum("4?", 4)).to.equal(0)
			expect(api.tonum("4?4", 4)).to.equal(0)
		end)
	end)

	-- TODO: test special chars and chars currently autoreplaces with "8"
	describe("api.chr", function()
		it("works for printable numbers", function()
			expect(api.chr(42)).to.equal("*")
		end)

		it("works for printable strings", function()
			expect(api.chr("42")).to.equal("*")
		end)

		it("works for non printable numbers", function()
			expect(api.chr(0)).to.equal("\0")
			expect(api.chr(1)).to.equal("\1")
			expect(api.chr(2)).to.equal("\2")
			expect(api.chr(3)).to.equal("\3")
			expect(api.chr(4)).to.equal("\4")
			expect(api.chr(5)).to.equal("\5")
		end)

		it("works for number > 255", function()
			expect(api.chr(42 + 256)).to.equal("*")
		end)

		it("works for stirng > 255", function()
			expect(api.chr("298")).to.equal("*")
		end)

		it("works for other types", function()
			expect(api.chr(true)).to.equal(nil)
			expect(api.chr(false)).to.equal(nil)
			expect(api.chr("true")).to.equal(nil)
			expect(api.chr("false")).to.equal(nil)
			expect(api.chr("test")).to.equal(nil)
			expect(api.chr({})).to.equal(nil)
			expect(api.chr(function() end)).to.equal(nil)
		end)
	end)

	describe("api.sgn", function()
		it("works for positive numbers", function()
			expect(api.sgn(1)).to.equal(1)
			expect(api.sgn(42)).to.equal(1)
			expect(api.sgn(123456)).to.equal(1)
		end)

		it("works for zero", function()
			expect(api.sgn(0)).to.equal(1)
		end)

		it("works for negative numbers", function()
			expect(api.sgn(-1)).to.equal(-1)
			expect(api.sgn(-42)).to.equal(-1)
			expect(api.sgn(-123456)).to.equal(-1)
		end)

		it("works for positive floating point numbers", function()
			expect(api.sgn(0.0001)).to.equal(1)
			expect(api.sgn(1.1234)).to.equal(1)
			expect(api.sgn(42.0815)).to.equal(1)
			expect(api.sgn(123456.3333)).to.equal(1)
		end)

		it("works for negative floating point numbers", function()
			expect(api.sgn(-0.0001)).to.equal(-1)
			expect(api.sgn(-1.1234)).to.equal(-1)
			expect(api.sgn(-42.0815)).to.equal(-1)
			expect(api.sgn(-123456.3333)).to.equal(-1)
		end)

		it("works for positive numbers in strings", function()
			expect(api.sgn("1")).to.equal(1)
			expect(api.sgn("42")).to.equal(1)
			expect(api.sgn("123456")).to.equal(1)
		end)

		it("works for string zero", function()
			expect(api.sgn("0")).to.equal(1)
		end)

		it("works for negative numbers in strings", function()
			expect(api.sgn("-1")).to.equal(-1)
			expect(api.sgn("-42")).to.equal(-1)
			expect(api.sgn("-123456")).to.equal(-1)
		end)

		it("works for strings with positive floating point numbers", function()
			expect(api.sgn("0.0001")).to.equal(1)
			expect(api.sgn("1.1234")).to.equal(1)
			expect(api.sgn("42.0815")).to.equal(1)
			expect(api.sgn("123456.3333")).to.equal(1)
		end)

		it("works for strings with negative floating point numbers", function()
			expect(api.sgn("-0.0001")).to.equal(-1)
			expect(api.sgn("-1.1234")).to.equal(-1)
			expect(api.sgn("-42.0815")).to.equal(-1)
			expect(api.sgn("-123456.3333")).to.equal(-1)
		end)

		it("works for strings with negative hex numbers", function()
			expect(api.sgn("0x1")).to.equal(1)
			expect(api.sgn("0xbeef")).to.equal(1)
			expect(api.sgn("0xBEEF")).to.equal(1)
			expect(api.sgn("0xe5e7")).to.equal(1)
			expect(api.sgn("0xE5E7")).to.equal(1)
		end)

		it("works for strings with negative hex numbers", function()
			expect(api.sgn("-0x1")).to.equal(-1)
			expect(api.sgn("-0xbeef")).to.equal(-1)
			expect(api.sgn("-0xBEEF")).to.equal(-1)
			expect(api.sgn("-0xe5e7")).to.equal(-1)
			expect(api.sgn("-0xE5E7")).to.equal(-1)
		end)

		it("works for misc strings", function()
			expect(api.sgn("a1")).to.equal(1)
			expect(api.sgn("b42")).to.equal(1)
			expect(api.sgn("c123456")).to.equal(1)

			expect(api.sgn("0.0001x")).to.equal(1)
			expect(api.sgn("1.1234x")).to.equal(1)
			expect(api.sgn("42.0815x")).to.equal(1)
			expect(api.sgn("123456.3333x")).to.equal(1)

			expect(api.sgn("-0.0001x")).to.equal(1)
			expect(api.sgn("-1.1234x")).to.equal(1)
			expect(api.sgn("-42.0815x")).to.equal(1)
			expect(api.sgn("-123456.3333x")).to.equal(1)

			expect(api.sgn("hello")).to.equal(1)
			expect(api.sgn("////")).to.equal(1)
			expect(api.sgn("test")).to.equal(1)
		end)
	end)
end)

-- restore functions
print = print_org -- luacheck: globals print
log = log_org -- luacheck: globals log

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
