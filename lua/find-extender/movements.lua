local M = {}

local api = vim.api
local fn = vim.fn
local utils = require("find-extender.utils")

--- leap movement
---@param args table
---@return number|nil picked match
function M.leap(args)
	local picked_match = nil
	local buf_nr = api.nvim_get_current_buf()
	local line_nr = fn.line(".")
	local ns_id = api.nvim_create_namespace("")
	-- need exact location to highlight target position with respect to the key
	-- type threshold, which differs in find and till
	local threshold = nil
	if args.key_type.find then
		threshold = 1
	elseif args.key_type.till then
		threshold = 2
	end
	local i = 1
	for _, match in ipairs(args.matches) do
		local extmark_opts = {
			virt_text = { { string.sub(args.symbols, i, i), "FEVirtualText" } },
			virt_text_pos = "overlay",
			hl_mode = "combine",
			priority = 105,
		}
		api.nvim_buf_set_extmark(buf_nr, ns_id, line_nr - 1, match - threshold, extmark_opts)
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
		local match_pos = string.find(args.symbols, picked_match)
		picked_match = args.matches[match_pos]
	end
	vim.cmd("silent! do CursorMoved")

	return picked_match
end

-- TODO: you need to render and clear the highlights on every input

--- lh movement
---@param args table
---@return number|nil picked match
M.lh = function(args)
	local picked_match = nil
	local buf_nr = api.nvim_get_current_buf()
	local cursor_pos = api.nvim_win_get_cursor(0)
	local line_nr = fn.line(".")
	local ns_id = api.nvim_create_namespace("")
	-- this table of matches is for the use of h key for backward movmenet,
	-- because we mapped the string from left to right in case of the h key it
	-- will break the loop on the first match, that why we have to reverse this table.
	local args_matches_reversed = utils.reverse_tbl(args.matches)

	picked_match = cursor_pos[2]
	local lh_cursor_ns = api.nvim_create_namespace("")

	local function renader_matches()
		for _, match in ipairs(args.matches) do
			api.nvim_buf_add_highlight(buf_nr, ns_id, "FEVirtualText", line_nr - 1, match - 1, match + 1)
		end
	end
	local function clear_highlights()
		api.nvim_buf_clear_namespace(buf_nr, ns_id, 0, -1)
		api.nvim_buf_clear_namespace(buf_nr, lh_cursor_ns, 0, -1)
	end
	local function render_cursor(match)
		if match <= 1 then
			return
		end
		api.nvim_buf_clear_namespace(buf_nr, lh_cursor_ns, 0, -1)
		-- need to add the cursor highlight at the exact location relative to the key type
		local threshold = nil
		if args.key_type.find then
			threshold = 1
		elseif args.key_type.till then
			threshold = 2
		end
		clear_highlights()
		renader_matches()
		api.nvim_buf_add_highlight(buf_nr, lh_cursor_ns, "FECurrentMatchCursor", line_nr - 1, match - threshold, match)
	end
	-- if count was given in the lh movement
	local count = nil
	while true do
		local key = utils.get_chars({
			chars_length = 1,
			action_keys = args.action_keys,
			no_dummy_cursor = true,
		})
		vim.cmd("do CursorMoved")
		-- if a number was input -> to be used as count
		-- store this info for the next loop iteration to be used as count
		if tonumber(key) and tonumber(key) > 1 then
			count = tonumber(key) - 1
		end
		if key == "l" then
			local __matches = nil
			if args.direction.left then
				__matches = args.matches
			else
				__matches = args_matches_reversed
			end
			for idx, match in ipairs(__matches) do
				if count and __matches[idx + count] and __matches[idx + count] > picked_match then
					picked_match = __matches[idx + count]
					if picked_match then
						render_cursor(picked_match)
					else
						clear_highlights()
						return
					end
					-- need to remove the count after it has been used
					count = nil
					break
				elseif match > picked_match then
					picked_match = match
					render_cursor(picked_match)
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
			for idx, match in ipairs(__matches) do
				if count and __matches[idx - count] and __matches[idx - count] > picked_match then
					picked_match = __matches[idx + count]
					if picked_match then
						render_cursor(picked_match)
					else
						clear_highlights()
						return
					end
					-- need to remove the count after it has been used
					count = nil
					break
				elseif match < picked_match then
					picked_match = match
					render_cursor(picked_match)
					break
				end
			end
		end
		-- if key == args.actions_keys.accept -> accept the current position
		if key == args.action_keys.accept then
			break
		end
		-- if key == args.actions_keys.escape then don't return a match
		if key == args.action_keys.escape then
			picked_match = nil
			break
		end
	end
	clear_highlights()
	return picked_match
end

return M
