local M = {}

local api = vim.api
local utils = require("find-extender.utils")
local valid_node = utils.node_validation

--- gets node position based on opts
---@param opts table options which affect the position determination for the next node.
---@return number target node position
function M.get_node(opts)
	local get_cursor = api.nvim_win_get_cursor(0)
	local current_line = api.nvim_get_current_line()
	local string_nodes = utils.map_string_nodes(current_line, opts.pattern)

	local cursor_position = get_cursor[2]
	local node_value = nil
	-- in cases of node in the start of the line and node in the end of the
	-- line we need to reset the threshold
	local reset_threshold = false
	-- node_direction is to know which direction to search in
	if opts.node_direction.left then
		for node_position, node in ipairs(string_nodes) do
			if cursor_position + opts.threshold < node or cursor_position < 1 and node < 3 then
				if opts.threshold > 1 and valid_node(node, current_line) and not opts.count then
					reset_threshold = true
				end

				if opts.count then
					node_value = string_nodes[node_position + opts.count - 1]
				else
					node_value = node
				end
				break
			end
		end
	end

	if opts.node_direction.right then
		-- need to reverse the tbl of the string_nodes because now we have to
		-- start searching from the end of the string rather then from the start
		string_nodes = utils.reverse_tbl(string_nodes)
		for node_position, node in ipairs(string_nodes) do
			if cursor_position - opts.threshold == node or cursor_position - opts.threshold > node then
				if opts.threshold > 1 and valid_node(node, current_line) then
					reset_threshold = true
				end

				if opts.count then
					local n = string_nodes[node_position + opts.count - 1]
					-- need to reset the threshold here because previous
					-- guard wasn't for this x node
					if opts.threshold > 1 and valid_node(n, current_line) then
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
			opts.threshold = 1
		end
		target_node = node_value - opts.threshold
	end
	return target_node
end

return M
