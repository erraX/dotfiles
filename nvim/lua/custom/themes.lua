-- In your init.lua or a separate themes.lua file
local M = {}

local function apply_everforest(background, contrast)
  vim.o.background = background
  vim.g.everforest_background = contrast
  vim.g.everforest_better_performance = 1
  vim.cmd.colorscheme 'everforest'
end

local function apply_catppuccin(flavour, background)
  require('catppuccin').setup {
    flavour = flavour,
    no_italic = true,
  }
  vim.o.background = background
  vim.cmd.colorscheme('catppuccin-' .. flavour)
end

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
    apply_everforest('dark', 'medium')
  end,
  ['everforest-light-hard'] = function()
    apply_everforest('light', 'hard')
  end,
  ['everforest-light-medium'] = function()
    apply_everforest('light', 'medium')
  end,
  ['everforest-light-soft'] = function()
    apply_everforest('light', 'soft')
  end,
  ['tokyoday'] = function()
    require('tokyonight').setup {
      style = 'day',
      styles = { comments = { italic = false } },
    }
    vim.o.background = 'light'
    vim.cmd.colorscheme 'tokyonight-day'
  end,
  ['kanagawa-lotus'] = function()
    require('kanagawa').setup {
      theme = 'lotus',
      background = { dark = 'wave', light = 'lotus' },
      commentStyle = { italic = false },
      keywordStyle = { italic = false },
      terminalColors = true,
    }
    vim.o.background = 'light'
    vim.cmd.colorscheme 'kanagawa-lotus'
  end,
  ['rose-pine-dawn'] = function()
    require('rose-pine').setup {
      variant = 'dawn',
      dark_variant = 'moon',
      styles = { italic = false, transparency = false },
    }
    vim.o.background = 'light'
    vim.cmd.colorscheme 'rose-pine-dawn'
  end,
  ['rose-pine-moon'] = function()
    require('rose-pine').setup {
      variant = 'moon',
      dark_variant = 'moon',
      styles = { italic = false, transparency = false },
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'rose-pine-moon'
  end,
  ['tokyonight'] = function()
    require('tokyonight').setup {
      style = 'storm',
      styles = { comments = { italic = false } },
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'tokyonight-storm'
  end,
  ['kanagawa-dragon'] = function()
    require('kanagawa').setup {
      theme = 'dragon',
      background = { dark = 'dragon', light = 'lotus' },
      commentStyle = { italic = false },
      keywordStyle = { italic = false },
      terminalColors = true,
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'kanagawa-dragon'
  end,
  ['catppuccin-latte'] = function()
    apply_catppuccin('latte', 'light')
  end,
  ['catppuccin-frappe'] = function()
    apply_catppuccin('frappe', 'dark')
  end,
  ['catppuccin-macchiato'] = function()
    apply_catppuccin('macchiato', 'dark')
  end,
  ['catppuccin-mocha'] = function()
    apply_catppuccin('mocha', 'dark')
  end,
  ['terafox'] = function()
    require('nightfox').setup {
      options = { styles = { comments = 'NONE', keywords = 'NONE' } },
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'terafox'
  end,
  ['nordfox'] = function()
    require('nightfox').setup {
      options = { styles = { comments = 'NONE', keywords = 'NONE' } },
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'nordfox'
  end,
  ['gruvbox-material'] = function()
    vim.g.gruvbox_material_background = 'medium'
    vim.g.gruvbox_material_foreground = 'material'
    vim.g.gruvbox_material_enable_italic = 0
    vim.g.gruvbox_material_disable_italic_comment = 1
    vim.g.gruvbox_material_better_performance = 1
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'gruvbox-material'
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
