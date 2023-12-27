-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Include vimrc settings
vim.cmd("source ~/.vimrc")

return {

	{ "catppuccin/nvim", name = "catppuccin", priority = 1000 },
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin-latte",
		},
	},
}
