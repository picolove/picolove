require "strict"

local __pico_fps=30

local parselua = require('ParseLua')

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

local font_img
local cart = nil
local cartname = nil
local love_args = nil
local __screen
local __screen_data
local __pico_clip
local __pico_color
local __draw_palette
local __display_palette
local scale = 4
local xpadding = 8.5
local ypadding = 3.5
local __accum = 0
local loaded_code = nil
local __cartdata_id = nil
local __cartdata = {}

for i=0,63 do
	__cartdata[i] = 0
end

local __audio_buffer_size = 1024

local __pico_pal_transparent = {
}

local ffi = require "ffi"
ffi.cdef[[
typedef union {
	struct {
		unsigned char low  : 4;
		unsigned char high : 4;
	};
	unsigned char byte : 8;
} byte_t;
]]

ffi.cdef[[
 void *memmove(void *dest, const void *src, size_t n);
]]

local C = ffi.C

local memory = ffi.new("byte_t[?]",0x8000)
-- shared map memory is a bit strange, mset/mget only look at map_data
local map_memory = ffi.new("byte_t[?]",0x1000)
local rom = ffi.new("byte_t[?]",0x4300)

__pico_resolution = {128,128}

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
local fontchars = "abcdefghijklmnopqrstuvwxyz\"'`-_/1234567890!?[](){}.,;:<>+=%#^*~ "

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

	love.graphics.setDefaultFilter('nearest','nearest')

	font_img = love.image.newImageData("font.png")

	love.mouse.setVisible(false)
	love.keyboard.setKeyRepeat(true)
	love.window.setTitle("picolove")

	__draw_palette = {}
	__display_palette = {}
	__pico_pal_transparent = {}
	__screen_data = love.image.newImageData(128,128)

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
		cartdata=cartdata,
		cd=cd,
		cursor=cursor,
		color=color,
		cls=cls,
		camera=camera,
		circ=circ,
		circfill=circfill,
		help=help,
		dir=ls,
		dget=dget,
		dset=dset,
		line=line,
		load=_load,
		ls=ls,
		mkdir=mkdir,
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
		memset=memset,
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
					memory[inbyte].byte = byte
				elseif inbyte < 0x3000 then
					memory[inbyte].byte = byte
				elseif inbyte < 0x3100 then
					memory[inbyte].byte = byte
				elseif inbyte < 0x3200 then
					memory[inbyte].byte = byte
				elseif inbyte < 0x4300 then
					memory[inbyte].byte = byte
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
				if col % 2 == 0 then
					memory[0x0000+row*64+flr(col/2)].low = v
				else
					memory[0x0000+row*64+flr(col/2)].high = v
				end

				col = col + 1
				if col == 128 then
					col = 0
					row = row + 1
				end
			end
			next_line = gfxdata:find("\n",end_of_line)+1
		end

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
					memory[0x3000+sprite].byte = v
					sprite = sprite + 1
				end
			else
				for i=1,#line,2 do
					local v = line:sub(i,i+1)
					v = tonumber(v,16)
					memory[0x3000+sprite].byte = v
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
				mset(col,row,v)
				col = col + 1
				tiles = tiles + 1
				if col == 128 then
					col = 0
					row = row + 1
				end
			end
			next_line = mapdata:find("\n",end_of_line)+1
		end

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
	local original_lua = lua
	-- ensure there is a newline at end of lua
	lua = lua .. '\n'
	lua = lua_comment_remover(lua)

	-- apply if shorthand macro
	lua = lua:gsub("%f[%a]if%s*(%b())%s*([^\n]*)\n",function(a,b)
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


	do
		local st, ast = parselua.ParseLua(lua)
		if not st then
			local fp = io.open(cartname..'.lua','w')
			fp:write(lua)
			fp:close()
			local fp = io.open(cartname..'.orig.lua','w')
			fp:write(original_lua)
			fp:close()
			error(ast)
		end
		local util = require('Util')
		local format = require('FormatIdentity')
		st, lua = format(ast)
		if not st then
			error(lua,0)
		end
	end

	-- save memory to rom
	for i=0,0x4300-1 do
		rom[i].byte = memory[i].byte
	end

	-- copy memory to map_memory
	ffi.copy(map_memory[0],memory[0x1000],0x1000)

	log("finished loading cart",filename)

	local fp = io.open(cartname..'.lua','w')
	fp:write(lua)
	fp:close()
	local fp = io.open(cartname..'.orig.lua','w')
	fp:write(original_lua)
	fp:close()

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
	if cart._update then
		local ok,result = pcall(cart._update)
		if not ok then
			cls()
			camera()
			log(result)
			result = result:sub(#cartname + 13)
			print("runtime error", nil, nil, 14)
			print_wrap(tostring(result),6)
			cart._update = nil
			cart._draw = nil
		end
	end
end

function love.resize(w,h)
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
	-- copy video memory to screen image
	__screen_data:mapPixel(function(x,y,r,g,b,a)
		local byte = memory[0x6000+64*y+flr(x/2)]
		local color = __pico_palette[__display_palette[(x%2 == 0) and byte.low or byte.high]+1]
		return unpack(color)
	end)
	__screen = love.graphics.newImage(__screen_data)

	-- fill background
	love.graphics.setBackgroundColor(3, 5, 10)
	love.graphics.clear()

	local screen_w,screen_h = love.graphics.getDimensions()
	local draw_mode = peek(0x5f2c)
	local min_x,max_x,min_y,max_y
	local w,h
	if screen_w >= screen_h then
		min_x = screen_w/2-64*scale
		max_x = screen_w/2+64*scale
		min_y = ypadding*scale
		max_y = screen_h-ypadding*scale
		w = max_x - min_x
		h = max_y - min_y
	else
		min_x = xpadding*scale
		max_x = screen_w-xpadding*scale
		min_y = screen_h/2-64*scale
		max_y = screen_h/2+64*scale
		w = max_x - min_x
		h = max_y - min_y
	end

	love.graphics.setScissor(min_x,min_y,w,h)
	if draw_mode == 1 then
		love.graphics.draw(__screen,min_x,min_y,0,scale*2,scale)
	elseif draw_mode == 2 then
		love.graphics.draw(__screen,min_x,min_y,0,scale,scale*2)
	elseif draw_mode == 3 then
		love.graphics.draw(__screen,min_x,min_y,0,scale*2,scale*2)
	elseif draw_mode == 5 then
		-- horizontal mirror
		love.graphics.setScissor(min_x,min_y,w/2,h)
		love.graphics.draw(__screen,min_x,min_y,0,scale,scale)
		love.graphics.setScissor(min_x+w/2,min_y,w/2,h)
		love.graphics.draw(__screen,max_x,min_y,0,-scale,scale)
	elseif draw_mode == 6 then
		-- vertical mirror
		love.graphics.setScissor(min_x,min_y,w,h/2)
		love.graphics.draw(__screen,min_x,min_y,0,scale,scale)
		love.graphics.setScissor(min_x,min_y+h/2,w,h)
		love.graphics.draw(__screen,min_x,max_y,0,scale,-scale)
	elseif draw_mode == 7 then
		-- both mirror

		-- top left
		love.graphics.setScissor(min_x,min_y,w/2,h/2)
		love.graphics.draw(__screen,min_x,min_y,0,scale,scale)

		-- top right
		love.graphics.setScissor(min_x+w/2,min_y,w/2,h/2)
		love.graphics.draw(__screen,max_x,min_y,0,-scale,scale)

		-- bottom left
		love.graphics.setScissor(min_x,min_y+h/2,w/2,h/2)
		love.graphics.draw(__screen,min_x,max_y,0,scale,-scale)

		-- bottom right
		love.graphics.setScissor(min_x+w/2,min_y+h/2,w/2,h/2)
		love.graphics.draw(__screen,max_x,max_y,0,-scale,-scale)
	else
		love.graphics.draw(__screen,min_x,min_y,0,scale,scale)
	end
	love.graphics.setScissor()

	love.graphics.present()

	if video_frames then
		local tmp = love.graphics.newCanvas(__pico_resolution[1],__pico_resolution[2])
		love.graphics.setCanvas(tmp)
		love.graphics.draw(__screen,0,0)
		table.insert(video_frames,tmp:getImageData())
	end
end

function love.draw()
	-- run the cart's draw function
	if cart._draw then
		local ok,result = pcall(cart._draw)
		if not ok then
			cls()
			camera()
			log(result)
			result = result:sub(#cartname + 13)
			print("runtime error", nil, nil, 14)
			print_wrap(tostring(result),6)
			cart._update = nil
			cart._draw = nil

		end
	end

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
	local validchar = false
	for i = 1,#fontchars do
		if fontchars:sub(i,i) == text then
			validchar = true
			break
		end
	end
	if validchar and cart and cart._textinput then
		return cart._textinput(text)
	end
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
		__pico_clip = {x,y,x+w,y+h}
	else
		__pico_clip = {0,0,127,127}
	end
end

function pget(x,y)
	x = flr(x - __pico_camera_x)
	y = flr(y - __pico_camera_y)
	if x < 0 or x > 127 or y < 0 or y > 127 then return 0 end
	if x%2 == 0 then
		return memory[0x6000+y*64+flr(x/2)].low
	else
		return memory[0x6000+y*64+flr(x/2)].high
	end
end

function pset_draw(x,y,c,transparency)
	if type(c) ~= 'number' then c = 0 end
	c = c and flr(c) or 0
	local dc = __draw_palette[c%16]
	x = flr(x - __pico_camera_x)
	y = flr(y - __pico_camera_y)
	if x < 0 or x > 127 or y < 0 or y > 127 then return end
	if x < __pico_clip[1] or x > __pico_clip[3] or y < __pico_clip[2] or y > __pico_clip[4] then return end
	if not transparency or not __pico_pal_transparent[c] then
		if x%2 == 0 then
			memory[0x6000+y*64+flr(x/2)].low = dc
		else
			memory[0x6000+y*64+flr(x/2)].high = dc
		end
	end
end

function pset(x,y,c)
	x = flr(x - __pico_camera_x)
	y = flr(y - __pico_camera_y)
	if x < 0 or x > 127 or y < 0 or y > 127 then return end
	if x < __pico_clip[1] or x > __pico_clip[3] or y < __pico_clip[2] or y > __pico_clip[4] then return end
	c = c and flr(c) or 0
	color(c)
	local dc = __draw_palette[c%16]
	if x%2 == 0 then
		memory[0x6000+y*64+flr(x/2)].low = dc
	else
		memory[0x6000+y*64+flr(x/2)].high = dc
	end
end

function sget(x,y)
	-- return the color from the spritesheet
	x = flr(x)
	y = flr(y)
	if x < 0 or x > 127 or y < 0 or y > 127 then return 0 end
	if x%2 == 0 then
		return memory[0x0000+y*64+flr(x/2)].low
	else
		return memory[0x0000+y*64+flr(x/2)].high
	end
end

function sset(x,y,c)
	x = flr(x)
	y = flr(y)
	if x < 0 or x > 127 or y < 0 or y > 127 then return end
	if x%2 == 0 then
		memory[0x000+y*64+flr(x/2)].low = c
	else
		memory[0x000+y*64+flr(x/2)].high = c
	end
end

function fget(n,f)
	if n == nil then return 0 end
	if n < 0 or n > 127 then return 0 end
	if f ~= nil then
		-- return just that bit as a boolean
		return band(memory[0x3000+flr(n)].byte,shl(1,flr(f))) ~= 0
	end
	return memory[0x3000+flr(n)].byte
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
			memory[0x3000+n].byte = bor(memory[0x3000+n].byte, shl(1,f))
		else
			memory[0x3000+n].byte = band(bnot(memory[0x3000+n].byte, shl(1,f)))
		end
	else
		-- set bitfield to v (number)
		memory[0x3000+n].byte = v
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

function draw_glyph(glyph,dx,dy,c)
	local index = fontchars:find(glyph,nil,true)
	if not index then
		return
	end
	index = index - 1
	for y=0,4 do
		for x=0,3 do
			local r = font_img:getPixel(index*4+x+1,y)
			if r==255 then
				pset_draw(dx+x,dy+y,c)
			end
		end
	end
end

function print_wrap(str,col)
	str = tostring(str)
	for i=1,#str,32 do
		print(str:sub(i,i+31),nil,nil,col)
	end
end

local real_print = print
log = function(...)
	local args = {...}
	for k,v in pairs(args) do
		io.stderr:write(tostring(v))
		io.stderr:write(' ')
	end
	io.stderr:write('\n')
end

function print(str,x,y,col)
	str = tostring(str)
	if col then
		color(col)
	else
		col = __pico_color
	end
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
	for i=1,#str do
		draw_glyph(str:sub(i,i),x+(i-1)*4,y,col)
	end
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
	if type(c) ~= 'number' then
		c = 0
	end
	c = c and flr(c) or 0
	__pico_color = c
end

function cls()
	ffi.fill(memory+0x6000,8192,0)
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
end

function circ(ox,oy,r,col)
	col = col or __pico_color
	color(col)
	ox = flr(ox)
	oy = flr(oy)
	r = flr(r)

	if r == 1 then
		pset_draw(ox-1,oy,col)
		pset_draw(ox+1,oy,col)
		pset_draw(ox,oy-1,col)
		pset_draw(ox,oy+1,col)
		return
	end

	local x = r + 0.5
	local y = 0 + 0.5
	local decisionOver2 = 1 - x

	while y <= x do
		pset(ox+x,oy+y,col)
		pset(ox+y,oy+x,col)
		pset(ox-x,oy+y,col)
		pset(ox-y,oy+x,col)

		pset(ox-x,oy-y,col)
		pset(ox-y,oy-x,col)
		pset(ox+x,oy-y,col)
		pset(ox+y,oy-x,col)

		y = y + 1
		if decisionOver2 <= 0 then
			decisionOver2 = decisionOver2 + 2 * y + 1
		else
			x = x - 1
			decisionOver2 = decisionOver2 + 2 * (y-x) + 1
		end
	end
end

function _plot4points(cx,cy,x,y)
	_horizontal_line(cx - x, cy + y, cx + x)
	if x ~= 0 and y ~= 0 then
		_horizontal_line(cx - x, cy - y, cx + x)
	end
end

function _horizontal_line(x0,y,x1)
	for x=x0,x1 do
		pset(x,y,__pico_color)
	end
end

function circfill(cx,cy,r,col)
	col = col or __pico_color
	color(col)
	cx = flr(cx)
	cy = flr(cy)
	r = flr(r)

	if r == 1 then
		pset_draw(cx,cy,col)
		pset_draw(cx-1,cy,col)
		pset_draw(cx+1,cy,col)
		pset_draw(cx,cy-1,col)
		pset_draw(cx,cy+1,col)
		return
	end
	local x = r
	local y = 0
	local err = -r

	while y <= x do
		local lasty = y
		err = err + y
		y = y + 1
		err = err + y
		_plot4points(cx,cy,x,lasty)
		if err > 0 then
			if x ~= lasty then
				_plot4points(cx,cy,lasty,x)
			end
			err = err - x
			x = x - 1
			err = err - x
		end
	end
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

	if dx == 0 then
		-- simple case draw a vertical line
		if y0 > y1 then y0,y1 = y1,y0 end
		for y=y0,y1 do
			pset(x0,y,col)
		end
	elseif dy == 0 then
		-- simple case draw a horizontal line
		if x0 > x1 then x0,x1 = x1,x0 end
		for x=x0,x1 do
			pset(x,y0,col)
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
				pset(x0,y0,col)
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
				pset(x0,y0,col)
			end
		end
	end
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
	cartname = _cartname
	if load_p8(currentDirectory.._cartname) then
		print('loaded '.._cartname, nil, nil, 6)
	end
end

function ls()
	local files = love.filesystem.getDirectoryItems(currentDirectory)
	print("directory: "..currentDirectory, nil, nil, 12)
	local count = 0
	local col = nil
	love.keyboard.setTextInput(false)
	for _, file in ipairs(files) do
		file = file:lower()
		if love.filesystem.isDirectory(currentDirectory..'/'..file) then
			col = 14
		else
			if file:sub(-3) == '.p8' or file:sub(-7) == '.p8.png' then
				col = 6
			else
				col = 5
			end
		end
		for i=1,#file,32 do
			print(file:sub(i,i+32),nil,nil,col)
			flip_screen()
			count = count + 1
			if count == 20 then
				print("--more--", nil, nil, 12)
				flip_screen()
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

function mkdir(name)
	if name == nil then
		color(6)
		print('mkdir [name]')
	else
		love.filesystem.createDirectory(currentDirectory..name)
	end
end

function hline(y,x0,x1,col)
	for x=x0,x1 do
		pset(x,y,col)
	end
end

function vline(x,y0,y1,col)
	for y=y0,y1 do
		pset(x,y,col)
	end
end

function rect(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)
	hline(y0,x0,x1,col)
	hline(y1,x0,x1,col)
	vline(x0,y0,y1,col)
	vline(x1,y0,y1,col)
end

function rectfill(x0,y0,x1,y1,col)
	col = col or __pico_color
	color(col)
	if y0 > y1 then y0,y1 = y1,y0 end
	if x0 > x1 then x0,x1 = x1,x0 end
	for y=y0,y1 do
		for x=x0,x1 do
			pset(x,y,col)
		end
	end
end

function run()
	-- reset state
	clip()
	camera()
	pal()
	palt()
	color(6)

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
		ok,result = pcall(f)
		if not ok then
			cls()
			print(tostring(result),nil,nil,6)
		else
			log("lua completed")
		end
	end

	if cart._init then
		local ok,result = pcall(cart._init)
		if not ok then
			cls()
			print(tostring(result),nil,nil,6)
			log(tostring(result))
			cart._update = nil
			cart._draw = nil
		end
	end
end

function reload(dest_addr,source_addr,len)
	if type(dest_addr) ~= 'number' then
		dest_addr = 0
		source_addr = 0
		len = 0x4300
	end
	for i=0,len-1 do
		memory[dest_addr+i].byte = rom[source_addr+i].byte
	end
end

function pal(c0,c1,p)
	if type(c0) ~= 'number' then
		for i=0,15 do
			__draw_palette[i] = i
			__display_palette[i] = i
		end
	elseif p == 1 and c1 ~= nil then
		c0 = flr(c0)%16
		c1 = flr(c1)%16
		__display_palette[c0] = c1
	elseif c1 ~= nil then
		c0 = flr(c0)%16
		c1 = flr(c1)%16
		__draw_palette[c0] = c1
	end
end

function palt(c,t)
	if type(c) ~= 'number' then
		__pico_pal_transparent[0] = true
		for i=1,15 do
			__pico_pal_transparent[i] = false
		end
	else
		c = flr(c)%16
		__pico_pal_transparent[c] = t
	end
end

function raw_pset(x,y,c)
	--if x < 0 or x > 127 or y < 0 or y > 127 then
	--	error(string.format('raw_pset %d,%d = %d',x,y,c))
	--	return
	--end
	if x%2 == 0 then
		memory[0x6000+y*64+floor(x/2)].low = c
	else
		memory[0x6000+y*64+floor(x/2)].high = c
	end
end

function spr(n,dx,dy,w,h,flip_x,flip_y)
	-- blit sprite n to screen at x,y
	-- if it's outside of the screen just skip it
	dx = floor(dx - __pico_camera_x)
	dy = floor(dy - __pico_camera_y)
	n = flr(n)
	w = w or 1
	h = h or 1
	if
		dx + w*8-1 < __pico_clip[1] or
		dy + h*8-1 < __pico_clip[2] or
		dx > __pico_clip[3] or
		dy > __pico_clip[4]
	then
		return
	end
	local minx = max(dx,__pico_clip[1])
	local maxx = min(dx+w*8-1,__pico_clip[3])
	local miny = max(dy,__pico_clip[2])
	local maxy = min(dy+h*8-1,__pico_clip[4])
	local sx2
	local sx
	local sy = flr(n/16)*8 + (flip_y and h*8-1 or 0) + (miny - dy) * (flip_y and -1 or 1)
	local srow
	local sc
	for y=miny,maxy do
		srow = 0x0000+sy*64
		sx = (n%16)*8 + (flip_x and w*8-1 or 0) + (minx - dx) * (flip_x and -1 or 1)
		for x=minx,maxx do
			sx2 = floor(sx/2)
			sc = map_color(sx%2 == 0 and
				memory[srow+sx2].low or
				memory[srow+sx2].high)
			if sc ~= nil then
				raw_pset(
					x,
					y,
					sc)
			end
			sx = sx + (flip_x and -1 or 1)
		end
		sy = sy + (flip_y and -1 or 1)
	end
end

function map_color(x)
	-- return the color from the palette, or nil if transparent
	x = floor(x) or 0
	if __pico_pal_transparent[x] then return nil end
	return __draw_palette[x%16]
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

	for x=0,dw-1 do
		local sxx = sx + (flip_x and dw-x-1 or x)*(sw/dw)
		for y=0,dh-1 do
			local syy = sy + (flip_y and dh-y-1 or y)*(sh/dh)
			pset_draw(dx+x,dy+y,sget(sxx,syy),true)
		end
	end
end

function add(a,v)
	if type(a) ~= 'table' then
		warning('add to non-table')
		return
	end
	table.insert(a,v)
end

function del(a,dv)
	if type(a) ~= 'table' then
		warning('del from non-table')
		return
	end
	for i,v in ipairs(a) do
		if v==dv then
			table.remove(a,i)
		end
	end
end

function warning(msg)
	log(debug.traceback("WARNING: "..msg,3))
end

local olderror = error
function error(msg)
	log(debug.traceback("ERROR: "..msg,3))
	olderror(msg)
end

function foreach(a,f)
	if type(a) ~= 'table' then
		warning("foreach got a non-table value")
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
	a = a or {}
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
		[4] = {'z','n','c'},
		[5] = {'x','m','v'},
	},
	[1] = {
		[0] = {'s'},
		[1] = {'f'},
		[2] = {'e'},
		[3] = {'d'},
		[4] = {'tab','lshift'},
		[5] = {'q','a'},
	},
}

function btn(i,p)
	if type(i) == 'number' then
		p = p or 0
		if p > 1 then return false end
		if __keymap[p][i] then
			return __pico_keypressed[p][i] ~= nil
		end
		return false
	else
		-- return bitfield of buttons
		local bitfield = 0
		for i=0,5 do
			if __pico_keypressed[0][i] then
				bitfield = bitfield + bit.lshift(1,i)
			end
		end
		for i=6,13 do
			if __pico_keypressed[1][i] then
				bitfield = bitfield + bit.lshift(1,i)
			end
		end
		return bitfield
	end
end

function btnp(i,p)
	if type(i) == 'number' then
		p = p or 0
		if p > 1 then return false end
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
				bitfield = bitfield + bit.lshift(1,i)
			end
		end
		for i=6,13 do
			if __pico_keypressed[1][i] then
				bitfield = bitfield + bit.lshift(1,i)
			end
		end
		return bitfield
	end
end

function mget(x,y)
	if x == nil or y == nil then return 0 end
	x = flr(x)
	y = flr(y)
	if y > 63 or x > 127 or x < 0 or y < 0 then return 0 end
	if y > 31 then
		return map_memory[(y-32)*128+x].byte
	else
		return memory[0x2000+y*128+x].byte
	end
end

function mset(x,y,v)
	x = flr(x)
	y = flr(y)
	if x >= 0 and x < 127 and y >= 0 and y < 63 then
		if y > 31 then
			map_memory[(y-32)*128+x].byte = v
		else
			memory[0x2000+y*128+x].byte = v
		end
	end
end

function map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
	cel_x = cel_x or 0
	cel_y = cel_y or 0
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
					local v = mget(cel_x+x,cel_y+y)
					if v > 0 then
						if bitmask == nil or bitmask == 0 then
							spr(v,sx+x*8,sy+y*8)
						else
							if band(fget(v),bitmask) ~= 0 then
								spr(v,sx+x*8,sy+y*8)
							end
						end
					end
				end
			end
		end
	end
end

function memset(dest_addr,val,len)
	if len < 1 then return end
	if dest_addr < 0 or dest_addr + len-1 >= 0x8000 then
		warning(string.format("memset, accessing outside bounds: 0x%x + %d = 0x%x", dest_addr, len, dest_addr + len))
		return
	end
	ffi.fill(memory+dest_addr,len-1,val)
end

function memcpy(dest_addr,source_addr,len)
	if len < 1 then return end
	if dest_addr < 0 or source_addr < 0 or dest_addr + len-1 >= 0x8000 or source_addr + len-1 >= 0x8000 then
		warning(string.format("memcpy, accessing outside bounds: 0x%x + %d = 0x%x", dest_addr, len, dest_addr + len))
	end
	C.memmove(memory[dest_addr],memory[source_addr],len-1)
end

function peek(addr)
	if addr < 0 or addr >= 0x8000 then
		warning(string.format('peek(0x%x)',addr))
		return
	end
	return memory[addr].byte
end

function poke(addr, val)
	if addr < 0 or addr >= 0x8000 then
		warning(string.format('poke(0x%x)',addr))
		return
	end
	memory[addr].byte = val
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

flr = function(x)
	if x ~= x then return 0 end
	return math.floor(x)
end
ceil = function(x) return -flr(-x) end
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

function cartdata(id)
	local datafile
	if id:match("[%W_]") then
		__cartdata_id = id
		datafile = love.filesystem.newFile(string.format("%s.cartdata",id))
		datafile:open('r')
		local cartdata, bytesread = datafile:read(256)
		if cartdata then
			datafile:close()
			__cartdata = {}
			for i=0,63 do
				__cartdata[i] = bytes_to_number(cartdata:sub(i*4,i*4+3))
			end
		end

		return cartdata ~= nil
	else
		__cartdata_id = nil
		error(string.format('invalid cartdata id "%s", alphanumeric and _ only',id))
	end
end

function dget(index)
	return __cartdata[index]
end

function dset(index,value)
	if __cartdata_id then
		__cartdata[index] = (type(value) == 'number' and value) or 0
		save_cartdata()
	end
end

function bytes_to_number(bytes)
	-- takes a string of 4 bytes and returns a number AB.CD
	if type(bytes) ~= 'string' or #bytes < 4 then return 0 end
	local a = bit.lshift(string.byte(string.sub(bytes,1,1)),24)
	local b = bit.lshift(string.byte(string.sub(bytes,2,2)),16)
	local c = bit.lshift(string.byte(string.sub(bytes,3,3)),8)
	local d = string.byte(string.sub(bytes,4,4))
	local n = (a+b+c+d) / 65536
	return n
end

function number_to_bytes(fixed)
	-- takes a number and returns 4 bytes. AB.CD
	if type(fixed) ~= 'number' then fixed = 0 end
	local i = math.floor(fixed * 65536)
	local a,b = bit.rshift(bit.band(0xff000000,i),24), bit.rshift(bit.band(0x00ff0000,i),16)
	local c,d = bit.rshift(bit.band(0x0000ff00,i),8),  bit.band(0x000000ff,i)
	log(a,b,c,d)
	return table.concat({ string.char(a), string.char(b), string.char(c), string.char(d) })
end

function save_cartdata()
	local file = love.filesystem.newFile(string.format("%s.cartdata",__cartdata_id))
	if file:open('w') then
		-- write data as bytes, 4 bytes per number
		for i=0,63 do
			file:write(number_to_bytes(__cartdata_id[i]))
		end
		file:close()
	end
end

function shutdown()
	love.event.quit()
end

function stat(x)
	return 0
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

function lua_comment_remover(lua)
	-- TODO: handle multiline comments
	local comment = false
	local string = false
	local escapenext = false
	local output = {}
	for i=1,#lua do
		local char = lua:sub(i,i)
		if string == false then
			if not comment then
				if char == '-' then
					local nextchar = lua:sub(i+1,i+1)
					if nextchar == '-' then
						comment = true
					end
				elseif char == '"' then
					string = '"'
				elseif char == '\'' then
					string = '\''
				elseif char == '[' then
					local nextchar = lua:sub(i+1,i+1)
					if nextchar == '[' then
						string = '['
					end
				end
			elseif comment then
				if comment == 'multiline' then
					if char == ']' then
						local nextchar = lua:sub(i+1,i+1)
						if nextchar == ']' then
							comment = false
						end
					end
				elseif comment == true then
					if char == '\n' then
						comment = false
					elseif char == '[' then
						local nextchar = lua:sub(i+1,i+1)
						if nextchar == '[' then
							comment = 'multiline'
						end
					end
				end
			end
		elseif string and escapenext ~= i then
			if string == '"' and char == '"' then
				string = false
			elseif string == '\'' and char == '\'' then
				string = false
			elseif string == '[' and char == ']' then
				local nextchar = lua:sub(i+1,i+1)
				if nextchar == ']' then
					string = false
				end
			elseif char == '\\' then
				escapenext = i+1
			end
		end
		if not comment then
			table.insert(output,char)
		end
	end
	return table.concat(output)
end
