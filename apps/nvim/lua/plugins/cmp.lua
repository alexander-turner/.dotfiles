local cmp = require("cmp")

cmp.setup({
  -- You can set other general options here
  -- Configure sources and other settings
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "copilot", group_index = 2 },
    {
      name = "zbirenbaum/copilot-cmp",
      config = function()
        require("copilot_cmp").setup()
      end,
    },
  }),
  mapping = {
    ["<tab>"] = cmp.mapping.confirm({ select = true }),
    -- ["<CR>"] = cmp.mapping.abort(),
  },
})

return {}
