return {
  'akinsho/bufferline.nvim',
  dependencies = {
    'nvim-mini/mini.nvim',
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    -- Take the tab-bar palette from the active colorscheme's own TabLine groups
    -- instead of bufferline's default recipe (Normal darkened by 25% for tabs and
    -- 45% for the fill), which reads as near-black on dark themes. The references
    -- are resolved again on every ColorScheme, so they follow theme switches.
    local function attr(group, attribute)
      return { highlight = group, attribute = attribute }
    end
    local tab_bg = attr('TabLine', 'bg') -- unselected buffers
    local fill_bg = attr('TabLineFill', 'bg') -- empty space right of the tabs
    local sep_fg = attr('TabLine', 'fg') -- '│' between tabs

    local highlights = {
      buffer_selected = { bold = true, italic = false },
      separator_selected = { fg = sep_fg },
      separator_visible = { fg = sep_fg },
    }
    -- Every component drawn inside an unselected tab (bufferline's `background_color`).
    for _, group in ipairs {
      'background', 'buffer', 'close_button', 'diagnostic', 'duplicate',
      'error', 'error_diagnostic', 'hint', 'hint_diagnostic', 'info', 'info_diagnostic',
      'modified', 'numbers', 'pick', 'separator', 'tab', 'tab_close', 'tab_separator',
      'warning', 'warning_diagnostic',
    } do
      highlights[group] = { bg = tab_bg }
    end
    highlights.separator.fg = sep_fg
    -- Everything drawn on the fill (bufferline's `separator_background_color`).
    for _, group in ipairs { 'fill', 'group_separator', 'offset_separator', 'trunc_marker' } do
      highlights[group] = { bg = fill_bg }
    end

    require('bufferline').setup {
      options = {
        mode = 'buffers', -- set to "tabs" to only show tabpages instead
        themable = true, -- allows highlight groups to be overriden i.e. sets highlights as default
        numbers = 'none', -- | "ordinal" | "buffer_id" | "both" | function({ ordinal, id, lower, raise }): string,
        close_command = 'Bdelete! %d', -- can be a string | function, see "Mouse actions"
        buffer_close_icon = '✗',
        close_icon = '✗',
        path_components = 1, -- Show only the file name without the directory
        modified_icon = '●',
        left_trunc_marker = '',
        right_trunc_marker = '',
        max_name_length = 30,
        max_prefix_length = 30, -- prefix used when a buffer is de-duplicated
        tab_size = 21,
        diagnostics = false,
        diagnostics_update_in_insert = false,
        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = true,
        persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
        separator_style = { '│', '│' }, -- | "thick" | "thin" | { 'any', 'any' },
        enforce_regular_tabs = true,
        always_show_bufferline = true,
        show_tab_indicators = false,
        indicator = {
          -- icon = '▎', -- this should be omitted if indicator style is not 'icon'
          style = 'none', -- Options: 'icon', 'underline', 'none'
        },
        icon_pinned = '󰐃',
        minimum_padding = 1,
        maximum_padding = 5,
        maximum_length = 15,
        sort_by = 'insert_at_end',
      },
      highlights = highlights,
    }
  end,
}
