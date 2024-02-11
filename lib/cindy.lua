local cindy = {
	_VERSION     = 'cindy 0.1.2',
	_LICENSE     = 'WTFPL, http://www.wtfpl.net',
	_URL         = 'https://github.com/megagrump/cindy',
	_DESCRIPTION = 'True Colors for LÖVE 11',
}

--[[-----------------------------------------------------------------------------------------------------------------

cindy adds functions to LÖVE 11.x that accept/return colors in the [0,255] range instead of the newly introduced
[0.0,1.0] range.

In love.graphics:
- clearBytes
- getColorBytes, setColorBytes
- getBackgroundColorBytes, setBackgroundColorBytes

In ImageData:
- getPixelBytes, setPixelBytes
- mapPixelBytes

In ParticleSystem:
- setColorsBytes, getColorsBytes

In SpriteBatch:
- getColorBytes, setColorBytes

In Shader:
- sendColorBytes

These functions behave the same as their built-in counterparts, except for the different value range.
Note that calling them has additional runtime costs.

To replace all original functions, call cindy.applyPatch() at the start of the program: require('cindy').applyPatch() -
this effectively restores the pre-11.0 behavior.

-------------------------------------------------------------------------------------------------------------------]]

local gfx, reg = love.graphics, debug.getregistry()
local ImageData, ParticleSystem, SpriteBatch, Shader = reg.ImageData, reg.ParticleSystem, reg.SpriteBatch, reg.Shader
local clear, getColor, setColor = gfx.clear, gfx.getColor, gfx.setColor
local getBackgroundColor, setBackgroundColor = gfx.getBackgroundColor, gfx.setBackgroundColor
local getPixel, setPixel, mapPixel = ImageData.getPixel, ImageData.setPixel, ImageData.mapPixel
local getParticleColors, setParticleColors = ParticleSystem.getColors, ParticleSystem.setColors
local getBatchColor, setBatchColor = SpriteBatch.getColor, SpriteBatch.setColor
local sendColor = Shader.sendColor

---------------------------------------------------------------------------------------------------------------------

local function round(v)
	return math.floor(v + .5)
end

-- convert a single channel value from [0.0,1.0] to [0,255]
function cindy.channel2byte(c)
	return round(c * 255)
end

-- convert a single channel value from [0,255] to [0.0,1.0]
function cindy.byte2channel(c)
	return c / 255
end

-- convert RGBA values from [0.0,1.0] to [0,255]
function cindy.rgba2bytes(r, g, b, a)
	return round(r * 255), round(g * 255), round(b * 255), a and round(a * 255)
end

-- convert RGBA values from [0,255] to [0.0,1.0]
function cindy.bytes2rgba(r, g, b, a)
	return r / 255, g / 255, b / 255, a and a / 255
end

-- convert RGBA value table from [0.0,1.0] to [0,255]. places the result in dest, if given
function cindy.table2bytes(color, dest)
	dest = dest or {}
	dest[1], dest[2], dest[3], dest[4] = cindy.rgba2bytes(color[1], color[2], color[3], color[4])
	return dest
end

-- convert RGBA value table from [0,255] to [0.0,1.0]. places the result in dest, if given
function cindy.bytes2table(color, dest)
	dest = dest or {}
	dest[1], dest[2], dest[3], dest[4] = cindy.bytes2rgba(color[1], color[2], color[3], color[4])
	return dest
end

-- convert RGBA values or table from [0.0,1.0] to [0,255]. returns separate values
function cindy.color2bytes(r, g, b, a)
	if type(r) == 'table' then
		r, g, b, a = r[1], r[2], r[3], r[4]
	end

	return cindy.rgba2bytes(r, g, b, a)
end

-- convert RGBA values or table from [0,255] to [0.0,1.0]. returns separate values
function cindy.bytes2color(r, g, b, a)
	if type(r) == 'table' then
		r, g, b, a = r[1], r[2], r[3], r[4]
	end

	return cindy.bytes2rgba(r, g, b, a)
end

-- patch all LÖVE functions to accept colors in the [0,255] range
function cindy.applyPatch()
	gfx.clear, gfx.getColor, gfx.setColor = gfx.clearBytes, gfx.getColorBytes, gfx.setColorBytes
	gfx.getBackgroundColor, gfx.setBackgroundColor = gfx.getBackgroundColorBytes, gfx.setBackgroundColorBytes
	ImageData.getPixel, ImageData.setPixel = ImageData.getPixelBytes, ImageData.setPixelBytes
	ImageData.mapPixel = ImageData.mapPixelBytes
	ParticleSystem.getColors, ParticleSystem.setColors = ParticleSystem.getColorsBytes, ParticleSystem.setColorsBytes
	SpriteBatch.getColor, SpriteBatch.setColor = SpriteBatch.getColorBytes, SpriteBatch.setColorBytes
	Shader.sendColor = Shader.sendColorBytes

	return cindy
end

---------------------------------------------------------------------------------------------------------------------

local tempTables = { {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {} }

function gfx.getColorBytes()
	return cindy.rgba2bytes(getColor())
end

function gfx.setColorBytes(r, g, b, a)
	return setColor(cindy.bytes2color(r, g, b, a))
end

function gfx.getBackgroundColorBytes()
	return cindy.rgba2bytes(getBackgroundColor())
end

function gfx.setBackgroundColorBytes(r, g, b, a)
	return setBackgroundColor(cindy.bytes2color(r, g, b, a))
end

function gfx.clearBytes(...)
	local nargs = select('#', ...)
	if nargs == 0 then return clear() end

	local argtype = type(select(1, ...))
	if argtype == 'boolean' then return clear(...) end

	local converter = argtype == 'table' and cindy.bytes2table or cindy.byte2channel
	local args, i = {...}, 1

	repeat
		args[i] = converter(args[i], tempTables[i])
		i = i + 1
	until type(args[i]) ~= argtype

	return clear(unpack(args))
end

---------------------------------------------------------------------------------------------------------------------

function ImageData:getPixelBytes(x, y)
	return cindy.rgba2bytes(getPixel(self, x, y))
end

function ImageData:setPixelBytes(x, y, r, g, b, a)
	return setPixel(self, x, y, cindy.bytes2rgba(r, g, b, a))
end

function ImageData:mapPixelBytes(fn)
	return mapPixel(self, function(x, y, r, g, b, a)
		return cindy.bytes2rgba(fn(x, y, cindy.rgba2bytes(r, g, b, a)))
	end)
end

---------------------------------------------------------------------------------------------------------------------

function ParticleSystem:setColorsBytes(...)
	local args, nargs = {...}, select('#', ...)

	if type(args[1]) == 'table' then
		for i = 1, nargs do
			args[i] = cindy.bytes2table(args[i], tempTables[i])
		end
	else
		for i = 1, nargs do
			args[i] = args[i] / 255
		end
	end

	return setParticleColors(self, unpack(args))
end

function ParticleSystem:getColorsBytes()
	local colors = { getParticleColors(self) }
	local ncolors = #colors

	for i = 1, ncolors do
		local rgba = colors[i]
		rgba[1], rgba[2], rgba[3], rgba[4] = cindy.rgba2bytes(rgba[1], rgba[2], rgba[3], rgba[4])
	end

	return unpack(colors)
end

---------------------------------------------------------------------------------------------------------------------

function SpriteBatch:getColorBytes()
	local r, g, b, a = getBatchColor(self)

	if r then
		return cindy.rgba2bytes(r, g, b, a)
	end
end

function SpriteBatch:setColorBytes(r, g, b, a)
	if r then
		return setBatchColor(self, cindy.bytes2color(r, g, b, a))
	end

	return setBatchColor(self)
end

---------------------------------------------------------------------------------------------------------------------

function Shader:sendColorBytes(name, ...)
	local colors, ncolors = {...}, select('#', ...)

	for i = 1, ncolors do
		colors[i] = cindy.bytes2table(colors[i], tempTables[i])
	end

	return sendColor(self, name, unpack(colors))
end

---------------------------------------------------------------------------------------------------------------------

return cindy
