local M = {}
function M.setup(user_config)
	print(vim.inspect(user_config))
	local default_config = {
		enable = true,
		chars_length = 2,
		timeout = false,
		start_timeout_after_chars = 1,
		keymaps = {
			modes = "nv",
			till = { "T", "t" },
			find = { "F", "f" },
			text_manipulation = {
				yank = true,
				delete = true,
				change = true,
			},
		},
		highlight_on_yank = { enable = true, timeout = 40, hl_group = "IncSearch" },
	}
	-- merge the user config and the default config
	local config = vim.tbl_extend("force", default_config, user_config or {})
	print(vim.inspect(config))

	-- merge the user keymaps and default keymaps
	config.keymaps = vim.tbl_extend("force", default_config.keymaps, config.keymaps)

	require("find-extender.finder").finder(config)
end

return M
