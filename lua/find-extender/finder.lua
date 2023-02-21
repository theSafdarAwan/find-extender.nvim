----------------------------------------------------------------------
--        replace find command to find more characters rather       --
--                             then one                             --
----------------------------------------------------------------------

local M = {}
function M.finder(config)
	local api = vim.api
	local fn = vim.fn

	-- how many characters to find for
	local find_extender_find_chars_length = config.find_extender_find_chars_length
	-- timeout before the quick movement goes to the default behavior of f to find 1
	-- char false or timeout in ms false by default
	local find_extender_find_timeout = config.find_extender_find_timeout

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
	local function map_pattern_positions(str, pattern)
		local mapped_tbl = {}
		local pattern_last_idx = mapped_tbl[#mapped_tbl] or 1
		while true do
			local pattern_idx = string.find(str, pattern, pattern_last_idx, true)
			if pattern_last_idx == pattern_idx or not pattern_idx then
				break
			end
			table.insert(mapped_tbl, pattern_idx)
			pattern_last_idx = mapped_tbl[#mapped_tbl] + 2
		end
		return mapped_tbl
	end

	-- get the position for the next or previous chars pattern position
	local function get_position(pattern, direction, threshold)
		local cursor_position = api.nvim_win_get_cursor(0)[2]
		local current_line = api.nvim_get_current_line()
		local pattern_positions = map_pattern_positions(current_line, pattern)

		local target_position
		-- gives target position location
		if direction == "l" then
			for key, position in ipairs(pattern_positions) do
				if position > cursor_position then
					target_position = position
					-- if the cursor is already on one occurrence then move to the next one
					if cursor_position == position - threshold then
						target_position = pattern_positions[key + 1]
					end
					break
				end
			end
		elseif direction == "h" then
			-- need to reverse the tbl of the mapped_string because now we have to
			-- start searching from the end of the string rather then from the start
			pattern_positions = reverse_tbl(pattern_positions)
			for key, position in ipairs(pattern_positions) do
				if position < cursor_position then
					target_position = position
					-- if the cursor is already on one occurrence then move to the previous one
					if cursor_position == position + threshold then
						target_position = pattern_positions[key - 1]
					end
					break
				end
			end
		end

		return { target_position = target_position, cursor_position = cursor_position }
	end

	local function get_chars()
		local find_chars_lenght = 2 or find_extender_find_chars_length
		local break_loop = false
		local timeout = find_extender_find_timeout
		local chars = ""
		while true do
			-- this timer will only stop waiting the second character
			if timeout and #chars == 1 then
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
			if #chars == find_chars_lenght then
				break
			end
		end
		return chars
	end

	local function notify(chars_pattern)
		api.nvim_notify(chars_pattern .. " pattern not found", vim.log.levels.WARN, {})
	end

	local function move_to_char_position(key)
		local previous_find_info = _previous_find_info
		-- if no find command was executed previously then there's no last pattern for
		-- , or ; so return
		if not previous_find_info.pattern and key == "," or key == ";" and not previous_find_info.pattern then
			return
		end

		-- to determine which direction to go
		-- > find
		local find_direction_l = key == "f"
			or previous_find_info.key == "F" and key == ","
			or previous_find_info.key == "f" and key == ";"
		local find_direction_h = key == "F"
			or previous_find_info.key == "f" and key == ","
			or previous_find_info.key == "F" and key == ";"
		-- > till
		local till_direction_l = key == "t"
			or previous_find_info.key == "T" and key == ","
			or previous_find_info.key == "t" and key == ";"
		local till_direction_h = key == "T"
			or previous_find_info.key == "t" and key == ","
			or previous_find_info.key == "T" and key == ";"

		local direction
		if find_direction_h or till_direction_h then
			direction = "h"
		elseif find_direction_l or till_direction_l then
			direction = "l"
		else
			notify(previous_find_info.pattern)
			return
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
			-- _previous_find_info table.
			chars_pattern = get_chars()
			if not chars_pattern then
				return
			end
			previous_find_info.key = key
			previous_find_info.pattern = chars_pattern
		else
			-- if f or F or t or T command wasn't pressed then search for the _previous_find_info.pattern
			-- for , or ; command
			chars_pattern = previous_find_info.pattern
		end
		local position = get_position(chars_pattern, direction, threshold)

		print(vim.inspect(position))
		if not position.target_position then
			notify(chars_pattern)
			return
		end

		-- to determine how much away the target position is
		local target_distance
		if find_direction_l then
			target_distance = position.target_position - position.cursor_position - threshold
		elseif find_direction_h then
			target_distance = position.cursor_position - position.target_position + threshold
		elseif till_direction_l then
			target_distance = position.target_position - position.cursor_position - threshold
		elseif till_direction_h then
			target_distance = position.cursor_position - position.target_position + threshold
		end

		fn.feedkeys(target_distance)
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
