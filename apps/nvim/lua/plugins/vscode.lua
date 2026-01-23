-- Disable LSP features that conflict with VSCode
if vim.g.vscode then
  return {
    -- Disable LazyVim's LSP document highlighting in VSCode
    {
      "neovim/nvim-lspconfig",
      opts = {
        -- Disable document highlighting which uses clear_references
        document_highlight = {
          enabled = false,
        },
      },
    },
  }
else
  return {}
end
