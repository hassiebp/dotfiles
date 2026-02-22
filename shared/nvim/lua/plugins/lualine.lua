return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- Show more of the file path before truncating
      opts.sections = opts.sections or {}
      opts.sections.lualine_c = {
        {
          "filename",
          path = 1, -- relative path
          shorting_target = 20, -- leave 20 chars for other components (lower = more path shown)
        },
      }
    end,
  },
}
