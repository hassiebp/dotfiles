return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local function git_blame()
        return vim.trim(vim.b.gitsigns_blame_line or "")
      end

      -- Show more of the file path before truncating
      opts.sections = opts.sections or {}
      opts.sections.lualine_c = {
        {
          "filename",
          path = 1, -- relative path
          shorting_target = 20, -- leave 20 chars for other components (lower = more path shown)
        },
      }
      opts.sections.lualine_x = opts.sections.lualine_x or {}
      table.insert(opts.sections.lualine_x, 1, {
        git_blame,
        cond = function()
          return vim.b.gitsigns_blame_line_dict ~= nil and git_blame() ~= ""
        end,
      })
    end,
  },
}
