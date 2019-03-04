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

return api
