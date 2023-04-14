--- Finds characters and sets the cursor position to the target.
local M = {}

local api = vim.api
local fn = vim.fn

local keymap = {
	set = vim.keymap.set,
	del = vim.keymap.del,
	opts = { silent = true, noremap = true },
}

--- main finder function
---@param config table config
function M.finder(config)
	-- timeout before the find-extender.nvim goes to the default behavior to find 1 char
	-- * timeout in ms
	local timeout = config.timeout
	-- to highlight the yanked area
	local highlight_on_yank = config.highlight_on_yank
	-- to remember the last pattern and the command when using the ; and , command
	local __previous_data = { pattern = nil, key = nil }

	local utils = require("find-extender.utils")

	local tm = require("find-extender.text-manipulation")
	local get_chars = utils.get_chars

	----------------------------------------------------------------------
	--                          Picking match                           --
	----------------------------------------------------------------------
	--- pick next highlighted match
	---@param args table includes matches and threshold
	---@return number|nil picked count
	local function pick_match(args)
		local picked_match = nil
		local buf_nr = api.nvim_get_current_buf()
		local cursor_pos = fn.getpos(".")[3]
		local line_nr = fn.line(".")
		local ns_id = api.nvim_create_namespace("")
		if config.movments.leap and not config.movments.lh then
			args.alphabets = "abcdefgh"
			local i = 1
			for _, match in ipairs(args.matches) do
				local extmark_opts = {
					virt_text = { { string.sub(args.alphabets, i, i), "FEVirtualText" } },
					virt_text_pos = "overlay",
					hl_mode = "combine",
					priority = 105,
				}
				api.nvim_buf_set_extmark(buf_nr, ns_id, line_nr - 1, match - 1, extmark_opts)
				i = i + 1
			end
			api.nvim_create_autocmd({ "CursorMoved" }, {
				once = true,
				callback = function()
					api.nvim_buf_clear_namespace(buf_nr, ns_id, 0, -1)
				end,
			})
			picked_match = get_chars({ chars_length = 1 })
			if picked_match then
				local match_pos = string.find(args.alphabets, picked_match)
				picked_match = args.matches[match_pos]
			end
			vim.cmd("silent! do CursorMoved")
		end

		if config.movments.lh then
			-- this table of matches is for the use of h key for backward movmenet,
			-- because we mapped the string from left to right in case of the h key it
			-- will break the loop on the first match, that why we have to reverse this table.
			local args_matches_reversed = utils.reverse_tbl(args.matches)
			for _, match in ipairs(args.matches) do
				api.nvim_buf_add_highlight(buf_nr, ns_id, "FEVirtualText", line_nr - 1, match - 1, match + 1)
			end
			picked_match = cursor_pos
			local lh_cursor_ns = api.nvim_create_namespace("")
			while true do
				vim.cmd("redraw")
				local key = get_chars({ chars_length = 1 })
				if key == "l" then
					local __matches = nil
					if args.direction.left then
						__matches = args.matches
					else
						__matches = args_matches_reversed
					end
					for _, match in ipairs(__matches) do
						if match > picked_match then
							picked_match = match
							api.nvim_buf_clear_namespace(buf_nr, lh_cursor_ns, 0, -1)
							api.nvim_buf_add_highlight(
								buf_nr,
								lh_cursor_ns,
								"FECurrentMatchCursor",
								line_nr - 1,
								picked_match - 1,
								picked_match
							)
							break
						end
					end
				end
				if key == "h" then
					local __matches = nil
					if args.direction.left then
						__matches = args_matches_reversed
					else
						__matches = args.matches
					end
					for _, match in ipairs(__matches) do
						if match < picked_match then
							picked_match = match
							api.nvim_buf_clear_namespace(buf_nr, lh_cursor_ns, 0, -1)
							api.nvim_buf_add_highlight(buf_nr, lh_cursor_ns, "FECurrentMatchCursor", line_nr - 1, match - 1, match)
							break
						end
					end
				end
				if key ~= "h" and key ~= "l" then
					break
				end
			end
			api.nvim_buf_clear_namespace(buf_nr, ns_id, 0, -1)
			api.nvim_buf_clear_namespace(buf_nr, lh_cursor_ns, 0, -1)
		end
		return picked_match
	end

	--- check if string has has characters or not
	---@param end_pos number string end position till which we have to sub string
	---@param str string current line
	---@return boolean|nil true if is valid
	local string_sanity = function(str, end_pos)
		local s = string.sub(str, 1, end_pos - 1)
		return utils.string_has_chars(s)
	end

	--- helper function for determing the direction and type of the finding key
	---@param args table of keys with current key and the previous key.
	---@return table
	local function get_finding_key_info(args)
		local tbl = {}
		-- find
		tbl.find_direction_left = args.key == "f"
			or args.prev_key == "F" and args.key == ","
			or args.prev_key == "f" and args.key == ";"
		tbl.find_direction_right = args.key == "F"
			or args.prev_key == "f" and args.key == ","
			or args.prev_key == "F" and args.key == ";"
		-- till
		tbl.till_direction_left = args.key == "t"
			or args.prev_key == "T" and args.key == ","
			or args.prev_key == "t" and args.key == ";"
		tbl.till_direction_right = args.key == "T"
			or __previous_data.key == "t" and args.key == ","
			or __previous_data.key == "T" and args.key == ";"
		-- is args.key is pattern repeat key
		tbl.pattern_repeat_key = args.key == ";" or args.key == ","
		return tbl
	end

	----------------------------------------------------------------------
	--                            get match                             --
	----------------------------------------------------------------------
	--- gets the matches of the pattern
	---@param args table
	---@return nil|nil|number match
	local function get_target_match(args)
		local str = api.nvim_get_current_line()
		-- count sanity check
		local count = nil
		if vim.v.count > 1 then
			count = vim.v.count
		end

		local matches = nil
		matches = utils.map_string_pattern_positions(str, args.pattern)
		if not matches then
			return
		end
		-- in case of F/T commands we need to reverse the tbl of the matches because now we have
		-- to start searching from the end of the string rather then from the start
		if args.match_direction.right then
			matches = utils.reverse_tbl(matches)
		end

		local cursor_pos = fn.getpos(".")[3]
		-- trim the matches table and only have matches that are in the same
		-- direction with respect to the key.
		if args.match_direction.right then
			local tbl = {}
			for _, match in ipairs(matches) do
				if match <= cursor_pos then
					table.insert(tbl, match)
				end
			end
			matches = tbl
		end
		if args.match_direction.left then
			local tbl = {}
			for _, match in ipairs(matches) do
				if match >= cursor_pos then
					table.insert(tbl, match)
				end
			end
			matches = tbl
		end

		if count then
			matches = utils.trim_table({ index = count - 1, tbl = matches })
		end
		local match = nil
		-- highlight match if pattern matches exceed the virtual_text.max_matches
		if #matches > config.movments.min_matches then
			local picked_match = pick_match({ matches = matches, direction = args.match_direction })
			if not picked_match then
				return
			end
			matches = { picked_match }
		end

		-- get the appropriate match
		if args.match_direction.left then
			for _, match_position in ipairs(matches) do
				if cursor_pos < match_position then
					match = match_position
					break
				end
			end
		end

		if args.match_direction.right then
			for _, match_position in ipairs(matches) do
				if cursor_pos > match_position then
					match = match_position
					break
				end
			end
		end

		if not match then
			return
		end
		-- string.find returns the exact position for the match so we have to adjust
		-- the cursor position based on the type of the command
		-- tT/fF commands have different behaviour for settings cursor
		-- till command      match | find command       match
		--                  ^      |                    ^
		if args.key_type.till then
			if match > 2 and string_sanity(str, match) then
				match = match - 2
			else
				match = match - 1
			end
		end

		if args.key_type.find then
			match = match - 1
		end
		return match
	end

	----------------------------------------------------------------------
	--                           Finding Keys                           --
	----------------------------------------------------------------------
	--- helper for finding keys, gets the match and then sets the cursor.
	---@param args table contains arguments needed for finding the next/prev match
	---@field args.key string to determine direction, etc.
	local function finding_keys_helper(args)
		-- if not __previous_data was saved before `,` and `;` then return
		if not __previous_data.pattern and args.key == "," or args.key == ";" and not __previous_data.pattern then
			return
		end

		local key_types = get_finding_key_info({ key = args.key, prev_key = __previous_data.key })
		-- match position direction determined by the input key
		local match_direction = { left = false, right = false }
		if key_types.find_direction_right or key_types.till_direction_right then
			match_direction.right = true
		elseif key_types.find_direction_left or key_types.till_direction_left then
			match_direction.left = true
		end

		local pattern = nil
		if key_types.pattern_repeat_key then
			-- if args.key is , or ; then use the previous pattern
			pattern = __previous_data.pattern
		else
			pattern = get_chars({ chars_length = 2, timeout = timeout })
			if not pattern then
				return
			end
			-- if one of fF or tT command's is executed then add the pattern and the key to the
			-- __previous_data table.
			__previous_data.key = args.key
			__previous_data.pattern = pattern
		end

		local key_type = {
			till = key_types.till_direction_left or key_types.till_direction_right,
			find = key_types.find_direction_left or key_types.find_direction_right,
		}

		local match = get_target_match({ pattern = pattern, match_direction = match_direction, key_type = key_type })
		if not match then
			return
		end
		utils.set_cursor(match)
	end

	----------------------------------------------------------------------
	--                      Text Manipulation Keys                      --
	----------------------------------------------------------------------
	--- helper for the text_manipulation keys
	--- This is an easy way of dealing with y/d/c keys operations.
	---@param args table
	local function tm_keys_helper(args)
		local type = { change = false, delete = false, yank = false }
		local init_key = string.sub(args.key, 1, 1)
		if init_key == "c" then
			type.change = true
		elseif init_key == "d" then
			type.delete = true
		elseif init_key == "y" then
			type.yank = true
		end

		local match_direction = { left = false, right = false }

		local second_key = string.sub(args.key, 2, 2)
		if second_key == "f" or second_key == "t" then
			match_direction.left = true
		else
			match_direction.right = true
		end

		local key_type = {}
		if second_key == "F" or second_key == "f" then
			key_type.find = true
		elseif second_key == "T" or second_key == "t" then
			key_type.till = true
		end
		---------------------

		local pattern = get_chars({ chars_length = 2 })
		if not pattern then
			return
		end

		local match = get_target_match({ pattern = pattern, match_direction = match_direction, key_type = key_type })
		if not match then
			return
		end

		tm.manipulate_text({
			match = match,
			match_direction = match_direction,
			type = type,
			highlight_on_yank = highlight_on_yank,
		})
	end
	----------------------------------------------------------------------
	--                             Keymaps                              --
	----------------------------------------------------------------------

	local keymaps = config.keymaps
	---------------------------------------------------------
	--          Convert modes string's to table            --
	---------------------------------------------------------
	local keymap_finding_modes = nil
	if keymaps.finding and keymaps.finding.modes and #keymaps.finding.modes > 0 then
		keymap_finding_modes = keymaps.finding.modes
	else
		keymap_finding_modes = "nv"
	end
	if keymaps.finding and keymaps.finding.modes then
		config.keymaps.finding.modes = nil
	end

	local keymap_tm_modes = nil
	if keymap.text_manipulation and keymaps.text_manipulation.modes and #keymaps.text_manipulation.modes > 0 then
		keymap_tm_modes = keymap.text_manipulation.modes
	else
		keymap_tm_modes = "n"
	end
	if keymaps.text_manipulation and keymaps.text_manipulation.modes then
		config.keymaps.text_manipulation.modes = nil
	end
	-- adding modes to the modes list
	local modes = {
		finding = {},
		text_manipulation = {},
	}
	-- adding mode list for finding
	for i = 1, #keymap_finding_modes, 1 do
		local mode = string.sub(keymap_finding_modes, i, i)
		table.insert(modes.finding, mode)
	end
	-- adding mode list for text_manipulation
	for i = 1, #keymap_tm_modes, 1 do
		local mode = string.sub(keymap_tm_modes, i, i)
		table.insert(modes.text_manipulation, mode)
	end

	---------------------------------------------------------
	--                         keys                        --
	---------------------------------------------------------
	local finding_keys = {
		-- these keys aren't optional
		";",
		",",
	}
	finding_keys = utils.merge_tables(finding_keys, keymaps.finding.find, keymaps.finding.till)
	local tm_keys = config.keymaps.text_manipulation

	----------------------------------------------------------------------
	--                       set user added keys                        --
	----------------------------------------------------------------------
	local function set_maps()
		for _, key in ipairs(finding_keys) do
			keymap.set(modes.finding, key, key, {
				---@diagnostic disable-next-line: deprecated
				unpack(keymap.opts),
				callback = function()
					finding_keys_helper({ key = key })
				end,
			})
		end
		for key_name, keys in pairs(tm_keys) do
			-- to get the first character of delete/change/yank
			local tm_key_init_char = string.sub(tostring(key_name), 1, 1)
			for _, key in ipairs(keys) do
				key = tm_key_init_char .. key
				keymap.set("n", key, key, {
					---@diagnostic disable-next-line: deprecated
					unpack(keymap.opts),
					callback = function()
						tm_keys_helper({ key = key })
					end,
				})
			end
		end
	end

	----------------------------------------------------------------------
	--                          remove keymaps                          --
	----------------------------------------------------------------------
	local function remove_maps()
		for _, key in ipairs(finding_keys) do
			keymap.set(modes.finding, key, key, keymap.opts)
		end
		for key_name, _ in pairs(tm_keys) do
			local key = string.sub(tostring(key_name), 1, 1)
			keymap.set(modes.text_manipulation, key, function()
				keymap.set(keymaps.text_manipulation, key, key, keymap.opts)
			end)
		end
	end

	----------------------------------------------------------------------
	--                          User commands                           --
	----------------------------------------------------------------------
	local plugin_enabled = true
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

	----------------------------------------------------------------------
	--                      Highlight virtual text                      --
	----------------------------------------------------------------------
	api.nvim_set_hl(0, "FEVirtualText", config.highlight_match)
	api.nvim_set_hl(0, "FECurrentMatchCursor", config.lh_curosr_hl)

	-- add the maps on setup function execution
	set_maps()
end

return M
