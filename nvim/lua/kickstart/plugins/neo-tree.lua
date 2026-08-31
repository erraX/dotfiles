-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    {
      '<leader>e',
      function()
        if vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) ~= '' then
          vim.cmd 'Neotree reveal'
        else
          vim.cmd 'Neotree filesystem'
        end
      end,
      desc = 'NeoTree reveal',
      silent = true,
    },
  },
  opts = {
    close_if_last_window = false,
    follow_current_file = true,
    filesystem = {
      components = {
        icon = function(config, node, state)
          local icon = require('neo-tree.sources.common.components').icon(config, node, state)
          icon.text = icon.text .. ' '
          return icon
        end,
      },
      window = {
        mappings = {
          ['<leader>e'] = 'close_window',
          ['Y'] = function(state)
            -- NeoTree is based on [NuiTree](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/tree)
            -- The node is based on [NuiNode](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/tree#nuitreenode)
            local node = state.tree:get_node()
            local filepath = node:get_id()
            local filename = node.name
            local modify = vim.fn.fnamemodify

            local results = {
              filepath,
              modify(filepath, ':.'),
              modify(filepath, ':~'),
              filename,
              modify(filename, ':r'),
              modify(filename, ':e'),
            }

            -- absolute path to clipboard
            local i = vim.fn.inputlist {
              'Choose to copy to clipboard:',
              '1. Absolute path: ' .. results[1],
              '2. Path relative to CWD: ' .. results[2],
              '3. Path relative to HOME: ' .. results[3],
              '4. Filename: ' .. results[4],
              '5. Filename without extension: ' .. results[5],
              '6. Extension of the filename: ' .. results[6],
            }

            if i > 0 then
              local result = results[i]
              if not result then
                return print('Invalid choice: ' .. i)
              end
              vim.fn.setreg('+', result)
              vim.notify('Copied: ' .. result)
            end
          end,
        },
      },
    },
  },
}
