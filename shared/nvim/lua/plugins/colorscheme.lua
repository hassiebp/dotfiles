-- Detect macOS system appearance
local function is_dark_mode()
  if vim.fn.has("mac") == 1 then
    local result = vim.fn.system("defaults read -g AppleInterfaceStyle 2>/dev/null")
    return result:match("Dark") ~= nil
  end
  return false
end

local function keep_diff_background(group)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or vim.tbl_isempty(hl) then
    return
  end

  local new_hl = {}
  for _, key in ipairs({
    "bg",
    "sp",
    "blend",
    "bold",
    "italic",
    "underline",
    "undercurl",
    "underdashed",
    "underdotted",
    "underdouble",
    "strikethrough",
    "standout",
    "reverse",
    "nocombine",
  }) do
    if hl[key] ~= nil then
      new_hl[key] = hl[key]
    end
  end

  vim.api.nvim_set_hl(0, group, new_hl)
end

local function apply_diff_background_only()
  for _, group in ipairs({ "DiffAdd", "DiffChange", "DiffText", "DiffDelete" }) do
    keep_diff_background(group)
  end
end

return {
  { "projekt0n/github-nvim-theme", name = "github-theme" },

  {
    "LazyVim/LazyVim",
    init = function()
      local augroup = vim.api.nvim_create_augroup("HassiebDiffHighlights", { clear = true })

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        callback = apply_diff_background_only,
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        group = augroup,
        once = true,
        callback = apply_diff_background_only,
      })
    end,
    opts = {
      colorscheme = is_dark_mode() and "github_dark_default" or "github_light_default",
    },
  },
}
