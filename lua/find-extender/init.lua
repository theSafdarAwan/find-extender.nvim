--- setup module.
local M = {}

-- TODO: add strategy when first input char is a character and expose an option
-- for user to decide what to do
-- TODO: add strategy for cursor movement when searching backwards

--- default config
local DEFAULT_CONFIG = {
	---@field chars_length number how much characters to get input for finding.
	chars_length = 2,
	---@field highlight_matches table controls the highlighting of the pattern matches
	highlight_matches = {
		---@field min_matches number minimum matches after which the matches should
		-- be highlighted.
		min_matches = 2,
		-- TODO: add highlights
	},
	---@field timeout number|boolean timeout before we find the characters input
	--- at our disposal before the `chars_length` completes.
	timeout = false,
	---@field start_timeout_after_chars number how much characters should be
	--- available before timeout triggers the character finder.
	start_timeout_after_chars = 1,
	---@field keymaps table information for keymaps.
	keymaps = {
		---@field finding table finding keys config
		finding = {
			---@field modes string modes in which the finding keys should be added.
			modes = "nv",
			---@field till table table of till keys backward and forward both by default.
			till = { "T", "t" },
			---@field find table table of find keys backward and forward both by default.
			find = { "F", "f" },
		},
		---@field text_manipulation table information about text manipulation keys including yank/delete/change.
		text_manipulation = {
			---@field modes string modes in which the text_manipulation keys should be added. By default only in normal mode.
			modes = "n",
			---@field yank table keys related to finding yanking area of text in a line.
			yank = { "f", "F", "t", "T" },
			---@field delete table keys related to finding deleting area of text in a line.
			delete = { "f", "F", "t", "T" },
			---@field change table keys related to finding changing area of text in a line.
			change = { "f", "F", "t", "T" },
		},
	},
	---@field highlight_on_yank table highlight the yanked area
	highlight_on_yank = {
		---@field enable boolean to enable the highlight_on_yank
		enable = true,
		---@field timeout number timeout for the yank highlight
		timeout = 40,
		---@field hl_group string highlight groups for highlighting the yanked area
		hl_group = "IncSearch",
	},
}

--- setup function to load plugin.
---@param user_config table|nil user specified configuration for the plugin.
function M.setup(user_config)
	---@table config merged config from user and default
	local config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, user_config or {})
	config.keymaps = vim.tbl_extend("force", DEFAULT_CONFIG.keymaps, user_config and user_config.keymaps or {})

	require("find-extender.finder").finder(config)
end

return M
