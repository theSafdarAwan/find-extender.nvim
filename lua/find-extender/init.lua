--- setup module.
local M = {}

-- TODO: add capability to use count in the leap movement.
--
-- TODO: add capability to use different movements for different finding commands
-- like leap for deleting but lh moving through

-- TODO: add support for prefix

local deprecate = require("find-extender.deprecate")

-- TODO: add strategy when first input char is a punctuation and expose an option
-- for user to decide what to do
-- TODO: add strategy for cursor movement when searching backwards

--- default config
local DEFAULT_CONFIG = {
	---@field prefix string if you don't want this plugin to hijack the default
	--- finding commands use a prefix to use this plugin.
	prefix = "",
	movments = {
		---@field min_matches number minimum number of matches required after which
		--- you can use the leap or lh.
		min_matches = 2,
		---@field highlight_match table highlights the match
		highlight_match = { fg = "#c0caf5", bg = "#545c7e" },
		---@field lh table this lets you move though the matches using `l` and `h` keys.
		lh = {
			enable = false,
			---@field lh_curosr_hl table highlight the cursor for the `lh` movment
			cursor_hl = { fg = "#545c7e", bg = "#ff9e64" },
		},
		---@field leap table pick match, with virtual text symbol for that match.
		leap = {
			enable = true,
			---@field symbols string symbols that represent matches, with virtual text
			symbols = "abcdefgh",
		},
	},
	---@field no_wait table don't wait for second char if one of these is the first
	--- char, very helpful if you don't wait to enter 2 chars if the first one
	--- is a punctuation.
	no_wait = {
		"}",
		"{",
		"[",
		"]",
		"(",
		")",
		",",
	},
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
		---@field hl_group string highlight the yanked area
		hl = { bg = "#565f89" },
	},
}

--- setup function to load plugin.
---@param user_config table|nil user specified configuration for the plugin.
function M.setup(user_config)
	---@table config merged config from user and default
	local config = DEFAULT_CONFIG
	local config_is_derecated = deprecate.old_syntax(user_config)

	if user_config and user_config.no_wait then
		config.no_wait = user_config.no_wait
	end

	if not config_is_derecated then
		config = vim.tbl_deep_extend("force", config, user_config or {})
		config.keymaps = vim.tbl_extend("force", DEFAULT_CONFIG.keymaps, user_config and user_config.keymaps or {})
	end
	require("find-extender.finder").finder(config)
end

return M
