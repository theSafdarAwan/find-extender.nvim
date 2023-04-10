local M = {}

local api = vim.api
local utils = require("find-extender.utils")
local valid_pos = utils.valid_pos

--- gets node position based on opts
---@param args table options which affect the position determination for the next node.
---@return nil|number target node position
function M.get_node(args)
	vim.validate({
		node_direction = { args.node_direction, "table" },
		threshold = { args.threshold, "number" },
		count = { args.count, "number" },
		pattern = { args.pattern, "string" },
	})
	if not args.node_direction.left and not args.node_direction.right then
		vim.notify("find-extender: get_node> no direction value provided")
		return
	end

	local current_line = api.nvim_get_current_line() -- current line string
	local string_nodes = utils.map_string_pattern_positions(current_line, args.pattern)
	local cursor_position = api.nvim_win_get_cursor(0)[2] -- 0 indexed
	local node_value = nil
	-- in cases of node in the start of the line and node in the end of the
	-- line we need to reset the threshold
	local reset_threshold = false
	-- node_direction is to know which direction to search in
	if args.node_direction.left then
		for node_idx, node_pos in ipairs(string_nodes) do
			if node_pos > cursor_position + args.threshold or cursor_position < 1 and node_pos < 3 then
				if args.threshold > 1 and valid_pos(node_pos, current_line) and not args.count then
					reset_threshold = true
				end

				if args.count then
					node_value = string_nodes[node_idx + args.count - 1]
				else
					node_value = node_pos
				end
				break
			end
		end
	end

	if args.node_direction.right then
		-- need to reverse the tbl of the string_nodes because now we have to
		-- start searching from the end of the string rather then from the start
		string_nodes = utils.reverse_tbl(string_nodes)
		for node_position, node in ipairs(string_nodes) do
			if cursor_position - args.threshold == node or cursor_position - args.threshold > node then
				if args.threshold > 1 and valid_pos(node, current_line) then
					reset_threshold = true
				end

				if args.count then
					local n = string_nodes[node_position + args.count - 1]
					-- need to reset the threshold here because previous
					-- guard wasn't for this x node
					if args.threshold > 1 and valid_pos(n, current_line) then
						reset_threshold = true
					end
					node_value = n
				else
					node_value = node
				end
				break
			end
		end
	end

	local target_node = nil
	if node_value then
		if reset_threshold then
			args.threshold = 1
		end
		target_node = node_value - args.threshold
	end
	return target_node
end

return M
