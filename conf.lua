scale = 4
xpadding = 8.5
ypadding = 3.5
__pico_resolution = {128, 128}

function love.conf(t)
	t.console = true

	t.identity = "picolove"
	t.version = "0.10.2"

	t.window.title = "picolove 0.1 - (love " .. t.version .. ")"
	t.window.width = __pico_resolution[1] * scale + xpadding * scale * 2
	t.window.height = __pico_resolution[2] * scale + ypadding * scale * 2
	t.window.resizable = true
end
