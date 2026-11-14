-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.opt.guicursor = "a:block"

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(args)
    if vim.bo[args.buf].filetype == "" then
      vim.bo[args.buf].filetype = "terminal"
    end
  end,
})

-- The sidebar's panel label. This used to ride on lualine's winbar, but winbar
-- is per-window, so the buffer chips sharing that bar were redrawn once per
-- split. The chips moved to the tabline; the label stays per-window, because
-- naming the panel a window holds is genuinely per-window information.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function()
    vim.opt_local.winbar = "%#ZenixExplorer#  EXPLORER"
  end,
})
