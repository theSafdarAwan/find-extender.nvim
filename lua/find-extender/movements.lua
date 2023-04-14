local M = {}

local api = vim.api
local fn = vim.fn
local utils = require("find-extender.utils")

--- leap movment
---@param args table
---@return number|nil picked match
function M.leap(args)
	local picked_match = nil
	local buf_nr = api.nvim_get_current_buf()
	local line_nr = fn.line(".")
	local ns_id = api.nvim_create_namespace("")
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
	picked_match = utils.get_chars({ chars_length = 1 })
	if picked_match then
		local match_pos = string.find(args.alphabets, picked_match)
		picked_match = args.matches[match_pos]
	end
	vim.cmd("silent! do CursorMoved")

	return picked_match
end

--- lh movment
---@param args table
---@return number|nil picked match
M.lh = function(args)
	local picked_match = nil
	local buf_nr = api.nvim_get_current_buf()
	local cursor_pos = fn.getpos(".")[3]
	local line_nr = fn.line(".")
	local ns_id = api.nvim_create_namespace("")
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
		local key = utils.get_chars({ chars_length = 1 })
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
	return picked_match
end

return M
