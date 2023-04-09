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
	-- timeout before the find-extender.nvim goes to the default behavior to find 1 char
	-- * timeout in ms
	local timeout = config.timeout
	-- How many characters after which the timeout should be triggered. Important when
	-- we have more set more then _2_ chars lenght in _chars_lenght_.
	local start_timeout_after_chars = config.start_timeout_after_chars -- 2 by default
	-- to highlight the yanked area
	local highlight_on_yank = config.highlight_on_yank
	-- to remember the last pattern and the command when using the ; and , command
	local _previous_op_info = { pattern = nil, key = nil }

	local utils = require("find-extender.utils")

	local get_node = require("find-extender.get-node").get_node
	local tm = require("find-extender.text-manipulation")
	local get_chars = utils.get_chars

	--- determines the direction and gets the next node position
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
		-- don't allow , and ; command to be used before any find command gets executed
		if not _previous_op_info.pattern and key == "," or key == ";" and not _previous_op_info.pattern then
			return
		end
		-- TODO: pass direction and the type of the key in the opts table when
		-- calling this function
		-- determine which direction to go
		-- > find
		local find_node_direction_left = key == "f"
			or _previous_op_info.key == "F" and key == ","
			or _previous_op_info.key == "f" and key == ";"
			or key == "cf"
			or key == "df"
			or key == "yf"
		local find_node_direction_right = key == "F"
			or _previous_op_info.key == "f" and key == ","
			or _previous_op_info.key == "F" and key == ";"
			or key == "cF"
			or key == "dF"
			or key == "yF"
		-- > till
		local till_node_direction_left = key == "t"
			or _previous_op_info.key == "T" and key == ","
			or _previous_op_info.key == "t" and key == ";"
			or key == "ct"
			or key == "dt"
			or key == "yt"
		local till_node_direction_right = key == "T"
			or _previous_op_info.key == "t" and key == ","
			or _previous_op_info.key == "T" and key == ";"
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
		local threshold
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

		local get_chars_args = {
			chars_length = chars_length,
			timeout = timeout,
			start_timeout_after_chars = start_timeout_after_chars,
		}

		utils.add_dummy_cursor()

		if normal_keys then
			-- if find or till command is executed then add the pattern and the key to the
			-- _last_search_info table.
			pattern = get_chars(get_chars_args)
			if not pattern then
				return
			end
			_previous_op_info.key = key
			_previous_op_info.pattern = pattern
		end
		if text_manipulation_keys then
			pattern = get_chars(get_chars_args)
			if not pattern then
				return
			end
		end
		if not text_manipulation_keys and not normal_keys then
			-- if f or F or t or T command wasn't pressed then search for the _last_search_info.pattern
			-- for , or ; command
			pattern = _previous_op_info.pattern
		end

		local node_info = {
			pattern = pattern,
			node_direction = node_direction,
			threshold = threshold,
			count = count,
		}

		local cur_line = api.nvim_get_current_line()
		---@diagnostic disable-next-line: param-type-mismatch
		local string_nodes = utils.map_string_nodes(cur_line, pattern)
		-- if count is available then highlight only the nodes after the count - 1
		if count then
			local tbl = {}
			local i = count - 1
			while true do
				if i == #string_nodes then
					break
				end
				i = i + 1
				table.insert(tbl, string_nodes[i])
			end
			string_nodes = tbl
		end

		local node = nil
		if #string_nodes > 2 then
			local picked_node = fn.getchar()
			picked_node = tonumber(fn.nr2char(picked_node))
			if type(picked_node) ~= "number" then
				-- TODO: add virtual text with numbers displayed on them
				vim.notify("find-extender: pick a number", vim.log.levels.WARN, {})
				-- to remove the highlighted nodes
				vim.cmd("silent! do CursorMoved")
				return
			end
			---@diagnostic disable-next-line: param-type-mismatch
			string_nodes = utils.map_string_nodes(cur_line, pattern)
			node_info.count = tonumber(picked_node)
			node = get_node(node_info)
		end

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
			if not node then
				node = get_node(node_info)
			end
			tm.manipulate_text(
				{ node = node, node_direction = node_direction, threshold = threshold },
				type,
				{ highlight_on_yank = highlight_on_yank }
			)
		else
			local cursor_pos = get_node(node_info)
			utils.set_cursor(cursor_pos)
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
