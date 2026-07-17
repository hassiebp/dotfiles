local M = {}

local DARK_COLORSCHEME = "github_dark_default"
local LIGHT_COLORSCHEME = "github_light_default"
local POLL_INTERVAL_MS = 5000

local timer

local function is_macos()
  return vim.fn.has("mac") == 1
end

function M.is_dark()
  if not is_macos() then
    return false
  end

  local result = vim.fn.system("defaults read -g AppleInterfaceStyle 2>/dev/null")
  return result:match("Dark") ~= nil
end

function M.background()
  return M.is_dark() and "dark" or "light"
end

function M.colorscheme()
  return M.background() == "dark" and DARK_COLORSCHEME or LIGHT_COLORSCHEME
end

function M.apply()
  local background = M.background()
  local colorscheme = background == "dark" and DARK_COLORSCHEME or LIGHT_COLORSCHEME

  if vim.o.background ~= background then
    vim.o.background = background
  end

  if vim.g.colors_name ~= colorscheme then
    pcall(vim.cmd.colorscheme, colorscheme)
  end
end

function M.setup()
  if not is_macos() then
    return
  end

  local group = vim.api.nvim_create_augroup("SystemAppearance", { clear = true })

  vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
    group = group,
    callback = M.apply,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      if timer then
        timer:stop()
        if not timer:is_closing() then
          timer:close()
        end
        timer = nil
      end
    end,
  })

  if timer then
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
  end

  timer = (vim.uv or vim.loop).new_timer()
  timer:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, vim.schedule_wrap(M.apply))

  M.apply()
end

return M
