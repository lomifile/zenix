-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- undercurl
vim.cmd([[let &t_Cs = "\e[4:3m]"]])
vim.cmd([[let &t_Ce = "\e[4:3m]"]])

vim.o.winborder = "rounded"
vim.o.pumheight = 12

-- Plain ascending line numbers, right-aligned in a gutter with room to breathe.
-- LazyVim turns relativenumber on; the design this config follows reads the
-- file as a listing rather than as jump distances.
vim.o.relativenumber = false
vim.o.numberwidth = 5
