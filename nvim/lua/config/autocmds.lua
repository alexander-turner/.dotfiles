-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_augroup("AutoReloadConfig", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  group = "AutoReloadConfig",
  pattern = "../plugins/cmp.lua",
  command = "source ../plugins/cmp.lua",
})
