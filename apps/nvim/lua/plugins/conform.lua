return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      fish = { "fish_indent" },
      lua = { "stylua" },
      python = { "ruff_format" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
      xml = { "xmllint" },
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
    },
  },
}
