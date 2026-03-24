-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Tab/indent settings (override LazyVim defaults of 2)
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.copyindent = true
vim.opt.preserveindent = true

-- Scrolling
vim.opt.scrolloff = 3
vim.opt.wrap = true

-- Copy selected text to system clipboard
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Copy to clipboard" })

-- File-type specific indentation
vim.api.nvim_create_autocmd("FileType", {
  pattern = "html",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "text",
  callback = function()
    vim.opt_local.textwidth = 78
  end,
})
