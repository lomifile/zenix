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
