--- setup module.
local M = {}

--- Default Config
---@table Default_Config
---@field enable boolean to enable the plugin.
---@field chars_length number how much characters to get input for finding.
---@field timeout number|boolean timeout before we find the characters input
--- at our disposal before the `chars_length` completes.
---@field start_timeout_after_chars number how much characters should be
--- available before timeout triggers the character finder.
---@field keymaps table information for keymaps.
---@field keymaps.modes string modes in which the find-extender should be eanbled.
---@field keymaps.till table table of till keys includes backward and forward both by default.
---@field keymaps.find table table of find keys includes backward and forward both by default.
---@field keymaps.text_manipulation table information about text manipulation keys including yank/delete/change.
---@field keymaps.text_manipulation.yank table includes keys related to finding yanking area of text in a line.
---@field keymaps.text_manipulation.delete table includes keys related to finding deleting area of text in a line.
---@field keymaps.text_manipulation.change table includes keys related to finding changing area of text in a line.
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

--- setup function to load plugin.
---@param user_config table|nil user specified configuration for the plugin.
function M.setup(user_config)
	---@table config merged config from user and default
	local config = vim.tbl_deep_extend("force", default_config, user_config or {})
	require("find-extender.finder").finder(config)
end

return M
