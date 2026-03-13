return {
  'erraX/nvim-ctx',
  cmd = { 'NvimCtxSend', 'NvimCtxPickTarget', 'NvimCtxClearTarget' },
  opts = {
    clipboard = {
      enabled = true,
      register = '+',
    },
  },
  keys = {
    { '<leader>ap', '<cmd>NvimCtxPickTarget<cr>', desc = 'Pick AI target', mode = 'n' },
    { '<leader>ax', '<cmd>NvimCtxClearTarget<cr>', desc = 'Clear AI target', mode = 'n' },
    { '<leader>al', ':NvimCtxSend<cr>', desc = 'Send selected context', mode = 'x' },
    { '<leader>al', '<cmd>NvimCtxSend<cr>', desc = 'Send current line context', mode = 'n' },
  },
}
