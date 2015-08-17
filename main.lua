--[[
Implementation of PICO8 API for LOVE

What it is:

 * An implementation of pico-8's api in love

Why:

 * For a fun challenge!
 * Allow standalone publishing of pico-8 games on other platforms
  * should work on mobile devices
 * Configurable controls
 * No arbitrary cpu or memory limitations
 * No arbitrary code size limitations
 * Betting debugging tools available
 * Open source

What it isn't:

 * A replacement for Pico-8
 * A perfect replica
 * No dev tools, no image editor, map editor, sfx editor, music editor
 * No modifying or saving carts

Not Yet Implemented:

 * Palette mapping
 * Memory modification/reading
 * Sound/music
 * if (foo) bar=1 shorthand
 * Resizing window

Not working:

 * Camera stuff is broken with tilemap

Differences:

 * Uses floating point numbers not fixed point
 * sqrt doesn't freeze
 * Uses luajit not lua 5.2

Extra features:

 * log(...) function prints to console for debugging
 * assert(expr,message) if expr is not true then errors with message
 * error(message) bluescreens with an error message

]]

local scale = 4
local xpadding = 8.5
local ypadding = 3.5
local __accum = 0

local __pico_pal_draw = {
}

local __pico_pal_display = {
}

local __pico_pal_transparent = {
	[0] = false
}

local __pico_palette = {
	[0] = {0,0,0,255},
	{29,43,83,255},
	{126,37,83,255},
	{0,135,81,255},
	{171,82,54,255},
	{95,87,79,255},
	{194,195,199,255},
	{255,241,232,255},
	{255,0,77,255},
	{255,163,0,255},
	{255,255,39,255},
	{0,231,86,255},
	{41,173,255,255},
	{131,118,156,255},
	{255,119,168,255},
	{255,204,170,255}
}



local __pico_camera_x = 0
local __pico_camera_y = 0

local host_time = 0

local retro_mode = false

function love.load(argv)
	love_args = argv
	if love.system.getOS() == "Android" then
		--love.window.setMode(128*scale+xpadding*scale*2,128*scale+ypadding*scale*2)
		love.resize(love.window.getDimensions())
	else
		love.window.setMode(128*scale+xpadding*scale*2,128*scale+ypadding*scale*2)
	end
	love.graphics.setDefaultFilter('nearest','nearest')
	__screen = love.graphics.newCanvas(128,128)
	__screen:clear(0,0,0,255)
	__screen:setFilter('linear','nearest')

	local font = love.graphics.newImageFont("font.png","abcdefghijklmnopqrstuvwxyz\"'`-_/1234567890!?[](){}.,;:<>+ ")
	love.graphics.setFont(font)
	font:setFilter('nearest','nearest')

	love.mouse.setVisible(false)
	love.window.setTitle("pico-8-emu")
	love.graphics.setLineStyle('rough')
	love.graphics.setPointStyle('rough')
	love.graphics.setPointSize(1)
	love.graphics.setLineWidth(1)

	love.graphics.origin()
	love.graphics.setCanvas(__screen)
	love.graphics.setScissor(0,0,128,128)

	__draw_palette = love.graphics.newCanvas(16,1)
	__display_palette = love.graphics.newCanvas(16,1)

	__draw_palette:setFilter('nearest','nearest')
	__display_palette:setFilter('nearest','nearest')

	__draw_shader = love.graphics.newShader([[
extern Image palette;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	int index = int(color.r*16.0);
	// lookup the colour in the palette by index
	return Texel(palette,vec2(float(index)/16.0,0));
}]])
	__draw_shader:send('palette',__draw_palette)

	__sprite_shader = love.graphics.newShader([[
extern Image palette;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	int index = int(Texel(texture, texture_coords).r*16.0);
	if(index == 0) {
		return vec4(0.0,0.0,0.0,0.0);
	}
	// lookup the colour in the palette by index
	return Texel(palette,vec2(float(index)/16.0,0));
}]])
	__sprite_shader:send('palette',__draw_palette)

	__text_shader = love.graphics.newShader([[
extern Image palette;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 texcolor = Texel(texture, texture_coords);
	if(texcolor.a == 0) {
		return vec4(0.0,0.0,0.0,0.0);
	}
	int index = int(color.r*16.0);
	// lookup the colour in the palette by index
	return Texel(palette,vec2(float(index)/16.0,0));
}]])
	__text_shader:send('palette',__draw_palette)

	__display_shader = love.graphics.newShader([[
extern Image palette;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	int index = int(Texel(texture, texture_coords).r*16.0);
	// lookup the colour in the palette by index
	return Texel(palette,vec2(float(index)/16.0,0));
}]])
	__display_shader:send('palette',__display_palette)

	pal()

	-- load the cart
	clip()
	camera()
	pal()
	color(0)
	--load(argv[2])
	load(argv[2] or 'picopout.p8')
	run()
end

function load_p8(filename)
	log("Opening",filename)
	local f = love.filesystem.newFile(filename,'r')
	if not f then
		error("Unable to open",filename)
	end
	local data,size = f:read()
	f:close()

	if not data then
		error("invalid cart")
	end

	--local start = data:find("pico-8 cartridge // http://www.pico-8.com\nversion ")
	local header = "pico-8 cartridge // http://www.pico-8.com\nversion "
	local start = data:find("pico%-8 cartridge // http://www.pico%-8.com\nversion ")
	if start == nil then
		error("invalid cart")
	end
	local next_line = data:find("\n",start+#header)
	local version_str = data:sub(start+#header,next_line-1)
	local version = tonumber(version_str)
	log("version",version)
	-- extract the lua
	local lua_start = data:find("__lua__") + 8
	local lua_end = data:find("__gfx__") - 1

	local lua = data:sub(lua_start,lua_end)

	-- patch the lua
	lua = lua:gsub("!=","~=")
	-- rewrite assignment operators
	lua = lua:gsub("(%S+)%s*([%+-%*/])=","%1 = %1 %2 ")
	-- rewrite shorthand if statements eg. if (not b) i=1 j=2
	--lua = lua:gsub("if%s*%(([^\n]+)%)%s+([^\n]+)\n",function(a,b)
	--	local c = b:sub(1,5)
	--	log("'"..c.."'")
	--	if c == "then " or c == "then" or c == "then\t" then
	--		return "if "..a.." "..b.."\n"
	--	else
	--		return "if "..a.." then "..b.." end\n"
	--	end
	--end)

	local cart_G = {
		-- extra functions provided by picolove
		assert=assert,
		error=error,
		log=log,
		-- pico8 api functions go here
		clip=clip,
		pget=pget,
		pset=pset,
		sget=sget,
		sset=sset,
		fget=fget,
		fset=fset,
		flip=flip,
		print=print,
		cursor=cursor,
		color=color,
		cls=cls,
		camera=camera,
		circ=circ,
		circfill=circfill,
		line=line,
		load=load,
		rect=rect,
		rectfill=rectfill,
		run=run,
		reload=reload,
		pal=pal,
		palt=palt,
		spr=spr,
		sspr=sspr,
		add=add,
		del=del,
		foreach=foreach,
		count=count,
		all=all,
		btn=btn,
		btnp=btnp,
		sfx=sfx,
		music=music,
		mget=mget,
		mset=mset,
		map=map,
		memcpy=memcpy,
		peek=peek,
		poke=poke,
		max=max,
		min=min,
		mid=mid,
		flr=flr,
		cos=cos,
		sin=sin,
		atan2=atan2,
		sqrt=sqrt,
		abs=abs,
		rnd=rnd,
		srand=srand,
		sgn=sgn,
		band=band,
		bor=bor,
		bxor=bxor,
		bnot=bnot,
		shl=shl,
		shr=shr,
		sub=sub,
		-- deprecated pico-8 function aliases
		mapdraw=map
	}

	local ok,f,e = pcall(loadstring,lua)
	if not ok or f==nil then
		error("Error loading lua: "..tostring(e))
	else
		local result
		setfenv(f,cart_G)
		ok,result = pcall(f)
		if not ok then
			error("Error running lua: "..tostring(result))
		else
			log("Ran lua")
		end
	end

	-- load the sprites into an imagedata
	-- generate a quad for each sprite index
	local gfx_start = data:find("__gfx__") + 8
	local gfx_end = data:find("__gff__") - 1
	local gfxdata = data:sub(gfx_start,gfx_end)

	local row = 0
	local tile_row = 32
	local tile_col = 0
	local col = 0
	local sprite = 0
	local tiles = 0
	local shared = 0

	__pico_map = {}
	__pico_quads = {}
	for y=0,63 do
		__pico_map[y] = {}
		for x=0,127 do
			__pico_map[y][x] = 0
		end
	end
	__pico_spritesheet_data = love.image.newImageData(128,128)

	local next_line = 1
	while next_line do
		local end_of_line = gfxdata:find("\n",next_line)
		if end_of_line == nil then break end
		end_of_line = end_of_line - 1
		local line = gfxdata:sub(next_line,end_of_line)
		for i=1,#line do
			local v = line:sub(i,i)
			v = tonumber(v,16)
			__pico_spritesheet_data:setPixel(col,row,v*16,v*16,v*16,255)

			col = col + 1
			if col == 128 then
				col = 0
				row = row + 1
			end
		end
		next_line = gfxdata:find("\n",end_of_line)+1
	end

	local tx,ty = 0,32
	for sy=64,127 do
		for sx=0,127,2 do
			-- get the two pixel values and merge them
			local lo = flr(__pico_spritesheet_data:getPixel(sx,sy)/16)
			local hi = flr(__pico_spritesheet_data:getPixel(sx+1,sy)/16)
			local v = bor(shl(hi,4),lo)
			__pico_map[ty][tx] = v
			shared = shared + 1
			tx = tx + 1
			if tx == 128 then
				tx = 0
				ty = ty + 1
			end
		end
	end

	for y=0,15 do
		for x=0,15 do
			__pico_quads[sprite] = love.graphics.newQuad(8*x,8*y,8,8,128,128)
			sprite = sprite + 1
		end
	end

	assert(shared == 128 * 32,shared)
	assert(sprite == 256,sprite)

	__pico_spritesheet = love.graphics.newImage(__pico_spritesheet_data)
	__pico_spritesheet_data:encode('spritesheet.png')

	-- load the sprite flags
	__pico_spriteflags = {}

	local gff_start = data:find("__gff__") + 8
	local gff_end = data:find("__map__") - 1
	local gffdata = data:sub(gff_start,gff_end)

	local sprite = 0

	local next_line = 1
	while next_line do
		local end_of_line = gffdata:find("\n",next_line)
		if end_of_line == nil then break end
		end_of_line = end_of_line - 1
		local line = gffdata:sub(next_line,end_of_line)
		if version <= 2 then
			for i=1,#line do
				local v = line:sub(i)
				v = tonumber(v,16)
				__pico_spriteflags[sprite] = v
				sprite = sprite + 1
			end
		else
			for i=1,#line,2 do
				local v = line:sub(i,i+1)
				v = tonumber(v,16)
				__pico_spriteflags[sprite] = v
				sprite = sprite + 1
			end
		end
		next_line = gfxdata:find("\n",end_of_line)+1
	end

	assert(sprite == 256,"wrong number of spriteflags:"..sprite)

	-- convert the tile data to a table

	local map_start = data:find("__map__") + 8
	local map_end = data:find("__sfx__") - 1
	local mapdata = data:sub(map_start,map_end)

	local row = 0
	local col = 0

	local next_line = 1
	while next_line do
		local end_of_line = mapdata:find("\n",next_line)
		if end_of_line == nil then
			log("reached end of map data")
			break
		end
		end_of_line = end_of_line - 1
		local line = mapdata:sub(next_line,end_of_line)
		for i=1,#line,2 do
			local v = line:sub(i,i+1)
			v = tonumber(v,16)
			if col == 0 then
			end
			__pico_map[row][col] = v
			col = col + 1
			tiles = tiles + 1
			if col == 128 then
				col = 0
				row = row + 1
			end
		end
		next_line = mapdata:find("\n",end_of_line)+1
	end
	assert(tiles + shared == 128 * 64,string.format("%d + %d != %d",tiles,shared,128*64))

	-- check all the data is there
	love.graphics.setScissor()
	mapimage = love.graphics.newCanvas(1024,512)
	mapimage:clear(0,0,0,255)
	love.graphics.setCanvas(mapimage)
	love.graphics.setShader(__display_shader)
	for y=0,63 do
		for x=0,127 do
			assert(__pico_map[y][x],string.format("missing map data: %d,%d",x,y))
			local n = mget(x,y)
			love.graphics.draw(__pico_spritesheet,__pico_quads[n],x*8,y*8)
		end
	end
	love.graphics.setShader()
	love.graphics.setCanvas()
	mapimage:getImageData():encode('map.png')

	log("finished loading cart",filename)

	return cart_G
end

function love.update(dt)
	host_time = host_time + dt
	if cart._update then cart._update() end
end

function love.resize(w,h)
	love.graphics.clear()
	-- adjust stuff to fit the screen
	if w > h then
		scale = h/(128+ypadding*2)
	else
		scale = w/(128+xpadding*2)
	end
end

function love.run()
	if love.math then
		love.math.setRandomSeed(os.time())
		for i=1,3 do love.math.random() end
	end

	if love.event then
		love.event.pump()
	end

	if love.load then love.load(arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	while true do
		-- Process events.
		if love.event then
			love.event.pump()
			for e,a,b,c,d in love.event.poll() do
				if e == "quit" then
					if not love.quit or not love.quit() then
						if love.audio then
							love.audio.stop()
						end
						return
					end
				end
				love.handlers[e](a,b,c,d)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then
			love.timer.step()
			dt = dt + love.timer.getDelta()
		end

		-- Call update and draw
		local render = false
		while dt > 1/30 do
			if love.update then love.update(1/30) end -- will pass 0 if love.timer is disabled
			dt = dt - 1/30
			render = true
		end

		if render and love.window and love.graphics and love.window.isCreated() then
			love.graphics.origin()
			if love.draw then love.draw() end
			love.graphics.present()
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end

function love.draw()
	love.graphics.setCanvas(__screen)
	love.graphics.setScissor(0,0,128,128)
	love.graphics.origin()
	love.graphics.translate(__pico_camera_x,__pico_camera_y)

	love.graphics.setShader(__draw_shader)
	__draw_shader:send('palette',__draw_palette)
	__text_shader:send('palette',__draw_palette)
	__sprite_shader:send('palette',__draw_palette)

	-- run the cart's draw function
	if cart._draw then cart._draw() end

	-- draw the contents of pico screen to our screen
	love.graphics.setShader(__display_shader)
	__display_shader:send('palette',__display_palette)
	love.graphics.setCanvas()
	love.graphics.origin()

	love.graphics.setColor(255,255,255,255)
	love.graphics.setScissor()

	local screen_w,screen_h = love.graphics.getDimensions()
	if screen_w > screen_h then
		love.graphics.draw(__screen,screen_w/2-64*scale,ypadding*scale,0,scale,scale)
	else
		love.graphics.draw(__screen,xpadding*scale,screen_h/2-64*scale,0,scale,scale)
	end

	-- get ready for next time
	love.graphics.setShader(__draw_shader)
	love.graphics.setCanvas(__screen)
	love.graphics.setScissor(0,0,128,128)
end

function love.keypressed(key)
	if key == 'r' and love.keyboard.isDown('lctrl') then
		reload()
	end
end

function music()
	-- STUB
end

function sfx()
	-- STUB
end

function clip(x,y,w,h)
	if x then
		love.graphics.setScissor(x,y,w,h)
	else
		love.graphics.setScissor(0,0,128,128)
	end
end

function pget(x,y)
	if x >= 0 and x < 128 and y >= 0 and y < 128 then
		return flr(__screen:getImageData():getPixel(flr(x),flr(y))[1]/16)
	else
		return nil
	end
end

function pset(x,y,c)
	if not c then return end
	color(c)
	love.graphics.point(x,y,c*16,0,0,255)
end

function sget(x,y)
	-- return the color from the spritesheet
	x = flr(x)
	y = flr(y)
	local r,g,b,a = __pico_spritesheet_data:getPixel(x,y)
	return flr(r/16)
end

function sset(x,y,c)
	x = flr(x)
	y = flr(y)
	__pico_spritesheet_data:setPixel(x,y,c*16,0,0,255)
end

function fget(n,f)
	if n == nil then return nil end
	if f ~= nil then
		-- return just that bit as a boolean
		return band(__pico_spriteflags[flr(n)],shl(1,flr(f))) ~= 0
	end
	return __pico_spriteflags[flr(n)]
end

assert(bit.band(0x01,bit.lshift(1,0)) ~= 0)
assert(bit.band(0x02,bit.lshift(1,1)) ~= 0)
assert(bit.band(0x04,bit.lshift(1,2)) ~= 0)

assert(bit.band(0x05,bit.lshift(1,2)) ~= 0)
assert(bit.band(0x05,bit.lshift(1,0)) ~= 0)
assert(bit.band(0x05,bit.lshift(1,3)) == 0)

function fset(n,f,v)
	if v == nil then
		v,f = f,nil
	end
	if f then
		__pico_spriteflags[n] = bor(__pico_spriteflags[n],shl(1,v))
	else
		__pico_spriteflags[n] = v
	end
end

function flip()
	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.setColor(255,255,255,255)
	love.graphics.setScissor()
	love.graphics.draw(__screen,xpadding,ypadding,0,scale,scale)
	love.graphics.present()

	love.graphics.setCanvas(__screen)
	love.graphics.setScissor(0,0,128,128)

	love.timer.sleep(1/30)
end

log = print
function print(str,x,y,col)
	if col then color(col) end
	love.graphics.setShader(__text_shader)
	love.graphics.print(str,flr(x),flr(y))
	love.graphics.setShader(__text_shader)
end

function cursor(x,y)
	__pico_cursor = {x,y}
end

function color(c)
	c = flr(c)
	assert(c >= 0 and c < 16,string.format("c is %s",c))
	__pico_color = c
	love.graphics.setColor(c*16,0,0,255)
end

function cls()
	__screen:clear(0,0,0,255)
end

__pico_camera_x = 0
__pico_camera_y = 0

function camera(x,y)
	if x ~= nil then
		__pico_camera_x = flr(x)
		__pico_camera_y = flr(y)
		love.graphics.origin()
		love.graphics.translate(-flr(x),-flr(y))
	else
		__pico_camera_x = 0
		__pico_camera_y = 0
		love.graphics.origin()
	end
end

function circ(x,y,r,col)
	col = col or __pico_color
	color(col)
	love.graphics.circle("line",x,y,r,32)
end

function circfill(ox,oy,r,col)
	col = col or __pico_color
	color(col)
	ox = flr(ox)
	oy = flr(oy)
	r = flr(r)
	love.graphics.circle("fill",ox,oy,r,32)
	--local r2 = r*r
	--for y=-r,r do
	--	for x=-r,r do
	--		if x*x+y*y <= r2 + r*0.8 then
	--			love.graphics.point(ox+x,oy+y)
	--		end
	--	end
	--end
end

local lineMesh = love.graphics.newMesh(128,nil,"points")

function line(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)

	x0 = flr(x0)
	y0 = flr(y0)
	x1 = flr(x1)
	y1 = flr(y1)

	local dx = x1 - x0
	local dy = y1 - y0
	local stepx, stepy

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

	local points = {{x0,y0}}
	--love.graphics.point(x0,y0)
	if dx > dy then
		local fraction = dy - bit.rshift(dx, 1)
		while x0 ~= x1 do
			if fraction >= 0 then
				y0 = y0 + stepy
				fraction = fraction - dx
			end
			x0 = x0 + stepx
			fraction = fraction + dy
			--love.graphics.point(flr(x0),flr(y0))
			table.insert(points,{flr(x0),flr(y0)})
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
			--love.graphics.point(flr(x0),flr(y0))
			table.insert(points,{flr(x0),flr(y0)})
		end
	end
	lineMesh:setVertices(points)
	lineMesh:setDrawRange(1,#points)
	love.graphics.draw(lineMesh)
end

function load(_cartname)
	cartname = _cartname
	cart = load_p8(cartname)
end

function rect(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)
	love.graphics.rectangle("line",flr(x0),flr(y0),flr(x1-x0)+1,flr(y1-y0)+1)
end

function rectfill(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)
	love.graphics.rectangle("fill",flr(x0),flr(y0),flr(x1-x0)+1,flr(y1-y0)+1)
end

function run()
	love.graphics.setCanvas(__screen)
	love.graphics.setShader(__draw_shader)
	love.graphics.setScissor(0,0,128,128)
	if cart._init then cart._init() end
end

function reload()
	love.graphics.setCanvas(__screen)
	love.graphics.setShader(__draw_shader)
	love.graphics.setScissor(0,0,128,128)
	load(cartname)
	run()
end

local __palette_modified = true

function pal(c0,c1,p)
	love.graphics.setShader()
	love.graphics.origin()
	if c0 == nil then
		if __palette_modified == false then return end
		for i=0,15 do
			__draw_palette:renderTo(function()
				love.graphics.setColor(i*16,0,0,255)
				love.graphics.point(i,0)
			end)
			__display_palette:renderTo(function()
				love.graphics.setColor(__pico_palette[i] or 0)
				love.graphics.point(i,0)
			end)
		end
		__draw_shader:send('palette',__draw_palette)
		__sprite_shader:send('palette',__draw_palette)
		__text_shader:send('palette',__draw_palette)
		__display_shader:send('palette',__display_palette)
		__palette_modified = false
	elseif p == 1 then
		__display_palette:renderTo(function()
			if __pico_palette[flr(c1)] then
				love.graphics.setColor(__pico_palette[flr(c1)])
			else
				love.graphics.setColor(0,0,0,255)
			end
			love.graphics.point(flr(c0),0)
		end)
		__display_shader:send('palette',__display_palette)
		__palette_modified = true
	else
		__draw_palette:renderTo(function()
			love.graphics.setColor(flr(c1)*16,0,0,255)
			love.graphics.point(flr(c0),0)
		end)
		__draw_shader:send('palette',__draw_palette)
		__sprite_shader:send('palette',__draw_palette)
		__text_shader:send('palette',__draw_palette)
		__palette_modified = true
	end
	love.graphics.translate(-__pico_camera_x,-__pico_camera_y)
	love.graphics.setShader(__draw_shader)
end

function palt(c,t)
	if c == nil then
		__pico_pal_transparent = { [0] = false }
	else
		if t == false then
			__pico_pal_transparent[c] = false
		else
			__pico_pal_transparent[c] = nil
		end
	end
end

function spr(n,x,y,w,h,flip_x,flip_y)
	love.graphics.setShader(__sprite_shader)
	love.graphics.setColor(255,255,255,255)
	love.graphics.draw(__pico_spritesheet,__pico_quads[flr(n)],flr(x),flr(y),0)
	love.graphics.setShader(__draw_shader)
end

function sspr(sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y)
	dw = dw or sw
	dh = dh or sh
	-- FIXME: cache this quad
	local q = love.graphics.newQuad(sx,sy,sw,sh,128,128)
	love.graphics.setShader(__sprite_shader)
	love.graphics.setColor(255,255,255,255)
	love.graphics.draw(__pico_spritesheet,q,flr(dx),flr(dy),0,dw/sw,dh/sh)
	love.graphics.setShader(__draw_shader)
end

function add(a,v)
	table.insert(a,v)
end

function del(a,dv)
	for i,v in ipairs(a) do
		if v==dv then
			table.remove(a,i)
		end
	end
end

function foreach(a,f)
	for i,v in ipairs(a) do
		f(v)
	end
end

function count(a)
	return #a
end

function all(a)
	local i = 0
	local n = table.getn(a)
	return function()
		i = i + 1
		if i <= n then return a[i] end
	end
end

local __pico_keypressed = {
	[0] = {},
	[1] = {}
}

local __keymap = {
	[0] = {
		[0] = 'left',
		[1] = 'right',
		[2] = 'up',
		[3] = 'down',
		[4] = 'z',
		[5] = 'x',
	},
	[1] = {
		[4] = 'escape',
	}
}

function btn(i,p)
	p = p or 0
	if __keymap[p][i] then
		return love.keyboard.isDown(__keymap[p][i])
	end
end



function btnp(i,p)
	p = p or 0
	if __keymap[p][i] then
		local id = love.keyboard.isDown(__keymap[p][i])
		if __pico_keypressed[p][i] and __pico_keypressed[p][i] > 0 then
			__pico_keypressed[p][i] = __pico_keypressed[p][i] - 1
			return false
		end
		if id then
			__pico_keypressed[p][i] = 12
			return true
		end
	end
end

function sfx(n,channel,offset)
end

function music(n,fade_len,channel_mask)
end

function mget(x,y)
	if x == nil or y == nil then return nil end
	if y > 63 or x > 127 or x < 0 or y < 0 then return nil end
	return __pico_map[flr(y)][flr(x)]
end

function mset(x,y,v)
	if x >= 0 and x < 128 and y >= 0 and y < 64 then
		__pico_map[flr(y)][flr(x)] = v
	end
end

function map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
	love.graphics.setShader(__sprite_shader)
	love.graphics.setColor(255,255,255,255)
	cel_x = flr(cel_x)
	cel_y = flr(cel_y)
	sx = flr(sx)
	sy = flr(sy)
	cel_w = flr(cel_w)
	cel_h = flr(cel_h)
	for y=cel_y,cel_y+cel_h-1 do
		if y < 64 and y >= 0 then
			for x=cel_x,cel_x+cel_w-1 do
				if x < 128 and x >= 0 then
					local v = __pico_map[y][x]
					if v > 0 then
						if bitmask == nil then
							love.graphics.draw(__pico_spritesheet,__pico_quads[v],sx+8*x,sy+8*y)
						else
							if band(__pico_spriteflags[v],bitmask) ~= 0 then
								love.graphics.draw(__pico_spritesheet,__pico_quads[v],sx+8*x,sy+8*y)
							else
							end
						end
					end
				end
			end
		end
	end
	love.graphics.setShader()
end

-- memory functions excluded

function memcpy(dest_addr,source_addr,len)
	-- only for range 0x6000+0x8000
	if source_addr >= 0x6000 and dest_addr >= 0x6000 then
		if source_addr + len >= 0x8000 then
			return
		end
		if dest_addr + len >= 0x8000 then
			return
		end
		local img = __screen:getImageData()
		for i=1,len do
			local x = flr(source_addr-0x6000+i)%128
			local y = flr((source_addr-0x6000+i)/64)
			local c = flr(img:getPixel(x,y)/16)

			local dx = flr(dest_addr-0x6000+i)%128
			local dy = flr((dest_addr-0x6000+i)/64)
			pset(dx,dy,c)
		end
	end
end

function peek(...)
end

function poke(...)
end

max = math.max
min = math.min
function mid(x,y,z)
	return x > y and x or y > z and z or y
end

assert(mid(1,5,6) == 5)
assert(mid(3,2,6) == 3)
assert(mid(3,9,6) == 6)

function __pico_angle(a)
	-- FIXME: why does this work?
	return (((a - math.pi) / (math.pi*2)) + 0.25) % 1.0
end

flr = math.floor
cos = function(x) return math.cos(x*(math.pi*2)) end
sin = function(x) return math.sin(-x*(math.pi*2)) end
atan2 = function(y,x) return __pico_angle(math.atan2(y,x)) end

sqrt = math.sqrt
abs = math.abs
rnd = function(x) return love.math.random()*x end
srand = love.math.randomseed
sgn = function(x)
	if x < 0 then
		return -1
	elseif x > 0 then
		return 1
	else
		return 0
	end
end

assert(sgn(-10) == -1)
assert(sgn(10) == 1)
assert(sgn(0) == 0)

local bit = require("bit")

band = bit.band
bor = bit.bor
bxor = bit.bxor
bnot = bit.bnot
shl = bit.lshift
shr = bit.rshift

sub = string.sub

love.graphics.point = function(x,y)
	love.graphics.rectangle('fill',x,y,1,1)
end
