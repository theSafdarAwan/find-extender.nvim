--- Finds characters and sets the cursor position to the target.
local M = {}

local api = vim.api

--- main finder function
---@param config table config
function M.finder(config)
	local plugin_enabled = true
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
	local __info = { pattern = nil, key = nil }

	local get_node = require("find-extender.get-node").get_node
	local get_chars = require("find-extender.utils").get_chars
	local text_manipulation = require("find-extender.text-manipulation")

	--- sets the cursor to given position
	---@param cursor_pos table cursor position table
	local function set_cursor(cursor_pos)
		local get_cursor = api.nvim_win_get_cursor(0)
		local target_position = get_node(cursor_pos)
		if not target_position then
			return
		end
		get_cursor[2] = target_position
		api.nvim_win_set_cursor(0, get_cursor)
	end

	--- determiens the direction and gets the next pattern position
	---@param key string key to determine direction, etc.
	---@param opts table options
	local function finder(key, opts)
		-- to get the count
		local count = vim.v.count
		if count < 2 then
			count = nil
		end
		-- this opts table is from get_text_manipulation_keys
		if opts and opts.count then
			count = opts.count
		end
		-- if no find command was executed previously then there's no last pattern for
		-- , or ; so return
		if
			not __info.pattern and key == ","
			or key == ";" and not __info.pattern
		then
			return
		end
		-- to determine which node_direction to go
		-- THIS is the only way i found efficient without heaving overhead
		-- > find
		local find_node_direction_left = key == "f"
			or __info.key == "F" and key == ","
			or __info.key == "f" and key == ";"
			or key == "cf"
			or key == "df"
			or key == "yf"
		local find_node_direction_right = key == "F"
			or __info.key == "f" and key == ","
			or __info.key == "F" and key == ";"
			or key == "cF"
			or key == "dF"
			or key == "yF"
		-- > till
		local till_node_direction_left = key == "t"
			or __info.key == "T" and key == ","
			or __info.key == "t" and key == ";"
			or key == "ct"
			or key == "dt"
			or key == "yt"
		local till_node_direction_right = key == "T"
			or __info.key == "t" and key == ","
			or __info.key == "T" and key == ";"
			or key == "cT"
			or key == "dT"
			or key == "yT"

		-- node position direction determined by the key
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
			__info.key = key
			__info.pattern = pattern
		elseif text_manipulation_keys then
			pattern = get_chars(get_chars_opts)
			if not pattern then
				return
			end
		else
			-- if f or F or t or T command wasn't pressed then search for the _last_search_info.pattern
			-- for , or ; command
			pattern = __info.pattern
		end

		local next_node_info = {
			pattern = pattern,
			node_direction = node_direction,
			threshold = threshold,
			count = count,
		}

		if #key > 1 then
			local type = {}
			local first_key = string.sub(key, 1, 1)
			if first_key == "c" then
				type.change = true
			elseif first_key == "d" then
				type.delete = true
			elseif first_key == "y" then
				type.yank = true
			end
			local node = get_node(next_node_info)
			text_manipulation.manipulate_text(
				{ node = node, node_direction = node_direction, threshold = threshold },
				type,
				{ highlight_on_yank = highlight_on_yank }
			)
		else
			set_cursor(next_node_info)
		end
	end

	--- gets the keys and count when manipulating keys.
	---@param pressed_key string key
	---@param keys_tbl table previous keys get deleted from the maps so we have to set them again.
	---@param opts table options.
	local function get_text_manipulation_keys(pressed_key, keys_tbl, opts)
		local function not_text_manipulation_key(char, count)
			local map_opts = { silent = true, noremap = true }
			vim.keymap.set("n", pressed_key, pressed_key, map_opts)
			local feed_key = pressed_key .. char
			if count > 0 then
				feed_key = count .. feed_key
			end
			api.nvim_feedkeys(feed_key, "n", false)
			vim.keymap.set("n", pressed_key, function()
				opts.callback(pressed_key, keys_tbl, opts)
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

		local count = vim.v.count
		local char = get_char()
		if char then
			char = vim.fn.nr2char(char)
		end

		if type(tonumber(char)) == "number" then
			count = tonumber(char)
			char = get_char()
			char = vim.fn.nr2char(char)
			if char and keys_tbl[char] then
				finder(pressed_key .. char, { count = count })
			elseif type(char) == "string" then
				not_text_manipulation_key(char, count)
			end
		elseif keys_tbl[char] then
			finder(pressed_key .. char, {})
		elseif char then
			not_text_manipulation_key(char, count)
		end
	end

	local normal_keys = {
		-- these keys aren't optional
		";",
		",",
	}
	local text_manipulation_keys = config.keymaps.text_manipulation

	local modes_tbl = {}

	--- notify helper function
	---@param msg string notification message
	local function notify(msg)
		local level = vim.log.levels.WARN
		vim.api.nvim_notify(msg, level, {})
	end

	local utils = require("find-extender.utils")
	local keymaps = config.keymaps
	normal_keys = utils.merge_tables(keymaps.find, normal_keys)
	normal_keys = utils.merge_tables(keymaps.till, normal_keys)
	if keymaps.text_manipulation then
		local type = keymaps.text_manipulation
		if #type.yank < 1 then
			text_manipulation_keys.yank = nil
		end
		if #type.delete < 1 then
			text_manipulation_keys.delete = nil
		end
		if #type.change < 1 then
			text_manipulation_keys.change = nil
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
	local keymap_opts = { noremap = true, silent = true }
	--- sets maps for the available keys on startup or when enabling plugin after
	--- disabling it using commands.
	local function set_maps()
		for _, key in ipairs(normal_keys) do
			set_keymap(modes_tbl, key, function()
				finder(key, {})
			end, keymap_opts)
		end
		for key_name, keys in pairs(text_manipulation_keys) do
			local key = string.sub(tostring(key_name), 1, 1)
			set_keymap("n", key, function()
				get_text_manipulation_keys(key, keys, { callback = get_text_manipulation_keys })
			end, keymap_opts)
		end
	end

	--- removes maps when disabling plugin.
	local function remove_maps()
		for _, key in ipairs(normal_keys) do
			set_keymap(modes_tbl, key, key, keymap_opts)
		end
		for key_name, _ in pairs(text_manipulation_keys) do
			local key = string.sub(tostring(key_name), 1, 1)
			set_keymap("n", key, function()
				set_keymap("n", key, key, keymap_opts)
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
	local user_commands = {
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
	for cmd_name, cmd_func in pairs(user_commands) do
		api.nvim_create_user_command(cmd_name, function()
			cmd_func()
		end, {})
	end

	-- add the maps on setup function execution
	set_maps()
end

return M
