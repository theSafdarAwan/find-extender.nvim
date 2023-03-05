local M = {}

local api = vim.api

function M.finder(config)
	local utils = require("find-extender.utils")

	local plugin_enabled = config.enable
	-- how many characters to find for
	local chars_length = config.chars_length
	-- timeout before the find-extender.nvim goes to the default behavior to find 1 char
	-- * timeout in ms
	local timeout = config.timeout
	-- How many characters after which the timeout should be triggered. Important when
	-- we have more set more then _2_ chars lenght in _chars_lenght_.
	local start_timeout_after_chars = config.start_timeout_after_chars -- 2 by default
	-- to highlight the yanked area
	local highlight_on_yank = config.highlight_on_yank
	-- to remember the last pattern and the command when using the ; and , command
	local _previous_find_info = { pattern = nil, key = nil }

	local get_node = require("find-extender.get-node").get_node
	local get_chars = require("find-extender.utils").get_chars

	local function set_cursor(opts)
		local get_cursor = api.nvim_win_get_cursor(0)
		local target_position = get_node(opts)
		if not target_position then
			return
		end
		get_cursor[2] = target_position
		api.nvim_win_set_cursor(0, get_cursor)
	end

	local function finder(key, opts)
		-- to get the count
		local skip_nodes = vim.v.count
		if skip_nodes < 2 then
			skip_nodes = nil
		end
		-- this opts table is from get_text_manipulation_keys
		if opts and opts.skip_nodes then
			skip_nodes = opts.skip_nodes
		end
		-- if no find command was executed previously then there's no last pattern for
		-- , or ; so return
		if not _previous_find_info.pattern and key == "," or key == ";" and not _previous_find_info.pattern then
			return
		end
		-- to determine which node_direction to go
		-- THIS is the only way i found efficient without heaving overhead
		-- > find
		local find_node_direction_left = key == "f"
			or _previous_find_info.key == "F" and key == ","
			or _previous_find_info.key == "f" and key == ";"
			or key == "cf"
			or key == "df"
			or key == "yf"
		local find_node_direction_right = key == "F"
			or _previous_find_info.key == "f" and key == ","
			or _previous_find_info.key == "F" and key == ";"
			or key == "cF"
			or key == "dF"
			or key == "yF"
		-- > till
		local till_node_direction_left = key == "t"
			or _previous_find_info.key == "T" and key == ","
			or _previous_find_info.key == "t" and key == ";"
			or key == "ct"
			or key == "dt"
			or key == "yt"
		local till_node_direction_right = key == "T"
			or _previous_find_info.key == "t" and key == ","
			or _previous_find_info.key == "T" and key == ";"
			or key == "cT"
			or key == "dT"
			or key == "yT"

		local node_direction = { left = false, right = false }
		if find_node_direction_right or till_node_direction_right then
			node_direction.right = true
		elseif find_node_direction_left or till_node_direction_left then
			node_direction.left = true
		end
		-- this variable is threshold between the pattern under the cursor position
		-- it it exists the pattern exists within this threshold then move to the
		-- next one or previous one depending on the key
		local threshold = nil
		if till_node_direction_left or till_node_direction_right then
			threshold = 2
		elseif find_node_direction_left or find_node_direction_right then
			threshold = 1
		end

		local pattern
		local normal_keys = key == "f" or key == "F" or key == "t" or key == "T"
		local text_manipulation_keys = key == "cT"
			or key == "dT"
			or key == "yT"
			or key == "ct"
			or key == "dt"
			or key == "yt"
			or key == "cf"
			or key == "df"
			or key == "yf"
			or key == "cF"
			or key == "dF"
			or key == "yF"

		local get_chars_opts = {
			chars_length = chars_length,
			timeout = timeout,
			start_timeout_after_chars = start_timeout_after_chars,
		}

		if normal_keys then
			-- if find or till command is executed then add the pattern and the key to the
			-- _last_search_info table.
			pattern = get_chars(get_chars_opts)
			if not pattern then
				return
			end
			_previous_find_info.key = key
			_previous_find_info.pattern = pattern
		elseif text_manipulation_keys then
			pattern = get_chars(get_chars_opts)
			if not pattern then
				return
			end
		else
			-- if f or F or t or T command wasn't pressed then search for the _last_search_info.pattern
			-- for , or ; command
			pattern = _previous_find_info.pattern
		end

		local get_node_opts = {
			pattern = pattern,
			node_direction = node_direction,
			threshold = threshold,
			skip_nodes = skip_nodes,
		}

		local text_manipulation_types = { change = false, yank = false, delete = false }
		if #key > 1 then
			local type = string.sub(key, 1, 1)
			if type == "c" then
				text_manipulation_types.change = true
			elseif type == "d" then
				text_manipulation_types.delete = true
			elseif type == "y" then
				text_manipulation_types.yank = true
			end
			local node = get_node(get_node_opts)
			require("find-extender.text-manipulation").manipulate_text(
				{ node = node, node_direction = node_direction, threshold = threshold },
				text_manipulation_types,
				{ highlight_on_yank = highlight_on_yank }
			)
		else
			set_cursor(get_node_opts)
		end
	end

	local function get_text_manipulation_keys(key, keys_tbl, opts)
		local function not_text_manipulation_key(c, skip_nodes)
			local map_opts = { silent = true, noremap = true }
			vim.keymap.set("n", key, key, map_opts)
			if skip_nodes == 0 then
				skip_nodes = 1
			end
			api.nvim_feedkeys(skip_nodes .. key .. c, "n", false)
			vim.keymap.set("n", key, function()
				opts.func(key, keys_tbl, opts)
			end, map_opts)
		end

		local function get_char()
			local c = vim.fn.getchar()

			if type(c) ~= "number" then
				return
			end

			-- return if its not an alphabet or punctuation
			if c < 32 or c > 127 then
				return nil
			end
			return c
		end
		for index, key_str in ipairs(keys_tbl) do
			keys_tbl[key_str] = {}
			keys_tbl[index] = nil
		end

		local skip_nodes = vim.v.count
		local c = get_char()
		if c then
			c = vim.fn.nr2char(c)
		end

		if type(tonumber(c)) == "number" then
			skip_nodes = tonumber(c)
			c = get_char()
			c = vim.fn.nr2char(c)
			if c and keys_tbl[c] then
				finder(key .. c, { skip_nodes = skip_nodes })
			elseif type(c) == "string" then
				not_text_manipulation_key(c, skip_nodes)
			end
		elseif keys_tbl[c] then
			finder(key .. c)
		else
			not_text_manipulation_key(c, skip_nodes)
		end
	end

	local normal_keys_tbl = {
		-- these keys aren't optional
		";",
		",",
	}
	local text_manipulation_keys_tbl = config.keymaps.text_manipulation

	local modes_tbl = {}

	local function notify(msg)
		local level = vim.log.levels.WARN
		vim.api.nvim_notify(msg, level, {})
	end

	local keymaps = config.keymaps
	normal_keys_tbl = utils.merge_tables(keymaps.find, normal_keys_tbl)
	normal_keys_tbl = utils.merge_tables(keymaps.till, normal_keys_tbl)
	if keymaps.text_manipulation then
		local type = keymaps.text_manipulation
		if #type.yank < 1 then
			text_manipulation_keys_tbl["y"] = nil
		end
		if #type.delete < 1 then
			text_manipulation_keys_tbl["d"] = nil
		end
		if #type.change < 1 then
			text_manipulation_keys_tbl["c"] = nil
		end
	end

	local modes = keymaps.modes
	if #modes > 0 then
		-- adding modes to the modes list
		for i = 1, #modes, 1 do
			local mode = string.sub(modes, i, i)
			table.insert(modes_tbl, mode)
		end
	else
		notify("find-extender.nvim: no modes provided in keymaps table.")
	end

	local set_keymap = vim.keymap.set
	local set_keymap_opts = { noremap = true, silent = true }
	local function set_maps()
		for _, key in ipairs(normal_keys_tbl) do
			set_keymap(modes_tbl, key, function()
				finder(key)
			end, set_keymap_opts)
		end
		for key, keys in pairs(text_manipulation_keys_tbl) do
			set_keymap("n", key, function()
				get_text_manipulation_keys(key, keys, { func = get_text_manipulation_keys })
			end, set_keymap_opts)
		end
	end

	local function remove_maps()
		for _, key in ipairs(normal_keys_tbl) do
			set_keymap(modes_tbl, key, key, set_keymap_opts)
		end
		for key, _ in pairs(text_manipulation_keys_tbl) do
			set_keymap("n", key, function()
				set_keymap("n", key, key, set_keymap_opts)
			end)
		end
	end

	local function enable_plugin()
		plugin_enabled = true
		set_maps()
	end
	local function disable_plugin()
		plugin_enabled = false
		remove_maps()
	end

	-- create the commands for the plugin
	local cmds = {
		["FindExtenderDisable"] = function()
			disable_plugin()
		end,
		["FindExtenderEnable"] = function()
			enable_plugin()
		end,
		["FindExtenderToggle"] = function()
			if plugin_enabled then
				disable_plugin()
			else
				enable_plugin()
			end
		end,
	}
	for cmd_name, cmd_func in pairs(cmds) do
		api.nvim_create_user_command(cmd_name, function()
			cmd_func()
		end, {})
	end

	-- enable plugin on startup if it was enabled
	if plugin_enabled then
		enable_plugin()
	end
end

return M
