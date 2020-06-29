local api = require("api")

local compression_map = {}
for entry in ("\n 0123456789abcdefghijklmnopqrstuvwxyz!#%(){}[]<>+=/*:;.,~_"):gmatch(
	"."
) do
	table.insert(compression_map, entry)
end

local function decompress(code)
	local lua = ""
	local mode = 0
	local copy = nil
	local i = 8
	local codelen = bit.lshift(code:byte(5, 5), 8) + code:byte(6, 6)
	log("codelen", codelen)
	while #lua < codelen do
		i = i + 1
		local byte = string.byte(code, i, i)
		if byte == nil then
			error("reached end of code")
		else
			if mode == 1 then
				lua = lua .. code:sub(i, i)
				mode = 0
			elseif mode == 2 then
				-- copy from buffer
				local offset = (copy - 0x3c) * 16 + bit.band(byte, 0xf)
				local length = bit.rshift(byte, 4) + 2
				offset = #lua - offset
				local buffer = lua:sub(offset + 1, offset + length)
				lua = lua .. buffer
				mode = 0
			elseif byte == 0x00 then
				-- output next byte
				mode = 1
			elseif byte >= 0x01 and byte <= 0x3b then
				-- output this byte from map
				lua = lua .. compression_map[byte]
			elseif byte >= 0x3c then
				-- copy previous bytes
				mode = 2
				copy = byte
			end
		end
	end
	return lua
end

local cart = {}

function cart.load_p8(filename)
	log("Loading", filename)

	local lua = ""
	pico8.quads = {}
	pico8.spritesheet_data = love.image.newImageData(128, 128)
	pico8.map = {}
	for y = 0, 63 do
		pico8.map[y] = {}
		for x = 0, 127 do
			pico8.map[y][x] = 0
		end
	end
	pico8.spriteflags = {}
	for i = 0, 255 do
		pico8.spriteflags[i] = 0
	end
	pico8.sfx = {}
	for i = 0, 63 do
		pico8.sfx[i] = {
			editor_mode = 0,
			speed = 16,
			loop_start = 0,
			loop_end = 0
		}
		for j = 0, 31 do
			pico8.sfx[i][j] = {0, 0, 0, 0}
		end
	end
	pico8.music = {}
	for i = 0, 63 do
		pico8.music[i] = {
			loop = 0,
			[0] = 1,
			[1] = 2,
			[2] = 3,
			[3] = 4
		}
	end

	local fileheader = love.filesystem.read(filename, 8)
	if fileheader == "\137PNG\r\n\26\n" then
		local data = love.image.newImageData(filename)
		if data:getWidth() ~= 160 or data:getHeight() ~= 205 then
			error("Image is the wrong size")
		end

		local outX = 0
		local outY = 0
		local inbyte = 0
		local lastbyte = nil
		local mapY = 32
		local mapX = 0
		local version = nil
		local compressed = false
		local sprite = 0
		for y = 0, 204 do
			for x = 0, 159 do
				local r, g, b, a = data:getPixel(x, y)
				-- extract lowest bits
				r = bit.band(r, 0x0003)
				g = bit.band(g, 0x0003)
				b = bit.band(b, 0x0003)
				a = bit.band(a, 0x0003)
				data:setPixel(
					x,
					y,
					bit.lshift(r, 6),
					bit.lshift(g, 6),
					bit.lshift(b, 6),
					255
				)
				local byte = bit.lshift(a, 6) + bit.lshift(r, 4) + bit.lshift(g, 2) + b
				local lo = bit.band(byte, 0x0f)
				local hi = bit.rshift(byte, 4)
				if inbyte < 0x2000 then
					-- spritesheet
					if outY >= 64 then
						pico8.map[mapY][mapX] = byte
						mapX = mapX + 1
						if mapX == 128 then
							mapX = 0
							mapY = mapY + 1
						end
					end
					pico8.spritesheet_data:setPixel(outX, outY, lo * 16, lo * 16, lo * 16)
					outX = outX + 1
					pico8.spritesheet_data:setPixel(outX, outY, hi * 16, hi * 16, hi * 16)
					outX = outX + 1
					if outX == 128 then
						outY = outY + 1
						outX = 0
						if outY == 128 then
							-- end of spritesheet, generate quads
							pico8.spritesheet = love.graphics.newImage(pico8.spritesheet_data)
							local spriteCounter = 0
							for yy = 0, 15 do
								for xx = 0, 15 do
									pico8.quads[spriteCounter] =
										love.graphics.newQuad(
										xx * 8,
										yy * 8,
										8,
										8,
										pico8.spritesheet:getDimensions()
									)
									spriteCounter = spriteCounter + 1
								end
							end
							mapY = 0
							mapX = 0
						end
					end
				elseif inbyte < 0x3000 then
					-- map data
					pico8.map[mapY][mapX] = byte
					mapX = mapX + 1
					if mapX == 128 then
						mapX = 0
						mapY = mapY + 1
					end
				elseif inbyte < 0x3100 then
					-- sprite flags
					pico8.spriteflags[sprite] = byte
					sprite = sprite + 1
				elseif inbyte < 0x3200 then
					-- music
					local _music = math.floor((inbyte - 0x3100) / 4)
					pico8.music[_music][inbyte % 4] = bit.band(byte, 0x7F)
					pico8.music[_music].loop =
						bit.bor(
						bit.rshift(bit.band(byte, 0x80), 7 - inbyte % 4),
						pico8.music[_music].loop
					)
				elseif inbyte < 0x4300 then
					-- sfx
					local _sfx = math.floor((inbyte - 0x3200) / 68)
					local step = (inbyte - 0x3200) % 68
					if step < 64 and inbyte % 2 == 1 then
						local note = bit.lshift(byte, 8) + lastbyte
						pico8.sfx[_sfx][(step - 1) / 2] = {
							bit.band(note, 0x3f),
							bit.rshift(bit.band(note, 0x1c0), 6),
							bit.rshift(bit.band(note, 0xe00), 9),
							bit.rshift(bit.band(note, 0x7000), 12)
						}
					elseif step == 64 then
						pico8.sfx[_sfx].editor_mode = byte
					elseif step == 65 then
						pico8.sfx[_sfx].speed = byte
					elseif step == 66 then
						pico8.sfx[_sfx].loop_start = byte
					elseif step == 67 then
						pico8.sfx[_sfx].loop_end = byte
					end
				elseif inbyte < 0x8000 then
					-- code, possibly compressed
					if inbyte == 0x4300 then
						compressed = (byte == 58)
					end
					lua = lua .. string.char(byte)
				elseif inbyte == 0x8000 then
					version = byte
				end
				lastbyte = byte
				inbyte = inbyte + 1
			end
		end

		-- decompress code
		log("version", version)
		if version > 8 then
			api.print(string.format("unknown file version %d", version), nil, nil, 3)
		end

		if compressed then
			lua = decompress(lua)
		else
			lua = lua:match("(.-)%f[%z]")
		end
	else
		local data, size = love.filesystem.read(filename)
		if not data or size == 0 then
			error(string.format("Unable to open: %s", filename))
		end

		-- strip carriage returns pico-8 style
		data = data:gsub("\r\n", "\n")
		-- tack on a fake header
		if data:sub(-1) ~= "\n" then
			data = data .. "\n"
		end
		data = data .. "__eof__\n"

		-- check for header and vesion
		local header = "pico-8 cartridge // http://www.pico-8.com\nversion "
		local start =
			data:find("pico%-8 cartridge // http://www.pico%-8%.com\nversion ")
		if start == nil then
			error("invalid cart")
		end
		local next_line = data:find("\n", start + #header)
		local version_str = data:sub(start + #header, next_line - 1)
		local version = tonumber(version_str)
		log("version", version)

		-- extract the lua
		lua = data:match("\n__lua__.-\n(.-)\n__") or ""

		-- load the sprites into an imagedata
		-- generate a quad for each sprite index
		local gfxdata = data:match("\n__gfx__.-\n(.-\n)\n-__")

		local shared = 0

		if gfxdata then
			local row = 0

			for line in gfxdata:gmatch("(.-)\n") do
				local col = 0
				for v in line:gmatch(".") do
					v = tonumber(v, 16)
					pico8.spritesheet_data:setPixel(col, row, v * 16, v * 16, v * 16, 255)

					col = col + 1
					if col == 128 then
						break
					end
				end

				row = row + 1
				if row == 128 then
					break
				end
			end
		end

		if version > 3 then
			local tx, ty = 0, 32
			for sy = 64, 127 do
				for sx = 0, 127, 2 do
					-- get the two pixel values and merge them
					local lo = api.flr(pico8.spritesheet_data:getPixel(sx, sy) / 16)
					local hi = api.flr(pico8.spritesheet_data:getPixel(sx + 1, sy) / 16)
					local v = bit.bor(bit.lshift(hi, 4), lo)
					pico8.map[ty][tx] = v
					shared = shared + 1
					tx = tx + 1
					if tx == 128 then
						tx = 0
						ty = ty + 1
					end
				end
			end
		end

		for y = 0, 15 do
			for x = 0, 15 do
				pico8.quads[y * 16 + x] =
					love.graphics.newQuad(8 * x, 8 * y, 8, 8, 128, 128)
			end
		end

		pico8.spritesheet = love.graphics.newImage(pico8.spritesheet_data)

		-- load the sprite flags
		local gffdata = data:match("\n__gff__.-\n(.-\n)\n-__")

		if gffdata then
			local sprite = 0
			local gffpat = (version <= 2 and "." or "..")

			for line in gffdata:gmatch("(.-)\n") do
				local col = 0

				for v in line:gmatch(gffpat) do
					v = tonumber(v, 16)
					pico8.spriteflags[sprite + col] = v
					col = col + 1

					if col == 128 then
						break
					end
				end

				sprite = sprite + 128
				if sprite == 256 then
					break
				end
			end
		end

		-- convert the tile data to a table
		local mapdata = data:match("\n__map__.-\n(.-\n)\n-__")

		if mapdata then
			local row = 0
			local tiles = 0

			for line in mapdata:gmatch("(.-)\n") do
				local col = 0

				for v in line:gmatch("..") do
					v = tonumber(v, 16)
					pico8.map[row][col] = v
					col = col + 1
					tiles = tiles + 1

					if col == 128 then
						break
					end
				end
				row = row + 1

				if row == 32 then
					break
				end
			end

		--assert(tiles + shared == 128 * 64, string.format("%d + %d != %d", tiles, shared, 128 * 64))
		end

		-- load sfx
		local sfxdata = data:match("\n__sfx__.-\n(.-\n)\n-__")

		if sfxdata then
			local _sfx = 0

			for line in sfxdata:gmatch("(.-)\n") do
				pico8.sfx[_sfx].editor_mode = tonumber(line:sub(1, 2), 16)
				pico8.sfx[_sfx].speed = tonumber(line:sub(3, 4), 16)
				pico8.sfx[_sfx].loop_start = tonumber(line:sub(5, 6), 16)
				pico8.sfx[_sfx].loop_end = tonumber(line:sub(7, 8), 16)
				local step = 0

				for i = 9, #line, 5 do
					local v = line:sub(i, i + 4)
					assert(#v == 5)
					local note = tonumber(line:sub(i, i + 1), 16)
					local instr = tonumber(line:sub(i + 2, i + 2), 16)
					local vol = tonumber(line:sub(i + 3, i + 3), 16)
					local fx = tonumber(line:sub(i + 4, i + 4), 16)
					pico8.sfx[_sfx][step] = {note, instr, vol, fx}
					step = step + 1

					if step == 32 then
						break
					end
				end
				_sfx = _sfx + 1

				if _sfx == 64 then
					break
				end
			end
		end

		-- load music
		local musicdata = data:match("\n__music__.-\n(.-\n)\n-__")

		if musicdata then
			local _music = 0

			for line in musicdata:gmatch("(.-)\n") do
				pico8.music[_music] = {
					loop = tonumber(line:sub(1, 2), 16),
					[0] = tonumber(line:sub(4, 5), 16),
					[1] = tonumber(line:sub(6, 7), 16),
					[2] = tonumber(line:sub(8, 9), 16),
					[3] = tonumber(line:sub(10, 11), 16)
				}

				_music = _music + 1
				if _music == 64 then
					break
				end
			end

		--assert(_music == 64, string.format("%d", _music))
		end
	end

	lua = patch_lua(lua)

	log("finished loading cart", filename)

	loaded_code = lua

	return true
end

return cart
