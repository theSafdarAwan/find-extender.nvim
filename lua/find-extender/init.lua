local M = {}
function M.setup(user_config)
	local default_config = {
		chars_length = 2,
		timeout = false,
		start_timeout_after_chars = 2,
	}
	-- merge the user config and the default config
	local config = vim.tbl_extend("force", default_config, user_config)

	require("find-extender.finder").finder(config)
end

return M
