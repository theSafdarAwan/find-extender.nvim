local M = {}
function M.setup(config)
	local default_config = {
		find_extender_find_chars_length = 2,
		find_extender_find_timeout = false,
	}

	require("find-extender.finder").finder(config or default_config)
end

return M
