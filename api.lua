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

return api
