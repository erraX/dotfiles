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
  ['everforest'] = function()
    vim.o.background = 'dark'
    vim.g.everforest_background = 'medium'
    vim.g.everforest_better_performance = 1
    vim.cmd.colorscheme 'everforest'
  end,
  ['tokyoday'] = function()
    require('tokyonight').setup {
      style = 'day',
      styles = { comments = { italic = false } },
    }
    vim.o.background = 'light'
    vim.cmd.colorscheme 'tokyonight-day'
  end,
  ['tokyonight'] = function()
    require('tokyonight').setup {
      style = 'storm',
      styles = { comments = { italic = false } },
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'tokyonight-storm'
  end,
  -- Add more themes as needed
}

-- Apply the current theme
function M.apply_theme(theme)
  theme = theme or M.get_current_theme()
  if theme == M.current_theme then
    return
  end

  if M.themes[theme] then
    local ok, err = pcall(M.themes[theme])
    if not ok then
      vim.notify('Failed to apply theme "' .. theme .. '": ' .. err, vim.log.levels.ERROR)
      return
    end

    M.current_theme = theme
    vim.notify('Applied theme: ' .. theme)
  else
    vim.notify('Unknown theme: ' .. theme, vim.log.levels.WARN)
    M.apply_theme 'solarized-dark'
  end
end

-- Watch for theme changes
function M.setup_theme_watcher()
  local theme_file = vim.fn.expand '~/.config/nvim/current_theme'
  local theme_dir = vim.fs.dirname(theme_file)

  local augroup = vim.api.nvim_create_augroup('ThemeWatcher', { clear = true })

  -- Re-check after Neovim returns to the foreground in case the filesystem
  -- event was missed while the machine was asleep.
  vim.api.nvim_create_autocmd({ 'FocusGained', 'VimResume' }, {
    group = augroup,
    callback = function()
      M.apply_theme()
    end,
  })

  if M.watcher then
    M.watcher:stop()
    M.watcher:close()
  end

  M.watcher = vim.uv.new_fs_event()
  if M.watcher then
    M.watcher:start(theme_dir, {}, function(err, filename)
      if err or (filename and filename ~= 'current_theme') then
        return
      end

      vim.schedule(M.apply_theme)
    end)
  end

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      if M.watcher and not M.watcher:is_closing() then
        M.watcher:stop()
        M.watcher:close()
      end
    end,
  })

  M.apply_theme()
end

return M
