-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- Bufferline override of LazyVim defaults of using "L" and "H"
map("n", "<tab>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next Buffer" })
map("n", "<S-tab>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev Buffer" })

map("i", "jk", "<ESC>", { desc = "Easier escape" })
map("i", "kj", "<ESC>", { desc = "Easier escape" })
map("n", ";", ":", { desc = "CMD enter command mode" })

map("n", "L", "$", { desc = "Jump to line end" })
map("n", "H", "^", { desc = "Jump to line start" })
map("i", "<C-l>", "<Right>", { desc = "Move cursor right in insert mode" })
map("i", "<C-h>", "<Left>", { desc = "Move cursor left in insert mode" })

map("v", "<", "<gv", { desc = "Better indenting" })
map("v", ">", ">gv", { desc = "Better indenting" })

map("v", "p", '"_dP', { desc = "Paste without losing register" })

map("n", "<leader>cP", '<cmd>let @+ = expand("%")<CR>', { desc = "Copy file path" })
map("n", "<leader>cp", '<cmd>let @+ = expand("%:.")<CR>', { desc = "Copy relative path" })

map("n", "<leader>fa", function()
  require("snacks").picker.files({
    hidden = true,
    ignored = true,
    follow = true,
  })
end, { desc = "Find all files (hidden + ignored)" })
