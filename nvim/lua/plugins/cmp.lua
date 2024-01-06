local cmp = require("cmp")

cmp.setup({
  -- You can set other general options here

  mapping = {
    -- Other key mappings for nvim-cmp
    ["<CR>"] = function(fallback)
      fallback() -- This will just execute the default action, which is typically inserting a newline
    end,

    -- Override the Shift+Tab key to accept the current suggestion
    ["<S-Tab>"] = cmp.mapping.confirm({ select = true }),

    -- Example of mapping the Tab key to select the next item
    ["<Tab>"] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end,
  },

  -- Configure sources and other settings
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
  }),
})

return {}
