local cmp = require("cmp")

cmp.setup({
  -- You can set other general options here
  -- Configure sources and other settings
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
  }),
  mapping = {
    ["<tab>"] = cmp.mapping.confirm({ select = true }),
    -- ["<CR>"] = cmp.mapping.abort(),
  },
})

return {}
