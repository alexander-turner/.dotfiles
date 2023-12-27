-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
-- Include vimrc settings
vim.cmd("source ~/.vimrc")

return {
  { 'numToStr/Comment.nvim', lazy = false, },

  -- add gruvbox
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-latte",
    },
  },
}
