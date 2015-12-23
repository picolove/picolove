require "strict"

local __pico_fps=30

local frametime = 1/__pico_fps

local __compression_map = {
	'INVALID',
	' ',
	'0',
	'1',
	'2',
	'3',
	'4',
	'5',
	'6',
	'7',
	'8',
	'9',
	'a',
	'b',
	'c',
	'd',
	'e',
	'f',
	'g',
	'h',
	'i',
	'j',
	'k',
	'l',
	'm',
	'n',
	'o',
	'p',
	'q',
	'r',
	's',
	't',
	'u',
	'v',
	'w',
	'x',
	'y',
	'z',
	'!',
	'#',
	'%',
	'(',
	')',
	'{',
	'}',
	'[',
	']',
	'<',
	'>',
	'+',
	'=',
	'/',
	'*',
	':',
	';',
	'.',
	',',
	'~',
	'_',
	'"',
}

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
local loaded_code = nil

local __audio_buffer_size = 1024

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
	{255,240,36,255},
	{0,231,86,255},
	{41,173,255,255},
	{131,118,156,255},
	{255,119,168,255},
	{255,204,170,255}
}

local video_frames = nil

local __pico_camera_x = 0
local __pico_camera_y = 0
local osc

local host_time = 0

local retro_mode = false

local __pico_audio_channels = {
	[0]={},
	[1]={},
	[2]={},
	[3]={}
}

local __pico_sfx = {}
local __audio_channels
local __sample_rate = 22050
local channels = 1
local bits = 16

local __pico_music = {}

local __pico_current_music = nil

local currentDirectory = '/'

function get_bits(v,s,e)
	local mask = shl(shl(1,s)-1,e)
	return shr(band(mask,v))
end

local QueueableSource = require "QueueableSource"

function lowpass(y0,y1, cutoff)
	local RC = 1.0/(cutoff*2*3.14)
	local dt = 1.0/__sample_rate
	local alpha = dt/(RC+dt)
	return y0 + (alpha*(y1 - y0))
end

local paused = false
local focus = true

function love.load(argv)
	love_args = argv
	if love.system.getOS() == "Android" then
		love.resize(love.window.getDimensions())
	else
		love.window.setMode(__pico_resolution[1]*scale+xpadding*scale*2,__pico_resolution[2]*scale+ypadding*scale*2)
	end

	osc = {}
	osc[0] = function()
		-- tri
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			return (abs((x%2)-1)-0.5) * 0.5
		end
	end
	osc[1] = function()
		-- uneven tri
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			local t = x%1
			return (((t < 0.875) and (t * 16 / 7) or ((1-t)*16)) -1) * 0.5
		end
	end
	osc[2] = function()
		-- saw
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			return (x%1-0.5) * 0.333
		end
	end
	osc[3] = function()
		-- sqr
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			return (x%2 < 0.5 and 1 or -1) * 0.25
		end
	end
	osc[4] = function(x)
		-- pulse
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			return (x%2 < 0.25 and 1 or -1) * 0.25
		end
	end
	osc[5] = function(x)
		-- tri/2
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			return (abs((x%2)-1)-0.5 + (abs(((x*0.5)%2)-1)-0.5)/2) * 0.333
		end
	end
	osc[6] = function(x)
		-- noise FIXME: (zep said this is brown noise)
		local x = 0
		local last_samples = {0}
		return function(freq)
			local y = last_samples[#last_samples] + (love.math.random()*2-1)/10
			y = lowpass(last_samples[#last_samples],y,freq)
			table.insert(last_samples,y)
			table.remove(last_samples,1)
			return mid(-1,y * 1.666,1)
			--return y * 0.666
		end
	end
	osc[7] = function(x)
		-- detuned tri
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			return (abs((x%2)-1)-0.5 + (abs(((x*0.97)%2)-1)-0.5)/2) * 0.333
		end
	end
	osc["saw_lfo"] = function()
		-- saw from 0 to 1, used for arppregiator
		local x = 0
		return function(freq)
			x = x + freq/__sample_rate
			return x%1
		end
	end

	__audio_channels = {
		[0]=QueueableSource:new(8),
		QueueableSource:new(8),
		QueueableSource:new(8),
		QueueableSource:new(8)
	}

	for i=0,3 do
		__audio_channels[i]:play()
	end

	love.graphics.clear()
	love.graphics.setDefaultFilter('nearest','nearest')
	__screen = love.graphics.newCanvas(__pico_resolution[1],__pico_resolution[2])
	__screen:setFilter('linear','nearest')

	local font = love.graphics.newImageFont("font.png","abcdefghijklmnopqrstuvwxyz\"'`-_/1234567890!?[](){}.,;:<>+=%#^*~ ")
	love.graphics.setFont(font)
	font:setFilter('nearest','nearest')

	love.mouse.setVisible(false)
	love.keyboard.setKeyRepeat(true)
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
	color(6)

	_load(argv[2] or 'nocart.p8')
	run()
end

function new_sandbox()
	return {
		-- extra functions provided by picolove
		assert=assert,
		error=error,
		log=log,
		pairs=pairs,
		ipairs=ipairs,
		warning=warning,
		setfps=setfps,
		_call=_call,
		_keydown=nil,
		_keyup=nil,
		_textinput=nil,
		_getcursorx=_getcursorx,
		_getcursory=_getcursory,
		-- pico8 api functions go here
		clip=clip,
		pget=pget,
		pset=pset,
		sget=sget,
		sset=sset,
		fget=fget,
		fset=fset,
		flip=flip,
		folder=folder,
		print=print,
		printh=log,
		cd=cd,
		cursor=cursor,
		color=color,
		cls=cls,
		camera=camera,
		circ=circ,
		circfill=circfill,
		help=help,
		dir=ls,
		line=line,
		load=_load,
		ls=ls,
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
		exit=shutdown,
		shutdown=shutdown,
		sub=sub,
		stat=stat,
		time=function() return host_time end,
		-- deprecated pico-8 function aliases
		mapdraw=map
	}
end

function load_p8(filename)
	log("Loading",filename)

	local lua = ""
	__pico_map = {}
	__pico_quads = {}
	for y=0,63 do
		__pico_map[y] = {}
		for x=0,127 do
			__pico_map[y][x] = 0
		end
	end
	__pico_spritesheet_data = love.image.newImageData(128,128)
	__pico_spriteflags = {}

	if filename:sub(#filename-3,#filename) == '.png' then
		local img = love.graphics.newImage(filename)
		if img:getWidth() ~= 160 or img:getHeight() ~= 205 then
			error("Image is the wrong size")
		end
		local data = img:getData()

		local outX = 0
		local outY = 0
		local inbyte = 0
		local lastbyte = nil
		local mapY = 32
		local mapX = 0
		local version = nil
		local codelen = nil
		local code = ""
		local sprite = 0
		for y=0,204 do
			for x=0,159 do
				local r,g,b,a = data:getPixel(x,y)
				-- extract lowest bits
				r = bit.band(r,0x0003)
				g = bit.band(g,0x0003)
				b = bit.band(b,0x0003)
				a = bit.band(a,0x0003)
				data:setPixel(x,y,bit.lshift(r,6),bit.lshift(g,6),bit.lshift(b,6),255)
				local byte = b + bit.lshift(g,2) + bit.lshift(r,4) + bit.lshift(a,6)
				local lo = bit.band(byte,0x0f)
				local hi = bit.rshift(byte,4)
				if inbyte < 0x2000 then
					if outY >= 64 then
						__pico_map[mapY][mapX] = byte
						mapX = mapX + 1
						if mapX == 128 then
							mapX = 0
							mapY = mapY + 1
						end
					end
					__pico_spritesheet_data:setPixel(outX,outY,lo*16,lo*16,lo*16)
					outX = outX + 1
					__pico_spritesheet_data:setPixel(outX,outY,hi*16,hi*16,hi*16)
					outX = outX + 1
					if outX == 128 then
						outY = outY + 1
						outX = 0
						if outY == 128 then
							-- end of spritesheet, generate quads
							__pico_spritesheet = love.graphics.newImage(__pico_spritesheet_data)
							local sprite = 0
							for yy=0,15 do
								for xx=0,15 do
									__pico_quads[sprite] = love.graphics.newQuad(xx*8,yy*8,8,8,__pico_spritesheet:getDimensions())
									sprite = sprite + 1
								end
							end
							mapY = 0
							mapX = 0
						end
					end
				elseif inbyte < 0x3000 then
					__pico_map[mapY][mapX] = byte
					mapX = mapX + 1
					if mapX == 128 then
						mapX = 0
						mapY = mapY + 1
					end
				elseif inbyte < 0x3100 then
					__pico_spriteflags[sprite] = byte
					sprite = sprite + 1
				elseif inbyte < 0x3200 then
					-- load song
				elseif inbyte < 0x4300 then
					-- sfx
				elseif inbyte == 0x8000 then
					version = byte
				else
					-- code, possibly compressed
					if inbyte == 0x4305 then
						codelen = bit.lshift(lastbyte,8) + byte
					elseif inbyte >= 0x4308 then
						code = code .. string.char(byte)
					end
					lastbyte = byte
				end
				inbyte = inbyte + 1
			end
		end

		-- decompress code
		log('version',version)
		log('codelen',codelen)
		if version == 0 then
			lua = code
		elseif version == 1 or version == 5 then
			-- decompress code
			local mode = 0
			local copy = nil
			local i = 0
			while #lua < codelen do
				i = i + 1
				local byte = string.byte(code,i,i)
				if byte == nil then
					error('reached end of code')
				else
					if mode == 1 then
						lua = lua .. code:sub(i,i)
						mode = 0
					elseif mode == 2 then
						-- copy from buffer
						local offset = (copy - 0x3c) * 16 + bit.band(byte,0xf)
						local length = bit.rshift(byte,4) + 2

						local offset = #lua - offset
						local buffer = lua:sub(offset+1,offset+1+length-1)
						lua = lua .. buffer
						mode = 0
					elseif byte == 0x00 then
						-- output next byte
						mode = 1
					elseif byte == 0x01 then
						-- output newline
						lua = lua .. "\n"
					elseif byte >= 0x02 and byte <= 0x3b then
						-- output this byte from map
						lua = lua .. __compression_map[byte]
					elseif byte >= 0x3c then
						-- copy previous bytes
						mode = 2
						copy = byte
					end
				end
			end
		else
			error(string.format('unknown file version %d',version))
		end

	else
		local f = love.filesystem.newFile(filename,'r')
		if not f then
			error(string.format("Unable to open: %s",filename))
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

		lua = data:sub(lua_start,lua_end)

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

		if version > 3 then
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

		-- load the sprite flags

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

		-- load sfx
		local sfx_start = data:find("__sfx__") + 8
		local sfx_end = data:find("__music__") - 1
		local sfxdata = data:sub(sfx_start,sfx_end)

		__pico_sfx = {}
		for i=0,63 do
			__pico_sfx[i] = {
				speed=16,
				loop_start=0,
				loop_end=0
			}
			for j=0,31 do
				__pico_sfx[i][j] = {0,0,0,0}
			end
		end

		local _sfx = 0
		local step = 0

		local next_line = 1
		while next_line do
			local end_of_line = sfxdata:find("\n",next_line)
			if end_of_line == nil then break end
			end_of_line = end_of_line - 1
			local line = sfxdata:sub(next_line,end_of_line)
			local editor_mode = tonumber(line:sub(1,2),16)
			__pico_sfx[_sfx].speed = tonumber(line:sub(3,4),16)
			__pico_sfx[_sfx].loop_start = tonumber(line:sub(5,6),16)
			__pico_sfx[_sfx].loop_end = tonumber(line:sub(7,8),16)
			for i=9,#line,5 do
				local v = line:sub(i,i+4)
				assert(#v == 5)
				local note  = tonumber(line:sub(i,i+1),16)
				local instr = tonumber(line:sub(i+2,i+2),16)
				local vol   = tonumber(line:sub(i+3,i+3),16)
				local fx    = tonumber(line:sub(i+4,i+4),16)
				__pico_sfx[_sfx][step] = {note,instr,vol,fx}
				step = step + 1
			end
			_sfx = _sfx + 1
			step = 0
			next_line = sfxdata:find("\n",end_of_line)+1
		end

		assert(_sfx == 64)

		-- load music
		local music_start = data:find("__music__") + 10
		local music_end = #data-1
		local musicdata = data:sub(music_start,music_end)

		local _music = 0
		__pico_music = {}

		local next_line = 1
		while next_line do
			local end_of_line = musicdata:find("\n",next_line)
			if end_of_line == nil then break end
			end_of_line = end_of_line - 1
			local line = musicdata:sub(next_line,end_of_line)

			__pico_music[_music] = {
				loop = tonumber(line:sub(1,2),16),
				[0] = tonumber(line:sub(4,5),16),
				[1] = tonumber(line:sub(6,7),16),
				[2] = tonumber(line:sub(8,9),16),
				[3] = tonumber(line:sub(10,11),16)
			}
			_music = _music + 1
			next_line = musicdata:find("\n",end_of_line)+1
		end
	end

	-- patch the lua
	lua = lua:gsub("!=","~=")
	-- rewrite shorthand if statements eg. if (not b) i=1 j=2
	lua = lua:gsub("if%s*(%b())%s*([^\n]*)\n",function(a,b)
		local nl = a:find('\n')
		local th = b:find('%f[%w]then%f[%W]')
		local an = b:find('%f[%w]and%f[%W]')
		local o = b:find('%f[%w]or%f[%W]')
		if nl or th or an or o then
			return string.format('if %s %s\n',a,b)
		else
			return "if "..a:sub(2,#a-1).." then "..b.." end\n"
		end
	end)
	-- rewrite assignment operators
	lua = lua:gsub("(%S+)%s*([%+-%*/%%])=","%1 = %1 %2 ")

	log("finished loading cart",filename)

	loaded_code = lua

	return true
end

function love.update(dt)
	for p=0,1 do
		for i=0,#__keymap[p] do
			for _,key in pairs(__keymap[p][i]) do
				local v = __pico_keypressed[p][i]
				if v then
					v = v + 1
					__pico_keypressed[p][i] = v
					break
				end
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
			host_time = host_time + dt
			if host_time > 65536 then host_time = host_time - 65536 end
			if paused or not focus then
			else
				if love.update then love.update(frametime) end -- will pass 0 if love.timer is disabled
				update_audio(frametime)
			end
			dt = dt - frametime
			render = true
		end

		if render and love.window and love.graphics and love.window.isCreated() then
			love.graphics.origin()
			if not paused and focus then
				if love.draw then love.draw() end
			end
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end

function love.focus(f)
	focus = f
end

note_map = {
	[0] = 'C-',
	'C#',
	'D-',
	'D#',
	'E-',
	'F-',
	'F#',
	'G-',
	'G#',
	'A-',
	'A#',
	'B-',
}

function note_to_string(note)
	local octave = flr(note/12)
	local note = flr(note%12)
	return string.format("%s%d",note_map[note],octave)
end

function note_to_hz(note)
	return 440*math.pow(2,(note-33)/12)
end

function update_audio(time)
	-- check what sfx should be playing
	local samples = flr(time*__sample_rate)

	for i=0,samples-1 do
		if __pico_current_music then
			__pico_current_music.offset = __pico_current_music.offset + 1/(48*16)*(1/__pico_current_music.speed*4)
			if __pico_current_music.offset >= 32 then
				local next_track = __pico_current_music.music
				if __pico_music[next_track].loop == 2 then
					-- go back until we find the loop start
					while true do
						if __pico_music[next_track].loop == 1 or next_track == 0 then
							break
						end
						next_track = next_track - 1
					end
				elseif __pico_music[__pico_current_music.music].loop == 4 then
					next_track = nil
				elseif __pico_music[__pico_current_music.music].loop <= 1 then
					next_track = next_track + 1
				end
				if next_track then
					music(next_track)
				end
			end
		end
		local music = __pico_current_music and __pico_music[__pico_current_music.music] or nil

		for channel=0,3 do
			local ch = __pico_audio_channels[channel]
			local tick = 0
			local tickrate = 60*16
			local note,instr,vol,fx
			local freq

			if ch.bufferpos == 0 or ch.bufferpos == nil then
				ch.buffer = love.sound.newSoundData(__audio_buffer_size,__sample_rate,bits,channels)
				ch.bufferpos = 0
			end
			if ch.sfx and __pico_sfx[ch.sfx] then
				local sfx = __pico_sfx[ch.sfx]
				ch.offset = ch.offset + 1/(48*16)*(1/sfx.speed*4)
				if sfx.loop_end ~= 0 and ch.offset >= sfx.loop_end then
					if ch.loop then
						ch.last_step = -1
						ch.offset = sfx.loop_start
					else
						__pico_audio_channels[channel].sfx = nil
					end
				elseif ch.offset >= 32 then
					__pico_audio_channels[channel].sfx = nil
				end
			end
			if ch.sfx and __pico_sfx[ch.sfx] then
				local sfx = __pico_sfx[ch.sfx]
				-- when we pass a new step
				if flr(ch.offset) > ch.last_step then
					ch.lastnote = ch.note
					ch.note,ch.instr,ch.vol,ch.fx = unpack(sfx[flr(ch.offset)])
					ch.osc = osc[ch.instr]()
					if ch.fx == 2 then
						ch.lfo = osc[0]()
					elseif ch.fx >= 6 then
						ch.lfo = osc["saw_lfo"]()
					end
					if ch.vol > 0 then
						ch.freq = note_to_hz(ch.note)
					end
					ch.last_step = flr(ch.offset)
				end
				if ch.vol and ch.vol > 0 then
					local vol = ch.vol
					if ch.fx == 1 then
						-- slide from previous note over the length of a step
						ch.freq = lerp(note_to_hz(ch.lastnote or 0),note_to_hz(ch.note),ch.offset%1)
					elseif ch.fx == 2 then
						-- vibrato one semitone?
						ch.freq = lerp(note_to_hz(ch.note),note_to_hz(ch.note+0.5),ch.lfo(4))
					elseif ch.fx == 3 then
						-- drop/bomb slide from note to c-0
						local off = ch.offset%1
						--local freq = lerp(note_to_hz(ch.note),note_to_hz(0),off)
						local freq = lerp(note_to_hz(ch.note),0,off)
						ch.freq = freq
					elseif ch.fx == 4 then
						-- fade in
						vol = lerp(0,ch.vol,ch.offset%1)
					elseif ch.fx == 5 then
						-- fade out
						vol = lerp(ch.vol,0,ch.offset%1)
					elseif ch.fx == 6 then
						-- fast appreggio over 4 steps
						local off = bit.band(flr(ch.offset),0xfc)
						local lfo = flr(ch.lfo(8)*4)
						off = off + lfo
						local note = sfx[flr(off)][1]
						ch.freq = note_to_hz(note)
					elseif ch.fx == 7 then
						-- slow appreggio over 4 steps
						local off = bit.band(flr(ch.offset),0xfc)
						local lfo = flr(ch.lfo(4)*4)
						off = off + lfo
						local note = sfx[flr(off)][1]
						ch.freq = note_to_hz(note)
					end
					ch.sample = ch.osc(ch.freq) * vol/7
					if ch.offset%1 < 0.1 then
						-- ramp up to avoid pops
						ch.sample = lerp(0,ch.sample,ch.offset%0.1*10)
					elseif ch.offset%1 > 0.9 then
						-- ramp down to avoid pops
						ch.sample = lerp(ch.sample,0,(ch.offset+0.8)%0.1*10)
					end
					ch.buffer:setSample(ch.bufferpos,ch.sample)
				else
					ch.buffer:setSample(ch.bufferpos,lerp(ch.sample or 0,0,0.1))
					ch.sample = 0
				end
			else
				ch.buffer:setSample(ch.bufferpos,lerp(ch.sample or 0,0,0.1))
				ch.sample = 0
			end
			ch.bufferpos = ch.bufferpos + 1
			if ch.bufferpos == __audio_buffer_size then
				-- queue buffer and reset
				__audio_channels[channel]:queue(ch.buffer)
				__audio_channels[channel]:play()
				ch.bufferpos = 0
			end
		end
	end
end

function flip_screen()
	--love.graphics.setShader(__display_shader)
	love.graphics.setShader(__display_shader)
	__display_shader:send('palette',unpack(__display_palette))
	love.graphics.setCanvas()
	love.graphics.origin()

	-- love.graphics.setColor(255,255,255,255)
	love.graphics.setScissor()

	love.graphics.setBackgroundColor(3, 5, 10)
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
	if key == 'r' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('lgui')) then
		reload()
		run()
	elseif key == 'q' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('lgui')) then
		love.event.quit()
	elseif key == 'pause' then
		paused = not paused
	elseif key == 'f6' then
		-- screenshot
		local screenshot = love.graphics.newScreenshot(false)
		local filename = cartname..'-'..os.time()..'.png'
		screenshot:encode(filename)
		log('saved screenshot to',filename)
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
	elseif key == 'return' and (love.keyboard.isDown('lalt') or love.keyboard.isDown('ralt')) then
		love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
	else
		for p=0,1 do
			for i=0,#__keymap[p] do
				for _,testkey in pairs(__keymap[p][i]) do
					if key == testkey then
						__pico_keypressed[p][i] = -1 -- becomes 0 on the next frame
						break
					end
				end
			end
		end
	end
	if cart and cart._keydown then
		return cart._keydown(key)
	end
end

function love.keyreleased(key)
	for p=0,1 do
		for i=0,#__keymap[p] do
			for _,testkey in pairs(__keymap[p][i]) do
				if key == testkey then
					__pico_keypressed[p][i] = nil
					break
				end
			end
		end
	end
	if cart and cart._keyup then
		return cart._keyup(key)
	end
end

function music(n,fade_len,channel_mask)
	if n == -1 then
		for i=0,3 do
			if __pico_current_music and __pico_music[__pico_current_music.music][i] < 64 then
				__pico_audio_channels[i].sfx = nil
				__pico_audio_channels[i].offset = 0
				__pico_audio_channels[i].last_step = -1
			end
		end
		__pico_current_music = nil
		return
	end
	local m = __pico_music[n]
	if not m then
		warning(string.format("music %d does not exist",n))
		return
	end
	local slowest_speed = nil
	local slowest_channel = nil
	for i=0,3 do
		if m[i] < 64 then
			local sfx = __pico_sfx[m[i]]
			if slowest_speed == nil or slowest_speed > sfx.speed then
				slowest_speed = sfx.speed
				slowest_channel = i
			end
		end
	end
	__pico_audio_channels[slowest_channel].loop = false
	__pico_current_music = {music=n,offset=0,channel_mask=channel_mask or 15,speed=slowest_speed}
	for i=0,3 do
		if __pico_music[n][i] < 64 then
			__pico_audio_channels[i].sfx = __pico_music[n][i]
			__pico_audio_channels[i].offset = 0
			__pico_audio_channels[i].last_step = -1
		end
	end
end

function love.textinput(text)
	text = text:lower()
	if cart and cart._textinput then return cart._textinput(text) end
end

function sfx(n,channel,offset)
	-- n = -1 stop sound on channel
	-- n = -2 to stop looping on channel
	channel = channel or -1
	if n == -1 and channel >= 0 then
		__pico_audio_channels[channel].sfx = nil
		return
	elseif n == -2 and channel >= 0 then
		__pico_audio_channels[channel].loop = false
	end
	offset = offset or 0
	if channel == -1 then
		-- find a free channel
		for i=0,3 do
			if __pico_audio_channels[i].sfx == nil then
				channel = i
			end
		end
	end
	if channel == -1 then return end
	local ch = __pico_audio_channels[channel]
	ch.sfx=n
	ch.offset=offset
	ch.last_step=offset-1
	ch.loop=true
end

function clip(x,y,w,h)
	if type(x) == "number" then
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
		if not __pico_spriteflags[flr(n)] then
			warning(string.format('fget(%d,%d)',n,f))
			return 0
		end
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

function folder()
	love.system.openURL("file://"..love.filesystem.getWorkingDirectory())
end

function scroll(pixels)
	local base = 0x6000
	local delta = base + pixels*0x40
	local basehigh = 0x7fff
	memcpy(base, delta, basehigh-delta)
end

log = print
function print(str,x,y,col)
	if col then color(col) end
	local canscroll = y==nil
	if y==nil then
		y = __pico_cursor[2]
		__pico_cursor[2] = __pico_cursor[2] + 6
	end
	if x==nil then
		x = __pico_cursor[1]
	end
	if canscroll and y > 121 then
		local c = col or __pico_color
		scroll(6)
		y = 120
		rectfill(0,y,127,y+6,0)
		color(c)
		cursor(0, y+6)
	end
	love.graphics.setShader(__text_shader)
	love.graphics.print(str,flr(x),flr(y))
	love.graphics.setShader(__text_shader)
end

__pico_cursor = {0,0}

function cursor(x,y)
	__pico_cursor = {x,y}
end

function _getcursorx()
	return __pico_cursor[1]
end

function _getcursory()
	return __pico_cursor[2]
end

function color(c)
	c = flr(c)
	assert(c >= 0 and c <= 16,string.format("c is %s",c))
	__pico_color = c
	love.graphics.setColor(c*16,0,0,255)
end

function cls()
	__screen:clear(0,0,0,255)
	__pico_cursor = {0,0}
end

__pico_camera_x = 0
__pico_camera_y = 0

function camera(x,y)
	if type(x) == 'number' then
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

function help()
	print('')
	color(12)
	print('commands')
	print('')
	color(6)
	print('load <filename>  save <filename>')
	print('run              resume')
	print('shutdown         reboot')
	print('install_demos    dir')
	print('cd <dirname>     mkdir <dirname>')
	print('cd ..   go up a directory')
	print('alt+enter to toggle fullscreen')
	print('alt+f4 or command+q to fastquit')
	print('')
	color(12)
	print('see readme.md for more info or')
	print('visit github.com/ftsf/picolove')
	print('')
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

function _call(code)
	local ok,f,e = pcall(load,code,"repl")
	if not ok or f==nil then
		print("syntax error", nil, nil, 14)
		print(sub(e,20), nil, nil, 6)
		return false
	else
		local result
		setfenv(f,cart)
		ok,e = pcall(f)
		if not ok then
			print("runtime error", nil, nil, 14)
			print(sub(e,20), nil, nil, 6)
		end
	end
	return true
end

function _load(_cartname)
	if love.filesystem.isFile(currentDirectory.._cartname) then
	elseif love.filesystem.isFile(currentDirectory.._cartname..'.p8') then
		_cartname = _cartname..'.p8'
	elseif love.filesystem.isFile(currentDirectory.._cartname..'.p8.png') then
		_cartname = _cartname..'.p8.png'
	else
		print('could not load', nil, nil, 6)
		return
	end
	love.graphics.setShader(__draw_shader)
	love.graphics.setCanvas(__screen)
	love.graphics.origin()
	camera()
	restore_clip()
	cartname = _cartname
	if load_p8(currentDirectory.._cartname) then
		print('loaded '.._cartname, nil, nil, 6)
	end
end

function ls()
	-- TODO: paginate results
	local files = love.filesystem.getDirectoryItems(currentDirectory)
	print("directory: "..currentDirectory, nil, nil, 12)
	for _, file in ipairs(files) do
		file = file:lower()
		if love.filesystem.isDirectory(currentDirectory..'/'..file) then
			color(14)
		else
			if file:sub(-3) == '.p8' or file:sub(-7) == '.p8.png' then
				color(6)
			else
				color(5)
			end
		end
		if #file > 32 then
			for i=1,#file,32 do
				print(file:sub(i,i+32))
				flip()
			end
		else
			print(file)
			flip()
		end
	end
end

function cd(name)
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
		color(12)
		for i=1,#output,32 do
			print(output:sub(i,i+32))
		end
	else
		color(7)
		print(output)
	end
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

	cart = new_sandbox()

	local ok,f,e = pcall(load,loaded_code,cartname)
	if not ok or f==nil then
		log('=======8<========')
		log(loaded_code)
		log('=======>8========')
		error("Error loading lua: "..tostring(e))
	else
		local result
		setfenv(f,cart)
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

	if cart._init then cart._init() end
end

function reload(dest_addr,source_addr,len)
	-- FIXME: doesn't handle ranges, we should keep a "cart rom"
	_load(cartname)
end

local __palette_modified = true

function pal(c0,c1,p)
	if type(c0) ~= 'number' then
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
	if type(c) ~= 'number' then
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
	n = flr(n)
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
		local id = string.format("%d-%d-%d",n,w,h)
		if __pico_quads[id] then
			q = __pico_quads[id]
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
		0,
		flip_x and -1 or 1,
		flip_y and -1 or 1)
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
	local q = love.graphics.newQuad(sx,sy,sw,sh,__pico_spritesheet:getDimensions())
	love.graphics.setShader(__sprite_shader)
	__sprite_shader:send('transparent',unpack(__pico_pal_transparent))
	love.graphics.draw(__pico_spritesheet,q,
		flr(dx)+(dw*(flip_x and 1 or 0)),
		flr(dy)+(dh*(flip_y and 1 or 0)),
		0,
		flip_x and -1 or 1 * (dw/sw),
		flip_y and -1 or 1 * (dh/sh))
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
		[0] = {'left'},
		[1] = {'right'},
		[2] = {'up'},
		[3] = {'down'},
		[4] = {'z','n'},
		[5] = {'x','m'},
	},
	[1] = {
		[0] = {'s'},
		[1] = {'f'},
		[2] = {'e'},
		[3] = {'d'},
		[4] = {'tab','lshift'},
		[5] = {'q','a'},
	}
}

function btn(i,p)
	if type(i) == 'number' then
		p = p or 0
		if __keymap[p][i] then
			return __pico_keypressed[p][i] ~= nil
		end
		return false
	else
		-- return bitfield of buttons
		local bitfield = 0
		for i=0,5 do
			if __pico_keypressed[0][i] then
				bitfield = bitfield + bit.lshift(1,i+1)
			end
		end
		for i=6,13 do
			if __pico_keypressed[1][i] then
				bitfield = bitfield + bit.lshift(1,i+1)
			end
		end
		return bitfield
	end
end

function btnp(i,p)
	if type(i) == 'number' then
		p = p or 0
		if __keymap[p][i] then
			local v = __pico_keypressed[p][i]
			if v and (v == 0 or v == 12 or (v > 12 and v % 4 == 0)) then
				return true
			end
		end
		return false
	else
		-- return bitfield of buttons
		local bitfield = 0
		for i=0,5 do
			if __pico_keypressed[0][i] then
				bitfield = bitfield + bit.lshift(1,i+1)
			end
		end
		for i=6,13 do
			if __pico_keypressed[1][i] then
				bitfield = bitfield + bit.lshift(1,i+1)
			end
		end
		return bitfield
	end
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
		for i=0,len-1 do
			local x = flr(source_addr-0x6000+i)%64*2
			local y = flr((source_addr-0x6000+i)/64)
			--TODO: why are colors broken?
			local c = ceil(img:getPixel(x,y)/16)
			local d = ceil(img:getPixel(x+1,y)/16)
			if c ~= 0 then
				c = c - 1
			end
			if d ~= 0 then
				d = d - 1
			end

			local dx = flr(dest_addr-0x6000+i)%64*2
			local dy = flr((dest_addr-0x6000+i)/64)
			pset(dx,dy,c)
			pset(dx+1,dy,d)
		end
	end
end

function peek(addr, val)
	-- TODO: implement for non screen space
	if addr >= 0x6000 and addr < 0x8000 then
		local dx = flr(addr-0x6000)%64
		local dy = flr((addr-0x6000)/64)
		local low = pget(dx, dy)
		local high = bit.lshift(pget(dx + 1, dy))
		return bit.band(low, high)
	end
end

function poke(addr, val)
	-- TODO: implement for non screen space
	if addr >= 0x6000 and addr < 0x8000 then
		local dx = flr(addr-0x6000)%64*2
		local dy = flr((addr-0x6000)/64)
		pset(dx, dy, bit.band(val, 15))
		pset(dx + 1, dy, bit.rshift(val, 4))
	end
end

function min(a,b)
	if a == nil or b == nil then
		warning('min a or b are nil returning 0')
		return 0
	end
	if a < b then return a end
	return b
end

function max(a,b)
	if a == nil or b == nil then
		warning('max a or b are nil returning 0')
		return 0
	end
	if a > b then return a end
	return b
end

function mid(x,y,z)
	x = x or 0
	y = y or 0
	z = z or 0
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
ceil = math.ceil
cos = function(x) return math.cos((x or 0)*(math.pi*2)) end
sin = function(x) return math.sin(-(x or 0)*(math.pi*2)) end
atan2 = function(y,x) return __pico_angle(math.atan2(y,x)) end

sqrt = math.sqrt
abs = math.abs
rnd = function(x) return love.math.random()*(x or 1) end
srand = function(seed)
	if seed == 0 then seed = 1 end
	return love.math.setRandomSeed(flr(seed*32768))
end
sgn = function(x)
	if x < 0 then
		return -1
	else
		return 1
	end
end

local bit = require("bit")

band = bit.band
bor = bit.bor
bxor = bit.bxor
bnot = bit.bnot
shl = bit.lshift
shr = bit.rshift

sub = string.sub

function shutdown()
	love.event.quit()
end

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

function lerp(a,b,t)
	return (1-t)*a+t*b
end
