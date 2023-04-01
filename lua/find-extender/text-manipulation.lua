local M = {}

local api = vim.api
local fn = vim.fn

local utils = require("find-extender.utils")

--- manipulates text and puts information to the register
---@param node_info table target node information to which the text manipulation should be done.
---@param type table type of the text manipulation action change/delete/yank.
---@param opts table options
function M.manipulate_text(node_info, type, opts)
	local current_line = api.nvim_get_current_line()
	local register = vim.v.register
	local get_cursor = api.nvim_win_get_cursor(0)

	local node = node_info.node
	local node_pos_direction = node_info.node_direction

	if not node then
		return
	end

	local start
	local finish
	if node_pos_direction.right then
		start = node + 1
		finish = get_cursor[2] + 1
	elseif node_pos_direction.left then
		start = get_cursor[2]
		finish = node + 2
	end
	if get_cursor[2] == 0 and node == 1 and node_info.threshold == 2 then
		return
	end
	local in_range_str = string.sub(current_line, start, finish - 1)
	if type.delete or type.change then
		-- substitute the remaining line from the cursor position till the
		-- next target position
		local remaining_line = utils.get_remaining_str(current_line, start, finish)
		-- replace the current line with the remaining line
		api.nvim_buf_set_lines(0, get_cursor[1] - 1, get_cursor[1], false, { remaining_line })
		-- if we substitute from right to left the cursor resets to the end
		-- of the line after line gets swapped so we have to get the cursor
		-- position and then set it to the appropriate position
		if node_pos_direction.right then
			get_cursor[2] = get_cursor[2] - #in_range_str + 1
			api.nvim_win_set_cursor(0, get_cursor)
		end
		-- in case of change text start insert after the text gets deleted
		if type.change then
			api.nvim_command("startinsert")
		end
	end

	local highlight_on_yank = opts.highlight_on_yank
	-- highlight's the yanked area
	if type.yank and highlight_on_yank.enable then
		require("find-extender.utils").on_yank(highlight_on_yank, start, finish - 1)
	end

	-- NOTE: we are doing this text substitution using lua string.sub which
	-- isn't same as the nvim's delete or change so we have to adjust how
	-- much characters we got into our register in some case we have to sometimes
	-- discard one character.
	if get_cursor[2] == 0 then
		in_range_str = string.sub(in_range_str, 1, #in_range_str)
	else
		in_range_str = string.sub(in_range_str, 2, #in_range_str)
	end
	fn.setreg(register, in_range_str)
end

return M
