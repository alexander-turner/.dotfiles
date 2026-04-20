-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Copy selected text to system clipboard
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Copy to clipboard" })
