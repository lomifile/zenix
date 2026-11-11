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
    keys = {
      {
        "<leader>sj",
        function()
          require("util.jsonfly_fzf").open()
        end,
        desc = "Open json(fly)",
        ft = { "json", "jsonc", "yaml" },
      },
    },
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
}
