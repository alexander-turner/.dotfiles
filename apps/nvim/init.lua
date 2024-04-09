-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Include vimrc settings
vim.cmd("source ~/.vimrc")
vim.cmd.colorscheme("catppuccin-latte")

return {

  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-latte",
    },
  },
  { "cmp", name = "tab-completion" },
  -- override nvim-cmp and add cmp-emoji
  {
    "hrsh7th/nvim-cmp",
  },
}
