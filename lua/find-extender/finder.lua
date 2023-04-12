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
	-- how many characters to find for
	local chars_length = config.chars_length
	-- highlight matches
	local highlight_matches = config.highlight_matches
	-- timeout before the find-extender.nvim goes to the default behavior to find 1 char
	-- * timeout in ms
	local timeout = config.timeout
	-- How many characters after which the timeout should be triggered. Important when
	-- we have more set more then _2_ chars lenght in _chars_lenght_.
	local start_timeout_after_chars = config.start_timeout_after_chars -- 2 by default
	-- to highlight the yanked area
	local highlight_on_yank = config.highlight_on_yank
	-- to remember the last pattern and the command when using the ; and , command
	local __data = { pattern = nil, key = nil }

	local utils = require("find-extender.utils")

	local get_match = require("find-extender.get-match").get_match
	local tm = require("find-extender.text-manipulation")
	local get_chars = utils.get_chars

	--- pick next highlighted match
	---@return nil|number picked count
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

	--- get direction and the type of the keys it a lot easier to do this like this
	--- then other methods. It's cleaner way of dealing with keys.
	---@param args table of keys with current key and the previous key.
	---@return table
	local function get_key_type(args)
		local tbl = {}
		-- > find
		tbl.find_direction_left = args.key == "f"
			or args.prev_key == "F" and args.key == ","
			or args.prev_key == "f" and args.key == ";"
			or args.key == "cf"
			or args.key == "df"
			or args.key == "yf"
		tbl.find_direction_right = args.key == "F"
			or args.prev_key == "f" and args.key == ","
			or args.prev_key == "F" and args.key == ";"
			or args.key == "cF"
			or args.key == "dF"
			or args.key == "yF"
		-- > till
		tbl.till_direction_left = args.key == "t"
			or args.prev_key == "T" and args.key == ","
			or args.prev_key == "t" and args.key == ";"
			or args.key == "ct"
			or args.key == "dt"
			or args.key == "yt"
		tbl.till_direction_right = args.key == "T"
			or __data.key == "t" and args.key == ","
			or __data.key == "T" and args.key == ";"
			or args.key == "cT"
			or args.key == "dT"
			or args.key == "yT"
		tbl.normal_keys = args.key == "f" or args.key == "F" or args.key == "t" or args.key == "T"
		tbl.text_manipulation_keys = args.key == "cT"
			or args.key == "dT"
			or args.key == "yT"
			or args.key == "ct"
			or args.key == "dt"
			or args.key == "yt"
			or args.key == "cf"
			or args.key == "df"
			or args.key == "yf"
			or args.key == "cF"
			or args.key == "dF"
			or args.key == "yF"
		return tbl
	end

	--- determines the direction and gets the next match position
	---@param args table
	---@field args.key string to determine direction, etc.
	---@field args.count number count
	local function finder(args)
		-- don't allow , and ; command to be used before any other command's got
		-- executed and data has been collected for last pattern repetition.
		if not __data.pattern and args.key == "," or args.key == ";" and not __data.pattern then
			return
		end

		local key_types = get_key_type({ key = args.key, prev_key = __data.key })

		-- match position direction determined by the input key
		local match_direction = { left = false, right = false }
		if key_types.find_direction_right or key_types.till_direction_right then
			match_direction.right = true
		elseif key_types.find_direction_left or key_types.till_direction_left then
			match_direction.left = true
		end
		-- threshold for till and find command's till command's set cursor before
		-- text and find command's set cursor on the text pattern.
		local threshold
		if key_types.till_direction_left or key_types.till_direction_right then
			threshold = 2
		elseif key_types.find_direction_left or key_types.find_direction_right then
			threshold = 1
		end

		local get_chars_args = {
			chars_length = chars_length,
			timeout = timeout,
			start_timeout_after_chars = start_timeout_after_chars,
		}

		local pattern = nil
		if key_types.normal_keys then
			-- if find or till command is executed then add the pattern and the key to the
			-- _last_search_info table.
			pattern = get_chars(get_chars_args)
			if not pattern then
				return
			end
			__data.key = args.key
			__data.pattern = pattern
		end
		if key_types.text_manipulation_keys then
			pattern = get_chars(get_chars_args)
			if not pattern then
				return
			end
		end
		if not key_types.text_manipulation_keys and not key_types.normal_keys then
			-- if f or F or t or T command wasn't pressed then search for the _last_search_info.pattern
			-- for , or ; command
			pattern = __data.pattern
		end

		local count = nil
		-- args.count has higher precedence
		if args and args.count then
			count = args.count
		else
			if vim.v.count > 1 then
				count = vim.v.count
			end
		end

		local str = api.nvim_get_current_line()
		local matches = nil
		if pattern then
			matches = utils.map_string_pattern_positions(str, pattern)
		else
			return
		end

		-- need to reverse the tbl of the matches because now we have to start
		-- searching from the end of the string rather then from the start
		if match_direction.right then
			matches = utils.reverse_tbl(matches)
		end
		if count then
			-- if count is available then highlight only the matches after the `count - 1`
			local matches_tbl = {}
			local i = count - 1
			while true do
				if i == #matches then
					break
				end
				i = i + 1
				table.insert(matches_tbl, matches[i])
			end
			matches = matches_tbl
		end

		local get_match_args = {
			str = str,
			str_matches = matches,
			pattern = pattern,
			match_direction = match_direction,
			threshold = threshold,
			count = count,
		}
		local match = nil
		-- match match if pattern matches exceed the highlight_matches.max_matches
		if #matches > highlight_matches.min_matches * 100 then
			count = pick_match()
			get_match_args.count = count
		end
		match = get_match(get_match_args)

		if #args.key > 1 then
			local type = {}
			local first_key = string.sub(args.key, 1, 1)
			if first_key == "c" then
				type.change = true
			elseif first_key == "d" then
				type.delete = true
			elseif first_key == "y" then
				type.yank = true
			end
			tm.manipulate_text(
				{ match = match, match_direction = match_direction, threshold = threshold },
				type,
				{ highlight_on_yank = highlight_on_yank }
			)
		else
			if match then
				utils.set_cursor(match)
			end
		end
	end

	-- TODO: support using text_manipulation keys in visual mode

	-- TODO: re-write text_manipulation
	--
	--- gets the keys and count when manipulating keys.
	--- This is an easy way of dealing with y/d/c keys operations.
	---@param args table
	local function text_manipulation(args)
		local chars = get_chars({ chars_length = 2 })

		if chars then
			local count = vim.v.count
			-- need to normalize the key by removing the callback function from its opts
			keymap.set(args.modes, args.key, "", keymap.opts)
			local feed_key = args.key .. chars
			if count and count > 0 then
				feed_key = count .. feed_key
			end
			api.nvim_feedkeys(feed_key, "n", false)
			-- this key would be the key that triggered this text_manipulation_keys function
			-- and we need to set it back so that we can use it again
			keymap.set(args.modes, args.key, "", {
				unpack(keymap.opts),
				callback = function()
					text_manipulation(args)
				end,
			})
		end
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
			keymap.set(modes.finding, key, "", {
				unpack(keymap.opts),
				callback = function()
					finder(key, {})
				end,
			})
		end
		-- BUG: currently i have to re-write the text_manipulation function
		-- for key_name, keys in pairs(tm_keys) do
		-- 	-- to get the first character of delete/change/yank
		-- 	local tm_key_initial = string.sub(tostring(key_name), 1, 1)
		-- 	for _, key in ipairs(keys) do
		-- 		key = tm_key_initial .. key
		-- 		keymap.set(modes.text_manipulation, key, "", {
		-- 			unpack(keymap.opts),
		-- 			callback = function()
		-- 				text_manipulation({
		-- 					modes = modes.text_manipulation,
		-- 					key = key,
		-- 					keys = keys,
		-- 				})
		-- 			end,
		-- 		})
		-- 	end
		-- end
	end

	----------------------------------------------------------------------
	--                          remove keymaps                          --
	----------------------------------------------------------------------
	local function remove_maps()
		for _, key in ipairs(finding_keys) do
			keymap.set(modes.finding, key, "", keymap.opts)
		end
		for key_name, _ in pairs(tm_keys) do
			local key = string.sub(tostring(key_name), 1, 1)
			keymap.set(modes.text_manipulation, key, function()
				keymap.set(keymaps.text_manipulation, key, "", keymap.opts)
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
