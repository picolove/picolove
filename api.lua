local api = {}

function api.flip()
	flip_screen()
	love.timer.sleep(frametime)
end

return api
