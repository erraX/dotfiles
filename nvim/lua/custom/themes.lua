-- In your init.lua or a separate themes.lua file
local M = {}

-- Function to read current theme from file
function M.get_current_theme()
  local theme_file = vim.fn.expand '~/.config/nvim/current_theme'
  local f = io.open(theme_file, 'r')
  if f then
    local theme = f:read('*all'):gsub('%s+', '')
    f:close()
    return theme
  end
  return 'solarized-dark' -- Default theme
end

-- Define your themes
M.themes = {
  ['solarized-dark'] = function()
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'solarized'
  end,
  ['quietlight'] = function()
    require('quietlight').setup {
      transparent = true,
      italic_comments = true,
      bold_functions = true,
    }
    vim.o.background = 'light'
    vim.cmd.colorscheme 'quietlight'
  end,
  ['gruvbox'] = function()
    require('gruvbox').setup {
      contrast = 'soft',
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'gruvbox'
  end,
  ['tokyoday'] = function()
    require('tokyonight').setup {
      style = 'day',
      styles = { comments = { italic = false } },
    }
    vim.o.background = 'light'
    vim.cmd.colorscheme 'tokyonight-day'
  end,
  -- Add more themes as needed
}

-- Apply the current theme
function M.apply_theme()
  local theme = M.get_current_theme()
  if M.themes[theme] then
    M.themes[theme]()
    print('Applied theme: ' .. theme)
  else
    print('Unknown theme: ' .. theme)
    -- Apply default theme
    M.themes['solarized-dark']()
  end
end

-- Watch for theme changes
function M.setup_theme_watcher()
  local theme_file = vim.fn.expand '~/.config/nvim/current_theme'

  -- Create an autocommand group
  local augroup = vim.api.nvim_create_augroup('ThemeWatcher', { clear = true })

  -- Watch for changes to the theme file
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'FileChangedShellPost' }, {
    pattern = theme_file,
    group = augroup,
    callback = function()
      M.apply_theme()
    end,
  })

  -- Apply theme on startup
  M.apply_theme()
end

return M
