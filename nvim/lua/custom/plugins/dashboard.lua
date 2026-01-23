return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  config = function()
    require('dashboard').setup {
      theme = 'hyper',
      config = {
        week_header = {
          enable = true,
        },
        -- project = {
        --   enable = true,
        --   limit = 8,
        --   icon = '󰳏',
        --   label = 'Projects',
        --   action = 'Telescope find_files cwd=',
        -- },
        shortcut = {
          { desc = '󰊳 Update', group = '@property', action = 'Lazy update', key = 'u' },
          {
            icon = ' ',
            icon_hl = '@variable',
            desc = 'Neovim config',
            group = 'Label',
            action = 'cd ~/.config/nvim | e ~/.config/nvim/init.lua',
            key = 'n',
          },
          {
            icon = ' ',
            icon_hl = '@variable',
            desc = 'Files',
            group = 'Label',
            action = 'Telescope find_files',
            key = 'f',
          },
          {
            icon = '󰳏 ',
            icon_hl = '@variable',
            desc = 'Projects',
            group = 'Projects',
            action = 'Telescope project',
            key = 'p',
          },
          {
            desc = ' dotfiles',
            group = 'Number',
            key = 'd',
            action = function()
              require('telescope.builtin').find_files {
                prompt_title = 'Dotfiles',
                cwd = vim.fn.expand '~', -- 搜索 ~/ 目录
                hidden = true, -- 包括 .config、.zshrc 等隐藏文件
                follow = true, -- 跟随符号链接（可选）
              }
            end,
          },
        },
      },
    }
  end,
  dependencies = { { 'nvim-tree/nvim-web-devicons' } },
}
