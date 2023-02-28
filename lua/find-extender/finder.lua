----------------------------------------------------------------------
--        replace find command to find more characters rather       --
--                             then one                             --
----------------------------------------------------------------------
local M = {}
function M.finder(config)
	local api = vim.api
	local fn = vim.fn
	local plugin_enabled = config.enable
	-- how many characters to find for
	local chars_length = config.chars_length
	-- timeout before the find-extender.nvim goes to the default behavior to find 1
	-- char
	-- * timeout in ms
	local timeout = config.timeout
	-- How many characters after which the timeout should be triggered. Important when
	-- we have more set more then _2_ chars lenght in _chars_lenght_.
	local start_timeout_after_chars = config.start_timeout_after_chars -- 2 by default
	-- to remember the last pattern and the command when using the ; and , command
	local _previous_find_info = { pattern = nil, key = nil }

	local function reverse_tbl(tbl)
		local transformed_tbl = {}
		local idx = #tbl
		while true do
			table.insert(transformed_tbl, tbl[idx])
			if idx < 1 then
				break
			end
			idx = idx - 1
		end
		return transformed_tbl
	end

	-- maps the occurrences of the pattern in a string
	local function map_string_nodes(string, pattern)
		local mapped_tbl = {}
		local pattern_last_idx = mapped_tbl[#mapped_tbl] or 1
		while true do
			local pattern_idx = string.find(string, pattern, pattern_last_idx, true)
			if not pattern_idx then
				break
			end
			table.insert(mapped_tbl, pattern_idx)
			pattern_last_idx = mapped_tbl[#mapped_tbl] + 2
		end
		return mapped_tbl
	end

	local function node_validation(string_end_position, str)
		local string = string.sub(str, 1, string_end_position)
		local i = 0
		for _ in string.gmatch(string, "%a") do
			i = i + 1
		end
		if i > 1 then
			return false
		else
			return true
		end
	end

	-- Gets you the position for you next target node depending on direction
	local function set_cursor(pattern, direction, threshold, skip_nodes)
		local get_cursor = api.nvim_win_get_cursor(0)
		local current_line = api.nvim_get_current_line()
		local string_nodes = map_string_nodes(current_line, pattern)

		local cursor_position = get_cursor[2]
		local node = nil
		-- in cases of node in the start of the line and node in the end of the
		-- line we need to reset the threshold
		local reset_threshold = false
		-- direction is to know which direction to search in
		if direction.left then
			for node_position, current_node in ipairs(string_nodes) do
				if
					cursor_position + threshold < current_node
					or cursor_position < 1 and current_node < 3
				then
					if
						threshold > 1
						and node_validation(current_node, current_line)
						and not skip_nodes
					then
						reset_threshold = true
					end
					if skip_nodes then
						node = string_nodes[node_position + skip_nodes - 1]
					else
						node = current_node
					end
					break
				end
			end
		elseif direction.right then
			-- need to reverse the tbl of the string_nodes because now
			-- we have to start searching from the end of the string rather then from
			-- the start
			string_nodes = reverse_tbl(string_nodes)
			for node_position, current_node in ipairs(string_nodes) do
				if
					cursor_position - threshold == current_node
					or cursor_position - threshold > current_node
				then
					if threshold > 1 and node_validation(current_node, current_line) then
						reset_threshold = true
					end
					if skip_nodes then
						local x = string_nodes[node_position + skip_nodes - 1]
						-- need to reset the threshold here because previous
						-- guard wasn't for this x node
						if threshold > 1 and node_validation(x, current_line) then
							reset_threshold = true
						end
						node = x
					else
						node = current_node
					end
					break
				end
			end
		end
		if node then
			if reset_threshold then
				threshold = 1
			end
			cursor_position = node - threshold
		end
		get_cursor[2] = cursor_position

		api.nvim_win_set_cursor(0, get_cursor)
	end

	local function get_chars()
		local break_loop = false
		local chars = ""
		local i = 0
		while true do
			if timeout and #chars > start_timeout_after_chars - 1 then
				-- this is a trick to solve issue of multiple timers being
				-- created and once the guard condition becomes true the previous
				-- timers jeopardised the timeout
				-- So for now the i and id variable's acts as a id validation
				i = i + 1
				local id = i
				vim.defer_fn(function()
					if i == id then
						-- to get rid of the getchar will throw dummy value which won't
						-- be added to the chars list
						api.nvim_feedkeys("�", "n", false)
						break_loop = true
					end
				end, timeout)
			end
			local c = fn.getchar()
			if type(c) ~= "number" then
				return
			end
			if break_loop then
				return chars
			elseif c < 32 or c > 127 then
				-- only accept ASCII value for the letters and punctuations including
				-- space as input
				return
			end
			chars = chars .. fn.nr2char(c)
			if #chars == chars_length then
				break
			end
		end
		return chars
	end

	local function find_target(key)
		-- to get the count
		local skip_nodes = vim.v.count
		if skip_nodes < 2 then
			skip_nodes = nil
		end
		-- if no find command was executed previously then there's no last pattern for
		-- , or ; so return
		if not _previous_find_info.pattern and key == "," or key == ";" and not _previous_find_info.pattern then
			return
		end
		-- to determine which direction to go
		-- THIS is the only way i found efficient without heaving overhead
		-- > find
		local find_direction_left = key == "f"
			or _previous_find_info.key == "F" and key == ","
			or _previous_find_info.key == "f" and key == ";"
		local find_direction_right = key == "F"
			or _previous_find_info.key == "f" and key == ","
			or _previous_find_info.key == "F" and key == ";"
		-- > till
		local till_direction_left = key == "t"
			or _previous_find_info.key == "T" and key == ","
			or _previous_find_info.key == "t" and key == ";"
		local till_direction_right = key == "T"
			or _previous_find_info.key == "t" and key == ","
			or _previous_find_info.key == "T" and key == ";"

		local direction = { left = false, right = false }
		if find_direction_right or till_direction_right then
			direction.right = true
		elseif find_direction_left or till_direction_left then
			direction.left = true
		end
		-- this variable is threshold between the pattern under the cursor position
		-- it it exists the pattern exists within this threshold then move to the
		-- next one or previous one depending on the key
		local threshold = nil
		if till_direction_left or till_direction_right then
			threshold = 2
		elseif find_direction_left or find_direction_right then
			threshold = 1
		end

		local chars_pattern
		local normal_keys = key == "f" or key == "F" or key == "t" or key == "T"
		if normal_keys then
			-- if find or till command is executed then add the pattern and the key to the
			-- _last_search_info table.
			chars_pattern = get_chars()
			if not chars_pattern then
				return
			end
			_previous_find_info.key = key
			_previous_find_info.pattern = chars_pattern
		else
			-- if f or F or t or T command wasn't pressed then search for the _last_search_info.pattern
			-- for , or ; command
			chars_pattern = _previous_find_info.pattern
		end
		set_cursor(chars_pattern, direction, threshold, skip_nodes)
	end

	local function merge_tables(tbl_a, tbl_b)
		for _, val in pairs(tbl_a) do
			table.insert(tbl_b, val)
		end
		return tbl_b
	end

	local keys_tbl = {
		-- these keys aren't optional
		";",
		",",
	}

	local modes_tbl = {}

	local function notify(msg)
		local level = vim.log.levels.WARN
		vim.api.nvim_notify(msg, level, {})
	end

	local keymaps = config.keymaps
	keys_tbl = merge_tables(keymaps.find, keys_tbl)
	keys_tbl = merge_tables(keymaps.till, keys_tbl)

	local modes = keymaps.modes
	if #modes > 0 then
		-- adding modes to the list
		for i = 1, #modes, 1 do
			local mode = string.sub(modes, i, i)
			table.insert(modes_tbl, mode)
		end
	else
		notify("find-extender.nvim: no modes provided in keymaps table.")
	end

	local set_keymap = vim.keymap.set
	local function set_maps()
		for _, key in ipairs(keys_tbl) do
			set_keymap(modes_tbl, key, function()
				find_target(key)
			end)
		end
	end

	local function remove_maps()
		for _, key in ipairs(keys_tbl) do
			set_keymap(modes_tbl, key, key)
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
