return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers = opts.servers or {}

    local poetry_path = vim.fn.trim(vim.fn.system("poetry env info --path"))
    if vim.v.shell_error ~= 0 or poetry_path == "" then
      return
    end

    opts.servers.pyright = vim.tbl_deep_extend("force", opts.servers.pyright or {}, {
      settings = {
        python = {
          pythonPath = poetry_path .. "/bin/python",
        },
      },
    })
  end,
}
