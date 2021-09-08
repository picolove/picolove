pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
local content = {
	"todo: editor",
	"",
	"press esc to quit"
}

local caretx = 1
local carety = 1
local caretbig = false

local normalmode = {}
local inputmode = {}
local commandmode = {}

local mode = normalmode
local nextmode = mode

local commandline = ""
local commandlinecaret = 1

local isctrldown = false
local isshiftdown = false

local prevkey = nil

function resetblink()
	tc = 0
end

function _init()
	tc = 0
	-- enable keyboard
	poke(0x5f2d, 1)
end

function setmode(mode)
	nextmode = mode
end
function updatemode()
	mode = nextmode
end

function _update()
	tc += 1
end

function returntomain()
	load("nocart.p8")
	run()
end

function updatecaret()
	local posaftertext = 1
	if nextmode ~= inputmode then
		posaftertext = 0
	end

	carety = max(min(carety, #content), 1)
	caretx = max(min(caretx, #content[carety] + posaftertext), 1)
	caretbig = caretx == 1 or caretx <= #content[carety]
end

function normalmode._keydown(key)
	if prevkey ~= nil then
		if key == "lshift" or key == "rshift" or
			key == "lctrl" or key == "rctrl" or
			key == "lalt" or key == "ralt" then
			return
		elseif key >= "0" and key <= "9" then
			prevkey = prevkey .. key
		elseif prevkey == "escape" and key == "escape" then
			returntomain()
		elseif prevkey == "d" and key == "d" then
			deli(content, carety)
			if #content == 0 then
				content[1] = ""
			end
			caretx = 1
			updatecaret()
		elseif prevkey == "d" and key == "w" then
			local delstartpos = caretx
			local delendpos = nil

			local foundpos = content[carety]:find(" ", caretx)

			if foundpos ~= nil then
				delendpos = foundpos
			elseif #content[carety] == 0 and #content == 1 then
				caretx = 1
				carety = 1
				content[1] = ""
				delstartpos = nil
			elseif #content[carety] == 0 then
				caretx = 1
				deli(content, carety)
				delstartpos = nil
			else
				delendpos = #content[carety] + 1
			end

			if delstartpos ~= nil then
				if delendpos ~= nil then
					content[carety] = content[carety]:sub(1, delstartpos - 1) .. "" .. content[carety]:sub(delendpos + 1)
				else
					content[carety] = content[carety]:sub(1, delstartpos - 1)
				end
			end
			updatecaret()
		elseif prevkey == "g" and key == "g" then
			carety = 1
			caretx = 1
			updatecaret()
		elseif isshiftdown and key == "g" then
			local num = tonum(prevkey)
			if num ~= nil then
				carety = num
				caretx = 1
				updatecaret()
			end
		end
		prevkey = nil

	elseif key >= "1" and key <= "9" then
		prevkey = key
	elseif key == "h" then
		if caretx == 1 and carety > 1 then
			carety -= 1
			caretx = #content[carety]
		else
			caretx -= 1
		end
		updatecaret()
	elseif key == "j" then
		carety += 1
		updatecaret()
	elseif key == "k" then
		carety -= 1
		updatecaret()
	elseif key == "l" then
		if caretx == #content[carety] and carety < #content then
			carety += 1
			caretx = 1
		else
			caretx += 1
		end
		updatecaret()
	elseif key == "d" then
		prevkey = key
	elseif key == "w" then
		local pos, posend = content[carety]:find(" %S", caretx)
		if pos ~= nil then
			caretx = posend
		elseif carety < #content then
			carety += 1
			caretx = 1
		else
			caretx = #content[carety]
		end
		updatecaret()
	elseif key == "e" then
		local pos, posend = content[carety]:find("%S ", caretx + 1)
		if pos ~= nil then
			caretx = pos
		elseif caretx >= #content[carety] and carety < #content then
			carety += 1
			caretx = 1
		else
			caretx = #content[carety]
		end
		updatecaret()
	elseif key == "b" then
		if caretx == 1 and carety > 1 then
			carety -= 1
			caretx = #content[carety]
		end
		local pos, posend = content[carety]:reverse():find("%S ", #content[carety] - caretx + 2)
		if pos == nil then
			caretx = 1
		else
			caretx = #content[carety] - posend + 2
		end
		updatecaret()
	elseif key == "escape" then
		prevkey = key
	elseif key == "a" then
		if isshiftdown then
			caretx = #content[carety] + 1
		else
			caretx += 1
		end
		setmode(inputmode)
		updatecaret()
	elseif key == "i" then
		setmode(inputmode)
	elseif isshiftdown and key == "g" then
		carety = #content
		caretx = 1
	elseif key == "g" then
		prevkey = key
	elseif key == "o" then
		if not isshiftdown then
			carety += 1
		end
		add(content, "", carety)
		setmode(inputmode)
		updatecaret()
	elseif key == "x" and caretbig then
		if caretbig then
			if carety < #content and #content[carety] == 0 then
				deli(content, carety)
			else
				content[carety] = content[carety]:sub(1, caretx - 1) .. content[carety]:sub(caretx + 1)
			end
		end
		updatecaret()
	end
end
function normalmode._keyup(key)
end
function normalmode._textinput(text)
	if text == ":" then
		commandline = ":"
		setmode(commandmode)
	end

	if text == "0" then
		caretx = 1
		updatecaret()
	elseif text == "$" then -- TODO: fix input filtering
		caretx = #content[carety]
		updatecaret()
	end
end
function normalmode._drawstatusline()
	print("line " .. carety .. "/" .. #content, 1, 122, 2)
	print("        6/8192  ", 65, 122, 2)
	print("-", 123, 120, 6)
	print("-", 123, 122, 2)
	print("-", 123, 124, 2)
end
function normalmode._drawcaret()
	if nextmode == inputmode then
		nextmode._drawcaret()
	elseif tc % 16 < 8 or tc < 16 then
		if caretbig then
			rectfill(caretx*4-4, carety*6 + 2, caretx*4, carety*6 + 2 + 5, 8)
		else
			rectfill(caretx*4-4, carety*6 + 3, caretx*4, carety*6 + 3 + 4, 8)
		end
	end
end


function inputmode._keydown(key)
	if key == "escape" or (isctrldown and key == "c") then
		caretx -= 1
		setmode(normalmode)
		updatecaret()
	elseif key == "backspace" then
		if caretx > 1 then
			content[carety] = content[carety]:sub(1, caretx - 2) .. content[carety]:sub(caretx)
			caretx -= 1
			updatecaret()
		end
	elseif key == "return" then
		add(content, content[carety]:sub(caretx), carety + 1)
		content[carety] = content[carety]:sub(1, caretx - 1)
		carety += 1
		caretx = 1
		updatecaret()
	end
end
function inputmode._keyup(key)
end
function inputmode._textinput(text)
	content[carety] = content[carety]:sub(1, caretx - 1) .. text .. content[carety]:sub(caretx)
	caretx += 1
	updatecaret()
end
function inputmode._drawstatusline()
	print("-- insert --", 1, 122, 2)
end
function inputmode._drawcaret()
	if nextmode == normalmode then
		nextmode._drawcaret()
	elseif tc % 16 < 8 or tc < 16 then
		if caretbig then
			rectfill(caretx*4-4, carety*6 + 2, caretx*4-4, carety*6 + 2 + 5, 8)
		else
			rectfill(caretx*4-4, carety*6 + 3, caretx*4-4, carety*6 + 3 + 4, 8)
		end
	end
end


function commandmode._keydown(key)
	if key == "escape" then
		commandlinecaret = 1
		setmode(normalmode)
	elseif key == "return" then
		commandlinecaret = 1
		if commandline == ":q" then
			returntomain()
		else
			setmode(normalmode)
		end
	elseif key == "delete" then
			commandline = commandline:sub(1, commandlinecaret) .. commandline:sub(commandlinecaret + 2)
	elseif key == "backspace" then
		if commandlinecaret > 1 then
			commandline = commandline:sub(1, commandlinecaret - 1) .. commandline:sub(commandlinecaret + 1)
			commandlinecaret -= 1
			commandlinecaret = max(commandlinecaret, 1)
		elseif #commandline <= 1 then
			setmode(normalmode)
		end
	elseif key == "left" then
		commandlinecaret -= 1
		commandlinecaret = max(commandlinecaret, 1)
	elseif key == "right" then
		commandlinecaret += 1
		commandlinecaret = min(commandlinecaret, #commandline)
	end
end
function commandmode._keyup(key)
end
function commandmode._textinput(text)
	commandline = commandline:sub(1,commandlinecaret) .. text .. commandline:sub(commandlinecaret + 1)
	commandlinecaret += 1
	commandlinecaret = min(commandlinecaret, #commandline)
end
function commandmode._drawstatusline()
	commandmode._drawcaretextra()
	print(commandline, 1, 122, 2)
end
function commandmode._drawcaret()
	--no op
end
function commandmode._drawcaretextra()
	if tc % 16 < 8 or tc < 16 then
		if commandlinecaret == #commandline then
			rectfill(commandlinecaret * 4, 121, commandlinecaret * 4 + 4, 126, 14)
		else
			rectfill(commandlinecaret * 4, 121, commandlinecaret * 4, 126, 14)
		end
	end
end


function _keydown(key)
	resetblink()
	updatemode()
	if key == "lctrl" or key == "rctrl" then
		isctrldown = true
	elseif key == "lshift" or key == "rshift" then
		isshiftdown = true
	end
	mode._keydown(key)
end

function _keyup(key)
	updatemode()
	if key == "lctrl" or key == "rctrl" then
		isctrldown = false
	elseif key == "lshift" or key == "rshift" then
		isshiftdown = false
	end
	mode._keyup(key)
end

function _textinput(text)
	mode._textinput(text)
end

function _touchup()
end

function _draw()
	-- render background
	cls(1)
	rectfill(0, 0, 128, 7, 8)

	mode._drawcaret()

	-- render dummy content
	color(6)
	for i,v in ipairs(content) do
		print(v, 1, 3 + i*6)
	end

	-- render toolbar
	rectfill(3, 1, 10, 7, 14)
	print("+", 2, -1, 8)
	print("0", 6, 2, 8)
	print("+", 15, 2, 14)

	rectfill(0, 121, 128, 128, 8)
	mode._drawstatusline()
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
