-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Include vimrc settings
vim.cmd("source ~/.vimrc")

-- Only set up LSP when not in VSCode
if not vim.g.vscode then
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "fish",
    callback = function()
      vim.lsp.start({
        name = "fish-lsp",
        cmd = { "fish-lsp", "start" },
        cmd_env = { fish_lsp_show_client_popups = false },
      })
    end,
  })
end
