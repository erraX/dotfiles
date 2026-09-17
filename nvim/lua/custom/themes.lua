-- In your init.lua or a separate themes.lua file
local M = {}

local function apply_everforest(background, contrast)
  vim.o.background = background
  vim.g.everforest_background = contrast
  vim.g.everforest_better_performance = 1
  vim.cmd.colorscheme 'everforest'
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
      -- Upstream Dawn gold #ea9d34 is 2.05:1 on the base; ochre keeps the hue
      -- at the lightness/chroma of love/rose (4.0:1). Same value as the
      -- terminal palette 3/11, pi, lazygit, yazi, delta and Herdr.
      palette = { dawn = { gold = '#a46d24' } },
      highlight_groups = {
        -- Search puts dark text on the gold: keep upstream's light gold there
        -- (3.2:1); on ochre it would drop to 1.7:1. CurSearch/IncSearch use
        -- base-on-gold and get better with ochre (2.1 -> 4.0:1).
        Search = { fg = 'text', bg = '#ea9d34', blend = 20 },
      },
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
  ['catppuccin-frappe'] = function()
    require('catppuccin').setup {
      flavour = 'frappe',
      no_italic = true,
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'catppuccin-frappe'
  end,
  ['nordfox'] = function()
    require('nightfox').setup {
      options = { styles = { comments = 'NONE', keywords = 'NONE' } },
    }
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'nordfox'
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
    -- Wipe highlight groups defined *before* the colorscheme loads (e.g. bufferline's
    -- `default` highlights, derived from Neovim's built-in scheme at plugin setup).
    -- Most colorschemes only `hi clear` when g:colors_name is already set, so on a
    -- fresh start those stale groups would survive and `hi default` re-application
    -- on ColorScheme could not replace them.
    vim.cmd.highlight 'clear'

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
