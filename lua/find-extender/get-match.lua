local M = {}

local api = vim.api
local utils = require("find-extender.utils")

--- check if string till the match has has characters or not
---@param end_pos number string end position till which we have to sub string
---@param str string current line
---@return boolean|nil
local string_sanity = function(str, end_pos)
	local s = string.sub(str, 1, end_pos)
	return utils.string_has_chars(s)
end

--- gets match position based on opts
---@param args table options which affect the position determination for the next match.
---@return nil|number target match position
function M.get_match(args)
	vim.validate({
		str_matches = { args.str_matches, "table" },
		match_direction = { args.match_direction, "table" },
		threshold = { args.threshold, "number" },
		pattern = { args.pattern, "string" },
	})
	if not args.match_direction.left and not args.match_direction.right then
		vim.notify("find-extender: get_match::~ no direction value provided")
		return
	end

	local str = api.nvim_get_current_line()
	local cursor_position = api.nvim_win_get_cursor(0)[2] + 1 -- this api was 0 indexed
	local match_value = nil
	if args.match_direction.left then
		for _, match_position in ipairs(args.str_matches) do
			if cursor_position < match_position then
				match_value = match_position
				-- need to deal with till command if the match is in the start of the line
				if args.threshold > 1 and not string_sanity(str, match_value - 1) then
					args.threshold = 1
				end
				break
			end
		end
	end

	if args.match_direction.right then
		for _, match_position in ipairs(args.str_matches) do
			if cursor_position > match_position then
				match_value = match_position
				if not string_sanity(str, match_value - 1) then
					args.threshold = 1
				end
				break
			end
		end
	end

	if match_value then
		match_value = match_value - args.threshold
	end
	return match_value
end

return M
