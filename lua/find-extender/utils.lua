local M = {}
local api = vim.api
local fn = vim.fn

--- gets user input
---@param opts table includes information about chars and timeout.
---@return nil|string|nil|string nil if nil character, if loop broke either because of
--- timeout or chars limit, next target input chars, if nil(out of eng alphabets, numbers,
--- or punctuations) character was provided.
function M.get_chars(opts)
	local break_loop = false
	local chars = ""
	local i = 0
	while true do
		if opts.timeout and #chars > opts.start_timeout_after_chars - 1 then
			-- this is a trick to solve issue of multiple timers being created in every
			-- loop iteration and once the guard condition becomes true the previous timers
			-- jeopardised the timeout So for now the i and id variable's acts as a id
			-- validation
			i = i + 1
			local id = i
			vim.defer_fn(function()
				if i == id then
					-- to get rid of the getchar will throw dummy value which won't
					-- be added to the chars list
					api.nvim_feedkeys("�", "n", false)
					break_loop = true
				end
			end, opts.timeout)
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
		if #chars == opts.chars_length then
			break
		end
	end
	return chars
end

--- sets the cursor to given position
---@param pos number cursor position
function M.set_cursor(pos)
	local get_cursor = api.nvim_win_get_cursor(0)
	local win_nr = api.nvim_get_current_win()
	if not pos then
		return
	end
	get_cursor[2] = pos
	api.nvim_win_set_cursor(win_nr, get_cursor)
end

--- highlights the yanked area
---@param highlight_on_yank_opts table options related to highlight on yank includes,
--- highlight group and timeout.
---@param start number starting mark for the yanked area.
---@param finish number finishing mark for the yanked area.
function M.on_yank(highlight_on_yank_opts, start, finish)
	local yank_timer
	local buf_id = api.nvim_get_current_buf()
	local line_nr = fn.getpos(".")[2] - 1

	local ns_id = api.nvim_create_namespace("")
	local event = vim.v.event

	if yank_timer then
		yank_timer.close()
	end

	--- neovim function
	require("vim.highlight").range(
		buf_id,
		ns_id,
		highlight_on_yank_opts.hl_group,
		{ line_nr, start },
		{ line_nr, finish },
		{ regtype = event.regtype, inclusive = event.inclusive, priority = 200 }
	)
	yank_timer = vim.defer_fn(function()
		yank_timer = nil
		if api.nvim_buf_is_valid(buf_id) then
			api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)
		end
	end, highlight_on_yank_opts.timeout)
end

--- highlights the table nodes, clears highlights when CursorMoved event happens.
---@param nodes_tbl table nodes position to highlight
---@param threshold number information about
M.highlight_nodes = function(nodes_tbl, threshold)
	local buf = api.nvim_get_current_buf()
	local line_nr = fn.line(".")
	local ns_id = api.nvim_create_namespace("")
	for _, node in ipairs(nodes_tbl) do
		api.nvim_buf_add_highlight(buf, ns_id, "CursorColumn", line_nr - 1, node - 1, node + threshold)
	end
	api.nvim_create_autocmd({ "CursorMoved" }, {
		once = true,
		callback = function()
			api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
		end,
	})
end

--- adds a dummy cursor at the cursor position when the cursor is in the command
--- line when getting cursor input
M.add_dummy_cursor = function()
	local buf_nr = api.nvim_get_current_buf()
	local ns_id = api.nvim_create_namespace("")
	local pos = vim.fn.getpos(".")
	local line_num = pos[2] - 1
	local col_num = pos[3] - 1
	local opts = {
		end_col = col_num + 1,
		hl_group = "Cursor",
		hl_mode = "blend",
		priority = 106,
	}
	vim.schedule_wrap(function()
		local extmark_id = api.nvim_buf_set_extmark(buf_nr, ns_id, line_num, col_num, opts)
		api.nvim_create_autocmd({ "CursorMoved" }, {
			once = true,
			callback = function()
				api.nvim_buf_del_extmark(buf_nr, ns_id, extmark_id)
			end,
		})
	end)
end

--- validates if any character or punctuation is present
---@param string_end_position number string ending position based on direction
--- from left to right.
---@param str string need to validate this string.
---@return boolean return true if contains any English alphabet or punctuation.
function M.node_validation(string_end_position, str)
	local string = string.sub(str, 1, string_end_position)
	local i = 0
	for _ in string.gmatch(string, "[%a%p]") do
		i = i + 1
	end
	if i > 1 then
		return false
	end
	return true
end

--- gets you the remaining string before and after the pattern this gets called
--- on c/d text manipulation actions
---@param str string current line target area.
---@param before_end number mark before the string ends
---@param after_start number mark after the string started.
---@return string returns the remaining string before and after the target area.
function M.get_remaining_str(str, before_end, after_start)
	local a = string.sub(str, 1, before_end)
	local b = string.sub(str, after_start, #str)
	return a .. b
end

--- revers a table from {1, 2, 3} -> {3, 2, 1}
---@param tbl table to reverse.
---@return table transformed table.
function M.reverse_tbl(tbl)
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

--- merges two tables
---@param tbl table a
---@param ... table's
---@return table merged table
function M.merge_tables(tbl, ...)
	local __ = { ... }
	for _, t in pairs(__) do
		for _, key in pairs(t) do
			table.insert(tbl, key)
		end
	end
	return tbl
end

--- maps the occurrences of the pattern in a string
---@param str string current line.
---@param pattern string pattern which we need to map in the `str`.
---@return table mapped pattern occurrences mapped.
function M.map_string_nodes(str, pattern)
	local mapped_tbl = {}
	local pattern_last_idx = mapped_tbl[#mapped_tbl] or 1
	while true do
		local pattern_idx = str.find(str, pattern, pattern_last_idx, true)
		if not pattern_idx then
			break
		end
		table.insert(mapped_tbl, pattern_idx)
		pattern_last_idx = mapped_tbl[#mapped_tbl] + 2
	end
	return mapped_tbl
end

return M
