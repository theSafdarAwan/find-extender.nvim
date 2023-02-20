local M = {}
-- TODO: add the t(till) movement along f and F
function M.setup(config)
	local default_config = {
		find_extender_find_chars_length = 2,
		find_extender_find_timeout = false,
	}

	require("find-extender.finder").finder(config or default_config)
end

return M
