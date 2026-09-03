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
    -- noice takes over textDocument/hover, so it renders `K` in its own nui
    -- popup and never reaches vim.lsp.util.open_floating_preview below. Its
    -- default hover view is borderless with NoicePopup colours; point it at the
    -- rounded border and BlinkCmpDoc* groups the suggestion box already uses.
    "folke/noice.nvim",
    opts = {
      views = {
        hover = {
          border = { style = "rounded", padding = { 0, 1 } },
          position = { row = 2, col = 0 },
          size = { max_width = 72, max_height = 20 },
          win_options = {
            winhighlight = {
              Normal = "BlinkCmpDoc",
              FloatBorder = "BlinkCmpDocBorder",
            },
          },
        },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    init = function()
      -- Everything noice does not intercept -- diagnostic floats, :LspInfo,
      -- signature help when blink hands it back -- still opens a plain
      -- NormalFloat window. Give those the same border, size caps and
      -- BlinkCmpDoc* groups as the hover view above.
      local open_floating_preview = vim.lsp.util.open_floating_preview
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
        opts = vim.tbl_deep_extend("keep", opts or {}, {
          border = "rounded",
          max_width = 72,
          max_height = 20,
          wrap = true,
        })

        local bufnr, winnr = open_floating_preview(contents, syntax, opts, ...)
        if winnr and vim.api.nvim_win_is_valid(winnr) then
          vim.wo[winnr].winhighlight = "NormalFloat:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder"
          vim.wo[winnr].winblend = 0
        end
        return bufnr, winnr
      end
    end,
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
