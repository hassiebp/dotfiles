-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable LSP root detection as this would 'Find files' to be scoped to monorepo package instead of current working directory (cwd)
vim.g.root_spec = { { ".git", "lua" }, "cwd" }

-- Wrap lines
vim.opt.wrap = true
