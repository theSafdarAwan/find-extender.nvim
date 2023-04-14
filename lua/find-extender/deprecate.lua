local M = {}

M.old_syntax = function(config)
	if config.timeout or config.chars_lenght or config.enable or config.keymaps and config.keymaps.modes then
		vim.defer_fn(function()
			vim.notify(
				"find-extender: Please refer to the `https://github.com/TheSafdarAwan/find-extender.nvim`. This syntax for config has been deprecated.",
				vim.log.levels.WARN,
				{}
			)
		end, 0)
	end
end

return M
