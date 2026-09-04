return {
  {
    "LazyVim/LazyVim",
    opts = {},
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = true,
        },
      },
    },
  },
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    opts = function(_, _opts)
      local fzf = require("fzf-lua")
      local actions = fzf.actions
      return {
        files = {
          cwd_prompt = false,
          actions = {
            ["ctrl-i"] = { actions.toggle_ignore },
            ["ctrl-h"] = { actions.toggle_hidden },
          },
        },
        grep = {
          actions = {
            ["ctrl-i"] = { actions.toggle_ignore },
            ["ctrl-h"] = { actions.toggle_hidden },
          },
        },
      }
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "https://git.myzel394.app/Myzel394/jsonfly.nvim",
    },
    opts = {
      defaults = {
        prompt_prefix = "󰍉  ",
        selection_caret = "▍ ",
        entry_prefix = "  ",
        multi_icon = "✓ ",
        sorting_strategy = "ascending",
        results_title = false,
        dynamic_preview_title = true,
        borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = { width = 0.86, height = 0.8, preview_width = 0.55, prompt_position = "top" },
          vertical = { width = 0.7, height = 0.85, preview_height = 0.5, prompt_position = "top" },
        },
        winblend = 0,
      },
    },
    keys = {
      {
        "<leader>sj",
        "<cmd>Telescope jsonfly<cr>",
        desc = "Open json(fly)",
        ft = { "json", "xml", "yaml" },
        mode = "n",
      },
    },
  },
}
