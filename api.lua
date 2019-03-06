local api = {}

function api.flip()
	flip_screen()
	love.timer.sleep(frametime)
end

function api.clip(x,y,w,h)
	if type(x) == 'number' then
		love.graphics.setScissor(x,y,w,h)
		pico8.clip = {x,y,w,h}
	else
		love.graphics.setScissor(0,0,__pico_resolution[1],__pico_resolution[2])
		pico8.clip = nil
	end
end

function api.cls()
	love.graphics.clear(0,0,0,255)
	pico8.cursor = {0,0}
end

function api.folder()
	love.system.openURL('file://'..love.filesystem.getWorkingDirectory())
end

-- TODO: move interactive implementatn into nocart
-- TODO: should return table of strings
function api.ls()
	local files = love.filesystem.getDirectoryItems(currentDirectory)
	api.print('directory: '..currentDirectory, nil, nil, 12)
	local output = {}
	for _, file in ipairs(files) do
		if love.filesystem.isDirectory(currentDirectory..file) then
			output[#output+1] = {name=file:lower(), color=14}
		end
	end
	for _, file in ipairs(files) do
		if love.filesystem.isDirectory(currentDirectory..file) then
		elseif file:sub(-3) == '.p8' or file:sub(-4) == '.png' then
			output[#output+1] = {name=file:lower(), color=6}
		else
			output[#output+1] = {name=file:lower(), color=5}
		end
	end
	local count = 0
	love.keyboard.setTextInput(false)
	for i, item in ipairs(output) do
		api.color(item.color)
		for j=1,#item.name,32 do
			api.print(item.name:sub(j,j+32))
			flip_screen()
			count = count + 1
			if count == 20 then
				api.print('--more--', nil, nil, 12)
				flip_screen()
				local y = _getcursory() - 6
				api.cursor(0, y)
				api.rectfill(0, y, 127, y+6, 0)
				api.color(item.color)
				while true do
					local e = love.event.wait()
					if e == 'keypressed' then
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
	local output = ''
	local newDirectory = currentDirectory..name..'/'

	-- filter /TEXT/../ -> /
	local count = 1
	while count > 0 do
		newDirectory, count = newDirectory:gsub('/[^/]*/%.%./','/')
	end

	-- filter /TEXT/..$ -> /
	count = 1
	while count > 0 do
		newDirectory, count = newDirectory:gsub('/[^/]*/%.%.$','/')
	end

	local failed = newDirectory:find('%.%.') ~= nil

	if #name == 0 then
		output = 'directory: '..currentDirectory
	elseif failed then
		if newDirectory == '/../' then
			output = 'cd: failed'
		else
			output = 'directory not found'
		end
	elseif love.filesystem.exists(newDirectory) then
		currentDirectory = newDirectory
		output = currentDirectory
	else
		failed = true
		output = 'directory not found'
	end

	if not failed then
		api.color(12)
		for i=1,#output,32 do
			api.print(output:sub(i,i+32))
		end
	else
		api.color(7)
		api.print(output)
	end
end

function api.mkdir(name)
	if name == nil then
		api.color(6)
		api.print('mkdir [name]')
	else
		love.filesystem.createDirectory(currentDirectory..name)
	end
end

function api.pset(x,y,c)
	if not c then return end
	api.color(c)
	love.graphics.point(api.flr(x),api.flr(y),c*16,0,0,255)
end

function api.pget(x,y)
	if x >= 0 and x < __pico_resolution[1] and y >= 0 and y < __pico_resolution[2] then
		local __screen_img = pico8.screen:newImageData()
		local r,g,b,a = __screen_img:getPixel(api.flr(x),api.flr(y))
		return api.flr(r/17.0)
	else
		warning(string.format('pget out of screen %d,%d',x,y))
		return 0
	end
end

function api.print(str,x,y,col)
	if col then api.color(col) end
	local canscroll = y==nil
	if y==nil then
		y = pico8.cursor[2]
		pico8.cursor[2] = pico8.cursor[2] + 6
	end
	if x==nil then
		x = pico8.cursor[1]
	end
	if canscroll and y > 121 then
		local c = col or pico8.color
		scroll(6)
		y = 120
		api.rectfill(0,y,127,y+6,0)
		api.color(c)
		api.cursor(0, y+6)
	end
	love.graphics.setShader(__text_shader)
	love.graphics.print(str,api.flr(x),api.flr(y))
end

function api.cursor(x,y)
	pico8.cursor = {x,y}
end

function api.spr(n,x,y,w,h,flip_x,flip_y)
	n = api.flr(n)
	love.graphics.setShader(__sprite_shader)
	__sprite_shader:send('transparent',shdr_unpack(pico8.pal_transparent))
	n = api.flr(n)
	w = w or 1
	h = h or 1
	local q
	if w == 1 and h == 1 then
		q = __pico_quads[n]
		if not q then
			log('warning: sprite '..n..' is missing')
			return
		end
	else
		local id = string.format('%d-%d-%d',n,w,h)
		if __pico_quads[id] then
			q = __pico_quads[id]
		else
			q = love.graphics.newQuad(api.flr(n%16)*8,api.flr(n/16)*8,8*w,8*h,128,128)
			__pico_quads[id] = q
		end
	end
	if not q then
		log('missing quad',n)
	end
	love.graphics.draw(__pico_spritesheet,q,
		api.flr(x)+(w*8*(flip_x and 1 or 0)),
		api.flr(y)+(h*8*(flip_y and 1 or 0)),
		0,
		flip_x and -1 or 1,
		flip_y and -1 or 1)
	love.graphics.setShader(__draw_shader)
end

function api.sspr(sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y)
-- Stretch rectangle from sprite sheet (sx, sy, sw, sh) // given in pixels
-- and draw in rectangle (dx, dy, dw, dh)
-- Colour 0 drawn as transparent by default (see palt())
-- dw, dh defaults to sw, sh
-- flip_x=true to flip horizontally
-- flip_y=true to flip vertically
	dw = dw or sw
	dh = dh or sh
	-- FIXME: cache this quad
	local q = love.graphics.newQuad(sx,sy,sw,sh,__pico_spritesheet:getDimensions())
	love.graphics.setShader(__sprite_shader)
	__sprite_shader:send('transparent',shdr_unpack(pico8.pal_transparent))
	love.graphics.draw(__pico_spritesheet,q,
		api.flr(dx)+(dw*(flip_x and 1 or 0)),
		api.flr(dy)+(dh*(flip_y and 1 or 0)),
		0,
		flip_x and -1 or 1 * (dw/sw),
		flip_y and -1 or 1 * (dh/sh))
	love.graphics.setShader(__draw_shader)
end

function api.rect(x0,y0,x1,y1,col)
	col = col or pico8.color
	api.color(col)
	love.graphics.rectangle('line',api.flr(x0)+1,api.flr(y0)+1,api.flr(x1-x0),api.flr(y1-y0))
end

function api.rectfill(x0,y0,x1,y1,col)
	col = col or pico8.color
	api.color(col)
	local w = (x1-x0)+1
	local h = (y1-y0)+1
	if w < 0 then
		w = -w
		x0 = x0-w
	end
	if h < 0 then
		h = -h
		y0 = y0-h
	end
	love.graphics.rectangle('fill',api.flr(x0),api.flr(y0),w,h)
end

function api.circ(ox,oy,r,col)
	col = col or pico8.color
	api.color(col)
	ox = api.flr(ox)
	oy = api.flr(oy)
	r = api.flr(r)
	local points = {}
	local x = r
	local y = 0
	local decisionOver2 = 1 - x

	while y <= x do
		table.insert(points,{ox+x,oy+y})
		table.insert(points,{ox+y,oy+x})
		table.insert(points,{ox-x,oy+y})
		table.insert(points,{ox-y,oy+x})

		table.insert(points,{ox-x,oy-y})
		table.insert(points,{ox-y,oy-x})
		table.insert(points,{ox+x,oy-y})
		table.insert(points,{ox+y,oy-x})
		y = y + 1
		if decisionOver2 < 0 then
			decisionOver2 = decisionOver2 + 2 * y + 1
		else
			x = x - 1
			decisionOver2 = decisionOver2 + 2 * (y-x) + 1
		end
	end
	if #points > 0 then
		love.graphics.points(points)
	end
end

function api.circfill(cx,cy,r,col)
	col = col or pico8.color
	api.color(col)
	cx = api.flr(cx)
	cy = api.flr(cy)
	r = api.flr(r)
	local x = r
	local y = 0
	local err = 1 - r

	local points = {}

	while y <= x do
		_plot4points(points,cx,cy,x,y)
		if err < 0 then
			err = err + 2 * y + 3
		else
			if x ~= y then
				_plot4points(points,cx,cy,y,x)
			end
			x = x - 1
			err = err + 2 * (y - x) + 3
		end
		y = y + 1
	end
	if #points > 0 then
		love.graphics.points(points)
	end
end

function api.line(x0,y0,x1,y1,col)
	col = col or pico8.color
	api.color(col)

	if x0 ~= x0 or y0 ~= y0 or x1 ~= x1 or y1 ~= y1 then
		warning('line has NaN value')
		return
	end

	x0 = api.flr(x0)
	y0 = api.flr(y0)
	x1 = api.flr(x1)
	y1 = api.flr(y1)


	local dx = x1 - x0
	local dy = y1 - y0
	local stepx, stepy

	local points = {{x0,y0}}

	if dx == 0 then
		-- simple case draw a vertical line
		points = {}
		if y0 > y1 then y0,y1 = y1,y0 end
		for y=y0,y1 do
			table.insert(points,{x0,y})
		end
	elseif dy == 0 then
		-- simple case draw a horizontal line
		points = {}
		if x0 > x1 then x0,x1 = x1,x0 end
		for x=x0,x1 do
			table.insert(points,{x,y0})
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
				table.insert(points,{api.flr(x0),api.flr(y0)})
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
				table.insert(points,{api.flr(x0),api.flr(y0)})
			end
		end
	end
	love.graphics.points(points)
end

local __palette_modified = true

function api.pal(c0,c1,p)
	if type(c0) ~= 'number' then
		if __palette_modified == false then return end
		for i=1,16 do
			pico8.draw_palette[i] = i
			pico8.display_palette[i] = pico8.palette[i]
		end
		__draw_shader:send('palette',shdr_unpack(pico8.draw_palette))
		__sprite_shader:send('palette',shdr_unpack(pico8.draw_palette))
		__text_shader:send('palette',shdr_unpack(pico8.draw_palette))
		__display_shader:send('palette',shdr_unpack(pico8.display_palette))
		__palette_modified = false
		-- According to PICO-8 manual:
		-- pal() to reset to system defaults (including transparency values)
		api.palt()
	elseif p == 1 and c1 ~= nil then
		c0 = api.flr(c0)%16
		c1 = api.flr(c1)%16
		c1 = c1+1
		c0 = c0+1
		pico8.display_palette[c0] = pico8.palette[c1]
		__display_shader:send('palette',shdr_unpack(pico8.display_palette))
		__palette_modified = true
	elseif c1 ~= nil then
		c0 = api.flr(c0)%16
		c1 = api.flr(c1)%16
		c1 = c1+1
		c0 = c0+1
		pico8.draw_palette[c0] = c1
		__draw_shader:send('palette',shdr_unpack(pico8.draw_palette))
		__sprite_shader:send('palette',shdr_unpack(pico8.draw_palette))
		__text_shader:send('palette',shdr_unpack(pico8.draw_palette))
		__palette_modified = true
	end
end

function api.palt(c,t)
	if type(c) ~= 'number' then
		for i=1,16 do
			pico8.pal_transparent[i] = i == 1 and 0 or 1
		end
	else
		c = api.flr(c)%16
		if t == false then
			pico8.pal_transparent[c+1] = 1
		elseif t == true then
			pico8.pal_transparent[c+1] = 0
		end
	end
	__sprite_shader:send('transparent',shdr_unpack(pico8.pal_transparent))
end

function api.map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
	cel_x = cel_x or 0
	cel_y = cel_y or 0
	love.graphics.setShader(__sprite_shader)
	love.graphics.setColor(255,255,255,255)
	cel_x = api.flr(cel_x)
	cel_y = api.flr(cel_y)
	sx = api.flr(sx)
	sy = api.flr(sy)
	cel_w = api.flr(cel_w)
	cel_h = api.flr(cel_h)
	for y=0,cel_h-1 do
		if cel_y+y < 64 and cel_y+y >= 0 then
			for x=0,cel_w-1 do
				if cel_x+x < 128 and cel_x+x >= 0 then
					local v = pico8.map[api.flr(cel_y+y)][api.flr(cel_x+x)]
					if v > 0 then
						if bitmask == nil or bitmask == 0 then
							love.graphics.draw(__pico_spritesheet,__pico_quads[v],sx+8*x,sy+8*y)
						else
							if api.band(pico8.spriteflags[v],bitmask) ~= 0 then
								love.graphics.draw(__pico_spritesheet,__pico_quads[v],sx+8*x,sy+8*y)
							else
							end
						end
					end
				end
			end
		end
	end
	love.graphics.setShader(__draw_shader)
end

function api.mget(x,y)
	if x == nil or y == nil then return 0 end
	if y > 63 or x > 127 or x < 0 or y < 0 then return 0 end
	return pico8.map[api.flr(y)][api.flr(x)]
end

function api.mset(x,y,v)
	if x >= 0 and x < 128 and y >= 0 and y < 64 then
		pico8.map[api.flr(y)][api.flr(x)] = v
	end
end

function api.fget(n,f)
	if n == nil then return nil end
	if f ~= nil then
		-- return just that bit as a boolean
		if not pico8.spriteflags[api.flr(n)] then
			warning(string.format('fget(%d,%d)',n,f))
			return 0
		end
		return api.band(pico8.spriteflags[api.flr(n)],api.shl(1,api.flr(f))) ~= 0
	end
	return pico8.spriteflags[api.flr(n)]
end

return api
