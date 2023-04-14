local M = {}

local api = vim.api

--- gets match position based on opts
---@param args table options which affect the position determination for the next match.
---@return nil|number target match position
function M.get_match(args)
	vim.validate({
		str_matches = { args.str_matches, "table" },
		match_direction = { args.match_direction, "table" },
	})
	if not args.match_direction.left and not args.match_direction.right then
		vim.notify("find-extender: get_match::~ no direction value provided")
		return
	end

	local cursor_position = api.nvim_win_get_cursor(0)[2] + 1 -- this api was 0 indexed
	local match_value = nil
	if args.match_direction.left then
		for _, match_position in ipairs(args.str_matches) do
			if cursor_position < match_position then
				match_value = match_position
				break
			end
		end
	end

	if args.match_direction.right then
		for _, match_position in ipairs(args.str_matches) do
			if cursor_position > match_position then
				match_value = match_position
				break
			end
		end
	end

	return match_value
end

return M
