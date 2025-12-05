-- Detect macOS system appearance
local function is_dark_mode()
  if vim.fn.has("mac") == 1 then
    local result = vim.fn.system("defaults read -g AppleInterfaceStyle 2>/dev/null")
    return result:match("Dark") ~= nil
  end
  return false
end

return {
  { "projekt0n/github-nvim-theme", name = "github-theme" },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = is_dark_mode() and "github_dark_default" or "github_light_default",
    },
  },
}
