return {
  'catgoose/nvim-colorizer.lua',
  event = 'BufReadPre',
  opts = {
    filetypes = { '*' },
    user_default_options = {
      RGB = true,
      RRGGBB = true,
      RRGGBBAA = true,
      AARRGGBB = false,
      names = false,
      rgb_fn = true,
      hsl_fn = true,
      css = false,
      css_fn = false,
      tailwind = false,
      mode = 'virtualtext',
      virtualtext = '■',
      virtualtext_inline = true,
      virtualtext_mode = 'foreground',
      sass = { enable = false },
    },
  },
}
