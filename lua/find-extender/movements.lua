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
	local i = 1
	for _, match in ipairs(args.matches) do
		local extmark_opts = {
			virt_text = { { string.sub(args.symbols, i, i), "FEVirtualText" } },
			virt_text_pos = "overlay",
			hl_mode = "combine",
			priority = 105,
		}
		api.nvim_buf_set_extmark(buf_nr, ns_id, line_nr - 1, match - args.virt_hl_length, extmark_opts)
		i = i + 1
	end
	api.nvim_create_autocmd({ "CursorMoved" }, {
		once = true,
		callback = function()
			api.nvim_buf_clear_namespace(buf_nr, ns_id, 0, -1)
		end,
	})
	-- TODO: ??
	picked_match = utils.get_chars({ chars_length = 1 })
	if picked_match then
		local match_pos = string.find(args.symbols, picked_match)
		picked_match = args.matches[match_pos]
	end
	vim.cmd("silent! do CursorMoved")

	return picked_match
end

--- lh movement
---@param args table
---@return number|nil picked match
M.lh = function(args)
	local buf_nr = api.nvim_get_current_buf()
	local cursor_pos = api.nvim_win_get_cursor(0)
	local line_nr = fn.line(".")
	local ns_id = api.nvim_create_namespace("FElhMatchesHihglight")
	-- this table of matches is for the use of h key for backward movmenet,
	-- because we mapped the string from left to right in case of the h key it
	-- will break the loop on the first match, that why we have to reverse this table.
	local args_matches_reversed = utils.reverse_tbl(args.matches)

	for _, match in ipairs(args.matches) do
		api.nvim_buf_add_highlight(buf_nr, ns_id, "FEVirtualText", line_nr - 1, match - 1, match + args.virt_hl_length)
	end

	local lh_cursor_ns = api.nvim_create_namespace("FElhCursor")
	local function render_and_set_cursor(match)
		-- set cursor
		utils.set_cursor(match)
		-- need to add the cursor highlight at the exact location relative to the key type
		local threshold = nil
		if args.key_type.find then
			threshold = 1
		elseif args.key_type.till then
			threshold = 2
		end
		api.nvim_buf_clear_namespace(buf_nr, lh_cursor_ns, 0, -1)
		local cur_line = vim.api.nvim_get_current_line()
		local text = string.sub(cur_line, match, match)
		local extmark_opts = {
			virt_text = { { text, "FECurrentMatchCursor" } },
			virt_text_pos = "overlay",
			hl_mode = "combine",
			priority = 105,
		}
		api.nvim_buf_set_extmark(buf_nr, lh_cursor_ns, line_nr - 1, match - threshold, extmark_opts)
	end

	-- clear all the highlights and resets the cursor to the original position
	local function clear_highlights_and_reset_cursor()
		-- reset cursor position
		utils.set_cursor(cursor_pos[2])
		-- clear highlights
		api.nvim_buf_clear_namespace(buf_nr, ns_id, 0, -1)
		api.nvim_buf_clear_namespace(buf_nr, lh_cursor_ns, 0, -1)
	end

	-- need to remove the dummy cursor set by the find command input
	utils.wait(function()
		vim.cmd("do CursorMoved")
	end)

	local picked_match = nil
	-- for the first loop iteration use the cursor position as the picked match
	picked_match = cursor_pos[2] + 1 -- nvim_win_get_cursor api i 0 indexed

	-- if count was given in the lh movement
	local count = nil
	while true do
		render_and_set_cursor(picked_match)
		-- get input
		local key = utils.get_chars({
			chars_length = 1,
			action_keys = args.action_keys,
			no_dummy_cursor = true,
		})
		-- get out of loop if previously count was provided but now no `l|h` movement
		-- key is provided
		if count and key ~= "l" and key ~= "h" then
			clear_highlights_and_reset_cursor()
			return
		end
		-- if picked match was invalid in the previous iteration then return
		if not picked_match then
			clear_highlights_and_reset_cursor()
			return
		end
		-- if a number was input -> to be used as count
		-- store this info for the next loop iteration to be used as count
		local key_as_count = tonumber(key)
		if key_as_count then
			count = key_as_count
		end
		if key == "l" then
			local __matches = args.matches
			for idx, match in ipairs(__matches) do
				if count and match > picked_match then
					-- also need to skip the current cursor position
					count = count - 1
					picked_match = __matches[idx + count]
					-- need to remove the count after it has been used
					count = nil
					break
				end
				if not count and match > picked_match then
					picked_match = match
					break
				end
			end
		end
		if key == "h" then
			local __matches = args_matches_reversed
			for idx, match in ipairs(__matches) do
				if count and match < picked_match then
					picked_match = __matches[idx + count - 1]
					-- need to remove the count after it has been used
					count = nil
					break
				end
				if not count and match < picked_match then
					picked_match = match
					break
				end
			end
		end
		-- if key == args.actions_keys.accept -> accept the current position
		if fn.char2nr(key) == args.action_keys.accept then
			break
		end
		-- if key == args.actions_keys.escape then don't return a match
		if fn.char2nr(key) == args.action_keys.escape then
			picked_match = nil
			break
		end
	end
	clear_highlights_and_reset_cursor()
	return picked_match
end

return M
