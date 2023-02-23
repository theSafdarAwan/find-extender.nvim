----------------------------------------------------------------------
--        replace find command to find more characters rather       --
--                             then one                             --
----------------------------------------------------------------------

local M = {}
function M.finder(config)
	local api = vim.api
	local fn = vim.fn

	-- how many characters to find for
	local chars_length = config.chars_length
	-- timeout before the find-extender.nvim goes to the default behavior to find 1
	-- char
	-- * timeout in ms
	local timeout = config.timeout

	-- How many characters after which the timeout should be triggered. Important when
	-- we have more set more then _2_ chars lenght in _chars_lenght_.
	--
	local start_timeout_after_chars = config.start_timeout_after_chars -- 2 by default

	-- to remember the last pattern and the command when using the ; and , command
	local _last_search_info = { pattern = nil, key = nil }

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
	local function get_string_nodes(string, pattern)
		local mapped_tbl = {}
		local pattern_last_idx = mapped_tbl[#mapped_tbl] or 1
		while true do
			local pattern_idx = string.find(string, pattern, pattern_last_idx, true)
			if pattern_last_idx == pattern_idx or not pattern_idx then
				break
			end
			table.insert(mapped_tbl, pattern_idx)
			pattern_last_idx = mapped_tbl[#mapped_tbl] + 2
		end
		return mapped_tbl
	end

	-- Gets you the position for you next target node depending on direction
	local function get_position(pattern, direction, threshold)
		local cursor_position = api.nvim_win_get_cursor(0)[2]
		local current_line = api.nvim_get_current_line()
		local string_nodes = get_string_nodes(current_line, pattern)

		local target_node
		-- direction is to know which direction to search in
		if direction == "l" then
			for key, current_node in ipairs(string_nodes) do
				-- if the cursor is on the start of the line
				if cursor_position == 0 then
					target_node = current_node
					break
				elseif current_node - threshold > cursor_position then
					target_node = current_node
					break
				elseif current_node == cursor_position + threshold then
					target_node = string_nodes[key + 1]
					break
				end
			end
		elseif direction == "h" then
			-- need to reverse the tbl of the string_nodes because now
			-- we have to start searching from the end of the string rather then from
			-- the start
			string_nodes = reverse_tbl(string_nodes)
			for key, current_node in ipairs(string_nodes) do
				if cursor_position < current_node and current_node == string_nodes[#string_nodes] then
					break
				end
				-- in case the node is in the start of the string then behave
				-- like find
				if
					threshold == 2
					and current_node == string_nodes[#string_nodes]
					and current_node < 3
				then
					threshold = 1
					target_node = current_node
					break
				elseif cursor_position == #current_line - 1 then
					-- if the cursor is on the end of the line then first node
					-- would be the target node because we reversed the table it in case
					-- you are wondering else it would have been the last
					-- like tbl[#tbl] but in this case its the first
					target_node = current_node
					break
				elseif current_node + threshold < cursor_position or cursor_position > current_node then
					target_node = current_node
					break
				elseif current_node == cursor_position - threshold then
					target_node = string_nodes[key - 1]
					break
				end
			end
		end

		local target_node_distance
		if target_node and direction == "l" then
			target_node_distance = target_node - cursor_position - threshold
		elseif target_node and direction == "h" then
			target_node_distance = cursor_position - target_node + threshold
		end

		return target_node_distance
	end

	local function get_chars()
		local break_loop = false
		local chars = ""
		while true do
			if timeout and #chars == start_timeout_after_chars then
				vim.defer_fn(function()
					-- to get rid of the getchar will throw dummy value which won't
					-- be added to the chars list
					api.nvim_feedkeys("�", "n", false)
					break_loop = true
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

	local function move_to_char_position(key)
		local last_search_info = _previous_find_info
		-- if no find command was executed previously then there's no last pattern for
		-- , or ; so return
		if not last_search_info.pattern and key == "," or key == ";" and not previous_find_info.pattern then
			return
		end

		-- to determine which direction to go
		-- THIS is the only way i found efficient without heaving overhead
		-- > find
		local find_direction_l = key == "f"
			or last_search_info.key == "F" and key == ","
			or last_search_info.key == "f" and key == ";"
		local find_direction_h = key == "F"
			or last_search_info.key == "f" and key == ","
			or last_search_info.key == "F" and key == ";"
		-- > till
		local till_direction_l = key == "t"
			or last_search_info.key == "T" and key == ","
			or last_search_info.key == "t" and key == ";"
		local till_direction_h = key == "T"
			or last_search_info.key == "t" and key == ","
			or last_search_info.key == "T" and key == ";"

		local direction
		if find_direction_h or till_direction_h then
			direction = "h"
		elseif find_direction_l or till_direction_l then
			direction = "l"
		end

		-- this variable is threshold between the pattern under the cursor position
		-- it it exists the pattern exists within this threshold then move to the
		-- next one or previous one depending on the key
		local threshold = nil
		if till_direction_l or till_direction_h then
			threshold = 2
		elseif find_direction_l or find_direction_h then
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
			last_search_info.key = key
			last_search_info.pattern = chars_pattern
		else
			-- if f or F or t or T command wasn't pressed then search for the _last_search_info.pattern
			-- for , or ; command
			chars_pattern = last_search_info.pattern
		end
		local target_position = get_position(chars_pattern, direction, threshold)

		if not target_position then
			return
		end

		fn.feedkeys(target_position)
		api.nvim_feedkeys(direction, "m", true)
	end

	local find_keys_tbl = {
		"t",
		"T",
		"f",
		"F",
		";",
		",",
	}

	for _, key in ipairs(find_keys_tbl) do
		vim.keymap.set({ "n", "v" }, key, function()
			move_to_char_position(key)
		end)
	end
end

return M
