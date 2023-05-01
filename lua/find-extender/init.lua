--- setup module.
local M = {}

local deprecate = require("find-extender.deprecate")
local utils = require("find-extender.utils")

--- default config
local DEFAULT_CONFIG = {
	---@field prefix table if you don't want this plugin to hijack the default
	--- finding commands use a prefix to use this plugin.
	prefix = {
		key = "g",
		enable = false,
	},
	---@field input_length number how much characters should we take input for
	--- default is `2` you can change it to `1`.
	input_length = 2,
	---@field ignore_case boolean whether to ignore case or not when searching
	ignore_case = false,
	movements = {
		---@field min_matches number minimum number of matches required after which
		--- you can use the leap or lh.
		min_matches = 1,
		---@field highlight_match table highlights the match
		highlight_match = { fg = "#c0caf5", bg = "#545c7e" },
		---@field lh table this lets you move though the matches using `l` and `h` keys.
		lh = {
			enable = true,
			---@field lh_curosr_hl table highlight the cursor for the `lh` movement
			cursor_hl = { fg = "#545c7e", bg = "#ff9e64" },
			---@field go_to_first_match boolean leave the current cursor position and
			--- go to the first match.
			go_to_first_match = true,
		},
		---@field leap table pick match, with virtual text symbol for that match.
		leap = {
			enable = false,
			---@field symbols string virtual text symbols, that represent matches
			symbols = "abcdefgh",
		},
		---@field search table this movement behaves likes search(/ or ?) features of vim
		--- this movement behaves like `lh` but i doesn't respects the `input_length`
		--- and you can add as many characters as you want until you have only one
		--- match left in the current line Or you can press the `<CR> or <ESC>` to
		--- activate the `lh` movement on the current matches
		--TODO: comming soon...
		search = {
			---@field real_time_highlight boolean highlight the matches in real time as
			--you enter the input it will start highlighting the matches
			real_time_highlight = true,
			enable = false,
		},
	},
	---@field no_wait table don't wait for second char if one of these is the first
	--- char, very helpful if you don't want to enter 2 chars if the first one
	--- is a punctuation.
	no_wait = {
		"}",
		"{",
		"[",
		"]",
		"(",
		")",
	},
	---@field keymaps table
	keymaps = {
		---@field finding table finding keys config
		finding = {
			---@field modes string modes in which the finding keys should be added.
			modes = "nv",
			---@field till table table of till keys backward and forward
			till = { "T", "t" },
			---@field find table table of find keys backward and forward
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

	-- override no_wait
	if user_config and user_config.no_wait then
		config.no_wait = user_config.no_wait
	end

	if not config_is_derecated then
		config = vim.tbl_deep_extend("force", config, user_config or {})
		config.keymaps = vim.tbl_extend("force", DEFAULT_CONFIG.keymaps, user_config and user_config.keymaps or {})
	end

	if user_config and user_config.movments then
		config.movements = vim.tbl_deep_extend("force", config.movements, user_config.movments)
		vim.defer_fn(function()
			vim.notify("find-extender: please use `movements` instead of `movments` which has wrong spelling")
		end, 3000)
	end

	require("find-extender.finder").finder(config)
end

return M
