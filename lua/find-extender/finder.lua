--- Finds characters and sets the cursor position to the target.
local M = {}

-- TODO: The cursor is down on the command line during `getchar`,
-- so we set a temporary highlight on it to see where we are.

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
	-- highlight matches
	local highlight_matches = config.highlight_matches
	-- timeout before the find-extender.nvim goes to the default behavior to find 1 char
	-- * timeout in ms
	local timeout = config.timeout
	-- to highlight the yanked area
	local highlight_on_yank = config.highlight_on_yank
	-- to remember the last pattern and the command when using the ; and , command
	local __previous_data = { pattern = nil, key = nil }

	local utils = require("find-extender.utils")

	local get_match = require("find-extender.get-match").get_match
	local tm = require("find-extender.text-manipulation")
	local get_chars = utils.get_chars

	--- pick next highlighted match
	---@return number|nil picked count
	local function pick_match()
		local picked_match = fn.getchar()
		picked_match = tonumber(fn.nr2char(picked_match))
		if type(picked_match) ~= "number" then
			-- TODO: add virtual text with numbers displayed on them
			--
			-- to remove the highlighted matches
			vim.cmd("silent! do CursorMoved")
			return
		end
		return tonumber(picked_match)
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

	--- gets the matches of the pattern
	---@param args table
	---@return table matches
	local function get_matches_and_count(args)
		local str = api.nvim_get_current_line()
		-- count sanity check
		local count = nil
		if vim.v.count > 1 then
			count = vim.v.count
		end

		local matches = nil
		matches = utils.map_string_pattern_positions(str, args.pattern)
		-- in case of F/T commands we need to reverse the tbl of the matches because now we have
		-- to start searching from the end of the string rather then from the start
		if args.match_direction.right then
			matches = utils.reverse_tbl(matches)
		end
		if count then
			matches = utils.trim_table({ index = count - 1, tbl = matches })
		end
		return matches
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

		-- string.find returns the exact position for the match so we have to adjust
		-- the cursor position base on the type of the command
		-- tT/fF commands have different behaviour for settings cursor and threshold value
		-- justifies that example for the cursor position settings:
		-- till command      match | find command       match
		--                  ^      |                    ^
		local threshold = nil
		if key_types.find_direction_left or key_types.find_direction_right then
			threshold = 1
		elseif key_types.till_direction_left or key_types.till_direction_right then
			threshold = 2
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

		local matches = get_matches_and_count({ pattern = pattern, match_direction = match_direction })

		local match = nil
		-- highlight match if pattern matches exceed the highlight_matches.max_matches
		if #matches > highlight_matches.min_matches then
			local picked_match = pick_match()
			if not picked_match then
				return
			end
			matches = utils.trim_table({ index = picked_match - 1, tbl = matches })
		end
		match = get_match({
			str_matches = matches,
			pattern = pattern,
			match_direction = match_direction,
			threshold = threshold,
		})

		if match then
			utils.set_cursor(match)
		end
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

		local second_key = string.sub(args.key, 2, 2)
		local threshold = nil
		if second_key == "F" or second_key == "f" then
			threshold = 1
		elseif second_key == "T" or second_key == "t" then
			threshold = 2
		end

		local match_direction = { left = false, right = false }
		if second_key == "f" or second_key == "t" then
			match_direction.left = true
		else
			match_direction.right = true
		end
		---------------------

		local pattern = get_chars({ chars_length = 2, chars_type = "number" })
		if not pattern then
			return
		end

		local matches = get_matches_and_count({ pattern = pattern, match_direction = match_direction })

		local match = nil
		-- highlight match if pattern matches exceed the highlight_matches.max_matches
		-- and trim the matches table according to the user picked match
		if #matches > highlight_matches.min_matches then
			local picked_match = pick_match()
			if not picked_match then
				return
			end
			matches = utils.trim_table({ index = picked_match - 1, tbl = matches })
		end
		match = get_match({
			str_matches = matches,
			pattern = pattern,
			match_direction = match_direction,
			threshold = threshold,
		})

		if not match then
			return
		end

		tm.manipulate_text({
			threshold = threshold,
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

	-- add the maps on setup function execution
	set_maps()
end

return M
