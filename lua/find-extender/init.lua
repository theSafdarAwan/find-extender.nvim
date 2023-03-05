local M = {}
function M.setup(user_config)
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
				["y"] = { "f", "F", "t", "T" },
				["d"] = { "f", "F", "t", "T" },
				["c"] = { "f", "F", "t", "T" },
			},
		},
		highlight_on_yank = { enable = true, timeout = 40, hl_group = "IncSearch" },
	}
	-- merge the user config and the default config
	local config = vim.tbl_extend("force", default_config, user_config or {})

	-- merge the user keymaps and default keymaps
	config.keymaps = vim.tbl_extend("force", default_config.keymaps, config.keymaps or {})

	local text_manipulation_keys = config.keymaps.text_manipulation
	-- merge the user text_manipulation_keys and default text_manipulation_keys
	text_manipulation_keys =
		vim.tbl_extend("force", default_config.keymaps.text_manipulation, text_manipulation_keys or {})

	require("find-extender.finder").finder(config)
end

return M
