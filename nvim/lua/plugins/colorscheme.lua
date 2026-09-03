local function palette()
  return require("xcode-zenix.palette")
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "xcode-zenix",
    },
  },
  {
    "folke/tokyonight.nvim",
    enabled = false,
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local c = palette()
      local icons = require("lazyvim.config").icons

      local mode_colour = {
        n = c.steel,
        i = c.cyan,
        v = c.pink,
        V = c.pink,
        ["\22"] = c.pink,
        s = c.pink,
        S = c.pink,
        R = c.salmon,
        c = c.orange,
        t = c.teal,
      }

      local function accent()
        return { fg = mode_colour[vim.fn.mode()] or c.fg_dim }
      end

      -- Chips are built by hand rather than with lualine's `buffers` component:
      -- the dot has to come before the name and change colour on its own, which
      -- that component has no way to express.
      local function buffer_chips()
        local current = vim.api.nvim_get_current_buf()
        local out = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[buf].buflisted and vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            name = name ~= "" and vim.fn.fnamemodify(name, ":t") or "untitled"
            local active = buf == current
            local chip = active and "ZenixTabActive" or "ZenixTabInactive"
            local dot = "ZenixTabDotInactive"
            if vim.bo[buf].modified then
              dot = "ZenixTabDotModified"
            elseif active then
              dot = "ZenixTabDot"
            end
            out[#out + 1] = ("%%#%s# %%#%s#●%%#%s# %s %%#ZenixTabFill#"):format(chip, dot, chip, name)
          end
        end
        return table.concat(out)
      end

      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        theme = "xcode-zenix",
        section_separators = "",
        component_separators = "",
        globalstatus = true,
        disabled_filetypes = {
          statusline = { "dashboard", "alpha", "snacks_dashboard" },
          winbar = { "dashboard", "alpha", "snacks_dashboard", "trouble", "toggleterm" },
        },
      })

      opts.sections = {
        lualine_a = {
          {
            "mode",
            -- A filled chip rather than the default slab: the mode reads as a
            -- badge on the bar, which is what the rest of the chrome does too.
            color = "ZenixMode",
            padding = { left = 2, right = 2 },
          },
        },
        lualine_b = {
          { "branch", icon = "", padding = { left = 1, right = 1 } },
          {
            "diff",
            symbols = { added = "+", modified = "~", removed = "-" },
            diff_color = {
              added = { fg = c.teal },
              modified = { fg = c.orange },
              removed = { fg = c.salmon },
            },
            padding = { left = 0, right = 1 },
          },
        },
        lualine_c = {
          {
            "diagnostics",
            symbols = {
              error = icons.diagnostics.Error,
              warn = icons.diagnostics.Warn,
              info = icons.diagnostics.Info,
              hint = icons.diagnostics.Hint,
            },
          },
          {
            "filename",
            path = 1,
            symbols = { modified = " ●", readonly = " ", unnamed = "untitled" },
            color = { fg = c.fg_dim },
          },
        },
        lualine_x = {
          {
            function()
              local reg = vim.fn.reg_recording()
              return reg ~= "" and ("recording @" .. reg) or ""
            end,
            color = { fg = c.salmon },
          },
          {
            function()
              if vim.v.hlsearch == 0 then return "" end
              local ok, count = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
              if not ok or count.total == 0 then return "" end
              return ("%d/%d"):format(count.current, count.total)
            end,
            color = { fg = c.sand },
          },
          {
            -- The mockup's floating "LSP" pill, moved onto the bar so it never
            -- covers a long line. Dim when nothing is attached to this buffer.
            function()
              return "● LSP"
            end,
            color = function()
              return #vim.lsp.get_clients({ bufnr = 0 }) > 0 and "ZenixLspOn" or "ZenixLspOff"
            end,
            padding = { left = 1, right = 1 },
          },
          {
            -- Always shown, not only when unusual: the bar in the mockup states
            -- the encoding and line ending outright.
            function()
              local enc = vim.bo.fileencoding
              return enc ~= "" and enc or vim.o.encoding
            end,
            color = { fg = c.gutter },
            padding = { left = 1, right = 0 },
          },
          {
            function()
              return ({ unix = "LF", dos = "CRLF", mac = "CR" })[vim.bo.fileformat] or ""
            end,
            color = { fg = c.gutter },
            padding = { left = 1, right = 0 },
          },
        },
        lualine_y = {},
        lualine_z = {
          {
            function()
              local line, col = unpack(vim.api.nvim_win_get_cursor(0))
              return ("Ln %d, Col %d"):format(line, col + 1)
            end,
            color = { fg = c.gutter },
            padding = { left = 1, right = 2 },
          },
        },
      }

      -- Row 1: the title bar. Neovim has one tabline, so it holds the window
      -- title and the buffer chips live in the winbar below it.
      opts.tabline = {
        lualine_a = {
          {
            function() return "●" end,
            color = "ZenixTitleDot",
            padding = { left = 2, right = 1 },
          },
          { function() return "nvim" end, color = "ZenixTitle", padding = { right = 1 } },
          { function() return "│" end, color = "ZenixTitleSep", padding = 0 },
          {
            function()
              return vim.fn.fnamemodify(vim.uv.cwd() or "", ":~")
            end,
            color = "ZenixTitleDim",
            padding = { left = 1, right = 1 },
          },
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      }

      -- Row 2: buffer chips, or the panel's name over a sidebar. One component
      -- for both because the winbar is per-window and the sidebar is a window.
      local winbar = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
          {
            function()
              if vim.bo.filetype == "neo-tree" then
                return "%#ZenixExplorer#  EXPLORER"
              end
              return buffer_chips()
            end,
            padding = 0,
          },
        },
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      }
      opts.winbar = winbar
      opts.inactive_winbar = winbar

      opts.inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { "filename", path = 1, color = { fg = c.gutter } } },
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      }

      return opts
    end,
  },
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        -- snacks generates a lazygit theme from highlight groups and appends it
        -- to LG_CONFIG_FILE, so it overrides the gui.theme in
        -- lazygit/config.yml. Its defaults point inactiveBorderColor at
        -- FloatBorder, which this colorscheme sets to a near-background hairline
        -- for rounded popups -- invisible as a panel border. These map to groups
        -- that exist to be read here, so both lazygits look the same.
        theme = {
          [241] = { fg = "LazygitMuted" },
          activeBorderColor = { fg = "LazygitActiveBorder", bold = true },
          inactiveBorderColor = { fg = "LazygitInactiveBorder" },
          optionsTextColor = { fg = "LazygitInactiveBorder" },
          searchingActiveBorderColor = { fg = "LazygitSearchBorder", bold = true },
          cherryPickedCommitFgColor = { fg = "LazygitCherryPickFg" },
          cherryPickedCommitBgColor = { fg = "LazygitCherryPickBg" },
          selectedLineBgColor = { bg = "Visual" },
          defaultFgColor = { fg = "Normal" },
          unstagedChangesColor = { fg = "DiagnosticError" },
        },
      },
    },
  },
  {
    -- The tabline is the title bar now and the buffer chips are drawn in the
    -- winbar by lualine, so bufferline has nothing left to render. LazyVim's
    -- core <S-h>/<S-l> fall back to :bprevious/:bnext on their own.
    "akinsho/bufferline.nvim",
    enabled = false,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      close_if_last_window = true,
      popup_border_style = "single",
      window = {
        width = 32,
        mappings = { ["<space>"] = "none" },
      },
      default_component_configs = {
        indent = {
          indent_size = 2,
          padding = 1,
          with_markers = true,
          indent_marker = "│",
          last_indent_marker = "└",
          with_expanders = true,
          expander_collapsed = "▸",
          expander_expanded = "▾",
          expander_highlight = "NeoTreeExpander",
        },
        icon = {
          folder_closed = "",
          folder_open = "",
          folder_empty = "",
          default = "",
          highlight = "NeoTreeFileIcon",
          provider = function(icon, node)
            icon.text = ""
            icon.highlight = node.type == "directory" and "NeoTreeDirectoryIcon" or "NeoTreeFileIcon"
            return icon
          end,
        },
        modified = { symbol = "●" },
        name = { trailing_slash = false, use_git_status_colors = false },
        git_status = {
          symbols = {
            added = "A",
            modified = "M",
            deleted = "D",
            renamed = "R",
            untracked = "?",
            ignored = "",
            unstaged = "",
            staged = "",
            conflict = "!",
          },
        },
      },
      filesystem = {
        use_libuv_file_watcher = true,
        -- The root line is the cwd, which neo-tree prints in full. The panel is
        -- 32 columns wide, so anything but the last component is truncated
        -- noise. Components are merged per source, not globally, so this has to
        -- live under `filesystem` rather than at the top level.
        components = {
          name = function(config, node, state)
            local result = require("neo-tree.sources.common.components").name(config, node, state)
            if node:get_depth() == 1 then
              result.text = vim.fn.fnamemodify(result.text, ":t") .. "/"
            end
            return result
          end,
        },
        window = {
          mappings = { ["<space>"] = "none" },
        },
      },
    },
  },
}
