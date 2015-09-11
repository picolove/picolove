require "strict"

local __pico_fps=30

local frametime = 1/__pico_fps

local cart = nil
local cartname = nil
local love_args = nil
local __screen
local __pico_clip
local __pico_color
local __pico_map
local __pico_quads
local __pico_spritesheet_data
local __pico_spritesheet
local __pico_spriteflags
local __draw_palette
local __draw_shader
local __sprite_shader
local __text_shader
local __display_palette
local __display_shader
local scale = 4
local xpadding = 8.5
local ypadding = 3.5
local __accum = 0

local __pico_pal_transparent = {
}

__pico_resolution = {128,128}

local lineMesh = love.graphics.newMesh(128,nil,"points")

local __pico_palette = {
	{0,0,0,255},
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

local video_frames = nil



local __pico_camera_x = 0
local __pico_camera_y = 0

local host_time = 0

local retro_mode = false

function love.load(argv)
	love_args = argv
	if love.system.getOS() == "Android" then
		love.resize(love.window.getDimensions())
	else
		love.window.setMode(__pico_resolution[1]*scale+xpadding*scale*2,__pico_resolution[2]*scale+ypadding*scale*2)
	end
	love.graphics.clear()
	love.graphics.setDefaultFilter('nearest','nearest')
	__screen = love.graphics.newCanvas(__pico_resolution[1],__pico_resolution[2])
	__screen:setFilter('linear','nearest')

	local font = love.graphics.newImageFont("font.png","abcdefghijklmnopqrstuvwxyz\"'`-_/1234567890!?[](){}.,;:<>+=%#^*~ ")
	love.graphics.setFont(font)
	font:setFilter('nearest','nearest')

	love.mouse.setVisible(false)
	love.window.setTitle("picolove")
	love.graphics.setLineStyle('rough')
	love.graphics.setPointStyle('rough')
	love.graphics.setPointSize(1)
	love.graphics.setLineWidth(1)

	love.graphics.origin()
	love.graphics.setCanvas(__screen)
	restore_clip()

	__draw_palette = {}
	__display_palette = {}
	__pico_pal_transparent = {}
	for i=1,16 do
		__draw_palette[i] = i
		__pico_pal_transparent[i] = i == 1 and 0 or 1
		__display_palette[i] = __pico_palette[i]
	end


	__draw_shader = love.graphics.newShader([[
extern float palette[16];

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	int index = int(color.r*16.0);
	return vec4(vec3(palette[index]/16.0),1.0);
}]])
	__draw_shader:send('palette',unpack(__draw_palette))

	__sprite_shader = love.graphics.newShader([[
extern float palette[16];
extern float transparent[16];

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	int index = int(floor(Texel(texture, texture_coords).r*16.0));
	float alpha = transparent[index];
	return vec4(vec3(palette[index]/16.0),alpha);
}]])
	__sprite_shader:send('palette',unpack(__draw_palette))
	__sprite_shader:send('transparent',unpack(__pico_pal_transparent))

	__text_shader = love.graphics.newShader([[
extern float palette[16];

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 texcolor = Texel(texture, texture_coords);
	if(texcolor.a == 0) {
		return vec4(0.0,0.0,0.0,0.0);
	}
	int index = int(color.r*16.0);
	// lookup the colour in the palette by index
	return vec4(vec3(palette[index]/16.0),1.0);
}]])
	__text_shader:send('palette',unpack(__draw_palette))

	__display_shader = love.graphics.newShader([[

extern vec4 palette[16];

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	int index = int(Texel(texture, texture_coords).r*15.0);
	// lookup the colour in the palette by index
	return palette[index]/256.0;
}]])
	__display_shader:send('palette',unpack(__display_palette))

	pal()

	-- load the cart
	clip()
	camera()
	pal()
	palt()
	color(0)
	_load(argv[2] or 'nocart.p8')
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
	--lua = lua:gsub("%-%-[^\n]*\n","\n")
	lua = lua:gsub("!=","~=")
	-- rewrite shorthand if statements eg. if (not b) i=1 j=2
	lua = lua:gsub("if%s*(%b())%s*([^\n]*)\n",function(a,b)
		local nl = a:find('\n')
		local th = b:find('%f[%w]then%f[%W]')
		local an = b:find('%f[%w]and%f[%W]')
		local o = b:find('%f[%w]or%f[W]')
		if nl or th or an or o then
			return string.format('if %s %s\n',a,b)
		else
			return "if "..a:sub(2,#a-1).." then "..b.." end\n"
		end
	end)
	-- rewrite assignment operators
	lua = lua:gsub("(%S+)%s*([%+-%*/%%])=","%1 = %1 %2 ")

	local cart_G = {
		-- extra functions provided by picolove
		assert=assert,
		error=error,
		log=log,
		pairs=pairs,
		ipairs=ipairs,
		warning=warning,
		setfps=setfps,
		_keydown=nil,
		_keyup=nil,
		_textinput=nil,
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
		load=_load,
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
		stat=stat,
		-- deprecated pico-8 function aliases
		mapdraw=map
	}

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

	if version > 2 then
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
		assert(shared == 128 * 32,shared)
	end

	for y=0,15 do
		for x=0,15 do
			__pico_quads[sprite] = love.graphics.newQuad(8*x,8*y,8,8,128,128)
			sprite = sprite + 1
		end
	end

	assert(sprite == 256,sprite)

	__pico_spritesheet = love.graphics.newImage(__pico_spritesheet_data)

	local tmp = love.graphics.newCanvas(128,128)
	local spritesheetout = love.graphics.newCanvas(128,128)

	love.graphics.setCanvas(tmp)
	love.graphics.setShader(__sprite_shader)
	love.graphics.draw(__pico_spritesheet,0,0,0)

	love.graphics.setShader(__display_shader)
	love.graphics.setCanvas(spritesheetout)
	love.graphics.draw(tmp,0,0,0)
	spritesheetout:getImageData():encode('spritesheet.png')

	love.graphics.setCanvas()
	love.graphics.setShader()

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
	local mapimage = love.graphics.newCanvas(1024,512)
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


	local ok,f,e = pcall(load,lua,cartname)
	if not ok or f==nil then
		error("Error loading lua: "..tostring(e))
	else
		local result
		setfenv(f,cart_G)
		love.graphics.setShader(__draw_shader)
		love.graphics.setCanvas(__screen)
		love.graphics.origin()
		restore_clip()
		ok,result = pcall(f)
		if not ok then
			error("Error running lua: "..tostring(result))
		else
			log("lua completed")
		end
	end
	log("finished loading cart",filename)

	return cart_G
end

function love.update(dt)
	host_time = host_time + dt
	for p=0,1 do
		for i=0,#__keymap[p] do
			local v = __pico_keypressed[p][i]
			if v then
				v = v + 1
				__pico_keypressed[p][i] = v
			end
		end
	end
	if cart._update then cart._update() end
end

function love.resize(w,h)
	love.graphics.clear()
	-- adjust stuff to fit the screen
	if w > h then
		scale = h/(__pico_resolution[2]+ypadding*2)
	else
		scale = w/(__pico_resolution[1]+xpadding*2)
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
		while dt > frametime do
			if love.update then love.update(frametime) end -- will pass 0 if love.timer is disabled
			dt = dt - frametime
			render = true
		end

		if render and love.window and love.graphics and love.window.isCreated() then
			love.graphics.origin()
			if love.draw then love.draw() end
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end

function flip_screen()
	--love.graphics.setShader(__display_shader)
	love.graphics.setShader(__display_shader)
	__display_shader:send('palette',unpack(__display_palette))
	love.graphics.setCanvas()
	love.graphics.origin()

	love.graphics.setColor(255,255,255,255)
	love.graphics.setScissor()

	love.graphics.clear()

	local screen_w,screen_h = love.graphics.getDimensions()
	if screen_w > screen_h then
		love.graphics.draw(__screen,screen_w/2-64*scale,ypadding*scale,0,scale,scale)
	else
		love.graphics.draw(__screen,xpadding*scale,screen_h/2-64*scale,0,scale,scale)
	end

	love.graphics.present()

	if video_frames then
		local tmp = love.graphics.newCanvas(__pico_resolution[1],__pico_resolution[2])
		love.graphics.setCanvas(tmp)
		love.graphics.draw(__screen,0,0)
		table.insert(video_frames,tmp:getImageData())
	end
	-- get ready for next time
	love.graphics.setShader(__draw_shader)
	love.graphics.setCanvas(__screen)
	restore_clip()
	restore_camera()
end

function love.draw()
	love.graphics.setCanvas(__screen)
	restore_clip()
	restore_camera()

	love.graphics.setShader(__draw_shader)

	-- run the cart's draw function
	if cart._draw then cart._draw() end

	-- draw the contents of pico screen to our screen
	flip_screen()
end

function love.keypressed(key)
	if cart and cart._keydown then
		return cart._keydown(key)
	end
	if key == 'r' and love.keyboard.isDown('lctrl') then
		reload()
	elseif key == 'q' and love.keyboard.isDown('lctrl') then
		love.event.quit()
	elseif key == 'f6' then
		-- screenshot
		local screenshot = love.graphics.newScreenshot(false)
		local filename = cartname..'-'..os.time()..'.png'
		screenshot:encode(filename)
		log('saved screenshort to',filename)
	elseif key == 'f8' then
		-- start recording
		video_frames = {}
	elseif key == 'f9' then
		-- stop recording and save
		local basename = cartname..'-'..os.time()..'-'
		for i,v in ipairs(video_frames) do
			v:encode(string.format("%s%04d.png",basename,i))
		end
		video_frames = nil
		log('saved video to',basename)
	else
		for p=0,1 do
			for i=0,#__keymap[p] do
				if key == __keymap[p][i] then
					__pico_keypressed[p][i] = -1 -- becomes 0 on the next frame
					break
				end
			end
		end
	end
end

function love.keyreleased(key)
	if cart and cart._keyup then
		return cart._keyup(key)
	end
	for p=0,1 do
		for i=0,#__keymap[p] do
			if key == __keymap[p][i] then
				__pico_keypressed[p][i] = nil
				break
			end
		end
	end
end

function love.textinput(text)
	if cart and cart._textinput then return cart._textinput(text) end
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
		__pico_clip = {x,y,w,h}
	else
		love.graphics.setScissor(0,0,__pico_resolution[1],__pico_resolution[2])
		__pico_clip = nil
	end
end

function restore_clip()
	if __pico_clip then
		love.graphics.setScissor(unpack(__pico_clip))
	else
		love.graphics.setScissor(0,0,__pico_resolution[1],__pico_resolution[2])
	end
end

function pget(x,y)
	if x >= 0 and x < __pico_resolution[1] and y >= 0 and y < __pico_resolution[2] then
		local r,g,b,a = __screen:getPixel(flr(x),flr(y))
		return flr(r/17.0)
	else
		warning(string.format("pget out of screen %d,%d",x,y))
		return 0
	end
end

function pset(x,y,c)
	if not c then return end
	color(c)
	love.graphics.point(flr(x),flr(y),c*16,0,0,255)
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
	__pico_spritesheet:refresh()
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
	-- fset n [f] v
	-- f is the flag index 0..7
	-- v is boolean
	if v == nil then
		v,f = f,nil
	end
	if f then
		-- set specific bit to v (true or false)
		if f then
			__pico_spriteflags[n] = bor(__pico_spriteflags[n],shl(1,f))
		else
			__pico_spriteflags[n] = band(bnot(__pico_spriteflags[n],shl(1,f)))
		end
	else
		-- set bitfield to v (number)
		__pico_spriteflags[n] = v
	end
end

function flip()
	flip_screen()
	love.timer.sleep(frametime)
end

log = print
function print(str,x,y,col)
	if col then color(col) end
	if y==nil then
		y = __pico_cursor[2]
		__pico_cursor[2] = __pico_cursor[2] + 6
	end
	if x==nil then
		x = __pico_cursor[1]
	end
	love.graphics.setShader(__text_shader)
	love.graphics.print(str,flr(x),flr(y))
	love.graphics.setShader(__text_shader)
end

__pico_cursor = {0,0}

function cursor(x,y)
	__pico_cursor = {x,y}
end

function color(c)
	c = flr(c)
	assert(c >= 0 and c <= 16,string.format("c is %s",c))
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
	else
		__pico_camera_x = 0
		__pico_camera_y = 0
	end
	restore_camera()
end

function restore_camera()
	love.graphics.origin()
	love.graphics.translate(-__pico_camera_x,-__pico_camera_y)
end

function circ(ox,oy,r,col)
	col = col or __pico_color
	color(col)
	ox = flr(ox)
	oy = flr(oy)
	r = flr(r)
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
		if decisionOver2 <= 0 then
			decisionOver2 = decisionOver2 + 2 * y + 1
		else
			x = x - 1
			decisionOver2 = decisionOver2 + 2 * (y-x) + 1
		end
	end
	lineMesh:setVertices(points)
	lineMesh:setDrawRange(1,#points)
	love.graphics.draw(lineMesh)
end

function _plot4points(points,cx,cy,x,y)
	_horizontal_line(points, cx - x, cy + y, cx + x)
	if x ~= 0 and y ~= 0 then
		_horizontal_line(points, cx - x, cy - y, cx + x)
	end
end

function _horizontal_line(points,x0,y,x1)
	for x=x0,x1 do
		table.insert(points,{x,y})
	end
end

function circfill(cx,cy,r,col)
	col = col or __pico_color
	color(col)
	cx = flr(cx)
	cy = flr(cy)
	r = flr(r)
	local x = r
	local y = 0
	local err = -r

	local points = {}

	while y <= x do
		local lasty = y
		err = err + y
		y = y + 1
		err = err + y
		_plot4points(points,cx,cy,x,lasty)
		if err > 0 then
			if x ~= lasty then
				_plot4points(points,cx,cy,lasty,x)
			end
			err = err - x
			x = x - 1
			err = err - x
		end
	end

	lineMesh:setVertices(points)
	lineMesh:setDrawRange(1,#points)
	love.graphics.draw(lineMesh)

end

function line(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)

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
				table.insert(points,{flr(x0),flr(y0)})
			end
		end
	end
	lineMesh:setVertices(points)
	lineMesh:setDrawRange(1,#points)
	love.graphics.draw(lineMesh)
end

function _load(_cartname)
	love.graphics.setShader(__draw_shader)
	love.graphics.setCanvas(__screen)
	love.graphics.origin()
	restore_clip()
	cartname = _cartname
	cart = load_p8(cartname)
end

function rect(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)
	love.graphics.rectangle("line",flr(x0)+1,flr(y0)+1,flr(x1-x0),flr(y1-y0))
end

function rectfill(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)
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
	love.graphics.rectangle("fill",flr(x0),flr(y0),w,h)
end

function run()
	love.graphics.setCanvas(__screen)
	love.graphics.setShader(__draw_shader)
	restore_clip()
	love.graphics.origin()
	if cart._init then cart._init() end
end

function reload()
	_load(cartname)
	run()
end

local __palette_modified = true

function pal(c0,c1,p)
	if c0 == nil then
		if __palette_modified == false then return end
		for i=1,16 do
			__draw_palette[i] = i
			__display_palette[i] = __pico_palette[i]
		end
		__draw_shader:send('palette',unpack(__draw_palette))
		__sprite_shader:send('palette',unpack(__draw_palette))
		__text_shader:send('palette',unpack(__draw_palette))
		__display_shader:send('palette',unpack(__display_palette))
		__palette_modified = false
	elseif p == 1 and c1 ~= nil then
		c0 = flr(c0)%16
		c1 = flr(c1)%16
		c1 = c1+1
		c0 = c0+1
		__display_palette[c0] = __pico_palette[c1]
		__display_shader:send('palette',unpack(__display_palette))
		__palette_modified = true
	elseif c1 ~= nil then
		c0 = flr(c0)%16
		c1 = flr(c1)%16
		c1 = c1+1
		c0 = c0+1
		__draw_palette[c0] = c1
		__draw_shader:send('palette',unpack(__draw_palette))
		__sprite_shader:send('palette',unpack(__draw_palette))
		__text_shader:send('palette',unpack(__draw_palette))
		__palette_modified = true
	end
end

function palt(c,t)
	if c == nil then
		for i=1,16 do
			__pico_pal_transparent[i] = i == 1 and 0 or 1
		end
	else
		c = flr(c)%16
		if t == false then
			__pico_pal_transparent[c+1] = 1
		elseif t == true then
			__pico_pal_transparent[c+1] = 0
		end
	end
	__sprite_shader:send('transparent',unpack(__pico_pal_transparent))
end

function spr(n,x,y,w,h,flip_x,flip_y)
	n = flr(n)
	love.graphics.setShader(__sprite_shader)
	__sprite_shader:send('transparent',unpack(__pico_pal_transparent))
	w = w or 1
	h = h or 1
	local q
	if w == 1 and h == 1 then
		q = __pico_quads[n]
	else
		local id = string.format("%d-%d-%d",n,w,h)
		if __pico_quads[id] then
			q =  __pico_quads[id]
		else
			q = love.graphics.newQuad(flr(n%16)*8,flr(n/16)*8,8*w,8*h,128,128)
			__pico_quads[id] = q
		end
	end
	if not q then
		log('missing quad',n)
	end
	love.graphics.draw(__pico_spritesheet,q,
		flr(x)+(w*8*(flip_x and 1 or 0)),
		flr(y)+(h*8*(flip_y and 1 or 0)),
		0,flip_x and -1 or 1,flip_y and -1 or 1)
	love.graphics.setShader(__draw_shader)
end

function sspr(sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y)
-- Stretch rectangle from sprite sheet (sx, sy, sw, sh) // given in pixels
-- and draw in rectangle (dx, dy, dw, dh)
-- Colour 0 drawn as transparent by default (see palt())
-- dw, dh defaults to sw, sh
-- flip_x=true to flip horizontally
-- flip_y=true to flip vertically
	dw = dw or sw
	dh = dh or sh
	-- FIXME: cache this quad
	-- FIXME handle flipping
	local q = love.graphics.newQuad(sx,sy,sw,sh,__pico_spritesheet:getDimensions())
	love.graphics.setShader(__sprite_shader)
	__sprite_shader:send('transparent',unpack(__pico_pal_transparent))
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

function warning(msg)
	log(debug.traceback("WARNING: "..msg,3))
end

function foreach(a,f)
	if not a then
		warning("foreach got a nil value")
		return
	end
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

__pico_keypressed = {
	[0] = {},
	[1] = {}
}

__keymap = {
	[0] = {
		[0] = 'left',
		[1] = 'right',
		[2] = 'up',
		[3] = 'down',
		[4] = 'z',
		[5] = 'x',
	},
	[1] = {
		[0] = 's',
		[1] = 'f',
		[2] = 'e',
		[3] = 'd',
		[4] = 'q',
		[5] = 'a',
	}
}

function btn(i,p)
	p = p or 0
	if __keymap[p][i] then
		return __pico_keypressed[p][i] ~= nil
	end
	return false
end



function btnp(i,p)
	p = p or 0
	if __keymap[p][i] then
		local v = __pico_keypressed[p][i]
		if v and (v == 0 or v == 12 or (v > 12 and v % 4 == 0)) then
			return true
		end
	end
	return false
end

function sfx(n,channel,offset)
end

function music(n,fade_len,channel_mask)
end

function mget(x,y)
	if x == nil or y == nil then return 0 end
	if y > 63 or x > 127 or x < 0 or y < 0 then return 0 end
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
	for y=0,cel_h-1 do
		if cel_y+y < 64 and cel_y+y >= 0 then
			for x=0,cel_w-1 do
				if cel_x+x < 128 and cel_x+x >= 0 then
					local v = __pico_map[flr(cel_y+y)][flr(cel_x+x)]
					if v > 0 then
						if bitmask == nil or bitmask == 0 then
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
	love.graphics.setShader(__draw_shader)
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
cos = function(x) return math.cos((x or 0)*(math.pi*2)) end
sin = function(x) return math.sin(-(x or 0)*(math.pi*2)) end
atan2 = function(y,x) return __pico_angle(math.atan2(y,x)) end

sqrt = math.sqrt
abs = math.abs
rnd = function(x) return love.math.random()*(x or 1) end
srand = function(seed)
	return love.math.setRandomSeed(flr(seed*32768))
end
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

function stat(x)
	return 0
end

love.graphics.point = function(x,y)
	love.graphics.rectangle('fill',x,y,1,1)
end

setfps = function(fps)
	__pico_fps = flr(fps)
	if __pico_fps <= 0 then
		__pico_fps = 30
	end
	frametime = 1/__pico_fps
end
