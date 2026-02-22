return {
  -- Diffview: PR-style diff viewer with file tree navigation
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      {
        "<leader>gd",
        function()
          local lib = require("diffview.lib")
          local view = lib.get_current_view()
          if view then
            -- Already in diffview, close it
            vim.cmd("DiffviewClose")
          elseif #lib.views > 0 then
            -- Diffview open in another tab, focus it
            local dv = lib.views[1]
            vim.api.nvim_set_current_tabpage(dv.tabpage)
          else
            -- No diffview open, create one
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Toggle diff working tree",
      },
      {
        "<leader>gD",
        function()
          local lib = require("diffview.lib")
          local view = lib.get_current_view()
          if view then
            vim.cmd("DiffviewClose")
          elseif #lib.views > 0 then
            local dv = lib.views[1]
            vim.api.nvim_set_current_tabpage(dv.tabpage)
          else
            vim.cmd("DiffviewOpen origin/main")
          end
        end,
        desc = "Toggle diff against main (PR view)",
      },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = { layout = "diff2_horizontal" },
        merge_tool = { layout = "diff3_mixed" },
      },
    },
  },

  -- Enhanced gitsigns with hunk navigation
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      on_attach = function(buffer)
        local gs = require("gitsigns")
        local map = vim.keymap.set

        -- Navigate hunks (changes)
        map("n", "]h", function()
          gs.nav_hunk("next")
        end, { buffer = buffer, desc = "Next hunk" })
        map("n", "[h", function()
          gs.nav_hunk("prev")
        end, { buffer = buffer, desc = "Prev hunk" })

        -- Hunk actions
        map("n", "<leader>hs", gs.stage_hunk, { buffer = buffer, desc = "Stage hunk" })
        map("n", "<leader>hr", gs.reset_hunk, { buffer = buffer, desc = "Reset hunk" })
        map("n", "<leader>hp", gs.preview_hunk, { buffer = buffer, desc = "Preview hunk" })
        map("n", "<leader>hb", function()
          gs.blame_line({ full = true })
        end, { buffer = buffer, desc = "Blame line" })
      end,
    },
  },
}
