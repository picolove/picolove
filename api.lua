local api = {}

local flr = math.floor

local function color(c)
	c = flr(c or 0) % 16
	pico8.color = c
	setColor(c)
end

local function warning(msg)
	log(debug.traceback("WARNING: " .. msg, 3))
end

local function _horizontal_line(lines, x0, y, x1)
	table.insert(lines, {x0 + 0.5, y + 0.5, x1 + 0.5, y + 0.5})
end

local function _plot4points(lines, cx, cy, x, y)
	_horizontal_line(lines, cx - x, cy + y, cx + x)
	if y ~= 0 then
		_horizontal_line(lines, cx - x, cy - y, cx + x)
	end
end

local function scroll(pixels)
	local base = 0x6000
	local delta = base + pixels * 0x40
	local basehigh = 0x8000
	api.memcpy(base, delta, basehigh - delta)
end

local function setfps(fps)
	pico8.fps = flr(fps)
	if pico8.fps <= 0 then
		pico8.fps = 30
	end
	pico8.frametime = 1 / pico8.fps
end

local function getmousex()
	return flr((love.mouse.getX() - xpadding) / scale)
end

local function getmousey()
	return flr((love.mouse.getY() - ypadding) / scale)
end

-- extra functions provided by picolove
api.warning = warning
api.setfps = setfps

function api._getcursorx()
	return pico8.cursor[1]
end

function api._getcursory()
	return pico8.cursor[2]
end

function api._call(code)
	code = patch_lua(code)

	local ok, f, e = pcall(load, code, "repl")
	if not ok or f == nil then
		api.print("syntax error", nil, nil, 14)
		api.print(api.sub(e, 20), nil, nil, 6)
		return false
	else
		setfenv(f, pico8.cart)
		ok, e = pcall(f)
		if not ok then
			api.print("runtime error", nil, nil, 14)
			api.print(api.sub(e, 20), nil, nil, 6)
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- PICO-8 API

function api.flip()
	flip_screen()
	love.timer.sleep(pico8.frametime)
end

function api.camera(x, y)
	pico8.camera_x = flr(tonumber(x) or 0)
	pico8.camera_y = flr(tonumber(y) or 0)
	restore_camera()
end

function api.clip(x, y, w, h)
	if type(x) == "number" then
		love.graphics.setScissor(x, y, w, h)
		pico8.clip = {x, y, w, h}
	else
		love.graphics.setScissor(0, 0, pico8.resolution[1], pico8.resolution[2])
		pico8.clip = {0, 0, pico8.resolution[1], pico8.resolution[2]}
	end
end

function api.cls(c)
	c = flr(tonumber(c) or 0) % 16
	c = c + 1 -- TODO: fix workaround

	love.graphics.clear(c * 16, 0, 0, 255)
	pico8.cursor = {0, 0}
end

function api.folder()
	love.system.openURL("file://" .. love.filesystem.getWorkingDirectory())
end

function api._completecommand(command, path)
	-- TODO: handle depending on command

	local startDir = ""
	local pos = path:find("/", 1, true)
	if pos ~= nil then
		startDir = startDir .. path:sub(1, pos)
		path = path:sub(pos + 1)
	end
	local files = love.filesystem.getDirectoryItems(currentDirectory .. startDir)

	local filteredFiles = {}
	for _, file in ipairs(files) do
		if string.sub(file:lower(), 1, string.len(path)) == path then
			filteredFiles[#filteredFiles + 1] = file
		end
	end
	files = filteredFiles

	local result
	if #files == 0 then
		result = path
	elseif #files == 1 then
		if love.filesystem.isDirectory(currentDirectory .. startDir .. files[1]) then
			result = files[1]:lower() .. "/"
		else
			result = files[1]:lower()
		end
	else
		local matches
		local match = path

		repeat
			result = match
			if #match == #files[1] then
				break
			end

			match = files[1]:sub(1, #match + 1)
			matches = 0
			for _, file in ipairs(files) do
				if string.sub(file:lower(), 1, string.len(match)) == match then
					matches = matches + 1
				end
			end
		until matches ~= #files

		result = result:lower()

		if #result == #path then
			-- TODO: remove duplicate code (see api.ls())
			local output = {}
			for _, file in ipairs(files) do
				if love.filesystem.isDirectory(currentDirectory .. file) then
					output[#output + 1] = {name = file:lower(), color = 14}
				elseif file:sub(-3) == ".p8" or file:sub(-4) == ".png" then
					output[#output + 1] = {name = file:lower(), color = 6}
				else
					output[#output + 1] = {name = file:lower(), color = 5}
				end
			end

			local count = 0
			love.keyboard.setTextInput(false)
			api.color(12)
			api.print(#output .. " files")
			for _, item in ipairs(output) do
				api.color(item.color)
				for j = 1, #item.name, 32 do
					api.print(item.name:sub(j, j + 32))
					flip_screen()
					count = count + 1
					if count == 20 then
						api.print("--more--", nil, nil, 12)
						flip_screen()
						local y = api._getcursory() - 6
						api.cursor(0, y)
						api.rectfill(0, y, 127, y + 6, 0)
						api.color(item.color)
						while true do
							local e = love.event.wait()
							if e == "keypressed" then
								break
							end
						end
						count = 0
					end
				end
			end
			love.keyboard.setTextInput(true)
		end
	end

	return command .. " " .. startDir .. result
end

-- TODO: move interactive implementatn into nocart
-- TODO: should return table of strings
function api.ls()
	local files = love.filesystem.getDirectoryItems(currentDirectory)
	api.print("directory: " .. currentDirectory, nil, nil, 12)
	local output = {}
	for _, file in ipairs(files) do
		if love.filesystem.isDirectory(currentDirectory .. file) then
			output[#output + 1] = {name = file:lower(), color = 14}
		elseif file:sub(-3) == ".p8" or file:sub(-4) == ".png" then
			output[#output + 1] = {name = file:lower(), color = 6}
		else
			output[#output + 1] = {name = file:lower(), color = 5}
		end
	end
	local count = 0
	love.keyboard.setTextInput(false)
	for _, item in ipairs(output) do
		api.color(item.color)
		for j = 1, #item.name, 32 do
			api.print(item.name:sub(j, j + 32))
			flip_screen()
			count = count + 1
			if count == 20 then
				api.print("--more--", nil, nil, 12)
				flip_screen()
				local y = api._getcursory() - 6
				api.cursor(0, y)
				api.rectfill(0, y, 127, y + 6, 0)
				api.color(item.color)
				while true do
					local e = love.event.wait()
					if e == "keypressed" then
						break
					end
				end
				count = 0
			end
		end
	end
	love.keyboard.setTextInput(true)
end

api.dir = api.ls

function api.cd(name)
	local output, count

	name = name .. "/"

	-- filter /TEXT//$ -> /
	count = 1
	while count > 0 do
		name, count = name:gsub("//", "/")
	end

	local newDirectory = currentDirectory .. name

	if name == "/" then
		newDirectory = "/"
	end

	-- filter /TEXT/../ -> /
	count = 1
	while count > 0 do
		newDirectory, count = newDirectory:gsub("/[^/]*/%.%./", "/")
	end

	-- filter /TEXT/..$ -> /
	count = 1
	while count > 0 do
		newDirectory, count = newDirectory:gsub("/[^/]*/%.%.$", "/")
	end

	local failed = newDirectory:find("%.%.") ~= nil
	failed = failed or newDirectory:find("/[ ]+/") ~= nil

	if #name == 0 then
		output = "directory: " .. currentDirectory
	elseif failed then
		if newDirectory == "/../" then
			output = "cd: failed"
		else
			output = "directory not found"
		end
	elseif love.filesystem.exists(newDirectory) then
		currentDirectory = newDirectory
		output = currentDirectory
	else
		failed = true
		output = "directory not found"
	end

	if not failed then
		api.color(12)
		for i = 1, #output, 32 do
			api.print(output:sub(i, i + 32))
		end
	else
		api.color(7)
		api.print(output)
	end
end

function api.mkdir(name)
	if name == nil then
		api.color(6)
		api.print("mkdir [name]")
	else
		love.filesystem.createDirectory(currentDirectory .. name)
	end
end

function api.install_demos()
	-- TODO: implement this
end

function api.install_games()
	-- TODO: implement this
end

function api.keyconfig()
	-- TODO: implement this
end

function api.splore()
	-- TODO: implement this
end

function api.pset(x, y, c)
	if c then
		color(c)
	end
	love.graphics.point(flr(x), flr(y))
end

function api.pget(x, y)
	if x >= 0 and x < pico8.resolution[1] and y >= 0 and y < pico8.resolution[2] then
		love.graphics.setCanvas()
		local __screen_img = pico8.screen:newImageData()
		love.graphics.setCanvas(pico8.screen)
		local r = __screen_img:getPixel(flr(x), flr(y))
		return flr(r / 17.0)
	end
	warning(string.format("pget out of screen %d, %d", x, y))
	return 0
end

function api.color(c)
	color(c)
end

-- workaround for non printable chars
local tostring_org = tostring
local function tostring(str)
	return tostring_org(str):gsub("[^%z\32-\127]", "8")
end

function api.print(str, x, y, col)
	--TODO: support printing special pico8 chars
	if col then
		color(col)
	end
	local canscroll = y == nil
	if y == nil then
		y = pico8.cursor[2]
		pico8.cursor[2] = pico8.cursor[2] + 6
	end
	if x == nil then
		x = pico8.cursor[1]
	end
	if canscroll and y > 121 then
		local c = col or pico8.color
		scroll(6)
		y = 120
		api.rectfill(0, y, 127, y + 6, 0)
		api.color(c)
		api.cursor(0, y + 6)
	end
	local to_print = tostring(str):gsub("[^%z\32-\127]", " ")
	love.graphics.setShader(pico8.text_shader)
	love.graphics.print(to_print, flr(x), flr(y))
end

api.printh = print

function api.cursor(x, y, col)
	if col then
		color(col)
	end
	x = flr(tonumber(x) or 0) % 256
	y = flr(tonumber(y) or 0) % 256
	pico8.cursor = {x, y}
end

function api.tonum(val)
	return tonumber(val) -- not a direct assignment to prevent usage of the radix argument
end

function api.tostr(val, hex)
	local kind = type(val)
	if kind == "string" then
		return val
	elseif kind == "number" then
		if hex then
			val = val * 0x10000
			local part1 = bit.rshift(bit.band(val, 0xFFFF0000), 16)
			local part2 = bit.band(val, 0xFFFF)
			return string.format("0x%04x.%04x", part1, part2)
		else
			return tostring(val)
		end
	elseif kind == "boolean" then
		return tostring(val)
	else
		return "[" .. kind .. "]"
	end
end

function api.spr(n, x, y, w, h, flip_x, flip_y)
	love.graphics.setShader(pico8.sprite_shader)
	pico8.sprite_shader:send("transparent", shdr_unpack(pico8.pal_transparent))
	n = flr(n)
	w = w or 1
	h = h or 1
	local q
	if w == 1 and h == 1 then
		q = pico8.quads[n]
		if not q then
			log("warning: sprite " .. n .. " is missing")
			return
		end
	else
		local id = string.format("%d-%d-%d", n, w, h)
		if pico8.quads[id] then
			q = pico8.quads[id]
		else
			q =
				love.graphics.newQuad(
				flr(n % 16) * 8,
				flr(n / 16) * 8,
				8 * w,
				8 * h,
				128,
				128
			)
			pico8.quads[id] = q
		end
	end
	if not q then
		log("missing quad", n)
	end
	love.graphics.draw(
		pico8.spritesheet,
		q,
		flr(x) + (w * 8 * (flip_x and 1 or 0)),
		flr(y) + (h * 8 * (flip_y and 1 or 0)),
		0,
		flip_x and -1 or 1,
		flip_y and -1 or 1
	)
	love.graphics.setShader(pico8.draw_shader)
end

function api.sspr(sx, sy, sw, sh, dx, dy, dw, dh, flip_x, flip_y)
	-- Stretch rectangle from sprite sheet (sx, sy, sw, sh) // given in pixels
	-- and draw in rectangle (dx, dy, dw, dh)
	-- Color 0 drawn as transparent by default (see palt())
	-- dw, dh defaults to sw, sh
	-- flip_x = true to flip horizontally
	-- flip_y = true to flip vertically
	dw = dw or sw
	dh = dh or sh
	-- FIXME: cache this quad
	local q =
		love.graphics.newQuad(sx, sy, sw, sh, pico8.spritesheet:getDimensions())
	love.graphics.setShader(pico8.sprite_shader)
	pico8.sprite_shader:send("transparent", shdr_unpack(pico8.pal_transparent))
	love.graphics.draw(
		pico8.spritesheet,
		q,
		flr(dx) + (flip_x and dw or 0),
		flr(dy) + (flip_y and dh or 0),
		0,
		dw / sw * (flip_x and -1 or 1),
		dh / sh * (flip_y and -1 or 1)
	)
	love.graphics.setShader(pico8.draw_shader)
end

function api.rect(x0, y0, x1, y1, col)
	if col then
		color(col)
	end
	love.graphics.rectangle(
		"line",
		flr(x0) + 1,
		flr(y0) + 1,
		flr(x1 - x0),
		flr(y1 - y0)
	)
end

function api.rectfill(x0, y0, x1, y1, col)
	if col then
		color(col)
	end
	if x1 < x0 then
		x0, x1 = x1, x0
	end
	if y1 < y0 then
		y0, y1 = y1, y0
	end
	love.graphics.rectangle(
		"fill",
		flr(x0),
		flr(y0),
		flr(x1 - x0) + 1,
		flr(y1 - y0) + 1
	)
end

function api.circ(ox, oy, r, col)
	if col then
		color(col)
	end
	ox = flr(ox)
	oy = flr(oy)
	r = flr(r)
	local points = {}
	local x = r
	local y = 0
	local decisionOver2 = 1 - x

	while y <= x do
		table.insert(points, {ox + x, oy + y})
		table.insert(points, {ox + y, oy + x})
		table.insert(points, {ox - x, oy + y})
		table.insert(points, {ox - y, oy + x})

		table.insert(points, {ox - x, oy - y})
		table.insert(points, {ox - y, oy - x})
		table.insert(points, {ox + x, oy - y})
		table.insert(points, {ox + y, oy - x})
		y = y + 1
		if decisionOver2 < 0 then
			decisionOver2 = decisionOver2 + 2 * y + 1
		else
			x = x - 1
			decisionOver2 = decisionOver2 + 2 * (y - x) + 1
		end
	end
	if #points > 0 then
		love.graphics.points(points)
	end
end

function api.circfill(cx, cy, r, col)
	if col then
		color(col)
	end
	cx = flr(cx)
	cy = flr(cy)
	r = flr(r)
	local x = r
	local y = 0
	local err = 1 - r

	local lines = {}

	while y <= x do
		_plot4points(lines, cx, cy, x, y)
		if err < 0 then
			err = err + 2 * y + 3
		else
			if x ~= y then
				_plot4points(lines, cx, cy, y, x)
			end
			x = x - 1
			err = err + 2 * (y - x) + 3
		end
		y = y + 1
	end
	if #lines > 0 then
		for i = 1, #lines do
			love.graphics.line(lines[i])
		end
	end
end

function api.oval(x1, y1, x2, y2, col)
	_ellipse("line", x1, y1, x2, y2, col)
end

function api.ovalfill(x1, y1, x2, y2, col)
	_ellipse("fill", x1, y1, x2, y2, col)
end

function _ellipse(drawmode, x1, y1, x2, y2, col)
	assert(drawmode == "line" or drawmode == "fill")
	assert(x1 ~= nil and x2 ~= nil)
	assert(y1 ~= nil and y2 ~= nil)
	assert((col >= 0 and col <=15) or col == nil)

	if col then
		color(col)
	end

	local rx = (x2 - x1) / 2
	local ry = (y2 - y1) / 2
	local x = x1 + rx
	local y = y1 + ry
	love.graphics.ellipse(drawmode, x, y, rx, ry)
end

function api.line(x0, y0, x1, y1, col)
	if col then
		color(col)
	end

	if x0 ~= x0 or y0 ~= y0 or x1 ~= x1 or y1 ~= y1 then
		warning("line has NaN value")
		return
	end

	x0 = flr(x0)
	y0 = flr(y0)
	x1 = flr(x1)
	y1 = flr(y1)

	local dx = x1 - x0
	local dy = y1 - y0
	local stepx, stepy

	local points = {{x0, y0}}

	if dx == 0 then
		-- simple case draw a vertical line
		points = {}
		if y0 > y1 then
			y0, y1 = y1, y0
		end
		for y = y0, y1 do
			table.insert(points, {x0, y})
		end
	elseif dy == 0 then
		-- simple case draw a horizontal line
		points = {}
		if x0 > x1 then
			x0, x1 = x1, x0
		end
		for x = x0, x1 do
			table.insert(points, {x, y0})
		end
	else
		if dy < 0 then
			dy = -dy
			stepy = -1
		else
			stepy = 1
		end

		if dx < 0 then
			dx = -dx
			stepx = -1
		else
			stepx = 1
		end

		if dx > dy then
			local fraction = dy - bit.rshift(dx, 1)
			while x0 ~= x1 do
				if fraction >= 0 then
					y0 = y0 + stepy
					fraction = fraction - dx
				end
				x0 = x0 + stepx
				fraction = fraction + dy
				table.insert(points, {flr(x0), flr(y0)})
			end
		else
			local fraction = dx - bit.rshift(dy, 1)
			while y0 ~= y1 do
				if fraction >= 0 then
					x0 = x0 + stepx
					fraction = fraction - dy
				end
				y0 = y0 + stepy
				fraction = fraction + dx
				table.insert(points, {flr(x0), flr(y0)})
			end
		end
	end
	love.graphics.points(points)
end

local __palette_modified = true

function api.pal(c0, c1, p)
	if type(c0) ~= "number" then
		if __palette_modified == false then
			return
		end
		for i = 1, 16 do
			pico8.draw_palette[i] = i
			pico8.display_palette[i] = pico8.palette[i]
		end
		pico8.draw_shader:send("palette", shdr_unpack(pico8.draw_palette))
		pico8.sprite_shader:send("palette", shdr_unpack(pico8.draw_palette))
		pico8.text_shader:send("palette", shdr_unpack(pico8.draw_palette))
		pico8.display_shader:send("palette", shdr_unpack(pico8.display_palette))
		__palette_modified = false
		-- According to PICO-8 manual:
		-- pal() to reset to system defaults (including transparency values)
		api.palt()
	elseif p == 1 and c1 ~= nil then
		c0 = flr(c0) % 16
		c1 = flr(c1) % 16
		c1 = c1 + 1
		c0 = c0 + 1
		pico8.display_palette[c0] = pico8.palette[c1]
		pico8.display_shader:send("palette", shdr_unpack(pico8.display_palette))
		__palette_modified = true
	elseif c1 ~= nil then
		c0 = flr(c0) % 16
		c1 = flr(c1) % 16
		c1 = c1 + 1
		c0 = c0 + 1
		pico8.draw_palette[c0] = c1
		pico8.draw_shader:send("palette", shdr_unpack(pico8.draw_palette))
		pico8.sprite_shader:send("palette", shdr_unpack(pico8.draw_palette))
		pico8.text_shader:send("palette", shdr_unpack(pico8.draw_palette))
		__palette_modified = true
	end
end

function api.palt(c, t)
	if type(c) ~= "number" then
		for i = 1, 16 do
			pico8.pal_transparent[i] = i == 1 and 0 or 1
		end
	else
		c = flr(c) % 16
		pico8.pal_transparent[c + 1] = t and 0 or 1
	end
	pico8.sprite_shader:send("transparent", shdr_unpack(pico8.pal_transparent))
end

function api.fillp(_)
	-- TODO: implement this
end

function api.map(cel_x, cel_y, sx, sy, cel_w, cel_h, bitmask)
	love.graphics.setShader(pico8.sprite_shader)
	love.graphics.setColor(255, 255, 255, 255)
	cel_x = flr(cel_x or 0)
	cel_y = flr(cel_y or 0)
	sx = flr(sx or 0)
	sy = flr(sy or 0)
	cel_w = flr(cel_w or 128)
	cel_h = flr(cel_h or 64)
	for y = 0, cel_h - 1 do
		if cel_y + y < 64 and cel_y + y >= 0 then
			for x = 0, cel_w - 1 do
				if cel_x + x < 128 and cel_x + x >= 0 then
					local v = pico8.map[flr(cel_y + y)][flr(cel_x + x)]
					if v > 0 then
						if bitmask == nil or bitmask == 0 then
							love.graphics.draw(
								pico8.spritesheet,
								pico8.quads[v],
								sx + 8 * x,
								sy + 8 * y
							)
						else
							if bit.band(pico8.spriteflags[v], bitmask) ~= 0 then
								love.graphics.draw(
									pico8.spritesheet,
									pico8.quads[v],
									sx + 8 * x,
									sy + 8 * y
								)
							end
						end
					end
				end
			end
		end
	end
	love.graphics.setShader(pico8.draw_shader)
end
-- deprecated pico-8 function
api.mapdraw = api.map

function api.mget(x, y)
	x = flr(x or 0)
	y = flr(y or 0)
	if x >= 0 and x < 128 and y >= 0 and y < 64 then
		return pico8.map[y][x]
	end
	return 0
end

function api.mset(x, y, v)
	x = flr(x or 0)
	y = flr(y or 0)
	v = flr(v or 0) % 256
	if x >= 0 and x < 128 and y >= 0 and y < 64 then
		pico8.map[y][x] = v
	end
end

function api.fget(n, f)
	if n == nil then
		return nil
	end
	if f ~= nil then
		-- return just that bit as a boolean
		if not pico8.spriteflags[flr(n)] then
			warning(string.format("fget(%d, %d)", n, f))
			return false
		end
		return bit.band(pico8.spriteflags[flr(n)], bit.lshift(1, flr(f))) ~= 0
	end
	return pico8.spriteflags[flr(n)] or 0
end

function api.fset(n, f, v)
	-- fset n [f] v
	-- f is the flag index 0..7
	-- v is boolean
	if v == nil then
		v, f = f, nil
	end
	if f then
		-- set specific bit to v (true or false)
		if v then
			pico8.spriteflags[n] = bit.bor(pico8.spriteflags[n], bit.lshift(1, f))
		else
			pico8.spriteflags[n] =
				bit.band(pico8.spriteflags[n], bit.bnot(bit.lshift(1, f)))
		end
	else
		-- set bitfield to v (number)
		pico8.spriteflags[n] = v
	end
end

function api.sget(x, y)
	-- return the color from the spritesheet
	x = flr(tonumber(x) or 0)
	y = flr(tonumber(y) or 0)

	if x >= 0 and x < 128 and y >= 0 and y < 128 then
		local c = pico8.spritesheet_data:getPixel(x, y)
		return flr(c / 16)
	end
	return 0
end

function api.sset(x, y, c)
	x = flr(tonumber(x) or 0)
	y = flr(tonumber(y) or 0)
	c = flr(tonumber(c) or 0)
	pico8.spritesheet_data:setPixel(x, y, c * 16, 0, 0, 255)
	pico8.spritesheet:refresh()
end

function api.music(n, fade_len, channel_mask) -- luacheck: no unused
	-- TODO: implement fade out
	if n == -1 then
		if pico8.current_music then
			for i = 0, 3 do
				if pico8.music[pico8.current_music.music][i] < 64 then
					pico8.audio_channels[i].sfx = nil
					pico8.audio_channels[i].offset = 0
					pico8.audio_channels[i].last_step = -1
				end
			end
			pico8.current_music = nil
		end
		return
	end
	local m = pico8.music[n]
	if not m then
		warning(string.format("music %d does not exist", n))
		return
	end
	local music_speed = nil
	local music_channel = nil
	for i = 0, 3 do
		if m[i] < 64 then
			local sfx = pico8.sfx[m[i]]
			if music_speed == nil or music_speed > sfx.speed then
				music_speed = sfx.speed
				music_channel = i
			end
		end
	end
	pico8.audio_channels[music_channel].loop = false
	pico8.current_music = {
		music = n,
		offset = 0,
		channel_mask = channel_mask or 15,
		speed = music_speed
	}
	for i = 0, 3 do
		if pico8.music[n][i] < 64 then
			pico8.audio_channels[i].sfx = pico8.music[n][i]
			pico8.audio_channels[i].offset = 0
			pico8.audio_channels[i].last_step = -1
		end
	end
end

function api.sfx(n, channel, offset)
	-- n = -1 stop sound on channel
	-- n = -2 to stop looping on channel
	channel = channel or -1
	if n == -1 and channel >= 0 then
		pico8.audio_channels[channel].sfx = nil
		return
	elseif n == -2 and channel >= 0 then
		pico8.audio_channels[channel].loop = false
	end
	offset = offset or 0
	if channel == -1 then
		-- find a free channel
		for i = 0, 3 do
			if pico8.audio_channels[i].sfx == nil then
				channel = i
			end
		end
	end
	if channel == -1 then
		return
	end
	local ch = pico8.audio_channels[channel]
	ch.sfx = n
	ch.offset = offset
	ch.last_step = offset - 1
	ch.loop = true
end

function api.peek(addr)
	addr = flr(tonumber(addr) or 0)
	if addr < 0 then
		return 0
	elseif addr < 0x2000 then -- luacheck: ignore 542
		-- TODO: spritesheet data
	elseif addr < 0x3000 then
		addr = addr - 0x2000
		return pico8.map[flr(addr / 128)][addr % 128]
	elseif addr < 0x3100 then
		return pico8.spriteflags[addr - 0x3000]
	elseif addr < 0x3200 then -- luacheck: ignore 542
		-- TODO: music data
	elseif addr < 0x4300 then -- luacheck: ignore 542
		-- TODO: sfx data
	elseif addr < 0x5e00 then
		return pico8.usermemory[addr - 0x4300]
	elseif addr < 0x5f00 then
		local val = pico8.cartdata[flr((addr - 0x5e00) / 4)] * 0x10000
		local shift = (addr % 4) * 8
		return bit.rshift(bit.band(val, bit.lshift(0xFF, shift)), shift)
	elseif addr < 0x5f40 then
		-- TODO: draw state
		if addr == 0x5f20 then
			return pico8.clip[1]
		elseif addr == 0x5f21 then
			return pico8.clip[2]
		elseif addr == 0x5f22 then
			return pico8.clip[1] + pico8.clip[3]
		elseif addr == 0x5f23 then
			return pico8.clip[2] + pico8.clip[4]
		elseif addr == 0x5f25 then
			return pico8.color
		elseif addr == 0x5f26 then
			return pico8.cursor[1]
		elseif addr == 0x5f27 then
			return pico8.cursor[2]
		elseif addr == 0x5f28 then
			return pico8.camera_x % 256
		elseif addr == 0x5f29 then
			return flr(pico8.camera_x / 256)
		elseif addr == 0x5f2a then
			return pico8.camera_y % 256
		elseif addr == 0x5f2b then
			return flr(pico8.camera_y / 256)
		end
	elseif addr < 0x5f80 then -- luacheck: ignore 542
		-- TODO: hardware state
	elseif addr < 0x6000 then -- luacheck: ignore 542
		-- TODO: gpio pins
	elseif addr < 0x8000 then
		-- screen data
		local dx = (addr - 0x6000) % 64
		local dy = flr((addr - 0x6000) / 64)
		local low = api.pget(dx, dy)
		local high = bit.lshift(api.pget(dx + 1, dy), 4)
		return bit.bor(low, high)
	end
	return 0
end

function api.poke(addr, val)
	if tonumber(val) == nil then
		return
	end
	addr, val = flr(tonumber(addr) or 0), flr(val) % 256
	if addr < 0 or addr >= 0x8000 then
		error("bad memory access")
	elseif addr < 0x1000 then -- luacheck: ignore 542
	elseif addr < 0x2000 then -- luacheck: ignore 542
		-- TODO: spritesheet data
	elseif addr < 0x3000 then
		addr = addr - 0x2000
		pico8.map[flr(addr / 128)][addr % 128] = val
	elseif addr < 0x3100 then
		pico8.spriteflags[addr - 0x3000] = val
	elseif addr < 0x3200 then -- luacheck: ignore 542
		-- TODO: music data
	elseif addr < 0x4300 then -- luacheck: ignore 542
		-- TODO: sfx data
	elseif addr < 0x5e00 then
		pico8.usermemory[addr - 0x4300] = val
	elseif addr < 0x5f00 then -- luacheck: ignore 542
		-- TODO: cart data
	elseif addr < 0x5f40 then -- luacheck: ignore 542
		-- TODO: draw state
		if addr == 0x5f26 then
			pico8.cursor[1] = val
		elseif addr == 0x5f27 then
			pico8.cursor[2] = val
		elseif addr == 0x5f28 then
			pico8.camera_x = flr(pico8.camera_x / 256) + val % 256
		elseif addr == 0x5f29 then
			pico8.camera_x = flr((val % 256) * 256) + pico8.camera_x % 256
		elseif addr == 0x5f2a then
			pico8.camera_y = flr(pico8.camera_y / 256) + val % 256
		elseif addr == 0x5f2b then
			pico8.camera_y = flr((val % 256) * 256) + pico8.camera_y % 256
		end
	elseif addr < 0x5f80 then -- luacheck: ignore 542
		-- TODO: hardware state
	elseif addr < 0x6000 then -- luacheck: ignore 542
		-- TODO: gpio pins
	elseif addr < 0x8000 then
		addr = addr - 0x6000
		local dx = addr % 64 * 2
		local dy = flr(addr / 64)
		api.pset(dx, dy, bit.band(val, 15))
		api.pset(dx + 1, dy, bit.rshift(val, 4))
	end
end

function api.peek2(addr)
	local val = 0
	val = val + api.peek(addr + 0)
	val = val + api.peek(addr + 1) * 0x100
	return val
end

function api.peek4(addr)
	local val = 0
	val = val + api.peek(addr + 0) / 0x10000
	val = val + api.peek(addr + 1) / 0x100
	val = val + api.peek(addr + 2)
	val = val + api.peek(addr + 3) * 0x100
	return val
end

function api.poke2(addr, val)
	api.poke(addr + 0, bit.rshift(bit.band(val, 0x00FF), 0))
	api.poke(addr + 1, bit.rshift(bit.band(val, 0xFF00), 8))
end

function api.poke4(addr, val)
	val = val * 0x10000
	api.poke(addr + 0, bit.rshift(bit.band(val, 0x000000FF), 0))
	api.poke(addr + 1, bit.rshift(bit.band(val, 0x0000FF00), 8))
	api.poke(addr + 2, bit.rshift(bit.band(val, 0x00FF0000), 16))
	api.poke(addr + 3, bit.rshift(bit.band(val, 0xFF000000), 24))
end

function api.memcpy(dest_addr, source_addr, len)
	if len < 1 or dest_addr == source_addr then
		return
	end

	-- only for range 0x6000 + 0x8000
	if source_addr < 0x6000 or dest_addr < 0x6000 then
		return
	end
	if source_addr + len > 0x8000 or dest_addr + len > 0x8000 then
		return
	end
	love.graphics.setCanvas()
	local img = pico8.screen:newImageData()
	love.graphics.setCanvas(pico8.screen)
	for i = 0, len - 1 do
		local x = flr(source_addr - 0x6000 + i) % 64 * 2
		local y = flr((source_addr - 0x6000 + i) / 64)
		--TODO: why are colors broken?
		local c = api.ceil(img:getPixel(x, y) / 16)
		local d = api.ceil(img:getPixel(x + 1, y) / 16)
		if c ~= 0 then
			c = c - 1
		end
		if d ~= 0 then
			d = d - 1
		end

		local dx = flr(dest_addr - 0x6000 + i) % 64 * 2
		local dy = flr((dest_addr - 0x6000 + i) / 64)
		api.pset(dx, dy, c)
		api.pset(dx + 1, dy, d)
	end
end

function api.memset(dest_addr, val, len)
	if len < 1 then
		return
	end

	for i = dest_addr, dest_addr + len - 1 do
		api.poke(i, val)
	end
end

function api.reload(dest_addr, source_addr, len, filepath) -- luacheck: no unused
	-- FIXME: doesn't handle ranges, we should keep a "cart rom"
	-- FIXME: doesn't handle filepaths
	_load(cartname)
end

function api.cstore(dest_addr, source_addr, len) -- luacheck: no unused
	-- TODO: implement this
end

function api.rnd(x)
	local t = type(x)
	assert(t == "number" or t == "table", "rnd() accepts a number or a table")
	if t == "number" then
		return love.math.random() * (x or 1)
	elseif t == "table" then
		local len = #x
		if len > 0
		then
			local index = 0
			while(index == 0)
			do
				index = math.ceil(love.math.random() * len)
			end
			return x[index]
		end
		return nil
	end
end

function api.srand(seed)
	if seed == 0 then
		seed = 1
	end
	return love.math.setRandomSeed(flr(seed * 0x8000))
end

api.flr = math.floor
api.ceil = math.ceil

function api.sgn(x)
	return x < 0 and -1 or 1
end

api.abs = math.abs

function api.min(a, b)
	a = tonumber(a) or 0
	b = tonumber(b) or 0
	return a < b and a or b
end

function api.max(a, b)
	a = tonumber(a) or 0
	b = tonumber(b) or 0
	return a > b and a or b
end

function api.mid(x, y, z)
	x = tonumber(x) or 0
	y = tonumber(y) or 0
	z = tonumber(z) or 0
	if x > y then
		x, y = y, x
	end
	return api.max(x, api.min(y, z))
end

function api.cos(x)
	return math.cos((x or 0) * math.pi * 2)
end

function api.sin(x)
	return -math.sin((x or 0) * math.pi * 2)
end

api.sqrt = math.sqrt

function api.atan2(x, y)
	return (0.75 + math.atan2(x, y) / (math.pi * 2)) % 1.0
end

local bit = require("bit")

api.band = bit.band
api.bor = bit.bor
api.bxor = bit.bxor
api.bnot = bit.bnot
api.shl = bit.lshift
api.shr = bit.rshift

function api.load(filename)
	_load(filename)
end

function api.save()
	-- TODO: implement this
end

function api.run()
	love.graphics.setCanvas(pico8.screen)
	love.graphics.setShader(pico8.draw_shader)
	restore_clip()
	love.graphics.origin()

	api.clip()
	pico8.cart = new_sandbox()

	pico8.can_pause = true
	pico8.can_shutdown = false

	for addr = 0x4300, 0x5e00 - 1 do
		pico8.usermemory[addr - 0x4300] = 0
	end

	for i = 0, 63 do
		pico8.cartdata[i] = 0
	end

	local ok, f, e = pcall(load, loaded_code, cartname)
	if not ok or f == nil then
		log("=======8<========")
		log(loaded_code)
		log("=======>8========")
		error("Error loading lua: " .. tostring(e))
	else
		setfenv(f, pico8.cart)
		love.graphics.setShader(pico8.draw_shader)
		love.graphics.setCanvas(pico8.screen)
		love.graphics.origin()
		restore_clip()
		ok, e = pcall(f)
		if not ok then
			error("Error running lua: " .. tostring(e))
		else
			log("lua completed")
		end
	end

	if pico8.cart._init then
		pico8.cart._init()
	end
	if pico8.cart._update60 then
		setfps(60)
	else
		setfps(30)
	end
end

function api.stop()
	-- TODO: implement this
end

function api.reboot()
	_load("nocart.p8")
	api.run()
end

function api.shutdown()
	if pico8.can_shutdown then
		love.event.quit()
	end
end

api.exit = api.shutdown

function api.info()
	-- TODO: implement this
end

function api.export()
	-- TODO: implement this
end

function api.import()
	-- TODO: implement this
end

function api.help()
	api.print("")
	api.color(12)
	api.print("commands")
	api.print("")
	api.color(6)
	api.print("load <filename>  save <filename>")
	api.print("run              resume")
	api.print("shutdown         reboot")
	api.print("install_demos    dir")
	api.print("cd <dirname>     mkdir <dirname>")
	api.print("cd ..   go up a directory")
	api.print("")
	api.print("alt+enter to toggle fullscreen")
	api.print("alt+f4 or command+q to fastquit")
	api.print("")
	api.color(12)
	api.print("see readme.md for more info")
	api.print("or visit: github.com/picolove")
	api.print("")
end

function api.time()
	return host_time
end
api.t = api.time

function api.login()
	return nil
end

function api.logout()
	return nil
end

function api.bbsreq()
	return nil
end

function api.scoresub()
	return nil, 0
end

function api.extcmd(_)
	-- TODO: Implement this?
end

function api.radio()
	return nil, 0
end

function api.btn(i, p)
	if type(i) == "number" then
		p = p or 0
		if pico8.keymap[p] and pico8.keymap[p][i] then
			return pico8.keypressed[p][i] ~= nil
		end
		return false
	else
		-- return bitfield of buttons
		local bitfield = 0
		for j = 0, 7 do
			if pico8.keypressed[0][j] then
				bitfield = bitfield + bit.lshift(1, j)
			end
		end
		for j = 0, 7 do
			if pico8.keypressed[1][j] then
				bitfield = bitfield + bit.lshift(1, j + 8)
			end
		end
		return bitfield
	end
end

function api.btnp(i, p)
	if type(i) == "number" then
		p = p or 0
		if pico8.keymap[p] and pico8.keymap[p][i] then
			local v = pico8.keypressed[p][i]
			if v and (v == 0 or (v >= 12 and v % 4 == 0)) then
				return true
			end
		end
		return false
	else
		-- return bitfield of buttons
		local bitfield = 0
		for j = 0, 7 do
			if pico8.keypressed[0][j] then
				bitfield = bitfield + bit.lshift(1, j)
			end
		end
		for j = 0, 7 do
			if pico8.keypressed[1][j] then
				bitfield = bitfield + bit.lshift(1, j + 8)
			end
		end
		return bitfield
	end
end

function api.cartdata(id) -- luacheck: no unused
	-- TODO: handle global cartdata properly
	-- TODO: handle cartdata() from console should not work
	pico8.can_cartdata = true
	-- if cartdata exists
	-- return true
	return false
end

function api.dget(index)
	-- TODO: handle global cartdata properly
	-- TODO: handle missing cartdata(id) call
	index = flr(index)
	if not pico8.can_cartdata then
		api.print("** dget called before cartdata()", nil, nil, 6)
		return ""
	end
	if index < 0 or index > 63 then
		warning("cartdata index out of range")
		return 0
	end
	return pico8.cartdata[index]
end

function api.dset(index, value)
	-- TODO: handle global cartdata properly
	-- TODO: handle missing cartdata(id) call
	index = flr(index)
	if not pico8.can_cartdata then
		api.print("** dget called before cartdata()", nil, nil, 6)
		return ""
	end
	if value >= 0x8000 or value < -0x8000 then
		value = -0x8000
	end
	if index < 0 or index > 63 then
		warning("cartdata index out of range")
		return
	end
	pico8.cartdata[index] = value
end

local tfield = {[0] = "year", "month", "day", "hour", "min", "sec"}
function api.stat(x)
	-- TODO: implement this
	if x == 4 then
		return pico8.clipboard
	elseif x == 7 then
		return pico8.fps -- current fps
	elseif x == 8 then
		return pico8.fps -- target fps
	elseif x == 9 then
		return love.timer.getFPS()
	elseif x == 32 then
		return getmousex()
	elseif x == 33 then
		return getmousey()
	elseif x == 34 then
		local btns = 0
		for i = 0, 2 do
			if love.mouse.isDown(i + 1) then
				btns = bit.bor(btns, bit.lshift(1, i))
			end
		end
		return btns
	elseif x == 36 then
		return pico8.mwheel
	elseif (x >= 80 and x <= 85) or (x >= 90 and x <= 95) then
		local tinfo
		if x < 90 then
			tinfo = os.date("!*t")
		else
			tinfo = os.date("*t")
		end
		return tinfo[tfield[x % 10]]
	elseif x == 100 then
		return nil -- TODO: breadcrumb not supported
	elseif x == 101 then
		return nil -- TODO: bbs id not supported
	elseif x == 102 then
		return 0 -- TODO: bbs site not supported
	elseif x == 103 then
		return 0
	elseif x == 104 then
		return false
	end
	return 0
end

function api.holdframe()
	-- TODO: Implement this
end

function api.menuitem()
end

api.sub = string.sub
api.pairs = pairs
api.type = type
api.assert = assert
api.setmetatable = setmetatable
api.getmetatable = getmetatable
api.cocreate = coroutine.create
api.coresume = coroutine.resume
api.yield = coroutine.yield
api.costatus = coroutine.status
api.trace = debug.traceback
api.rawset = rawset
api.rawget = rawget
function api.rawlen(table) -- luacheck: no unused
	-- TODO: implement this
end
api.rawequal = rawequal
api.next = next

local function arraylen(t)
	local len = 0
	for i, _ in pairs(t) do
		if type(i) == "number" then
			len = i
		end
	end
	return len
end

function api.all(a)
	if a == nil then
		return function()
		end
	end

	local i = 0
	local n = arraylen(a)
	return function()
		i = i + 1
		while (a[i] == nil and i <= n) do
			i = i + 1
		end
		return a[i]
	end
end

function api.foreach(a, f)
	if not a then
		warning("foreach got a nil value")
		return
	end
	for _, v in ipairs(a) do
		f(v)
	end
end

-- legacy function
function api.count(a)
	return #a
end

function api.add(a, v)
	if a == nil then
		warning("add to nil")
		return
	end
	table.insert(a, v)
	return v
end

function api.del(a, dv)
	if a == nil then
		warning("del from nil")
		return
	end
	for i, v in ipairs(a) do
		if v == dv then
			table.remove(a, i)
			return dv
		end
	end
end

function api.serial(channel, address, length) -- luacheck: no unused
	-- TODO: implement this
end

return api
