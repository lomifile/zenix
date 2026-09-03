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

      local scrollbar = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        theme = "xcode-zenix",
        section_separators = "",
        component_separators = "",
        globalstatus = true,
        disabled_filetypes = { statusline = { "dashboard", "alpha", "snacks_dashboard" } },
      })

      opts.sections = {
        lualine_a = {
          { function() return "▍" end, color = accent, padding = { left = 1, right = 0 } },
          {
            "mode",
            fmt = function(str) return str:sub(1, 1) .. str:sub(2):lower() end,
            color = accent,
            padding = { left = 1, right = 1 },
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
            function()
              local names = {}
              for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
                names[#names + 1] = client.name
              end
              return table.concat(names, " ")
            end,
            color = { fg = c.gutter },
          },
          {
            function()
              local enc = vim.bo.fileencoding
              return (enc ~= "" and enc ~= "utf-8") and enc or ""
            end,
            color = { fg = c.orange },
          },
          {
            function()
              return vim.bo.fileformat ~= "unix" and vim.bo.fileformat or ""
            end,
            color = { fg = c.orange },
          },
          {
            function()
              local label = vim.bo.expandtab and "Spaces" or "Tab Size"
              local width = vim.bo.shiftwidth
              if width == 0 then width = vim.bo.tabstop end
              return label .. ": " .. width
            end,
            color = { fg = c.gutter },
          },
        },
        lualine_y = {
          {
            function()
              return vim.bo.filetype ~= "" and vim.bo.filetype or "plain text"
            end,
            color = { fg = c.comment },
          },
        },
        lualine_z = {
          {
            function()
              local line, col = unpack(vim.api.nvim_win_get_cursor(0))
              return ("Ln %d, Col %d"):format(line, col + 1)
            end,
            color = { fg = c.fg_dim },
            padding = { left = 1, right = 1 },
          },
          {
            function()
              local current = vim.fn.line(".")
              local total = math.max(vim.fn.line("$"), 1)
              local index = math.floor((current - 1) / total * #scrollbar) + 1
              return scrollbar[math.min(index, #scrollbar)]
            end,
            color = accent,
            padding = { left = 0, right = 1 },
          },
        },
      }

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
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        separator_style = { "│", "│" },
        indicator = { style = "none" },
        show_buffer_icons = false,
        show_buffer_close_icons = false,
        show_close_icon = false,
        always_show_bufferline = true,
        modified_icon = "●",
        max_name_length = 30,
        offsets = {
          {
            filetype = "neo-tree",
            text = "FOLDERS",
            highlight = "NeoTreeRootName",
            text_align = "left",
            separator = false,
          },
        },
      },
    },
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
        window = {
          mappings = { ["<space>"] = "none" },
        },
      },
    },
  },
}
