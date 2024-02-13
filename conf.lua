__picolove_version = "0.1.0"

scale = 4
xpadding = 8.5
ypadding = 3.5
__pico_resolution = { 128, 128 }

function love.conf(t)
	t.console = true

	t.identity = "picolove"

	__picolove_love_version = t.version

	-- 0.9.x  is wip
	-- 0.10.x is default
	-- 11.x   is wip
	if
		t.version ~= "0.9.0"
		and t.version ~= "0.9.1"
		and t.version ~= "0.9.2"
		and t.version ~= "0.10.0"
		and t.version ~= "0.10.1"
		and t.version ~= "0.10.2"
		and t.version ~= "11.0"
		and t.version ~= "11.1"
		and t.version ~= "11.2"
		and t.version ~= "11.3"
		and t.version ~= "11.4"
		and t.version ~= "11.5"
	then
		-- show default version if no match
		t.version = "0.10.2"
	end

	t.window.title = "PICOLÖVE"
	t.window.icon = "icon.png"
	t.window.width = __pico_resolution[1] * scale + xpadding * scale * 2
	t.window.height = __pico_resolution[2] * scale + ypadding * scale * 2
	t.window.resizable = true
end
