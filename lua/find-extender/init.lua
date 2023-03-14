--- setup module.
local M = {}
--- loads plguin
---@param user_config table|nil user specified configuration for the plugin.
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
				yank = { "f", "F", "t", "T" },
				delete = { "f", "F", "t", "T" },
				change = { "f", "F", "t", "T" },
			},
		},
		highlight_on_yank = { enable = true, timeout = 40, hl_group = "IncSearch" },
	}
	-- merge the user config and the default config
	local config = vim.tbl_deep_extend("force", default_config, user_config or {})

	require("find-extender.finder").finder(config)
end

return M
