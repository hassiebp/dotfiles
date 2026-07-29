local function toggle_octo_review()
  local reviews = require("octo.reviews")
  local current_review = reviews.get_current_review()

  if current_review then
    reviews.close(vim.api.nvim_get_current_tabpage())
  else
    reviews.start_or_resume_review()
  end
end

local function octo_search_current_repo(query)
  local repo = require("octo.utils").get_remote_name()
  if not repo then
    vim.notify("No git remote found for Octo search", vim.log.levels.ERROR)
    return
  end

  vim.cmd("Octo search repo:" .. repo .. " " .. query)
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gd", false },
      { "<leader>gD", false },
      { "<leader>gp", false },
      { "<leader>gI", false },
      { "<leader>gP", false },
      { "<leader>gS", false },
    },
  },

  -- Octo: GitHub issues, PRs, and reviews inside Neovim
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    keys = {
      { "<leader>go", "<cmd>Octo<cr>", desc = "Octo actions" },
      {
        "<leader>gp",
        function()
          octo_search_current_repo("is:pr is:open author:hassiebp")
        end,
        desc = "My open PRs",
      },
      { "<leader>gP", "<cmd>Octo pr list<cr>", desc = "All open PRs" },
      { "<leader>gI", "<cmd>Octo issue list<cr>", desc = "GitHub issues" },
      { "<leader>gN", "<cmd>Octo notification list<cr>", desc = "GitHub notifications" },
      {
        "<leader>gv",
        toggle_octo_review,
        desc = "Toggle PR review",
      },
      {
        "<leader>gS",
        function()
          require("octo.utils").create_base_search_command({ include_current_repo = true })
        end,
        desc = "Search GitHub",
      },
    },
    opts = {
      enable_builtin = true,
      picker = "snacks",
      default_remote = { "origin", "upstream" },
      reviews = {
        auto_show_threads = true,
        focus = "right",
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "folke/snacks.nvim",
    },
  },

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
            vim.cmd("DiffviewOpen origin/main...HEAD")
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
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = false,
        delay = 300,
      },
      current_line_blame_formatter = "<author>, <author_time:%R>",
      current_line_blame_formatter_nc = "Not committed yet",
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
