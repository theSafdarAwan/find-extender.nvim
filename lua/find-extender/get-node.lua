local M = {}

local api = vim.api
local utils = require("find-extender.utils")

--- check if string till the node has has characters or not
---@param end_pos number string end position till which we have to sub string
---@param current_line string current line
---@return boolean|nil
local string_sanity = function(end_pos, current_line)
	local s = string.sub(current_line, 1, end_pos)
	return utils.string_has_chars(s)
end

--- gets node position based on opts
---@param args table options which affect the position determination for the next node.
---@return nil|number target node position
function M.get_node(args)
	vim.validate({
		node_direction = { args.node_direction, "table" },
		threshold = { args.threshold, "number" },
		count = { args.count, { "number", "nil" } },
		pattern = { args.pattern, "string" },
	})
	if not args.node_direction.left and not args.node_direction.right then
		vim.notify("find-extender: get_node::~ no direction value provided")
		return
	end

	local current_line = api.nvim_get_current_line() -- current line string
	local string_nodes = utils.map_string_pattern_positions(current_line, args.pattern)
	local cursor_position = api.nvim_win_get_cursor(0)[2] + 1 -- this api was 0 indexed
	local node_value = nil
	if args.node_direction.left then
		for node_idx, node_position in ipairs(string_nodes) do
			if cursor_position < node_position then
				if args.count then
					node_value = string_nodes[node_idx + args.count - 1]
				else
					node_value = node_position
				end
				-- need to deal with till command if the node is in the start of the line
				if args.threshold > 1 and not string_sanity(node_value - 1, current_line) then
					args.threshold = 1
				end
				break
			end
		end
	end

	if args.node_direction.right then
		-- need to reverse the tbl of the string_nodes because now we have to
		-- start searching from the end of the string rather then from the start
		string_nodes = utils.reverse_tbl(string_nodes)
		for node_idx, node_position in ipairs(string_nodes) do
			if cursor_position > node_position then
				if args.count then
					local node = string_nodes[node_idx + args.count - 1]
					node_value = node
				else
					node_value = node_position
				end
				if not string_sanity(node_value - 1, current_line) then
					args.threshold = 1
				end
				break
			end
		end
	end

	if node_value then
		node_value = node_value - args.threshold
	end
	return node_value
end

return M
