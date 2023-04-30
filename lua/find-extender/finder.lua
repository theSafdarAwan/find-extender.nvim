--- Finds characters and sets the cursor position to the target.
local M = {}

local api = vim.api
local fn = vim.fn

local keymap = {
	set = vim.keymap.set,
	opts = { silent = true, noremap = true },
}

--- main finder function
---@param config table config
function M.finder(config)
	-- timeout after which the find-extender searches for only one char.
	local timeout = config.timeout
	-- to highlight the yanked area
	local highlight_on_yank = config.highlight_on_yank

	-- need to store the command and the pattern for the user of , and ; commands
	local __previous_data = { pattern = nil, key = nil }

	local utils = require("find-extender.utils")
	local get_chars = utils.get_chars
	local tm = require("find-extender.text-manipulation")
	local movements = require("find-extender.movements")

	----------------------------------------------------------------------
	--                            Pick Match                            --
	----------------------------------------------------------------------
	--- pick match
	---@param args table
	local function pick_match(args)
		local picked_match = nil
		if not config.movements.leap.enable then
			args.go_to_first_match = config.movements.lh.go_to_first_match

			-- hide cursor
			utils.wait(function()
				vim.cmd.hi("Cursor", "blend=100")
				vim.opt.guicursor:append({ "a:Cursor/lCursor" })
			end)

			picked_match = movements.lh(args)

			-- show cursor
			vim.cmd.hi("Cursor", "blend=0")
			vim.opt.guicursor:remove({ "a:Cursor/lCursor" })
		else
			args.symbols = config.movements.leap.symbols
			picked_match = movements.leap(args)
		end
		return picked_match
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
		if config.ignore_case then
			local char_1 = string.upper(string.sub(args.pattern, 1, 1))
			local char_2 = string.upper(string.sub(args.pattern, 2, 2))
			-- ignore case matching sequences
			-- example match str: sS
			-- case 1: sS
			local xX = utils.map_string_pattern_positions(str, string.upper(char_1) .. string.lower(char_2))
			-- case 2: Ss
			local Xx = utils.map_string_pattern_positions(str, string.lower(char_1) .. string.upper(char_2))
			-- case 3: SS
			local XX = utils.map_string_pattern_positions(str, string.upper(char_1) .. string.upper(char_2))
			-- case 4: ss
			local xx = utils.map_string_pattern_positions(str, string.lower(char_1) .. string.lower(char_2))
			matches = utils.merge_tables({}, xX, Xx, XX, xx)
			-- sort positions correctly -> numerically
			table.sort(matches, function(x, y)
				return x < y
			end)
		else
			matches = utils.map_string_pattern_positions(str, args.pattern)
		end
		if not matches then
			return
		end
		-- in case of F/T commands we need to reverse the tbl of the matches because now we have
		-- to start searching from the end of the string rather then from the start
		if args.match_direction.right then
			matches = utils.reverse_tbl(matches)
		end

		local cursor_pos = fn.getpos(".")[3]
		-- trim the matches table and only leave matches that are in the same
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
			-- trim tables if count was available -> to skip matches, we don't need
			matches = utils.trim_table({ index = count - 1, tbl = matches })
		end
		local match = nil

		-- use the movements if matches exceed -> config.movements.min_matches
		if #matches > config.movements.min_matches then
			local picked_match = pick_match({
				matches = matches,
				direction = args.match_direction,
				key_type = args.key_type,
				-- how many chars do we need to highlight and we need to remove one char
				-- from this length because our cursor will be one char behind this pattern.
				virt_hl_length = #args.pattern - 1,
			})
			if not picked_match then
				return
			end
			match = picked_match
		else
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
			-- need to check if there are any valid characters before match
			if utils.string_sanity(match) then
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
		local prefix = ""
		if config.prefix.enable then
			prefix = config.prefix.key
		end

		-- find
		local find_direction_left = args.key == prefix .. "f"
			or __previous_data.key == prefix .. "F" and args.key == prefix .. ","
			or __previous_data.key == prefix .. "f" and args.key == prefix .. ";"
		local find_direction_right = args.key == prefix .. "F"
			or __previous_data.key == prefix .. "f" and args.key == prefix .. ","
			or __previous_data.key == prefix .. "F" and args.key == prefix .. ";"
		-- till
		local till_direction_left = args.key == prefix .. "t"
			or __previous_data.key == prefix .. "T" and args.key == prefix .. ","
			or __previous_data.key == prefix .. "t" and args.key == prefix .. ";"
		local till_direction_right = args.key == prefix .. "T"
			or __previous_data.key == prefix .. "t" and args.key == prefix .. ","
			or __previous_data.key == prefix .. "T" and args.key == prefix .. ";"
		-- is args.key is pattern repeat key
		local pattern_repeat_key = args.key == prefix .. ";" or args.key == prefix .. ","

		-- match position direction determined by the input key
		local match_direction = { left = false, right = false }
		if find_direction_right or till_direction_right then
			match_direction.right = true
		elseif find_direction_left or till_direction_left then
			match_direction.left = true
		end

		local pattern = nil
		if pattern_repeat_key then
			-- if args.key is , or ; then use the previous pattern
			pattern = __previous_data.pattern
		else
			pattern = get_chars({ input_length = config.input_length, no_wait = config.no_wait, timeout = timeout })
			if not pattern then
				return
			end
			-- if one of fF or tT command's is executed then add the pattern and the key to the
			-- __previous_data table.
			__previous_data.key = args.key
			__previous_data.pattern = pattern
		end

		local key_type = {
			till = till_direction_left or till_direction_right,
			find = find_direction_left or find_direction_right,
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

		local pattern = get_chars({ input_length = config.input_length, no_wait = config.no_wait })
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

	if config.prefix.enable then
		for idx, key in ipairs(finding_keys) do
			finding_keys[idx] = config.prefix.key .. key
		end
		for idx, key in ipairs(tm_keys) do
			tm_keys[idx] = config.prefix.key .. key
		end
	end

	----------------------------------------------------------------------
	--                       set user added keys                        --
	----------------------------------------------------------------------
	local function set_maps()
		for _, key in ipairs(finding_keys) do
			local opts = vim.deepcopy(keymap.opts)
			opts.callback = function()
				finding_keys_helper({ key = key })
				vim.cmd("do CursorMoved")
			end
			keymap.set(modes.finding, key, "", opts)
		end
		for key_name, keys in pairs(tm_keys) do
			-- to get the first character of delete/change/yank
			local tm_key_init_char = string.sub(tostring(key_name), 1, 1)
			for _, key in ipairs(keys) do
				key = tm_key_init_char .. key
				local opts = vim.deepcopy(keymap.opts)
				opts.callback = function()
					tm_keys_helper({ key = key })
					vim.cmd("do CursorMoved")
				end
				keymap.set("n", key, "", opts)
			end
		end
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
			keymap.set(keymaps.text_manipulation, key, "", keymap.opts)
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
	api.nvim_set_hl(0, "FEVirtualText", config.movements.highlight_match)
	api.nvim_set_hl(0, "FECurrentMatchCursor", config.movements.lh.cursor_hl)
	api.nvim_set_hl(0, "FEHighlightOnYank", config.highlight_on_yank.hl)

	-- add the maps on setup function execution
	set_maps()
end

return M
