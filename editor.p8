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
local isshifdown = false

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
	carety = max(min(carety, #content), 1)
	caretx = max(min(caretx, #content[carety]+1), 1)
	caretbig = caretx == 1 or caretx <= #content[carety]
end

function normalmode._keydown(key)
	printh("nm-key: '" .. key .. "'")

	if key == "h" then
		if caretx == 1 and carety > 1 then
			carety -= 1
			caretx = #content[carety] + 1
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
		if caretx == #content[carety] + 1 and carety < #content then
			carety += 1
			caretx = 1
		else
			caretx += 1
		end
		updatecaret()
	elseif key == "escape" then
		returntomain()
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
	elseif key == "o" then
		carety += 1
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
	printh("nm-text: '" .. text .. "'")

	if text == ":" then
		commandline = ":"
		setmode(commandmode)
	end

	if text == "0" then
		caretx = 1
		updatecaret()
	elseif text == "$" then -- TODO: fix input filtering
		caretx = #content[carety]+1
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
	if tc % 16 < 8 then
		if caretbig then
			rectfill(caretx*4-4, carety*6 + 2, caretx*4, carety*6 + 2 + 5, 8)
		else
			rectfill(caretx*4-4, carety*6 + 3, caretx*4, carety*6 + 3 + 4, 8)
		end
	end
end


function inputmode._keydown(key)
	printh("im-key: '" .. key .. "'")

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
	printh("im-text: '" .. text .. "'")

	content[carety] = content[carety]:sub(1, caretx - 1) .. text .. content[carety]:sub(caretx)
	caretx += 1
	updatecaret()
end
function inputmode._drawstatusline()
	print("-- insert --", 1, 122, 2)
end
function inputmode._drawcaret()
	if tc % 16 < 8 then
		if caretbig then
			rectfill(caretx*4-4, carety*6 + 2, caretx*4-4, carety*6 + 2 + 5, 8)
		else
			rectfill(caretx*4-4, carety*6 + 3, caretx*4-4, carety*6 + 3 + 4, 8)
		end
	end
end


function commandmode._keydown(key)
	printh("cm-key: '" .. key .. "'")
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
	printh("cm-text: '" .. text .. "'")
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
	if tc % 16 < 8 then
		if commandlinecaret == #commandline then
			rectfill(commandlinecaret * 4, 121, commandlinecaret * 4 + 4, 126, 14)
		else
			rectfill(commandlinecaret * 4, 121, commandlinecaret * 4, 126, 14)
		end
	end
end


function _keydown(key)
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
