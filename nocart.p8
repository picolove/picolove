pico-8 cartridge
version 33
__lua__
-- pico-8 compatibility
_allow_pause = _allow_pause or function() end
_allow_shutdown = _allow_shutdown or function() end
_getpicoloveversion = _getpicoloveversion or function() return "" end
_getcursorx =  _getcursorx or function() return peek(0x5f26) end
_getcursory =  _getcursory or function() return peek(0x5f27) - 6 end

function _init()
	_allow_pause(false)
	_allow_shutdown(true)

	-- TODO: move all variables into hidden table to prevent overwriting via commandline
	pencolor = 6
	tc = 0
	isctrldown = false
	linebuffer = ""
	line = 0
	commandhistory = {}
	commandindex = 0
	commandbuffer = ""
	cursorx = 0

	-- enable keyboard
	poke(0x5f2d, 1)

	cls()
	spr(0, 1, -3, 6, 2)
	spr(22, 43, 1)

	color(6)
	print("")
	print("")
	print("")
	print("picolove " .. _getpicoloveversion())
	print("a pico-8 clone made with love <3")
	print("")
	print("type help for help")
	print("")

	-- show umlauts on "picolove" text
	print(".", 19, 12)
	print(".", 21, 12)

	-- optional: show umlauts on "made with love" text
	--print(".", 103, 18)
	--print(".", 105, 18)
end

function _update()
	tc += 1
end

function _keydown(key)
	if key == "backspace" then
		-- delete carret
		rectfill((#linebuffer + 2) * 4, _getcursory(), (#linebuffer + 2) * 4 + 3, _getcursory() + 4, 0)

		cursorx -= 1
		local delchars = 1
		if cursorx < 0 then
			cursorx = 0
			delchars = 0
		end

		local startbuffer = linebuffer:sub(1, cursorx)
		local endbuffer = linebuffer:sub(cursorx + 1 + delchars)
		linebuffer = startbuffer .. endbuffer

	elseif key == "delete" then
		-- delete carret
		rectfill((#linebuffer + 2) * 4, _getcursory(), (#linebuffer + 2) * 4 + 3, _getcursory() + 4, 0)

		local startbuffer = linebuffer:sub(1, cursorx)
		local endbuffer = linebuffer:sub(cursorx + 2)
		linebuffer = startbuffer .. endbuffer

	elseif key == "home" then
		cursorx = 0

	elseif key == "end" then
		cursorx = #linebuffer

	elseif key == "left" then
		cursorx -= 1
		if cursorx < 0 then
			cursorx = 0
		end

	elseif key == "right" then
		cursorx += 1
		if cursorx > #linebuffer then
			cursorx = #linebuffer
		end

	elseif key == "up" then
		-- delete text and carret
		rectfill(0, _getcursory(), (#linebuffer + 2) * 4 + 3, _getcursory() + 4, 0)

		if commandindex == #commandhistory + 1 then
			commandbuffer = linebuffer
		end

		commandindex -= 1
		if commandindex < 1 then
			commandindex = 1
		end

		linebuffer = commandhistory[commandindex] or linebuffer
		cursorx = #linebuffer

	elseif key == "down" then
		-- delete text and carret
		rectfill(0, _getcursory(), (#linebuffer + 2) * 4 + 3, _getcursory() + 4, 0)

		if commandindex == #commandhistory + 1 then
			commandbuffer = linebuffer
		end

		local newbuffer
		commandindex += 1
		if commandindex >= #commandhistory + 1 then
			commandindex = #commandhistory + 1
			newbuffer = commandbuffer
		else
			newbuffer = commandhistory[commandindex]
		end

		linebuffer = newbuffer or linebuffer
		cursorx = #linebuffer

	elseif key == "lctrl" then
		isctrldown = true

	elseif key == "c" and isctrldown then
		-- NOTE: feature not part of pico
		-- delete text and carret
		rectfill(0, _getcursory(), (#linebuffer + 2) * 4 + 3, _getcursory() + 4, 0)
		-- render command
		print("> " .. linebuffer, 7)
		linebuffer = ""
		cursorx = 0

	elseif key == "v" and isctrldown then
		local startbuffer = linebuffer:sub(1, cursorx)
		local endbuffer = linebuffer:sub(cursorx + 1)
		linebuffer = startbuffer .. stat(4) .. endbuffer
		cursorx = cursorx + #stat(4)

	elseif key == "tab" then
		-- NOTE: we display colors for file types (pico doesn't)
		-- NOTE: we use blue colors for "3 files" text (pico uses light red)
		-- NOTE: split at first space (pico does last space -> bug)
		local newbuffer = linebuffer
		local pos = linebuffer:find(" ", 1, true)
		if pos ~= nil and pos < #linebuffer then
			rectfill(0, _getcursory(), (#linebuffer + 2) * 4 + 3, _getcursory() + 4, 0)
			local command = linebuffer:sub(1, pos - 1)
			local file = linebuffer:sub(pos + 1)
			linebuffer = _completecommand(command, file)
			cursorx = #linebuffer
		end

	elseif key == "return" or key == "kpenter" then
		-- add to history
		if linebuffer != commandhistory[#commandhistory] then
			add(commandhistory, linebuffer)
		end
		commandindex = #commandhistory + 1

		-- delete text and carret
		rectfill(0, _getcursory(), (#linebuffer + 2) * 4 + 3, _getcursory() + 4, 0)
		-- render command
		print("> " .. linebuffer, 7)
		if linebuffer == "dir" or linebuffer == "ls"
			or (#linebuffer > 4 and linebuffer:sub(1, 4) == "dir ")
			or (#linebuffer > 3 and linebuffer:sub(1, 3) == "ls ") then
			ls()

		elseif linebuffer:sub(1, 5) == "load " then
			load(linebuffer:sub(6, #linebuffer))

		elseif linebuffer == "load" then
			load()

		elseif linebuffer == "cls" or
      linebuffer:sub(1, 4) == "cls " and #linebuffer > 4  then
			line = -1
			cls(linebuffer:sub(5):gsub('"%s*(%d+)%s*"', "%1"))

		elseif linebuffer == "help" or
			linebuffer:sub(1, 5) == "help " and #linebuffer > 5  then
			help()

		elseif linebuffer == "shutdown" or linebuffer == ":q" or
			linebuffer == "exit" or linebuffer == "quit" then
			shutdown()

		elseif linebuffer == "folder" then
			folder()
		elseif linebuffer:sub(1, 7) == "folder " and #linebuffer > 7 then
			folder(linebuffer:sub(8))

		elseif linebuffer == "run" then
			run()

		elseif linebuffer == "cd" or linebuffer:sub(1, 3) == "cd " then
			cd(linebuffer:sub(4))

		elseif linebuffer == "mkdir" then
			mkdir()

		elseif linebuffer:sub(1, 6) == "mkdir " and #linebuffer > 6 then
			mkdir(linebuffer:sub(7))

		elseif #linebuffer == 0 then
			-- do nothing

		elseif linebuffer == "resume" then
			-- delete text and carret
			rectfill(0, _getcursory(), 128, _getcursory() + 5, 0)
			-- render text
			print("nothing to resume", 6)
			-- TODO

		elseif linebuffer == "reboot" then
			reboot()

		elseif linebuffer:sub(1, 5) == "save " then
			-- TODO

		else
			color(pencolor)
			_call(linebuffer)
			pencolor = peek(0x5f25) or pencolor
		end

		linebuffer = ""
		cursorx = 0
	elseif key == "escape" then
		load("editor.p8")
		run()
	end
end

function _keyup(key)
	if key == "lctrl" then
		isctrldown = false
	end
end

function _textinput(text)
	local startbuffer = linebuffer:sub(1, cursorx)
	local endbuffer = linebuffer:sub(cursorx + 1, #linebuffer)
	linebuffer = startbuffer .. text .. endbuffer

	if #text then
		cursorx += #text
	end
end

function _touchup()
	-- hide/show keyboard
	poke(0x5f2d, peek(0x5f2d))
end

function _draw()
	-- stay on screen
	if _getcursory() > 121 then
		print("") -- scroll text
		cursor(0, 120)
	end
	-- delete text and carret
	rectfill(0, _getcursory(), (#linebuffer + 2) * 4 + 4, _getcursory() + 5, 0)
	-- render text
	print("> " .. linebuffer, 0, _getcursory(), 7)
	-- render carret
	if tc % 16 < 8 then
		rectfill((cursorx + 2) * 4, _getcursory(), (cursorx + 2) * 4 + 3, _getcursory() + 4, 8)
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000307777777777770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000307777777777770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000307777777777770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000307777777777770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000307779577777770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000307775577777770300000000000000000000000000000000
00000000000000000000000000707000000000000000000000000000000000000000000000000000307750577777770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000307750557777770300000000000000000000000000000000
07777077007777007777077000777007707700777000000000000000000000000000000000000000307700007777770300000000000000000000000000000000
77077077077000077077077007707707707707707700000008090000000000000000000000000000307750557777770300000000000000000000000000000000
777700770770000770770770077077077077077777000000e7f7a000000000000000000000000000307950555777770300000000000000000000000000000000
7700007707700007707707700770770077700770000000000d7b0000000000000000000000000000307000000777770300000000000000000000000000000000
77000077077777077770077770777000777000777000000000c00000000000000000000000000000305550555977770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000305550555577770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000300000000007770300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000305550555555550300000000000000000000000000000000
