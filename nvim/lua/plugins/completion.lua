return {
  {
    "saghen/blink.cmp",
    opts = {
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        menu = {
          border = "rounded",
          scrolloff = 1,
          scrollbar = false,
          draw = {
            padding = 1,
            gap = 2,
            columns = {
              { "kind_icon" },
              { "label", gap = 1 },
              { "label_description" },
            },
            components = {
              kind_icon = {
                text = function(ctx)
                  return ctx.kind_icon .. " "
                end,
                highlight = function(ctx)
                  return "BlinkCmpKind" .. ctx.kind
                end,
              },
              label_description = {
                text = function(ctx)
                  return ctx.label_description or ""
                end,
                highlight = "BlinkCmpLabelDescription",
              },
            },
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = {
            border = "rounded",
            max_width = 72,
            max_height = 20,
          },
        },
        ghost_text = { enabled = true },
      },
      signature = {
        enabled = true,
        window = { border = "rounded" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        float = {
          border = "rounded",
          source = true,
          header = "",
          prefix = "",
        },
      },
    },
  },
}
