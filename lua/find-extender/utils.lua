local M = {}
local api = vim.api
local fn = vim.fn
-- get chars from user input
function M.get_chars(opts)
	local break_loop = false
	local chars = ""
	local i = 0
	while true do
		if opts.timeout and #chars > opts.start_timeout_after_chars - 1 then
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
-- highlight the yanked area
function M.on_yank(highlight_on_yank, start, finish)
	local yank_timer
	local buf_id = api.nvim_get_current_buf()
	local line_nr = fn.getpos(".")[2] - 1

	local buf_ns = api.nvim_create_namespace("my namespace")
	local event = vim.v.event

	if yank_timer then
		yank_timer.close()
	end

	require("vim.highlight").range(
		buf_id,
		buf_ns,
		highlight_on_yank.hl_group,
		{ line_nr, start },
		{ line_nr, finish },
		{ regtype = event.regtype, inclusive = event.inclusive, priority = 200 }
	)
	yank_timer = vim.defer_fn(function()
		yank_timer = nil
		if api.nvim_buf_is_valid(buf_id) then
			api.nvim_buf_clear_namespace(buf_id, buf_ns, 0, -1)
		end
	end, highlight_on_yank.timeout)
end

-- validates if any character or punctuation is present
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

-- gets you the remaining string before and after the pattern
function M.get_remaining_str(str, before_end, after_start)
	local a = string.sub(str, 1, before_end)
	local b = string.sub(str, after_start, #str)
	return a .. b
end

-- revers a table from {1, 2, 3} -> {3, 2, 1}
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

-- merges two tables
function M.merge_tables(tbl_a, tbl_b)
	for _, val in pairs(tbl_a) do
		table.insert(tbl_b, val)
	end
	return tbl_b
end

-- maps the occurrences of the pattern in a string
function M.map_string_nodes(string, pattern)
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

return M
