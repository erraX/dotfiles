-- -- For conciseness
local opts = { noremap = true, silent = true }

vim.keymap.set('n', 'q', '<Nop>', { noremap = true })

-- Navigation
vim.keymap.set('i', 'jk', '<Esc>', { desc = 'Press jk to enter normal mode' })
-- vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Vertical scroll down and center' })
-- vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Vertical scroll up and center' })
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Find next and center' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Find previous and center' })
vim.keymap.set('n', 'j', 'gj', opts)
vim.keymap.set('n', 'k', 'gk', opts)
vim.keymap.set('n', '0', '^', opts)

-- LSP
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = 'LSP: Go to Definition' })
vim.keymap.set('n', '<leader>lf', ':EslintFixAll <CR>', opts)

-- Clipboard
-- vim.keymap.set('n', 'x', '"_x', { noremap = true, silent = true, desc = 'Delete without sync to system clipboard' })
vim.keymap.set('x', 'p', '"_dP', { desc = 'Visual paste without overwriting register' })
vim.keymap.set('v', '<C-c>', '"+y', opts)
-- vim.keymap.set('v', 'p', '"_dP', opts)

-- Misc
vim.keymap.set('n', '<C-s>', '<cmd>w<CR>', { noremap = true, silent = true, desc = 'Save file' })
vim.keymap.set('n', '<leader>sn', '<cmd>noautocmd w<CR>', { noremap = true, silent = true, desc = 'Save file without formatting' })
vim.keymap.set('n', '<C-q>', '<cmd>q<CR>', { noremap = true, silent = true, desc = 'Quit' })

-- Buffers
vim.keymap.set('n', '<S-h>', ':bprevious<CR>', { noremap = true, silent = true, desc = 'Previous buffer' })
vim.keymap.set('n', '<S-l>', ':bnext<CR>', { noremap = true, silent = true, desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bn', '<cmd> enew <CR>', { noremap = true, silent = true, desc = 'New buffer' })
vim.keymap.set('n', '<S-w>', function()
  require('mini.bufremove').delete(0, false)
end, { desc = 'Delete buffer (keep window)' })

-- Window management
vim.keymap.set('n', '<leader>v', '<C-w>v', opts) -- split window vertically
vim.keymap.set('n', '<leader>h', '<C-w>s', opts) -- split window horizontally
vim.keymap.set('n', '<leader>se', '<C-w>=', opts) -- make split windows equal width & height
vim.keymap.set('n', '<leader>xs', ':close<CR>', opts) -- close current split window

-- Stay in indent mode
vim.keymap.set('v', '<', '<gv', opts)
vim.keymap.set('v', '>', '>gv', opts)

-- Toggle line wrapping
vim.keymap.set('n', '<leader>lw', '<cmd>set wrap!<CR>', opts)

-- Diagnostic keymaps
vim.keymap.set('n', '[d', function()
  vim.diagnostic.jump { count = -1, float = true }
end, { desc = 'Go to previous diagnostic message' })

vim.keymap.set('n', ']d', function()
  vim.diagnostic.jump { count = 1, float = true }
end, { desc = 'Go to next diagnostic message' })

vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })
